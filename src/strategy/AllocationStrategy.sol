// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IAllo} from "src/interfaces/IAllo.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {Metadata} from "src/libraries/Metadata.sol";
import {BaseStrategy} from "./BaseStrategy.sol";

import {Roles} from "src/governor/GovRoles.sol";

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

// represents the nft held by the guardians, they can be allows to vote on who gets funded..
// if not staked, it will be exempt. holders of the nft will also receive residual funds from the strategy

contract StealthStrategy is BaseStrategy {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Stores the details of the recipients.
    struct Recipient {
        bool useRegistryAnchor;
        address recipientAddress;
        uint256 proposalBid;
        Status recipientStatus;
        Metadata metadata;
    }

    /// @notice Stores the details of the milestone

    // funds are issued to users, based on milestones
    struct Milestone {
        uint256 amountPercentage;
        Metadata metadata;
        Status milestoneStatus;
    }

    IVotes public GoverannceToken;

    mapping(address => Recipient) private recipients;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the milestone is invalid
    error INVALID_MILESTONE();

    /// @notice Thrown when the milestone are already approved and cannot be changed
    error MILESTONES_ALREADY_SET();

    /// @notice Throws when the milestone is already accepted.
    error MILESTONE_ALREADY_ACCEPTED();

    /// @notice Throws when the allocation exceeds the pool amount.
    error ALLOCATION_EXCEEDS_POOL_AMOUNT();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted for the registration of a recipient and the status is updated.
    event RecipientStatusChanged(address recipientId, Status status);

    /// @notice Emitted for the submission of a milestone.
    event MilestoneSubmitted(address recipientId, uint256 milestoneId, Metadata metadata);

    /// @notice Emitted for the status change of a milestone.
    event MilestoneStatusChanged(address recipientId, uint256 milestoneId, Status status);

    /// @notice Emitted for the milestones set.
    event MilestonesSet(address recipientId, uint256 milestonesLength);

    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/

    // @notice Struct to hold the init params for the strategy
    struct InitializeData {
        address GovernanceToken;
        uint256 timestamp;
        bool registryGating;
        bool metadataRequired;
        bool grantAmountRequired;
    }

    /// @notice Flag to check if registry gating is enabled.
    bool public registryGating;

    /// @notice Flag to check if metadata is required.
    bool public metadataRequired;

    /// @notice Flag to check if grant amount is required.
    bool public grantAmountRequired;

    /// @notice The 'Registry' contract interface.
    // IRegistry private _registry;
    address private _registry;

    /// @notice The total amount allocated to grant/recipient.
    uint256 public allocatedGrantAmount;
    uint256 public timeStamp;

    /// @notice This maps accepted recipients to their details
    /// @dev 'recipientId' to 'Recipient'
    mapping(address => Recipient) private _recipients;

    /// @notice This maps accepted recipients to their milestones
    /// @dev 'recipientId' to 'Milestone'
    mapping(address => Milestone[]) public milestones;

    /// @notice This maps accepted recipients to their upcoming milestone
    /// @dev 'recipientId' to 'nextMilestone'
    mapping(address => uint256) public upcomingMilestone;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Constructor for the Direct Grants Simple Strategy
    /// @param _allo The 'Allo' contract
    /// @param _name The name of the strategy
    constructor(address _allo, string memory _name) BaseStrategy(_allo, _name) {}

    /*//////////////////////////////////////////////////////////////
                            INITIALIZE
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the strategy
    /// @param _poolId ID of the pool
    /// @param _data The data to be decoded
    /// @custom:data (bool registryGating, bool metadataRequired, bool grantAmountRequired)
    function initialize(uint256 _poolId, bytes memory _data) external virtual override {
        (InitializeData memory initData) = abi.decode(_data, (InitializeData));
        __DirectGrantsSimpleStrategy_init(_poolId, initData);
        emit Initialized(_poolId, _data);
    }

    /// @notice This initializes the BaseStrategy
    /// @dev You only need to pass the 'poolId' to initialize the BaseStrategy and the rest is specific to the strategy
    /// @param _poolId ID of the pool - required to initialize the BaseStrategy
    /// @param _initData The init params for the strategy (bool registryGating, bool metadataRequired, bool grantAmountRequired)
    function __DirectGrantsSimpleStrategy_init(uint256 _poolId, InitializeData memory _initData) internal {
        // Initialize the BaseStrategy
        __BaseStrategy_init(_poolId);

        GoverannceToken = IVotes(_initData.GovernanceToken);

        // Set the strategy specific variables
        registryGating = _initData.registryGating;
        metadataRequired = _initData.metadataRequired;
        grantAmountRequired = _initData.grantAmountRequired;
        timeStamp = _initData.timestamp;
        _registry = allo.getRegistry();

        // Set the pool to active - this is required for the strategy to work and distribute funds
        // NOTE: There may be some cases where you may want to not set this here, but will be strategy specific
        _setPoolActive(true);

        // sanity check if token implements getPastVotes
        // should revert if function is not available
        (uint256 value) = GoverannceToken.getPastVotes(address(this), 0);
        require(value == 0);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the recipient
    /// @param _recipientId ID of the recipient
    /// @return Recipient Returns the recipient
    function getRecipient(address _recipientId) external view returns (Recipient memory) {
        return _getRecipient(_recipientId);
    }

    /// @notice Get recipient status
    /// @dev The global 'Status' is used at the protocol level and most strategies will use this.
    /// @param _recipientId ID of the recipient
    /// @return Status Returns the global recipient status
    function _getRecipientStatus(address _recipientId) internal view override returns (Status) {
        return _getRecipient(_recipientId).recipientStatus;
    }

    /// @notice Checks if address is eligible allocator.
    /// @dev This is used to check if the allocator is a pool manager and able to allocate funds from the pool
    /// @param _allocator Address of the allocator
    /// @return 'true' if the allocator is a pool manager, otherwise false
    function _isValidAllocator(address _allocator) internal view override returns (bool) {
        return allo.isPoolManager(poolId, _allocator);
    }

    /// @notice Get the status of the milestone of an recipient.
    /// @dev This is used to check the status of the milestone of an recipient and is strategy specific
    /// @param _recipientId ID of the recipient
    /// @param _milestoneId ID of the milestone
    /// @return Status Returns the status of the milestone using the 'Status' enum
    function getMilestoneStatus(address _recipientId, uint256 _milestoneId) external view returns (Status) {
        return milestones[_recipientId][_milestoneId].milestoneStatus;
    }

    /// @notice Get the milestones.
    /// @param _recipientId ID of the recipient
    /// @return Milestone[] Returns the milestones for a 'recipientId'
    function getMilestones(address _recipientId) external view returns (Milestone[] memory) {
        return milestones[_recipientId];
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set milestones for recipient.
    /// @dev 'msg.sender' must be recipient creator or pool manager. Emits a 'MilestonesReviewed()' event.
    /// @param _recipientId ID of the recipient
    /// @param _milestones The milestones to be set
    function setMilestones(address _recipientId, Milestone[] memory _milestones) external virtual {
        bool isRecipientCreator = (msg.sender == _recipientId) || _isProfileMember(_recipientId, msg.sender);
        bool isPoolManager = allo.isPoolManager(poolId, msg.sender);
        if (!isRecipientCreator && !isPoolManager) {
            revert UNAUTHORIZED();
        }

        Recipient storage recipient = _recipients[_recipientId];

        // Check if the recipient is accepted, otherwise revert
        if (recipient.recipientStatus != Status.Accepted) {
            revert RECIPIENT_NOT_ACCEPTED();
        }

        _setMilestones(_recipientId, _milestones);
    }

    /// @notice Submit milestone by the recipient.
    /// @dev 'msg.sender' must be the 'recipientId' (this depends on whether your using registry gating) and must be a member
    ///      of a 'Profile' to submit a milestone and '_recipientId'.
    ///      must NOT be the same as 'msg.sender'. Emits a 'MilestonesSubmitted()' event.
    /// @param _recipientId ID of the recipient
    /// @param _metadata The proof of work
    function submitMilestone(address _recipientId, uint256 _milestoneId, Metadata calldata _metadata)
        external
        virtual
    {
        // Check if the '_recipientId' is the same as 'msg.sender' and if it is NOT, revert. This
        // also checks if the '_recipientId' is a member of the 'Profile' and if it is NOT, revert.
        if (_recipientId != msg.sender && !_isProfileMember(_recipientId, msg.sender)) {
            revert UNAUTHORIZED();
        }

        Recipient memory recipient = _recipients[_recipientId];

        // Check if the recipient is 'Accepted', otherwise revert
        if (recipient.recipientStatus != Status.Accepted) {
            revert RECIPIENT_NOT_ACCEPTED();
        }

        Milestone[] storage recipientMilestones = milestones[_recipientId];

        // Check if the milestone is the upcoming one
        if (_milestoneId > recipientMilestones.length) {
            revert INVALID_MILESTONE();
        }

        Milestone storage milestone = recipientMilestones[_milestoneId];

        // Check if the milestone is accepted, otherwise revert
        if (milestone.milestoneStatus == Status.Accepted) {
            revert MILESTONE_ALREADY_ACCEPTED();
        }

        // Set the milestone metadata and status
        milestone.metadata = _metadata;
        milestone.milestoneStatus = Status.Pending;

        // Emit event for the milestone submission
        emit MilestoneSubmitted(_recipientId, _milestoneId, _metadata);
    }

    /// @notice Reject pending milestone of the recipient.
    /// @dev 'msg.sender' must be a pool manager to reject a milestone. Emits a 'MilestonesStatusChanged()' event.
    /// @param _recipientId ID of the recipient
    /// @param _milestoneId ID of the milestone
    function rejectMilestone(address _recipientId, uint256 _milestoneId) external virtual onlyPoolManager(msg.sender) {
        Milestone[] storage recipientMilestones = milestones[_recipientId];

        // Check if the milestone is the upcoming one
        if (_milestoneId > recipientMilestones.length) {
            revert INVALID_MILESTONE();
        }

        Milestone storage milestone = recipientMilestones[_milestoneId];

        // Check if the milestone is NOT 'Accepted' already, and revert if it is
        if (milestone.milestoneStatus == Status.Accepted) {
            revert MILESTONE_ALREADY_ACCEPTED();
        }

        // Set the milestone status to 'Rejected'
        milestone.milestoneStatus = Status.Rejected;

        // Emit event for the milestone rejection
        emit MilestoneStatusChanged(_recipientId, _milestoneId, Status.Rejected);
    }

    /// @notice Set the status of the recipient to 'InReview'
    /// @dev Emits a 'RecipientStatusChanged()' event
    /// @param _recipientIds IDs of the recipients
    function setRecipientStatusToInReview(address[] calldata _recipientIds)
        external
        virtual
        onlyPoolManager(msg.sender)
    {
        uint256 recipientLength = _recipientIds.length;
        for (uint256 i; i < recipientLength;) {
            address recipientId = _recipientIds[i];
            _recipients[recipientId].recipientStatus = Status.InReview;

            emit RecipientStatusChanged(recipientId, Status.InReview);

            unchecked {
                i++;
            }
        }
    }

    /// @notice Toggle the status between active and inactive.
    /// @dev 'msg.sender' must be a pool manager to close the pool. Emits a 'PoolActive()' event.
    /// @param _flag The flag to set the pool to active or inactive
    function setPoolActive(bool _flag) external virtual onlyPoolManager(msg.sender) {
        _setPoolActive(_flag);
        emit PoolActive(_flag);
    }

    /// @notice Withdraw funds from pool.
    /// @dev 'msg.sender' must be a pool manager to withdraw funds.
    /// @param _amount The amount to be withdrawn
    function withdraw(uint256 _amount) external virtual onlyPoolManager(msg.sender) onlyInactivePool {
        // Decrement the pool amount
        poolAmount -= _amount;

        // Transfer the amount to the pool manager
        _transferAmount(allo.getPool(poolId).token, msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Register a recipient to the pool.
    /// @dev Emits a 'Registered()' event
    /// @param _data The data to be decoded
    /// @custom:data when 'registryGating' is 'true' -> (address recipientId, address recipientAddress, uint256 grantAmount, Metadata metadata)
    ///              when 'registryGating' is 'false' -> (address recipientAddress, address registryAnchor, uint256 grantAmount, Metadata metadata)
    /// @param _sender The sender of the transaction
    /// @return recipientId The id of the recipient
    function _registerRecipient(bytes memory _data, address _sender)
        internal
        override
        onlyActivePool
        returns (address recipientId)
    {
        address recipientAddress;
        address registryAnchor;
        bool isUsingRegistryAnchor;
        uint256 grantAmount;
        Metadata memory metadata;

        // Decode '_data' depending on the 'registryGating' flag
        /// @custom:data when 'true' -> (address recipientId, address recipientAddress, uint256 grantAmount, Metadata metadata)
        if (registryGating) {
            (recipientId, recipientAddress, grantAmount, metadata) =
                abi.decode(_data, (address, address, uint256, Metadata));

            if (!_isProfileMember(recipientId, _sender)) {
                revert UNAUTHORIZED();
            }
        } else {
            /// @custom:data when 'false' -> (address recipientAddress, address registryAnchor, uint256 grantAmount, Metadata metadata)
            (recipientAddress, registryAnchor, grantAmount, metadata) =
                abi.decode(_data, (address, address, uint256, Metadata));

            // Check if the registry anchor is valid so we know whether to use it or not
            isUsingRegistryAnchor = registryAnchor != address(0);

            // Ternerary to set the recipient id based on whether or not we are using the 'registryAnchor' or '_sender'
            recipientId = isUsingRegistryAnchor ? registryAnchor : _sender;
            if (isUsingRegistryAnchor && !_isProfileMember(recipientId, _sender)) {
                revert UNAUTHORIZED();
            }
        }

        // Check if the grant amount is required and if it is, check if it is greater than 0, otherwise revert
        if (grantAmountRequired && grantAmount == 0) {
            revert INVALID_REGISTRATION();
        }

        // Check if the recipient is not already accepted, otherwise revert
        if (_recipients[recipientId].recipientStatus == Status.Accepted) {
            revert RECIPIENT_ALREADY_ACCEPTED();
        }

        // Check if the metadata is required and if it is, check if it is valid, otherwise revert
        if (metadataRequired && (bytes(metadata.pointer).length == 0 || metadata.protocol == 0)) {
            revert INVALID_METADATA();
        }

        // Create the recipient instance
        Recipient memory recipient = Recipient({
            useRegistryAnchor: registryGating ? true : isUsingRegistryAnchor,
            recipientAddress: recipientAddress,
            proposalBid: 1,
            recipientStatus: Status.Pending,
            metadata: metadata
        });

        // Add the recipient to the accepted recipient ids mapping
        _recipients[recipientId] = recipient;

        // Emit event for the registration
        emit Registered(recipientId, _data, _sender);
    }

    /// @notice Distribute the upcoming milestone to recipients.
    /// @dev '_sender' must be a pool manager to distribute.
    /// @param _recipientIds The recipient ids of the distribution
    /// @param _sender The sender of the distribution
    function _distribute(address[] memory _recipientIds, bytes memory, address _sender)
        internal
        virtual
        override
        onlyPoolManager(_sender)
    {
        uint256 recipientLength = _recipientIds.length;
        for (uint256 i; i < recipientLength;) {
            _distributeUpcomingMilestone(_recipientIds[i], _sender);
            unchecked {
                i++;
            }
        }
    }

    /// @notice Check if sender is a profile owner or member.
    /// @param _anchor Anchor of the profile
    /// @param _sender The sender of the transaction
    /// @return 'true' if the sender is the owner or member of the profile, otherwise 'false'
    function _isProfileMember(address _anchor, address _sender) internal view returns (bool) {
        IRegistry.Profile memory profile = IRegistry(_registry).getProfileByAnchor(_anchor);
        return IRegistry(_registry).isOwnerOrMemberOfProfile(profile.id, _sender);
    }

    /// @notice Get the recipient.
    /// @param _recipientId ID of the recipient
    /// @return recipient Returns the recipient information
    function _getRecipient(address _recipientId) internal view returns (Recipient memory recipient) {
        recipient = _recipients[_recipientId];
    }

    /// @notice Get the payout summary for the accepted recipient.
    /// @return Returns the payout summary for the accepted recipient
    function _getPayout(address _recipientId, bytes memory) internal view override returns (PayoutSummary memory) {
        Recipient memory recipient = _getRecipient(_recipientId);
        return PayoutSummary(recipient.recipientAddress, recipient.proposalBid);
    }

    /// @notice Set the milestones for the recipient.
    /// @param _recipientId ID of the recipient
    /// @param _milestones The milestones to be set
    function _setMilestones(address _recipientId, Milestone[] memory _milestones) internal {
        uint256 totalAmountPercentage;

        // Clear out the milestones and reset the index to 0
        if (milestones[_recipientId].length > 0) {
            delete milestones[_recipientId];
        }

        uint256 milestonesLength = _milestones.length;

        // Loop through the milestones and set them
        for (uint256 i; i < milestonesLength;) {
            Milestone memory milestone = _milestones[i];

            // Reverts if the milestone status is 'None'
            if (milestone.milestoneStatus != Status.None) {
                revert INVALID_MILESTONE();
            }

            // TODO: I see we check on line 649, but it seems we need to check when added it is NOT greater than 100%?
            // Add the milestone percentage amount to the total percentage amount
            totalAmountPercentage += milestone.amountPercentage;

            // Add the milestone to the recipient's milestones
            milestones[_recipientId].push(milestone);

            unchecked {
                i++;
            }
        }

        if (totalAmountPercentage != 1e18) {
            revert INVALID_MILESTONE();
        }

        emit MilestonesSet(_recipientId, milestonesLength);
    }

    /// @notice Allocate votes to a recipient
    /// @param _data The data
    /// @param _sender The sender of the transaction
    /// @dev Only the pool manager(s) can call this function
    function _allocate(bytes memory _data, address _sender) internal virtual override {
        (address recipientId, uint256 voiceCreditsToAllocate) = abi.decode(_data, (address, uint256));

        // spin up the structs in storage for updating
        Recipient storage recipient = recipients[recipientId];
        // Allocator storage allocator = allocators[_sender];

        uint256 votePower = GoverannceToken.getPastVotes(_sender, timeStamp);

        // if (!_hasVoiceCreditsLeft(voiceCreditsToAllocate + allocator.voiceCredits, votePower)) {
        //     revert INVALID();
        // }

        if (!_isAcceptedRecipient(recipientId)) {
            revert RECIPIENT_ERROR(recipientId);
        }

        // _qv_allocate(allocator, recipient, recipientId, voiceCreditsToAllocate, _sender);
    }

    function _isAcceptedRecipient(address _recipientId) internal view returns (bool) {
        return recipients[_recipientId].recipientStatus == Status.Accepted;
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Distribute the upcoming milestone.
    /// @dev Emits 'MilestoneStatusChanged() and 'Distributed()' events.
    /// @param _recipientId The recipient of the distribution
    /// @param _sender The sender of the distribution
    function _distributeUpcomingMilestone(address _recipientId, address _sender) private {
        uint256 milestoneToBeDistributed = upcomingMilestone[_recipientId];
        Milestone[] storage recipientMilestones = milestones[_recipientId];

        Recipient memory recipient = _recipients[_recipientId];
        Milestone storage milestone = recipientMilestones[milestoneToBeDistributed];

        // check if milestone is not rejected or already paid out
        if (milestoneToBeDistributed > recipientMilestones.length || milestone.milestoneStatus != Status.Pending) {
            revert INVALID_MILESTONE();
        }

        // Calculate the amount to be distributed for the milestone
        uint256 amount = recipient.proposalBid * milestone.amountPercentage / 1e18;

        // Get the pool, subtract the amount and transfer to the recipient
        IAllo.Pool memory pool = allo.getPool(poolId);

        poolAmount -= amount;
        _transferAmount(pool.token, recipient.recipientAddress, amount);

        // Set the milestone status to 'Accepted'
        milestone.milestoneStatus = Status.Accepted;

        // Increment the upcoming milestone
        upcomingMilestone[_recipientId]++;

        // Emit events for the milestone and the distribution
        emit MilestoneStatusChanged(_recipientId, milestoneToBeDistributed, Status.Accepted);
        emit Distributed(_recipientId, recipient.recipientAddress, amount, _sender);
    }
}
