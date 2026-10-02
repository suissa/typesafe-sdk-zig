const std = @import("std");
const types = @import("types.zig");
const questions_mod = @import("questions.zig");
const errors = @import("errors.zig");
const env = @import("env.zig");
const retry_mod = @import("retry.zig");
const VERSION = @import("version.zig").VERSION;

pub const DEFAULT_BASE_URL = "https://api.typesafe.ai";
pub const DEFAULT_MODEL = "jev-latest";

pub const TypeSafeClient = struct {
    allocator: std.mem.Allocator,
    api_key: []u8,
    baseURL: []u8,
    defaultModel: []u8,
    logLevel: types.LogLevel,
    retry: types.RetryPolicy,
    timeout: u64,
    defaultHeaders: []const std.http.Header,
    max_response_bytes: usize,
    http: std.http.Client,

    /// Creates a client. Explicit configuration wins over environment variables and defaults.
    pub fn init(allocator: std.mem.Allocator, config: types.TypeSafeClientConfig) !TypeSafeClient {
        const env_key = if (config.apiKey == null) try env.readEnv(allocator, env.ENV.apiKey) else null;
        defer if (env_key) |value| allocator.free(value);
        const key = config.apiKey orelse env_key orelse return error.MissingApiKey;

        const env_base = if (config.baseURL == null) try env.readEnv(allocator, env.ENV.baseURL) else null;
        defer if (env_base) |value| allocator.free(value);
        const env_model = if (config.defaultModel == null) try env.readEnv(allocator, env.ENV.defaultModel) else null;
        defer if (env_model) |value| allocator.free(value);
        if (config.timeout == 0 or config.retry.backoffJitter < 0 or config.retry.backoffJitter > 1) return error.InvalidConfiguration;

        const base = std.mem.trimRight(u8, config.baseURL orelse env_base orelse DEFAULT_BASE_URL, "/");
        return .{
            .allocator = allocator,
            .api_key = try allocator.dupe(u8, key),
            .baseURL = try allocator.dupe(u8, base),
            .defaultModel = try allocator.dupe(u8, config.defaultModel orelse env_model orelse DEFAULT_MODEL),
            .logLevel = config.logLevel orelse .warn,
            .retry = config.retry,
            .timeout = config.timeout,
            .defaultHeaders = config.defaultHeaders,
            .max_response_bytes = config.maxResponseBytes,
            .http = .{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *TypeSafeClient) void {
        self.http.deinit();
        self.allocator.free(self.api_key);
        self.allocator.free(self.baseURL);
        self.allocator.free(self.defaultModel);
        self.* = undefined;
    }

    /// Answers named questions about text or structured state.
    pub fn systemOne(self: *TypeSafeClient, request: types.SystemOneRequest, options: types.RequestOptions) !std.json.Parsed(types.SystemOneResult) {
        try questions_mod.validateQuestions(request.questions);
        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();
        try self.writeSystemOneBody(body.writer(), request);
        const bytes = try self.sendRequest(.POST, "/v1/systemone", body.items, options);
        defer self.allocator.free(bytes);
        return std.json.parseFromSlice(types.SystemOneResult, self.allocator, bytes, .{ .ignore_unknown_fields = true });
    }

    /// Returns the Models API resource bound to this client.
    pub fn models(self: *TypeSafeClient) @import("resources.zig").Models {
        return .{ .client = self };
    }

    /// Lists models available to the account.
    pub fn listModels(self: *TypeSafeClient, options: types.RequestOptions) !std.json.Parsed(types.ModelsResult) {
        const bytes = try self.sendRequest(.GET, "/v1/models", null, options);
        defer self.allocator.free(bytes);
        return std.json.parseFromSlice(types.ModelsResult, self.allocator, bytes, .{ .ignore_unknown_fields = true });
    }

    fn writeSystemOneBody(self: *TypeSafeClient, out: anytype, request: types.SystemOneRequest) !void {
        var jw = std.json.writeStream(out, .{});
        defer jw.deinit();
        try jw.beginObject();
        try jw.objectField("state");
        try jw.write(request.state);
        try jw.objectField("questions");
        try jw.beginObject();
        var iterator = request.questions.iterator();
        while (iterator.next()) |entry| {
            try jw.objectField(entry.key_ptr.*);
            try types.writeQuestion(entry.value_ptr.*, &jw);
        }
        try jw.endObject();
        try jw.objectField("model");
        try jw.write(request.model orelse self.defaultModel);
        try jw.endObject();
    }

    fn sendRequest(self: *TypeSafeClient, method: std.http.Method, path: []const u8, payload: ?[]const u8, options: types.RequestOptions) ![]u8 {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.baseURL, path });
        defer self.allocator.free(url);
        const auth = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.api_key});
        defer self.allocator.free(auth);
        const sdk = "typesafe-sdk/" ++ VERSION;
        const policy = options.retry orelse self.retry;

        var headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer headers.deinit();
        try headers.appendSlice(self.defaultHeaders);
        try headers.appendSlice(options.headers);
        try headers.appendSlice(&.{
            .{ .name = "authorization", .value = auth },
            .{ .name = "accept", .value = "application/json" },
            .{ .name = "user-agent", .value = sdk },
            .{ .name = "x-typesafe-sdk", .value = sdk },
        });
        if (payload != null) try headers.append(.{ .name = "content-type", .value = "application/json" });

        var attempt: u8 = 0;
        while (true) : (attempt += 1) {
            var response = std.ArrayList(u8).init(self.allocator);
            errdefer response.deinit();
            const result = self.http.fetch(.{
                .location = .{ .url = url },
                .method = method,
                .payload = payload,
                .response_storage = .{ .dynamic = &response },
                .max_append_size = self.max_response_bytes,
                .extra_headers = headers.items,
            }) catch |err| {
                response.deinit();
                if (attempt < policy.maxRetries and policy.apiConnectionError) {
                    std.Thread.sleep(retry_mod.retryDelayMs(attempt, policy, 0.5) * std.time.ns_per_ms);
                    continue;
                }
                return switch (err) {
                    error.StreamTooLong => error.ResponseTooLarge,
                    else => error.APIConnectionError,
                };
            };
            const status: u16 = @intFromEnum(result.status);
            if (status >= 200 and status < 300) return response.toOwnedSlice();
            if (attempt < policy.maxRetries and policy.retriesStatus(status)) {
                response.deinit();
                std.Thread.sleep(retry_mod.retryDelayMs(attempt, policy, 0.5) * std.time.ns_per_ms);
                continue;
            }
            response.deinit();
            return errors.APIError.errorForStatus(status);
        }
    }
};
