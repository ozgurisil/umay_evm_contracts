// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract Users is Ownable{
    modifier onlyBy (address _address) {
        require(msg.sender == _address, 'Not authorized');
        _;
    }

    address public protocolTokenContract;
    address public chatsContract;
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
    }
    event RegisterUser(string userName);
    event SetStatus(address wallet, string userName, statuses status);
    mapping (address => User) public users;

    function getUserByAddress(address _address) public view returns (User memory) {
        return users[_address];
    }

    function setTokenAddress(address _address) public onlyOwner {
        protocolTokenContract = _address;
    }

    function setChatsAddress(address _address) public onlyOwner {
        chatsContract = _address;
    }

    function register(string calldata userName, uint birthDate, genders gender, uint fee) public {
        users[msg.sender] = User(userName, birthDate, gender, statuses.unknown, fee, 0, 0);
        emit RegisterUser(userName);
    }

    function setStatus(statuses status) public {
        // User storage user = users[msg.sender]; -- this is expensive. converting it to memory makes a copy!
        users[msg.sender].status = status;
        emit SetStatus(msg.sender, users[msg.sender].userName, users[msg.sender].status);
    }

    function getUserFee(address _wallet) public view returns (uint) {
        return users[_wallet].fee;
    }

    function deposit(uint _amount) public {
        IERC20 token = IERC20(protocolTokenContract);
        require(token.balanceOf(msg.sender) >= _amount, 'Not enought balance');
        token.transferFrom(msg.sender, address(this), _amount);
        users[msg.sender].depositBalance += _amount;
    }

    function withdraw(uint _amount) public {
        require(users[msg.sender].depositBalance - users[msg.sender].blockedAmount >= _amount, 'Not enough balance');
        IERC20 token = IERC20(protocolTokenContract);
        token.transfer(msg.sender, _amount);
        users[msg.sender].depositBalance += _amount;
    }

    function blockDeposit(address _address, uint _amount) onlyBy(chatsContract) public {
        require(users[_address].depositBalance >= _amount, 'Not enough balance');
        users[_address].blockedAmount += _amount;
    }

    function claim(address _address, uint _amount) onlyBy(chatsContract) public {
        IERC20 token = IERC20(protocolTokenContract);
        token.transfer(_address, _amount);
    }
}
