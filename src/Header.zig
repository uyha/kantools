const std = @import("std");

const Self = @This();

const Error = error{
    IncompleteMessage,
    MissingColon,
    UnknownHeader,
    MissingContentLength,
};

content_length: usize,
content_type: ?[]const u8 = null,
allocator: ?std.mem.Allocator = null,

pub fn deinit(self: Self) void {
    if (self.allocator) |allocator| {
        allocator.free(self.content_type.?);
    }
}

pub fn read(reader: anytype, allocator: std.mem.Allocator) !Self {
    var result = Self{ .content_length = undefined };
    errdefer result.deinit();

    var content_length_found = false;
    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    while (true) {
        if (reader.readByte()) |byte| {
            try buffer.append(byte);
        } else |_| {
            return Error.IncompleteMessage;
        }

        if (buffer.items.len == 2 and std.mem.eql(u8, "\r\n", buffer.items)) {
            break;
        }

        if (!(buffer.items.len >= 2 and
            std.mem.eql(u8, "\r\n", buffer.items[buffer.items.len - 2 .. buffer.items.len])))
        {
            continue;
        }

        const colon_index = std.mem.indexOf(u8, buffer.items, ":") orelse return Error.MissingColon;

        const header_name = buffer.items[0..colon_index];
        const header_value = std.mem.trim(u8, buffer.items[colon_index + 1 .. buffer.items.len - 2], " \t");

        if (std.mem.eql(u8, "Content-Length", header_name)) {
            result.content_length = try std.fmt.parseInt(usize, header_value, 10);
            content_length_found = true;
        } else if (std.mem.eql(u8, "Content-Type", header_name)) {
            result.allocator = allocator;
            result.content_type = try allocator.dupe(u8, header_value);
        } else {
            return Error.UnknownHeader;
        }

        try buffer.resize(0);
    }

    if (!content_length_found) return Error.MissingContentLength;

    return result;
}

pub fn write(self: *const Self, writer: anytype) @TypeOf(writer).Error!void {
    try writer.print("Content-Length: {}\r\n", .{self.content_length});
    if (self.content_type) |content_type| {
        try writer.print("Content-Type: {s}\r\n", .{content_type});
    }
    try writer.writeAll("\r\n");
}

pub fn format(value: *const Self, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
    try std.fmt.format(writer, "Header{{ .content_length = {}, .content_type = {any} }}", .{ value.content_length, value.content_type });
}

test "Valid headers" {
    const sliceReader = @import("slice_reader.zig").sliceReader;
    const testing = @import("std").testing;

    {
        const inputs = [_][]const u8{
            "Content-Length:10\r\n\r\n",
            "Content-Length: 10\r\n\r\n",
            "Content-Length:10 \r\n\r\n",
            "Content-Length: 10 \r\n\r\n",
        };

        for (inputs) |input| {
            var slice_reader = sliceReader(input);
            const reader = slice_reader.reader();

            const result = try read(reader, testing.allocator);
            try testing.expectEqual(10, result.content_length);
            try testing.expectEqual(null, result.content_type);
        }
    }

    {
        const inputs = [_][]const u8{
            "Content-Length:10\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length: 10\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length:10 \r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length: 10 \r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length:10\r\nContent-Type:application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length: 10\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n",
            "Content-Length:10 \r\nContent-Type:application/vscode-jsonrpc; charset=utf-8 \r\n\r\n",
            "Content-Length: 10 \r\nContent-Type: application/vscode-jsonrpc; charset=utf-8 \r\n\r\n",
        };

        for (inputs) |input| {
            var slice_reader = sliceReader(input);
            const reader = slice_reader.reader();

            const result = try read(reader, testing.allocator);
            defer result.deinit();
            try testing.expectEqual(10, result.content_length);
            try testing.expectEqualStrings("application/vscode-jsonrpc; charset=utf-8", result.content_type.?);
        }
    }
}

test "Invalid headers" {
    const sliceReader = @import("slice_reader.zig").sliceReader;
    const testing = @import("std").testing;

    {
        const input = "Content-Length:";
        var slice_reader = sliceReader(input);
        const reader = slice_reader.reader();

        const result = read(reader, testing.allocator);
        try testing.expectError(Error.IncompleteMessage, result);
    }
    {
        const input = "Content-Length: 10\r\n";
        var slice_reader = sliceReader(input);
        const reader = slice_reader.reader();

        const result = read(reader, testing.allocator);
        try testing.expectError(Error.IncompleteMessage, result);
    }
    {
        const input = "Content-Length: a\r\n\r\n";
        var slice_reader = sliceReader(input);
        const reader = slice_reader.reader();

        const result = read(reader, testing.allocator);
        try testing.expectError(error.InvalidCharacter, result);
    }
    {
        const input = "Content-Lengt: \r\n\r\n";
        var slice_reader = sliceReader(input);
        const reader = slice_reader.reader();

        const result = read(reader, testing.allocator);
        try testing.expectError(Error.UnknownHeader, result);
    }
}
