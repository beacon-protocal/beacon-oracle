// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/Strings.sol";
import "../lib/SafeERC20.sol";
import {IPriceData} from "./PriceService.sol";
import "./Mining.sol";
import {ITokenPairData} from "../auction/TokenPairData.sol";
import {IBonusData} from "../bonus/BonusData.sol";
import "./HTokenMining.sol";
import "./OfferData.sol";
import "../mdex/StakedBonus.sol";
import "../token/GCOIN.sol";

contract EthOfferMain is AccessController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    enum TradeChoices {SendEthBuyERC20, SendERC20BuyEth}

    IPriceData private _priceDataContract;
    Mining private _mingContract;
    IERC20 private _bcoinContract;
    IBonusData private _bonusDataContract;
    ITokenPairData private _tokenPairData;
    HTokenMining private _hTokenMining;
    IERC20 private _benchmarkContract;
    IERC20 private _husdContract;
    OfferData private _offerDataContract;
    StakedBonus private _stakedBonus;
    IGCOIN private _gcoin;

    uint256 public tradeRatio = 2;
    uint256 public leastEth = 10 ether;
    uint256 public offerSpan = 10 ether;
    uint256 public deviationThreshold = 10;
    uint256 public deviationScale = 4;
    uint256 public blockLimit = 100;
    //fee husd:1ether
    //主网husd 精度为8位
    uint256 public miningFee = 100000000;
    uint256 public tradeFee = 100000000;
    uint256 public gcoinReward = 1 ether;

    uint256 public lpTokenRatio = 30;
    uint256 private _miningRatio = 90;

    mapping(uint256 => mapping(address => uint256)) public feeOfBlock;
    mapping(uint256 => mapping(address => uint256)) public miningOfBlock;

    event NewOfferAdded(address indexed offerIndex, address indexed token, uint256 ethAmount, uint256 erc20Amount, uint256 confirmedBlock, uint256 fee, address offerOwner);
    event OfferTraded(address indexed offerIndex, address indexed token, address trader, address offerOwner, uint256 tradeEthAmount, uint256 tradeERC20Amount, uint256 tradeChoices);

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _priceDataContract = IPriceData(getContractAddress("ethPriceData"));
        _mingContract = Mining(getContractAddress("mining"));
        _bcoinContract = IERC20(getContractAddress("bcoin"));
        _bonusDataContract = IBonusData(getContractAddress("bonusData"));
        _tokenPairData = ITokenPairData(getContractAddress("tokenPairData"));
        _hTokenMining = HTokenMining(getContractAddress("hTokenMining"));
        _benchmarkContract = IERC20(getContractAddress("eth"));
        _husdContract = IERC20(getContractAddress("husd"));
        _offerDataContract = OfferData(getContractAddress("ethOfferData"));
        _stakedBonus = StakedBonus(getContractAddress("stakedBonus"));
        _gcoin = IGCOIN(getContractAddress("gcoin"));
        require(_bcoinContract.approve(getContractAddress("stakedBonusData"), uint256(100000000 ether)), "offerMain: approve fail");
        require(_bcoinContract.approve(getContractAddress("stakedSavingData"), uint256(100000000 ether)), "offerMain: approve fail");
    }

    function offer(uint256 ethAmount, uint256 erc20Amount, address erc20) public onlyEOA whenNotPaused {
        require(_tokenPairData.isValidToken(erc20), "offerMain: token not allowed");
        require(_tokenPairData.isEthToken(erc20), "offerMain: token type error");

        bool deviation = isDeviation(ethAmount, erc20Amount, erc20);
        if (deviation) {
            require(ethAmount >= leastEth.mul(deviationScale), "offerMain: EthAmount needs to be no less than 10 times of the minimum scale");
        }

        uint256 _miningFee = ethAmount.div(offerSpan).mul(miningFee);

        _benchmarkContract.safeTransferFrom(msg.sender,address(this),ethAmount);

        _createOffer(ethAmount, erc20Amount, erc20, _miningFee, deviation);

        IERC20(erc20).safeTransferFrom(msg.sender, address(this), erc20Amount);

        _ming(erc20);

        _husdContract.safeTransferFrom(msg.sender,address(this),_miningFee);
        require(_husdContract.approve(address(_bonusDataContract),_miningFee),"offerMain: approve failed");
        _bonusDataContract.depositUSDT(_tokenPairData.getTokenPair(erc20),address(this),_miningFee);
        feeOfBlock[block.number][erc20] = feeOfBlock[block.number][erc20].add(_miningFee);
        //添加获得游戏币
        uint256 _gcoinReward = ethAmount.div(offerSpan).mul(gcoinReward);
        _gcoin.mint(msg.sender,_gcoinReward);
    }

    function _ming(address token) private {
        uint256 miningAmount;
        if (_tokenPairData.isDefaultToken(token)) {
            miningAmount = _mingContract.mining(2);
            if (miningAmount > 0) {
                //讲矿池内的百分之30分入lp
                _stakedBonus.deposit(miningAmount.mul(lpTokenRatio).div(_miningRatio));
                miningOfBlock[block.number][token] = miningAmount.sub(miningAmount.mul(lpTokenRatio).div(_miningRatio));
            }
        } else {
            miningAmount = _hTokenMining.mining(token);
            if (miningAmount > 0){
                miningOfBlock[block.number][token] = miningAmount;
            }
        }
    }

    function sendEthBuyErc20(uint256 ethAmount, uint256 erc20Amount, address offerIndex, uint256 tradeEthAmount, uint256 tradeErc20Amount, address erc20) public onlyEOA whenNotPaused {
        _tradeOffer(TradeChoices.SendEthBuyERC20, ethAmount, erc20Amount, offerIndex, tradeEthAmount, tradeErc20Amount, erc20);
    }

    function sendErc20BuyEth(uint256 ethAmount, uint256 erc20Amount, address offerIndex, uint256 tradeEthAmount, uint256 tradeErc20Amount, address erc20) public onlyEOA whenNotPaused {
        _tradeOffer(TradeChoices.SendERC20BuyEth, ethAmount, erc20Amount, offerIndex, tradeEthAmount, tradeErc20Amount, erc20);
    }

    function _tradeOffer(TradeChoices tradeChoices, uint256 ethAmount, uint256 erc20Amount, address offerIndex, uint256 tradeEthAmount, uint256 tradeErc20Amount, address erc20) private {
        uint256 index = uint256(offerIndex);
        address offerOwner;
        bool offerIsDeviate;
        address offerToken;
        uint256[6] memory offerData;
        (offerOwner, offerIsDeviate, offerToken, offerData) = _getOffer(index);

        require(offerToken == erc20, "offerMain: wrong token address");

        bool deviation = isDeviation(ethAmount, erc20Amount, erc20) || offerIsDeviate;
        if (deviation) {
            require(ethAmount >= tradeEthAmount.mul(deviationScale), "offerMain: EthAmount needs to be no less than 10 times of transaction scale");
        } else {
            require(ethAmount >= tradeEthAmount.mul(tradeRatio), "offerMain: EthAmount needs to be no less than 2 times of transaction scale");
        }

        require(tradeEthAmount.mod(offerSpan) == 0, "offerMain: Transaction size does not meet asset span");
        require(!_isConfirmed(offerData[4]), "offerMain: price has been confirmed");
        require(offerData[2] >= tradeEthAmount, "offerMain: insufficient trading eth");
        require(offerData[3] >= tradeErc20Amount, "offerMain: insufficient trading token");
        require(tradeErc20Amount == offerData[3].mul(tradeEthAmount).div(offerData[2]), "offerMain: wrong erc20 amount");

        _trade(tradeChoices, ethAmount, erc20Amount, tradeEthAmount, tradeErc20Amount, erc20);
        _createOffer(ethAmount, erc20Amount, erc20, 0, deviation);

        if (tradeChoices == TradeChoices.SendEthBuyERC20) {
            offerData[0] = offerData[0].add(tradeEthAmount);
            offerData[1] = offerData[1].sub(tradeErc20Amount);
            emit OfferTraded(offerIndex, erc20, msg.sender, offerOwner, tradeEthAmount, tradeErc20Amount, 1);
        } else {
            offerData[0] = offerData[0].sub(tradeEthAmount);
            offerData[1] = offerData[1].add(tradeErc20Amount);
            emit OfferTraded(offerIndex, erc20, msg.sender, offerOwner, tradeEthAmount, tradeErc20Amount, 0);
        }
        offerData[3] = offerData[3].sub(tradeErc20Amount);
        offerData[2] = offerData[2].sub(tradeEthAmount);

        _priceDataContract.changePrice(erc20, tradeEthAmount, tradeErc20Amount, offerData[4].add(blockLimit));
        _offerDataContract.changeOffer(index, offerData[0], offerData[1], offerData[2], offerData[3], offerData[5]);
    }

    function withdraw(address offerIndex) public onlyEOA whenNotPaused {
        uint256 index = uint256(offerIndex);
        address offerOwner;
        bool offerIsDeviate;
        address offerToken;
        uint256[6] memory offerData;
        (offerOwner, offerIsDeviate, offerToken, offerData) = _getOffer(index);

        require(_isConfirmed(offerData[4]), "offerMain: offer has not benn confirmed");

        if (offerData[0] > 0) {
            _benchmarkContract.safeTransfer(offerOwner, offerData[0]);
        }

        if (offerData[1] > 0) {
            IERC20(offerToken).safeTransfer(offerOwner, offerData[1]);
        }

        if (offerData[5] > 0) {
            uint256 mining = offerData[5].mul(miningOfBlock[offerData[4]][offerToken]).div(feeOfBlock[offerData[4]][offerToken]);
            if (_tokenPairData.isDefaultToken(offerToken)) {
                require(_bcoinContract.transfer(offerOwner, mining), "OfferMain: bcoin transfer failed");
            } else {
                IERC20 htoken = IERC20(_tokenPairData.getTokenPair(offerToken));
                require(htoken.transfer(offerOwner, mining), "OfferMain: hToken transfer failed.");
            }
        }
        _offerDataContract.changeOffer(index, 0, 0, offerData[2], offerData[3], 0);
    }
    function miningProfit(address offerIndex) public onlyEOA whenNotPaused view returns (uint256) {
        uint256 index = uint256(offerIndex);
        address offerToken;
        address offerOwner;
        bool offerIsDeviate;
        uint256[6] memory offerData;
        uint256 mining;
        (offerOwner, offerIsDeviate, offerToken, offerData) = _getOffer(index);
        if (offerData[5] > 0) {
            mining = offerData[5].mul(miningOfBlock[offerData[4]][offerToken]).div(feeOfBlock[offerData[4]][offerToken]);
        }
        return mining;
    }

    function setMiningFee(uint256 fee) public onlyAdmin {
        miningFee = fee;
    }

    function setTradeFee(uint256 fee) public onlyAdmin {
        tradeFee = fee;
    }

    function _isConfirmed(uint256 blockNum) public view returns (bool){
        return block.number.sub(blockNum) > blockLimit;
    }

    function isDeviation(uint256 ethAmount, uint256 erc20Amount, address erc20) public view returns (bool){
        (uint256 latestEthAmount, uint256 latestERC20Amount,) = _priceDataContract.inquireLatestPriceInner(erc20);
        if (latestERC20Amount == 0 || latestEthAmount == 0)
            return false;
        uint256 suitableERC20Amount = ethAmount.mul(latestERC20Amount).div(latestEthAmount);
        return erc20Amount >= suitableERC20Amount.mul(uint256(100).add(deviationThreshold)).div(100) || erc20Amount <= suitableERC20Amount.mul(uint256(100).sub(deviationThreshold)).div(100);
    }

    function _createOffer(uint256 ethAmount, uint256 erc20Amount, address erc20, uint256 fee, bool deviation) private {
        require(ethAmount >= leastEth, "offerMain: Eth scale is smaller than the minimum scale");
        require(ethAmount.mod(offerSpan) == 0, "offerMain: Non compliant asset span");
        require(erc20Amount.mod(ethAmount.div(offerSpan)) == 0, "offerMain: Asset quantity is not divided");
        require(erc20Amount > 0);
        uint256 curIndex = _offerDataContract.createOffer(ethAmount, erc20Amount, erc20, fee, deviation,msg.sender,block.number);
        emit NewOfferAdded(address(curIndex), erc20, ethAmount, erc20Amount, block.number.add(blockLimit), fee, msg.sender);
        _priceDataContract.addPrice(erc20, ethAmount, erc20Amount, block.number.add(blockLimit), msg.sender);
    }

    function _getOffer(uint256 offerIndex) private view returns (address offerOwner,bool offerIsDeviate,address offerToken,uint256[6] memory){
        uint256[6] memory offerData;
        {
            (offerOwner, offerIsDeviate, offerToken, offerData[0], offerData[1], offerData[2],
            offerData[3], offerData[4], offerData[5]) = _offerDataContract.getOffer(offerIndex);
        }
        return (offerOwner, offerIsDeviate, offerToken, offerData);
    }

    function _trade(TradeChoices tradeChoices,uint256 ethAmount, uint256 erc20Amount, uint256 tradeEthAmount, uint256 tradeErc20Amount, address erc20) private{
        uint256 amount;
        if (tradeChoices == TradeChoices.SendEthBuyERC20) {
            if (erc20Amount > tradeErc20Amount) {
                IERC20(erc20).safeTransferFrom(msg.sender, address(this), erc20Amount.sub(tradeErc20Amount));
            } else {
                IERC20(erc20).safeTransfer(msg.sender, tradeErc20Amount.sub(erc20Amount));
            }
            amount = ethAmount.add(tradeEthAmount);
        } else {
            IERC20(erc20).safeTransferFrom(msg.sender, address(this), tradeErc20Amount.add(erc20Amount));
            amount = ethAmount.sub(tradeEthAmount);
        }
        _benchmarkContract.safeTransferFrom(msg.sender,address(this),amount);
        _husdContract.safeTransferFrom(msg.sender,address(this),tradeFee);
        require(_husdContract.approve(address(_bonusDataContract),tradeFee),"offerMain: approve failed");
        _bonusDataContract.depositUSDT(_tokenPairData.getTokenPair(erc20),address(this),tradeFee);
    }
}
