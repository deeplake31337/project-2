// SPDX-License-Identifier: MIT

pragma solidity > 0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pool is ERC20, Ownable, ReentrancyGuard, Pausable {
    address public immutable GAME_MANAGER;
    address public immutable POOL_ROUTER;
    address public immutable asset;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _asset,
        address _gameManager,
        address _poolRouter
    ) ERC20(_name, _symbol) Ownable(_owner) {
        GAME_MANAGER = _gameManager;
        POOL_ROUTER = _poolRouter;
        asset = _asset;
    }

    function mintPayout(
        uint256 amount,
        address receiver
    ) external nonReentrant whenNotPaused {
        _onlyGameManager();
        super._mint(receiver, amount);
    }

    function mintProtocolFee(
        uint256 amount,
        address protocolFeeAddress
    ) external nonReentrant whenNotPaused {
        _onlyGameManager();
        super._mint(protocolFeeAddress, amount);
    }

    function deposit(address receiver, uint256 amount) public {
        _onlypoolRouter();
        super._mint(receiver, amount);
    }

    function withdraw(address receiver, uint256 amount) public {
        _onlypoolRouter();
        IERC20(asset).transfer(receiver, amount);
        super._burn(receiver, amount);
    }

    function mint( //for testing only
        address receiver,
        uint256 amount
    ) external onlyOwner {
        super._mint(receiver, amount);
    }

    function burn(uint256 amount) public {
        super._burn(msg.sender, amount);
    }

    function togglePaused() external onlyOwner {
        paused() ? _unpause() : _pause();
    }

    function _onlyGameManager() internal view {
        if (msg.sender != GAME_MANAGER) {
            revert("Not authorized");
        }
    }

    function _onlypoolRouter() internal view {
        if (msg.sender != POOL_ROUTER) {
            revert("Not authorized");
        }
    }
}