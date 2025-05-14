// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Game} from "./Game.sol";
import {IGameManager} from "../interfaces/IGameManager.sol";

contract Lottery is Game {
    uint256 public currentRound;

    struct LotteryGame {
        uint256 roundPlay;
        uint256 numberChoosen;
        bool claimed;
    }

    constructor(
        address _gameManager,
        address _vrfCoordinator,
        address _owner
    ) Game(_gameManager, _vrfCoordinator, _owner) {}
}