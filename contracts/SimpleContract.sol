// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

contract ChainGame {
    struct Player {
        string name;
        bool inGame;
        uint[] gameIds;
    }

    struct Game {
        address owner;
        address[] players;
        address nextToPay;
        uint initialDate;
        uint timeToPay;
    }

    uint numGames = 0;
    mapping (uint => Game) public games;
    mapping (address => Player) public players;
    mapping (address => bool) private registered;
    mapping (uint => mapping(address => bool)) private hasPaid;
    mapping (address => bool) private blacklist;

    modifier notRegistered {
        require(!registered[msg.sender], "Already registered");
        _;
    }

    modifier isOwner(uint gameId) {
        require(games[gameId].owner == msg.sender, "You are not the owner of this game");
        _;
    }

    function register(string memory name) public notRegistered {
        Player memory newPlayer = Player(name, false, new uint[](0));
        players[msg.sender] = newPlayer;
        registered[msg.sender] = true;
    }

    function createGame(uint daysToStart, uint daysToPay) public returns (uint) {
        uint initialDate = block.timestamp + daysToStart * 1 days;
        games[numGames] = Game(
            msg.sender,
            new address[](0),
            msg.sender,
            initialDate,
            daysToPay * 1 days
        );
    
        games[numGames].players.push(msg.sender);
        players[msg.sender].gameIds.push(numGames);

        return numGames++;
    }

    function enterGame(uint gameId) public {
        games[gameId].players.push(msg.sender);
        players[msg.sender].gameIds.push(gameId);
    }

    function myGames() view public returns(Game[] memory) {
        uint[] memory gameIds = players[msg.sender].gameIds;

        Game[] memory tmpGames = new Game[](gameIds.length);
        for (uint i = 0; i < gameIds.length; i++) {
            tmpGames[i] = games[gameIds[i]];
        }

        return tmpGames;
    }
}
