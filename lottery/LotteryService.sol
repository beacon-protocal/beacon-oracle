// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "./WinningRecord.sol";
import "./ElaLottery.sol";
import "./BuyRecord.sol";

interface ILotteryService {
    // buy lottery
    function buyLottery(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,uint256 noteNumber,address account) external;

    function convertLottery(address first_number,address second_number,address third_number,address forth_number,address fifth_number,address account) external;

    //draw prize
    function draw(address account) external;

    //judge whether winning
    function judgeWinning(address account) external view returns(bool);

    //receive prize
    function receivePrice(address account) external;

    //get current period
    function getPeriod() external view returns(uint256);

    //get current block
    function getBlockNum() external view returns(uint256);

    //get draw prize block
    function getDrawBlockNum() external view returns(uint256);

    //get lottery price
    function getLotteryPrice() external view returns(uint256);

    //buy history
    function getBuyHistory(uint256 offset, uint256 pageCount,address account) external view returns(string memory, uint256);
    //get bonus pool
    function getBonusRecord(uint256 index) external view returns(uint256);

    function getNotes(uint256 index) external view returns(uint256);

    //last winning number
    function getWinningNum(uint256 index) external view returns(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number);
    //winning detail record
    function getWinningDetails(uint256 offset, uint256 pageCount) external view returns(string memory, uint256);
    //get note of period
    function getWinningAll(uint256 index,uint256 grade) external view returns(uint256);

    function judgeConvert(address account) external view returns(bool);

    function getConvertLimit() external view returns(uint256);

    function getGcoinBalance(address account) external view returns(uint256);

    function getConvertNumber() external view returns(uint256);
}

contract LotteryService is ILotteryService,AccessController {
    using SafeMath for uint256;

    BuyRecord private _buyRecordContract;
    ElaLottery private _lotteryContract;
    WinningRecord private _winningRecordContract;

    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _buyRecordContract = BuyRecord(getContractAddress("buyRecord"));
        _lotteryContract = ElaLottery(getContractAddress("elaLottery"));
        _winningRecordContract = WinningRecord(getContractAddress("winningRecord"));
    }
    // buy lottery
    function buyLottery(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,uint256 noteNumber,address account) public override {
        _lotteryContract.buyLottery(first_number,second_number,third_number,forth_number,noteNumber,account);
    }

    function convertLottery(address first_number,address second_number,address third_number,address forth_number,address fifth_number,address account) public override{
        _lotteryContract.convertLottery(first_number,second_number,third_number,forth_number,fifth_number,account);
    }

    //draw prize
    function draw(address account) public override {
        _lotteryContract.draw(account);
    }

    //judge whether winning
    function judgeWinning(address account) public view override returns(bool) {
        return _lotteryContract.judgeWinning(account);
    }

    //receive prize
    function receivePrice(address account) public override {
        _lotteryContract.receivePrice(account);
    }

    //get current period
    function getPeriod() public view override returns(uint256) {
        return _lotteryContract.getPeriod();
    }

    //get current block
    function getBlockNum() public view override returns(uint256) {
        return _lotteryContract.getBlockNum();
    }

    //get draw prize block
    function getDrawBlockNum() public view override returns(uint256) {
        return _lotteryContract.getDrawBlockNum();
    }

    //get lottery price
    function getLotteryPrice() public view override returns(uint256) {
        return _lotteryContract.getLotteryPrice();
    }

    //buy history
    function getBuyHistory(uint256 offset, uint256 pageCount,address account) public view override returns(string memory, uint256) {
        return _buyRecordContract.getBuyHistory(offset,pageCount,account);
    }
    //get bonus pool
    function getBonusRecord(uint256 index) public view override returns(uint256) {
        return _buyRecordContract.getBonusRecord(index);
    }

    //last winning number
    function getWinningNum(uint256 index) public view override returns(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number) {
        return _winningRecordContract.getWinningNum(index);
    }
    //winning detail record
    function getWinningDetails(uint256 offset, uint256 pageCount) public view override returns(string memory, uint256) {
        return _winningRecordContract.getWinningDetails(offset,pageCount);
    }
    //get note of period
    function getWinningAll(uint256 index,uint256 grade) public view override returns(uint256) {
        return _winningRecordContract.getWinningAll(index,grade);
    }

    function getNotes(uint256 index) public view override returns(uint256) {
        return _buyRecordContract.getNotes(index);
    }

    function getGcoinBalance(address account) public view override returns(uint256) {
        return _lotteryContract.getGcoinBalance(account);
    }

    function judgeConvert(address account) public view override returns(bool) {
        return _lotteryContract.judgeConvert(account);
    }

    function getConvertLimit() public view override returns(uint256) {
        return _lotteryContract.getConvertLimit();
    }

    function getConvertNumber() public view override returns(uint256) {
        return _lotteryContract.getConvertNumber();
    }
}
