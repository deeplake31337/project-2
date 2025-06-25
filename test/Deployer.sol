// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockERC20} from "../test/mock/MockErc20.sol";
import {VRFV2Coordirator} from "../test/mock/VRFV2Coordirator.sol";
import {GameManager} from "../src/GameManager.sol";
import {Pool} from "../src/Pool.sol";
import {PoolRouter} from "../src/PoolRouter.sol";

import {Game} from "../src/Games/Game.sol";
import {SpaceMan} from "../src/Games/SpaceMan.sol";
import {RockPaperScissors} from "../src/Games/RockPaperScissors.sol";
import {OddOrEven} from "../src/Games/OddOrEven.sol";

import {Test} from "../lib/forge-std/src/Test.sol";

abstract contract Deployer is Test {
    address public user1 = address(11);
    address public user2 = address(12);
    address public user3 = address(13);
    address public user4 = address(14);
    address public owner = address(69);
    address public feeRecipient = address(520);
    address public vrfFeeAddress = address(111);

    address public protocolFeeAddress = address(888);

    MockERC20 internal mockERC20;

    VRFV2Coordirator internal vrfV2Coordirator;

    GameManager internal gameManager;
    Pool internal pool;
    PoolRouter public poolRouter;

    SpaceMan internal spaceMan;
    RockPaperScissors internal rockPaperScissors;
    OddOrEven internal oddOrEven;
    address token;

    modifier asPrankedUser(address user) {
        vm.startPrank(user);
        _;
        vm.stopPrank();
    }

    function _deploy() internal {
        vm.warp(37373737);
        vm.roll(111111);

        vrfV2Coordirator = new VRFV2Coordirator(0, 0);

        mockERC20 = new MockERC20("Test token", "Test");

        gameManager = new GameManager({
            _owner: owner,
            _vrfFeeAddress: vrfFeeAddress,
            _protocolFeeAddress: protocolFeeAddress,
            _vrfCoordinator: address(vrfV2Coordirator),
            _keyHash: bytes32(0),
            _subscriptionId: 0
        });

        poolRouter = new PoolRouter({
            _owner: owner,
            _feeRecipient: feeRecipient
        });

        pool = new Pool({
            _name: "Pool token",
            _symbol: "Ptk",
            _owner: owner,
            _asset: address(mockERC20),
            _gameManager: address(gameManager),
            _poolRouter: address(poolRouter)
        });
        
        spaceMan = new SpaceMan({
            _gameManager: address(gameManager),
            _vrfCoordinator: address(vrfV2Coordirator),
            _owner: owner
        });

        rockPaperScissors = new RockPaperScissors({
            _gameManager: address(gameManager),
            _vrfCoordinator: address(vrfV2Coordirator),
            _owner: owner
        });

        oddOrEven = new OddOrEven({
            _gameManager: address(gameManager),
            _vrfCoordinator: address(vrfV2Coordirator),
            _owner: owner
        });

        vm.startPrank(owner);

        gameManager.setFeeData(address(spaceMan), 100, 100);
        gameManager.setFeeData(address(rockPaperScissors), 100, 100);
        gameManager.setFeeData(address(oddOrEven), 100, 100);

        /*gameManager.setPoolConnection(
            address(spaceMan),
            address(mockERC20),
            address(pool)
        );

        gameManager.setPoolConnection(
            address(rockPaperScissors),
            address(mockERC20),
            address(pool)
        );

        gameManager.setPoolConnection(
            address(oddOrEven),
            address(mockERC20),
            address(pool)
        );*/

        poolRouter.addPool(address(pool));
        poolRouter.setDepositLimit(address(pool), 0.01 ether, 30 ether, 30 ether);

        vm.stopPrank();

        token = address(mockERC20);

    }

    function _provideToken() internal {
        _provideToken(owner, 20 ether);
        _provideToken(user1, 5 ether);
        _provideToken(user2, 5 ether);
    }

    function _provideToken(address user, uint256 amount) internal {
        mockERC20.mint(user, amount);
        vm.startPrank(user);
        mockERC20.approve(address(poolRouter), amount);
        poolRouter.deposit(address(mockERC20), amount);
        vm.warp(block.timestamp + 3 days);
        poolRouter.finalizeDeposit(user);

        vm.stopPrank();
    }
}