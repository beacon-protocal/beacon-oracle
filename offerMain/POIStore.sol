// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../access/AccessController.sol";
import "../lib/SafeMath.sol";
import "../lib/SafeERC20.sol";
import "../lib/Address.sol";
import "../token/IERC20.sol";
import {ITokenPairData}  from "../auction/TokenPairData.sol";
import {IBonusData} from "../bonus/BonusData.sol";
import {IHToken} from "../token/HToken.sol";
import "../token/POI.sol";
import "./Mining.sol";
import "./HTokenMining.sol";

contract POIStore is AccessController {
    using SafeMath for uint256;

    //key price value level
    mapping(uint256 => uint256) public priceLevel;
    uint256[] private _prices = [20 ether,40 ether,80 ether];
    uint256 public effectBlock = 864000;

    POI private _poiContract;
    IERC20 private _bcoinContract;
    ITokenPairData private _tokenPairDataContract;
    Mining private _miningContract;
    HTokenMining private _hTokenMining;



    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _poiContract = POI(getContractAddress("poi"));
        _bcoinContract = IERC20(getContractAddress("bcoin"));
        _tokenPairDataContract = ITokenPairData(getContractAddress("tokenPairData"));
        _miningContract = Mining(getContractAddress("mining"));
        _hTokenMining = HTokenMining(getContractAddress("hTokenMining"));
        _initAWarrantConfig();
    }

    function _initAWarrantConfig() internal {
        for(uint256 i=0;i<3;i++){
            uint256 level = i.add(1);
            priceLevel[_prices[i]]=level;
        }
    }

    //购买token通证
    function buyPOI(address to,address token,uint256 price) public whenNotPaused {
        require(priceLevel[price]!=0,"POIStore: POI price does not meet asset span");
        address hTokenAddress = _tokenPairDataContract.getTokenPair(token);
        if (hTokenAddress == address(_bcoinContract)) {
            require(_bcoinContract.transferFrom(msg.sender, address(this), price), "POIStore:payPOI: bcoin transfer failed");
            //进行授权
            require(_bcoinContract.approve(address(_miningContract), price),"POIStore:payPOI: approve fail");
            _miningContract.depositBcoinAll(price);
        } else {
            require(_tokenPairDataContract.isHToken(hTokenAddress),"POIStore: not exist of hTokenAddress");
            IHToken hToken = IHToken(hTokenAddress);
            require(hToken.approve(address(_hTokenMining), price), "POIStore:payPOI: hToken approve failed");
            _hTokenMining.depositInner(token,price);
        }
        _poiContract.create(to,token,priceLevel[price],effectBlock);
    }


    function setPriceLevel(uint256 price, uint256 level) public onlyAdmin {
        priceLevel[price] = level;
    }
}
