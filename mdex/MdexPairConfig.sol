// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "./IMdexFactory.sol";
import "../lib/SafeMath.sol";
pragma experimental ABIEncoderV2;

interface IMdexPairConfig {

    struct Pair {
        address tokenA;
        address tokenB;
        address lpToken;
        uint256 ratio;
    }

    //校验lpToken
    function checkLpToken(address lpToken) external returns(bool);
    //获得lpToken分配的收益金额
    function getLpTokenRevenue(address lpToken,uint256 revenue) external view returns(uint256);

    function getLpTokenPairAll() external view returns(Pair[] memory);

    function getLpTokenPair(uint) external view returns(Pair memory);

    function getLpTokenPairLength() external view returns(uint);

    function addLpTokenPair(address tokenA,address tokenB,uint256 ratio) external;

    function updateLpTokenRevenueRatio(address tokenA,address tokenB,uint256 ratio) external;
}

contract MdexPairConfig is AccessController, IMdexPairConfig {
    using SafeMath for uint256;

    Pair[] public lpTokenPair;
    //pair flag
    mapping(address => bool) private _lpTokenFlag;
    //pair => ratio
    mapping(address => uint256) private _lpTokenRatio;

    uint256 private _originalRatio = 30;

    mapping(address => mapping(address => bool)) public tokenFlag;
    mapping(address => mapping(address => uint256)) public tokenIndex;

    IMdexFactory private _mdexFactory;

    constructor(address config) public AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _mdexFactory = IMdexFactory(getContractAddress("mdexFactory"));
    }

    //校验lpToken
    function checkLpToken(address lpToken) public override returns(bool){
        require(lpToken != address(0x0), "MdexPairConfig: lpToken address can not be zero address");
        if(_lpTokenFlag[lpToken]){
            return true;
        }else{
            return _checkLpToken(lpToken);
        }
    }

    //通过lpToken查看收益
    function getLpTokenRevenue(address lpToken,uint256 revenue) public view override returns(uint256){
        require(lpToken != address(0x0), "MdexPairConfig: lpToken address can not be zero address");
        require(revenue != 0, "MdexPairConfig: revenue can not be zero ");
        uint256 ratio = _lpTokenRatio[lpToken];
        return revenue.mul(ratio).div(_originalRatio);
    }

    //添加流动交易对
    function addLpTokenPair(address tokenA,address tokenB,uint256 ratio) public override onlyAdmin{
        require(!tokenFlag[tokenA][tokenB], "MdexPairConfig: TokenPair address can exist");
        uint index = lpTokenPair.length;
        lpTokenPair.push(Pair(tokenA,tokenB,address(0x0),ratio));
        tokenFlag[tokenA][tokenB]=true;
        tokenFlag[tokenB][tokenA]=true;
        tokenIndex[tokenA][tokenB]=index;
        tokenIndex[tokenB][tokenA]=index;
    }

    //更新流动交易对奖金比例
    function updateLpTokenRevenueRatio(address tokenA,address tokenB,uint256 ratio) public override onlyAdmin{
        require(tokenFlag[tokenA][tokenB], "MdexPairConfig: TokenPair address not exist");
        Pair storage pair = lpTokenPair[tokenIndex[tokenA][tokenB]];
        pair.ratio = ratio;
        if(pair.lpToken != address(0x0)){
            _lpTokenRatio[pair.lpToken] = ratio;
        }
    }

    function getLpTokenPairAll() public view override returns(Pair[] memory result){
        result = new Pair[](lpTokenPair.length);
        for (uint256 i = 0; i < lpTokenPair.length; i++) {
            Pair memory pair = _getLpPair(lpTokenPair[i]);
            result[i] = pair;
        }
        return result;
    }

    function getLpTokenPair(uint index) public view override returns(Pair memory){
        return _getLpPair(lpTokenPair[index]);
    }

    function getLpTokenPairLength() public view override returns(uint){
        return lpTokenPair.length;
    }

    function _checkLpToken(address lpToken) private returns(bool result){
        result = false;
        for(uint256 i=0;i<lpTokenPair.length;i++){
            address token = _mdexFactory.getPair(lpTokenPair[i].tokenA,lpTokenPair[i].tokenB);
            if(token == lpToken){
                result = true;
                lpTokenPair[i].lpToken = lpToken;
                _lpTokenFlag[lpToken] = true;
                _lpTokenRatio[lpToken] = lpTokenPair[i].ratio;
                break;
            }
        }
        return result;
    }

    function _getLpPair(Pair memory pair) private view returns(Pair memory){
        Pair memory result;
        address token = pair.lpToken;
        if(token == address(0x0)){
            token = _mdexFactory.getPair(pair.tokenA,pair.tokenB);
        }
        result = Pair(pair.tokenA,pair.tokenB,token,pair.ratio);
        return result;
    }
}
