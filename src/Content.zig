const std = @import("std");

content: std.ArrayList(u8),
allocator: std.mem.Allocator,

const Self = @This();

pub fn deinit(self: Self) void {
    self.content.deinit();
}

pub fn read(reader: anytype, length: usize, allocator: std.mem.Allocator) !Self {
    var bytes_read: usize = 0;
    var result = Self{ .content = std.ArrayList(u8).init(allocator), .allocator = allocator };
    try result.content.resize(length);
    while (bytes_read != length) {
        bytes_read += try reader.read(result.content.items[bytes_read..length]);
    }

    return result;
}

pub fn parse(self: *const Self, comptime T: type) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, self.allocator, self.content.items, .{ .ignore_unknown_fields = true });
}

test "read" {
    const sliceReader = @import("slice_reader.zig").sliceReader;
    const testing = @import("std").testing;

    for ([_][]const u8{ "{}", "{\"name\":\"World\"}" }) |input| {
        var slice_reader = sliceReader(input);
        const content = try read(slice_reader.reader(), input.len, testing.allocator);
        defer content.deinit();

        try testing.expectEqualStrings(input, content.content.items);
    }
}
