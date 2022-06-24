// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";


contract Users is Ownable, ReentrancyGuard{
    using SafeERC20 for IERC20;
    modifier onlyBy (address _address) {
        require(msg.sender == _address, 'Not authorized');
        _;
    }

    address public protocolTokenContract;
    address public chatsContract;
    enum Genders {
        unknown,
        male,
        female
    }
    enum Statuses {
        notRegistered,
        available,
        notAvailable
    }
    enum AreasOfInterest {
        Crypto,
        Dating,
        NSFW,
        Sports,
        Movies,
        Anime
    }
    enum Zodiac {
        unknown,
        Aries,
        Taurus,
        Gemini,
        Cancer,
        Leo,
        Virgo,
        Libra,
        Scorpio,
        Sagittarius,
        Capricorn,
        Aquarius,
        Pisces
    }
    struct User {
        string userName;
        uint birthDate;
        Genders gender;
        Statuses status;
        uint fee;
        uint depositBalance;
        uint blockedAmount;
        bytes32 currentChatId;
        AreasOfInterest[] interests;
        string bio;
        uint latitude;
        uint longitude;
        Zodiac sign;
        uint avgRating;
        uint cntRating;
        bytes32 firstRating;
        bytes32 lastRating;
    }
    event UserProfileChange(
        string userName,
        uint birthDate,
        Genders gender,
        Statuses status,
        uint fee,
        AreasOfInterest[] interests,
        string bio,
        uint latitude,
        uint longitude,
        Zodiac sign
    );

    struct Rating {
        address rated;
        uint rating;
        bytes32 prevRating;
        bytes32 nextRating;
    }

    event SetStatus(address indexed wallet, string userName, Statuses indexed status);
    event UserDeposit(address indexed _address, uint _amount, uint _balance);
    event UserWithdrawal(address indexed _address, uint _amount, uint _balance);
    event RatingChange(address indexed wallet, uint countRating, uint averageRating);

    mapping (address => User) private users;

    mapping (bytes32 => Rating) public ratings;

    function getUserByAddress(address _address) public view returns (User memory) {
        return users[_address];
    }

    function setTokenAddress(address _address) external onlyOwner {
        protocolTokenContract = _address;
    }

    function setChatsAddress(address _address) external onlyOwner {
        chatsContract = _address;
    }

    function updateProfile(
            string memory _userName, uint _birthDate, Genders _gender, uint _fee, AreasOfInterest[] memory _interests,
            string memory _bio, uint _latitude, uint _longitude, Zodiac _sign) external {

        if (users[msg.sender].status == Statuses.notRegistered) {
            require(bytes(_userName).length >= 2 && bytes(_userName).length <= 32, 'Invalid username');
            users[msg.sender] = User(
                _userName, _birthDate, _gender, Statuses.available, _fee, 0, 0, 0, _interests, _bio, _latitude, _longitude, _sign, 0, 0, 0x0, 0x0);
        }
        else {
            User storage user = users[msg.sender];
            if (bytes(_userName).length > 0) {
                require(bytes(_userName).length >= 2 && bytes(_userName).length <= 32, 'Invalid username');
                user.userName = _userName;
            }
            user.birthDate = _birthDate;
            user.gender = _gender;
            user.fee =_fee;
            user.interests = _interests;
            user.bio = _bio;
            user.latitude = _latitude;
            user.longitude = _longitude;
            user.sign = _sign;
        }
        emit UserProfileChange(_userName, _birthDate, _gender, Statuses.available, _fee, _interests, _bio, _latitude, _longitude, _sign);
    }

    function setStatus(Statuses _status) external {
        require(_status != Statuses.notRegistered, 'Invalid status');
        users[msg.sender].status = _status;
        emit SetStatus(msg.sender, users[msg.sender].userName, users[msg.sender].status);
    }

    function setChatId(address _caller, address _callee, bytes32 _id) onlyBy(chatsContract) external {
        users[_caller].currentChatId = _id;
        users[_callee].currentChatId = _id;
    }

    function getUserFee(address _wallet) external view returns (uint) {
        return users[_wallet].fee;
    }

    function deposit(uint _amount) external nonReentrant {
        IERC20 token = IERC20(protocolTokenContract);
        require(token.balanceOf(msg.sender) >= _amount, 'Not enought balance');
        users[msg.sender].depositBalance += _amount;
        emit UserDeposit(msg.sender, _amount, users[msg.sender].depositBalance);
        token.safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdraw(uint _amount) external nonReentrant {
        require(users[msg.sender].depositBalance - users[msg.sender].blockedAmount >= _amount, 'Not enough balance');
        users[msg.sender].depositBalance -= _amount;
        emit UserWithdrawal(msg.sender, _amount, users[msg.sender].depositBalance);
        IERC20 token = IERC20(protocolTokenContract);
        token.safeTransfer(msg.sender, _amount);
    }

    function blockDeposit(address _address, uint _amount) onlyBy(chatsContract) external {
        require(users[_address].depositBalance - users[_address].blockedAmount >= _amount, 'Not enough balance');
        users[_address].blockedAmount += _amount;
    }

    function unblockDeposit(address _address, uint exclude) onlyBy (chatsContract) external returns (uint) {
        uint blockedAmount = users[_address].blockedAmount;
        users[_address].blockedAmount = exclude;
        return blockedAmount - exclude;
    }

    function claim(address _address, uint _amount) onlyBy(chatsContract) external {
        IERC20 token = IERC20(protocolTokenContract);
        token.safeTransfer(_address, _amount);
    }

    function callerCanCoverFees(address _caller, address _callee) public view returns (bool) {
        if (users[_caller].depositBalance - users[_caller].blockedAmount >= users[_callee].fee) return true;
        return false;
    }

    function addRating(address _address, uint _rating) external {
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, _address));
        require(_rating == 1000 || _rating == 2000 || _rating == 3000 || _rating == 4000 || _rating == 5000, 'Invalid rating');
        require(ratings[hash].rating == 0, 'Duplicate rating');

        ratings[hash] = Rating(_address, _rating, users[msg.sender].lastRating, 0x0);

        if (users[msg.sender].firstRating == 0x0) {
            users[msg.sender].firstRating = hash;
        }
        ratings[users[msg.sender].lastRating].nextRating = hash;
        users[msg.sender].lastRating = hash;

        users[_address].avgRating = (users[_address].avgRating * users[_address].cntRating + _rating) / (users[_address].cntRating + 1);
        users[_address].cntRating++;
        emit RatingChange(_address, users[_address].cntRating, users[_address].avgRating);
    }

    function removeRating(address _address) external {
        bytes32 hash = keccak256(abi.encodePacked(msg.sender, _address));
        require(ratings[hash].rated != address(0), 'Invalid address');
        uint rating = ratings[hash].rating;

        // Fix linked list elements
        ratings[ratings[hash].nextRating].prevRating = ratings[hash].prevRating;
        ratings[ratings[hash].prevRating].nextRating = ratings[hash].nextRating;
        delete ratings[hash];

        // Fix user's ratings
        users[_address].avgRating = (users[_address].avgRating * users[_address].cntRating - rating) / Math.max(users[_address].cntRating - 1, 1);
        users[_address].cntRating--;

        emit RatingChange(_address, users[_address].cntRating, users[_address].avgRating);
    }

    function getRatingsByUser(bytes32 _start, uint _length) external view returns (Rating[] memory) {
        Rating[] memory ratingsByUser = new Rating[](_length);
        bytes32 nextPage;
        if (_start == 0x0) {
            _start = users[msg.sender].firstRating;
        }
        Rating memory rating = ratings[_start];

        for (uint i = 0; i < _length; i++) {
            ratingsByUser[i] = rating;
            rating = ratings[rating.nextRating];
            nextPage = rating.nextRating;
            if (rating.rated == address(0)) break;
        }
        return ratingsByUser;
    }
}
