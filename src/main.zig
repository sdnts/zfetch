const std = @import("std");
const builtin = @import("builtin");
const impl = @import("impl.zig");
const fmt = @import("fmt.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    const stdout = std.io.getStdOut().writer();

    const DecoratedString = fmt.Decorated([]const u8);
    const DecoratedUsize = fmt.Decorated(usize);
    const DecoratedFloat = fmt.Decorated(f64);

    var cores = try impl.cores(allocator);
    try DecoratedString.init("Cores: ").bold().print(stdout);
    try DecoratedUsize.init(cores).println(stdout);

    const cpu = try impl.cpu(allocator);
    try DecoratedString.init("CPU: ").bold().print(stdout);
    try DecoratedString.init(cpu).println(stdout);

    const gpus = try impl.gpu(allocator);
    try DecoratedString.init("GPU: ").bold().print(stdout);
    if (gpus.items.len == 0) {
        try DecoratedString.init("Integrated").println(stdout);
    } else for (gpus.items) |gpu| {
        try DecoratedString.init(gpu).println(stdout);
    }

    const hostname = try impl.hostname();
    try DecoratedString.init("Hostname: ").bold().print(stdout);
    try DecoratedString.init(hostname[0..]).println(stdout);

    const kernel = try impl.kernel(allocator);
    try DecoratedString.init("Kernel: ").bold().print(stdout);
    try DecoratedString.init(kernel).println(stdout);

    const machine = try impl.machine(allocator);
    try DecoratedString.init("Machine: ").bold().print(stdout);
    try DecoratedString.init(machine).println(stdout);

    const os = try impl.os(allocator);
    try DecoratedString.init("OS: ").bold().print(stdout);
    try DecoratedString.init(os).println(stdout);

    const ram = try impl.ram(allocator);
    try DecoratedString.init("RAM: ").bold().print(stdout);
    try DecoratedUsize.init(ram / (1024 * 1024 * 1024)).println(stdout);

    const resolution = try impl.resolution();
    try stdout.print("Resolution: {d}x{d}\n", .{ resolution.width, resolution.height });

    const shell = try impl.shell();
    try DecoratedString.init("Shell: ").bold().print(stdout);
    try DecoratedString.init(shell).println(stdout);

    const term = try impl.term();
    try DecoratedString.init("Term: ").bold().print(stdout);
    try DecoratedString.init(term).println(stdout);

    const threads = try impl.threads(allocator);
    try DecoratedString.init("Threads: ").bold().print(stdout);
    try DecoratedUsize.init(threads).println(stdout);

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
    try DecoratedString.init("Uptime: ").bold().print(stdout);
    try DecoratedFloat.init(days).print(stdout);
    try DecoratedString.init("d ").print(stdout);
    try DecoratedFloat.init(hours).print(stdout);
    try DecoratedString.init("h ").print(stdout);
    try DecoratedFloat.init(minutes).print(stdout);
    try DecoratedString.init("m ").print(stdout);
    try DecoratedFloat.init(seconds).print(stdout);
    try DecoratedString.init("s").println(stdout);

    const user = try impl.user();
    try DecoratedString.init("User: ").bold().print(stdout);
    try DecoratedString.init(user).println(stdout);
}
