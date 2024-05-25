const Self = @This();

const types = @import("lsp.zig");
const std = @import("std");

const HandledRequestMethod = enum { initialize };

pub fn processMessage(_: *const Self, message: types.Message, writer: anytype, allocator: std.mem.Allocator) !void {
    switch (message) {
        .request => |request| {
            const requestMethod = std.meta.stringToEnum(HandledRequestMethod, request.method) orelse {
                return try responseResult(request.id, null, writer);
            };

            switch (requestMethod) {
                inline else => |method| {
                    try routeRequest(method, request, writer, allocator);
                },
            }
        },
        else => {},
    }
}

fn routeRequest(comptime method: HandledRequestMethod, request: types.Message.Request, writer: anytype, allocator: std.mem.Allocator) !void {
    const Params = getRequestMetadata(@tagName(method)).?.Params.?;
    const params = try std.json.parseFromValue(Params, allocator, request.params.?, .{});
    defer params.deinit();

    const result = switch (comptime method) {
        .initialize => handleIntialize(params.value),
    };

    try responseResult(request.id, result, writer);
}

fn handleIntialize(params: types.InitializeParams) types.InitializeResult {
    _ = params;
    return types.InitializeResult{ .capabilities = .{}, .serverInfo = .{ .name = "kantools", .version = "0.1" } };
}

fn responseResult(@"?id": ?types.Message.ID, result: anytype, writer: anytype) !void {
    try writer.writeAll(
        \\{"jsonrpc":"2.0"
    );
    if (@"?id") |id| {
        try writer.writeAll(
            \\,"id":
        );
        try std.json.stringify(id, .{}, writer);
    }

    switch (comptime @typeInfo(@TypeOf(result))) {
        .Null => try writer.writeAll(
            \\,"result": null
        ),
        .Optional => |@"?result"| {
            try writer.writeAll(
                \\,"result":
            );
            if (@"?result") |response| {
                std.json.stringify(response, .{}, writer);
            } else {
                writer.writeAll(null);
            }
        },
        .Struct => {
            try writer.writeAll(
                \\,"result":
            );
            try std.json.stringify(result, .{ .emit_null_optional_fields = false }, writer);
        },
        else => {},
    }

    try writer.writeByte('}');
}

fn getRequestMetadata(comptime method: []const u8) ?types.RequestMetadata {
    for (types.request_metadata) |meta| {
        if (std.mem.eql(u8, method, meta.method)) {
            return meta;
        }
    }
    return null;
}

fn getNotificationMetadata(comptime method: []const u8) ?types.NotificationMetadata {
    for (types.notification_metadata) |meta| {
        if (std.mem.eql(u8, method, meta.method)) {
            return meta;
        }
    }
    return null;
}