// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;


contract Chats {
    enum Statuses {
        pending,
        started,
        finished,
        canceled
    }
    struct Chat {
        bytes32 id;  // TODO: Redundant field?
        address caller;
        address callee;
        uint startDateTime;
        uint endDateTime;
        Statuses status;
    }
    event ChatInit(bytes32 id, address caller, address callee, address sender);
    event ChatStatusChange(bytes32 id, Statuses status, uint startDateTime, uint EndDateTime, address sender);
    mapping (bytes32 => Chat) private chatsMapping;  // Emulating many-to-many relationship between users with a surrogate PK
    Chat[] private chatsArray;

    function getChatByID(bytes32 _id) public view returns (Chat memory) {
        return chatsMapping[_id];
    }

    function startChat(address _caller) public returns (bytes32) {
        Chat memory chat = Chat(
            keccak256(abi.encodePacked(msg.sender, _caller, block.timestamp)),
            _caller,
            msg.sender,
            0,
            0,
            Statuses.pending
        );
        chatsArray.push(chat);
        chatsMapping[chat.id] = chat;
        emit ChatInit(chat.id, chat.caller, chat.callee, msg.sender);
        return chat.id;
    }

    function confirmChat(bytes32 _id) public {
        Chat storage chat = chatsMapping[_id];
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.started;
        chat.startDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
    }

    function finishChat(bytes32 _id) public {
        Chat storage chat = chatsMapping[_id];
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        require(msg.sender == chat.caller || msg.sender == chat.callee, 'You cannot finish the chat');
        chat.status = Statuses.finished;
        chat.endDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        chat = chatsMapping[_id];
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
    }
}
