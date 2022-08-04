const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

pub const Lines = struct {
    const Self = @This();

    impl: *anyopaque,
    writeNextFn: fn (*anyopaque, Allocator, Writer) anyerror!?void,

    pub fn writeNext(self: *Self, allocator: Allocator, writer: Writer) !?void {
        return self.writeNextFn(self.impl, allocator, writer);
    }
};
