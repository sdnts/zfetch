const std = @import("std");
const ZFetchError = @import("errors.zig").ZFetchError;
const Art = @import("./art.zig").Art;
const Sys = @import("./sys.zig").Sys;
const latte = @import("./art.zig").latte;

pub fn main() !void {
    var w = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(w);
    var stdout = bw.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var art = Art.init(latte);
    var sys = Sys.init();

    try stdout.print("\n", .{});
    while (true) {
        // Print one line of our "art"
        var art_bytes = (try art.write(stdout)) orelse 0;

        // Add appropriate spacing to make all art lines the same width
        while (art_bytes < Art.width) : (art_bytes += 1) {
            _ = try stdout.write(" ");
        }

        // Spacing between art and sys info
        _ = try stdout.write("   ");

        // Print sys info
        var sys_line = try sys.write(allocator, stdout);
        try stdout.print("\n", .{});
        try bw.flush();

        if (art_bytes == Art.width and sys_line == null) {
            break;
        }
    }
}
