const std = @import("std");
const types = @import("types.zig");

pub const LOG_LEVELS = [_]types.LogLevel{ .debug, .info, .warn, .err, .off };
pub const DEFAULT_LOG_LEVEL: types.LogLevel = .warn;

pub fn parseLogLevel(value: []const u8) !types.LogLevel {
    if (std.mem.eql(u8, value, "debug")) return .debug;
    if (std.mem.eql(u8, value, "info")) return .info;
    if (std.mem.eql(u8, value, "warn")) return .warn;
    if (std.mem.eql(u8, value, "error")) return .err;
    if (std.mem.eql(u8, value, "off")) return .off;
    return error.InvalidConfiguration;
}

/// Masks credential headers while retaining the last four characters of long keys.
pub fn redactHeader(allocator: std.mem.Allocator, header: std.http.Header) !std.http.Header {
    const key = std.ascii.eqlIgnoreCase(header.name, "authorization") or
        std.ascii.eqlIgnoreCase(header.name, "proxy-authorization") or
        std.ascii.eqlIgnoreCase(header.name, "x-api-key");
    const is_opaque = std.ascii.eqlIgnoreCase(header.name, "cookie") or
        std.ascii.eqlIgnoreCase(header.name, "set-cookie");
    if (is_opaque) return .{ .name = header.name, .value = "***" };
    if (!key) return header;
    const tail = if (header.value.len > 8) header.value[header.value.len - 4 ..] else "";
    return .{ .name = header.name, .value = try std.fmt.allocPrint(allocator, "***{s}", .{tail}) };
}

test "credential values are redacted" {
    const h = try redactHeader(std.testing.allocator, .{ .name = "x-api-key", .value = "secret-key-1234" });
    defer std.testing.allocator.free(h.value);
    try std.testing.expectEqualStrings("***1234", h.value);
}
