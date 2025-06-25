// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

//@note:
// kéo: chia 3 dư 0
// búa: chia 3 dư 1
// bao: chia 3 dư 2

contract RockPaperScissors is Game {
    struct RockPaperScissorsGame {
        GameParams params;
        uint256 numberType;
    }

    mapping(address player => RockPaperScissorsGame) public games;

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
        uint256 numberType
    ) external payable nonReentrant {
        _checkRoundData(numberOfRounds, amountPerRound);
        _checkNoOngoingRound(games[msg.sender].params.numberOfRounds);
        _checkStopGainAndLoss(stopGain, stopLoss);
        _getGamePool(currency);
        uint256 vrfFee = _requestRandomness();
        _chargePlayAmountAndVrfFee(currency, numberOfRounds, amountPerRound, vrfFee);
        games[msg.sender] = RockPaperScissorsGame({
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
            numberType: numberType
        });
    }

    function refund() external nonReentrant {
        _refund(games[msg.sender].params);
        _resetGame(msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        address player = randomnessRequests[requestId];

        if (player != address(0)) {
            RockPaperScissorsGame storage game = games[player];
            if (_hasPool(game.params.currency)) {
                if (_checkVrfDeadline(game.params.requestedAt)) {
                    randomnessRequests[requestId] = address(0);
                    GameState memory gameState;
                    gameState.randomWord = randomWords[0];
                    gameState.payouts = new uint256[](game.params.numberOfRounds);
                    int256[] memory results = new int256[](game.params.numberOfRounds);
                    IGameManager.FeeData memory feeData = GAME_MANAGER.getFeeData(address(this));
                    Fee memory fee;
                    for (; gameState.playedRounds < game.params.numberOfRounds; gameState.playedRounds++) {
                        if (_gainOrLossHit(game.params.stopGain, game.params.stopLoss, gameState.netAmount)) {
                            break;
                        }       
                        int256 resultType = int256(gameState.randomWord - game.numberType) % 3;
                        results[gameState.playedRounds] = resultType;
                        if (resultType == 2) {
                            uint256 protocolFee = (game.params.amountPerRound * 2 * feeData.poolFeeBasis) / 1e4;
                            uint256 poolFee = (game.params.amountPerRound * 2 * feeData.poolFeeBasis) / 1e4;
                            gameState.netAmount += int256(game.params.amountPerRound * 2 - protocolFee - poolFee - game.params.amountPerRound);
                            gameState.payouts[gameState.playedRounds] = game.params.amountPerRound * 2 - protocolFee - poolFee;
                            gameState.payout += gameState.payouts[gameState.playedRounds];
                            fee.protocolFee += protocolFee;
                            fee.poolFee += poolFee;
                        } else if (resultType == 0) {
                            uint256 protocolFee = (game.params.amountPerRound * feeData.protocolFeeBasis) / 1e4;
                            uint256 poolFee = (game.params.amountPerRound * feeData.poolFeeBasis) / 1e4;
                            gameState.netAmount += int256(game.params.amountPerRound - protocolFee - poolFee - game.params.amountPerRound);
                            gameState.payouts[gameState.playedRounds] = game.params.amountPerRound - protocolFee - poolFee;
                            gameState.payout += gameState.payouts[gameState.playedRounds];
                            fee.protocolFee += protocolFee;
                            fee.poolFee += poolFee;
                        }
                        else {
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
        games[player] = RockPaperScissorsGame({
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
            numberType: 0
        });
    }
}