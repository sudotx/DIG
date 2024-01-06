// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IStrategy} from "src/interfaces/IStrategy.sol";
import {StealthStrategy} from "src/strategy/AllocationStrategy.sol";
import {Roles} from "src/governor/GovRoles.sol";
import {Metadata} from "src/libraries/Metadata.sol";

import {IAllo} from "src/interfaces/IAllo.sol";

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

contract Vault is ERC4626, Ownable, StealthStrategy {
    StrategyParams public s_strategy;

    address public constant ALLO = 0x1133eA7Af70876e64665ecD07C0A0476d09465a1; // allo proxy address
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
        StealthStrategy(ALLO, "StealthStrategy")
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

    // governor can mint any amount of gov tokens arbitrarily.
    function mint(address to, uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {
        _mint(to, amount);
    }

    // @dev Tracks assets owned by the vault plus assets in the strategy.
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + s_totalAssetsInStrategy;
    }

    // distribute to knights
    function _withdrawFromStrategy(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {
        s_totalAssetsInStrategy -= amount;

        // StealthStrategy.

        // withdraw from an allo pool

        // or set it so that

        // the allocation distribute can only be called from here..

        // address yieldStrategyAddress = address(s_strategy.implementation);

        emit StrategyWithdrawal(s_strategy.implementation, amount);
    }

    function createPoolWithCustomStrategy(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function distribute(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function fundPool(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function registerRecipient(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function recoverFunds(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function renounceRole(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function revokeRole(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function updateBaseFee(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function updatePercentFee(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}
    function updateRegistry(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}

    function removePoolManager(uint256 amount) external onlyCoreRole(Roles.GOVERNOR) {}

    // deposit from funders
    function _depositToStrategy(uint256 amount) external {
        s_totalAssetsInStrategy += amount;
        (uint256 value) = super.deposit(amount, address(1));
        assert(value == 1);

        // StealthStrategy.initialize

        // IAllo(address(0)).createPoolWithCustomStrategy()

        emit StrategyDeposit(s_strategy.implementation, amount);
    }

    // get assets in the associated pool.
    function _getTotalAssetsInStrategy() external view returns (uint256) {
        // get assets in an associated pool at a time.

        // get this from allocation startegy.
        return s_totalAssetsInStrategy;
    }

    // @dev just in case this contract receives ETH accidentally
    function gatherDust() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
