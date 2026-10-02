/// Header used to correlate requests with TypeSafe support.
pub const REQUEST_ID_HEADER = "x-typesafe-request-id";

/// Synchronous Zig equivalent of the JavaScript SDK's parsed value plus response metadata.
pub fn WithResponse(comptime T: type) type {
    return struct {
        data: T,
        status: u16,
        requestId: ?[]const u8 = null,
    };
}

/// Zig I/O is explicitly synchronous; APIPromise preserves the SDK name as a result container.
pub fn APIPromise(comptime T: type) type {
    return WithResponse(T);
}
