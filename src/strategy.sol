// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import solady for everything. including ownership, tokens(erc20, erc721)

// handles one grant per address

// vesting vault?.

import {BaseStrategy} from "src/BaseStrategy.sol";
import {IAllo} from "src/interfaces/IAllo.sol";
import {IRegistry} from "src/interfaces/IRegistry.sol";
import {Metadata} from "src/libraries/Metadata.sol";

contract AlloStealthFundoor {
    // this should house the main functionality for slashing, distributing tokens as well as
    // interacting with the main allo funds allocation

    function withdrawPayOut() public {
        // an EOA(anon) can withdraw a part of the total payout staked for it
        // it should not be able to withdraw all its stake
        // naturally should have 3 vesting schedules. 33, 33, 33 -> rest stays on the contract. goes back to protocol
        // between the 3 schedules, the anon will be sending up updates accoring to why they got the grant in the first place
        // edge case..anons will just aim to get the 1/3 of the payout..each payout could be much granular.
        // maybe a configurable % can be set due to some calculated risk appetite of the project
    }
    function delegateFundsForAnAnon() public {
        // this interacts with the allo contract to get the funds into this contract.abi
        // so some funds will be set aside for a project, which represent the project getting a grant
    }
    function slashAnonUser() public {
        // slash an anon from getting any more payouts from the system
    }
    function slashGuardian() public {
        // slash a percievd to be malicious guardian
    }
    function confidenceThreshold() public {
        // threshold for confidence
    }
    function updateConfidenceThreshold() public {
        // owner can change this
    }
    function getGuardian() public {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function voteAgainstGuardian() public {
        // other guardians can vote against guardians percieved to be malicious
    }
    function slashAFlaggedAnon() public {
        // slash an anon account that has been flagged previously, from receiving any other grants from this contract
    }
    function flagAnAnon() public {
        // flag an anon percieved to be malicious
    }
    function unstake() public {
        // guardians can unstake to stop being a guardian
    }
    function stake() public {
        // accounts can stake token to become a guardian
    }
    function distribute() public {
        // distribute funds to all whitelisted anons
        // based on varying schedules

        // can be called by the owner of the contract. which is the super admin
    }

    function getPubKey() public {}
    function setPubKey() public {}
}

contract StealthStrategy is BaseStrategy {
    /// ================================
    /// ========== Struct ==============
    /// ================================

    /// @notice Stores the details of the recipients.
    struct Recipient {
        bool useRegistryAnchor;
        address recipientAddress;
        uint256 proposalBid;
        Status recipientStatus;
        Metadata metadata;
    }

    /// @notice Stores the details of the milestone
    struct Milestone {
        uint256 amountPercentage;
        Metadata metadata;
        Status milestoneStatus;
    }

    /// @notice Stores the details needed for initializing strategy
    struct InitializeParams {
        uint256 maxBid;
        bool useRegistryAnchor;
        bool metadataRequired;
    }

    /// ===============================
    /// ========== Errors =============
    /// ===============================

    /// @notice Thrown when the milestone is invalid
    error INVALID_MILESTONE();

    /// @notice Thrown when the milestone is not pending
    error MILESTONE_NOT_PENDING();

    /// @notice Thrown when the proposal bid exceeds maximum bid
    error EXCEEDING_MAX_BID();

    /// @notice Thrown when the milestone are already approved and cannot be changed
    error MILESTONES_ALREADY_SET();

    /// @notice Thrown when the pool manager attempts to the lower the max bid
    error AMOUNT_TOO_LOW();

    /// ===============================
    /// ========== Events =============
    /// ===============================

    /// @notice Emitted when the maximum bid is increased.
    /// @param maxBid The new maximum bid
    event MaxBidIncreased(uint256 maxBid);

    /// @notice Emitted when a milestone is submitted.
    /// @param milestoneId Id of the milestone
    event MilstoneSubmitted(uint256 milestoneId);

    /// @notice Emitted for the status change of a milestone.
    /// @param milestoneId Id of the milestone
    /// @param status Status of the milestone
    event MilestoneStatusChanged(uint256 milestoneId, Status status);

    /// @notice Emitted when milestones are set.
    /// @param milestonesLength Count of milestones
    event MilestonesSet(uint256 milestonesLength);

    /// @notice Emitted when a recipient updates their registration
    /// @param recipientId Id of the recipient
    /// @param data The encoded data - (address recipientId, address recipientAddress, Metadata metadata)
    /// @param sender The sender of the transaction
    event UpdatedRegistration(address indexed recipientId, bytes data, address sender);

    /// ================================
    /// ========== Storage =============
    /// ================================

    /// @notice Flag to indicate whether to use the registry anchor or not.
    bool public useRegistryAnchor;

    /// @notice Flag to indicate whether metadata is required or not.
    bool public metadataRequired;

    /// @notice The accepted recipient who can submit milestones.
    address public acceptedRecipientId;

    /// @notice The registry contract interface.
    IRegistry private _registry;

    /// @notice The maximum bid for the RFP pool.
    uint256 public maxBid;

    /// @notice The upcoming milestone which is to be paid.
    uint256 public upcomingMilestone;

    /// @notice Internal collection of recipients
    address[] private _recipientIds;

    /// @notice Collection of milestones submitted by the 'acceptedRecipientId'
    Milestone[] public milestones;

    /// @notice This maps accepted recipients to their details
    /// @dev 'recipientId' to 'Recipient'
    mapping(address => Recipient) internal _recipients;

    /// ===============================
    /// ======== Constructor ==========
    /// ===============================

    /// @notice Constructor for the RFP Simple Strategy
    /// @param _allo The 'Allo' contract
    /// @param _name The name of the strategy
    constructor(address _allo, string memory _name) BaseStrategy(_allo, _name) {}

    /// ===============================
    /// ========= Initialize ==========
    /// ===============================

    // @notice Initialize the strategy
    /// @param _poolId ID of the pool
    /// @param _data The data to be decoded
    /// @custom:data (uint256 _maxBid, bool registryGating, bool metadataRequired)
    function initialize(uint256 _poolId, bytes memory _data) external virtual override {
        (InitializeParams memory initializeParams) = abi.decode(_data, (InitializeParams));
        __RFPSimpleStrategy_init(_poolId, initializeParams);
        emit Initialized(_poolId, _data);
    }

    /// @notice This initializes the BaseStrategy
    /// @dev You only need to pass the 'poolId' to initialize the BaseStrategy and the rest is specific to the strategy
    /// @param _initializeParams The initialize params
    function __RFPSimpleStrategy_init(uint256 _poolId, InitializeParams memory _initializeParams) internal {
        // Initialize the BaseStrategy
        __BaseStrategy_init(_poolId);

        // Set the strategy specific variables
        useRegistryAnchor = _initializeParams.useRegistryAnchor;
        metadataRequired = _initializeParams.metadataRequired;
        _registry = allo.getRegistry();
        _increaseMaxBid(_initializeParams.maxBid);

        // Set the pool to active - this is required for the strategy to work and distribute funds
        // NOTE: There may be some cases where you may want to not set this here, but will be strategy specific
        _setPoolActive(true);
    }

    /// ===============================
    /// ============ Views ============
    /// ===============================

    /// @notice Get the recipient
    /// @param _recipientId ID of the recipient
    /// @return Recipient Returns the recipient
    function getRecipient(address _recipientId) external view returns (Recipient memory) {
        return _getRecipient(_recipientId);
    }

    /// @notice Checks if msg.sender is eligible for RFP allocation
    /// @param _recipientId Id of the recipient
    function _getRecipientStatus(address _recipientId) internal view override returns (Status) {
        return _getRecipient(_recipientId).recipientStatus;
    }

    /// @notice Return the payout for acceptedRecipientId
    function getPayouts(address[] memory, bytes[] memory) external view override returns (PayoutSummary[] memory) {
        PayoutSummary[] memory payouts = new PayoutSummary[](1);
        payouts[0] = _getPayout(acceptedRecipientId, "");

        return payouts;
    }

    /// @notice Get the milestone
    /// @param _milestoneId ID of the milestone
    /// @return Milestone Returns the milestone
    function getMilestone(uint256 _milestoneId) external view returns (Milestone memory) {
        return milestones[_milestoneId];
    }

    /// @notice Get the status of the milestone
    /// @param _milestoneId Id of the milestone
    function getMilestoneStatus(uint256 _milestoneId) external view returns (Status) {
        return milestones[_milestoneId].milestoneStatus;
    }

    /// ===============================
    /// ======= External/Custom =======
    /// ===============================

    /// @notice Toggle the status between active and inactive.
    /// @dev 'msg.sender' must be a pool manager to close the pool. Emits a 'PoolActive()' event.
    /// @param _flag The flag to set the pool to active or inactive
    function setPoolActive(bool _flag) external onlyPoolManager(msg.sender) {
        _setPoolActive(_flag);
    }

    /// @notice Set the milestones for the acceptedRecipientId.
    /// @dev 'msg.sender' must be a pool manager to set milestones. Emits 'MilestonesSet' event
    /// @param _milestones Milestone[] The milestones to be set
    function setMilestones(Milestone[] memory _milestones) external onlyPoolManager(msg.sender) {
        if (milestones.length > 0) {
            if (milestones[0].milestoneStatus != Status.None) revert MILESTONES_ALREADY_SET();
            delete milestones;
        }

        uint256 totalAmountPercentage;

        // Loop through the milestones and add them to the milestones array
        uint256 milestonesLength = _milestones.length;
        for (uint256 i; i < milestonesLength;) {
            uint256 amountPercentage = _milestones[i].amountPercentage;

            if (amountPercentage == 0) revert INVALID_MILESTONE();

            totalAmountPercentage += amountPercentage;
            _milestones[i].milestoneStatus = Status.None;
            milestones.push(_milestones[i]);

            unchecked {
                i++;
            }
        }

        // Check if the all milestone amount percentage totals to 1e18(100%)
        if (totalAmountPercentage != 1e18) revert INVALID_MILESTONE();

        emit MilestonesSet(milestonesLength);
    }

    /// @notice Submit milestone by the acceptedRecipientId.
    /// @dev 'msg.sender' should be the 'acceptedRecipientId' OR must be a member
    ///      of a 'Profile' assuming that 'acceptedRecipientId' is profile on the registry
    //       Emits a 'MilestonesSubmitted()' event.
    /// @param _metadata The proof of work
    function submitUpcomingMilestone(Metadata calldata _metadata) external {
        // Check if the 'msg.sender' is the 'acceptedRecipientId' or
        // 'acceptedRecipientId' is a profile on the Registry and sender is a member of the profile
        if (acceptedRecipientId != msg.sender && !_isProfileMember(acceptedRecipientId, msg.sender)) {
            revert UNAUTHORIZED();
        }

        // Check if the upcoming milestone is in fact upcoming
        if (upcomingMilestone >= milestones.length) revert INVALID_MILESTONE();

        // Get the milestone and update the metadata and status
        Milestone storage milestone = milestones[upcomingMilestone];
        milestone.metadata = _metadata;

        // Set the milestone status to 'Pending' to indicate that the milestone is submitted
        milestone.milestoneStatus = Status.Pending;

        // Emit event for the milestone
        emit MilstoneSubmitted(upcomingMilestone);
    }

    /// @notice Update max bid for RFP pool
    /// @dev 'msg.sender' must be a pool manager to update the max bid.
    /// @param _maxBid The max bid to be set
    function increaseMaxBid(uint256 _maxBid) external onlyPoolManager(msg.sender) {
        _increaseMaxBid(_maxBid);
    }

    /// @notice Reject pending milestone submmited by the acceptedRecipientId.
    /// @dev 'msg.sender' must be a pool manager to reject a milestone. Emits a 'MilestoneStatusChanged()' event.
    /// @param _milestoneId ID of the milestone
    function rejectMilestone(uint256 _milestoneId) external onlyPoolManager(msg.sender) {
        // Check if the milestone status is pending
        if (milestones[_milestoneId].milestoneStatus != Status.Pending) revert MILESTONE_NOT_PENDING();

        milestones[_milestoneId].milestoneStatus = Status.Rejected;

        emit MilestoneStatusChanged(_milestoneId, milestones[_milestoneId].milestoneStatus);
    }

    /// @notice Withdraw the tokens from the pool
    /// @dev Callable by the pool manager
    /// @param _token The token to withdraw
    function withdraw(address _token) external onlyPoolManager(msg.sender) onlyInactivePool {
        uint256 amount = _getBalance(_token, address(this));

        // Transfer the tokens to the 'msg.sender' (pool manager calling function)
        _transferAmount(_token, msg.sender, amount);
    }

    /// ====================================
    /// ============ Internal ==============
    /// ====================================

    /// @notice Submit a proposal to RFP pool
    /// @dev Emits a 'Registered()' event
    /// @param _data The data to be decoded
    /// @custom:data (address registryAnchor, address recipientAddress, uint256 proposalBid, Metadata metadata)
    /// @param _sender The sender of the transaction
    /// @return recipientId The id of the recipient
    function _registerRecipient(bytes memory _data, address _sender)
        internal
        override
        onlyActivePool
        returns (address recipientId)
    {
        bool isUsingRegistryAnchor;
        address recipientAddress;
        address registryAnchor;
        uint256 proposalBid;
        Metadata memory metadata;

        //  @custom:data (address registryAnchor, address recipientAddress, uint256 proposalBid, Metadata metadata)
        (registryAnchor, recipientAddress, proposalBid, metadata) =
            abi.decode(_data, (address, address, uint256, Metadata));

        // Check if the registry anchor is valid so we know whether to use it or not
        isUsingRegistryAnchor = useRegistryAnchor || registryAnchor != address(0);

        // Ternerary to set the recipient id based on whether or not we are using the 'registryAnchor' or '_sender'
        recipientId = isUsingRegistryAnchor ? registryAnchor : _sender;

        // Checks if the '_sender' is a member of the profile 'anchor' being used and reverts if not
        if (isUsingRegistryAnchor && !_isProfileMember(recipientId, _sender)) revert UNAUTHORIZED();

        // Check if the metadata is required and if it is, check if it is valid, otherwise revert
        if (metadataRequired && (bytes(metadata.pointer).length == 0 || metadata.protocol == 0)) {
            revert INVALID_METADATA();
        }

        if (proposalBid > maxBid) {
            // If the proposal bid is greater than the max bid this will revert
            revert EXCEEDING_MAX_BID();
        } else if (proposalBid == 0) {
            // If the proposal bid is 0, set it to the max bid
            proposalBid = maxBid;
        }

        // If the recipient address is the zero address this will revert
        if (recipientAddress == address(0)) revert RECIPIENT_ERROR(recipientId);

        // Get the recipient
        Recipient storage recipient = _recipients[recipientId];

        if (recipient.recipientStatus == Status.None) {
            // If the recipient status is 'None' add the recipient to the '_recipientIds' array
            _recipientIds.push(recipientId);
            emit Registered(recipientId, _data, _sender);
        } else {
            emit UpdatedRegistration(recipientId, _data, _sender);
        }

        // update the recipients data
        recipient.recipientAddress = recipientAddress;
        recipient.useRegistryAnchor = isUsingRegistryAnchor ? true : recipient.useRegistryAnchor;
        recipient.proposalBid = proposalBid;
        recipient.metadata = metadata;
        recipient.recipientStatus = Status.Pending;
    }

    /// @notice Select recipient for RFP allocation
    /// @dev '_sender' must be a pool manager to allocate.
    /// @param _data The data to be decoded
    /// @param _sender The sender of the allocation
    function _allocate(bytes memory _data, address _sender)
        internal
        virtual
        override
        onlyActivePool
        onlyPoolManager(_sender)
    {
        uint256 finalProposalBid;
        // Decode the '_data'
        (acceptedRecipientId, finalProposalBid) = abi.decode(_data, (address, uint256));

        Recipient storage recipient = _recipients[acceptedRecipientId];

        if (acceptedRecipientId == address(0) || recipient.recipientStatus != Status.Pending) {
            revert RECIPIENT_ERROR(acceptedRecipientId);
        }

        // Update status of acceptedRecipientId to accepted
        recipient.recipientStatus = Status.Accepted;

        if (recipient.proposalBid != finalProposalBid) {
            // If the proposal bid is not equal to the final proposal bid this will revert
            // This is to prevent the pool manager from decreasing the proposal bid
            // or recipient from front running and increasing the proposal bid
            revert INVALID();
        }

        _setPoolActive(false);

        IAllo.Pool memory pool = allo.getPool(poolId);

        // Emit event for the allocation
        emit Allocated(acceptedRecipientId, finalProposalBid, pool.token, _sender);
    }

    /// @notice Distribute the upcoming milestone to acceptedRecipientId.
    /// @dev '_sender' must be a pool manager to distribute.
    /// @param _sender The sender of the distribution
    function _distribute(address[] memory, bytes memory, address _sender)
        internal
        virtual
        override
        onlyInactivePool
        onlyPoolManager(_sender)
    {
        // check to make sure there is a pending milestone
        if (upcomingMilestone >= milestones.length) revert INVALID_MILESTONE();

        IAllo.Pool memory pool = allo.getPool(poolId);
        Milestone storage milestone = milestones[upcomingMilestone];
        Recipient memory recipient = _recipients[acceptedRecipientId];

        // Check if the milestone is pending
        if (milestone.milestoneStatus != Status.Pending) revert INVALID_MILESTONE();

        // Calculate the amount to be distributed for the milestone
        uint256 amount = (recipient.proposalBid * milestone.amountPercentage) / 1e18;

        // Get the pool, subtract the amount and transfer to the recipient
        poolAmount -= amount;
        _transferAmount(pool.token, recipient.recipientAddress, amount);

        // Set the milestone status to 'Accepted'
        milestone.milestoneStatus = Status.Accepted;

        // Increment the upcoming milestone
        upcomingMilestone++;

        // Emit events for the milestone and the distribution
        emit MilestoneStatusChanged(upcomingMilestone, Status.Accepted);
        emit Distributed(acceptedRecipientId, recipient.recipientAddress, amount, _sender);
    }

    /// @notice Check if sender is a profile owner or member.
    /// @param _anchor Anchor of the profile
    /// @param _sender The sender of the transaction
    /// @return 'true' if the sender is the owner or member of the profile, otherwise 'false'
    function _isProfileMember(address _anchor, address _sender) internal view returns (bool) {
        IRegistry.Profile memory profile = _registry.getProfileByAnchor(_anchor);
        return _registry.isOwnerOrMemberOfProfile(profile.id, _sender);
    }

    /// @notice Get the recipient.
    /// @param _recipientId ID of the recipient
    /// @return recipient Returns the recipient information
    function _getRecipient(address _recipientId) internal view returns (Recipient memory recipient) {
        recipient = _recipients[_recipientId];

        if (acceptedRecipientId != address(0) && acceptedRecipientId != _recipientId) {
            recipient.recipientStatus = recipient.recipientStatus > Status.None ? Status.Rejected : Status.None;
        }
    }

    /// @notice Increase max bid for RFP pool
    /// @param _maxBid The new max bid to be set
    function _increaseMaxBid(uint256 _maxBid) internal {
        // make sure the new max bid is greater than the current max bid
        if (_maxBid < maxBid) revert AMOUNT_TOO_LOW();

        maxBid = _maxBid;

        // emit the new max mid
        emit MaxBidIncreased(maxBid);
    }

    /// @notice Get the payout summary for the accepted recipient.
    /// @return Returns the payout summary for the accepted recipient
    function _getPayout(address _recipientId, bytes memory) internal view override returns (PayoutSummary memory) {
        Recipient memory recipient = _recipients[_recipientId];
        return PayoutSummary(recipient.recipientAddress, recipient.proposalBid);
    }

    /// @notice Checks if address is eligible allocator.
    /// @dev This is used to check if the allocator is a pool manager and able to allocate funds from the pool
    /// @param _allocator Address of the allocator
    /// @return 'true' if the allocator is a pool manager, otherwise false
    function _isValidAllocator(address _allocator) internal view override returns (bool) {
        return allo.isPoolManager(poolId, _allocator);
    }

    /// @notice This contract should be able to receive native token
    receive() external payable {}
}
