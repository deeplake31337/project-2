// SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

contract Flipper is Game {
    struct FlipperGame {
        GameParams params;
        bool isOdd;
    }

    mapping(address player => FlipperGame) public games;

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

        games[msg.sender] = FlipperGame({
            params: GameParams({
                blockNumber: uint40(block.number),
                numberOfRounds: numberOfRounds,
                amountPerRound: amountPerRound,
                currency: currency,
                stopGain: stopGain,
                stopLoss: stopLoss,
                randomnessRequestedAt: uint40(block.timestamp),
                vrfFee: vrfFee
            }),
            isOdd: isOdd
        });

    }

    function refund() external nonReentrant {
        _refund(games[msg.sender].params);
        _deleteGame(msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        address player = randomnessRequests[requestId];

        if (player != address(0)) {
            FlipperGame storage game = games[player];
            if (_hasPool(game.params.currency)) {
                if (_checkVrfResponse(game.params.randomnessRequestedAt)) {
                    randomnessRequests[requestId] = address(0);

                    RunningGameState memory runningGameState;

                    runningGameState.randomWord = randomWords[0];
                    runningGameState.payouts = new uint256[](game.params.numberOfRounds);
                    bool[] memory results = new bool[](game.params.numberOfRounds);

                    IGameManager.FeeSplit memory feeSplit = GAME_MANAGER.getFeeSplit(
                        address(this)
                    );
                    Fee memory fee;

                    for (; runningGameState.playedRounds < game.params.numberOfRounds; runningGameState.playedRounds++) {
                        if (
                            _stopGainOrLossHit(
                                game.params.stopGain,
                                game.params.stopLoss,
                                runningGameState.netAmount
                            )
                        ) {
                            break;
                        }

                        bool isOdd = runningGameState.randomWord % 2 != 0;
                        results[runningGameState.playedRounds] = isOdd;

                        if (game.isOdd == isOdd) {
                            uint256 protocolFee = (game.params.amountPerRound * 2 * feeSplit.protocolFeeBasis) / 10_000;
                            uint256 poolFee = (game.params.amountPerRound * 2 * feeSplit.poolFeeBasis) / 10_000;
                            runningGameState.netAmount += int256(game.params.amountPerRound * 2 - protocolFee - poolFee - game.params.amountPerRound
                            );
                            runningGameState.payouts[runningGameState.playedRounds] = game.params.amountPerRound * 2 - protocolFee - poolFee;
                            runningGameState.payout += runningGameState.payouts[runningGameState.playedRounds];
                            fee.protocolFee += protocolFee;
                            fee.poolFee += poolFee;
                        } else {
                            runningGameState.netAmount -= int256(game.params.amountPerRound);
                        }
                        runningGameState.randomWord = uint256(keccak256(abi.encode(runningGameState.randomWord)));
                    }
                    _handlePayout(
                        player,
                        game.params,
                        runningGameState.playedRounds,
                        runningGameState.payout,
                        fee.protocolFee
                    );
                    _transferVrfFee(game.params.vrfFee);
                    _deleteGame(player);
                }
            }
        }
    }

    function _deleteGame(address player) private {
        games[player] = FlipperGame({
            params: GameParams({
                blockNumber: 0,
                numberOfRounds: 0,
                amountPerRound: 0,
                currency: address(0),
                stopGain: 0,
                stopLoss: 0,
                randomnessRequestedAt: 0,
                vrfFee: 0
            }),
            isOdd: false
        });
    }
}
