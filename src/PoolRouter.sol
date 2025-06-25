// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IPool} from "./interfaces/IPool.sol";

contract PoolRouter is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct Deposit {
        address gamePool;
        uint256 amount;
        uint256 initializedAt;
    }

    struct Withdraw {
        address gamePool;
        uint256 amount;
        uint256 initializedAt;
    }

    struct DepositLimit {
        uint256 minDepositAmount;
        uint256 maxDepositAmount;
        uint256 maxBalance;
    }

    uint256 timelockDelay = 3 days;
    
    address public immutable feeRecipient;

    mapping(address token => address Pool) public Pools;

    mapping(address Pool => DepositLimit) public depositLimit;

    mapping(address account => Deposit) public deposits;

    mapping(address account => Withdraw) public withdraws;

    mapping(address Pool => uint256 amount) public pendingDeposits;

    constructor(
        address _owner,
        address _feeRecipient
    ) Ownable(_owner) {
        feeRecipient = _feeRecipient;
    }

    function addPool(address pool) external onlyOwner {
        address token = IPool(pool).asset();
        if (Pools[token] != address(0)) {
            revert("Token already have");
        }
        Pools[token] = pool;
    }

    function setDepositLimit(
        address gamePool,
        uint256 minDepositAmount,
        uint256 maxDepositAmount,
        uint256 maxBalance
    ) external onlyOwner {
        if (minDepositAmount > maxDepositAmount) {
            revert("Min deposit amount too high.");
        }

        if (maxBalance < maxDepositAmount) {
            revert("Max deposit amount too high.");
        }

        depositLimit[gamePool] = DepositLimit(minDepositAmount, maxDepositAmount, maxBalance);
    }

    function deposit(address token, uint256 amount) external payable nonReentrant whenNotPaused {
        address gamePool = _getPoolOrRevert(token);

        uint256 depositFee = (amount * 50) / 10e4;
        amount -= depositFee;

        _validateDepositAmount(gamePool, amount);

        if (deposits[msg.sender].amount != 0) {
            revert("Deposit is ongoing.");
        }

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        IERC20(token).transferFrom(msg.sender, feeRecipient, depositFee);

        deposits[msg.sender] = Deposit(
            gamePool,
            amount,
            block.timestamp
        );
        pendingDeposits[gamePool] += amount;
    }

    function finalizeDeposit(address depositor) external nonReentrant whenNotPaused {
        uint256 amount = deposits[depositor].amount;
        if (amount == 0) {
            revert("No deposit to finish");
        }

        uint256 initializedAt = deposits[depositor].initializedAt;
        _validateTimelockIsOver(initializedAt);

        address gamePool = deposits[depositor].gamePool;
        address token = IPool(gamePool).asset();

        deposits[depositor] = Deposit(address(0), 0, 0);
        pendingDeposits[gamePool] -= amount;

        _deposit(token, gamePool, amount, depositor);
    }

    function withdraw(address token, uint256 amount) external payable nonReentrant {
        address gamePool = _getPoolOrRevert(token);

        if (withdraws[msg.sender].amount != 0) {
            revert("Withdraw is ongoing.");
        }

        IERC20(gamePool).transferFrom(msg.sender, address(this), amount);

        withdraws[msg.sender] = Withdraw(
            gamePool,
            amount,
            block.timestamp
        );
    }

    function finalizeWithdraw(address receiver) external nonReentrant whenNotPaused {
        uint256 amount = withdraws[receiver].amount;
        if (amount == 0) {
            revert("No ongoing withdraw");
        }

        uint256 initializedAt = withdraws[receiver].initializedAt;
        _validateTimelockIsOver(initializedAt);

        address gamePool = withdraws[receiver].gamePool;
        withdraws[receiver] = Withdraw(address(0), 0, 0);
        IPool(gamePool).withdraw(receiver, amount);
    }

    function _getPoolOrRevert(address token) private view returns (address pool) {
        pool = Pools[token];
        if (pool == address(0)) {
            revert("Pool does not exist");
        }
    }

    function _deposit(
        address token,
        address pool,
        uint256 amount,
        address depositor
    ) private {
        IERC20(token).transfer(pool, amount);
        IPool(pool).deposit(depositor, amount);
    }

    function _validateDepositAmount(address pool, uint256 amount) private view {
        if (amount == 0 || amount < depositLimit[pool].minDepositAmount) {
            revert("Deposit amount too low");
        }

        if (amount > depositLimit[pool].maxDepositAmount)
        {
            revert("Deposit amount too high");
        }

        /*if (IERC20(IPool(pool).asset()).balanceOf(pool) + amount + pendingDeposits[pool] > depositLimit[pool].maxBalance)
        {
            revert("Deposit amount too high");
        }*/
    }

    function _validateTimelockIsOver(uint256 initializedAt) private view {
        if (block.timestamp < initializedAt + timelockDelay) {
            revert("Timelock is not over");
        }
    }
}