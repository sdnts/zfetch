const FmtIterator = @import("./FmtIterator.zig");

const Self = @This();

/// Must give this an actual item so it has in-memory bits. Without it, it does not coerce to *anyopaque
/// TODO: Figure out a way around this
_: bool = false,

pub fn init() Self {
    return Self{ ._ = false };
}

pub fn iter(self: *Self) FmtIterator {
    return FmtIterator.init(self, next);
}

pub fn next(_: *Self) ?[]u8 {
    return null;
}
