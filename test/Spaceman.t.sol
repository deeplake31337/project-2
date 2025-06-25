// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import {Game} from "../src/Games/Game.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {GameManager} from "../src/GameManager.sol";

import {Deployer} from "./Deployer.sol";

contract Spaceman_Test is Deployer {
    function setUp() public {
        _deploy();
        vm.startPrank(user1);
        vm.stopPrank();
        vm.startPrank(owner);
        gameManager.setPoolConnection(
            address(spaceMan),
            address(mockERC20),
            address(pool)
        );
        vm.stopPrank();
    }

    function _play(bool isAbove) public {
        vm.deal(user1, 0.01 ether);
        vm.startPrank(user1);
        pool.approve(address(spaceMan), 2 ether);
        spaceMan.play{value: 0.01 ether}({
            numberOfRounds: 1,
            amountPerRound: 0.01 ether,
            currency: address(mockERC20),
            stopGain: 0,
            stopLoss: 0,
            isAbove: isAbove,
            multiplier: 10526
        });
        vm.stopPrank();
    }

    function test_play() public {
        _provideToken();
        _play({isAbove: true});

        (Game.GameParams memory params, bool isAbove, uint248 multiplier) = spaceMan.games(user1);

        assertEq(params.blockNumber, block.number);
        assertEq(params.numberOfRounds, 1);
        assertEq(params.amountPerRound, 0.01 ether);
        assertEq(params.currency, address(mockERC20));
        assertEq(params.stopGain, 0);
        assertEq(params.stopLoss, 0);
        assertEq(params.requestedAt, block.timestamp);
        //assertEq(params.vrfFee, 0.01 ether);
        assertTrue(isAbove);
        assertEq(multiplier, 10526);
    }
}