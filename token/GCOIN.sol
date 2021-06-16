// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../lib/SafeMath.sol";
import "./ERC20.sol";
import "../access/AccessController.sol";

interface IGCOIN is IERC20 {
    function mint(address account, uint256 amount) external returns (bool);

    function burn(address account, uint256 amount) external returns (bool);
}
contract GCOIN is IGCOIN, ERC20, AccessController {

    string private _name = "GCOIN";
    string private _symbol = "GCOIN";

    constructor(address config) public ERC20(_name, _symbol) AccessController(config){
        _initInstanceVariables();
    }

    function _initInstanceVariables() internal override {
        super._initInstanceVariables();
    }

    function mint(address account, uint256 amount) external override onlyOfferMain returns (bool) {
        _mint(account, amount);
        return true;
    }

    function burn(address account, uint256 amount) external override onlyGame returns (bool) {
        _burn(account, amount);
        return true;
    }
}

