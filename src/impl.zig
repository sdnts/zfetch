const builtin = @import("builtin");
const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysctl.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("IOKit/IOKitLib.h");
});
const darwin = @import("./impl/darwin.zig");

const isMacOS = builtin.target.os.tag == .macos;
const isLinux = builtin.target.os.tag == .linux;
const isWindows = builtin.target.os.tag == .windows;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Resolution = struct {
    width: u32,
    height: u32,
};

// Information you can show is implemented on a per-platform basis here. There is unfortunately no cross-platform way to get system information,
// so you'll regularly see branches based on supported operating systems. I'm leaving a few general notes here that might be useful if you're tweaking this,
// although to be honest I'm leaving these for myself.
// The general rule behind implementations is to favor speed over anything else (even correctness at times)
//
// macOS:
// More details in darwin.zig
//
// linux:
// Not implemented
//
// windows:
// Not implemented

/// Returns the number of physical CPUs available, or an error
pub fn cores(allocator: Allocator) !usize {
    if (isMacOS) {
        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_NCPU };
        // TODO: Find out why requesting a `usize` ValueType (instead of `c_int`) messes things up
        const value = try darwin.sysctl(allocator, c_int, mib[0..]);
        return @intCast(usize, value);
    }

    @compileError("impl.cores is not implemented for this OS");
}

/// Returns the make of your CPU, or an error
pub fn cpu(allocator: Allocator) ![]u8 {
    if (isMacOS) {
        // This has a system-dependent MIB, so we use `sysctlbyname`
        return darwin.sysctlbyname(allocator, []u8, "machdep.cpu.brand_string");
    }

    @compileError("impl.cpu is not implemented for this OS");
}

/// Returns the make of your GPU, or an error
pub fn gpu(allocator: Allocator) !ArrayList([]const u8) {
    _ = allocator;

    if (isMacOS) {
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

/// Returns your machine's name, or an error
pub fn hostname() ![std.os.HOST_NAME_MAX]u8 {
    var buf: [std.os.HOST_NAME_MAX]u8 = undefined;
    _ = try std.os.gethostname(&buf);
    return buf;
}

// Returns a string with the name and version of the kernel, or an error
pub fn kernel(allocator: Allocator) ![]u8 {
    if (isMacOS) {
        // This has a system-dependent MIB, so we use `sysctlbyname`
        const name = try darwin.sysctlbyname(allocator, []u8, "kern.ostype");
        const version = try darwin.sysctlbyname(allocator, []u8, "kern.osrelease");
        return std.mem.concat(allocator, u8, &[_][]const u8{ name, " ", version });
    }

    @compileError("impl.kernel is not implemented for this OS");
}

/// Returns the model number of your device (only applicable for laptops really), or an error
pub fn machine(allocator: Allocator) ![]u8 {
    if (isMacOS) {
        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_PRODUCT };
        return darwin.sysctl(allocator, []u8, mib[0..]);
    }

    @compileError("impl.machine is not implemented for this OS");
}

/// Returns a string with your OS's name and version, or an error
pub fn os(allocator: Allocator) ![]u8 {
    if (isMacOS) {
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

/// Returns the amount of RAM in your system (in bytes) or an error
pub fn ram(allocator: Allocator) !usize {
    if (isMacOS) {
        comptime var mib = [_]c_int{ c.CTL_HW, c.HW_MEMSIZE };
        return darwin.sysctl(allocator, usize, mib[0..]);
    }

    @compileError("impl.ram is not implemented for this OS");
}

/// Returns the primary display's resolution, or an error
pub fn resolution() !Resolution {
    if (isMacOS) {
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

/// Returns the name of your shell, or an error
pub fn shell() !?[]const u8 {
    if (isMacOS or isLinux) {
        if (std.os.getenv("SHELL")) |s| {
            var iter = std.mem.splitBackwards(u8, s, "/");
            return iter.next();
        }

        return null;
    }

    @compileError("impl.shell is not implemented for this OS");
}

/// Returns the name of your terminal, or an error
pub fn term() !?[]const u8 {
    if (isMacOS or isLinux) {
        return std.os.getenv("TERM");
    }

    @compileError("impl.term is not implemented for this OS");
}

/// Returns the number of total number of threads available, across all cores, or an error
pub fn threads(allocator: Allocator) !usize {
    if (isMacOS) {
        // This has a system-dependent MIB, so we use `sysctlbyname`
        // TODO: Find out why requesting a `usize` ValueType (instead of `c_int`) messes things up
        const value = try darwin.sysctlbyname(allocator, c_int, "machdep.cpu.thread_count");
        return @intCast(usize, value);
    }

    @compileError("impl.threads is not implemented for this OS");
}

/// Returns the time (in seconds) since your system was shut down / restarted, or an error
pub fn uptime(allocator: Allocator) !usize {
    if (isMacOS) {
        comptime var mib = [2]c_int{ c.CTL_KERN, c.KERN_BOOTTIME };
        // struct layout is dictated by libc
        // Reference: ziglang/zig lib/libc/include/any-macos-any/sys/_types/_timeval64.h
        const TimeVal = extern struct { secs: u64, usecs: u64 };

        var value = try darwin.sysctl(allocator, TimeVal, mib[0..]);
        return @divFloor(@intCast(u64, std.time.milliTimestamp()), 1000) - value.secs;
    }

    @compileError("impl.uptime is not implemented for this OS");
}
