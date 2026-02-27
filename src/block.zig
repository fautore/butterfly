const std = @import("std");

pub const Block = struct {
    saveFn: *const fn (*Block, buf: []u8) BlockErrors!void,
    loadFn: *const fn (*Block) []u8,

    pub const BlockErrors = error{
        BufferTooSmall,
    };

    pub fn save(interface: *Block, buf: []u8) BlockErrors!void {
        return try interface.saveFn(interface, buf);
    }
    pub fn load(interface: *Block) []u8 {
        return interface.loadFn(interface);
    }
};

const MemoryBlock = struct {
    mem: []u8,
    interface: Block,

    fn init(allocator: *std.mem.Allocator) !MemoryBlock {
        const mem = try allocator.alloc(u8, 1000);
        return MemoryBlock{
            .mem = mem,
            .interface = Block{ .saveFn = mbSave, .loadFn = mbLoad },
        };
    }

    fn mbSave(interface: *Block, buf: []u8) Block.BlockErrors!void {
        const self: *MemoryBlock = @fieldParentPtr("interface", interface);
        if (self.mem.len < buf.len) {
            return error.BufferTooSmall;
        }
        std.mem.copyForwards(u8, self.mem, buf);
    }

    fn mbLoad(interface: *Block) []u8 {
        const block: *MemoryBlock = @fieldParentPtr("interface", interface);
        return block.mem;
    }
};

pub fn save(interface: *Block, buf: []u8) Block.BlockErrors!void {
    return try interface.save(buf);
}
pub fn load(interface: *Block) []u8 {
    return interface.load();
}

test "Interface" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var alloc = arena.allocator();

    const exp = "Ciccio";

    var i = try MemoryBlock.init(&alloc);
    const buf = try alloc.dupe(u8, exp);

    try save(&i.interface, buf);
    const mem = load(&i.interface);

    try std.testing.expectEqualSlices(u8, exp, mem[0..exp.len]);
}
