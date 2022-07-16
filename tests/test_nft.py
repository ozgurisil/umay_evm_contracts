import pytest

from brownie import NFT, ChatToken, accounts, reverts
from brownie.network.state import Chain


chain = Chain()


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


@pytest.fixture(scope='module')
def token():
    token = accounts[9].deploy(ChatToken)
    token.transfer(accounts[0], 1_000e18, {'from': accounts[9]})
    token.transfer(accounts[1], 1_000e18, {'from': accounts[9]})
    token.transfer(accounts[2], 1_000e18, {'from': accounts[9]})
    return token


@pytest.fixture(scope='module')
def nft(NFT, token):
    nft = accounts[0].deploy(NFT)
    nft.setTreasuryAddress(accounts[9])
    nft.setStableCoinAddress(token.address)
    return nft


def test_mint(nft, token):
    account = accounts[0]
    token.approve(nft.address, 100e18, {'from': account})
    tx = nft.safeMint({'from': account})
    assert nft.balanceOf(account) == 1
    assert tx.events[-1]['tokenId'] == 0
    assert token.allowance(account, nft.address) == 100e18 - nft.cost()


def test_token_id_increment(nft, token):
    token.approve(nft.address, 100e18, {'from': accounts[0]})
    tx = nft.safeMint({'from': accounts[0]})
    assert tx.events[-1]['tokenId'] == 0
    token.approve(nft.address, 100e18, {'from': accounts[1]})
    tx = nft.safeMint({'from': accounts[1]})
    assert tx.events[-1]['tokenId'] == 1
    token.approve(nft.address, 100e18, {'from': accounts[2]})
    tx = nft.safeMint({'from': accounts[2]})
    assert tx.events[-1]['tokenId'] == 2


def test_mint_fail_if_owner_already_has_one(nft, token):
    account = accounts[0]
    token.approve(nft.address, 100e18, {'from': account})
    nft.safeMint({'from': account})
    with reverts():
        nft.safeMint({'from': account})


def test_mint_fail_if_owner_lacks_funds(nft, token):
    account = accounts[3]
    token.approve(nft.address, 100e18, {'from': account})
    with reverts('ERC20: transfer amount exceeds balance'):
        nft.safeMint({'from': account})


def test_transfer(nft, token):
    account = accounts[0]
    token.approve(nft.address, 100e18, {'from': account})
    tx = nft.safeMint({'from': account})
    token_id = tx.events[-1]['tokenId']
    with reverts('Cannot transfer NFT'):
        nft.safeTransferFrom(accounts[0], accounts[1], token_id, {'from': accounts[0]})
    with reverts('Cannot transfer NFT'):
        nft.transferFrom(accounts[0], accounts[1], token_id, {'from': accounts[0]})
