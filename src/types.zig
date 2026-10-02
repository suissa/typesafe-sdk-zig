const std = @import("std");

pub const JsonValue = std.json.Value;
pub const EntryType = JsonValue;
pub const Description = EntryType;

pub const NoulCriteria = struct { yes: ?EntryType = null, no: ?EntryType = null };
pub const NoulQuestion = struct { type: []const u8 = "noul", instructions: EntryType = .null, criteria: ?NoulCriteria = null };
pub const ChoiceCriteria = std.json.ObjectMap;
pub const ChoiceQuestion = struct { type: []const u8 = "choice", instructions: EntryType, criteria: ChoiceCriteria };
pub const ScoreCriteria = std.json.Array;
pub const ScoreQuestion = struct { type: []const u8 = "score", instructions: EntryType, criteria: ScoreCriteria };
pub const Question = union(enum) { noul: NoulQuestion, choice: ChoiceQuestion, score: ScoreQuestion };
pub const Questions = std.StringArrayHashMap(Question);

pub const NoulResponse = struct { type: []const u8, noul: f64 };
pub const ChoiceResponse = struct { type: []const u8, choice: []const u8, confidence: f64, probabilities: std.json.Value };
pub const ScoreResponse = struct { type: []const u8, score: f64, confidence: f64, legend: std.json.Value, probabilities: std.json.Value };
pub const Usage = struct { input_tokens: u64, output_tokens: u64 };
pub const SystemOneResult = struct { model: []const u8, answers: std.json.Value, usage: Usage };
pub const ModelCard = struct { name: []const u8, description: []const u8, release_date: []const u8 };
pub const ModelsResult = struct { models: []ModelCard };

pub const SystemOneRequest = struct {
    state: EntryType,
    questions: *const Questions,
    model: ?[]const u8 = null,
};

pub const LogLevel = enum { debug, info, warn, err, off };
pub const RetryPolicy = struct {
    maxRetries: u8 = 2,
    backoffInitialMs: u64 = 500,
    backoffMaxMs: u64 = 5000,
    backoffJitter: f64 = 0.25,
    respectRetryAfter: bool = true,
    maxRetryAfterMs: u64 = 60_000,
    apiConnectionError: bool = true,
    apiTimeoutError: bool = true,

    pub fn retriesStatus(_: RetryPolicy, status: u16) bool {
        return status == 408 or status == 429 or status >= 500;
    }
};

pub const RequestOptions = struct {
    timeout: ?u64 = null,
    retry: ?RetryPolicy = null,
    headers: []const std.http.Header = &.{},
};

pub const TypeSafeClientConfig = struct {
    apiKey: ?[]const u8 = null,
    baseURL: ?[]const u8 = null,
    defaultModel: ?[]const u8 = null,
    logLevel: ?LogLevel = null,
    retry: RetryPolicy = .{},
    timeout: u64 = 10_000,
    defaultHeaders: []const std.http.Header = &.{},
    maxResponseBytes: usize = 8 * 1024 * 1024,
};

/// Writes only the wire question object, without the union tag.
pub fn writeQuestion(question: Question, writer: anytype) !void {
    switch (question) {
        inline else => |payload| try writer.write(payload),
    }
}
