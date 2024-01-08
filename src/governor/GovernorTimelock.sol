// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.13;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovTimelockController is TimelockController {
    constructor(uint256 _minDelay) TimelockController(_minDelay, new address[](0), new address[](0), address(0)) {}

    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal override {}

    /// @dev override of OZ access/AccessControl.sol, role management is handled in TownHall.
    function _grantRole(bytes32 role, address account) internal override {}

    /// @dev override of OZ access/AccessControl.sol, role management is handled in TownHall.
    function _revokeRole(bytes32 role, address account) internal override {}
}
