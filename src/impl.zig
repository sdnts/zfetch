const builtin = @import("builtin");
const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysctl.h");
    @cInclude("sys/types.h");
    @cInclude("ApplicationServices/ApplicationServices.h");
});

const Allocator = std.mem.Allocator;
const HOST_NAME_MAX = std.os.HOST_NAME_MAX;

const isMacOS = builtin.target.os.tag == .macos;
const isLinux = builtin.target.os.tag == .linux;
const isWindows = builtin.target.os.tag == .windows;

// Information you can show is implemented on a per-platform basis here. There is unfortunately no cross-platform way to get system information,
// so you'll regularly see branches based on supported operating systems. I'm leaving a few general notes here that might be useful if you're tweaking this,
// although to be honest I'm leaving these for myself.
// The general rule behind implementations is to favor speed over anything else (even correctness at times)
//
// macOS:
// System information is available through `sysctl`.
// Running `sysctl -a` in your shell will list all information available to you. You can also use the `sysctl` syscall to query parts of this database.
// Useful reading: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctl.3.html
//
// TL;DR is that there are three syscalls in `sysctl.h`:
// 1. `sysctl` lets you query using a MIB array, which identifies what key you're looking for.
//    You also provide pointers to a variable that will be populated with the value of this key, and a pointer to a variable that defines the size of the value.
//    If you call `sysctl` with a `null` size or a size that is smaller than the value's expected size, your size variable will be populated with the correct size. We use this in multiple places to figure out how much memory to allocate.
//    If you call `sysctl` with a `null` value (but with a large enough size), the value will be populated using the pointer.
//    This syscall is the fastest, so prefer this whenever you can
//
// 2. `sysctlbyname` lets you query using the key's name directly. This internally translates the name into the MIB array, then calls `sysctl` as above.
//    This also accepts pointers to variables holding the value and its size, which behave the exact same way as above.
//    This syscall can be up to 3 times slower than using `sysctl` directly, avoid if at all possible.
//
//  3. `sysctlnametomib` lets you convert the key's name to a MIB array. You can then use the MIB array for a `sysctl` call.
//     This accepts the key's name, as well as pointers to an empty MIB array and its size, which are populated.
//
// linux:
// Not implemented
//
//
// windows:
// Not implemented
//

