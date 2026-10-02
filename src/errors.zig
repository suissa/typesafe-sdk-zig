/// Errors returned by the TypeSafe SDK. HTTP status names mirror the original SDK.
pub const TypeSafeError = error{
    MissingApiKey,
    InvalidConfiguration,
    InvalidQuestions,
    InvalidResponse,
    APIConnectionError,
    APITimeoutError,
    APIUserAbortError,
    APIError,
    BadRequestError,
    AuthenticationError,
    PermissionDeniedError,
    NotFoundError,
    UnprocessableEntityError,
    RateLimitError,
    InternalServerError,
    ResponseTooLarge,
};

pub const APIError = struct {
    status: u16,
    body: []const u8,
    requestId: ?[]const u8 = null,

    pub fn errorForStatus(status: u16) TypeSafeError {
        return switch (status) {
            400 => error.BadRequestError,
            401 => error.AuthenticationError,
            403 => error.PermissionDeniedError,
            404 => error.NotFoundError,
            422 => error.UnprocessableEntityError,
            429 => error.RateLimitError,
            500...599 => error.InternalServerError,
            else => error.APIError,
        };
    }
};

pub const APIConnectionError = error.APIConnectionError;
pub const APITimeoutError = error.APITimeoutError;
pub const APIUserAbortError = error.APIUserAbortError;
pub const BadRequestError = error.BadRequestError;
pub const AuthenticationError = error.AuthenticationError;
pub const PermissionDeniedError = error.PermissionDeniedError;
pub const NotFoundError = error.NotFoundError;
pub const UnprocessableEntityError = error.UnprocessableEntityError;
pub const RateLimitError = error.RateLimitError;
pub const InternalServerError = error.InternalServerError;

test "HTTP statuses map to public error names" {
    const std = @import("std");
    try std.testing.expectEqual(error.AuthenticationError, APIError.errorForStatus(401));
    try std.testing.expectEqual(error.RateLimitError, APIError.errorForStatus(429));
    try std.testing.expectEqual(error.InternalServerError, APIError.errorForStatus(503));
}
