// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {StealthStrategy} from "../strategy/AllocationStrategy.sol";

import {Roles} from "../GovRoles.sol";

error Vault_CouldNotWithdrawFromStrategy(address sender, address asset, address yieldStrategyTarget, uint256 amount);
error Vault_CouldNotDepositToStrategy(address sender, address asset, address yieldStrategyTarget, uint256 amount);
error Vault_CouldNotGetTotalAssetsFromStrategy(address asset, address yieldStrategyTarget);

struct StrategyParams {
    IStrategy implementation;
    address target;
}

// this should take funds from the funders of a pool
// deposit into a pool, store them in the registery using registry magic

// the share token acts as the governance tokens, so users get a proportional share to what they deposit in
//

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Forked from Solmate ERC4626 (https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
contract Vault is ERC4626, Ownable, StealthStrategy {
    StrategyParams public s_strategy;

    address public constant ALLO = 0xB087535DB0df98fC4327136e897A5985E5Cfbd66; // allo implementation address
    uint256 public s_totalAssetsInStrategy;

    /*//////////////////////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////////////////////*/
    event StrategyDeposit(IStrategy strategy, uint256 amount);
    event StrategyWithdrawal(IStrategy strategy, uint256 amount);

    constructor(address _asset, string memory _name, string memory _symbol, StrategyParams memory strategy)
        ERC4626(IERC20(_asset))
        ERC20(_name, _symbol)
        Ownable()
        StealthStrategy(ALLO, "GovStrategy")
    {
        s_strategy = strategy;
        s_totalAssetsInStrategy = 0;
    }

    struct Data {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => Data) private _roles;

    modifier onlyCoreRole(bytes32 role) {
        require(checkRole(role, msg.sender), "UNAUTHORIZED");
        _;
    }

    function checkRole(bytes32 role, address account) public view virtual returns (bool) {
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
        require(transferable || from == address(0) || to == address(0), "GovernanceToken: transfers disabled");
    }

    /*///////////////////////////////////////////////////////////////
                        MINT / BURN
    //////////////////////////////////////////////////////////////*/

    /// @notice mint new tokens to the target address
    function mint(address to, uint256 amount) external onlyCoreRole(Roles.GUILD_MINTER) {
        _mint(to, amount);
    }

    // @dev Tracks assets owned by the vault plus assets in the strategy.
    function totalAssets() public view override returns (uint256) {
        // return asset.balanceOf(address(this)) + s_totalAssetsInStrategy;
    }

    /*//////////////////////////////////////////////////////////////
                        Internal Hooks Logic
    //////////////////////////////////////////////////////////////*/

    // function beforeWithdraw(uint256 assets, uint256 /*shares*/ ) internal override after_updateTotalAssetsInStrategy {
    //     _withdrawFromStrategy(assets);
    // }

    // function afterDeposit(uint256 assets, uint256 /*shares*/ ) internal override after_updateTotalAssetsInStrategy {
    //     _depositToStrategy(assets);
    // }

    /*//////////////////////////////////////////////////////////////
                        Yield Strategy Logic
    //////////////////////////////////////////////////////////////*/

    modifier after_updateTotalAssetsInStrategy() {
        _;
        s_totalAssetsInStrategy = _getTotalAssetsInStrategy();
    }

    // distribute to knights
    function _withdrawFromStrategy(uint256 amount) internal {
        // address yieldStrategyAddress = address(s_strategy.implementation);
        // bytes memory withdrawCalldata = abi.encodeWithSignature("withdraw(uint256)", amount);

        // (bool success,) = yieldStrategyAddress.delegatecall(withdrawCalldata);
        // if (!success) {
        //     revert Vault_CouldNotWithdrawFromStrategy(msg.sender, address(asset), s_strategy.target, amount);
        // }

        // emit StrategyWithdrawal(s_strategy.implementation, amount);
    }

    // deposit from funders
    function _depositToStrategy(uint256 amount) internal {
        // address yieldStrategyAddress = address(s_strategy.implementation);
        // bytes memory depositCalldata = abi.encodeWithSignature("deposit(uint256)", amount);

        // (bool success,) = yieldStrategyAddress.delegatecall(depositCalldata);
        // if (!success) {
        //     revert Vault_CouldNotDepositToStrategy(msg.sender, address(asset), s_strategy.target, amount);
        // }

        // emit StrategyDeposit(s_strategy.implementation, amount);
    }

    // get assets in the associated pool.
    function _getTotalAssetsInStrategy() internal returns (uint256) {
        // address yieldStrategyAddress = address(s_strategy.implementation);
        // bytes memory totalAssetsCalldata = abi.encodeWithSignature("totalAssets()");

        // (bool success, bytes memory retData) = yieldStrategyAddress.delegatecall(totalAssetsCalldata);
        // if (!success) {
        //     revert Vault_CouldNotGetTotalAssetsFromStrategy(address(asset), s_strategy.target);
        // }

        // return abi.decode(retData, (uint256));
        return 1;
    }

    // @dev just in case this contract receives ETH accidentally
    function gatherDust() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
