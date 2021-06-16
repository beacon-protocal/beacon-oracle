// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../token/ERC20.sol";

contract MockToken is ERC20 {

    uint256 private _INITIAL_SUPPLY = 200000000 ether;

    constructor(string memory name, string memory symbol,uint8 decimals) public ERC20(name, symbol){
        _mint(msg.sender, _INITIAL_SUPPLY);
        _setupDecimals(decimals);
    }
}
