// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import "../lib/SafeMath.sol";
import "../access/AccessController.sol";
import "../token/IERC20.sol";

interface IStakedLockupData {
    function deposit(address lpToken, address account, uint256 amount) external;

    function withdraw(address lpToken, address account, uint256 amount) external;

    function getAmount(address lpToken, address account) external view returns (uint256);
}

contract StakedLockupData is AccessController, IStakedLockupData {
    using SafeMath for uint256;

    mapping(address => mapping(address => uint256)) _lockupData;

    constructor(address config) public AccessController(config) {
    }

    function deposit(address lpToken, address account, uint256 amount) public override onlyStakedBonus {
        require(IERC20(lpToken).transferFrom(account, address(this), amount), "lockupDate: transfer failed");
        _lockupData[lpToken][account] =_lockupData[lpToken][account].add(amount);
    }

    function withdraw(address lpToken, address account, uint256 amount) public override onlyStakedBonus {
        require(amount <= _lockupData[lpToken][account], "lockupData: Insufficient storage balance");
        _lockupData[lpToken][account] = _lockupData[lpToken][account].sub(amount);
        require(IERC20(lpToken).transfer(account, amount), "lockupData: transfer failed");
    }

    function getAmount(address lpToken, address account) public view override returns (uint256){
        return _lockupData[lpToken][account];
    }
}
