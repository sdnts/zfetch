const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

// Reference: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit

const Style = enum(u8) { Regular, Bold };

const Color = union(enum) {
    name: enum(u8) { Black, Red, Green, Blue, Yellow, Magenta, Cyan, White },
    number: u8,
};

pub const Decorated = struct {
    const Self = @This();

    style: Style = .Regular,
    fg: ?Color = null,
    bg: ?Color = null,

    pub fn init() Self {
        return .{};
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
        self.bg = color;
        return self;
    }

    pub fn print(self: *Self, writer: Writer, comptime format: []const u8, args: anytype) !void {
        switch (self.style) {
            .Bold => try writer.print("\x1B[1m", .{}),
            else => {},
        }

        if (self.fg) |color| {
            const val = switch (color) {
                .name => @enumToInt(color.name),
                .number => color.number,
            };
            try writer.print("\x1B[38;5;{d}m", .{val});
        }

        if (self.bg) |color| {
            const val = switch (color) {
                .name => @enumToInt(color.name),
                .number => color.number,
            };
            try writer.print("\x1B[48;5;{d}m", .{val});
        }

        try writer.print(format, args);

        try writer.print("\x1B[0m", .{});
    }

    pub fn println(self: *Self, writer: Writer, comptime format: []const u8, args: anytype) !void {
        try self.print(writer, format, args);
        try writer.print("\n", .{});
    }
};
