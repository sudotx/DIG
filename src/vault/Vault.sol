// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "@solmate/src/mixins/ERC4626.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import {ERC20} from "@solmate/src/tokens/ERC20.sol";
import {StealthStrategy} from "../strategy/AllocationStrategy.sol";

error Vault_CouldNotWithdrawFromStrategy(address sender, address asset, address yieldStrategyTarget, uint256 amount);
error Vault_CouldNotDepositToStrategy(address sender, address asset, address yieldStrategyTarget, uint256 amount);
error Vault_CouldNotGetTotalAssetsFromStrategy(address asset, address yieldStrategyTarget);

struct StrategyParams {
    IStrategy implementation;
    address target;
}

// this should take funds from the funders of a pool
// deposit into a pool, store them in the registery using registry magic
//

/// @notice Minimal ERC4626 tokenized Vault implementation.
/// @author Forked from Solmate ERC4626 (https://github.com/transmissions11/solmate/blob/main/src/mixins/ERC4626.sol)
contract Vault is ERC4626, Ownable, StealthStrategy {
    StrategyParams public s_strategy;
    uint256 public s_totalAssetsInStrategy;

    /*//////////////////////////////////////////////////////////////
                        EVENTS
    //////////////////////////////////////////////////////////////*/
    event StrategyDeposit(IStrategy strategy, uint256 amount);
    event StrategyWithdrawal(IStrategy strategy, uint256 amount);

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        StrategyParams memory strategy,
        address destinationVaultManager,
        address payable sourceVaultManager
    ) ERC4626(_asset, _name, _symbol) Ownable() StealthStrategy(address(0), "") {
        s_strategy = strategy;
        s_totalAssetsInStrategy = 0;
    }

    // @dev Tracks assets owned by the vault plus assets in the strategy.
    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + s_totalAssetsInStrategy;
    }

    /*//////////////////////////////////////////////////////////////
                        Internal Hooks Logic
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 /*shares*/ ) internal override after_updateTotalAssetsInStrategy {
        _withdrawFromStrategy(assets);
    }

    function afterDeposit(uint256 assets, uint256 /*shares*/ ) internal override after_updateTotalAssetsInStrategy {
        _depositToStrategy(assets);
    }

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

    // @note: If you use this function as is ensure you do not use the wrong destinationAddress.
    // Otherwise, "bye bye shares!"
    function sendSharesCrossChain(
        address destinationAddress,
        uint256 amount,
        uint64 destinationChainSelector,
        address destinationVaultManager
    ) external payable {
        // s_sourceVaultManager.sendShares(
        //     destinationAddress, amount, destinationChainSelector, destinationVaultManager, msg.sender
        // );
        _burn(msg.sender, amount);
    }

    function getFeeEsimateSendSharesCrossChain(
        address destinationAddress,
        uint256 amount,
        uint64 destinationChainSelector,
        address destinationVaultManager
    ) external returns (uint256) {
        // return s_sourceVaultManager.estimateFeeForSendShares(
        //     destinationAddress, amount, destinationChainSelector, destinationVaultManager
        // );
    }

    // @dev just in case this contract receives ETH accidentally
    function gatherDust() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
