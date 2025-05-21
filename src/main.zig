const std = @import("std");
const os = std.os;
const net = std.net;
const lib = @import("butterfly_lib");

const MAX_CONNECTIONS = 10;

// fn handleConnection(connection: std.net.Server.Connection) !void {
//     const buff = try std.heap.page_allocator.alloc(u8, 100);
//     while (connection.stream.read(buff)) |size| {
//         if (size == 0) {
//             return;
//         }
//         const trimBuff = std.mem.trimRight(u8, buff[0..size], "\n");
//         std.debug.print("Read {d} bytes {s}\n", .{ size, trimBuff[0 .. size - 1] });
//     } else |err| {
//         std.debug.panic("Panic {?}", .{err});
//     }
// }
//
// fn pollConnectionsForUpdates(clients: *[]?Client) void {
//     while (true) {}
// }
//
// const Client = struct {
//     connection: std.net.Server.Connection,
// };

const ErrorOutOfConnections = error{};

const ConnectionQueue = struct {
    connections: [MAX_CONNECTIONS]?net.Server.Connection = [_]?net.Server.Connection{null} ** MAX_CONNECTIONS,
    epoll_fd: os.linux.fd_t,
    openConnections: u32,

    pub fn init() !ConnectionQueue {
        const epoll_fd = os.linux.epoll_create1(0);
        return ConnectionQueue{
            .epoll_fd = @intCast(epoll_fd),
            .openConnections = 0,
        };
    }

    pub fn addConnection(self: *ConnectionQueue, conn: net.Server.Connection) !void {
        const idx = self.findFreeSlot() orelse return error.ErrorOutOfConnections;
        var event = os.linux.epoll_event{
            .events = os.linux.EPOLL.IN | os.linux.EPOLL.ET,
            .data = @bitCast(idx),
        };
        _ = os.linux.epoll_ctl(
            self.epoll_fd,
            os.linux.EPOLL.CTL_ADD,
            conn.stream.handle,
            &event,
        );
        self.connections[idx] = conn;
        self.openConnections += 1;
    }

    fn findFreeSlot(self: *ConnectionQueue) ?usize {
        for (self.connections, 0..) |c, i| {
            if (c == null) return i;
        }
        return null;
    }

    fn removeConnection(self: *ConnectionQueue, idx: usize) void {
        if (self.connections[idx]) |*c| {
            c.conn.deinit();
        }
        self.connections[idx] = null;
        self.openConnections -= 1;
    }
};

fn workerFn(connectionQueue: *ConnectionQueue) void {
    const allocator = std.heap.page_allocator;
    const events = allocator.alloc(os.linux.epoll_event, 64) catch |err| {
        const message = switch (err) {
            std.mem.Allocator.Error.OutOfMemory => "Out of memory, cannot allocate space for worker threads",
        };
        std.log.err("{s}", .{message});
        std.process.exit(1);
    };
    defer allocator.free(events);

    while (true) {
        // std.debug.print("Connections in queue {d}\n", .{connectionQueue.openConnections});
        const n = os.linux.epoll_wait(connectionQueue.epoll_fd, events.ptr, 64, -1);
        std.debug.print("Open connection {d}\n", .{n});
        std.Thread.sleep(1 * std.time.ns_per_s);
    }
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var pool: std.Thread.Pool = undefined;
    _ = try pool.init(.{ .allocator = alloc });
    defer pool.deinit();

    const addr = std.net.Address{
        .in = try std.net.Ip4Address.parse("127.0.0.1", 3000),
    };
    var server = try addr.listen(.{});
    defer server.deinit();

    var connectionQueue = try ConnectionQueue.init();

    try pool.spawn(workerFn, .{&connectionQueue});
    try pool.spawn(workerFn, .{&connectionQueue});

    while (server.accept()) |conn| {
        try connectionQueue.addConnection(conn);
    } else |err| {
        std.debug.panic("Panic {?}\n", .{err});
    }
}
