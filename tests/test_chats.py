import pytest

from brownie import Users, Chats, accounts


@pytest.fixture(scope='module')
def users():
    users = accounts[0].deploy(Users)
    users.register('test-user-1', 123, 1, 10, {'from': accounts[1]})
    users.register('test-user-2', 123, 1, 10, {'from': accounts[2]})
    users.register('test-user-3', 123, 1, 10, {'from': accounts[3]})
    return users


@pytest.fixture(scope='module')
def chats():
    return accounts[0].deploy(Chats)


def test_start_chat(users, chats):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat = chats.getChatByID(tx.return_value)
    assert chat[1] == accounts[2]
    assert chat[2] == accounts[1]
    assert chat[5] == 0  # Pending
    event = tx.events['ChatInit']
    assert event['caller'] == accounts[2]
    assert event['callee'] == accounts[1]


def test_confirm_chat(users, chats):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    tx = chats.confirmChat(chat_id, {'from': accounts[2]})
    tx = chats.getChatByID(chat_id)
    assert tx[1] == accounts[2]
    assert tx[2] == accounts[1]
    assert tx[5] == 1  # Started


def test_finish_chat(users, chats):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    tx = chats.finishChat(chat_id, {'from': accounts[1]})
    tx = chats.getChatByID(chat_id)
    assert tx[5 == 2]
