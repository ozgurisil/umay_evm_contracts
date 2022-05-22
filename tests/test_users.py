import pytest

from brownie import Users, accounts


@pytest.fixture
def users():
    return accounts[0].deploy(Users)


def test_register(users):
    tx = users.register('test-user', 123, 1, 10, {'from': accounts[1]})
    assert users.users(accounts[1]) == ('test-user', 123, 1, 2, 10)
    assert tx.events[0] == {'userName': 'test-user'}


def test_set_status(users):
    tx = users.register('test-user', 123, 1, 10, {'from': accounts[1]})
    # import pdb; pdb.set_trace()
    assert users.users(accounts[1]).dict()['status'] == 2
    tx = users.setStatus(0, {'from': accounts[1]})
    assert users.users(accounts[1]).dict()['status'] == 0
    assert tx.events[0] == {'wallet': accounts[1], 'userName': 'test-user', 'status': 0}
