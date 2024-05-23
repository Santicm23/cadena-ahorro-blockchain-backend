// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.24;

contract ChainGame {
    /// ---- Data models ---- ///
    struct Player {
        string name;
        bool inGame;
        uint256 gameId;
    }

    struct Game {
        address owner;
        address[] players;
        uint256 amount;
        uint256 initialDate;
        uint256 timeToPay;
        uint256 daysOfGrace;
        uint256 balance;
        uint256[] numPayments;
        uint256 numPlayersWithdraw;
    }

    /// ---- Global atributes ---- ///
    uint256 numGames = 0;
    mapping(uint256 => Game) private games;
    mapping(address => Player) private players;
    mapping(address => bool) private registered;
    mapping(uint256 => mapping(address => bool)) private canReceive;
    mapping(address => bool) private blacklist;

    /// ---- modifiers ---- ///
    modifier notRegistered() {
        require(!registered[msg.sender], "Already registered");
        _;
    }

    modifier isRegistered() {
        require(registered[msg.sender], "Not registered");
        _;
    }

    modifier isNotInGame() {
        if (gameHasEnded(players[msg.sender].gameId)) {
            players[msg.sender].inGame = false;
        }
        require(!players[msg.sender].inGame, "You are already in a game");
        _;
    }

    modifier isActiveGame(uint256 gameId) {
        require(!gameHasEnded(gameId), "The game has already ended");
        require(
            games[gameId].initialDate > block.timestamp,
            "The game has already started"
        );
        _;
    }

    modifier gameHasStarted(uint256 gameId) {
        require(
            games[gameId].initialDate < block.timestamp,
            "The game hasn't started yet"
        );
        _;
    }

    modifier notInBlackList(uint256 gameId) {
        require(!inBlacklist(msg.sender, gameId));
        _;
    }

    modifier isInGame(address player, uint256 gameId) {
        require(
            players[player].inGame && !gameHasEnded(gameId),
            "You are not in a game"
        );
        bool found = false;
        if (players[player].gameId == gameId) {
            found = true;
        }
        require(found, "You are not in the specified game");
        _;
    }

    /// ---- internal funcions ---- ///

    function shufflePlayers(uint256 gameId) internal {
        Game storage game = games[gameId];
        uint256 n = game.players.length;
        while (n > 1) {
            uint256 randIndex = uint256(
                keccak256(abi.encodePacked(block.timestamp, msg.sender, n))
            ) % n;
            n--;
            address temp = game.players[n];
            game.players[n] = game.players[randIndex];
            game.players[randIndex] = temp;
        }
    }

    function getIndexFromGame(address player, uint256 gameId)
        internal
        view
        isInGame(player, gameId)
        returns (int256)
    {
        int256 index = -1;
        for (uint256 i = 0; i < games[gameId].players.length; i++) {
            if (games[gameId].players[i] == player) {
                index = int256(i);
                break;
            }
        }
        return index;
    }

    function numTimesPaid(uint256 gameId) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - games[gameId].initialDate;

        uint256 timesPaid = uint256(timeElapsed / games[gameId].timeToPay);

        assert(timesPaid < games[gameId].players.length);

        return uint256(timeElapsed / games[gameId].timeToPay);
    }

    function canPay(address player, uint256 gameId) internal returns (bool) {
        uint256 timesPaid = numTimesPaid(gameId);

        uint256 index = uint256(getIndexFromGame(player, gameId));

        if (timesPaid - 1 > games[gameId].numPayments[index]) {
            if (
                timesPaid - 2 == games[gameId].numPayments[index] &&
                nextToWithdraw(gameId) == index
            ) {
                games[gameId].numPayments[index]++;
                return true;
            }

            return false;
        }

        return true;
    }

    function hasPaid(address player, uint256 gameId) internal returns (bool) {
        uint256 timesPaid = numTimesPaid(gameId);
        uint256 index = uint256(getIndexFromGame(player, gameId));

        if (timesPaid == games[gameId].numPayments[index]) {
            return true;
        }
        if (
            timesPaid - 1 == games[gameId].numPayments[index] &&
            nextToWithdraw(gameId) == index
        ) {
            games[gameId].numPayments[index]++;
            return true;
        }

        return false;
    }

    function canReceivePayment(address player, uint256 gameId)
        internal
        view
        returns (bool)
    {
        if (canReceive[gameId][player]) {
            return true;
        }
        uint256 index = nextToWithdraw(gameId);

        return player == games[gameId].players[index];
    }

    function inBlacklist(address player, uint256 gameId)
        internal
        returns (bool)
    {
        if (blacklist[player]) {
            return true;
        }

        if (canPay(player, gameId)) {
            return false;
        }

        blacklist[player] = true;

        return false;
    }

    function gameHasEnded(uint256 gameId) internal view returns (bool) {
        uint256 timeElapsed = block.timestamp - games[gameId].initialDate;

        return
            timeElapsed >
            games[gameId].timeToPay * games[gameId].players.length;
    }

    /// ---- contract methods ---- ///

    // --- Game info methods --- //
    function allActiveGames() public view isRegistered returns (Game[] memory) {
        Game[] memory tmpGames = new Game[](numGames);

        uint256 k = 0;
        for (uint256 i = 0; i < numGames; i++) {
            if (games[i].initialDate < block.timestamp) {
                continue;
            }
            tmpGames[k] = games[i];
            k++;
        }

        return tmpGames;
    }

    function getGameInfo(uint256 gameId)
        public
        view
        isRegistered
        returns (Game memory)
    {
        return games[gameId];
    }

    function createGame(
        uint256 amount,
        uint256 daysToStart,
        uint256 daysToPay,
        uint256 daysOfGrace
    ) public isRegistered isNotInGame returns (uint256) {
        assert(amount > 0);
        assert(daysToStart > 0);
        assert(daysToPay > 0);

        uint256 initialDate = block.timestamp + daysToStart * 1 days;
        games[numGames] = Game(
            msg.sender,
            new address[](0),
            amount,
            initialDate,
            daysToPay * 1 days,
            daysOfGrace * 1 days,
            0,
            new uint256[](0),
            0
        );

        games[numGames].players.push(msg.sender);
        players[msg.sender].gameId = numGames;
        players[msg.sender].inGame = true;
        games[numGames].numPayments.push(0);

        return numGames++;
    }

    function enterGame(uint256 gameId)
        public
        isRegistered
        notInBlackList(gameId)
        isNotInGame
        isActiveGame(gameId)
    {
        games[gameId].players.push(msg.sender);
        players[msg.sender].gameId = gameId;
        games[gameId].numPayments.push(0);
        shufflePlayers(gameId);
    }

    function register(string memory name) public notRegistered {
        Player memory newPlayer = Player(name, false, 0);
        players[msg.sender] = newPlayer;
        registered[msg.sender] = true;
    }

    function playersByGameId(uint256 gameId)
        public
        view
        isRegistered
        returns (Player[] memory)
    {
        address[] memory playersAddresses = games[gameId].players;

        Player[] memory tmpPlayers = new Player[](playersAddresses.length);
        for (uint256 i = 0; i < playersAddresses.length; i++) {
            tmpPlayers[i] = players[playersAddresses[i]];
        }

        return tmpPlayers;
    }

    function nextToWithdraw(uint256 gameId)
        public
        view
        gameHasStarted(gameId)
        returns (uint256)
    {
        uint256 timeElapsed = block.timestamp - games[gameId].initialDate;

        uint256 index = uint256(timeElapsed / games[gameId].timeToPay);

        return index;
    }

    // --- Player info methods --- //
    function getMyInfo() public view isRegistered returns (Player memory) {
        return players[msg.sender];
    }

    function myGame() public isRegistered returns (Game memory) {
        if (gameHasEnded(players[msg.sender].gameId)) {
            players[msg.sender].inGame = false;
            assert(false);
        }
        return games[players[msg.sender].gameId];
    }

    // --- Game logic methods --- //

    function pay(uint256 gameId)
        public
        payable
        isRegistered
        isInGame(msg.sender, gameId)
        gameHasStarted(gameId)
        notInBlackList(gameId)
        returns (bool)
    {
        if (!canPay(msg.sender, gameId)) {
            blacklist[msg.sender] = true;
            return false;
        }
        assert(msg.value == games[gameId].amount);
        assert(!hasPaid(msg.sender, gameId));

        uint256 index = uint256(getIndexFromGame(msg.sender, gameId));
        games[gameId].balance += msg.value;
        games[gameId].numPayments[index]++;
        return true;
    }

    function withdraw(uint256 gameId)
        public
        payable
        isRegistered
        isInGame(msg.sender, gameId)
        notInBlackList(gameId)
    {
        address payable player = payable(msg.sender);

        uint256 total = games[gameId].amount * games[gameId].players.length;

        assert(games[gameId].balance >= total);

        assert(player.send(total));
    }
}
