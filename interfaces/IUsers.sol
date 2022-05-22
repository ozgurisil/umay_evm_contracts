// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


interface IUsers {
    function getUserFee (address _address) external returns (uint fee);
}
