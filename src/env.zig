const std = @import("std");

/// Environment variable names understood by TypeSafeClient.init.
pub const ENV = struct {
    pub const apiKey = "TYPESAFE_API_KEY";
    pub const baseURL = "TYPESAFE_BASE_URL";
    pub const defaultModel = "TYPESAFE_DEFAULT_MODEL";
    pub const logLevel = "TYPESAFE_LOG_LEVEL";
};

/// Reads and trims an environment variable. The caller owns the returned memory.
pub fn readEnv(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    const value = std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => return null,
        else => return err,
    };
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    if (trimmed.len == 0) {
        allocator.free(value);
        return null;
    }
    if (trimmed.ptr == value.ptr and trimmed.len == value.len) return value;
    const result = try allocator.dupe(u8, trimmed);
    allocator.free(value);
    return result;
}
