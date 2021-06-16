// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "./BuyRecord.sol";
import "../lib/Address.sol";
import "../lib/Strings.sol";

pragma experimental ABIEncoderV2;

contract WinningRecord is AccessController {
    using SafeMath for uint256;

    struct NumberData {
        uint256 first_number;
        uint256 second_number;
        uint256 third_number;
        uint256 forth_number;
    }

    struct WinningHistory {
        uint256 period;
        NumberData number;
        uint256 bonusAmount;
        uint256 winningAmount;
        address winningAddress;
        uint256 winningGrade;
    }

    struct WinningDetail {
        uint256 period;
        NumberData number;
        uint256 bonusAmount;
        uint256 firstPrizeWinners;
        uint256 secondPrizeWinners;
        uint256 thirdPrizeWinners;
    }

    BuyRecord private _buyRecordContract;
    WinningHistory[] public winningHistories;
    //每一期的中奖记录
    mapping(uint256 => NumberData) winningInfo;

    WinningDetail[] public winningDetails;

    //期数=>中奖等级=>注数
    mapping(uint256 => mapping(uint256 => uint256)) winningAll;
    //每一期领奖人信息
    mapping(uint256 => address[]) receivePlayers;


    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _buyRecordContract = BuyRecord(getContractAddress("buyRecord"));
    }

    //存入中奖信息
    function depositWinningInfo(uint256 index,uint256 amount,uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,address winningAddress,uint256 winningAmount,uint256 winningGrade) public onlyElaLottery{
        winningHistories.push(WinningHistory(index,NumberData(first_number,second_number,third_number,forth_number),amount,winningAmount,winningAddress,winningGrade));
    }

    //获取中奖记录
    function getWinningRecord(uint256 offset, uint256 pageCount) public view returns(string memory, uint256) {
        string memory result;
        require(offset >= 0 && offset <= winningHistories.length, "WinningRecord: invalid offset");

        for (uint i = offset; i < winningHistories.length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            result = Strings.concat(result, _convertWinningHistoryToString(winningHistories[i], i));
        }
        return (result, winningHistories.length);
    }

    //存入中奖详情
    function depositWinningDetails(uint256 index,uint256 amount,uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,uint256 firstPrizeWinners,uint256 secondPrizeWinners,uint256 thirdPrizeWinners) public onlyElaLottery{
        winningDetails.push(WinningDetail(index,NumberData(first_number,second_number,third_number,forth_number),amount,firstPrizeWinners,secondPrizeWinners,thirdPrizeWinners));
    }
    //查询中奖详情记录
    function getWinningDetails(uint256 offset, uint256 pageCount) public view returns(string memory, uint256){
        string memory result;
        require(offset >= 0 && offset <= winningDetails.length, "WinningRecord: invalid offset");

        for (uint i = offset; i < winningDetails.length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            result = Strings.concat(result, _convertWinningDetailToString(winningDetails[i], i));
        }
        return (result, winningDetails.length);
    }

    function setWinningInfo(uint256 index,uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number) public onlyElaLottery{
        winningInfo[index] = NumberData(first_number,second_number,third_number,forth_number);
    }

    //获取上一期的中奖号码
    function getWinningNum(uint256 index) public view returns(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number) {
        if(index > 1) {
            return(winningInfo[index.sub(1)].first_number,winningInfo[index.sub(1)].second_number,winningInfo[index.sub(1)].third_number,winningInfo[index.sub(1)].forth_number);
        }else {
            return(0,0,0,0);
        }
    }

    function _convertWinningDetailToString(WinningDetail memory winningDetail, uint256 index) private pure returns (string memory){
        string memory winningDetailString;
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(index));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.period));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.number.first_number));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.number.second_number));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.number.third_number));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.number.forth_number));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.bonusAmount));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.firstPrizeWinners));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.secondPrizeWinners));
        winningDetailString = Strings.concat(winningDetailString, ",");
        winningDetailString = Strings.concat(winningDetailString, Strings.parseInt(winningDetail.thirdPrizeWinners));
        return winningDetailString;
    }

    function _convertWinningHistoryToString(WinningHistory memory winningHistory, uint256 index) private pure returns (string memory){
        string memory winningHistoryString;
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(index));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.period));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.number.first_number));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.number.second_number));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.number.third_number));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.number.forth_number));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.bonusAmount));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.winningAmount));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseAddress(winningHistory.winningAddress));
        winningHistoryString = Strings.concat(winningHistoryString, ",");
        winningHistoryString = Strings.concat(winningHistoryString, Strings.parseInt(winningHistory.winningGrade));
        return winningHistoryString;
    }
    //存入每一期的中奖信息
    function setWinningAll(uint256 index,uint256 grade,uint256 noteNumber) public onlyElaLottery{
        winningAll[index][grade] = winningAll[index][grade].add(noteNumber);
    }
    //获取每一期每一中奖等级的注数
    function getWinningAll(uint256 index,uint256 grade) public view returns(uint256) {
        return winningAll[index][grade];
    }
    //存每一期的领奖人
    function setReceivePlayers(uint256 index,address account) public onlyElaLottery{
            receivePlayers[index].push(account);
    }

    //判断每一期的领奖人是否领奖
    function exits(uint256 index,address account) public view returns(bool) {
        for(uint i=0;i<receivePlayers[index].length;i++) {
            if(receivePlayers[index][i] == account) {
                return true;
            }
        }
        return false;
    }

    function setLotteryAddress(address contractAddress) public onlyAdmin{
        addLottery(contractAddress);
    }
}
