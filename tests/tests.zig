const testing = @import("std").testing;
const kantools = @import("kantools");

comptime {
    testing.refAllDecls(@This());
}
