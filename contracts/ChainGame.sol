// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

contract ChainGame {
    struct Chain {
        uint256 chainId;
        address owner;
        uint256 validUsers;
        uint256 amountToPay;
        uint256 initialDate;
        uint256 timeToPay;
        uint256 balance;
        address[] users;
    }

    /// ---- Global atributes ---- ///

    // Chain feature
    uint256 public numChains = 0;
    mapping(uint256 => Chain) public chains;
    mapping(uint256 => mapping(address => uint256)) private timesPaid;
    mapping(uint256 => mapping(address => bool)) private hasWithdraw;
    mapping(address => mapping(uint256 => bool)) private isInChain;

    // Ban feature
    mapping(address => int256) private banDate;
    mapping(address => uint256) public timesBeingBanned;

    /// ---- modifiers ---- ///

    modifier notBanned() {
        require(!isBanned(msg.sender), "You are banned");
        _;
    }

    modifier isOwner(uint256 chainId) {
        require(chainId < numChains, "Chain id doesn't exists");
        /*require(
            chains[chainId].owner == msg.sender,
            "You don't have perssions to operate this action"
        );*/
        _;
    }

    /// ---- Chain logic methods ---- ///

    function createChain(
        uint256 amountToPay,
        uint256 daysToStart,
        uint256 daysToPay
    ) public notBanned returns (uint256) {
        assert(amountToPay > 0);
        assert(daysToStart > 0);
        assert(daysToPay > 0);

        uint256 initialDate = block.timestamp + daysToStart * 1 minutes; // testing with minutes
        chains[numChains] = Chain(
            numChains,
            msg.sender,
            1,
            amountToPay,
            initialDate,
            daysToPay * 1 minutes, // testing with minutes
            0,
            new address[](0)
        );

        chains[numChains].users.push(msg.sender);
        timesPaid[numChains][msg.sender] = 0;
        hasWithdraw[numChains][msg.sender] = false;
        isInChain[msg.sender][numChains] = true;

        return numChains++; // returns chain Id
    }

    function enterChain(uint256 chainId) public notBanned {
        require(chainId < numChains, "Chain id doesn't exists");
        require(
            chains[chainId].initialDate > block.timestamp,
            "The chain has already started"
        );
        require(
            !isInChain[msg.sender][chainId],
            "You are already in this chain"
        );

        chains[chainId].users.push(msg.sender);
        chains[chainId].validUsers++;
        timesPaid[chainId][msg.sender] = 0;
        hasWithdraw[chainId][msg.sender] = false;
        isInChain[msg.sender][chainId] = true;
    }

    function pay(uint256 chainId) public payable notBanned returns (bool) {
        require(chainId < numChains, "Chain id doesn't exists");
        require(!chainHasEnded(chainId), "The chain has ended");
        require(isInChain[msg.sender][chainId], "You are not in this chain");
        require(
            chains[chainId].initialDate < block.timestamp,
            "The chain hasn't started yet"
        );
        require(
            numPayments(chainId) > timesPaid[chainId][msg.sender],
            "You don't owe anything"
        );
        require(
            msg.value == chains[chainId].amountToPay,
            "The amount sent is not correct"
        );

        chains[chainId].balance += msg.value;
        timesPaid[chainId][msg.sender]++;
        return true;
    }

    function withdraw(uint256 chainId) public notBanned {
        require(chainId < numChains, "Chain id doesn't exists");
        require(isInChain[msg.sender][chainId], "You are not in this chain");
        require(canWithdraw(chainId, msg.sender), "You can't withdraw yet");
        require(
            !hasWithdraw[chainId][msg.sender],
            "You have already withdrawn"
        );
        require(
            numPayments(chainId) == timesPaid[chainId][msg.sender],
            "You owe money, please pay before withdrawing"
        );

        uint256 total = chains[chainId].amountToPay *
            chains[chainId].validUsers;

        require(
            chains[chainId].balance >= total || chainHasEnded(chainId),
            "Other users in the chain hasn't paid yet"
        );

        assert(payable(msg.sender).send(total));

        hasWithdraw[chainId][msg.sender] = true;
    }

    function ban(uint256 chainId, address user) public isOwner(chainId) {
        require(
            isInChain[user][chainId],
            "The user is not in the specific chain"
        );
        require(!isBanned(user), "The user is already banned");
        require(user != msg.sender, "You can't ban yourself");
        require(
            numPayments(chainId) > timesPaid[chainId][user],
            "The user don't owe anything"
        );

        timesBeingBanned[user]++;
        if (timesBeingBanned[user] >= 10) {
            banDate[user] = -1;
        } else {
            banDate[user] = int256(
                timesBeingBanned[user] * 1 minutes + block.timestamp // testing with minutes
            );
        }

        for (uint256 i = 0; i < numChains; i++) {
            if (isInChain[user][i]) {
                isInChain[user][i] = false;
                chains[i].validUsers--;
            }
        }
    }

    /// ---- info methods ---- ///

    function getIndebtedUsers(uint256 chainId)
        public
        view
        isOwner(chainId)
        returns (address[] memory)
    {
        require(chainId < numChains, "Chain id doesn't exists");

        address[] memory addrs = new address[](chains[chainId].validUsers);

        uint256 k = 0;
        for (uint256 i = 0; i < chains[chainId].users.length; i++) {
            address user = chains[chainId].users[i];
            if (
                isInChain[user][chainId] &&
                numPayments(chainId) - 1 > timesPaid[chainId][user]
                && user != chains[chainId].owner
            ) {
                addrs[k] = user;
                k++;
            }
        }

        return addrs;
    }

    /// ---- internal funcions ---- ///

    function numPayments(uint256 chainId) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - chains[chainId].initialDate;

        uint256 payments = uint256(timeElapsed / chains[chainId].timeToPay) + 1;

        if (payments <= chains[chainId].validUsers) {
            return payments;
        }
        return chains[chainId].validUsers;
    }

    function chainHasEnded(uint256 chainId) internal view returns (bool) {
        uint256 timeElapsed = block.timestamp - chains[chainId].initialDate;

        return
            timeElapsed >
            chains[chainId].timeToPay * chains[chainId].users.length;
    }

    function isBanned(address user) internal view returns (bool) {
        return
            banDate[user] == -1 || // is banned indefinitely after 10 times banned
            uint256(banDate[user]) >= block.timestamp;
    }

    function canWithdraw(uint256 chainId, address user)
        internal
        view
        returns (bool)
    {
        uint256 timeElapsed = block.timestamp - chains[chainId].initialDate;

        int256 index = -1;
        for (uint256 i = 0; i < chains[chainId].users.length; i++) {
            if (chains[chainId].users[i] == user) {
                index = int256(i);
                break;
            }
        }

        assert(index != -1);

        return chains[chainId].timeToPay * uint256(index) <= timeElapsed;
    }
}
