const std = @import("std");

content: std.ArrayList(u8),
allocator: std.mem.Allocator,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .content = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.content.deinit();
}

pub fn read(self: *Self, reader: anytype, length: usize) !void {
    var bytes_read: usize = 0;
    try self.content.resize(length);
    while (bytes_read != length) {
        bytes_read += try reader.read(self.content.items[bytes_read..length]);
    }
}

pub fn parse(self: *const Self, comptime T: type) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, self.allocator, self.content.items, .{ .ignore_unknown_fields = true });
}

test "read" {
    const sliceReader = @import("slice_reader.zig").sliceReader;
    const testing = @import("std").testing;

    var content = init(testing.allocator);
    defer content.deinit();

    for ([_][]const u8{ "{}", "{\"name\":\"World\"}" }) |input| {
        var slice_reader = sliceReader(input);
        try content.read(slice_reader.reader(), input.len);

        try testing.expectEqualStrings(input, content.content.items);
    }
}

const Id = union(enum) {
    string: []const u8,
    integer: i32,

    pub fn jsonParse(_: std.mem.Allocator, source: anytype, _: std.json.ParseOptions) !Id {
        return switch (try source.next()) {
            .number => |number| Id{ .integer = try std.fmt.parseInt(i32, number, 10) },
            .string => |string| Id{ .string = string },
            else => error.UnexpectedToken,
        };
    }
};

test "parse" {
    const sliceReader = @import("slice_reader.zig").sliceReader;
    const testing = @import("std").testing;

    var content = init(testing.allocator);
    defer content.deinit();

    const input =
        \\{
        \\  "id": "sadf"
        \\}
    ;
    var slice_reader = sliceReader(input);
    try content.read(slice_reader.reader(), input.len);

    const value = try content.parse(struct { id: Id });
    defer value.deinit();
    try testing.expectEqualStrings("sadf", value.value.id.string);
}
