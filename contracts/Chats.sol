// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUsers.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Chats is Ownable, ReentrancyGuard {
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

    function startChat(address _caller) public nonReentrant returns (bytes32) {
        IUsers users = IUsers(usersContract);
        require(users.getUserByAddress(msg.sender).currentChatId == '' && users.getUserByAddress(_caller).currentChatId == '', 'Cannot start a chat');
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

    function confirmChat(bytes32 _id) public nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.pending, 'Chat status is not "pending"');
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.started;
        chat.startDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        IUsers users = IUsers(usersContract);
        users.blockDeposit(msg.sender, chat.fee);
    }

    function rejectChat(bytes32 _id) public nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.pending, 'Chat status is not "pending"');
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.canceled;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        delete chatsMapping[_id];
    }

    function finishChat(bytes32 _id) public nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.started, 'Chat status is not "started"');
        require(msg.sender == chat.caller || msg.sender == chat.callee, 'You cannot finish the chat');
        chat.status = Statuses.finished;
        chat.endDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        IUsers users = IUsers(usersContract);
        users.setChatId(chat.caller, chat.callee, '');
    }

    function extendChat(bytes32 _id) public nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.started, 'Chat status is not "started"');
        require(msg.sender == chat.caller, 'You cannot extend the chat');
        emit ChatExtended(_id);
        IUsers users = IUsers(usersContract);
        users.blockDeposit(msg.sender, chat.fee);
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

    function claimFee(bytes32 _id) public nonReentrant returns (uint) {
        uint feeToClaim = getUnclaimedFee(_id);
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.finished, 'Chat status is not "finished"');
        chat.status = Statuses.feeClaimed;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        IUsers(usersContract).claim(chat.callee, feeToClaim);
        return feeToClaim;
    }

    function unblockDeposit(bytes32 _id) public nonReentrant returns (uint) {
        Chat storage chat = chatsMapping[_id];
        require (chat.status == Statuses.finished || chat.status == Statuses.feeClaimed, 'Chat status is not "finished" or "feeClaimed"');
        if (chat.status == Statuses.finished) claimFee(_id);
        return IUsers(usersContract).unblockDeposit(chat.caller);
    }
}
