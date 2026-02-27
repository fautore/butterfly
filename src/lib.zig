const std = @import("std");
const fs = std.fs;
const time = std.time;
const block = @import("block.zig");

pub const Coordinates = packed struct {
    lat: f64,
    lon: f64,
};
pub const GeoLog = packed struct {
    timestamp: i64,
    coordinates: Coordinates,
};

pub const Tree = struct {
    count: u64,
    block: *block.Block,

    pub fn New() Tree {
        return Tree{
            .count = 0,
            .timestamps = std.mem.zeroes([1000]i64),
            .coordinates = std.mem.zeroes([1000]Coordinates),
        };
    }

    pub fn addLog(
        self: *Tree,
        timepoint: GeoLog,
    ) void {
        const blockIsFull = self.count == self.timestamps.len;
        if (blockIsFull) {} else {
            defer self.count += 1;
            self.timestamps[@intCast(self.count)] = timepoint.timestamp;
            self.coordinates[@intCast(self.count)] = timepoint.coordinates;
        }
    }
};
