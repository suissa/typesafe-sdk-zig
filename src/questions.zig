const std = @import("std");
const types = @import("types.zig");

pub fn noul(instructions: types.EntryType, criteria: ?types.NoulCriteria) types.Question {
    return .{ .noul = .{ .instructions = instructions, .criteria = criteria } };
}

pub fn choice(instructions: types.EntryType, criteria: types.ChoiceCriteria) types.Question {
    return .{ .choice = .{ .instructions = instructions, .criteria = criteria } };
}

pub fn score(instructions: types.EntryType, criteria: types.ScoreCriteria) types.Question {
    return .{ .score = .{ .instructions = instructions, .criteria = criteria } };
}

pub fn validateQuestions(questions: *const types.Questions) !void {
    if (questions.count() == 0) return error.InvalidQuestions;
    for (questions.values()) |question| switch (question) {
        .score => |q| if (q.criteria.items.len < 2) return error.InvalidQuestions,
        .choice => |q| if (q.criteria.count() == 0) return error.InvalidQuestions,
        .noul => {},
    };
}

test "question validation requires questions and score criteria" {
    var questions = types.Questions.init(std.testing.allocator);
    defer questions.deinit();
    try std.testing.expectError(error.InvalidQuestions, validateQuestions(&questions));
    var criteria = types.ScoreCriteria.init(std.testing.allocator);
    defer criteria.deinit();
    try criteria.append(.null);
    try questions.put("quality", score(.{ .string = "Rate it" }, criteria));
    try std.testing.expectError(error.InvalidQuestions, validateQuestions(&questions));
}
