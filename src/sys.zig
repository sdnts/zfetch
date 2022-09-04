const std = @import("std");
const builtin = @import("builtin");
const Decor = @import("decor").Decor;
const c = @cImport({
    @cInclude("sys/sysctl.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("IOKit/IOKitLib.h");
});
const ZFetchError = @import("./errors.zig").ZFetchError;

pub const darwin = @import("./sys/darwin.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

const is_macos = builtin.target.os.tag == .macos;
const is_linux = builtin.target.os.tag == .linux;
const is_windows = builtin.target.os.tag == .windows;

// zig fmt: off
const SysKind = enum {
    UserAtHostname,
    Separator,
    Cores,
    CPU,
    GPU,
    Kernel,
    Machine,
    OS,
    RAM,
    Resolution,
    Shell,
    Term,
    Uptime,
    Space,
    Colors1,
    Colors2
};
// zig fmt: on

pub const Sys = struct {
    const Self = @This();
    const max_lines_written = @typeInfo(SysKind).Enum.fields.len;
    d: Decor = Decor.init(),
    lines_written: usize = 0,
    last_line_len: usize = 0, // TODO: Actually calculate it at the end of every iteration

    pub fn init() Self {
        return Self{};
    }

    /// Information you can show is implemented on a per-platform basis here. There is unfortunately no cross-platform way to get system information,
    /// so you'll regularly see branches based on supported operating systems. I'm leaving a few general notes here that might be useful if you're tweaking this,
    /// although to be honest I'm leaving these for myself.
    /// The general rule behind implementations is to favor speed over anything else (even correctness at times, because it really isn't as important in this case)
    pub fn write(self: *Self, allocator: Allocator, writer: Writer) ZFetchError!?void {
        defer self.lines_written += 1;

        if (self.lines_written >= Self.max_lines_written) {
            return null;
        }

        switch (@intToEnum(SysKind, self.lines_written)) {
            .UserAtHostname => {
                const user = blk: {
                    if (is_macos or is_linux) {
                        const value = std.os.getenv("USER");
                        if (value == null) return error.MissingEnvVar;

                        break :blk value.?;
                    }

                    @compileError("impl.user is not implemented for this OS");
                };

                const hostname = blk: {
                    var buf: [std.os.HOST_NAME_MAX]u8 = undefined;
                    var h = try std.os.gethostname(&buf);
                    break :blk h;
                };

                self.last_line_len =
                    try self.d.reset().bold().write(writer, "{s} @ {s}", .{ user, hostname });
            },
            .Separator => {
                var i: usize = 0;
                while (i < self.last_line_len) : (i += 1) {
                    _ = try writer.write("-");
                }
            },
            .Cores => {
                try self.d.reset().bold().print(writer, "Cores: ", .{});

                const cores = blk: {
                    if (is_macos) {
                        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_NCPU };
                        const value = try darwin.sysctl(allocator, c_int, mib[0..]);
                        break :blk @intCast(usize, value);
                    }

                    @compileError("impl.cores is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{d}", .{cores});
            },
            .CPU => {
                try self.d.reset().bold().print(writer, "CPU: ", .{});

                const cpu = blk: {
                    if (is_macos) {
                        // This has a system-dependent MIB, so we use `sysctlbyname`
                        break :blk try darwin.sysctlbyname(allocator, []u8, "machdep.cpu.brand_string");
                    }

                    @compileError("impl.cpu is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{cpu});
            },
            .GPU => {
                try self.d.reset().bold().print(writer, "GPU: ", .{});

                const gpus = blk: {
                    if (is_macos) {
                        var value = try ArrayList([]const u8).initCapacity(allocator, 2);

                        // Super helpful reading: https://www.starcoder.com/wordpress/2011/10/using-iokit-to-detect-graphics-hardware/
                        var matchDictionary = c.IOServiceMatching("IOPCIDevice");
                        var serviceObjectIter: c.io_iterator_t = undefined;
                        defer _ = c.IOObjectRelease(serviceObjectIter);

                        // Create an iterator for PCI devices
                        var result = c.IOServiceGetMatchingServices(c.kIOMasterPortDefault, matchDictionary, &serviceObjectIter);
                        if (result != c.kIOReturnSuccess) return error.IOKitError;

                        // Iterate through PCI devices
                        while (true) {
                            var serviceObject = c.IOIteratorNext(serviceObjectIter);
                            defer _ = c.IOObjectRelease(serviceObject);

                            if (serviceObject == 0) break;

                            var serviceDictionary: c.CFMutableDictionaryRef = undefined;
                            defer _ = c.CFRelease(serviceDictionary);

                            // Create a CFDictionary from the serviceObject
                            result = c.IORegistryEntryCreateCFProperties(serviceObject, &serviceDictionary, c.kCFAllocatorDefault, c.kNilOptions);
                            if (result != c.kIOReturnSuccess) return error.IOKitError;

                            // If this is a GPU listing, it will have a "model" key that points to a CFDataRef
                            var cfStringKey = c.CFStringCreateWithCString(c.kCFAllocatorDefault, "model", 1);
                            defer c.CFRelease(cfStringKey);

                            var model = @ptrCast(c.CFDataRef, c.CFDictionaryGetValue(serviceDictionary, cfStringKey));
                            if (model == null) continue;

                            if (c.CFGetTypeID(model) == c.CFDataGetTypeID()) {
                                var size = c.CFDataGetLength(model);
                                var buf = try allocator.alloc(u8, @intCast(usize, size));

                                c.CFDataGetBytes(model, c.CFRangeMake(0, size), @ptrCast([*c]u8, buf));
                                try value.append(buf);
                            } else {
                                // Means Our ptrCast was wrong up above
                                unreachable;
                            }
                        }

                        break :blk value;
                    }

                    @compileError("impl.gpu is not implemented for this OS");
                };

                if (gpus.items.len == 0) {
                    try self.d.reset().print(writer, "Integrated", .{});
                } else {
                    try self.d.reset().print(writer, "{s}", .{gpus.items[0]});
                }
            },
            .Kernel => {
                try self.d.reset().bold().print(writer, "Kernel: ", .{});

                const kernel = blk: {
                    if (is_macos) {
                        // This has a system-dependent MIB, so we use `sysctlbyname`
                        const name = try darwin.sysctlbyname(allocator, []u8, "kern.ostype");
                        const version = try darwin.sysctlbyname(allocator, []u8, "kern.osrelease");
                        break :blk try std.mem.concat(allocator, u8, &[_][]const u8{ name, " ", version });
                    }

                    @compileError("impl.kernel is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{kernel});
            },
            .Machine => {
                try self.d.reset().bold().print(writer, "Machine: ", .{});

                const machine = blk: {
                    if (is_macos) {
                        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_PRODUCT };
                        break :blk try darwin.sysctl(allocator, []u8, mib[0..]);
                    }

                    @compileError("impl.machine is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{machine});
            },
            .OS => {
                try self.d.reset().bold().print(writer, "OS: ", .{});

                const os = blk: {
                    if (is_macos) {
                        // COMPATIBILITY:
                        // The following only works for macOS 10.13.4 (High Sierra) and up.
                        // The sysctl entry to get the macOS version is `kern.osproductversion`, which has two issues:
                        //   1. kern.osproductversion is only available 10.13.4 High Sierra and later
                        //   2. ker.osproductversion, when used from a binary built against < SDK 11.0, returns 10.16 and masks Big Sur 11.x version
                        //
                        // I think this accuracy to speed tradeoff is worth it though because of High Sierra and SDK 11.0's age.
                        //
                        // Zig's builtin `std.darwin.detect` parses the `/System/Library/CoreServices/SystemVersion.plist` file to get around this, which I'd also like to avoid.

                        // This has a system-dependent MIB, so we use `sysctlbyname`
                        var version = try darwin.sysctlbyname(allocator, []u8, "kern.osproductversion");
                        break :blk try std.mem.concat(allocator, u8, &[_][]const u8{ "macOS ", version });
                    }

                    @compileError("impl.os is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{os});
            },
            .RAM => {
                try self.d.reset().bold().print(writer, "RAM: ", .{});

                const ram = blk: {
                    if (is_macos) {
                        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_MEMSIZE };
                        const value = try darwin.sysctl(allocator, u64, mib[0..]);
                        break :blk @intCast(u64, value);
                    }

                    @compileError("impl.ram is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{d}GB", .{ram / (1024 * 1024 * 1024)});
            },
            .Resolution => {
                try self.d.reset().bold().print(writer, "Resolution: ", .{});

                const resolution = blk: {
                    if (is_macos) {
                        // Big help:
                        // https://github.com/jakehilborn/displayplacer/blob/master/displayplacer.c#L5
                        // https://github.com/jakehilborn/displayplacer/blob/master/displayplacer.c#L255
                        //
                        // Docs: https://developer.apple.com/documentation/coregraphics/1456361-cgdisplaypixelswide
                        var w = c.CGDisplayPixelsWide(c.CGMainDisplayID());
                        var h = c.CGDisplayPixelsHigh(c.CGMainDisplayID());

                        break :blk .{ .width = @intCast(u32, w), .height = @intCast(u32, h) };
                    }

                    @compileError("impl.resolution is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{d}x{d}", .{ resolution.width, resolution.height });
            },
            .Shell => {
                try self.d.reset().bold().print(writer, "Shell: ", .{});

                const shell = blk: {
                    if (is_macos or is_linux) {
                        var value = std.os.getenv("SHELL");
                        if (value == null) return error.MissingEnvVar;

                        var iter = std.mem.splitBackwards(u8, value.?, "/");
                        value = iter.next();
                        if (value == null) return error.UnexpectedEnvVar;

                        break :blk value.?;
                    }

                    @compileError("impl.shell is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{shell});
            },
            .Term => {
                try self.d.reset().bold().print(writer, "Term: ", .{});

                const term = blk: {
                    if (is_macos or is_linux) {
                        const value = std.os.getenv("TERM");
                        if (value == null) return error.MissingEnvVar;

                        break :blk value.?;
                    }

                    @compileError("impl.term is not implemented for this OS");
                };

                try self.d.reset().print(writer, "{s}", .{term});
            },
            .Uptime => {
                try self.d.reset().bold().print(writer, "Uptime: ", .{});

                const uptime = blk: {
                    const value_ms = ms: {
                        if (is_macos) {
                            comptime var mib = [2]c_int{ c.CTL_KERN, c.KERN_BOOTTIME };
                            // struct layout is dictated by libc
                            // Reference: ziglang/zig lib/libc/include/any-macos-any/sys/_types/_timeval64.h
                            const TimeVal = extern struct { secs: u64, usecs: u64 };

                            var value = try darwin.sysctl(allocator, TimeVal, mib[0..]);
                            break :ms @divFloor(@intCast(u64, std.time.milliTimestamp()), 1000) - value.secs;
                        }

                        @compileError("impl.uptime is not implemented for this OS");
                    };

                    const DAYS_DIVISOR = 60 * 60 * 24;
                    const HOURS_DIVISOR = 60 * 60;
                    const MINUTES_DIVISOR = 60;
                    const SECONDS_DIVISOR = 1;

                    const days_abs = @divFloor(value_ms, DAYS_DIVISOR);
                    const hours_abs = @divFloor(value_ms, HOURS_DIVISOR);
                    const minutes_abs = @divFloor(value_ms, MINUTES_DIVISOR);

                    break :blk .{
                        .days = days_abs,
                        .hours = @divFloor(value_ms - days_abs * DAYS_DIVISOR, HOURS_DIVISOR),
                        .minutes = @divFloor(value_ms - hours_abs * HOURS_DIVISOR, MINUTES_DIVISOR),
                        .seconds = @divFloor(value_ms - minutes_abs * MINUTES_DIVISOR, SECONDS_DIVISOR),
                    };
                };

                try self.d.reset().print(writer, "{d}d {d}h {d}m {d}s", .{ uptime.days, uptime.hours, uptime.minutes, uptime.seconds });
            },
            .Space => {},
            .Colors1 => {
                var i: u8 = 0;
                while (i < 8) : (i += 1)
                    try self.d.reset().bgANSI(i).print(writer, "   ", .{});
            },
            .Colors2 => {
                var i: u8 = 8;
                while (i < 16) : (i += 1)
                    try self.d.reset().bgANSI(i).print(writer, "   ", .{});
            },
        }
    }
};
