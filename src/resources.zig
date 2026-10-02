const std = @import("std");
const client = @import("client.zig");
const types = @import("types.zig");

/// Access to the Models API resource. Zig exposes it without storing a self-reference in the client.
pub const Models = struct {
    client: *client.TypeSafeClient,

    pub fn list(self: Models, options: types.RequestOptions) !std.json.Parsed(types.ModelsResult) {
        return self.client.listModels(options);
    }
};
