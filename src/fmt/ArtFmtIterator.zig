const std = @import("std");
const FmtIterator = @import("./FmtIterator.zig");

const SplitIterator = std.mem.SplitIterator(u8);
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

pub fn ArtFmtIterator(comptime art: []const u8) type {
    return struct {
        const Self = @This();
        lines: SplitIterator,

        pub fn init() Self {
            return Self{ .lines = std.mem.split(u8, art, "\n") };
        }

        pub fn iter(self: *Self) FmtIterator {
            return FmtIterator.init(self, next);
        }

        pub fn next(self: *Self, _: Allocator, writer: Writer) !?void {
            if (self.lines.next()) |l| {
                try writer.print("{s}", .{l});
            } else {
                return null;
            }
        }
    };
}
