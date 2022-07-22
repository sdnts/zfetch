const std = @import("std");
const builtin = @import("builtin");
const impl = @import("impl.zig");
const fmt = @import("fmt.zig");
const art = @import("art.zig");

const Decorated = fmt.Decorated;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    const stdout = std.io.getStdOut().writer();

    try Decorated.init().println(stdout, art.latte, .{});

    var cores = try impl.cores(allocator);
    try Decorated.init().bold().print(stdout, "Cores: ", .{});
    try Decorated.init().println(stdout, "{d}", .{cores});

    const cpu = try impl.cpu(allocator);
    try Decorated.init().bold().print(stdout, "CPU: ", .{});
    try Decorated.init().println(stdout, "{s}", .{cpu});

    const gpus = try impl.gpu(allocator);
    try Decorated.init().bold().print(stdout, "GPU: ", .{});
    if (gpus.items.len == 0) {
        try Decorated.init().println(stdout, "Integrated", .{});
    } else for (gpus.items) |gpu| {
        try Decorated.init().println(stdout, "{s}", .{gpu});
    }

    const hostname = try impl.hostname();
    try Decorated.init().bold().print(stdout, "Hostname: ", .{});
    try Decorated.init().println(stdout, "{s}", .{hostname});

    const kernel = try impl.kernel(allocator);
    try Decorated.init().bold().print(stdout, "Kernel: ", .{});
    try Decorated.init().println(stdout, "{s}", .{kernel});

    const machine = try impl.machine(allocator);
    try Decorated.init().bold().print(stdout, "Machine: ", .{});
    try Decorated.init().println(stdout, "{s}", .{machine});

    const os = try impl.os(allocator);
    try Decorated.init().bold().print(stdout, "OS: ", .{});
    try Decorated.init().println(stdout, "{s}", .{os});

    const ram = try impl.ram(allocator);
    try Decorated.init().bold().print(stdout, "RAM: ", .{});
    try Decorated.init().println(stdout, "{d}GB", .{ram / (1024 * 1024 * 1024)});

    const resolution = try impl.resolution();
    try Decorated.init().bold().print(stdout, "Resolution: ", .{});
    try Decorated.init().println(stdout, "{d}x{d}", .{ resolution.width, resolution.height });

    const shell = try impl.shell();
    try Decorated.init().bold().print(stdout, "Shell: ", .{});
    try Decorated.init().println(stdout, "{s}", .{shell});

    const term = try impl.term();
    try Decorated.init().bold().print(stdout, "Term: ", .{});
    try Decorated.init().println(stdout, "{s}", .{term});

    const threads = try impl.threads(allocator);
    try Decorated.init().bold().print(stdout, "Threads: ", .{});
    try Decorated.init().println(stdout, "{d}", .{threads});

    const uptime = try impl.uptime(allocator);
    try Decorated.init().bold().print(stdout, "Uptime: ", .{});
    try Decorated.init().println(stdout, "{d}d {d}h {d}m {d}s", .{ uptime.days, uptime.hours, uptime.minutes, uptime.seconds });

    const user = try impl.user();
    try Decorated.init().bold().print(stdout, "User: ", .{});
    try Decorated.init().println(stdout, "{s}", .{user});

    try stdout.print("\n", .{});
    const color_block = "   ";
    var i: u8 = 0;
    while (i < 8) : (i += 1)
        try Decorated.init().background(.{ .number = i }).print(stdout, color_block, .{});
    try stdout.print("\n", .{});
    while (i < 16) : (i += 1)
        try Decorated.init().background(.{ .number = i }).print(stdout, color_block, .{});
    try stdout.print("\n", .{});
}
