const std = @import("std");
const Lines = @import("./fmt/Lines.zig").Lines;
const Art = @import("./art.zig").Art;
const Sys = @import("./sys.zig").Sys;

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var art_lines = Art.init().lines();
    var sys_lines = Sys.init().lines();
    var exhausted: u8 = 0;

    while (true) {
        var art_line = try art_lines.writeNext(allocator, stdout);
        if (art_line == null) {
            exhausted += 1;
        }

        // Add spacing
        _ = try stdout.write("   ");

        var sys_line = try sys_lines.writeNext(allocator, stdout);
        if (sys_line == null) {
            exhausted += 1;
        }

        // Automatic newline after every iteration
        try stdout.print("\n", .{});

        if (exhausted == 2) {
            break;
        }
    }

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
