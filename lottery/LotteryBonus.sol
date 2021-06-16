// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../token/IERC20.sol";


contract LotteryBonus is AccessController{
    using SafeMath for uint256;
    mapping(address => uint256) bonusPool;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
    }

    function deposit(address token,address account, uint256 amount) public onlyElaLottery{
        require(IERC20(token).transferFrom(account, address(this), amount), "lotteryBonus: transfer failed");
        bonusPool[token] = bonusPool[token].add(amount);
    }

    function withdraw(address token, address account, uint256 amount) public onlyElaLottery{
        require(amount <= bonusPool[token], "lotteryBonus: Insufficient storage balance");
        require(IERC20(token).transfer(account, amount), "lockupData: transfer failed");
        bonusPool[token] = bonusPool[token].sub(amount);
    }

    function getAmount(address token) public view  returns (uint256){
        return bonusPool[token];
    }

    function setLotteryAddress(address contractAddress) public onlyAdmin{
        addLottery(contractAddress);
    }
}
