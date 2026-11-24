// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Types, data locations, visibility and mutability in one place.
contract Basics {
    // --- State variables -------------------------------------------------
    uint256 public constant MAX_LEVEL = 10;      // fixed at compile time, no storage slot
    address public immutable deployer;           // fixed in the constructor, cheap to read
    uint256 public totalPlayers;                 // normal storage variable

    enum Status { Idle, Running, Finished }      // stored as uint8: 0, 1, 2

    struct Player {
        uint256 bestScore;
        uint64 lastPlayed;                       // small types next to each other can share a slot
        Status status;
    }

    mapping(address => Player) public players;   // every key "exists", unset values are zero
    address[] public playerList;                 // dynamic array

    constructor() {
        deployer = msg.sender;
    }

    // --- Functions: visibility and mutability -----------------------------
    // external: callable from outside only (cheapest for calldata args)
    // public:   callable from outside and inside
    // internal: this contract and children
    // private:  this contract only (still readable onchain by anyone!)
    //
    // view: reads state.  pure: reads nothing.  (neither): writes state.

    function register() external {
        // `storage` makes p a reference: writes go straight to the mapping.
        Player storage p = players[msg.sender];
        require(p.lastPlayed == 0, "already registered");
        p.lastPlayed = uint64(block.timestamp);
        p.status = Status.Idle;
        playerList.push(msg.sender);
        totalPlayers += 1;
    }

    function bestOf(address who) external view returns (uint256) {
        return players[who].bestScore;
    }

    function double(uint256 x) external pure returns (uint256) {
        return x * 2; // checked: reverts on overflow since Solidity 0.8
    }

    // calldata: read-only args for external functions (cheaper than memory).
    // memory:   a temporary copy you can modify.
    function nameLength(string calldata name) external pure returns (uint256) {
        return bytes(name).length;
    }

    function shout(string memory text) public pure returns (string memory) {
        bytes memory b = bytes(text);
        if (b.length > 0 && b[0] >= 0x61 && b[0] <= 0x7a) {
            b[0] = bytes1(uint8(b[0]) - 32); // modify the memory copy
        }
        return string(b);
    }

    // Return several values (UIs read this in a single call).
    function snapshot(address who)
        external
        view
        returns (uint256 bestScore, uint64 lastPlayed, Status status)
    {
        Player storage p = players[who];
        return (p.bestScore, p.lastPlayed, p.status);
    }
}
