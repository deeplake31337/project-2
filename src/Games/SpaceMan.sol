// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

contract SpaceMan is Game {
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
                requestedAt: uint40(block.timestamp),
                vrfFee: vrfFee
            }),
            isAbove: isAbove,
            multiplier: multiplier
        });
    }

    function refund() external nonReentrant {
        _refund(games[msg.sender].params);
        _resetGame(msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override nonReentrant {
        address player = randomnessRequests[requestId];
        if (player != address(0)) {
            SpaceManGame storage game = games[player];
            if (_hasPool(game.params.currency)) {
                if (_checkVrfDeadline(game.params.requestedAt)) {
                    randomnessRequests[requestId] = address(0);
                    GameState memory gameState;
                    gameState.randomWord = randomWords[0];
                    gameState.payouts = new uint256[](game.params.numberOfRounds);
                    uint256[] memory results = new uint256[](game.params.numberOfRounds);
                    IGameManager.FeeData memory feeData = GAME_MANAGER.getFeeData(address(this));
                    Fee memory fee;
                    for (; gameState.playedRounds < game.params.numberOfRounds; gameState.playedRounds++) {
                        if (_gainOrLossHit(game.params.stopGain, game.params.stopLoss, gameState.netAmount)) {
                            break;
                        }
                        results[gameState.playedRounds] = gameState.randomWord % 1e7;
                        if (
                            (game.isAbove && results[gameState.playedRounds] >= getBoundary(getWinProb(game.multiplier))) ||
                            (!game.isAbove && results[gameState.playedRounds] < getWinProb(game.multiplier))
                        ) {
                            uint256 protocolFee = (game.multiplier * game.params.amountPerRound * feeData.protocolFeeBasis) / 1e8;
                            uint256 poolFee = (game.multiplier * game.params.amountPerRound * feeData.poolFeeBasis) / 1e8;
                            gameState.payouts[gameState.playedRounds] = ((game.multiplier * game.params.amountPerRound) / 1e4) - protocolFee - poolFee;
                            gameState.payout += gameState.payouts[gameState.playedRounds];
                            gameState.netAmount += int256(gameState.payouts[gameState.playedRounds] - game.params.amountPerRound);
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

    function getWinProb(uint256 multiplier) public pure returns (uint256 winProb) {
        winProb = 1e11 / multiplier;
    }

    function getBoundary(uint256 winProb) public pure returns (uint256 boundary) {
        if (winProb > 1e7) {
            revert("Invalid value");
        }
        boundary = 1e7 - winProb;
    }

    function _resetGame(address player) private {
        games[player] = SpaceManGame({
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
            isAbove: false,
            multiplier: 0
        });
    }

    function _checkMultiplier(uint256 multiplier) private pure {
        if (multiplier < 1e4 || multiplier > 1e7) {
            revert("Invalid multiplier");
        }
    }
}