
// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

interface IGameManager {

    struct FeeData {
        uint16 protocolFeeBasis;
        uint16 poolFeeBasis;
    }
    
    function setPoolConnection(address game, address currency, address pool) external;
    function removePoolConnection(address game, address currency) external;
    function timeForRefund() external view returns (uint40);
    function vrfFeeAddress() external view returns (address);
    function protocolFeeAddress() external view returns (address);
    function getGamePool(address game, address currency) external view returns (address pool);
    function getFeeData(address game) external view returns (FeeData memory);
    function maxNumberOfRounds() external view returns (uint16);
    function mintPayout(address currency, uint256 amount, address receiver) external;
    function mintProtocolFee(address currency, uint256 amount) external;
    function vrfParams() external view returns (
            address coordinator,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            uint16 minRequestConfirm,
            uint240 vrfFee,
            bytes32 keyHash
        );
}