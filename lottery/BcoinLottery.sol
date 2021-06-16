// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "./BuyRecord.sol";
import "../token/GCOIN.sol";
import "../token/IERC20.sol";
import "./LotteryBonus.sol";
import "./WinningRecord.sol";
import "./BurnGcoin.sol";
pragma experimental ABIEncoderV2;

contract BcoinLottery is AccessController{
    using SafeMath for uint256;

    //投注人记录
    address[] lotteryPlayers;

    //期数
    uint256 public periodNum = 1;

    uint256 public lotteryBet = 5;
    uint256 public lotteryPrice;
    uint256 public convertBet = 5;
    uint256 public firstRewardRate;
    uint256 public secondRewardRate;
    uint256 public thirdRewardRate;

    uint256 public initBlock;
    uint256 public drawBlock;
    uint256 convertNumber;
    address token;
    uint256 drawBlockTime;

    uint256 maxFirstPrize = 3000000 ether;
    uint256 maxSecondPrize = 250000 ether;
    uint256 maxThirdPrize = 15000 ether;

    BuyRecord private _buyRecordContract;
    LotteryBonus private _lotteryBonusContract;
    WinningRecord private _winningRecordContract;
    IGCOIN private _gcoin;
    BurnGcoin private _burnGcoinContract;

    constructor(address config,uint256 initPrice,uint256 drawBlockNum,uint256 period) public AccessController(config){
        periodNum = period;
        drawBlockTime = drawBlockNum;
        initBlock = block.number;
        lotteryPrice = initPrice;
        drawBlock = initBlock.add(drawBlockTime);
        firstRewardRate = 50;
        secondRewardRate = 30;
        thirdRewardRate = 20;
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _buyRecordContract = BuyRecord(getContractAddress("bcoinBuyRecord"));
        _lotteryBonusContract = LotteryBonus(getContractAddress("lotteryBonus"));
        _winningRecordContract = WinningRecord(getContractAddress("bcoinWinningRecord"));
        _gcoin = IGCOIN(getContractAddress("gcoin"));
        token = getContractAddress("bcoin");
        _burnGcoinContract = BurnGcoin(getContractAddress("game"));
    }

    //兑换彩票
    function convertLottery(address first_number,address second_number,address third_number,address forth_number,address fifth_number,address account) public onlyLucky {
        //判断是否可以兑换
        require(block.number<drawBlock,"lotteryConvert:It's not time to buy lottery tickets");
        require(_buyRecordContract.getSetConvertRecord(periodNum,account) != true,"lotteryConvert:You have already exchanged this issue");
        require(_buyRecordContract.getNotes(periodNum).mul(10).div(100).div(5).sub(convertNumber) > 0,"lotteryConvert:The number of exchanges in this period has been used up");
        require(_gcoin.balanceOf(account) >= 1,"lotteryConvert:your credit is running low");
        bool exist = false;
        _buyRecordContract.setNotes(periodNum,5);
        _burnGcoinContract.burn(account,1 ether);
        //将购买信息存入购买记录
        _buyRecordContract.depositBuyInfo(account,periodNum,uint256(first_number)>>12,(uint256(first_number)>>8)^((uint256(first_number)>>12)<<4),(uint256(first_number)>>4) ^ ((uint256(first_number)>> 8)<<4),uint256(first_number) ^ (uint256(first_number)>>4)<<4,1,false,false,0,0);
        _buyRecordContract.depositBuyInfo(account,periodNum,uint256(second_number)>>12,(uint256(second_number)>>8)^((uint256(second_number)>>12)<<4),(uint256(second_number)>>4) ^ ((uint256(second_number)>> 8)<<4),uint256(second_number) ^ (uint256(second_number)>>4)<<4,1,false,false,0,0);
        _buyRecordContract.depositBuyInfo(account,periodNum,uint256(third_number)>>12,(uint256(third_number)>>8)^((uint256(third_number)>>12)<<4),(uint256(third_number)>>4) ^ ((uint256(third_number)>> 8)<<4),uint256(third_number) ^ (uint256(third_number)>>4)<<4,1,false,false,0,0);
        _buyRecordContract.depositBuyInfo(account,periodNum,uint256(forth_number)>>12,(uint256(forth_number)>>8)^((uint256(forth_number)>>12)<<4),(uint256(forth_number)>>4) ^ ((uint256(forth_number)>> 8)<<4),uint256(forth_number) ^ (uint256(forth_number)>>4)<<4,1,false,false,0,0);
        _buyRecordContract.depositBuyInfo(account,periodNum,uint256(fifth_number)>>12,(uint256(fifth_number)>>8)^((uint256(fifth_number)>>12)<<4),(uint256(fifth_number)>>4) ^ ((uint256(fifth_number)>> 8)<<4),uint256(fifth_number) ^ (uint256(fifth_number)>>4)<<4,1,false,false,0,0);
        //分别将前四位，前三位，二位存入
        _buyRecordContract.setFourToNote(periodNum,uint256(first_number) ,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(first_number),account,1);
        _buyRecordContract.setThreeToNote(periodNum,uint256(first_number) >> 4,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(first_number) >> 4,account,1);
        _buyRecordContract.setTwoToNote(periodNum,uint256(first_number) >> 8,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(first_number) >> 8,account,1);

        _buyRecordContract.setFourToNote(periodNum,uint256(second_number) ,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(second_number),account,1);
        _buyRecordContract.setThreeToNote(periodNum,uint256(second_number) >> 4,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(second_number) >> 4,account,1);
        _buyRecordContract.setTwoToNote(periodNum,uint256(second_number) >> 8,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(second_number) >> 8,account,1);

        _buyRecordContract.setFourToNote(periodNum,uint256(third_number) ,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(third_number),account,1);
        _buyRecordContract.setThreeToNote(periodNum,uint256(third_number) >> 4,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(third_number) >> 4,account,1);
        _buyRecordContract.setTwoToNote(periodNum,uint256(third_number) >> 8,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(third_number) >> 8,account,1);

        _buyRecordContract.setFourToNote(periodNum,uint256(forth_number) ,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(forth_number),account,1);
        _buyRecordContract.setThreeToNote(periodNum,uint256(forth_number) >> 4,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(forth_number) >> 4,account,1);
        _buyRecordContract.setTwoToNote(periodNum,uint256(forth_number) >> 8,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(forth_number) >> 8,account,1);

        _buyRecordContract.setFourToNote(periodNum,uint256(fifth_number) ,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(fifth_number),account,1);
        _buyRecordContract.setThreeToNote(periodNum,uint256(fifth_number) >> 4,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(fifth_number) >> 4,account,1);
        _buyRecordContract.setTwoToNote(periodNum,uint256(fifth_number) >> 8,1);
        _buyRecordContract.setPlayersInfo(periodNum,uint256(fifth_number) >> 8,account,1);
        for(uint i=0;i<lotteryPlayers.length;i++) {
            if(lotteryPlayers[i] == account) {
                exist = true;
            }
        }
        if(!exist) {
            lotteryPlayers.push(account);
        }
        _buyRecordContract.setConvertRecord(periodNum,account);
        convertNumber = convertNumber.add(1);
    }

    function buyLottery(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number,uint256 noteNumber,address account) public onlyLucky{
        //判断时间是否是投注时间
        require(block.number<drawBlock,"lottery:It's not time to buy lottery tickets");
        bool exist = false;
        uint256 costs = noteNumber.mul(lotteryPrice);
        require(IERC20(token).balanceOf(account) >= costs,"buyLottery:your credit is running low");
        //将购买金额存入奖金池
         _lotteryBonusContract.deposit(token,account,costs);
        _buyRecordContract.setNotes(periodNum,noteNumber);
        //将购买信息存入购买记录
        _buyRecordContract.depositBuyInfo(account,periodNum,first_number,second_number,third_number,forth_number,noteNumber,false,false,0,0);
        //分别将前四位，前三位，二位存入
        _buyRecordContract.setFourToNote(periodNum,getFourDigits(first_number,second_number,third_number,forth_number),noteNumber);
        _buyRecordContract.setPlayersInfo(periodNum,getFourDigits(first_number,second_number,third_number,forth_number),account,noteNumber);
        _buyRecordContract.setThreeToNote(periodNum,getThreeDigits(first_number,second_number,third_number),noteNumber);
        _buyRecordContract.setPlayersInfo(periodNum,getThreeDigits(first_number,second_number,third_number),account,noteNumber);
        _buyRecordContract.setTwoToNote(periodNum,getTwoDigits(first_number,second_number),noteNumber);
        _buyRecordContract.setPlayersInfo(periodNum,getTwoDigits(first_number,second_number),account,noteNumber);
        for(uint i=0;i<lotteryPlayers.length;i++) {
            if(lotteryPlayers[i] == account) {
               exist = true;
            }
        }
        if(!exist) {
            lotteryPlayers.push(account);
        }
        //将每一期的购买人信息存入
        _buyRecordContract.setLotteryPlayers(periodNum,account);
        //查询奖金池合约余额存入奖金池记录
        uint256 lotteryBonusPool = IERC20(token).balanceOf(getContractAddress("lotteryBonus"));
        //将本期奖金存入奖金池记录
        _buyRecordContract.setBonusRecord(periodNum,lotteryBonusPool);
    }

    function draw(address account) public onlyLucky{
        require(block.number>=drawBlock,"lottery:It's not the lottery time");
        uint256 first_number;
        uint256 second_number;
        uint256 third_number;
        uint256 forth_number;
        (first_number,second_number,third_number,forth_number) = randomNumber();
        //向开奖者发送奖励
        uint256 fee = IERC20(token).balanceOf(getContractAddress("lotteryBonus")).div(100);
        if( fee>=lotteryPrice.mul(lotteryBet)) {
            _lotteryBonusContract.withdraw(token,account,lotteryPrice.mul(lotteryBet));
        }else if(fee > 0 ){
            _lotteryBonusContract.withdraw(token,account,IERC20(token).balanceOf(getContractAddress("lotteryBonus")).div(100));
        }
        _buyRecordContract.setBonusRecord(periodNum,IERC20(token).balanceOf(getContractAddress("lotteryBonus")));
        //存开奖号码
        _winningRecordContract.setWinningInfo(periodNum,first_number,second_number,third_number,forth_number);
        //中奖号码比对获取中奖信息
        check(first_number,second_number,third_number,forth_number);
        //期数自动加一
        periodNum = periodNum.add(1);
        //计算下一期的开奖区块
        drawBlock = block.number.add(drawBlockTime);
        delete lotteryPlayers;
        convertNumber = 0;
        _buyRecordContract.setBonusRecord(periodNum,IERC20(token).balanceOf(getContractAddress("lotteryBonus")));
    }

    function receivePrice(address account) public onlyLucky{
        uint256 first_number;
        uint256 second_number;
        uint256 third_number;
        uint256 forth_number;
        uint256 bonus;
        uint256 bonusBalance = _buyRecordContract.getBonusRecord(periodNum.sub(1));
        (first_number,second_number,third_number,forth_number)=_winningRecordContract.getWinningNum(periodNum);
        uint256 oneNoteNumber = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getFourDigits(first_number,second_number,third_number,forth_number),account);
        uint256 twoNoteNumber = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getThreeDigits(first_number,second_number,third_number),account);
        uint256 threeNoteNumber = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getTwoDigits(first_number,second_number),account);
        if(_winningRecordContract.getWinningAll(periodNum.sub(1),4) != 0) {
            if(bonusBalance.mul(firstRewardRate).div(100).div(_winningRecordContract.getWinningAll(periodNum.sub(1),4)) >= maxFirstPrize) {
                bonus = bonus.add(oneNoteNumber.mul(maxFirstPrize));
            }else {
                bonus = bonus.add(oneNoteNumber.mul(bonusBalance.mul(firstRewardRate).div(100)).div(_winningRecordContract.getWinningAll(periodNum.sub(1),4)));
            }
        }
        if(_winningRecordContract.getWinningAll(periodNum.sub(1),3) != 0) {
            if(bonusBalance.mul(secondRewardRate).div(100).div(_winningRecordContract.getWinningAll(periodNum.sub(1),3)) >= maxSecondPrize) {
                bonus = bonus.add((twoNoteNumber.sub(oneNoteNumber)).mul(maxSecondPrize));
            }else {
                bonus = bonus.add((twoNoteNumber.sub(oneNoteNumber)).mul(bonusBalance.mul(secondRewardRate).div(100)).div(_winningRecordContract.getWinningAll(periodNum.sub(1),3)));
            }
        }
        if(_winningRecordContract.getWinningAll(periodNum.sub(1),2) != 0) {
            if(bonusBalance.mul(thirdRewardRate).div(100).div(_winningRecordContract.getWinningAll(periodNum.sub(1),2)) >= maxThirdPrize) {
                bonus = bonus.add((threeNoteNumber.sub(twoNoteNumber)).mul(maxThirdPrize));
            }else {
                bonus = bonus.add((threeNoteNumber.sub(twoNoteNumber)).mul(bonusBalance.mul(thirdRewardRate).div(100)).div(_winningRecordContract.getWinningAll(periodNum.sub(1),2)));
            }
        }
        _lotteryBonusContract.withdraw(token,account,bonus);
        _winningRecordContract.setReceivePlayers(periodNum.sub(1),account);
        _buyRecordContract.setBonusRecord(periodNum,IERC20(token).balanceOf(getContractAddress("lotteryBonus")));
    }

    function judgeWinning(address account) public view returns(bool) {
        if(_winningRecordContract.exits(periodNum.sub(1),account)) {
            return false;
        }
        uint256 first_number;
        uint256 second_number;
        uint256 third_number;
        uint256 forth_number;
        (first_number,second_number,third_number,forth_number)=_winningRecordContract.getWinningNum(periodNum);
        uint256 firstPrize = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getFourDigits(first_number,second_number,third_number,forth_number),account);
        uint256 secondPrize = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getThreeDigits(first_number,second_number,third_number),account);
        uint256 thirdPrize = _buyRecordContract.getPlayersInfo(periodNum.sub(1),getTwoDigits(first_number,second_number),account);
        if(firstPrize != 0 || secondPrize != 0 || thirdPrize != 0) {
            return true;
        }
        return false;
    }

    function getPeriod() public view returns(uint256) {
        return periodNum;
    }

    function getBlockNum() public view returns(uint256) {
        return block.number;
    }

    function getDrawBlockNum() public view returns(uint256) {
        return drawBlock;
    }

    function getLotteryPrice() public view returns(uint256) {
        return lotteryPrice;
    }

    function check(uint256 first_number,uint256 second_number,uint256 third_number,uint256 forth_number) private {
        //取出四位中奖号码注数
        uint256 firstPrize = _buyRecordContract.getFourToNote(periodNum,getFourDigits(first_number,second_number,third_number,forth_number));
        //取出三位中奖号码注数
        uint256 secondPrize = _buyRecordContract.getThreeToNote(periodNum,getThreeDigits(first_number,second_number,third_number));
        //取出两位中奖号码注数
        uint256 thirdPrize = _buyRecordContract.getTwoToNote(periodNum,getTwoDigits(first_number,second_number));
        _winningRecordContract.setWinningAll(periodNum,4,firstPrize);
        _winningRecordContract.setWinningAll(periodNum,3,secondPrize.sub(firstPrize));
        _winningRecordContract.setWinningAll(periodNum,2,thirdPrize.sub(secondPrize));
        uint256  bonusAmount = _buyRecordContract.getBonusRecord(periodNum);
        _winningRecordContract.depositWinningDetails(periodNum,bonusAmount,first_number,second_number,third_number,forth_number,_winningRecordContract.getWinningAll(periodNum,4),_winningRecordContract.getWinningAll(periodNum,3),_winningRecordContract.getWinningAll(periodNum,2));
    }

    function random(uint256 seed) private view returns(uint256) {
        uint num = block.number;
        uint timestamp = block.timestamp;
        return uint256(uint256(keccak256(abi.encodePacked(num,seed,timestamp))) % 13).add(1);
    }

    function randomTwo(uint256 seed) public view returns(uint256) {
        uint num = block.number;
        uint timestamp = block.timestamp;
        return uint256(uint256(keccak256(abi.encodePacked(num,seed,timestamp))) % lotteryPlayers.length);
    }

    function randomNumber() private view returns(uint256 one,uint256 two,uint256 three,uint256 four) {
        uint256 firstNumber;
        uint256 secondNumber;
        uint256 thirdNumber;
        uint256 fortNumber;
        if(lotteryPlayers.length == 0) {
            firstNumber = random(lotteryPlayers.length);
            secondNumber = random(firstNumber);
            thirdNumber = random(secondNumber);
            fortNumber = random(thirdNumber);
        }else {
            uint256 i;
            if(randomTwo(firstNumber) >= lotteryPlayers.length) {
                i = randomTwo(firstNumber).sub(1);
            }else {
                i = randomTwo(firstNumber);
            }
            uint256 number = uint256(lotteryPlayers[i]);
            firstNumber = random(number<<12);
            secondNumber = random(number<<16);
            thirdNumber = random(number<<8);
            fortNumber = random(number<<32);
        }
        return (firstNumber,secondNumber,thirdNumber,fortNumber);
    }

    function getFourDigits(uint256 one,uint256 two,uint256 three,uint256 four) private pure returns(uint256) {
        uint256 i = (one << 12) + (two << 8) + (three << 4) +four;
        return i;
    }
    function getThreeDigits(uint256 one,uint256 two,uint256 three) private pure returns(uint256) {
        uint256 i = (one << 8) + (two << 4) + three;
        return i;
    }
    function getTwoDigits(uint256 one,uint256 two) private pure returns(uint256) {
        uint256 i = (one << 4) + two;
        return i;
    }

    function getGcoinBalance(address account) public view returns(uint256) {
        return _gcoin.balanceOf(account);
    }

    function judgeConvert(address account) public view returns(bool) {
        return _buyRecordContract.getSetConvertRecord(periodNum,account);
    }

    function getConvertLimit() public view returns(uint256) {
        return _buyRecordContract.getNotes(periodNum).mul(10).div(100).div(5).sub(convertNumber);
    }

    function getConvertNumber() public view returns(uint256) {
         return _buyRecordContract.getNotes(periodNum).mul(10).div(100).div(5).sub(convertNumber);
    }

    function setDrawBlockTime(uint256 blockSpace) public onlyAdmin{
        drawBlockTime = blockSpace;
    }

    function setGameAddress(address contractAddress) public onlyAdmin{
        addGames(contractAddress);
    }
}
