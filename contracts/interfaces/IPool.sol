// SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

interface IPool {
    function mintPayout(address game, uint256 amount, address receiver) external;
    function mintProtocolFee(address game, uint256 amount, address protocolFeeAddress) external;
    function deposit(address receiver, uint256 amount) external;
    function withdraw(address receiver, uint256 amount) external;
    function burn(uint256 amount) external;
    function asset() external view returns (address);
}