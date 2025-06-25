// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IPool} from "./interfaces/IPool.sol";

contract GameManager is Ownable {
    uint40 public timeForRefund = 10 minutes;

    uint16 public maxNumberOfRounds = 10;

    struct VrfParams {
        address coordinator;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        uint16 minRequestConfirm;
        uint240 vrfFee;
        bytes32 keyHash;
    }

    struct FeeData {
        uint16 protocolFeeBasis;
        uint16 poolFeeBasis;
    }

    VrfParams public vrfParams;

    address public vrfFeeAddress;

    address public protocolFeeAddress;

    mapping(address game => mapping(address currency => address pool)) private gamePool;

    mapping(address game => FeeData) private feeData;

    constructor(
        address _owner,
        address _vrfFeeAddress,
        address _protocolFeeAddress,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    ) Ownable(_owner) {

        vrfFeeAddress = _vrfFeeAddress;
        protocolFeeAddress = _protocolFeeAddress;

        VrfParams memory _vrfParams = VrfParams({
            coordinator: _vrfCoordinator,
            subscriptionId: _subscriptionId,
            callbackGasLimit: 25 * 10e5,
            minRequestConfirm: 3,
            vrfFee: 0.0003 ether,
            keyHash: _keyHash
        });
        _setVrfParams(_vrfParams);
    }

    function setPoolConnection(
        address game,
        address currency,
        address pool
    ) external onlyOwner {
        address poolCurrency = IPool(pool).asset();

        if (currency != poolCurrency) {
            revert("Currency mismatch");
        }
        gamePool[game][currency] = pool;
    }

    function removePoolConnection(address game, address currency) external onlyOwner {
        gamePool[game][currency] = address(0);
    }

    function settimeForRefund(uint40 _timeForRefund) external onlyOwner {
        if (_timeForRefund < 10 minutes) {
            revert("Time required for refund is too short");
        }

        if (_timeForRefund > 1 days) {
            revert("Time required for refund is too long");
        }
        timeForRefund = _timeForRefund;

    }

    function setMaxNumberOfRounds(uint16 _maxNumberOfRounds) external onlyOwner {
        maxNumberOfRounds = _maxNumberOfRounds;
    }

    function setVrfParams(VrfParams memory _vrfParams) external onlyOwner {
        _setVrfParams(_vrfParams);
    }

    function setVrfFeeAddress(address _vrfFeeAddress) external onlyOwner {
        vrfFeeAddress = _vrfFeeAddress;
    }

    function setProtocolFeeAddress(address _protocolFeeAddress) external onlyOwner {
        protocolFeeAddress = _protocolFeeAddress;
    }

    function setFeeData(
        address _game,
        uint16 _protocolFeeBasis,
        uint16 _poolFeeBasis
    ) external onlyOwner {
        feeData[_game] = FeeData({
            protocolFeeBasis: _protocolFeeBasis,
            poolFeeBasis: _poolFeeBasis
        });
    }

    function mintPayout(address currency, uint256 amount, address receiver) external {
        address pool = gamePool[msg.sender][currency];
        if (pool == address(0)) {
            revert("No pool found");
        }

        IPool(pool).mintPayout(msg.sender, amount, receiver);
    }

    function mintProtocolFee(address currency, uint256 amount) external {
        address pool = gamePool[msg.sender][currency];
        if (pool == address(0)) {
            revert("No pool found");
        }

        IPool(pool).mintProtocolFee(msg.sender, amount, protocolFeeAddress);
    }

    function getGamePool(address game, address currency) external view returns (address pool) {
        pool = gamePool[game][currency];
    }


    function getFeeData(address game) external view returns (FeeData memory) {
        return feeData[game];
    }

    function _setVrfParams(VrfParams memory _vrfParams) internal {
        vrfParams.callbackGasLimit = _vrfParams.callbackGasLimit;
        vrfParams.minRequestConfirm = _vrfParams.minRequestConfirm;
        vrfParams.vrfFee = _vrfParams.vrfFee;
        vrfParams.keyHash = _vrfParams.keyHash;
        vrfParams.coordinator = _vrfParams.coordinator;
        vrfParams.subscriptionId = _vrfParams.subscriptionId;
    }
}