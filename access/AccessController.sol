// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.6.0;

import "../lib/EnumerableSet.sol";
import "./Configuration.sol";

contract AccessController {
    using EnumerableSet for EnumerableSet.AddressSet;

    Configuration private _config;

    EnumerableSet.AddressSet private _gameAddress;

    EnumerableSet.AddressSet private _lotteryAddress;

    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);
    event AdminGranted(address indexed contractAddress);


    event ConfigurationChanged(address indexed origin, address indexed config);
    constructor(address config) public {
        _config = Configuration(config);
        _paused = false;
    }

    function changeConfig(address config) public virtual onlyAdmin returns (bool){
        emit ConfigurationChanged(address(_config), config);
        _config = Configuration(config);
        _initInstanceVariables();
        return true;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "AccessController: only allow EOA access");
        _;
    }

    modifier onlyAdmin() {
        require(_config.isAdmin(msg.sender), "AccessController: only allow admin access");
        _;
    }

    modifier onlyOfferMain(){
        require((_config.getContractAddress("offerMain") == msg.sender
            || _config.getContractAddress("elaOfferMain") == msg.sender
            || _config.getContractAddress("ethOfferMain") == msg.sender), "AccessController: only allow offerMain access");
        _;
    }

    modifier onlyBonus(){
        require(_config.getContractAddress("bonus") == msg.sender, "AccessController: only allow bonus access");
        _;
    }

    modifier onlyTokenAuction(){
        require(_config.getContractAddress("tokenAuction") == msg.sender, "AccessController: only allow offerMain access");
        _;
    }

    modifier onlyHTokenMining(){
        require(_config.getContractAddress("hTokenMining") == msg.sender, "AccessController: only allow hTokenMining access");
        _;
    }

    modifier onlyPriceService(){
        require(_config.getContractAddress("priceService") == msg.sender, "AccessController: only allow priceService access");
        _;
    }

    modifier onlyPOIStore(){
        require(_config.getContractAddress("POIStore") == msg.sender, "AccessController: only allow POIStore access");
        _;
    }

    modifier onlyPOIStoreAndOfferMain(){
        require(_config.getContractAddress("POIStore") == msg.sender
                ||_config.getContractAddress("offerMain") == msg.sender
                || _config.getContractAddress("elaOfferMain") == msg.sender
                || _config.getContractAddress("ethOfferMain") == msg.sender, "AccessController: only allow POIStore and offerMain access");
        _;
    }

    modifier onlyPOIStoreAndTokenAuction(){
        require(_config.getContractAddress("POIStore") == msg.sender
        ||_config.getContractAddress("tokenAuction") == msg.sender, "AccessController: only allow POIStore and tokenAuction access");
        _;
    }

    modifier onlyStakedBonus(){
        require(_config.getContractAddress("stakedBonus") == msg.sender, "AccessController: only allow POIStore access");
        _;
    }

    modifier onlyGame() {
        require(_config.getContractAddress("game") == msg.sender, "AccessController: only allow game access");
        _;
    }

    modifier onlyLucky() {
        require(_gameAddress.contains(msg.sender), "AccessController: only allow lucky access");
        _;
    }

    modifier onlyElaLottery() {
        require(_lotteryAddress.contains(msg.sender), "AccessController: only allow elaLottery access");
        _;
//        require(_config.getContractAddress('elaLottery') == msg.sender
//        || _config.getContractAddress("bcoinLottery") == msg.sender, "AccessController: only allow elaLottery access");
//        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function getConfiguration() internal view returns (address){
        return address(_config);
    }

    function getContractAddress(string memory name) public view returns (address){
        return _config.getContractAddress(name);
    }


    function paused() public view returns (bool) {
        return _paused;
    }

    function addAdmin(address account) public onlyAdmin {
        _config.addAdmin(account);
    }

    function revokeAdmin(address account) public onlyAdmin {
        _config.revokeAdmin(account);
    }

    function setPause(bool isPause) public onlyAdmin{
        if(isPause){
            _pause();
        }else{
            _unpause();
        }
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    function _initInstanceVariables() internal virtual {}

    function addGames(address contractAddress) internal virtual {
        if (_gameAddress.add(contractAddress)) {
            emit AdminGranted(contractAddress);
        }
    }

    function addLottery(address contractAddress) internal virtual {
        if (_lotteryAddress.add(contractAddress)) {
            emit AdminGranted(contractAddress);
        }
    }
}
