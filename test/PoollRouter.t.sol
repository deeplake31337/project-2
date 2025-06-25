// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {PoolRouter} from "../src/PoolRouter.sol";
import {Deployer} from "./Deployer.sol";

contract PoolRouterTest is Deployer {
    function setUp() public {
        _deploy();
    }

    function initalizeDeposit() public {
        mockERC20.mint(user1, 2 ether);
        vm.startPrank(user1);
        mockERC20.approve(address(feeRecipient), 1 ether);
        mockERC20.approve(address(poolRouter), 1 ether);
        poolRouter.deposit(address(mockERC20), 0.02 ether);
        vm.stopPrank();
    }

    function finalizeDeposit() public {
        initalizeDeposit();

        vm.warp(block.timestamp + 3 days);

        vm.prank(user1);
        poolRouter.finalizeDeposit(user1);
    }

    function testDeposit() public {
        initalizeDeposit();
    }

    function testFinalizeDeposit() public {
        initalizeDeposit();

        vm.warp(block.timestamp + 3 days);

        vm.prank(user1);
        poolRouter.finalizeDeposit(user1);
    }

    function initalizeWithdraw() public {
        vm.startPrank(owner);
        pool.mint(user1, 1 ether);
        vm.stopPrank();
        vm.startPrank(user1);
        pool.approve(address(poolRouter), 1 ether);
        poolRouter.withdraw(address(mockERC20), 0.1 ether);
        vm.stopPrank();
    }

    function testWithdraw() public {
        initalizeWithdraw();
    }

    function testFinalizeWithdraw() public {
        mockERC20.mint(address(pool), 0.1 ether);
        initalizeWithdraw();

        vm.warp(block.timestamp + 3 days);

        vm.prank(user1);
        poolRouter.finalizeWithdraw(user1);
    }
}