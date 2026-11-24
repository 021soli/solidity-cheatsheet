# Solidity Cheatsheet

A compact cheatsheet for writing small, safe contracts on [Base](https://base.org). Every example in [`examples/`](examples) compiles with Solidity 0.8.28 (EVM `cancun`) and is covered by a test that checks the behavior described here.

## Contents

1. [Quick start](#quick-start)
2. [Data types and locations](#data-types-and-locations)
3. [Functions](#functions)
4. [Events](#events)
5. [Errors and `require`](#errors-and-require)
6. [Modifiers and access control](#modifiers-and-access-control)
7. [Time, cooldowns and streaks](#time-cooldowns-and-streaks)
8. [Sending and receiving ETH](#sending-and-receiving-eth)
9. [Security checklist](#security-checklist)
10. [Gas tips](#gas-tips)
11. [Calling a contract from a web page](#calling-a-contract-from-a-web-page)
12. [Deploy and verify](#deploy-and-verify)

## Quick start

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Counter {
    uint256 public count;                    // public = free getter function

    function increment() external {         // writes state: costs gas
        count += 1;
    }
}
```

- The `SPDX` line is the license. The `pragma` line is the allowed compiler range.
- Set the EVM version to **cancun** when compiling recent OpenZeppelin v5 releases.

## Data types and locations

| Type | Notes |
|------|-------|
| `uint256`, `uint8` … | Unsigned integers. Default to `uint256` unless you are packing storage. |
| `int256` | Signed integers. |
| `bool` | `true` / `false`. |
| `address`, `address payable` | 20-byte account. Only `address payable` can receive ETH through `.transfer()`/`.send()`. |
| `bytes32`, `bytes` | Fixed and dynamic raw bytes. |
| `string` | UTF-8 text. No `.length`. Use `bytes(s).length`. |
| `enum` | Named values, stored as `uint8`. |
| `struct` | Group related fields. |
| `mapping(K => V)` | Every key exists, unset values are zero. Cannot be iterated. |
| `T[]` | Dynamic array. Avoid looping over arrays that can grow without limit. |

**Data locations** for reference types (structs, arrays, strings):

| Location | Meaning |
|----------|---------|
| `storage` | Permanent contract state. A `storage` variable is a reference, so writes change the state. |
| `memory` | Temporary copy that disappears after the call. |
| `calldata` | Read-only call arguments of `external` functions. Cheapest. |

```solidity
Player storage p = players[msg.sender]; // reference: p.bestScore = 5 writes to the mapping
Player memory q = players[msg.sender];  // copy: changes to q are lost
```

Since Solidity 0.8, arithmetic is **checked**: overflow reverts. Wrap code in `unchecked { ... }` only when you have proved it cannot overflow.

Example: [`01_Basics.sol`](examples/01_Basics.sol)

## Functions

| Visibility | Who can call |
|------------|--------------|
| `external` | Only from outside the contract |
| `public` | Outside and inside |
| `internal` | This contract and children |
| `private` | This contract only |

| Mutability | Meaning |
|------------|---------|
| `view` | Reads state, no writes. Free when called off-chain. |
| `pure` | Reads nothing, writes nothing. |
| `payable` | Can receive ETH (`msg.value`). |
| *(none)* | Can write state. |

Useful globals: `msg.sender` (caller), `msg.value` (ETH sent, in wei), `block.timestamp`, `block.number`, `address(this)`.

Return several values so a UI can read everything in one call:

```solidity
function getPlayerStats(address who) external view returns (uint256 best, uint256 runs, bool canClaim) { ... }
```

## Events

Events are cheap logs that apps and indexers read. Mark up to three fields `indexed` so they can be filtered.

```solidity
event ScoreSaved(address indexed player, uint256 score, uint256 wave);

emit ScoreSaved(msg.sender, score, wave);
```

Emit an event for every important state change. Contracts cannot read events, only off-chain code can.

Example: [`02_EventsErrorsModifiers.sol`](examples/02_EventsErrorsModifiers.sol)

## Errors and `require`

Prefer **custom errors**. They are cheaper than revert strings and can carry data.

```solidity
error ScoreTooLow(uint256 sent, uint256 best);

if (score <= best) revert ScoreTooLow(score, best);
```

| Tool | Use for |
|------|---------|
| `require(cond, "msg")` | Short checks where a string is fine. |
| `revert CustomError(args)` | Most checks. Cheaper, easy to decode. |
| `assert(cond)` | Things that must never be false. A failure means a bug. |

A reverted transaction undoes all its state changes. The sender still pays gas for the work done.

## Modifiers and access control

A modifier wraps a function. The `_` marks where the function body runs.

```solidity
modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();
    _;
}

function pause() external onlyOwner { paused = true; }
```

- Use `msg.sender` for authorization. **Never use `tx.origin`**. A malicious contract can trick a user into calling it.
- Use a **two-step ownership transfer** so a typo cannot lock you out: [`05_OwnerTwoStep.sol`](examples/05_OwnerTwoStep.sol).
- In real projects, prefer audited code: OpenZeppelin `Ownable`, `Ownable2Step`, `AccessControl`, `Pausable`.

## Time, cooldowns and streaks

`block.timestamp` is in seconds. Time units: `1 minutes`, `1 hours`, `1 days`, `1 weeks`.

```solidity
uint256 public constant COOLDOWN = 1 days;

if (block.timestamp < lastClaim + COOLDOWN) revert TooSoon(lastClaim + COOLDOWN - block.timestamp);
```

A daily-claim streak is a cooldown plus a window. Claim again inside the window and the streak grows, miss the window and it resets:

```solidity
if (c.lastClaim == 0 || block.timestamp > c.lastClaim + STREAK_WINDOW) c.streak = 1;
else c.streak += 1;
```

Good to know:
- Timestamps are fine for hours and days. Do not rely on them for exact seconds.
- **Never use `block.timestamp` or `blockhash` as randomness.** It is predictable. Use a verifiable random source for anything valuable.
- Expose a `timeUntilNextClaim(address)` view so the UI can show a countdown.

Example: [`03_DailyClaimStreak.sol`](examples/03_DailyClaimStreak.sol)

## Sending and receiving ETH

```solidity
function deposit() external payable { balances[msg.sender] += msg.value; }

receive() external payable { ... }   // plain ETH transfer with no data
```

Send ETH with `call` and check the result. Do not use `.transfer()` or `.send()`, because their fixed 2300 gas limit breaks with many wallets and contracts.

```solidity
(bool ok, ) = msg.sender.call{value: amount}("");
if (!ok) revert TransferFailed();
```

Follow **Checks → Effects → Interactions**: validate, update your state, and only then send ETH or call other contracts. Add a reentrancy guard for extra safety.

Example: [`04_PayableAndWithdraw.sol`](examples/04_PayableAndWithdraw.sol)

## Security checklist

- [ ] Authorization uses `msg.sender`, never `tx.origin`.
- [ ] State is updated **before** external calls (reentrancy).
- [ ] ETH is sent with `call` and the result is checked.
- [ ] Owner-only functions are protected, and ownership moves in two steps.
- [ ] No unbounded loops over user-growable arrays.
- [ ] No on-chain randomness from `block.timestamp`, `blockhash` or `block.number`.
- [ ] `private` is not secret: all storage is readable onchain.
- [ ] Inputs are validated (zero address, zero amounts, ranges).
- [ ] Self-reported data is not trusted. A function like `saveScore(score)` accepts any number from any caller. Treat it as a log, or verify with a server signature or a proof.
- [ ] Events are emitted for every state change that matters.
- [ ] Contract is verified on the block explorer, and tested before mainnet.
- [ ] Anything holding real value is audited.

## Gas tips

Storage writes are the most expensive operation. Savings that matter most:

- Read a storage variable once into a local variable if you use it several times.
- Pack small types together in one struct (`uint64`, `uint32`, `bool`) so they share a storage slot.
- Use `constant` and `immutable` for values that never change.
- Use `calldata` instead of `memory` for read-only `external` arguments.
- Use custom errors instead of revert strings.
- Do not store what you can emit as an event.
- Enable the optimizer (`runs: 200` is a sensible default).

## Calling a contract from a web page

A call is ABI-encoded: the first 4 bytes are the function selector (the start of the keccak256 hash of its signature), followed by the encoded arguments. Do not hand-write selectors. Let a library encode it:

```js
import { ethers } from 'ethers';

const iface = new ethers.Interface(['function saveScore(uint256 score, uint256 wave)']);
const data = iface.encodeFunctionData('saveScore', [1200, 7]);

await provider.request({
  method: 'eth_sendTransaction',
  params: [{ from: userAddress, to: CONTRACT_ADDRESS, data }]
});
```

Tips:
- Send to the **contract address**. Many wallets block a transaction **to your own address that carries data** ("External transactions to internal accounts cannot include data").
- Extra bytes appended after the arguments (such as a Base Builder Code suffix) are ignored by the contract.
- Wallets warn more on unverified contracts. Verify yours on BaseScan.

## Deploy and verify

1. In [Remix](https://remix.ethereum.org), create the `.sol` file and compile. Pick a version that matches your `pragma` and remember the optimizer settings.
2. In **Deploy & Run**, choose *Injected Provider* with MetaMask on Base Sepolia first (chain ID `84532`), then on Base Mainnet (chain ID `8453`).
3. Copy the deployed address and verify the source on [BaseScan](https://basescan.org/verifyContract). Use the same compiler version and optimizer settings as in Remix.
4. Put the address and ABI in your front end.

To run the examples locally with Hardhat, see [base-starter-contracts](../base-starter-contracts).

## Further reading

- [Solidity documentation](https://docs.soliditylang.org)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/)
- [Smart contracts on Base](https://docs.base.org/specifications/reference/smart-contracts)

## License

[MIT](LICENSE)
