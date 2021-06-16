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

interface IPriceService{

    struct PaymentInfo{
        uint256 index;
        address token;
        address owner;
        uint256 amount;
        uint256 blockNum;
    }

    event Payment(uint256 indexed index, address indexed token, address owner, uint256 amount, uint256 blockNum);

    function showPoiAndPayForInquirePrice(uint256 index,address token, uint256 amountUSDT,uint256 tokenId) external;

    function payForInquirePrice(uint256 index,address token, uint256 amountUSDT) external;

    function inquireLatestPrice(uint256 index,address token) external view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum);

    function setLevelCost(uint256 level, uint256 cost) external;

    function getLatestPriceList(uint256 index, address token, uint256 num) external view returns (string memory result,uint256 lastConfirmedBlock);

    function getPaymentRecord() external view returns(PaymentInfo[] memory);


}

interface IPriceData {
    struct Price {
        uint256 ethAmount;
        uint256 erc20Amount;
        uint256 frontBlock;
        address priceOwner;
        uint256 time;
    }

    struct TokenInfo {
        mapping(uint256 => Price) prices;         // block number => Offer
        uint256 latestOfferBlock;
    }

    //    function addPriceCost(address token) external;

    function addPrice(address token, uint256 ethAmount, uint256 erc20Amount, uint256 endBlock, address account) external;

    function changePrice(address token, uint256 ethAmount, uint256 erc20Amount, uint256 endBlock) external;

    function inquireLatestPrice(address token) external view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum);

    function inquireLatestPriceFree(address token) external view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum);

    function inquireLatestPriceInner(address token) external view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum);

    function inquirePriceForBlock(address token, uint256 blockNum) external view returns (uint256 ethAmount, uint256 erc20Amount);

    function getLatestPriceList(address token, uint256 num) external view returns (string memory,uint256);
}

