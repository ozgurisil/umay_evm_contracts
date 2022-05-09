// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


contract Users {
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
    }
    event RegisterUser(string userName);
    event SetStatus(address wallet, string userName, statuses status);
    mapping (address => User) public users;

    function register(string calldata userName, uint birthDate, genders gender, uint fee) public {
        users[msg.sender] = User(userName, birthDate, gender, statuses.unknown, fee);
        emit RegisterUser(userName);
    }

    function setStatus(statuses status) public {
        // User storage user = users[msg.sender]; -- this is expensive. converting it to memory makes a copy!
        users[msg.sender].status = status;
        emit SetStatus(msg.sender, users[msg.sender].userName, users[msg.sender].status);
    }
}
