const std = @import("std");
const builtin = @import("builtin");
const Impl = @import("impl.zig").Impl;

pub fn main() !void {
    print() catch {
        std.process.exit(1);
    };
}

pub fn print() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const stdout = std.io.getStdOut().writer();

    const cores = try Impl.cores();
    try stdout.print("Cores: {d}\n", .{cores});

    const cpu = try Impl.cpu(allocator);
    try stdout.print("CPU: {s}\n", .{cpu});

    const gpu = try Impl.gpu(allocator);
    try stdout.print("GPU: {s}\n", .{gpu});

    const hostname = try Impl.hostname();
    try stdout.print("Hostname: {s}\n", .{hostname});

    const kernel = try Impl.kernel(allocator);
    try stdout.print("Kernel: {s}\n", .{kernel});

    const machine = try Impl.machine(allocator);
    try stdout.print("Machine: {s}\n", .{machine});

    const os = try Impl.os(allocator);
    try stdout.print("OS: {s}\n", .{os});

    const ram = try Impl.ram();
    try stdout.print("RAM: {d}GB\n", .{ram / (1024 * 1024 * 1024)});

    const resolution = try Impl.resolution();
    try stdout.print("Resolution: {d}x{d}\n", .{ resolution.width, resolution.height });

    const shell = try Impl.shell();
    if (shell) |s| {
        try stdout.print("Shell: {s}\n", .{s});
    }

    const term = try Impl.term();
    if (term) |t| {
        try stdout.print("Term: {s}\n", .{t});
    }

    const threads = try Impl.threads();
    try stdout.print("Threads: {d}\n", .{threads});

    const uptime = @intToFloat(f64, try Impl.uptime());
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
