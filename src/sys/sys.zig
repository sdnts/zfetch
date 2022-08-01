const builtin = @import("builtin");
const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysctl.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("IOKit/IOKitLib.h");
});
const darwin = @import("./darwin.zig");

const Allocator = std.mem.Allocator;
pub const Kind = enum { Cores, CPU, GPU, Hostname, Kernel, Machine, OS, RAM, Resolution, Shell, Term, Threads, Uptime, User };
const is_macos = builtin.target.os.tag == .macos;
const is_linux = builtin.target.os.tag == .linux;
const is_windows = builtin.target.os.tag == .windows;

/// Information you can show is implemented on a per-platform basis here. There is unfortunately no cross-platform way to get system information,
/// so you'll regularly see branches based on supported operating systems. I'm leaving a few general notes here that might be useful if you're tweaking this,
/// although to be honest I'm leaving these for myself.
/// The general rule behind implementations is to favor speed over anything else (even correctness at times, because it really isn't as important in this case)
pub const Impl = union(Kind) {
    Cores: Cores,
    CPU: CPU,
    GPU: GPU,
    Hostname: Hostname,
    Kernel: Kernel,
    Machine: Machine,
    OS: OS,
    RAM: RAM,
    Resolution: Resolution,
    Shell: Shell,
    Term: Term,
    Threads: Threads,
    Uptime: Uptime,
    User: User,

    pub const Cores = struct {
        pub fn cores(allocator: Allocator) !usize {
            if (is_macos) {
                comptime var mib = [_]c_int{ c.CTL_HW, c.HW_NCPU };
                // TODO: Find out why requesting a `usize` ValueType (instead of `c_int`) messes things up
                const value = try darwin.sysctl(allocator, c_int, mib[0..]);
                return @intCast(usize, value);
            }

            @compileError("impl.cores is not implemented for this OS");
        }
    };

    pub const CPU = struct {
        pub fn cpu(allocator: Allocator) ![]u8 {
            if (is_macos) {
                // This has a system-dependent MIB, so we use `sysctlbyname`
                return darwin.sysctlbyname(allocator, []u8, "machdep.cpu.brand_string");
            }

            @compileError("impl.cpu is not implemented for this OS");
        }
    };

    pub const GPU = struct {
        const ArrayList = std.ArrayList;

        pub fn gpu(allocator: Allocator) !ArrayList([]const u8) {
            _ = allocator;

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
                    }
                }

                return value;
            }

            @compileError("impl.gpu is not implemented for this OS");
        }
    };

    pub const Hostname = struct {
        pub fn hostname() ![std.os.HOST_NAME_MAX]u8 {
            var buf: [std.os.HOST_NAME_MAX]u8 = undefined;
            _ = try std.os.gethostname(&buf);
            return buf;
        }
    };

    pub const Kernel = struct {
        pub fn kernel(allocator: Allocator) ![]u8 {
            if (is_macos) {
                // This has a system-dependent MIB, so we use `sysctlbyname`
                const name = try darwin.sysctlbyname(allocator, []u8, "kern.ostype");
                const version = try darwin.sysctlbyname(allocator, []u8, "kern.osrelease");
                return std.mem.concat(allocator, u8, &[_][]const u8{ name, " ", version });
            }

            @compileError("impl.kernel is not implemented for this OS");
        }
    };

    pub const Machine = struct {
        pub fn machine(allocator: Allocator) ![]u8 {
            if (is_macos) {
                comptime var mib = [_]c_int{ c.CTL_HW, c.HW_PRODUCT };
                return darwin.sysctl(allocator, []u8, mib[0..]);
            }

            @compileError("impl.machine is not implemented for this OS");
        }
    };

    pub const OS = struct {
        pub fn os(allocator: Allocator) ![]u8 {
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
                return std.mem.concat(allocator, u8, &[_][]const u8{ "macOS ", version });
            }

            @compileError("impl.os is not implemented for this OS");
        }
    };

    pub const RAM = struct {
        pub fn ram(allocator: Allocator) !usize {
            if (is_macos) {
                comptime var mib = [_]c_int{ c.CTL_HW, c.HW_MEMSIZE };
                return darwin.sysctl(allocator, usize, mib[0..]);
            }

            @compileError("impl.ram is not implemented for this OS");
        }
    };

    pub const Resolution = struct {
        const Self = @This();
        width: u32,
        height: u32,

        pub fn resolution() !Self {
            if (is_macos) {
                // Big help:
                // https://github.com/jakehilborn/displayplacer/blob/master/displayplacer.c#L5
                // https://github.com/jakehilborn/displayplacer/blob/master/displayplacer.c#L255
                //
                // Docs: https://developer.apple.com/documentation/coregraphics/1456361-cgdisplaypixelswide
                var width = c.CGDisplayPixelsWide(c.CGMainDisplayID());
                var height = c.CGDisplayPixelsHigh(c.CGMainDisplayID());

                return Resolution{ .width = @intCast(u32, width), .height = @intCast(u32, height) };
            }

            @compileError("impl.resolution is not implemented for this OS");
        }
    };

    pub const Shell = struct {
        pub fn shell() ![]const u8 {
            if (is_macos or is_linux) {
                var value = std.os.getenv("SHELL");
                if (value == null) return error.MissingEnvVar;

                var iter = std.mem.splitBackwards(u8, value.?, "/");
                value = iter.next();
                if (value == null) return error.UnexpectedEnvVar;

                return value.?;
            }

            @compileError("impl.shell is not implemented for this OS");
        }
    };

    pub const Term = struct {
        pub fn term() ![]const u8 {
            if (is_macos or is_linux) {
                const value = std.os.getenv("TERM");
                if (value == null) return error.MissingEnvVar;

                return value.?;
            }

            @compileError("impl.term is not implemented for this OS");
        }
    };

    pub const Threads = struct {
        pub fn threads(allocator: Allocator) !usize {
            if (is_macos) {
                // This has a system-dependent MIB, so we use `sysctlbyname`
                // TODO: Find out why requesting a `usize` ValueType (instead of `c_int`) messes things up
                const value = try darwin.sysctlbyname(allocator, c_int, "machdep.cpu.thread_count");
                return @intCast(usize, value);
            }

            @compileError("impl.threads is not implemented for this OS");
        }
    };

    pub const Uptime = struct {
        const Self = @This();
        days: u64,
        hours: u64,
        minutes: u64,
        seconds: u64,

        pub fn uptime(allocator: Allocator) !Self {
            const value_ms = blk: {
                if (is_macos) {
                    comptime var mib = [2]c_int{ c.CTL_KERN, c.KERN_BOOTTIME };
                    // struct layout is dictated by libc
                    // Reference: ziglang/zig lib/libc/include/any-macos-any/sys/_types/_timeval64.h
                    const TimeVal = extern struct { secs: u64, usecs: u64 };

                    var value = try darwin.sysctl(allocator, TimeVal, mib[0..]);
                    break :blk @divFloor(@intCast(u64, std.time.milliTimestamp()), 1000) - value.secs;
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

            return Uptime{
                .days = days_abs,
                .hours = @divFloor(value_ms - days_abs * DAYS_DIVISOR, HOURS_DIVISOR),
                .minutes = @divFloor(value_ms - hours_abs * HOURS_DIVISOR, MINUTES_DIVISOR),
                .seconds = @divFloor(value_ms - minutes_abs * MINUTES_DIVISOR, SECONDS_DIVISOR),
            };
        }
    };

    pub const User = struct {
        pub fn user() ![]const u8 {
            if (is_macos or is_linux) {
                const value = std.os.getenv("USER");
                if (value == null) return error.MissingEnvVar;

                return value.?;
            }

            @compileError("impl.user is not implemented for this OS");
        }
    };
};
