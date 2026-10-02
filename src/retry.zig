const std = @import("std");
const types = @import("types.zig");

pub const DEFAULT_TIMEOUT_MS: u64 = 10_000;
pub const DEFAULT_MAX_RETRIES: u8 = 2;
pub const DEFAULT_RETRY_POLICY = types.RetryPolicy{};

/// Capped exponential backoff with subtractive jitter, matching the SDK policy.
pub fn retryDelayMs(attempt: u8, policy: types.RetryPolicy, random: f64) u64 {
    const shift: u6 = @intCast(@min(attempt, 63));
    const multiplied = std.math.mul(u64, policy.backoffInitialMs, @as(u64, 1) << shift) catch std.math.maxInt(u64);
    const exponential = @min(multiplied, policy.backoffMaxMs);
    const jitter = std.math.clamp(random, 0, 1) * policy.backoffJitter;
    return @intFromFloat(@round(@as(f64, @floatFromInt(exponential)) * (1 - jitter)));
}

pub fn parseRetryAfter(value: []const u8) ?u64 {
    const seconds = std.fmt.parseFloat(f64, value) catch return null;
    if (seconds < 0 or !std.math.isFinite(seconds)) return null;
    return @intFromFloat(@round(seconds * 1000));
}

test "retry delay is capped and jittered" {
    const policy = types.RetryPolicy{ .backoffInitialMs = 500, .backoffMaxMs = 1000, .backoffJitter = 0.25 };
    try std.testing.expectEqual(@as(u64, 875), retryDelayMs(4, policy, 0.5));
    try std.testing.expectEqual(@as(?u64, 1500), parseRetryAfter("1.5"));
}
