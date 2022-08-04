const std = @import("std");
const sys = @import("sys.zig");

// zig fmt: off

pub const ZFetchError =
    std.mem.Allocator.Error ||
    std.os.WriteError ||
    std.fs.File.WriteError ||
    sys.darwin.SysctlError ||
    error{
        MissingEnvVar,
        UnexpectedEnvVar,
        IOKitError
    };

// zig fmt: on
