import pytest

from brownie import Users, ChatToken, accounts


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    pass


@pytest.fixture
def users(isolate):
    users = accounts[0].deploy(Users)
    users.register('test-user-1', 123, 1, 100 * 10 ** 18, {'from': accounts[1]})
    assert users.getUserByAddress(accounts[1]) == ('test-user-1', 123, 1, 2, 100 * 10 ** 18, 0, 0)
    users.register('test-user-2', 123, 1, 200 * 10 ** 18, {'from': accounts[2]})
    assert users.getUserByAddress(accounts[2]) == ('test-user-2', 123, 1, 2, 200 * 10 ** 18, 0, 0)
    users.register('test-user-3', 123, 1, 300 * 10 ** 18, {'from': accounts[3]})
    assert users.getUserByAddress(accounts[3]) == ('test-user-3', 123, 1, 2, 300 * 10 ** 18, 0, 0)
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


def test_set_status(users):
    tx = users.register('test-user', 123, 1, 10, {'from': accounts[1]})
    assert users.users(accounts[1]).dict()['status'] == 2
    tx = users.setStatus(0, {'from': accounts[1]})
    assert users.users(accounts[1]).dict()['status'] == 0
    assert tx.events[0] == {'wallet': accounts[1], 'userName': 'test-user', 'status': 0}


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
