// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../token/IERC20.sol";
import "./StakedLockupData.sol";
import "./StakedBonusData.sol";
import "./MdexPairConfig.sol";
import "./StakedSavingData.sol";

interface IStakedBonus {

    function lockup(address lpToken,uint256 amount) external returns (bool);

    function unlock(address lpToken, uint256 amount) external returns(bool);

    function receiveBonus(address lpToken) external returns(bool);

    function getAccountRevenue(address lpToken,address account) external view returns (uint256);

    function deposit(uint256 miningAmount) external returns(bool);
}

contract StakedBonus is AccessController, IStakedBonus {
    using SafeMath for uint256;

    struct RevenueRecord {
        address owner;
        uint256 period;
        uint256 amount;
    }
    address[] public lpTokenList;

    mapping(address => bool) public lpTokenFlag;

    //lpToken => period
    mapping(address => uint256) public periodNum;
    //lpToken => pledge;
    mapping(address => uint256) public totalPledge;
    //lpToken => revenue;
    mapping(address => uint256) public totalRevenue;

    //lpToken => period => totalPledge;
    mapping(address => mapping(uint256 => uint256)) public periodTotalPledge;
    //lpToken => period => income;
    mapping(address => mapping(uint256 => uint256)) public periodRevenue;

    //lpToken => account => period;
    mapping(address => mapping(address => uint256)) public accountCompPeriod;
    //lpToken => account => RevenueRecord
    mapping(address => mapping(address => RevenueRecord[])) public accountRevenueRecord;
    //lpToken => account => Revenue
    mapping(address => mapping(address => uint256)) public accountRevenue;
    //lpToken => account => period => alreadyRevenue
    mapping(address => mapping(address => mapping(uint256 => uint256))) public accountPeriodAlreadyRevenue;

    IStakedLockupData private _stakedLockupData;
    IStakedBonusData private _stakedBonusData;
    IMdexPairConfig private _mdexPairConfig;
    IStakedSavingData private _stakedSavingData;

    event Received(address indexed lpToken, address indexed account, uint256 period, uint256 amount);

    event Staked(address indexed lpToken, address indexed account, uint256 amount);

    event Withdraw(address indexed lpToken, address indexed account, uint256 amount);


    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _stakedLockupData = IStakedLockupData(getContractAddress("stakedLockupData"));
        _stakedBonusData = IStakedBonusData(getContractAddress("stakedBonusData"));
        _mdexPairConfig = IMdexPairConfig(getContractAddress("mdexPairConfig"));
        _stakedSavingData = IStakedSavingData(getContractAddress("stakedSavingData"));
    }

    function lockup(address lpToken,uint256 amount) external override whenNotPaused returns (bool) {
        require(_mdexPairConfig.checkLpToken(lpToken), "StakedBonus: lpToken check fail");
        uint256 period = periodNum[lpToken];
        _computeRevenueBeforePeriod(lpToken,period);
        _stakedLockupData.deposit(lpToken, msg.sender, amount);
        periodNum[lpToken] = period.add(1);
        totalPledge[lpToken] = totalPledge[lpToken].add(amount);
        periodTotalPledge[lpToken][periodNum[lpToken]] = totalPledge[lpToken];
        //添加lpToken
        if(!lpTokenFlag[lpToken]){
            lpTokenFlag[lpToken] = true;
            lpTokenList.push(lpToken);
        }
        emit Staked(lpToken, msg.sender, amount);
        return true;
    }

    function unlock(address lpToken, uint256 amount) public override whenNotPaused returns(bool) {
        require(_mdexPairConfig.checkLpToken(lpToken), "StakedBonus: lpToken check fail");
        uint256 period = periodNum[lpToken];
        _computeRevenueBeforePeriod(lpToken,period);
        periodNum[lpToken] = period.add(1);
        totalPledge[lpToken] = totalPledge[lpToken].sub(amount);
        periodTotalPledge[lpToken][periodNum[lpToken]] = totalPledge[lpToken];
        _receiveBonus(lpToken);
        _stakedLockupData.withdraw(lpToken, msg.sender, amount);
        emit Withdraw(lpToken, msg.sender, amount);
        return true;
    }

    function receiveBonus(address lpToken) public override whenNotPaused returns(bool){
        uint256 period = periodNum[lpToken];
        //获取之前质押的lpToken
        uint256 lockupAmount = _stakedLockupData.getAmount(lpToken,msg.sender);
        if(lockupAmount != 0){
            //计算之前应领取奖励
            accountRevenue[lpToken][msg.sender] = accountRevenue[lpToken][msg.sender].add(_getAccountRevenue(lpToken,msg.sender,lockupAmount,period));
            //讲已计算当前期数进行记录
            accountPeriodAlreadyRevenue[lpToken][msg.sender][period] = periodRevenue[lpToken][period];
            //更新当前期数
            accountCompPeriod[lpToken][msg.sender] = period;
        }
        //获取当前奖励
        _receiveBonus(lpToken);
        return true;
    }

    function deposit(uint256 miningAmount) public override onlyOfferMain returns(bool) {
        require(miningAmount != 0, "StakedBonus: miningAmount can not be zero ");
        uint256 totalBonus;
        for(uint256 i = 0; i < lpTokenList.length; i++){
            address lpToken = lpTokenList[i];
            if(totalPledge[lpToken]!=0){
                uint256 revenue = _mdexPairConfig.getLpTokenRevenue(lpToken,miningAmount);
                totalBonus = totalBonus.add(revenue);
                totalRevenue[lpToken] = totalRevenue[lpToken].add(revenue);
                periodRevenue[lpToken][periodNum[lpToken]] = periodRevenue[lpToken][periodNum[lpToken]].add(revenue);
            }
        }
        _stakedBonusData.deposit(msg.sender,totalBonus);
        _stakedSavingData.deposit(msg.sender,miningAmount.sub(totalBonus));
        return true;
    }

    function getAccountRevenue(address lpToken,address account) public view override returns (uint256){
        //获取之前质押的lpToken
        uint256 lockupAmount = _stakedLockupData.getAmount(lpToken,account);
        if(lockupAmount != 0){
            //计算之前应领取奖励
            return accountRevenue[lpToken][account].add(_getAccountRevenue(lpToken, account, lockupAmount, periodNum[lpToken]));
        }else{
            return accountRevenue[lpToken][account];
        }
    }

    function _receiveBonus(address lpToken) private{
        if(accountRevenue[lpToken][msg.sender] != 0){
            _stakedBonusData.withdraw(msg.sender,accountRevenue[lpToken][msg.sender]);
            accountRevenueRecord[lpToken][msg.sender].push(RevenueRecord(msg.sender,periodNum[lpToken], accountRevenue[lpToken][msg.sender]));
            emit Received(lpToken, msg.sender, periodNum[lpToken], accountRevenue[lpToken][msg.sender]);
            totalRevenue[lpToken] = totalRevenue[lpToken].sub(accountRevenue[lpToken][msg.sender]);
            accountRevenue[lpToken][msg.sender] = 0;
        }
    }

    function _computeRevenueBeforePeriod(address lpToken,uint256 period) private{
        //获取之前质押的lpToken
        uint256 lockupAmount = _stakedLockupData.getAmount(lpToken,msg.sender);
        if(lockupAmount != 0){
            //计算之前应领取奖励
            accountRevenue[lpToken][msg.sender] = accountRevenue[lpToken][msg.sender].add(_getAccountRevenue(lpToken,msg.sender,lockupAmount,period));
        }
        //将计算期数更新
        accountCompPeriod[lpToken][msg.sender] = period.add(1);
    }

    function _getAccountRevenue(address lpToken, address account, uint256 lockupAmount,uint256 period) private view returns (uint256){
        uint256 amount;
        for(uint256 i = accountCompPeriod[lpToken][account];i <= period ; i = i.add(1)){
            amount = amount.add(lockupAmount.mul(periodRevenue[lpToken][i].sub(accountPeriodAlreadyRevenue[lpToken][account][i]))
                        .div(periodTotalPledge[lpToken][i]));
        }
        return amount;
    }
}
