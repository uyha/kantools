const std = @import("std");

const kantools = @import("kantools");
const Header = kantools.Header;
const Content = kantools.Content;
const Server = kantools.Server;
const types = kantools.types;

pub fn main() !void {
    var gp_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gp_allocator.detectLeaks();
    const allocator = gp_allocator.allocator();

    const stdin = std.io.getStdIn();
    var buffered_reader = std.io.bufferedReader(stdin.reader());
    const reader = buffered_reader.reader();

    const stdoutWriter = std.io.getStdOut().writer();

    const log = try std.fs.cwd().createFile("log", .{});
    const logWriter = log.writer();

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var multiWriter = std.io.multiWriter(.{ stdoutWriter, logWriter });
    const writer = multiWriter.writer();

    const server = Server{};

    while (true) {
        try buffer.resize(0);

        const header = try Header.read(reader, allocator);
        defer header.deinit();
        const content = try Content.read(reader, header.content_length, allocator);
        defer content.deinit();

        try logWriter.print("\n{} {s}\n", .{ header, content.content.items });

        const message = try content.parse(types.Message);
        try server.processMessage(message.value, buffer.writer(), allocator);

        if (buffer.items.len > 0) {
            try writer.print("Content-Length: {}\r\n\r\n", .{buffer.items.len});
            try writer.print("{s}", .{buffer.items});
        }
    }
}
