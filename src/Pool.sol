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
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {Vault} from "./vault/Vault.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Roles} from "./GovRoles.sol";

contract MyGovernor is
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
        Vault(ERC20(_token), "My Governor Vault", "MGG", s_strategy)
    {
        _setQuorum(initialQuorum);
        _grantRole(Roles.GOVERNOR, msg.sender);

        _setRoleAdmin(Roles.GOVERNOR, Roles.GOVERNOR);
        _setRoleAdmin(Roles.GUARDIAN, Roles.GOVERNOR);
        _setRoleAdmin(Roles.GUILD_MINTER, Roles.GOVERNOR);
        _setRoleAdmin(Roles.TIMELOCK_PROPOSER, Roles.GOVERNOR);
        _setRoleAdmin(Roles.TIMELOCK_EXECUTOR, Roles.GOVERNOR);
        _setRoleAdmin(Roles.TIMELOCK_CANCELLER, Roles.GOVERNOR);
    }

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
}
