const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

// Reference: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit

const Style = enum(u8) { Regular = 0, Bold = 8 };

// While technically we can support full 24-bit colors (RGB) because most modern terminals will be able to render them, there's really no point, the standard 256 colors are more than enough
const Color = enum(u8) { Black, Red, Green, Blue, Magenta, Cyan, White };

pub fn Decorated(comptime Value: type) type {
    return struct {
        const Self = @This();

        value: Value,
        style: Style = .Regular,
        fg: ?Color = null,
        bg: ?Color = null,

        pub fn init(value: Value) Self {
            return .{ .value = value };
        }

        pub fn bold(self: *Self) *Self {
            self.style = .Bold;
            return self;
        }

        pub fn regular(self: *Self) *Self {
            self.style = .Regular;
            return self;
        }

        pub fn foreground(self: *Self, color: Color) *Self {
            self.fg = color;
            return self;
        }

        pub fn background(self: *Self, color: Color) *Self {
            self.fg = color;
            return self;
        }

        pub fn print(self: *Self, writer: Writer) !void {
            switch (self.style) {
                .Bold => try writer.print("\x1B[1m", .{}),
                else => {},
            }

            if (self.fg) |color| {
                try writer.print("\x1B[38;5;{d}m", .{@enumToInt(color)});
            }

            if (self.bg) |color| {
                try writer.print("\x1B[48;5;{d}m", .{@enumToInt(color)});
            }

            switch (@typeInfo(Value)) {
                .Int => try writer.print("{d}", .{self.value}),
                .Float => try writer.print("{d}", .{self.value}),
                else => try writer.print("{s}", .{self.value}),
            }

            try writer.print("\x1B[0m", .{});
        }

        pub fn println(self: *Self, writer: Writer) !void {
            try self.print(writer);
            try writer.print("\n", .{});
        }
    };
}
