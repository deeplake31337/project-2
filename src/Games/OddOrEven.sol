// SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

contract OddOrEven is Game {
    struct OddOrEvenGame {
        GameParams params;
        bool isOdd;
    }

    mapping(address player => OddOrEvenGame) public games;

    constructor(
        address _gameManager,
        address _vrfCoordinator,
        address _owner
    ) Game(_gameManager, _vrfCoordinator, _owner) {}

    function play(
        uint16 numberOfRounds,
        uint256 amountPerRound,
        address currency,
        int256 stopGain,
        int256 stopLoss,
        bool isOdd
    ) external payable nonReentrant {
        _checkRoundData(numberOfRounds, amountPerRound);
        _checkNoOngoingRound(games[msg.sender].params.numberOfRounds);
        _checkStopGainAndLoss(stopGain, stopLoss);
        _getGamePool(currency);
        uint256 vrfFee = _requestRandomness();
        _chargePlayAmountAndVrfFee(currency, numberOfRounds, amountPerRound, vrfFee);
        games[msg.sender] = OddOrEvenGame({
            params: GameParams({
                blockNumber: uint40(block.number),
                numberOfRounds: numberOfRounds,
                amountPerRound: amountPerRound,
                currency: currency,
                stopGain: stopGain,
                stopLoss: stopLoss,
                requestedAt: uint40(block.timestamp),
                vrfFee: vrfFee
            }),
            isOdd: isOdd
        });

    }

    function refund() external nonReentrant {
        _refund(games[msg.sender].params);
        _resetGame(msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        address player = randomnessRequests[requestId];

        if (player != address(0)) {
            OddOrEvenGame storage game = games[player];
            if (_hasPool(game.params.currency)) {
                if (_checkVrfDeadline(game.params.requestedAt)) {
                    randomnessRequests[requestId] = address(0);
                    GameState memory gameState;
                    gameState.randomWord = randomWords[0];
                    gameState.payouts = new uint256[](game.params.numberOfRounds);
                    bool[] memory results = new bool[](game.params.numberOfRounds);
                    IGameManager.FeeData memory feeData = GAME_MANAGER.getFeeData(address(this));
                    Fee memory fee;
                    for (; gameState.playedRounds < game.params.numberOfRounds; gameState.playedRounds++) {
                        if (_gainOrLossHit(game.params.stopGain, game.params.stopLoss, gameState.netAmount)) {
                            break;
                        }
                        bool isOdd = gameState.randomWord % 2 != 0;
                        results[gameState.playedRounds] = isOdd;
                        if (game.isOdd == isOdd) {
                            uint256 protocolFee = (game.params.amountPerRound * 2 * feeData.protocolFeeBasis) / 1e4;
                            uint256 poolFee = (game.params.amountPerRound * 2 * feeData.poolFeeBasis) / 1e4;
                            gameState.netAmount += int256(game.params.amountPerRound * 2 - protocolFee - poolFee - game.params.amountPerRound);
                            gameState.payouts[gameState.playedRounds] = game.params.amountPerRound * 2 - protocolFee - poolFee;
                            gameState.payout += gameState.payouts[gameState.playedRounds];
                            fee.protocolFee += protocolFee;
                            fee.poolFee += poolFee;
                        } else {
                            gameState.netAmount -= int256(game.params.amountPerRound);
                        }
                        gameState.randomWord = uint256(keccak256(abi.encode(gameState.randomWord)));
                    }
                    _handlePayout(player, game.params, gameState.playedRounds, gameState.payout, fee.protocolFee);
                    _transferVrfFee(game.params.vrfFee);
                    _resetGame(player);
                }
            }
        }
    }

    function _resetGame(address player) private {
        games[player] = OddOrEvenGame({
            params: GameParams({
                blockNumber: 0,
                numberOfRounds: 0,
                amountPerRound: 0,
                currency: address(0),
                stopGain: 0,
                stopLoss: 0,
                requestedAt: 0,
                vrfFee: 0
            }),
            isOdd: false
        });
    }
}
