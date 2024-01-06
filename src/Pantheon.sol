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

// play with governance tokens here!!

// forwards calls to allocation strategy to release funds.

// proposals made here from tally, then pushed along by guardians, then funded and assigned to knights via milestones.

contract Pantheon is
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

    address[] private Voters;

    // theses are delegated users that can perform constant votes to the direction of the system.
    // they are selected by the community.

    // mini aesir
    address[] private Guardians;

    // they are selected by the guardians and community, as specialized individuals who can carry out a task
    // they are penalizeed for not meeting up to task expectation by being slashed from receiving streaming rewards
    address[] private Knights;

    // ALLFATHER, GOD OF AESIR
    // multisig controlled by everyone, holding a governance NFT. used to assign and revoke guardian roles.
    address public ALLFATHER;

    struct Initiative {
        // description of the initiative in as much detail as needed, this will be shown on the frontend.
        //! again using an array of bytes like this tends to get more expensive with more characters
        string Description;
        uint256 initiativeId;
        // initiativeCreator that thought of this
        address Creator;
        // representing amount of pool funds to be allocated to this initiative
        uint256 CurrentFundsAllocated;
        // guardians first have to clear this initiative for funding
        bool isClearedForFunding;
        // if funding goal is reached, then the funds can be streamed to a selected knight
        // if there is no selected knight at this time, funds remain in the pool for a set amount of time
        // other wise refunds are sent back to all concerned parties.
        bool isFundingComplete;
        // users who funded the initiative are added here, to decided how funds are used
        // they have some voting power to veto the course of the initative

        // guardians can vote, voters can vote, the creator of the initiative also has some funds allocated to it
        address[] Voters;
        // the knights are in charge of carrying out the initiative
        // they are vetted by the guardians and community at large
        // they are assumed to be skilled individuals, or bounty hunters
        // they are streamed part of the funds from the pool

        // if they default at any milestone, they can be slashed and removed as a knight from the platform if they get 3 strikes or majority decision
        address[] Knights;
    }

    mapping(uint256 => Initiative) private initiatives;

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

    // public view if an intiative has been fundede

    function initiativeFunded(uint256 initId, address account) public view returns (bool) {
        // return initiatives[initId];
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

    // this should house the main functionality for slashing, distributing tokens as well as
    // interacting with the main allo funds allocation

    Initiative initiative;

    function createAnInitiative() external {
        // users can create initiative
        // pay a fee to prevent spam
        // Initiative storage _initiative = initiative;

        // _initative.Description = "";
        // _initative.Creator = address(1);
        // _initative.CurrentFundsAlloacted = 1;
        // _initative.isClearedForFunding = false;
        // _initative.isFundingComplete = false;
        // _initative.Voters = [];

        // _initative = Initiiatve({
        //     Description: "",
        //     Creator: address(1),
        //     CurrentFundsAllocated: 1,
        //     isClearedForFunding: false,
        //     isFundingComplete: false,
        //     Voters: [address(0)],
        //     Knights: address[address(0)]
        // });
    }

    function voteOnASelectedInitiative() private {
        // providing the initiative details
        // holders of the voting nft can vote on this nft and provide funding
        // also users with specific roles can vote on a initiative as well
        // funds sent via this function are routed to the attacked pool and wait to be streamed to an individual that can do the work
    }

    function withdrawPayOut() private {
        // an EOA(anon) can withdraw a part of the total payout staked for it
        // it should not be able to withdraw all its stake
        // naturally should have 3 vesting schedules. 33, 33, 33 -> rest stays on the contract. goes back to protocol
        // between the 3 schedules, the anon will be sending up updates accoring to why they got the grant in the first place
        // edge case..anons will just aim to get the 1/3 of the payout..each payout could be much granular.
        // maybe a configurable % can be set due to some calculated risk appetite of the project

        // this logic will be refactored into a pattern that allows users to be streamed the funds to a contract
        // then this function allws them to claim from the funds set aside for them
    }

    function delegateFundsForAnInitiative() private {
        // this interacts with the allo contract to get the funds into this contract.abi
        // so some funds will be set aside for an initiative, which represent the project getting a grant
    }

    function slashAKnight() private {
        // slash an anon from getting any more payouts from the system
    }
    function slashAGuardian() private {
        // slash a percievd to be malicious guardian
    }
    function confidenceThreshold() private view {
        // threshold for confidence
    }
    function updateConfidenceThreshold() private {
        // owner can change this
    }
    function getGuardian() private view {
        // get details of a guardian
        // including the votes made, users slashed etc
    }
    function voteAgainstGuardian() private {
        // other guardians can vote against guardians percieved to be malicious
        // guardian will be releived of its role

        //! ensure guardian cannot send the role about
        //! roles are only issues by the AllFather
    }
    function slashAFlaggedAnon() private {
        // slash an anon account that has been flagged previously, from receiving any other grants from this contract
    }
    function flagAKnight() private {
        // flag an anon percieved to be malicious
        // by guardian
    }
    function distribute() private {
        // distribute funds to all whitelisted anons
        // based on varying schedules

        // can be called by the owner of the contract. which is the super admin
    }
}
