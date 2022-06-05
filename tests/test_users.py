import pytest

from brownie import Users, ChatToken, Chats, accounts, reverts


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


@pytest.fixture
def users(isolate):
    users = accounts[0].deploy(Users)
    users.updateProfile('test-user-1', 123, 1, 100e18, [], 'bio for user 1', 41, 29, 1, {'from': accounts[1]})
    assert users.getUserByAddress(accounts[1]) == ('test-user-1', 123, 1, 1, 100e18, 0, 0, '0x0', [], 'bio for user 1', 41, 29, 1)
    users.updateProfile('test-user-2', 123, 1, 200e18, [], 'bio for user 2', 41, 29, 1, {'from': accounts[2]})
    assert users.getUserByAddress(accounts[2]) == ('test-user-2', 123, 1, 1, 200e18, 0, 0, '0x0', [], 'bio for user 2', 41, 29, 1)
    users.updateProfile('test-user-3', 123, 1, 300e18, [], 'bio for user 3', 41, 29, 1, {'from': accounts[3]})
    assert users.getUserByAddress(accounts[3]) == ('test-user-3', 123, 1, 1, 300e18, 0, 0, '0x0', [], 'bio for user 3', 41, 29, 1)
    return users


@pytest.fixture
def token(users):
    token = accounts[0].deploy(ChatToken)
    token.approve(users.address, 10_000e18, {'from': accounts[1]})
    token.approve(users.address, 10_000e18, {'from': accounts[2]})
    token.transfer(accounts[1], 1_000_000e18, {'from': accounts[0]})
    token.transfer(accounts[2], 1_000_000e18, {'from': accounts[0]})
    users.setTokenAddress(token.address)
    return token


@pytest.fixture
def chats(users):
    chats = accounts[0].deploy(Chats)
    users.setChatsAddress(chats.address)
    return chats;


def test_update_profile_valid_username(users):
    users.updateProfile('aB1_+-@ şğiüçö', 123, 1, 100e18, [1, 3, 5], 'bio for user 5', 41, 29, 1, {'from': accounts[5]})


def test_update_profile_invalid_username(users):
    with reverts():
        users.updateProfile('', 123, 1, 100e18, [1, 3, 5], 'bio for user 5', 41, 29, 1, {'from': accounts[5]})
    with reverts():
        users.updateProfile('a', 123, 1, 100e18, [1, 3, 5], 'bio for user 5', 41, 29, 1, {'from': accounts[5]})
    with reverts():
        users.updateProfile('a' * 33, 123, 1, 100e18, [1, 3, 5], 'bio for user 5', 41, 29, 1, {'from': accounts[5]})


def test_update_profile_areas_of_interest(users):
    users.updateProfile('test-user-5', 123, 1, 100e18, [1, 3, 5], 'bio for user 5', 41, 29, 1, {'from': accounts[5]})
    user5 = users.getUserByAddress(accounts[5])
    assert user5[8] == (1, 3, 5)


def test_set_status(users):
    tx = users.updateProfile('test-user-4', 123, 1, 10, [], 'bio for user 4', 41, 29, 1, {'from': accounts[4]})
    assert users.getUserByAddress(accounts[4])['status'] == 1
    tx = users.setStatus(2, {'from': accounts[4]})
    assert users.getUserByAddress(accounts[4])['status'] == 2
    assert 'SetStatus' in tx.events and tx.events[0] == {'wallet': accounts[4], 'userName': 'test-user-4', 'status': 2}


def test_deposit(users, token):
    tx = users.deposit(500e18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 500e18
    assert token.balanceOf(accounts[1]) == 999_500e18
    tx = users.deposit(1000e18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 1500e18
    assert token.balanceOf(accounts[1]) == 998_500e18
    tx = users.deposit(500e18, {'from': accounts[2]})
    assert token.balanceOf(users.address) == 2000e18
    assert token.balanceOf(accounts[1]) == 998_500e18
    assert token.balanceOf(accounts[2]) == 999_500e18
    user1 = users.getUserByAddress(accounts[1])
    assert user1['depositBalance'] == 1500e18
    user2 = users.getUserByAddress(accounts[2])
    assert user2['depositBalance'] == 500e18


def test_fail_deposit_not_enough_balance(users, token):
    with reverts():
        users.deposit(2_000_000e18, {'from': accounts[1]})


def test_withdraw(users, token):
    users.deposit(500e18, {'from': accounts[1]})
    users.deposit(1000e18, {'from': accounts[2]})
    users.withdraw(250e18, {'from': accounts[1]})
    assert token.balanceOf(users.address) == 1250e18
    assert token.balanceOf(accounts[1]) == 999_750e18
    assert token.balanceOf(accounts[2]) == 999_000e18
    user1 = users.getUserByAddress(accounts[1])
    assert user1['depositBalance'] == 250e18
    user2 = users.getUserByAddress(accounts[2])
    assert user2['depositBalance'] == 1000e18


def test_withdraw_fail_not_enough_balance(users, token):
    users.deposit(500e18, {'from': accounts[1]})
    with reverts():
        users.withdraw(1000e18, {'from': accounts[1]})


def test_block_deposit(users, chats, token):
    users.deposit(500e18, {'from': accounts[1]})
    users.blockDeposit(accounts[1], 300e18, {'from': chats.address})
    assert users.getUserByAddress(accounts[1])[6] == 300e18 # Blocked amount


def test_fail_block_deposit_wrong_chats_address(users, chats, token):
    users.deposit(500e18, {'from': accounts[1]})
    with reverts():
        users.blockDeposit(accounts[1], 300e18, {'from': accounts[1]})
    with reverts():
        users.blockDeposit(accounts[1], 300e18, {'from': accounts[2]})


def test_fail_block_deposit_not_enough_balance(users, chats, token):
    users.deposit(500e18, {'from': accounts[1]})
    with reverts():
        users.blockDeposit(accounts[1], 1000e18, {'from': chats.address})


def test_unblock_deposit(users, chats, token):
    users.deposit(500e18, {'from': accounts[1]})
    users.blockDeposit(accounts[1], 300e18, {'from': chats.address})
    users.unblockDeposit(accounts[1], 0, {'from': chats.address})
    assert users.getUserByAddress(accounts[1])[6] == 0 # Blocked amount


def test_fail_unblock_deposit_wrong_chat_address(users, chats, token):
    users.deposit(500e18, {'from': accounts[1]})
    with reverts():
        users.unblockDeposit(accounts[1], 0, {'from': accounts[1]})


def test_blocked_deposit_withdrawal(users, chats, token):
    users.deposit(10_000e18, {'from': accounts[1]})
    users.blockDeposit(accounts[1], 5_000e18, {'from': chats.address})
    users.withdraw(3_000e18, {'from': accounts[1]})
    users.withdraw(2_000e18, {'from': accounts[1]})
    with reverts():
        users.withdraw(3_000e18, {'from': accounts[1]})
