// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2} from "../../src/VRFConsumerBaseV2.sol";
import {VRFCoordinatorV2Interface} from "../../src/interfaces/VRFCoordinatorV2Interface.sol";

contract VRFV2Coordirator is VRFCoordinatorV2Interface {
    uint96 public immutable BASE_FEE;
    uint96 public immutable GAS_PRICE_LINK;
    uint16 public immutable MAX_CONSUMERS = 100;

    error InvalidSubscription();
    error InsufficientBalance();
    error MustBeSubOwner(address owner);

    mapping(uint256 => uint64) public s_requestSubscription;
    mapping(uint256 => uint256[]) public s_requestRandomWords;
    mapping(uint256 => VRFConsumerBaseV2) public s_requests;

    uint256 public s_nextRequestId = 1;
    uint256 public s_nextCoordinatorId = 1;

    constructor(uint96 _baseFee, uint96 _gasPriceLink) {
        BASE_FEE = _baseFee;
        GAS_PRICE_LINK = _gasPriceLink;
    }

    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external override returns (uint256) {
        keyHash;
        minimumRequestConfirmations;
        callbackGasLimit;
        uint256 requestId = s_nextRequestId++;
        uint256[] memory randomWords = new uint256[](numWords);
        for(uint256 i = 0; i < numWords; i++) {
            randomWords[i] = uint256(keccak256(abi.encode(requestId, i)));
        }

        s_requestSubscription[requestId] = subId;
        s_requestRandomWords[requestId] = randomWords;
        s_requests[requestId] = VRFConsumerBaseV2(msg.sender);

        return requestId;
    }

    function fulfillRandomWords(uint256 requestId) external {
        require(s_requests[requestId] != VRFConsumerBaseV2(address(0)), "request not found");
        s_requests[requestId].rawFulfillRandomWords(
            requestId,
            s_requestRandomWords[requestId]
        );
    }

    function getRequestConfig() external pure override returns (uint16, uint32, bytes32[] memory) {
        revert("not implemented");
    }

    function createSubscription() external pure override returns (uint64) {
        return 1;
    }

    function getSubscription(uint64) external pure override returns (uint96, uint64, address, address[] memory) {
        revert("not implemented");
    }

    function requestSubscriptionOwnerTransfer(uint64, address) external pure override {
        revert("not implemented");
    }

    function acceptSubscriptionOwnerTransfer(uint64) external pure override {
        revert("not implemented");
    }

    function addConsumer(uint64, address) external pure override {
        revert("not implemented");
    }

    function removeConsumer(uint64, address) external pure override {
        revert("not implemented");
    }

    function cancelSubscription(uint64, address) external pure override {
        revert("not implemented");
    }

    function pendingRequestExists(uint64) external pure override returns (bool) {
        revert("not implemented");
    }
}