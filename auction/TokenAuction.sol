// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";
import "../lib/Strings.sol";
import "../token/IERC20.sol";
import "../token/HToken.sol";
import {ITokenPairData} from "./TokenPairData.sol";
import "./Blacklist.sol";

contract TokenAuction is AccessController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private _bcoinContract;
    ITokenPairData private _tokenPairContract;
    Blacklist private _blacklistContract;

    address private _destructionAddress;

    uint256 public duration = 5 days;
    uint256 public miniBcoin = 2000 ether;
    uint256 public miniInterval = 200 ether;
    uint256 public incentivePercent = 50;

    uint256 public tokenNum = 1;

    struct Auction {
        uint256 endTime;
        uint256 bid;
        address bidder;
        uint256 remain;
    }

    mapping(address => Auction) private _auctions;
    address[] private _auctionTokens;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _bcoinContract = IERC20(getContractAddress("bcoin"));
        _tokenPairContract = ITokenPairData(getContractAddress("tokenPairData"));
        _destructionAddress = getContractAddress("destruction");
        _blacklistContract = Blacklist(getContractAddress("blacklist"));
    }

    function start(address token, uint256 amount) whenNotPaused public {
        require((_tokenPairContract.getTokenPair(token) == address(0x0)), "TokenAuction: token already exists");
        require(_auctions[token].endTime == 0, "TokenAuction: token is on sale");
        require(!_tokenPairContract.isBlocked(token), "TokenAuction: token is blocked");
        require(amount >= miniBcoin, "TokenAuction: 'amount' must be greater than 'miniBcoin'");

        require(_bcoinContract.transferFrom(msg.sender, address(this), amount), "TokenAuction: transfer failed");

        IERC20 tokenERC20 = IERC20(token);
        tokenERC20.safeTransferFrom(msg.sender, address(this), 1);
        require(tokenERC20.balanceOf(address(this)) == 1, "TokenAuction: verify token failed");
        tokenERC20.safeTransfer(msg.sender, 1);
        require(tokenERC20.balanceOf(address(this)) == 0, "TokenAuction: verify token failed");


        Auction memory auction = Auction(now.add(duration), amount, msg.sender, amount);
        _auctions[token] = auction;
        _auctionTokens.push(token);
    }

    function bid(address token, uint256 amount) whenNotPaused public {
        Auction storage auction = _auctions[token];
        require(auction.endTime != 0 && now <= auction.endTime, "TokenAuction: auction closed or not started");
        require(amount >= auction.bid.add(miniInterval), "TokenAuction: insufficient amount");

        uint256 excitation = amount.sub(auction.bid).mul(incentivePercent).div(100);
        require(_bcoinContract.transferFrom(msg.sender, address(this), amount), "TokenAuction: transfer failed");
        require(_bcoinContract.transfer(auction.bidder, auction.bid.add(excitation)), "TokenAuction: transfer failed");

        auction.remain = auction.remain.add(amount.sub(auction.bid)).sub(excitation);
        auction.bid = amount;
        auction.bidder = msg.sender;
    }

    function end(address token,string memory tokenSymbol) whenNotPaused public {
        uint256 nowTime = now;
        require(nowTime > _auctions[token].endTime && _auctions[token].endTime != 0, "TokenAuction: token is on sale");
        require(_bcoinContract.transfer(_destructionAddress, _auctions[token].remain), "TokenAuction: transfer failed");
        require(msg.sender == _auctions[token].bidder,"TokenAuction:Only the successful bidder is allowed to operate");
        require(!_blacklistContract.isBlacklist(tokenSymbol), "TokenAuction: symbol not available");
        string memory tokenName = Strings.concat("HToken", _convertIntToString(tokenNum));
        HToken hToken = new HToken(tokenName, tokenSymbol, getConfiguration(), _auctions[token].bidder);
        _blacklistContract.addBlacklistInner(tokenSymbol);
        _tokenPairContract.addTokenPair(token, address(hToken));
        tokenNum = tokenNum.add(1);
        _setTokenIndex(token);
    }

    function getCount() public view returns (uint256){
        return _auctionTokens.length;
    }

    function getTokenAddress(uint256 index) public view returns (address){
        return _auctionTokens[index];
    }

    function getAuctionInfo(address token) public view returns (Auction memory){
        return _auctions[token];
    }

    function changeDuration(uint256 newDuration) public onlyAdmin {
        duration = newDuration;
    }

    function changeMiniBcoin(uint256 newMiniBcoin) public onlyAdmin {
        miniBcoin = newMiniBcoin;
    }
    

    function _setTokenIndex(address token) private {
        _tokenPairContract.enableHtToken(token);
        _tokenPairContract.enableElaToken(token);
        _tokenPairContract.enableEthToken(token);
    }

    function _convertIntToString(uint256 iv) private pure returns (string memory) {
        bytes memory buf = new bytes(64);
        uint256 index = 0;
        do {
            buf[index++] = byte(uint8(iv % 10 + 48));
            iv /= 10;
        } while (iv > 0 || index < 4);
        bytes memory str = new bytes(index);
        for(uint256 i = 0; i < index; ++i) {
            str[i] = buf[index - i - 1];
        }
        return string(str);
    }
}
