// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/SafeERC20.sol";
import "../token/IERC20.sol";
import {ITokenPairData} from "../auction/TokenPairData.sol";

interface IBonusData {

    function depositUSDT(address token, address account, uint256 amount) external;

    function withdrawUSDT(address token, address account, uint256 amount) external;

    function getAmountUSDT(address token) external view returns (uint256);
}

contract BonusData is AccessController, IBonusData {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ITokenPairData private _tokenPairDataContract;
    address private _bcoinAddress;
    IERC20 private _contractUSDT;

    mapping(address => uint256) private _revenueUSDT;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _tokenPairDataContract = ITokenPairData(getContractAddress("tokenPairData"));
        _bcoinAddress = getContractAddress("bcoin");
        _contractUSDT = IERC20(getContractAddress("husd"));
    }

    function depositUSDT(address token, address account,uint256 amount) public override whenNotPaused {
        require(_tokenPairDataContract.isHToken(token) || token == _bcoinAddress, "BonusData: invalid token");
        if(amount != 0){
            require(_contractUSDT.transferFrom(account, address(this), amount), "BonusData: transfer failed");
            _revenueUSDT[token] = _revenueUSDT[token].add(amount);
        }
    }

    function withdrawUSDT(address token, address account, uint256 amount) public override onlyBonus {
        require(amount <= _revenueUSDT[token], "BonusData: Insufficient storage balance");
        if(amount != 0){
            _revenueUSDT[token] = _revenueUSDT[token].sub(amount);
            require(_contractUSDT.transfer(account, amount), "BonusData: transfer failed");
        }
    }

    function getAmountUSDT(address token) public override view returns (uint256){
        return _revenueUSDT[token];
    }


}
