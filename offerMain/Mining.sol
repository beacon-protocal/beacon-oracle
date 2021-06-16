// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../token/IERC20.sol";
import "../lib/SafeMath.sol";

contract Mining is AccessController {
    using SafeMath for uint256;

    IERC20 private _bcoinContract;

    address public coder;
    uint256 public coderPercent = 10;

    uint256 public decayPeriod = 10512000;
    uint256 public decayPercent = 40;

    uint256[] public poolAllocation = [34,33,33];

    mapping(uint256 => mapping(uint256 => uint256)) public miningAmountList;
    uint256 public initialMiningAmount = 3.80517504 ether;
    mapping(uint256 => uint256) public firstBlock;
    mapping(uint256 => uint256) public latestBlock;

    mapping(uint256 => uint256) public pool;

    event Mined(uint256 blockNum, uint256 bcoinAmount);

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        _bcoinContract = IERC20(getContractAddress("bcoin"));
        coder = getContractAddress("coder");
        miningAmountList[0][0] = initialMiningAmount;
        miningAmountList[1][0] = initialMiningAmount;
        miningAmountList[2][0] = initialMiningAmount;
    }

    function mining(uint256 index) public onlyOfferMain returns (uint256){
        uint256 miningAmount = _miningAmount(index);

        if (pool[index] < miningAmount) {
            miningAmount = pool[index];
        }

        if (miningAmount > 0) {
            pool[index] = pool[index].sub(miningAmount);
            emit Mined(block.number, miningAmount);
            if(miningAmountList[index][4] == 0){
                uint256 coderAmount = miningAmount.mul(coderPercent).div(100);
                require(_bcoinContract.transfer(coder, coderAmount), "mining: transfer fail");
                require(_bcoinContract.transfer(msg.sender, miningAmount.sub(coderAmount)), "mining: transfer failed");
                miningAmount = miningAmount.sub(coderAmount);
            }else{
                require(_bcoinContract.transfer(msg.sender, miningAmount), "mining: transfer failed");
            }
        }
        latestBlock[index] = block.number;
        return miningAmount;
    }

    function withdrawAllBcoin(uint256 index,address account) public onlyAdmin {
        require(index <= 2,"mining: index lt 2");
        require(account != address(0x0),"mining: account is not Invalid");
        uint256 amount = pool[index] < _bcoinContract.balanceOf(address(this)) ? pool[index]: _bcoinContract.balanceOf(address(this));
        require(_bcoinContract.transfer(account, amount), "mining: transfer failed");
        pool[index] = 0;
    }

    function depositBcoin(uint256 index,uint256 amount) public onlyAdmin {
        _depositBcoin(index,amount);
    }

    function depositBcoinInner(uint256 index,uint256 amount) public onlyOfferMain {
        _depositBcoin(index,amount);
    }

    function depositBcoinAll(uint256 amount) public onlyPOIStoreAndTokenAuction  {
        for(uint256 i = 0; i < poolAllocation.length; i++){
            _depositBcoin(i,amount.mul(poolAllocation[i]).div(uint256(100)));
        }
    }

    function _depositBcoin(uint256 index,uint256 amount) private {
        require(_bcoinContract.transferFrom(msg.sender,address(this),amount),"mining: transferFrom failed");
        if(pool[index] == 0){
            firstBlock[index] = block.number;
            latestBlock[index] = block.number;
        }
        pool[index] = pool[index].add(amount);
    }

    function _miningAmount(uint256 index) private returns (uint256) {
        uint256 decayPeriodNum = block.number.sub(firstBlock[index]).div(decayPeriod);
        uint256 miningAmountPerBlock = _singleBlockMining(index,decayPeriodNum);
        return miningAmountPerBlock.mul(block.number.sub(latestBlock[index]));
    }

    function _singleBlockMining(uint256 index,uint256 decayPeriodNum) private returns (uint256){
        if(miningAmountList[index][decayPeriodNum] == 0){
            miningAmountList[index][decayPeriodNum] = pool[index].mul(decayPercent).div(100).div(decayPeriod);
        }
        return miningAmountList[index][decayPeriodNum];
    }
}
