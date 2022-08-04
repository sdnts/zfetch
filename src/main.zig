const std = @import("std");
const ZFetchError = @import("errors.zig").ZFetchError;
const Art = @import("./art.zig").Art;
const Sys = @import("./sys.zig").Sys;

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var art = Art.init();
    var sys = Sys.init();

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

        if (art_bytes == Art.width and sys_line == null) {
            break;
        }
    }
}
