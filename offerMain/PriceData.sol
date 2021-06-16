// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/Strings.sol";
import {IPriceData} from "./PriceService.sol";

contract PriceData is IPriceData, AccessController {
    using SafeMath for uint256;

    mapping(address => TokenInfo) private _tokenInfo;
    mapping(address => bool) private _offerMainMapping;

    event LatestPriceInquired(address token, address account);
    event LatestPriceListInquired(address token, address account, uint256 num);

    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
    }

    function addPrice(address token, uint256 ethAmount, uint256 erc20Amount, uint256 endBlock, address account) public override onlyOfferMain {
        TokenInfo storage tokenInfo = _tokenInfo[token];
        Price storage price = tokenInfo.prices[endBlock];
        price.ethAmount = price.ethAmount.add(ethAmount);
        price.erc20Amount = price.erc20Amount.add(erc20Amount);
        price.priceOwner = account;
        price.time = now;

        if (endBlock != tokenInfo.latestOfferBlock) {
            price.frontBlock = tokenInfo.latestOfferBlock;
            tokenInfo.latestOfferBlock = endBlock;
        }
    }

    function changePrice(address token, uint256 ethAmount, uint256 erc20Amount, uint256 endBlock) public override onlyOfferMain {
        TokenInfo storage tokenInfo = _tokenInfo[token];
        Price storage price = tokenInfo.prices[endBlock];
        price.erc20Amount = price.erc20Amount.sub(erc20Amount);
        price.ethAmount = price.ethAmount.sub(ethAmount);
    }


    function inquireLatestPrice(address token) public view override onlyPriceService returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum){
        (ethAmount, erc20Amount, blockNum) = _getLatestPrice(token);
        return (ethAmount, erc20Amount,blockNum);
    }

    function inquireLatestPriceFree(address token) public view override onlyEOA returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum){
        return _getLatestPrice(token);
    }

    function inquireLatestPriceInner(address token) public view override onlyOfferMain returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum){
        return _getLatestPrice(token);
    }

    function inquirePriceForBlock(address token, uint256 blockNum) public view override onlyPriceService returns (uint256 ethAmount, uint256 erc20Amount){
        TokenInfo storage tokenInfo = _tokenInfo[token];
        return (tokenInfo.prices[blockNum].ethAmount, tokenInfo.prices[blockNum].erc20Amount);
    }

    function getLatestPriceList(address token, uint256 num) public view override onlyPriceService returns (string memory, uint256) {
        string memory result;
        TokenInfo storage tokenInfo = _tokenInfo[token];
        uint256 lastBlock = tokenInfo.latestOfferBlock;
        while (lastBlock > 0 && (lastBlock >= block.number || tokenInfo.prices[lastBlock].ethAmount == 0)) {
            lastBlock = tokenInfo.prices[lastBlock].frontBlock;
        }
        if(lastBlock == 0){
            return (result,0);
        }
        uint256 lastConfirmedBlock = lastBlock;
        for (uint256 i = 0; i < num; i++) {
            if(i!=0){
                result = Strings.concat(result, ";");
            }
            Price memory price = tokenInfo.prices[lastBlock];
            result = Strings.concat(result, _convertOfferToString(price));
            lastBlock = price.frontBlock;
            if (lastBlock == 0) {
                break;
            }
        }
        return (result,lastConfirmedBlock);
    }

    function _getLatestPrice(address token) private view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum){
        TokenInfo storage tokenInfo = _tokenInfo[token];
        uint256 latestBlock = tokenInfo.latestOfferBlock;
        while (latestBlock > 0 && (latestBlock >= block.number || tokenInfo.prices[latestBlock].ethAmount == 0)) {
            latestBlock = tokenInfo.prices[latestBlock].frontBlock;
        }
        if (latestBlock == 0) {
            return (0, 0, 0);
        }
        Price memory price = tokenInfo.prices[latestBlock];

        return (price.ethAmount, price.erc20Amount, latestBlock);
    }

    function _convertOfferToString(Price memory price) private pure returns (string memory){
        string memory priceString;
        priceString = Strings.concat(priceString, Strings.parseInt(price.ethAmount));
        priceString = Strings.concat(priceString, ",");
        priceString = Strings.concat(priceString, Strings.parseInt(price.erc20Amount));
        priceString = Strings.concat(priceString, ",");
        priceString = Strings.concat(priceString, Strings.parseInt(price.time));
        return priceString;
    }
}
