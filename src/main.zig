const std = @import("std");
const ZFetchError = @import("errors.zig").ZFetchError;
const Art = @import("./art.zig").Art;
const Sys = @import("./sys.zig").Sys;
const active_ascii_art = @import("./art.zig").active_ascii_art;

pub fn main() !void {
    var w = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(w);
    var stdout = bw.writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var sys = Sys.init();
    var art = Art.init(active_ascii_art);
    // Okay so this width is notoriously hard to calculate programmatically (at
    // comptime) because unicode. So I'm just going to trial-and-error a good value
    // so that the sys info lines up neatly. More details in the `Art.write` function.
    const estimated_art_width = 28;

    try stdout.print("\n", .{});
    while (true) {
        // Print one line of our "art"
        var art_bytes = (try art.write(stdout)) orelse 0;

        // Add appropriate spacing to make all art lines the same width
        while (art_bytes < estimated_art_width) : (art_bytes += 1) {
            _ = try stdout.write(" ");
        }

        // Spacing between art and sys info
        _ = try stdout.write("   ");

        // Print sys info
        var sys_line = try sys.write(allocator, stdout);
        try stdout.print("\n", .{});

        if (art_bytes == estimated_art_width and sys_line == null) {
            break;
        }
    }

    try bw.flush();
}
