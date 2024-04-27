// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Lock {
    uint public data;

    constructor() {
        data = 19231;
    }

    function setData(uint newData) public {
        data = data + newData;
    }

    function getData() public view returns (uint) {
        return data;
    }
}
