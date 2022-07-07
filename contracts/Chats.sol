// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IUsers.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract Chats is Ownable, ReentrancyGuard {
    address public usersContract;
    address public protocolToken;
    address public treasuryAddress;
    uint8 public treasuryPct = 0;
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
    event ChatInit(bytes32 indexed id, address indexed caller, address indexed callee, uint fee, address sender);
    event ChatStatusChange(bytes32 indexed id, Statuses indexed status, uint startDateTime, uint EndDateTime, address sender);
    event ChatExtended(bytes32 indexed id);
    mapping (bytes32 => Chat) private chatsMapping;  // Emulating many-to-many relationship between users with a surrogate PK
    Chat[] private chatsArray;

    function setUsersContractAddress (address _address) external onlyOwner {
        usersContract = _address;
    }

    function setTokenAddress(address _address) external onlyOwner {
        protocolToken = _address;
    }

    function setTreasuryAddress(address _address) external onlyOwner {
        treasuryAddress = _address;
    }

    function setTreasuryPct(uint8 _pct) external onlyOwner {
        treasuryPct = _pct;
    }

    function getChatByID(bytes32 _id) public view returns (Chat memory) {
        return chatsMapping[_id];
    }

    function startChat(address _caller) external nonReentrant returns (bytes32) {
        IUsers users = IUsers(usersContract);
        require(users.getUserByAddress(msg.sender).currentChatId == '' && users.getUserByAddress(_caller).currentChatId == '', 'Cannot start a chat');
        require(users.callerCanCoverFees(_caller, msg.sender), 'Caller funds not sufficient');
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

    function confirmChat(bytes32 _id) external nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.pending, 'Chat status is not "pending"');
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.started;
        chat.startDateTime = block.timestamp;
        // CONSIDERATION: setChatId() might better be called here instead of startChat()
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        IUsers users = IUsers(usersContract);
        require(users.callerCanCoverFees(msg.sender, chat.callee), 'Caller funds not sufficient');
        users.lockDeposit(msg.sender, chat.fee);
    }

    function cancelChat(bytes32 _id) external nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.pending, 'Chat status is not "pending"');
        require(msg.sender == chat.callee, 'You cannot cancel the chat');
        chat.status = Statuses.canceled;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        IUsers users = IUsers(usersContract);
        // CONSIDERATION: If setChatId is called in confirmChat, this won't be needed here.
        users.setChatId(chat.caller, chat.callee, '');
    }

    function rejectChat(bytes32 _id) external nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.pending, 'Chat status is not "pending"');
        require(msg.sender == chat.caller, 'You cannot confirm the chat');
        chat.status = Statuses.canceled;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, 0, msg.sender);
        delete chatsMapping[_id];
    }

    function finishChat(bytes32 _id) external nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.started, 'Chat status is not "started"');
        require(msg.sender == chat.caller || msg.sender == chat.callee, 'You cannot finish the chat');
        chat.status = Statuses.finished;
        chat.endDateTime = block.timestamp;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        IUsers users = IUsers(usersContract);
        users.setChatId(chat.caller, chat.callee, '');
    }

    function extendChat(bytes32 _id) external nonReentrant {
        Chat storage chat = chatsMapping[_id];
        require(chat.status == Statuses.started, 'Chat status is not "started"');
        require(msg.sender == chat.caller, 'You cannot extend the chat');
        emit ChatExtended(_id);
        // TODO: Handle the case in which the user doesn't have enough deposits
        IUsers users = IUsers(usersContract);
        require(users.callerCanCoverFees(msg.sender, chat.callee), 'Caller funds not sufficient');
        users.lockDeposit(msg.sender, chat.fee);
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
        return chat.fee * (end - start) / 3600;
    }

    function claimFee(bytes32 _id) public nonReentrant returns (uint) {
        uint feeToClaim = getUnclaimedFee(_id);
        Chat storage chat = chatsMapping[_id];
        uint treasuryShare = feeToClaim * treasuryPct / 100;
        uint feePayable = feeToClaim - treasuryShare;
        require(chat.status == Statuses.finished, 'Chat status is not "finished"');
        chat.status = Statuses.feeClaimed;
        emit ChatStatusChange(chat.id, chat.status, chat.startDateTime, chat.endDateTime, msg.sender);
        address[] memory addresses = new address[](2);
        addresses[0] = chat.callee;
        addresses[1] = treasuryAddress;
        uint[] memory amounts = new uint[](2);
        amounts[0] = feePayable;
        amounts[1] = treasuryShare;
        IUsers(usersContract).claim(addresses, amounts);
        return feeToClaim;
    }

    function unlockDeposit(bytes32 _id) external nonReentrant returns (uint) {
        Chat storage chat = chatsMapping[_id];
        require (chat.status == Statuses.finished || chat.status == Statuses.feeClaimed, 'Chat status is not "finished" or "feeClaimed"');
        uint feeToClaim = getUnclaimedFee(_id);
        return IUsers(usersContract).unlockDeposit(chat.caller, feeToClaim);
    }
}
