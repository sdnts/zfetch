const std = @import("std");
const Lines = @import("./fmt/Lines.zig").Lines;

const SplitIterator = std.mem.SplitIterator(u8);
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

// Unfortunately we cannot use Zig's multiline strings here because they do not support escape characters
// If we wanted to render an ASCII image with the same color/style all over, we could use multiline strings along with fmt.Decorated
const latte =
    "         \x1B[38;5;216;1m＿＿＿\n" ++
    "        \x1B[38;5;216;1m/フ    フ\n" ++
    "       \x1B[38;5;216;1m|   \x1B[38;5;255;1m_  _\x1B[38;5;216;1m⏐\n" ++
    "       \x1B[38;5;216;1m/\x1B[38;5;255;1mミ \x1B[38;5;216;1m＿\x1B[38;5;255;1mX\x1B[38;5;216;1mノ\n" ++
    "     \x1B[38;5;216;1m/       ⏐\n" ++
    "    \x1B[38;5;216;1m/  \\    ノ\n" ++
    "  \x1B[38;5;216;1m＿⏐  | |  |\n" ++
    " \x1B[38;5;216;1m/ _|   | |  |\n" ++
    " \x1B[38;5;216;1m| _\\＿_\\_)＿)\n" ++
    "  \x1B[38;5;216;1m\\_つ\n";

const cloudflare =
    " \x1B[38;5;208;1m                            ///\n" ++
    " \x1B[38;5;208;1m                      ///////////////\n" ++
    " \x1B[38;5;208;1m                   &///////////////////\n" ++
    " \x1B[38;5;208;1m            /////(//////////////////////\n" ++
    " \x1B[38;5;208;1m          /////////////////////////////// \x1B[38;5;216;1m***\n" ++
    " \x1B[38;5;208;1m          ////////////////////////////// \x1B[38;5;216;1m********#\n" ++
    " \x1B[38;5;208;1m     ////////////////////////////////,   \x1B[38;5;216;1m**********\n" ++
    " \x1B[38;5;208;1m   ///////////////,...                       \x1B[38;5;216;1m,******\n" ++
    " \x1B[38;5;208;1m  ///////////////////////////////////  \x1B[38;5;216;1m*************\n";

const apple = "";

pub const Art = struct {
    const Self = @This();
    pub const width: usize = 30;
    iterator: SplitIterator = std.mem.split(u8, latte, "\n"),

    pub fn init() Self {
        return Self{};
    }

    pub fn lines(self: *Self) Lines {
        return Lines{ .impl = @ptrCast(*anyopaque, self), .writeNextFn = writeNext };
    }

    pub fn writeNext(self_opaque: *anyopaque, _: Allocator, writer: Writer) !?void {
        const self = @ptrCast(*Self, @alignCast(@alignOf(Self), self_opaque));

        if (self.iterator.next()) |l| {
            try writer.print("{s}", .{l});
        } else {
            return null;
        }
    }
};
