// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Game} from "../src/Games/Game.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {GameManager} from "../src/GameManager.sol";

import {Deployer} from "./Deployer.sol";

contract RockPaperScissors_Test is Deployer {
    function setUp() public {
        _deploy();
        vm.startPrank(user1);
        vm.stopPrank();
        vm.startPrank(owner);
        gameManager.setPoolConnection(
            address(rockPaperScissors),
            address(mockERC20),
            address(pool)
        );
        vm.stopPrank();
    }

    function _play() private {
        vm.deal(user1, 0.01 ether);
        vm.startPrank(user1);
        pool.approve(address(rockPaperScissors), 10 ether);
        rockPaperScissors.play{value: 0.01 ether}({
            numberOfRounds: 1,
            amountPerRound: 0.01 ether,
            currency: address(mockERC20),
            stopGain: 0,
            stopLoss: 0,
            numberType: 1
        });
        vm.stopPrank();
    }

    function test_play() public {
        _provideToken();
        _play();

        (Game.GameParams memory params, ) = rockPaperScissors.games(user1);

        assertEq(params.blockNumber, block.number);
        assertEq(params.numberOfRounds, 1);
        assertEq(params.amountPerRound, 0.01 ether);
        assertEq(params.currency, address(mockERC20));
        assertEq(params.stopGain, 0);
        assertEq(params.stopLoss, 0);
        assertEq(params.requestedAt, block.timestamp);
        //assertEq(params.numberType, 1);
    }
}