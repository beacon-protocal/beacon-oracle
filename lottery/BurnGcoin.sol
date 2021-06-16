// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../access/AccessController.sol";
import "../token/GCOIN.sol";

contract BurnGcoin is AccessController{

    IGCOIN private _gcoin;

    constructor(address config) public AccessController(config) {
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
        _gcoin = IGCOIN(getContractAddress("gcoin"));
    }

    function burn(address account,uint256 amount) public onlyElaLottery returns (bool){
        return _gcoin.burn(account,amount);
    }

    function setLotteryAddress(address contractAddress) public onlyAdmin{
        addLottery(contractAddress);
    }
}
