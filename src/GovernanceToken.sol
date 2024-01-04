// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Roles} from "./GovRoles.sol";

contract GuildToken is ERC20Burnable {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor() ERC20("MyAllo dot Gov", "GUILD") {}

    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyCoreRole(bytes32 role) {
        require(hasRole(role, msg.sender), "UNAUTHORIZED");
        _;
    }

    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].members[account];
    }

    /*///////////////////////////////////////////////////////////////
                        TRANSFERABILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice at deployment, tokens are not transferable (can only mint/burn).
    /// Governance can enable transfers with `enableTransfers()`.
    bool public transferable; // default = false

    /// @notice emitted when transfers are enabled.
    event TransfersEnabled(uint256 block, uint256 timestamp);

    /// @notice permanently enable token transfers.
    function enableTransfer() external onlyCoreRole(Roles.GOVERNOR) {
        transferable = true;
        emit TransfersEnabled(block.number, block.timestamp);
    }

    /// @dev prevent transfers if they are not globally enabled.
    /// mint and burn (transfers to and from address 0) are accepted.
    function _beforeTokenTransfer(address from, address to, uint256 /* amount*/ ) internal view override {
        require(transferable || from == address(0) || to == address(0), "GuildToken: transfers disabled");
    }

    /*///////////////////////////////////////////////////////////////
                        MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /// @notice mint new tokens to the target address
    function mint(address to, uint256 amount) external onlyCoreRole(Roles.GUILD_MINTER) {
        _mint(to, amount);
    }

    /*///////////////////////////////////////////////////////////////
                        INHERITANCE RECONCILIATION
    //////////////////////////////////////////////////////////////*/

    function _burn(address from, uint256 amount) internal virtual override(ERC20) {
        ERC20._burn(from, amount);
    }

    function transfer(address to, uint256 amount) public virtual override(ERC20) returns (bool) {
        return ERC20.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override(ERC20) returns (bool) {
        return ERC20.transferFrom(from, to, amount);
    }
}
