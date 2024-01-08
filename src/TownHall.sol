// this controls how guardians allocate funds to knights, how funds are allocated to users, how winners are decided
// governance is spread between guardians, initiative creators and normie users.

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes, IERC165} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vault} from "./vault/Vault.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Roles} from "./governor/GovRoles.sol";
import {Initiative} from "./Initiative.sol";

// play with governance tokens here!!

// forwards calls to allocation strategy to release funds.

// proposals made here from tally, then pushed along by guardians, then funded and assigned to knights via milestones.

contract TownHall is
    Vault,
    Governor,
    GovernorVotes,
    GovernorTimelockControl,
    GovernorSettings,
    GovernorCountingSimple,
    AccessControlEnumerable
{
    /// @notice Private storage variable for quorum (the minimum number of votes needed for a vote to pass).
    uint256 private _quorum;

    /// @notice Emitted when quorum is updated.
    event QuorumUpdated(uint256 oldQuorum, uint256 newQuorum);

    // these users are the ideators, think of cool ideas. pay a fee to add it to the list of initiatives
    // the initiative can either affect them
    address[] private InitiativeCreators;

    // these are the nft/token holders that vote to which intiative if funded by sending in some funds to the initiative
    // from thier balances on the platform, these funds are used to fund the general pool of the system

    // they can be anyone, any concerned party looking to deploy capital to a private or good that is relevant to them

    /*//////////////////////////////////////////////////////////////
                            PROPOSED ACTORS
    //////////////////////////////////////////////////////////////*/

    // they are selected by the guardians and community, as specialized individuals who can carry out a task
    // they are penalizeed for not meeting up to task expectation by being slashed from receiving streaming rewards
    struct Knight {
        address KnightAddress;
        bool isFlagged;
        Initiative.InitiativeStruct assignedInitiative;
    }

    mapping(uint256 => address) Knights;

    struct Voter {
        address VoterAddress;
        bool hasVoted;
    }

    mapping(uint256 => address) Voters;

    // theses are delegated users that can perform constant votes to the direction of the system.
    // they are selected by the community.
    struct Guardian {
        address GuardianAddress;
        bool hasVoted;
        bool isFlagged;
        bool isSlashed;
    }

    mapping(uint256 => address) Guardians;

    // ALLFATHER, GOD OF AESIR
    // multisig controlled by everyone, holding a governance NFT. used to assign and revoke guardian roles.
    address public ALLFATHER;

    constructor(
        address _timelock,
        address _token,
        uint256 initialVotingDelay,
        uint256 initialVotingPeriod,
        uint256 initialProposalThreshold,
        uint256 initialQuorum
    )
        Governor("My Governor")
        // votes will be via erc721, issued by the vault. when users deposit into the pool
        GovernorVotes(IVotes(_token))
        GovernorTimelockControl(TimelockController(payable(_timelock)))
        GovernorSettings(initialVotingDelay, initialVotingPeriod, initialProposalThreshold)
        Vault(_token, "My Governor Vault", "MGG", s_strategy)
    {
        _setQuorum(initialQuorum);
        _grantRole(Roles.GOVERNOR, msg.sender);

        _setRoleAdmin(Roles.GOVERNOR, Roles.GOVERNOR);
        _setRoleAdmin(Roles.GUARDIAN, Roles.GOVERNOR);
    }

    // function proposalVotes(uint256 proposalId)
    //     public
    //     view
    //     virtual
    //     returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
    // {
    //     // againstVotes are supporting the execution of Veto
    //     // againstVotes = _proposalVotes[proposalId].againstVotes;
    //     // no forVotes can be cast in the Veto module, keep 0 value
    //     forVotes = 0;
    //     // no abstainVotes can be cast in the Veto module, keep 0 value
    //     abstainVotes = 0;
    // }

    // function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    //     // ProposalVote storage proposalvote = _proposalVotes[proposalId];

    //     // return quorum(proposalSnapshot(proposalId)) <= proposalvote.againstVotes;
    // }

    /// ------------------------------------------------------------------------
    /// Quorum managment.
    /// ------------------------------------------------------------------------

    /// @notice The minimum number of votes needed for a vote to pass.
    function quorum(uint256 /* blockNumber*/ ) public view override returns (uint256) {
        return _quorum;
    }

    /**
     * @dev Internal setter for the proposal quorum.
     *
     * Emits a {QuorumUpdated} event.
     */
    function _setQuorum(uint256 newQuorum) internal {
        emit QuorumUpdated(_quorum, newQuorum);
        _quorum = newQuorum;
    }

    /// ------------------------------------------------------------------------
    /// Governor-only actions.
    /// ------------------------------------------------------------------------

    /// @notice Override of a GovernorSettings function, restrict .
    function setVotingDelay(uint256 newVotingDelay) public override {
        _setVotingDelay(newVotingDelay);
    }

    /// @notice Override of a GovernorSettings function, to restrict .
    function setVotingPeriod(uint256 newVotingPeriod) public override {
        _setVotingPeriod(newVotingPeriod);
    }

    /// @notice Override of a GovernorSettings.sol function, to restrict.
    function setProposalThreshold(uint256 newProposalThreshold) public override {
        _setProposalThreshold(newProposalThreshold);
    }

    /// @notice Adjust quorum, restricted .
    function setQuorum(uint256 newQuorum) public {
        _setQuorum(newQuorum);
    }

    /// ------------------------------------------------------------------------
    /// Guardian-only actions.
    /// ------------------------------------------------------------------------

    /// @notice Allow guardian to cancel a proposal in progress.
    function guardianCancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public returns (uint256) {
        return _cancel(targets, values, calldatas, descriptionHash);
    }

    /// ------------------------------------------------------------------------
    /// Overrides required by Solidity.
    /// ------------------------------------------------------------------------

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
        return super.proposalThreshold();
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockControl, AccessControlEnumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function slashAKnight(uint256 knightId) public {
        // slash an knight from getting any more payouts from the system
    }
    function slashAGuardian(uint256 guardianId) public {
        // slash a percievd to be malicious guardian
    }
    function getGuardian(uint256 guardianId) public view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function getKnight(uint256 knightId) public view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function assignKnighthood(address addyB) public view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }

    function assignGuardianhood(address addressA) public view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function assignVoterhood(address addy) public view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }

    function voteAgainstGuardian(uint256 guardianId, uint256 amount) public {
        // other guardians can vote against guardians percieved to be malicious
        // guardian will be releived of its role

        //! ensure guardian cannot send the role about
        //! roles are only issues by the AllFather
    }

    function voteAgainstKnight(uint256 knightId) public {
        // flag an anon percieved to be malicious
        // by guardian
    }

    function voteOnASelectedInitiative(uint256 initiativeId, uint256 voterId) public {
        // require(Voters[voterId]. == msg.sender, "just checking, you are refering to y");
        require(Voters[voterId] != address(0), "uh oh, not a voter here");
        // require role, or add modifier to prevent unauthorized users from voting

        // initiatives[initiativeId].CurrentFundsAllocated += 1;

        // providing the initiative details
        // holders of the voting nft can vote on this nft and provide funding
        // also users with specific roles can vote on a initiative as well
        // funds sent via this function are routed to the attacked pool and wait to be streamed to an individual that can do the work
    }
}
