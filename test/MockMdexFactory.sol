// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "../mdex/IMdexFactory.sol";
import "../lib/SafeMath.sol";
import "./MockToken.sol";
pragma experimental ABIEncoderV2;

contract MockMdexFactory is IMdexFactory {
    using SafeMath for uint256;
    address private _feeTo;
    address private _feeToSetter;
    uint256 private _feeToRate;
    bytes32 private _initCodeHash;
    bool private initCode = false;

    mapping(address => mapping(address => address)) private _getPair;
    address[] private _allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address feeToSetter) public {
        _feeToSetter = feeToSetter;
    }

    function feeTo() external override view returns (address){
        return _feeTo;
    }

    function feeToSetter() external override view returns (address){
        return _feeToSetter;
    }

    function feeToRate() external override view returns (uint256){
        return _feeToRate;
    }

    function getPair(address tokenA, address tokenB) external override view returns (address pair){
        return _getPair[tokenA][tokenB];
    }

    function allPairs(uint index) public override view returns (address pair){
        return _allPairs[index];
    }

    function allPairsLength() external override view returns (uint) {
        return _allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'MdexSwapFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MdexSwapFactory: ZERO_ADDRESS');
        require(_getPair[token0][token1] == address(0), 'MdexSwapFactory: PAIR_EXISTS');
        MockToken mockToken = new MockToken('LP','LP',18);
        mockToken.transfer(msg.sender,200000000 ether);
        pair = address(mockToken);
        _getPair[token0][token1] = pair;
        _getPair[token1][token0] = pair;
        // populate mapping in the reverse direction
        _allPairs.push(pair);
        emit PairCreated(token0, token1, pair, _allPairs.length);
    }

    function setFeeTo(address feeToP) public override {
        require(msg.sender == _feeToSetter, 'MdexSwapFactory: FORBIDDEN');
        _feeTo = feeToP;
    }

    function setFeeToSetter(address feeToSetterP) public override {
        require(msg.sender == _feeToSetter, 'MdexSwapFactory: FORBIDDEN');
        require(feeToSetterP != address(0), "MdexSwapFactory: FeeToSetter is zero address");
        _feeToSetter = feeToSetterP;
    }

    function setFeeToRate(uint256 _rate) external override {
        require(msg.sender == _feeToSetter, 'MdexSwapFactory: FORBIDDEN');
        require(_rate > 0, "MdexSwapFactory: FEE_TO_RATE_OVERFLOW");
        _feeToRate = _rate.sub(1);
    }

    function setInitCodeHash(bytes32 initCodeHash) external override {
        require(msg.sender == _feeToSetter, 'MdexSwapFactory: FORBIDDEN');
        require(initCode == false, "MdexSwapFactory: Do not repeat settings initCodeHash");
        _initCodeHash = initCodeHash;
        initCode = true;
    }

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) public override pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'MdexSwapFactory: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MdexSwapFactory: ZERO_ADDRESS');
    }


    function initCodeHash() public override view returns (bytes32) {
        return keccak256('0');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB) public override view returns (address pair) {
        pair = _getPair[tokenA][tokenB];
    }
    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB) public override view returns (uint reserveA, uint reserveB) {
        return (uint256(tokenA),uint256(tokenB));
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) public override pure returns (uint amountB) {
        require(amountA > 0, 'MdexSwapFactory: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'MdexSwapFactory: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public override view returns (uint amountOut) {
        require(amountIn > 0, 'MdexSwapFactory: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'MdexSwapFactory: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public override view returns (uint amountIn) {
        require(amountOut > 0, 'MdexSwapFactory: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'MdexSwapFactory: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, address[] memory path) public override view returns (uint[] memory amounts) {
        require(path.length >= 2, 'MdexSwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(uint amountOut, address[] memory path) public override view returns (uint[] memory amounts) {
        require(path.length >= 2, 'MdexSwapFactory: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}