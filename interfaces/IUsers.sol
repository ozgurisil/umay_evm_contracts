// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


interface IUsers {
    function getUserFee (address _address) external returns (uint fee);
    function getUserByAddress (address _address) external returns (uint);
    function blockDeposit(address _address, uint _amount) external;
    function unblockDeposit(address _address) external returns (uint);
    function claim(address _address, uint _amount) external;
}
