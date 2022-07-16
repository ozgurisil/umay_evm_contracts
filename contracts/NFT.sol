// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract NFT is ERC721, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint public cost = 25_000_000_000_000_000_000;
    address public stableCoinAddress;
    address public treasuryAddress;

    constructor() ERC721("Umay NFT", "UmayNFT") {}

    function setStableCoinAddress(address _address) external onlyOwner {
        stableCoinAddress = _address;
    }

    function setTreasuryAddress(address _address) external onlyOwner {
        treasuryAddress = _address;
    }

    function setCost(uint _cost) external onlyOwner {
        cost = _cost;
    }

    function safeMint() public nonReentrant {
        require(this.balanceOf(msg.sender) == 0, 'Already has NFT');
        IERC20 stableCoin = IERC20(stableCoinAddress);
        stableCoin.transferFrom(msg.sender, treasuryAddress, cost);
        _safeMint(msg.sender, _tokenIdCounter.current());
        _tokenIdCounter.increment();
    }

    function _transfer(address, address, uint256) internal override pure {
        revert('Cannot transfer NFT');
    }
}