contract PriceService is IPriceService, AccessController {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 private _bcoinContract;
    IBonusData private _bonusDataContract;
    ITokenPairData private _tokenPairDataContract;
    IERC20 private _contractUSDT;
    IPriceData private _priceData;
    IPriceData private _elaPriceData;
    IPriceData private _ethPriceData;
    POI private _poiContract;


    mapping(uint256 => uint256) public levelCost;
    //主网husd 精度为8位
    uint256[] private _cost = [5000000,2000000,500000];
    uint256 public normalCost = 10000000;
    uint256 public hTokenPercent = 80;
    mapping(uint256 => mapping(address => mapping(address => uint256))) paymentInformation;
    PaymentInfo[] private paymentRecord;

    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _bcoinContract = IERC20(getContractAddress("bcoin"));
        _tokenPairDataContract = ITokenPairData(getContractAddress("tokenPairData"));
        _bonusDataContract = IBonusData(getContractAddress("bonusData"));
        _contractUSDT = IERC20(getContractAddress("husd"));
        _priceData = IPriceData(getContractAddress("priceData"));
        _elaPriceData = IPriceData(getContractAddress("elaPriceData"));
        _ethPriceData = IPriceData(getContractAddress("ethPriceData"));
        _poiContract = POI(getContractAddress("poi"));
        _initAWarrantConfig();
    }

    function _initAWarrantConfig() internal {
        for(uint256 i=0;i<3;i++){
            uint256 level = i.add(1);
            levelCost[level]=_cost[i];
        }
    }

    function showPoiAndPayForInquirePrice(uint256 index,address token, uint256 amountUSDT,uint256 tokenId) public override whenNotPaused {
        //判断tokenId是否存在
        require(_poiContract.exists(tokenId),"priceService: poi tokenId not exist");
        //判断token是否为本人
        require(msg.sender == _poiContract.ownerOf(tokenId),"priceService: payForInquirePrice of tokenId that is not own");
        (address poiToken,uint256 level, uint256 endBlock,bool activation) = _poiContract.getWarrant(tokenId);
        //判断token是否为询价token
        require(token == poiToken,"priceService: poi token is incorrect");
        //判断poi是否激活
        require(activation,"priceService:poi is not activated");
        //判断poi是否过期
        require(block.number < endBlock,"priceService:poi expired");
        //获得poi等级
        uint costUSDT = levelCost[level];
        require(amountUSDT >= costUSDT,"priceData: less than least cost");
        uint256 ethAmount;
        uint256 erc20Amount;
        uint256 blockNum;
        (ethAmount, erc20Amount, blockNum) = _getPriceDataByIndex(token,index);
        require(blockNum > 0, "priceData: no confirmed price;");

        address hToken = _tokenPairDataContract.getTokenPair(token);

        require(_contractUSDT.transferFrom(msg.sender,address(this),costUSDT),"priceData: transfer failed");
        require(_contractUSDT.approve(address(_bonusDataContract),costUSDT),"priceData:BonusData: approve failed");
        if (hToken == address(_bcoinContract)) {
            _bonusDataContract.depositUSDT(address(_bcoinContract),address(this),costUSDT);
        } else {
            _bonusDataContract.depositUSDT(address(_bcoinContract),address(this),costUSDT.sub(costUSDT.mul(hTokenPercent).div(100)));
            _bonusDataContract.depositUSDT(hToken,address(this),costUSDT.mul(hTokenPercent).div(100));
        }
        paymentInformation[index][token][msg.sender] = blockNum;
        paymentRecord.push(PaymentInfo(index,token,msg.sender,costUSDT,blockNum));
        emit Payment(index,token,msg.sender,costUSDT,blockNum);
    }

    function payForInquirePrice(uint256 index,address token, uint256 amountUSDT) public override whenNotPaused {
        uint256 costUSDT = normalCost;
        require(amountUSDT >= costUSDT,"priceData: less than least cost");
        uint256 ethAmount;
        uint256 erc20Amount;
        uint256 blockNum;
        (ethAmount, erc20Amount, blockNum) = _getPriceDataByIndex(token,index);
        require(blockNum > 0, "priceData: no confirmed price;");

        address hToken = _tokenPairDataContract.getTokenPair(token);

        require(_contractUSDT.transferFrom(msg.sender,address(this),costUSDT),"priceData: transfer failed");
        require(_contractUSDT.approve(address(_bonusDataContract),costUSDT),"priceData:BonusData: approve failed");
        if (hToken == address(_bcoinContract)) {
            _bonusDataContract.depositUSDT(address(_bcoinContract),address(this),costUSDT);
        } else {
            _bonusDataContract.depositUSDT(address(_bcoinContract),address(this),costUSDT.sub(costUSDT.mul(hTokenPercent).div(100)));
            _bonusDataContract.depositUSDT(hToken,address(this),costUSDT.mul(hTokenPercent).div(100));
        }
        paymentInformation[index][token][msg.sender] = blockNum;
        paymentRecord.push(PaymentInfo(index,token,msg.sender,costUSDT,blockNum));
        emit Payment(index,token,msg.sender,costUSDT,blockNum);
    }

    function inquireLatestPrice(uint256 index, address token) public view override returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum){
        blockNum = paymentInformation[index][token][msg.sender];
        require(blockNum > 0,"priceData: no payment");
        (ethAmount,erc20Amount) = _getPriceDataForBlockByIndex(token,blockNum,index);
        return (ethAmount,erc20Amount,blockNum);
    }


    function getLatestPriceList(uint256 index, address token, uint256 num) public view override onlyEOA returns (string memory result,uint256 lastConfirmedBlock){
        if(index == 0){
            (result, lastConfirmedBlock) = _priceData.getLatestPriceList(token,num);
        }else if(index == 1){
            (result, lastConfirmedBlock) = _elaPriceData.getLatestPriceList(token,num);
        }else {
            (result, lastConfirmedBlock) = _ethPriceData.getLatestPriceList(token,num);
        }
        return (result, lastConfirmedBlock);
    }


    function setLevelCost(uint256 level, uint256 cost) public override onlyAdmin {
        levelCost[level] = cost;
    }

    function getPaymentRecord() public view override returns(PaymentInfo[] memory){
        return paymentRecord;
    }


    function _getPriceDataByIndex(address token,uint256 index) private view returns (uint256 ethAmount, uint256 erc20Amount, uint256 blockNum) {
        if(index == 0){
            (ethAmount, erc20Amount, blockNum) = _priceData.inquireLatestPrice(token);
        }else if(index == 1){
            (ethAmount, erc20Amount, blockNum) = _elaPriceData.inquireLatestPrice(token);
        }else {
            (ethAmount, erc20Amount, blockNum) = _ethPriceData.inquireLatestPrice(token);
        }
        return (ethAmount, erc20Amount, blockNum);
    }

    function _getPriceDataForBlockByIndex(address token,uint256 blockNum,uint256 index) private view returns (uint256 ethAmount, uint256 erc20Amount) {
        if(index == 0){
            (ethAmount, erc20Amount) = _priceData.inquirePriceForBlock(token,blockNum);
        }else if(index == 1){
            (ethAmount, erc20Amount) = _elaPriceData.inquirePriceForBlock(token,blockNum);
        }else {
            (ethAmount, erc20Amount) = _ethPriceData.inquirePriceForBlock(token,blockNum);
        }
        return (ethAmount, erc20Amount);
    }
}
