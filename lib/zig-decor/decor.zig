const std = @import("std");

const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

const Style = enum { Bold };
const ColorName = enum(u8) { Black, Red, Green, Blue, Yellow, Magenta, Cyan, White };

/// A super simple utility to help you print pretty strings to the terminal.
pub const Decor = struct {
    const Self = @This();

    _style: ?Style,
    _fg: ?u8,
    _bg: ?u8,

    /// Initialize a new instance
    pub fn init() Self {
        return .{ ._style = null, ._fg = null, ._bg = null };
    }

    /// Set the style of your text. Currently supported styles are: .Bold
    pub fn style(self: *Self, s: ?Style) *Self {
        self._style = s;
        return self;
    }

    /// Set the text style to bold
    pub fn bold(self: *Self) *Self {
        return self.style(.Bold);
    }

    /// Set the foreground color of the text to one of the pre-defefined aliases
    pub fn foreground(self: *Self, color: ColorName) *Self {
        return self.foregroundANSI(@enumToInt(color));
    }

    /// Set the foreground color of the text to one of the pre-defefined aliases
    pub fn fg(self: *Self, color: ColorName) *Self {
        return self.foreground(color);
    }

    /// Set the foreground color of the text to an 8bit ANSI color code
    pub fn foregroundANSI(self: *Self, code: u8) *Self {
        self._fg = code;
        return self;
    }

    /// Set the foreground color of the text to an 8bit ANSI color code
    pub fn fgANSI(self: *Self, code: u8) *Self {
        return self.foregroundANSI(code);
    }

    /// Set the background color of the text to one of the pre-defefined aliases
    pub fn background(self: *Self, color: ColorName) *Self {
        return self.backgroundANSI(@enumToInt(color));
    }

    /// Set the background color of the text to one of the pre-defefined aliases
    pub fn bg(self: *Self, color: ColorName) *Self {
        return self.background(color);
    }

    /// Set the background color of the text to an 8bit ANSI color code
    pub fn backgroundANSI(self: *Self, code: u8) *Self {
        self._bg = code;
        return self;
    }

    /// Set the background color of the text to an 8bit ANSI color code
    pub fn bgANSI(self: *Self, code: u8) *Self {
        return self.backgroundANSI(code);
    }

    /// Write the configured text to a Writer (usually stdout). Returns the number of bytes written.
    pub fn write(self: *Self, writer: Writer, comptime format: []const u8, args: anytype) !usize {
        // Useful reference: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit

        var chars: usize = 0;

        // Reset styles before everything is written so you don't merge existing escape sequences into this one
        try writer.print("\x1B[0m", .{});

        // Write escape code for requested style
        if (self._style) |s| {
            switch (s) {
                .Bold => try writer.print("\x1B[1m", .{}),
            }
        }

        // Write escape code for requested foreground color (aka "set" the foreground color)
        if (self._fg) |color| {
            try writer.print("\x1B[38;5;{d}m", .{color});
        }

        // Write escape code for requested background color (aka "set" the background color)
        if (self._bg) |color| {
            try writer.print("\x1B[48;5;{d}m", .{color});
        }

        // Write actual content
        try writer.print(format, args);
        chars += std.fmt.count(format, args);

        // Reset styles after everything is written so you don't mess up terminal output after
        try writer.print("\x1B[0m", .{});

        return chars;
    }

    /// Write the configured text to a Writer (usually stdout). Useful as an alternative to `write` when you do not care about the number of bytes written.
    pub fn print(self: *Self, writer: Writer, comptime format: []const u8, args: anytype) !void {
        _ = try self.write(writer, format, args);
    }

    /// Write the configured text to a Writer (usually stdout), and add a new line. Useful shorthand.
    pub fn println(self: *Self, writer: Writer, comptime format: []const u8, args: anytype) !void {
        try self.print(writer, format ++ "\n", args);
    }
};
