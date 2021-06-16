// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/SafeERC20.sol";
import "../token/IERC20.sol";

interface IStakedBonusData {

    function deposit(address account, uint256 amount) external;

    function withdraw(address account, uint256 amount) external;

    function getAmount() external view returns (uint256);

    function withDrawAll(address targetAccount, uint256 amount) external;
}

contract StakedBonusData is AccessController, IStakedBonusData {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private _bcoinContract;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _bcoinContract = IERC20(getContractAddress("bcoin"));
    }

    function deposit(address account,uint256 amount) public override onlyStakedBonus {
        if(amount != 0){
            require(_bcoinContract.transferFrom(account, address(this), amount), "StakedBonusData: transfer failed");
        }
    }

    function withdraw(address account, uint256 amount) public override onlyStakedBonus {
        if(amount != 0){
            require(_bcoinContract.transfer(account, amount), "StakedBonusData: transfer failed");
        }
    }

    function getAmount() public override view returns (uint256){
        return _bcoinContract.balanceOf(address(this));
    }

    function withDrawAll(address targetAccount, uint256 amount) public override onlyAdmin {
        uint256 balance = _bcoinContract.balanceOf(address(this));
        uint256 withdrawAmount = balance > amount ? amount: balance;
        require(_bcoinContract.transfer(targetAccount, withdrawAmount), "StakedBonusData: transfer failed");
    }

}
