// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

contract SpaceMan is Game {

    uint256 private constant TOTAL_OUTCOMES = 10_000_000;

    struct SpaceManGame {
        GameParams params;
        bool isAbove;
        uint248 multiplier;
    }

    mapping(address player => SpaceManGame) public games;

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
        bool isAbove,
        uint248 multiplier
    ) external payable nonReentrant {
        _checkRoundData(numberOfRounds, amountPerRound);
        _checkNoOngoingRound(games[msg.sender].params.numberOfRounds);
        _checkStopGainAndLoss(stopGain, stopLoss);
        _checkMultiplier(multiplier);

        _getGamePool(currency);
        uint256 vrfFee = _requestRandomness();

        _chargePlayAmountAndVrfFee(currency, numberOfRounds, amountPerRound, vrfFee);
        games[msg.sender] = SpaceManGame({
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
            isAbove: isAbove,
            multiplier: multiplier
        });
    }

    function refund() external nonReentrant {
        _refund(games[msg.sender].params);
        _deleteGame(msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        address player = randomnessRequests[requestId];
        if (player != address(0)) {
            SpaceManGame storage game = games[player];
            if (_hasPool(game.params.currency)) {
                if (_checkVrfResponse(game.params.randomnessRequestedAt)) {
                    randomnessRequests[requestId] = address(0);

                    RunningGameState memory runningGameState;
                    runningGameState.payouts = new uint256[](game.params.numberOfRounds);
                    runningGameState.randomWord = randomWords[0];
                    uint256[] memory results = new uint256[](game.params.numberOfRounds);

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
                        results[runningGameState.playedRounds] = runningGameState.randomWord % TOTAL_OUTCOMES;
                        if (
                            (game.isAbove && results[runningGameState.playedRounds] >= getBoundary(getWinProbability(game.multiplier))) ||
                            (!game.isAbove && results[runningGameState.playedRounds] < getWinProbability(game.multiplier))
                        ) {
                            uint256 protocolFee = (game.multiplier * game.params.amountPerRound * feeSplit.protocolFeeBasis) / 1e8;
                            uint256 poolFee = (game.multiplier * game.params.amountPerRound * feeSplit.poolFeeBasis) / 1e8;

                            runningGameState.payouts[runningGameState.playedRounds] = ((game.multiplier * game.params.amountPerRound) / 10_000) - protocolFee - poolFee;
                            runningGameState.payout += runningGameState.payouts[runningGameState.playedRounds];
                            runningGameState.netAmount += int256(runningGameState.payouts[runningGameState.playedRounds] - game.params.amountPerRound);
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

    function getWinProbability(uint256 multiplier) public pure returns (uint256 winProbability) {
        winProbability = 100_000_000_000 / multiplier;
    }

    function getBoundary(uint256 winProbability) public pure returns (uint256 boundary) {
        if (winProbability > TOTAL_OUTCOMES) {
            revert("Invalid value");
        }
        boundary = TOTAL_OUTCOMES - winProbability;
    }

    function _deleteGame(address player) private {
        games[player] = SpaceManGame({
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
            isAbove: false,
            multiplier: 0
        });
    }

    function _checkMultiplier(uint256 multiplier) private pure {
        if (multiplier < 10_000 || multiplier > 10_000_000) {
            revert("Invalid multiplier");
        }
    }
}