pub const Impl = struct {
    /// Returns the number of physical CPUs available, or an error
    pub fn cores() CoresError!usize {
        if (isMacOS) {
            var mib = [2]c_int{ c.CTL_HW, c.HW_NCPU };
            var value: c_int = undefined;
            var size: usize = @sizeOf(@TypeOf(value));
            const err = std.os.darwin.sysctl(&mib, mib.len, &value, &size, null, 0);
            if (err != 0) return CoresError.SysctlError;

            return @intCast(usize, value);
        }

        @compileError("impl.cores is not implemented for this OS");
    }

    /// Returns the make of your CPU, or an error
    pub fn cpu(allocator: Allocator) CPUError![]u8 {
        if (isMacOS) {
            // To use `sysctl` (and avoid `sysctlbyname`), we need the MIB array, which is usually constructable using a relevant #define in `sysctl.h`, but I couldn't find one.
            // So I found the MIB for this key manually using:
            // ```
            //   var mib = [2]c_int{ c.CTL_MACHDEP, 0 };
            //   var mib_size: usize = mib.len;
            //   _ = std.os.darwin.sysctlnametomib("machdep.cpu.brand_string", &mib[0], &mib_size);
            //   std.debug.print("mib:{d}", .{mib});
            // ```
            //
            // Hence the magic numbers in the MIB declaration below
            var mib = [3]c_int{ c.CTL_MACHDEP, 100, 104 };

            var size: usize = undefined;
            var err = std.os.darwin.sysctl(&mib, mib.len, null, &size, null, 0);
            if (err != 0) return CPUError.SysctlError;

            var value = try allocator.alloc(u8, size);
            err = std.os.darwin.sysctl(&mib, mib.len, value.ptr, &size, null, 0);
            if (err != 0) return CPUError.SysctlError;

            return value;
        }

        @compileError("impl.cpu is not implemented for this OS");
    }

    /// Returns the make of your GPU, or an error
    pub fn gpu(allocator: Allocator) ![]const u8 {
        if (isMacOS) {
            const argv = [_][]const u8{ "system_profiler", "SPDisplaysDataType" };
            var cp = try std.ChildProcess.exec(.{ .allocator = allocator, .argv = argv[0..] });
            var iter = std.mem.split(u8, cp.stdout, "\n");

            // Output looks like:
            // ```
            // Graphics/Displays:
            //
            //      <GPUName>:
            //
            //          Chipset Model: ...
            //          ...
            // ```
            //
            // Name of the GPU will be on the third line.

            _ = iter.next().?;
            _ = iter.next().?;
            var value = std.mem.trim(u8, iter.next().?, "\t: ");

            return value;
        }

        @compileError("impl.gpu is not implemented for this OS");
    }

    /// Returns your machine's name, or an error
    pub fn hostname() HostnameError![HOST_NAME_MAX]u8 {
        var buf: [HOST_NAME_MAX]u8 = undefined;
        _ = try std.os.gethostname(&buf);
        return buf;
    }

    // Returns a string with the name and version of the kernel, or an error
    pub fn kernel(allocator: Allocator) KernelError![]u8 {
        if (isMacOS) {
            var name_mib = [2]c_int{ c.CTL_KERN, c.KERN_OSTYPE };
            var version_mib = [2]c_int{ c.CTL_KERN, c.KERN_OSRELEASE };

            // Calculate size of the name string
            var name_size: usize = undefined;
            var err = std.os.darwin.sysctl(&name_mib, name_mib.len, null, &name_size, null, 0);
            if (err != 0) return KernelError.SysctlError;

            // Calculate size of the version string
            var version_size: usize = undefined;
            err = std.os.darwin.sysctl(&version_mib, version_mib.len, null, &version_size, null, 0);
            if (err != 0) return KernelError.SysctlError;

            // Allocate a buffer bug enough for the both of them
            var value = try allocator.alloc(u8, name_size + ' ' + version_size);

            // Populate the name in the buffer
            err = std.os.darwin.sysctl(&name_mib, name_mib.len, value.ptr, &name_size, null, 0);
            if (err != 0) return KernelError.SysctlError;

            // Put in a space between the name and the version
            value[name_size] = ' ';

            // Populate the version in the same buffer
            var version_ptr_offset = (name_size + ' ') * @sizeOf(u8);
            err = std.os.darwin.sysctl(&version_mib, version_mib.len, value.ptr + version_ptr_offset, &version_size, null, 0);
            if (err != 0) return KernelError.SysctlError;

            return value;
        }

        @compileError("impl.kernel is not implemented for this OS");
    }

    /// Returns the model number of your device (only applicable for laptops really), or an error
    pub fn machine(allocator: Allocator) OSError![]u8 {
        if (isMacOS) {
            var mib = [2]c_int{ c.CTL_HW, c.HW_PRODUCT };

            // Calculate the size of the machine string
            var size: usize = undefined;
            var err = std.os.darwin.sysctl(&mib, mib.len, null, &size, null, 0);
            if (err != 0) return OSError.SysctlError;

            // Allocate buffer and populate the machine string in it
            var value = try allocator.alloc(u8, size);
            err = std.os.darwin.sysctl(&mib, mib.len, value.ptr, &size, null, 0);
            if (err != 0) return OSError.SysctlError;

            return value;
        }

        @compileError("impl.machine is not implemented for this OS");
    }

    /// Returns a string with your OS's name and version, or an error
    pub fn os(allocator: Allocator) OSError![]u8 {
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

            // To avoid using `sysctlbyname`, the MIB array was calculated manually using:
            // ```
            //   var mib = [2]c_int{ c.CTL_KERN, 0 };
            //   var mib_size: usize = mib.len;
            //   _ = std.os.darwin.sysctlnametomib("kern.osproductversion", &mib[0], &mib_size);
            //   std.debug.print("mib:{d}", .{mib});
            // ```
            //
            // Hence the magic numbers in the declaraiont below. Explanation is same as in `cpu()`
            var mib = [2]c_int{ c.CTL_KERN, 134 };

            // Calculate the size of the version string
            var version_size: usize = undefined;
            var err = std.os.darwin.sysctl(&mib, mib.len, null, &version_size, null, 0);
            if (err != 0) return OSError.SysctlError;

            // We already know the name of the OS, no syscalls needed
            const name = "macOS";

            // Allocate a buffer big enough for both of them
            var value = try allocator.alloc(u8, name.len + ' ' + version_size);

            // Copy the name to the buffer, and put a space between the name and the version
            std.mem.copy(u8, value, name);
            value[name.len] = ' ';

            // Populate the version in the same buffer
            var version_ptr_offset = (name.len + ' ') * @sizeOf(u8);
            err = std.os.darwin.sysctl(&mib, mib.len, value.ptr + version_ptr_offset, &version_size, null, 0);
            if (err != 0) return OSError.SysctlError;

            return value;
        }

        @compileError("impl.os is not implemented for this OS");
    }

    /// Returns the amount of RAM in your system (in bytes) or an error
    pub fn ram() RAMError!usize {
        if (isMacOS) {
            var mib = [2]c_int{ c.CTL_HW, c.HW_MEMSIZE };

            var value: usize = undefined;
            var size: usize = @sizeOf(@TypeOf(value));
            const err = std.os.darwin.sysctl(&mib, mib.len, &value, &size, null, 0);
            if (err != 0) return RAMError.SysctlError;

            return value;
        }

        @compileError("impl.ram is not implemented for this OS");
    }

    /// Returns the primary display's resolution, or an error
    pub fn resolution() ResolutionError!Resolution {
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
    pub fn shell() ShellError!?[]const u8 {
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
    pub fn term() TermError!?[]const u8 {
        if (isMacOS or isLinux) {
            return std.os.getenv("TERM");
        }

        @compileError("impl.term is not implemented for this OS");
    }

    /// Returns the number of total number of threads available, across all cores, or an error
    pub fn threads() ThreadsError!usize {
        if (isMacOS) {
            // To avoid using `sysctlbyname`, the MIB array was calculated manually using:
            // ```
            //   var mib = [3]c_int{ c.CTL_MACHDEP, 0, 0 };
            //   var mib_size: usize = mib.len;
            //   _ = std.os.darwin.sysctlnametomib("machdep.cpu.thread_count", &mib[0], &mib_size);
            //   std.debug.print("mib:{d}", .{mib});
            // ```
            //
            // Hence the magic numbers in the declaraiont below. Explanation is same as in `cpu()`
            var mib = [3]c_int{ c.CTL_MACHDEP, 100, 103 };

            var value: c_int = undefined;
            var size: usize = @sizeOf(@TypeOf(value));
            const err = std.os.darwin.sysctl(&mib, mib.len, &value, &size, null, 0);
            if (err != 0) return ThreadsError.SysctlError;

            return @intCast(usize, value);
        }

        @compileError("impl.threads is not implemented for this OS");
    }

    /// Returns the time (in seconds) since your system was shut down / restarted, or an error
    pub fn uptime() UptimeError!usize {
        if (isMacOS) {
            var mib = [2]c_int{ c.CTL_KERN, c.KERN_BOOTTIME };

            // struct layout is dictated by libc
            // Reference: ziglang/zig lib/libc/include/any-macos-any/sys/_types/_timeval64.h
            const TimeVal = extern struct { secs: u64, usecs: u64 };

            var value: TimeVal = undefined;
            var size: usize = @sizeOf(@TypeOf(value));
            const err = std.os.darwin.sysctl(&mib, mib.len, &value, &size, null, 0);
            if (err != 0) return RAMError.SysctlError;

            return @divFloor(@intCast(u64, std.time.milliTimestamp()), 1000) - value.secs;
        }

        @compileError("impl.uptime is not implemented for this OS");
    }
};

const Resolution = struct {
    width: u32,
    height: u32,
};

const AllocatorError = std.mem.Allocator.Error;
const SysctlError = error{SysctlError};

pub const ClockspeedError = SysctlError;
pub const CoresError = SysctlError;
pub const CPUError = AllocatorError || SysctlError;
pub const GPUError = AllocatorError || error{};
pub const HostnameError = AllocatorError || std.os.GetHostNameError;
pub const KernelError = AllocatorError || SysctlError;
pub const OSError = AllocatorError || SysctlError;
pub const RAMError = SysctlError;
pub const ResolutionError = error{};
pub const ShellError = error{};
pub const TermError = error{};
pub const ThreadsError = SysctlError;
pub const UptimeError = SysctlError;
