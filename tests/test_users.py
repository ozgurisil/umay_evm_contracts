import pytest

from brownie import Users, ChatToken, Chats, accounts, reverts


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


@pytest.fixture
def users(isolate):
    users = accounts[0].deploy(Users)
    users.register('test-user-1', 123, 1, 100 * 10 ** 18, {'from': accounts[1]})
    assert users.getUserByAddress(accounts[1]) == ('test-user-1', 123, 1, 1, 100 * 10 ** 18, 0, 0, '0x0')
    users.register('test-user-2', 123, 1, 200 * 10 ** 18, {'from': accounts[2]})
    assert users.getUserByAddress(accounts[2]) == ('test-user-2', 123, 1, 1, 200 * 10 ** 18, 0, 0, '0x0')
    users.register('test-user-3', 123, 1, 300 * 10 ** 18, {'from': accounts[3]})
    assert users.getUserByAddress(accounts[3]) == ('test-user-3', 123, 1, 1, 300 * 10 ** 18, 0, 0, '0x0')
    return users


@pytest.fixture
def token(users):
    token = accounts[0].deploy(ChatToken)
    token.approve(users.address, 10000 * 10 ** 18, {'from': accounts[1]})
    token.approve(users.address, 10000 * 10 ** 18, {'from': accounts[2]})
    token.transfer(accounts[1], 1000000 * 10 ** 18, {'from': accounts[0]})
    token.transfer(accounts[2], 1000000 * 10 ** 18, {'from': accounts[0]})
    users.setTokenAddress(token.address)
    return token


@pytest.fixture
def chats(users):
    chats = accounts[0].deploy(Chats)
    users.setChatsAddress(chats.address)
    return chats;


def test_set_status(users):
    tx = users.register('test-user-4', 123, 1, 10, {'from': accounts[4]})
    assert users.getUserByAddress(accounts[4])['status'] == 1
    tx = users.setStatus(2, {'from': accounts[4]})
    assert users.getUserByAddress(accounts[4])['status'] == 2
    assert 'SetStatus' in tx.events and tx.events[0] == {'wallet': accounts[4], 'userName': 'test-user-4', 'status': 2}


def test_deposit(users, token):
    tx = users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 500 * 10 ** 18
    assert token.balanceOf(accounts[1]) == 999500 * 10 ** 18
    tx = users.deposit(1000 * 10 ** 18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 1500 * 10 ** 18
    assert token.balanceOf(accounts[1]) == 998500 * 10 ** 18
    tx = users.deposit(500 * 10 ** 18, {'from': accounts[2]})
    assert token.balanceOf(users.address) == 2000 * 10 ** 18
    assert token.balanceOf(accounts[1]) == 998500 * 10 ** 18
    assert token.balanceOf(accounts[2]) == 999500 * 10 ** 18
    user1 = users.getUserByAddress(accounts[1])
    assert user1['depositBalance'] == 1500 * 10 ** 18
    user2 = users.getUserByAddress(accounts[2])
    assert user2['depositBalance'] == 500 * 10 ** 18


def test_fail_deposit_not_enough_balance(users, token):
    with reverts():
        users.deposit(2_000_000 * 10 ** 18, {'from': accounts[1]})


def test_withdraw(users, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    users.deposit(1000 * 10 ** 18, {'from': accounts[2]})
    users.withdraw(250 * 10 ** 18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 1250 * 10 ** 18
    assert token.balanceOf(accounts[1]) == 999750 * 10 ** 18
    assert token.balanceOf(accounts[2]) == 999000 * 10 ** 18
    user1 = users.getUserByAddress(accounts[1])
    assert user1['depositBalance'] == 250 * 10 ** 18
    user2 = users.getUserByAddress(accounts[2])
    assert user2['depositBalance'] == 1000 * 10 ** 18


def test_withdraw_fail_not_enough_balance(users, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    with reverts():
        users.withdraw(1000 * 10 ** 18, {'from': accounts[1]})


def test_block_deposit(users, chats, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    users.blockDeposit(accounts[1], 300 * 10 ** 18, {'from': chats.address})
    assert users.getUserByAddress(accounts[1])[6] == 300 * 10 ** 18 # Blocked amount


def test_fail_block_deposit_wrong_chats_address(users, chats, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    with reverts():
        users.blockDeposit(accounts[1], 300 * 10 ** 18, {'from': accounts[1]})
        users.blockDeposit(accounts[1], 300 * 10 ** 18, {'from': accounts[2]})


def test_fail_block_deposit_not_enough_balance(users, chats, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    with reverts():
        users.blockDeposit(accounts[1], 1000 * 10 ** 18, {'from': chats.address})


def test_unblock_deposit(users, chats, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    users.blockDeposit(accounts[1], 300 * 10 ** 18, {'from': chats.address})
    users.unblockDeposit(accounts[1], {'from': chats.address})
    assert users.getUserByAddress(accounts[1])[6] == 0 # Blocked amount


def test_fail_unblock_deposit_wrong_chat_address(users, chats, token):
    users.deposit(500 * 10 ** 18, {'from': accounts[1]})
    with reverts():
        users.unblockDeposit(accounts[1], {'from': accounts[1]})
