const std = @import("std");
const Decor = @import("decor").Decor;
const Sys = @import("../sys/sys.zig");
const FmtIterator = @import("./FmtIterator.zig");

const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;
const assert = std.debug.assert;

const Self = @This();

state: u8,

pub fn init() Self {
    return Self{ .state = 0 };
}

pub fn iter(self: *Self) FmtIterator {
    return FmtIterator.init(self, next);
}

pub fn next(self: *Self, allocator: Allocator, writer: Writer) !?void {
    const sys_enum_info = @typeInfo(Sys.Kind).Enum;
    if (self.state >= sys_enum_info.fields.len) {
        return null;
    }

    switch (@intToEnum(Sys.Kind, self.state)) {
        .Cores => {
            const cores = Sys.Impl.Cores.cores(allocator);
            try Decor.init().bold().print(writer, "Cores: ", .{});
            try Decor.init().print(writer, "{d}", .{cores});
        },
        .CPU => {
            const cpu = Sys.Impl.CPU.cpu(allocator);
            try Decor.init().bold().print(writer, "CPU: ", .{});
            try Decor.init().print(writer, "{s}", .{cpu});
        },
        .GPU => {
            // const gpus = try Sys.Impl.GPU.gpu(allocator);
            // try Decor.init().bold().print(writer, "GPU: ", .{});
            // if (gpus.items.len == 0) {
            //     try Decor.init().print(writer, "Integrated", .{});
            // } else for (gpus.items) |gpu| {
            //     try Decor.init().print(writer, "{s}", .{gpu});
            // }
        },
        .Hostname => {
            const hostname = Sys.Impl.Hostname.hostname();
            try Decor.init().bold().print(writer, "Hostname: ", .{});
            try Decor.init().print(writer, "{s}", .{hostname});
        },
        .Kernel => {
            const kernel = Sys.Impl.Kernel.kernel(allocator);
            try Decor.init().bold().print(writer, "Kernel: ", .{});
            try Decor.init().print(writer, "{s}", .{kernel});
        },
        .Machine => {
            const machine = Sys.Impl.Machine.machine(allocator);
            try Decor.init().bold().print(writer, "Machine: ", .{});
            try Decor.init().print(writer, "{s}", .{machine});
        },
        .OS => {
            const os = Sys.Impl.OS.os(allocator);
            try Decor.init().bold().print(writer, "OS: ", .{});
            try Decor.init().print(writer, "{s}", .{os});
        },
        .RAM => {
            const ram = try Sys.Impl.RAM.ram(allocator);
            try Decor.init().bold().print(writer, "RAM: ", .{});
            try Decor.init().print(writer, "{d}GB", .{ram / (1024 * 1024 * 1024)});
        },
        .Resolution => {
            const resolution = try Sys.Impl.Resolution.resolution();
            try Decor.init().bold().print(writer, "Resolution: ", .{});
            try Decor.init().print(writer, "{d}x{d}", .{ resolution.width, resolution.height });
        },
        .Shell => {
            // const shell = try Sys.Impl.Shell.shell();
            // try Decor.init().bold().print(writer, "Shell: ", .{});
            // try Decor.init().print(writer, "{s}", .{shell});
        },
        .Term => {
            // const term = try Sys.Impl.Term.term();
            // try Decor.init().bold().print(writer, "Term: ", .{});
            // try Decor.init().print(writer, "{s}", .{term});
        },
        .Threads => {
            // const threads = try Sys.Impl.Threads.threads(allocator);
            // try Decor.init().bold().print(writer, "Threads: ", .{});
            // try Decor.init().print(writer, "{d}", .{threads});
        },
        .Uptime => {
            const uptime = try Sys.Impl.Uptime.uptime(allocator);
            try Decor.init().bold().print(writer, "Uptime: ", .{});
            try Decor.init().print(writer, "{d}d {d}h {d}m {d}s", .{ uptime.days, uptime.hours, uptime.minutes, uptime.seconds });
        },
        .User => {
            const user = Sys.Impl.User.user();
            try Decor.init().bold().print(writer, "User: ", .{});
            try Decor.init().print(writer, "{s}", .{user});
        },
    }

    self.state += 1;
}
