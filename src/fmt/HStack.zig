const std = @import("std");
const FmtIterator = @import("./FmtIterator.zig");
const NoopFmtIterator = @import("./NoopFmtIterator.zig");

const Writer = std.fs.File.Writer;

const HStackConfig = struct {
    columns: u2,
};

///          HStack
///  ┌─────────────────────────┐
///  ┌───────┐┌───────┐┌───────┐
///  │ block ││ block ││ block │
///  │   1   ││   2   ││   3   │
///  │content││content││content│
///  └───────┘└───────┘└───────┘
///
/// An HStack allows you to layout/print multiple "blocks" of text side-by-side.
/// Each block's content is controlled by an iterator that outputs strings representing a single line per iteration.
/// A newline character is automatically appended after every iteration.
///
/// For sake of simplicity, this HStack is only as complex as it needs to be to be able to print zfetch's output.
/// Overflows / truncation, for example aren't supported.
pub fn HStack(comptime config: HStackConfig) type {
    return struct {
        const Self = @This();
        const Body = [config.columns]FmtIterator;

        _columns: u2,
        _spacing: u8,
        _body: Body,

        pub fn init() Self {
            var noop_iter = NoopFmtIterator.init().iter();
            return .{ ._columns = config.columns, ._spacing = 3, ._body = .{noop_iter} ** config.columns };
        }

        pub fn spacing(self: *Self, s: u8) *Self {
            self._spacing = s;
            return self;
        }

        pub fn body(self: *Self, b: Body) *Self {
            self._body = b;
            return self;
        }

        pub fn print(self: *Self, writer: Writer) !void {
            while (true) {
                for (self._body) |iter, i| {
                    // Write whatever the iterator wants
                    var str = iter.next();
                    try writer.print("{s}", .{str});

                    // Add spacing
                    if (i < self._body.len - 1) {
                        var s: u8 = 0;
                        while (s < self._spacing) : (s += 1) {
                            _ = try writer.write(" ");
                        }
                    }
                }

                // Automatic newline after every iteration
                try writer.print("\n", .{});

                break;
            }
        }
    };
}
