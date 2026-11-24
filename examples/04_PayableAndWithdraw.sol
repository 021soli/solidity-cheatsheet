// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// Receiving and sending ETH safely.
contract PayableAndWithdraw {
    mapping(address => uint256) public balances;
    uint256 private _locked = 1; // simple reentrancy lock

    event Deposited(address indexed who, uint256 amount);
    event Withdrawn(address indexed who, uint256 amount);

    error NothingToWithdraw();
    error TransferFailed();
    error Reentrancy();

    modifier nonReentrant() {
        if (_locked != 1) revert Reentrancy();
        _locked = 2;
        _;
        _locked = 1;
    }

    // `payable` lets a function receive ETH. The amount is msg.value.
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // Plain ETH sent with no calldata lands here.
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // Checks -> Effects -> Interactions: update state BEFORE sending ETH.
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NothingToWithdraw();

        balances[msg.sender] = 0;                              // effect first

        (bool ok, ) = msg.sender.call{value: amount}("");      // interaction last
        if (!ok) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }
}
