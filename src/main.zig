const std = @import("std");
const builtin = @import("builtin");
const impl = @import("impl.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    const stdout = std.io.getStdOut().writer();

    const cores = try impl.cores(allocator);
    try stdout.print("Cores: {d}\n", .{cores});

    const cpu = try impl.cpu(allocator);
    try stdout.print("CPU: {s}\n", .{cpu});

    const gpus = try impl.gpu(allocator);
    if (gpus.items.len == 0) {
        try stdout.print("GPU: Integrated\n", .{});
    } else for (gpus.items) |gpu| {
        try stdout.print("GPU: {s}\n", .{gpu});
    }

    const hostname = try impl.hostname();
    try stdout.print("Hostname: {s}\n", .{hostname});

    const kernel = try impl.kernel(allocator);
    try stdout.print("Kernel: {s}\n", .{kernel});

    const machine = try impl.machine(allocator);
    try stdout.print("Machine: {s}\n", .{machine});

    const os = try impl.os(allocator);
    try stdout.print("OS: {s}\n", .{os});

    const ram = try impl.ram(allocator);
    try stdout.print("RAM: {d}GB\n", .{ram / (1024 * 1024 * 1024)});

    const resolution = try impl.resolution();
    try stdout.print("Resolution: {d}x{d}\n", .{ resolution.width, resolution.height });

    const shell = try impl.shell();
    if (shell) |s| {
        try stdout.print("Shell: {s}\n", .{s});
    }

    const term = try impl.term();
    if (term) |t| {
        try stdout.print("Term: {s}\n", .{t});
    }

    const threads = try impl.threads(allocator);
    try stdout.print("Threads: {d}\n", .{threads});

    const uptime = @intToFloat(f64, try impl.uptime(allocator));
    const DAYS_DIVISOR = 60 * 60 * 24;
    const HOURS_DIVISOR = 60 * 60;
    const MINUTES_DIVISOR = 60;
    const SECONDS_DIVISOR = 1;

    const days_abs = @divFloor(uptime, DAYS_DIVISOR);
    const hours_abs = @divFloor(uptime, HOURS_DIVISOR);
    const minutes_abs = @divFloor(uptime, MINUTES_DIVISOR);

    const days = days_abs;
    const hours = @divFloor(uptime - days_abs * DAYS_DIVISOR, HOURS_DIVISOR);
    const minutes = @divFloor(uptime - hours_abs * HOURS_DIVISOR, MINUTES_DIVISOR);
    const seconds = @divFloor(uptime - minutes_abs * MINUTES_DIVISOR, SECONDS_DIVISOR);
    try stdout.print("Uptime: {d}d {d}h {d}m {d}s\n", .{ days, hours, minutes, seconds });
}
