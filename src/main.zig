const std = @import("std");
const decor = @import("decor");
const art = @import("./art.zig");
const HStack = @import("./fmt/hstack.zig").HStack;
const ArtFmtIterator = @import("./fmt/ArtFmtIterator.zig").ArtFmtIterator;
const SysFmtIterator = @import("./fmt/SysFmtIterator.zig");

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();

    try HStack(.{ .columns = 2 })
        .init()
        .spacing(3)
        .body(.{ ArtFmtIterator(art.latte).init().iter(), SysFmtIterator.init().iter() })
        .print(stdout);

    // try Decorated.init().println(stdout, art.latte, .{});
    // try stdout.print("\n", .{});
    // const color_block = "   ";
    // var i: u8 = 0;
    // while (i < 8) : (i += 1)
    //     try Decorated.init().background(.{ .number = i }).print(stdout, color_block, .{});
    // try stdout.print("\n", .{});
    // while (i < 16) : (i += 1)
    //     try Decorated.init().background(.{ .number = i }).print(stdout, color_block, .{});
    // try stdout.print("\n", .{});
}
