const sys = @import("../sys/sys.zig");

/// Iterates over system information, line-by-line
const Self = @This();

// const order: Decorated = .{
//     sys.cores(),
// };

pub fn init() Self {
    return Self{};
}

pub fn next(self: *Self) ?[]const u8 {
    _ = self;
    return "sysiter1";
}
