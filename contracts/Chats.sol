// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUsers.sol";


contract Chats is Ownable {
    address public usersContract;
    address public protocolToken;
    enum Statuses {
        pending,
        started,
        finished,
        canceled,
        feeClaimed
    }
    struct Chat {
        bytes32 id;  // TODO: Redundant field?
        address caller;
        address callee;
        uint startDateTime;
        uint endDateTime;
        uint fee;
        uint lastFeeTimestamp;
        Statuses status;
    }
    event ChatInit(bytes32 id, address caller, address callee, uint fee, address sender);
    event ChatStatusChange(bytes32 id, Statuses status, uint startDateTime, uint EndDateTime, address sender);
    event ChatExtended(bytes32 id);
    mapping (bytes32 => Chat) private chatsMapping;  // Emulating many-to-many relationship between users with a surrogate PK
    Chat[] private chatsArray;

    function setUsersContractAddress (address _address) public onlyOwner {
        usersContract = _address;
    }

    function setTokenAddress(address _address) public onlyOwner {
        protocolToken = _address;
    }

    function getChatByID(bytes32 _id) public view returns (Chat memory) {
        return chatsMapping[_id];
    }

    function startChat(address _caller) public returns (bytes32) {
        uint fee = IUsers(usersContract).getUserFee(msg.sender);
        Chat memory chat = Chat(
            keccak256(abi.encodePacked(msg.sender, _caller, block.timestamp)),
            _caller,
            msg.sender,
            0,
            0,
            fee,
            0,
            Statuses.pending
        );
        chatsArray.push(chat);
        chatsMapping[chat.id] = chat;
        users.setChatId(msg.sender, _caller, chat.id);
        emit ChatInit(chat.id, chat.caller, chat.callee, chat.fee, msg.sender);
        return chat.id;
    }

    function confirmChat(bytes32 _id) public {
        Chat storage chat = chatsMapping[_id];
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.started;
        chat.startDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        IUsers users = IUsers(usersContract);
        users.blockDeposit(msg.sender, chat.fee);
    }

    function finishChat(bytes32 _id) public {
        Chat storage chat = chatsMapping[_id];
        require(msg.sender == chat.caller || msg.sender == chat.callee, 'You cannot finish the chat');
        chat.status = Statuses.finished;
        chat.endDateTime = block.timestamp;
        IUsers users = IUsers(usersContract);
        users.setChatId(chat.caller, chat.callee, '');
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
    }

    function extendChat(bytes32 _id) public {
        Chat storage chat = chatsMapping[_id];
        require(msg.sender == chat.caller || msg.sender == chat.callee, 'You cannot extend the chat');
        IUsers users = IUsers(usersContract);
        users.blockDeposit(msg.sender, chat.fee);
        emit ChatExtended(_id);
    }

    function getUnclaimedFee(bytes32 _id) public view returns (uint) {
        Chat storage chat = chatsMapping[_id];
        uint start;
        uint end;
        if (chat.endDateTime > 0) {
            end = block.timestamp > chat.endDateTime ? chat.endDateTime : block.timestamp;
        } else {
            end = block.timestamp;
        }
        start = chat.lastFeeTimestamp > 0 ? chat.lastFeeTimestamp : chat.startDateTime;
        uint feePerSecond = chat.fee / 3600;
        return feePerSecond * (end - start);
    }

    function claimFee(bytes32 _id) public returns (uint) {
        uint feeToClaim = getUnclaimedFee(_id);
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.finished, 'Chat needs to be finished first');
        IUsers(usersContract).claim(chat.callee, feeToClaim);
        chat.status = Statuses.feeClaimed;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        return feeToClaim;
    }

    function unblockDeposit(bytes32 _id) public returns (uint) {
        Chat storage chat = chatsMapping[_id];
        require (chat.status == Statuses.finished || chat.status == Statuses.feeClaimed, "You can't unblock an unfinished chat");  // TODO: Canceled?
        if (chat.status == Statuses.finished) claimFee(_id);
        return IUsers(usersContract).unblockDeposit(chat.caller);
    }
}
