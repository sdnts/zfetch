const std = @import("std");

pub const SysctlError = error{IllegalValueType} || std.mem.Allocator.Error || std.os.SysCtlError;

// System information is available through `sysctl`.
// Running `sysctl -a` in your shell will list all information available to you. You can also use the `sysctl` syscall to query parts of this database.
// Useful reading: https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/sysctl.3.html
//
// TL;DR is that there are three syscalls in `sysctl.h`:
// 1. `sysctl` lets you query using a MIB array, which identifies what key you're looking for.
//    You also provide pointers to a variable that will be populated with the value of this key, and a pointer to a variable that defines the size of the value.
//    If you call `sysctl` with a `null` size or a size that is smaller than the value's expected size, your size variable will be populated with the correct size.
//    We could use this behaviour to allocate an exactly-large-enough buffer for the value, but a hard-coded size works faster because it saves a syscall. Of course, we do have a fallback for when our hard-coded value was too small.
//    If you call `sysctl` with a `null` value (but with a large enough size), the value will be populated using the pointer.
//    This syscall is approximately three times faster than using `sysctlbyname`.
//
// 2. `sysctlbyname` lets you query using the key's name directly. This internally translates the name into the MIB array, then calls `sysctl` as above.
//    This also accepts pointers to variables holding the value and its size, which behave the exact same way as above.
//    This syscall can be up to 3 times slower than using `sysctl` directly, avoid if at all possible.
//
//  3. `sysctlnametomib` lets you convert the key's name to a MIB array. You can then use the MIB array for a `sysctl` call.
//     This accepts the key's name, as well as pointers to an empty MIB array and its size, which are populated.
//
//  So using sysctl with a predefined MIB is clearly the way to go.
//  Sometimes however, different versions of macOS (and even arm vs Intel) have different MIBs for the same information (citation needed, I only did a little investigation on the Intel and M1 MacBooks that I own)
//  This means that hard-coded MIBs are not an option in these cases. Using sysctlnametomib + sysctl is almost exactly as fast as using `sysctlbyname`, so we just use sysctlbyname for maintainability (the slowest syscall ironically)
//  If you know more than I do about this, please do let me know!
//
//  Here are the benchmarks using hyperfine, for posterity:
//  Summary
//   './zig-out/bin/sysctl' ran
//     1.00 ± 0.12 times faster than './zig-out/bin/sysctlbyname'
//     1.02 ± 0.13 times faster than './zig-out/bin/sysctlnametomib'
//
//  So the implmentation strategy is: use predefined MIBs & a single `sysctl` call when possible, but switch to `sysctlbyname` otherwise.

/// Calls sysctl and handles errors to a reasonable extent
/// Since `sysctl` can return values as a usize or a string, this implementation handles both cases.
/// When calling this function, you provide the expected value type as the `ValueType` comptime argument. For `ValueType`s that do not make sense in the context of `sysctlbyname`, an error is returned. Currently supported `ValueType`s are `[]u8` & `usize`
pub fn sysctl(allocator: std.mem.Allocator, comptime ValueType: type, comptime mib: []c_int) SysctlError!ValueType {
    switch (@typeInfo(ValueType)) {
        .Pointer => |info| {
            // Special handling for "string" type values
            if (info.child != u8) {
                return SysctlError.IllegalValueType;
            }

            // Assume a buffer size. If it is too small, we'll deal with it later
            var size: usize = 64;
            var value = try allocator.alloc(u8, size);

            std.os.sysctl(mib, value.ptr, &size, null, 0) catch |err| switch (err) {
                error.SystemResources => {
                    // Assumed buffer size was too small

                    // According to docs, when the supplied buffer size is too small to fit the requested value, it is updated to the size of the actual value.
                    // But for whatever reason, that doesn't seem to be happening. So we make an additional sysctlbyname call with the buffer set to NULL. That does seem to update the `size` variable as advertised.
                    _ = try std.os.sysctl(mib, null, &size, null, 0);
                    value = try allocator.realloc(value, size);

                    // We don't handle errors in this statement explicitly because the only errors that can occur are non-recoverable
                    _ = try std.os.sysctl(mib, value.ptr, &size, null, 0);
                },
                else => {
                    // All other errors are unexpected (and non-recoverable)
                    return err;
                },
            };

            return value;
        },
        else => {
            var value: ValueType = undefined;
            var size: usize = @sizeOf(@TypeOf(value));

            _ = std.os.darwin.sysctl(mib.ptr, mib.len, &value, &size, null, 0);
            return value;
        },
    }
}

/// Calls sysctlbyname and handles errors to a reasonable extent
/// Since `sysctlbyname` can return values as a usize or a string, this implementation handles both cases.
/// When calling this function, you provide the expected value type as the `ValueType` comptime argument. For `ValueType`s that do not make sense in the context of `sysctlbyname`, an error is returned. Currently supported `ValueType`s are `[]u8` & `usize`
pub fn sysctlbyname(allocator: std.mem.Allocator, comptime ValueType: type, comptime name: [*:0]const u8) SysctlError!ValueType {
    switch (@typeInfo(ValueType)) {
        .Pointer => |info| {
            // Special handling for "string" type values
            if (info.child != u8) {
                return SysctlError.IllegalValueType;
            }

            // Assume a buffer size. If it is too small, we'll deal with it later
            var size: usize = 32;
            var value = try allocator.alloc(u8, size);

            std.os.sysctlbynameZ(name, value.ptr, &size, null, 0) catch |err| switch (err) {
                error.SystemResources => {
                    // Assumed buffer size was too small
                    std.debug.print("Buffer too small {d}", .{size});

                    // According to docs, when the supplied buffer size is too small to fit the requested value, it is updated to the size of the actual value.
                    // But for whatever reason, that doesn't seem to be happening. So we make an additional sysctlbyname call with the buffer set to NULL. That does seem to update the `size` variable as advertised.
                    _ = try std.os.sysctlbynameZ(name, null, &size, null, 0);
                    std.debug.print("Buffer adjusted {d}", .{size});
                    value = try allocator.realloc(value, size);

                    // We don't handle errors in this statement explicitly because the only errors that can occur are non-recoverable
                    _ = try std.os.sysctlbynameZ(name, value.ptr, &size, null, 0);
                },
                else => {
                    // All other errors are extremely unexpected (and non-recoverable)
                    return err;
                },
            };

            return value;
        },
        else => {
            var value: ValueType = undefined;
            var size: usize = @sizeOf(@TypeOf(value));

            _ = try std.os.sysctlbynameZ(name, &value, &size, null, 0);
            return value;
        },
    }
}

// sysctl returns usize
// sysctl returns string

test "sysctlbyname happy path" {}

test "sysctlbyname with unrecognized generic param" {}

test "sysctlbyname when assumed buffer is too small" {}
