// Simple test runner for Zig 0.16 (replaces the removed std.special test runner).
const tests = @import("tests");

pub fn main() !void {
    var count: usize = 0;
    var failed: usize = 0;
    for (tests.decls) |decl_fn| {
        const name = tests.names[@intCast(count)];
        count += 1;
        var output = std.mem.zeroes(tests.TestOutput);
        defer if (output.owned_alloc) output.writer.flush() catch {};
        testRunner(decl_fn, name, &output.writer) catch |err| switch (err) {
            error.TestExpectedEqual, error.TestUnreachableWasReached => {
                failed += 1;
                std.debug.print("{s}... FAIL\n", .{name});
                if (output.messages.len != 0) std.debug.print("{s}\n", .{output.messages});
            },
            else => {
                failed += 1;
                std.debug.print("{s}... ERROR: {}\n", .{ name, err });
            },
        };
        if (!output.failed) std.debug.print("[ok] {s}\n", .{name});
    }
    std.debug.print("\n{s}: {d} passed, {d} failed, {d} total\n", .{
        if (failed == 0) "SUCCESS" else "FAILURE",
        count - failed,
        failed,
        count,
    });
    if (failed != 0) return error.TestsFailed;
}
