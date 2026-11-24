// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Events, custom errors and modifiers.
contract EventsErrorsModifiers {
    address public owner;
    bool public paused;
    mapping(address => uint256) public bestScore;

    // Events: cheap logs that UIs and indexers read. Up to 3 `indexed` fields can be filtered.
    event ScoreSaved(address indexed player, uint256 score, uint256 wave);
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    // Custom errors: cheaper than revert strings and can carry data.
    error NotOwner();
    error ContractPaused();
    error ScoreTooLow(uint256 sent, uint256 best);

    constructor() {
        owner = msg.sender;
    }

    // A modifier wraps a function. `_` is where the function body runs.
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    function saveScore(uint256 score, uint256 wave) external whenNotPaused {
        uint256 best = bestScore[msg.sender];
        if (score <= best) revert ScoreTooLow(score, best);
        bestScore[msg.sender] = score;
        emit ScoreSaved(msg.sender, score, wave);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }
}
