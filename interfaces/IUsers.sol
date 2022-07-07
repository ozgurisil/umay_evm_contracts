// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


interface IUsers {
    enum genders {
        male,
        female
    }
    enum statuses {
        available,
        busy,
        unknown
    }
    struct User {
        string userName;
        uint birthDate;
        genders gender;
        statuses status;
        uint fee;
        uint depositBalance;
        uint blockedAmount;
        bytes32 currentChatId;
    }
    function getUserFee (address _address) external returns (uint fee);
    function getUserByAddress (address _address) external view returns (User memory);
    function setChatId(address _caller, address _callee, bytes32 _id) external;
    function blockDeposit(address _address, uint _amount) external;
    function unblockDeposit(address _address, uint exclude) external returns (uint);
    function claim(address[] calldata _addresses, uint[] calldata _amounts) external;
    function callerCanCoverFees(address _caller, address _callee) external view returns (bool);
}
