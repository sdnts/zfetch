const std = @import("std");
const ZFetchError = @import("errors.zig").ZFetchError;
const Art = @import("./art.zig").Art;
const Sys = @import("./sys.zig").Sys;

pub fn main() ZFetchError!void {
    var stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var art = Art.init();
    var sys = Sys.init();

    while (true) {
        var art_line = try art.write(stdout);
        _ = try stdout.write("   ");
        var sys_line = try sys.write(allocator, stdout);
        try stdout.print("\n", .{});

        if (art_line == null and sys_line == null) {
            break;
        }
    }
}
