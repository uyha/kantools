const std = @import("std");
const testing = std.testing;

const SliceReader = struct {
    slice: []const u8,

    pub const Error = error{};
    pub const Reader = std.io.GenericReader(*SliceReader, Error, read);

    pub fn read(self: *SliceReader, buffer: []u8) !usize {
        const bytes = @min(self.slice.len, buffer.len);
        @memcpy(buffer[0..bytes], self.slice[0..bytes]);
        self.slice = self.slice[bytes..];

        return bytes;
    }

    pub fn reader(self: *SliceReader) Reader {
        return .{ .context = self };
    }
};

pub fn sliceReader(slice: []const u8) SliceReader {
    return .{ .slice = slice };
}

test "Empty slice" {
    const source = [_]u8{};
    var slice_reader = sliceReader(&source);
    var reader = slice_reader.reader();
    try testing.expectError(error.EndOfStream, reader.readByte());
}

test "Filled slice" {
    var slice_reader = sliceReader("1234");
    var reader = slice_reader.reader();
    try testing.expectEqual('1', reader.readByte());
    try testing.expectEqual('2', reader.readByte());
    try testing.expectEqual('3', reader.readByte());
    try testing.expectEqual('4', reader.readByte());
    try testing.expectError(error.EndOfStream, reader.readByte());
}
