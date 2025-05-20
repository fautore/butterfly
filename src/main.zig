const std = @import("std");
const lib = @import("butterfly_lib");

fn handleConnection(connection: std.net.Server.Connection) !void {
    const buff = try std.heap.page_allocator.alloc(u8, 100);
    while (connection.stream.read(buff)) |size| {
        if (size == 0) {
            return;
        }
        const trimBuff = std.mem.trimRight(u8, buff[0..size], "\n");
        std.debug.print("Read {d} bytes {s}\n", .{ size, trimBuff[0 .. size - 1] });
    } else |err| {
        std.debug.panic("Panic {?}", .{err});
    }
}

pub fn main() !void {
    const addr = std.net.Address{
        .in = try std.net.Ip4Address.parse("127.0.0.1", 3000),
    };
    var server = try addr.listen(.{});
    defer server.deinit();

    while (server.accept()) |conn| {
        _ = try std.Thread.spawn(.{}, handleConnection, .{conn});
    } else |err| {
        std.debug.panic("Panic {?}\n", .{err});
    }

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    try bw.flush();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit();
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "use other module" {
    try std.testing.expectEqual(@as(i32, 150), lib.add(100, 50));
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
