// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/Address.sol";
import "../lib/Strings.sol";
import "../lib/SafeERC20.sol";

contract OfferData is AccessController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Offer {
        address owner;
        bool isDeviate;
        address token;

        uint256 ethAmount;
        uint256 erc20Amount;
        uint256 remainingEthAmount;
        uint256 remainingERC20Amount;

        uint256 blockNum;
        uint256 miningFee;
    }

    Offer[] private _offers;
    //erc20 => offers
    mapping(address => uint256[]) private _erc20OffersIndex;
    //erc20 => account => offers;
    mapping(address => mapping(address => uint256[])) private _erc20AccountOfferIndex;
    //erc20 => accounts;
    mapping(address => address[]) private _erc20IndexAccounts;

    uint256 public blockLimit = 100;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
    }

    function getPrice(uint256 index) public view returns (string memory){
        require(index < _offers.length, "OfferData: index overflow");
        return _convertOfferToString(_offers[index], index);
    }

    function getOffer(uint256 index) public view returns (address owner,bool isDeviate,address token,uint256 ethAmount,
        uint256 erc20Amount,uint256 remainingEthAmount,uint256 remainingERC20Amount,uint256 blockNum,uint256 miningFee){
        require(index < _offers.length, "OfferData: index overflow");
        Offer memory targetOffer = _offers[index];
        return (targetOffer.owner,targetOffer.isDeviate,targetOffer.token,targetOffer.ethAmount,targetOffer.erc20Amount,
            targetOffer.remainingEthAmount,targetOffer.remainingERC20Amount,targetOffer.blockNum,targetOffer.miningFee);
    }

    function list(uint256 offset, uint256 pageCount) public view returns (string memory, uint256){
        string memory result;
        require(offset >= 0 && offset <= _offers.length, "OfferData: invalid offset");

        for (uint i = offset; i < _offers.length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            result = Strings.concat(result, _convertOfferToString(_offers[i], i));
        }
        return (result, _offers.length);
    }


    function getPriceCount() public view returns (uint256){
        return _offers.length;
    }


    function getErc20PriceList(address erc20,uint256 offset, uint256 pageCount) public view returns (string memory, uint256){
        string memory result;
        require(offset >= 0 && offset <= _erc20OffersIndex[erc20].length, "OfferData: invalid offset");
        for (uint i = offset; i < _erc20OffersIndex[erc20].length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            uint index = _erc20OffersIndex[erc20][i];
            result = Strings.concat(result,_convertOfferToString(_offers[index],index));
        }
        return (result, _erc20OffersIndex[erc20].length);
    }

    function getErc20PriceCount(address erc20) public view returns (uint256){
        return _erc20OffersIndex[erc20].length;
    }

    function queryToBeConfirmed(address erc20, uint256 searchCount, uint256 maxReturnCount, address owner) public view returns (string memory){
        string memory result;
        Offer memory targetOffer;
        uint256 curIndex = _erc20OffersIndex[erc20].length;
        uint256 offset = maxReturnCount;
        while (curIndex > 0 && searchCount >0 && maxReturnCount >0){
            targetOffer = _offers[_erc20OffersIndex[erc20][curIndex-1]];
            if((!_isConfirmed(targetOffer.blockNum)) || (targetOffer.owner == owner && (targetOffer.ethAmount != 0 || targetOffer.erc20Amount != 0))){
                if (offset != maxReturnCount) {
                    result = Strings.concat(result, ";");
                }
                result = Strings.concat(result, _convertOfferToString(targetOffer, _erc20OffersIndex[erc20][curIndex-1]));
                maxReturnCount--;
            }
            searchCount--;
            curIndex--;
        }
        return result;
    }

    //获得erc20 账户个数
    function getOfferAccountCount(address erc20) public view returns (uint256){
        return _erc20IndexAccounts[erc20].length;
    }
    //获得erc20 账户列表
    function getOfferAccountList(address erc20,uint256 offset, uint256 pageCount) public view returns (string memory){
        string memory result;
        require(offset >= 0 && offset <= _erc20IndexAccounts[erc20].length, "OfferData: invalid offset");
        for (uint i = offset; i < _erc20IndexAccounts[erc20].length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            Strings.concat(result,Strings.parseAddress(_erc20IndexAccounts[erc20][i]));
        }
        return result;
    }
    //获得我的报价个数
    function getErc20AccountPriceCount(address erc20, address account) public view returns (uint256){
        return _erc20AccountOfferIndex[erc20][account].length;
    }
    //获得我的报价列表
    function getErc20AccountPriceList(address erc20, address account, uint256 offset, uint256 pageCount) public view returns (string memory, uint256){
        string memory result;
        require(offset >= 0 && offset <= _erc20AccountOfferIndex[erc20][account].length, "OfferData: invalid offset");
        for (uint i = offset; i < _erc20AccountOfferIndex[erc20][account].length && i < offset.add(pageCount); i++) {
            if (i != offset) {
                result = Strings.concat(result, ";");
            }
            uint index = _erc20AccountOfferIndex[erc20][account][i];
            result = Strings.concat(result,_convertOfferToString(_offers[index],index));
        }
        return (result, _erc20AccountOfferIndex[erc20][account].length);
    }

    function changeOffer(uint256 index,uint256 ethAmount, uint256 erc20Amount,
        uint256 remainingEthAmount,uint256 remainingERC20Amount,uint256 miningFee) public onlyOfferMain{
        require(index < _offers.length, "OfferData: index overflow");
        Offer storage targetOffer = _offers[index];
        targetOffer.ethAmount = ethAmount;
        targetOffer.erc20Amount = erc20Amount;
        targetOffer.remainingEthAmount = remainingEthAmount;
        targetOffer.remainingERC20Amount = remainingERC20Amount;
        targetOffer.miningFee = miningFee;
    }

    function createOffer(uint256 ethAmount, uint256 erc20Amount, address erc20, uint256 fee, bool deviation,address owner,uint256 blockNum) public onlyOfferMain returns(uint256) {
        uint256 curIndex = _offers.length;
        _offers.push(Offer(owner, deviation, erc20, ethAmount, erc20Amount, ethAmount, erc20Amount, blockNum, fee));
        _erc20OffersIndex[erc20].push(curIndex);
        if(_erc20AccountOfferIndex[erc20][owner].length == 0){
            _erc20IndexAccounts[erc20].push(owner);
        }
        _erc20AccountOfferIndex[erc20][owner].push(curIndex);
        return curIndex;
    }

    function _isConfirmed(uint256 blockNum) public view returns (bool){
        return block.number.sub(blockNum) > blockLimit;
    }

    function _convertOfferToString(Offer memory targetOffer, uint256 index) private pure returns (string memory){
        string memory offerString;
        offerString = Strings.concat(offerString, Strings.parseInt(index));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseAddress(targetOffer.owner));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseBoolean(targetOffer.isDeviate));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseAddress(targetOffer.token));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.ethAmount));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.erc20Amount));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.remainingEthAmount));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.remainingERC20Amount));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.blockNum));
        offerString = Strings.concat(offerString, ",");
        offerString = Strings.concat(offerString, Strings.parseInt(targetOffer.miningFee));
        return offerString;
    }
}
