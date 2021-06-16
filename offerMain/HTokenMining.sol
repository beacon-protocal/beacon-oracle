// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../token/IERC20.sol";
import "../lib/SafeMath.sol";
import {ITokenPairData} from "../auction/TokenPairData.sol";
import {IHToken} from "../token/HToken.sol";

contract HTokenMining is AccessController {
    using SafeMath for uint256;
    uint256 public decayPeriod = 10512000;
    uint256 public decayPercent = 40;
    uint256[200] public miningAmountList;
    uint256 public initialMiningAmount = 3.80517504 ether;
    uint256 public bidderRatio = 5;
    uint256 public initialSupply = 100000000 ether;
    mapping(address => uint256) hTokenPool;

    ITokenPairData private _tokenPairData;

    event Mined(uint256 blockNum, address token, address hToken, uint256 amount);

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
        miningAmountList[0] = initialMiningAmount;
    }

    function _initInstanceVariables() internal override {
        _tokenPairData = ITokenPairData(getContractAddress("tokenPairData"));
    }

    function mining(address token) public onlyOfferMain returns (uint256){
        require(!_tokenPairData.isBlocked(token) && _tokenPairData.isEnabled(token) && _tokenPairData.isValidToken(token), "HTokenMining: invalid token");
        address hTokenAddress = _tokenPairData.getTokenPair(token);
        IHToken hToken = IHToken(hTokenAddress);
        if(hTokenPool[hTokenAddress]==0){
            hTokenPool[hTokenAddress] = initialSupply;
        }
        (uint256 createBlock, uint256 recentUsedBlock) = hToken.getBlockInfo();
        uint256 decayPeriodNum = block.number.sub(createBlock).div(decayPeriod);
        uint256 miningAmountPerBlock = _singleBlockMining(decayPeriodNum,hTokenAddress);
        uint256 miningAmount = miningAmountPerBlock.mul(block.number.sub(recentUsedBlock));
        if (miningAmount > 0){
            hToken.mint(miningAmount);
            hTokenPool[hTokenAddress] = hTokenPool[hTokenAddress].sub(miningAmount);
            address bidder = hToken.getBidder();
            uint256 bidderAmount = miningAmount.mul(bidderRatio).div(100);
            require(hToken.transfer(bidder, bidderAmount), "HTokenMining: transfer to bidder failed");
            require(hToken.transfer(msg.sender, miningAmount.sub(bidderAmount)), "HTokenMining: transfer to offer contract failed");
            emit Mined(block.number, token, address(hToken), miningAmount);
            return miningAmount.sub(bidderAmount);
        }else{
            return 0;
        }
    }

    function depositInner(address token,uint256 amount) onlyPOIStoreAndOfferMain public {
        _deposit(token,amount);
    }

    function _deposit(address token,uint256 amount) private {
        require(!_tokenPairData.isBlocked(token) && _tokenPairData.isEnabled(token) && _tokenPairData.isValidToken(token), "HTokenMining: invalid token");
        address hTokenAddress = _tokenPairData.getTokenPair(token);
        IHToken hToken = IHToken(hTokenAddress);
        require(hToken.transferFrom(msg.sender,address(this),amount),"HTokenMining:depositInner transferFrom fail");
        hTokenPool[hTokenAddress] = hTokenPool[hTokenAddress].add(amount);
        hToken.burn(amount);
    }

    function _singleBlockMining(uint256 decayPeriodNum,address hToken) private returns (uint256){
        if(miningAmountList[decayPeriodNum] == 0){
            miningAmountList[decayPeriodNum] = hTokenPool[hToken].mul(decayPercent).div(100).div(decayPeriod);
        }
        return miningAmountList[decayPeriodNum];
    }
}
