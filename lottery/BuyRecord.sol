// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;


import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";
import "../lib/Strings.sol";
pragma experimental ABIEncoderV2;

contract BuyRecord is AccessController{
    using SafeMath for uint256;

    struct NumberData {
        uint256 first_number;
        uint256 second_number;
        uint256 third_number;
        uint256 forth_number;
    }

    struct BetInfo {
        NumberData number;
        uint256 noteNumber;
    }

    //兑换记录
    mapping(uint256 => address[])  convertRecord;
    //奖金池记录
    mapping(uint256 => uint256) bonusRecord;

    //购买信息
    mapping(uint256 => mapping(address => BetInfo[]))  buyInfo;
    //每一期的购买人地址信息 期数=》地址
    mapping(uint256 => address[]) lotteryPlayers;
    //期数-> 号->注数
    mapping(uint256 => mapping(uint256 => uint256)) fourToNote;
    mapping(uint256 => mapping(uint256 => uint256)) threeToNote;
    mapping(uint256 => mapping(uint256 => uint256)) twoToNote;
    //购买人信息
    mapping(uint256 => mapping(uint256 => mapping(address => uint256))) playersInfo;
    //每一期的总注数
    mapping(uint256 => uint256) notes;

    struct LotteryInfo {
        NumberData number;
        uint256 noteNumber;
        uint256 period;
        bool _isDraw;
        bool _isWinning;
        uint256 winningGrade;
        uint256 winningAmount;
    }
    //购买历史
    mapping(address => LotteryInfo[])  buyHistory;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
    }

    //存入购买信息
    function depositBuyInfo(address account,uint256 index, uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,uint256 noteNumber,bool _isDraw,bool _isWinning,uint256 grade,uint256 winningAmount) public onlyElaLottery{
        mapping(address => BetInfo[]) storage info = buyInfo[index];
        info[account].push(BetInfo(NumberData(first_number,second_number,third_number,forth_number),noteNumber));
        buyHistory[account].push(LotteryInfo(NumberData(first_number,second_number,third_number,forth_number),noteNumber,index,_isDraw,_isWinning,grade,winningAmount));
    }

    //查询我的购买历史
    function getBuyHistory(uint256 offset, uint256 pageCount,address account) public view returns(string memory, uint256) {
        string memory result;
        require(offset >= 0 && offset <= buyHistory[account].length, "BuyRecord: invalid offset");

        for (uint i = offset; i < buyHistory[account].length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            result = Strings.concat(result, _convertLotteryInfoToString(buyHistory[account][i], i));
        }
        return (result, buyHistory[account].length);
    }

    //查询我本期购买彩票信息
    function getBuyInfo(uint256 index,address account) public view returns(BetInfo[] memory) {
        return buyInfo[index][account];
    }

    //设置兑换记录
    function setConvertRecord(uint256 index,address account) public onlyElaLottery{
        bool exit = false;
        if(convertRecord[index].length !=0) {
            for(uint i=0;i<convertRecord[index].length;i++) {
                if(convertRecord[index][i] == account) {
                    exit = true;
                }
            }
        }
        if(!exit) {
            convertRecord[index].push(account);
        }
    }

    //查询是否兑换过
    function getSetConvertRecord(uint256 index,address account) public view returns(bool) {
        for(uint i=0;i<convertRecord[index].length;i++) {
            if(convertRecord[index][i] == account) {
                return true;
            }
        }
        return false;
    }

    //设置某一期的奖金
    function setBonusRecord(uint256 period,uint256 amount) public onlyElaLottery{
        bonusRecord[period] = amount;
    }

    //查询某一期的中奖信息
    function getBonusRecord(uint256 index) public view returns(uint256) {
        return bonusRecord[index];
    }

    //将每一期的购买人信息进行保存
    function setLotteryPlayers(uint256 index,address account) public onlyElaLottery{
        bool exit = false;
        if(lotteryPlayers[index].length !=0) {
            for(uint i=0;i<lotteryPlayers[index].length;i++) {
                if(lotteryPlayers[index][i] == account) {
                    exit = true;
                }
            }
        }
        if(!exit) {
            lotteryPlayers[index].push(account);
        }
    }

    function _convertLotteryInfoToString(LotteryInfo memory lotteryInfo, uint256 index) private pure returns (string memory){
        string memory lotteryInfoString;
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(index));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.period));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.number.first_number));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.number.second_number));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.number.third_number));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.number.forth_number));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.noteNumber));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseBoolean(lotteryInfo._isDraw));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseBoolean(lotteryInfo._isWinning));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.winningGrade));
        lotteryInfoString = Strings.concat(lotteryInfoString, ",");
        lotteryInfoString = Strings.concat(lotteryInfoString, Strings.parseInt(lotteryInfo.winningAmount));
        return lotteryInfoString;
    }
    //存入四位号码号码注数
    function setFourToNote(uint256 index,uint256 number,uint256 note) public onlyElaLottery{
        fourToNote[index][number] = fourToNote[index][number].add(note);
    }
    //取出四位号码的总注数
    function getFourToNote(uint256 index,uint256 number) public view returns(uint256) {
        return fourToNote[index][number];
    }
    //存入三位号码总注数
    function setThreeToNote(uint256 index,uint256 number,uint256 note) public onlyElaLottery {
        threeToNote[index][number] = threeToNote[index][number].add(note);
    }
    //取出三位号码的总注数
    function getThreeToNote(uint256 index,uint256 number) public view returns(uint256) {
        return threeToNote[index][number];
    }
    //存入二位位号码总注数
    function setTwoToNote(uint256 index,uint256 number,uint256 note) public onlyElaLottery{
        twoToNote[index][number] = twoToNote[index][number].add(note);
    }
    //取出二位号码的总注数
    function getTwoToNote(uint256 index,uint256 number) public view returns(uint256) {
        return twoToNote[index][number];
    }
    //存入购买人信息
    function setPlayersInfo(uint256 index,uint256 number,address account,uint256 note) public onlyElaLottery{
        playersInfo[index][number][account] = playersInfo[index][number][account].add(note);
    }
    //取出购买人购买号码注数
    function getPlayersInfo(uint256 index,uint256 number,address account) public view returns(uint256) {
        return playersInfo[index][number][account];
    }

    function setNotes(uint256 index,uint256 note) public onlyElaLottery{
        notes[index] = notes[index].add(note);
    }
    function getNotes(uint256 index) public view returns(uint256) {
        return notes[index];
    }

    function setLotteryAddress(address contractAddress) public onlyAdmin{
        addLottery(contractAddress);
    }
}
