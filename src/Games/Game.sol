// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {VRFCoordinatorV2Interface} from "../interfaces/VRFCoordinatorV2Interface.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";
import {IPool} from "../interfaces/IPool.sol";

import {VRFConsumerBaseV2} from "../VRFConsumerBaseV2.sol";

abstract contract Game is ReentrancyGuard, VRFConsumerBaseV2, Ownable {
    struct GameParams {
        uint40 blockNumber;
        uint40 requestedAt;
        uint16 numberOfRounds;
        address currency;
        uint256 amountPerRound;
        int256 stopGain;
        int256 stopLoss;
        uint256 vrfFee;
    }

    struct Fee {
        uint256 protocolFee;
        uint256 poolFee;
    }

    struct GameState {
        uint256 playedRounds;
        uint256 randomWord;
        int256 netAmount;
        uint256 payout;
        uint256[] payouts;
    }

    IGameManager public immutable GAME_MANAGER;

    mapping(uint256 requestId => address requester) public randomnessRequests;

    constructor(
        address _gameManager,
        address _vrfCoordinator,
        address _owner
    ) VRFConsumerBaseV2(_vrfCoordinator) Ownable(_owner) {
        GAME_MANAGER = IGameManager(_gameManager);

        (address coordinator, , , , , ) = GAME_MANAGER.vrfParams();
        if (coordinator != _vrfCoordinator) {
            revert("Wrong vrf coordinator");
        }
    }
    function _transferPlayAmountToPool(address currency, uint256 amount) internal {
        address gamePool = _getGamePool(currency);

        IERC20(currency).transfer(gamePool, amount);
    }

    function _getGamePool(address currency) internal view returns (address gamePool) {
        gamePool = GAME_MANAGER.getGamePool(address(this), currency);
        if (gamePool == address(0)) {
            revert("Game do not have pool");
        }
    }

    function _chargePlayAmountAndVrfFee(
        address currency,
        uint256 numberOfRounds,
        uint256 amountPerRound,
        uint256 vrfFee
    ) internal {
        /*if (msg.value != vrfFee) {
            revert("Incorrect fee charged");
        }*/
        vrfFee;
        address gamePool = _getGamePool(currency);
        IERC20(gamePool).transferFrom(msg.sender, address(this), amountPerRound * numberOfRounds);
        IPool(gamePool).burn(amountPerRound * numberOfRounds);
    }

    function _requestRandomness() internal returns (uint256 fee) {
        (
            address coordinator,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            uint16 minRequestConfirm,
            uint240 vrfFee,
            bytes32 keyHash
        ) = GAME_MANAGER.vrfParams();

        uint256 requestId = VRFCoordinatorV2Interface(coordinator).requestRandomWords({
            keyHash: keyHash,
            subId: subscriptionId,
            minimumRequestConfirmations: minRequestConfirm,
            callbackGasLimit: callbackGasLimit,
            numWords: uint32(1)
        });

        randomnessRequests[requestId] = msg.sender;
        fee = vrfFee;
    }

    function _handlePayout(
        address player,
        GameParams storage params,
        uint256 playedRounds,
        uint256 payout,
        uint256 protocolFee
    ) internal {
        payout += params.amountPerRound * (params.numberOfRounds - playedRounds);
        _transferPlayAmountToPool(params.currency, params.amountPerRound * params.numberOfRounds);
        if (payout > 0) {
            GAME_MANAGER.mintPayout(params.currency, payout, player);
        }
        if (protocolFee > 0) {
            GAME_MANAGER.mintProtocolFee(params.currency, protocolFee);
        }
    }

    function _transferVrfFee(uint256 vrfFee) internal {
        if (vrfFee > 0) {
            (bool value, ) = GAME_MANAGER.vrfFeeAddress().call{value: vrfFee}("");
            require(value,"");
        }
    }

    function _refund(GameParams storage params) internal {
        if (params.numberOfRounds == 0) {
            revert("No round found");
        }

        if (params.requestedAt + GAME_MANAGER.timeForRefund() > block.timestamp) {
            revert("Too early to refund");
        }

        address currency = params.currency;
        uint256 totalPlayAmount = params.amountPerRound * params.numberOfRounds;
        IERC20(currency).transfer(msg.sender, totalPlayAmount);

        if (params.vrfFee > 0) {
            (msg.sender).call{value: params.vrfFee};
        }
    }

    function _checkStopGainAndLoss(int256 stopGain, int256 stopLoss) internal pure {
        if (stopGain < 0 || stopLoss > 0) {
            revert("Invalid stop");
        }
    }

    function _checkRoundData(
        uint256 numberOfRounds,
        uint256 amountPerRound
    ) internal view {
        if (numberOfRounds == 0) {
            revert("Zero number of round");
        }

        if (numberOfRounds > GAME_MANAGER.maxNumberOfRounds()) {
            revert("Too many round");
        }

        if (amountPerRound == 0) {
            revert("Zero amount per round");
        }
    }

    function _checkNoOngoingRound(uint256 numberOfRounds) internal pure {
        if (numberOfRounds > 0) {
            revert("Round is ongoing");
        }
    }

    function _gainOrLossHit(
        int256 stopGain,
        int256 stopLoss,
        int256 netAmount
    ) internal pure returns (bool isHit) {
        isHit = (stopGain != 0 && netAmount >= stopGain) || (stopLoss != 0 && netAmount <= stopLoss);
    }

    function _checkVrfDeadline(uint40 requestedAt) internal view returns (bool executable) {
        executable = (requestedAt - 5 minutes + GAME_MANAGER.timeForRefund() > block.timestamp);
    }

    function _hasPool(address currency) internal view returns (bool hasPool) {
        hasPool = GAME_MANAGER.getGamePool(address(this), currency) != address(0);
    }
}