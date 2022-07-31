const art = @import("../art.zig");
const FmtIterator = @import("./FmtIterator.zig");

/// Iterates over some ASCII art, line-by-line
const Self = @This();
const img = art.latte;

pub fn iter(self: *Self) FmtIterator {
    return FmtIterator.init(self, next);
}

pub fn next(self: *Self) ?[]const u8 {
    _ = self;
    return "art_iter1";
}
