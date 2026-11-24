// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// A daily claim with a 24-hour cooldown and a streak that survives a grace window.
/// This is the pattern behind the "daily boost" in the Base Arcade games.
contract DailyClaimStreak {
    uint256 public constant COOLDOWN = 1 days;
    uint256 public constant STREAK_WINDOW = 2 days; // miss this window and the streak resets

    struct Claimer {
        uint64 lastClaim;     // 0 means never claimed
        uint32 totalClaims;
        uint32 streak;
    }

    mapping(address => Claimer) public claimers;

    event Claimed(address indexed player, uint32 streak, uint32 totalClaims);

    error TooSoon(uint256 secondsLeft);

    function claim() external {
        Claimer storage c = claimers[msg.sender];

        if (c.lastClaim != 0 && block.timestamp < c.lastClaim + COOLDOWN) {
            revert TooSoon(c.lastClaim + COOLDOWN - block.timestamp);
        }

        // First claim, or came back too late: start over. Otherwise extend the streak.
        if (c.lastClaim == 0 || block.timestamp > c.lastClaim + STREAK_WINDOW) {
            c.streak = 1;
        } else {
            c.streak += 1;
        }

        c.lastClaim = uint64(block.timestamp);
        c.totalClaims += 1;
        emit Claimed(msg.sender, c.streak, c.totalClaims);
    }

    /// Seconds until the next claim is allowed (0 if it can be claimed now).
    function timeUntilNextClaim(address who) public view returns (uint256) {
        uint256 last = claimers[who].lastClaim;
        if (last == 0 || block.timestamp >= last + COOLDOWN) return 0;
        return last + COOLDOWN - block.timestamp;
    }

    function canClaimNow(address who) external view returns (bool) {
        return timeUntilNextClaim(who) == 0;
    }
}
