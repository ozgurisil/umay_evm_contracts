import pytest

from brownie import Users, Chats, ChatToken, accounts, reverts
from brownie.network.state import Chain
from brownie.test import given, strategy


chain = Chain()


@pytest.fixture(scope='module')
def users():
    users = accounts[0].deploy(Users)
    users.register('test-user-1', 123, 1, 100 * 10 ** 18, {'from': accounts[1]})
    users.register('test-user-2', 123, 1, 200 * 10 ** 18, {'from': accounts[2]})
    users.register('test-user-3', 123, 1, 300 * 10 ** 18, {'from': accounts[3]})
    return users


@pytest.fixture(scope='module')
def token(users):
    token = accounts[0].deploy(ChatToken)
    token.transfer(accounts[1], 1000000 * 10 ** 18, {'from': accounts[0]})
    token.transfer(accounts[2], 1000000 * 10 ** 18, {'from': accounts[0]})
    return token


@pytest.fixture(scope='module')
def chats(users, token):
    chats = accounts[0].deploy(Chats)
    chats.setUsersContractAddress(users.address)
    chats.setTokenAddress(token.address)
    users.setTokenAddress(token.address)
    users.setChatsAddress(chats.address)
    token.approve(users.address, 10000 * 10 ** 18, {'from': accounts[1]})
    token.approve(users.address, 10000 * 10 ** 18, {'from': accounts[2]})
    # users.deposit(250 * 10 ** 18, {'from': accounts[0]})
    users.deposit(250 * 10 ** 18, {'from': accounts[1]})
    users.deposit(250 * 10 ** 18, {'from': accounts[2]})
    assert token.balanceOf(users.address) == 500 * 10 ** 18
    return chats


def test_start_chat(users, chats):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat = chats.getChatByID(tx.return_value)
    assert chat[1] == accounts[2]
    assert chat[2] == accounts[1]
    assert chat[5] == 100 * 10 ** 18
    assert chat[7] == 0  # Pending
    event = tx.events['ChatInit']
    assert event['caller'] == accounts[2]
    assert event['callee'] == accounts[1]


def test_confirm_chat(users, chats, token):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    tx = chats.confirmChat(chat_id, {'from': accounts[2]})
    tx = chats.getChatByID(chat_id)
    assert tx[1] == accounts[2]
    assert tx[2] == accounts[1]
    assert tx[5] == 100 * 10 ** 18
    assert tx[7] == 1  # Started
    assert users.getUserByAddress(accounts[1])[6] == 0
    assert users.getUserByAddress(accounts[2])[6] == 100 * 10 ** 18


# Workaround for this bug: https://github.com/eth-brownie/brownie/issues/918
def test_fail_confirm_chat(users, chats):
    @given(value=strategy('address', exclude=accounts[2]))
    def run(users, chats, value):
        tx = chats.startChat(accounts[2], {'from': accounts[1]})
        chat_id = tx.return_value
        with reverts():
            tx = chats.confirmChat(chat_id, {'from': value})
    run(users, chats)


def test_finish_chat(users, chats):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    tx = chats.finishChat(chat_id, {'from': accounts[1]})
    tx = chats.getChatByID(chat_id)
    assert tx[5] == 100 * 10 ** 18
    assert tx[7] == 2 # Finished


# Workaround for this bug: https://github.com/eth-brownie/brownie/issues/918
def test_fail_to_finish_chat(users, chats):
    @given(value=strategy('address', exclude=[accounts[1], accounts[2]]))
    def run(users, chats, value):
        tx = chats.startChat(accounts[2], {'from': accounts[1]})
        chat_id = tx.return_value
        chats.confirmChat(chat_id, {'from': accounts[2]})
        with reverts():
            tx = chats.finishChat(chat_id, {'from': value})
    run(users, chats)


@given(value=strategy('uint', min_value=900, max_value=3600))
def test_unclaimed_fee(users,  chats, value):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    chain.sleep(value)
    chain.mine()
    tx = chats.getUnclaimedFee(chat_id)
    assert 100 * value / 3600 * .999 < tx / 10 ** 18 < 100 * value / 3600 * 1.001


def test_claim_fee(users, chats, token):
    assert token.balanceOf(users.address) / 10 ** 18 == 500
    assert token.balanceOf(accounts[1]) / 10 ** 18 == 999750
    assert token.balanceOf(accounts[2]) / 10 ** 18 == 999750
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    chain.sleep(3600)
    chain.mine()
    with reverts():
        chats.claimFee(chat_id, {'from': accounts[1]})
    chats.finishChat(chat_id, {'from': accounts[1]})
    tx = chats.claimFee(chat_id, {'from': accounts[1]})
    assert tx.events['ChatStatusChange']['status'] == 4  # feeClaimed
    assert token.balanceOf(accounts[1]) / 10 ** 18 == 999850
    assert token.balanceOf(accounts[2]) / 10 ** 18 == 999750
    assert token.balanceOf(users.address) / 10 ** 18 == 400


def test_unblock_deposit(users, chats, token):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    chain.sleep(1800)  # Half of the blocked deposit will be available to unblock
    chain.mine()
    with reverts():
        chats.unblockDeposit(chat_id, {'from': accounts[1]})
    chats.finishChat(chat_id, {'from': accounts[1]})
    assert users.getUserByAddress(accounts[2])[6] == 100 * 10 ** 18
    tx = chats.unblockDeposit(chat_id, {'from': accounts[1]})
    assert users.getUserByAddress(accounts[2])[6] == 0


def test_extend_chat(users, chats, token):
    tx = chats.startChat(accounts[2], {'from': accounts[1]})
    chat_id = tx.return_value
    chats.confirmChat(chat_id, {'from': accounts[2]})
    assert users.getUserByAddress(accounts[2])[6] == 100 * 10 ** 18
    chain.sleep(3200)
    chain.mine()
    tx = chats.getUnclaimedFee(chat_id)
    assert abs(chats.getUnclaimedFee(chat_id) / 1e18 - 88.888) <= 0.001
    tx = chats.extendChat(chat_id, {'from': accounts[2]})
    assert 'ChatExtended' in tx.events
    assert users.getUserByAddress(accounts[2])[6] == 200 * 10 ** 18
    chain.sleep(3200)
    chain.mine()
    assert abs(chats.getUnclaimedFee(chat_id) / 1e18 - 177.777) <= 0.001
