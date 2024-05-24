const std = @import("std");
const kantools = @import("kantools");
const sliceReader = kantools.slice_reader.sliceReader;
const Header = kantools.Header;

pub fn main() !void {
    var slice_reader = sliceReader("Content-Length: 13\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n");
    const reader = slice_reader.reader();
    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    {
        const header = try Header.parse(reader, allocator.allocator());
        defer header.deinit();
        std.debug.print("Header{{.content_length = {any}, .content_type = {?s} }}\n", .{ header.content_length, header.content_type });
    }
    _ = allocator.detectLeaks();
}
