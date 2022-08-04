const std = @import("std");
const ZFetchError = @import("./errors.zig").ZFetchError;

const SplitIterator = std.mem.SplitIterator(u8);
const Allocator = std.mem.Allocator;
const Writer = std.fs.File.Writer;

// Unfortunately we cannot use Zig's multiline strings here because they do not support escape characters
// If we wanted to render an ASCII image with the same color/style all over, we could use multiline strings along with fmt.Decorated
const latte =
    "\n" ++
    "\n" ++
    "            \x1B[38;5;216;1m＿＿＿\n" ++
    "           \x1B[38;5;216;1m/フ    フ\n" ++
    "          \x1B[38;5;216;1m|   \x1B[38;5;255;1m_  _\x1B[38;5;216;1m|\n" ++
    "          \x1B[38;5;216;1m/\x1B[38;5;255;1mミ \x1B[38;5;216;1m＿\x1B[38;5;255;1mX\x1B[38;5;216;1mノ\n" ++
    "        \x1B[38;5;216;1m/       |\n" ++
    "       \x1B[38;5;216;1m/  \\    ノ\n" ++
    "     \x1B[38;5;216;1m＿|  | |  |\n" ++
    "    \x1B[38;5;216;1m/ _|   | |  |\n" ++
    "    \x1B[38;5;216;1m| _\\＿_\\_)＿)\n" ++
    "     \x1B[38;5;216;1m\\_つ\n";

const cloudflare =
    "\n" ++
    "\n" ++
    "     \x1B[38;5;208;1m                          ///\n" ++
    "     \x1B[38;5;208;1m                    ///////////////\n" ++
    "     \x1B[38;5;208;1m                 &///////////////////\n" ++
    "     \x1B[38;5;208;1m          /////(//////////////////////\n" ++
    "     \x1B[38;5;208;1m        /////////////////////////////// \x1B[38;5;216;1m***\n" ++
    "     \x1B[38;5;208;1m        ////////////////////////////// \x1B[38;5;216;1m********#\n" ++
    "     \x1B[38;5;208;1m   ////////////////////////////////,   \x1B[38;5;216;1m**********\n" ++
    "     \x1B[38;5;208;1m ///////////////,...                       \x1B[38;5;216;1m,******\n" ++
    "     \x1B[38;5;208;1m///////////////////////////////////  \x1B[38;5;216;1m*************\n";

pub const Art = struct {
    const Self = @This();
    pub const width = 24;
    iterator: SplitIterator,

    pub fn init() Self {
        return Self{ .iterator = std.mem.split(u8, latte, "\n") };
    }

    pub fn write(self_opaque: *anyopaque, writer: Writer) ZFetchError!?usize {
        const self = @ptrCast(*Self, @alignCast(@alignOf(Self), self_opaque));

        if (self.iterator.next()) |l| {
            try writer.print("{s}", .{l});

            // We'll attempt to calculate the length of this line so we can pad it appropriately (making sysinfo line up neatly)
            // This gets tricky though because every line in our "art" contains terminal escape sequences, which count as actual UTF8 characters
            // To avoid another allocation, we'll first create a UTF8 view into the line, then iterate over its codepoints
            // We'll greedily advance the iterator if we think we've hit a terminal escape sequence (counting it as 0 characters)
            // Any ASCII characters are counted as 1 character
            // Anything else is counted as 2 characters, because most terminals will render non-ASCII UTF8 as a glyph that is 2 ASCII characters wide
            // This is mostly based on observation, and I may be wrong
            // TODO: Verify these claims
            var chars: usize = 0;
            var utf8 = (try std.unicode.Utf8View.init(l)).iterator();
            while (utf8.nextCodepointSlice()) |codepoint| {
                // std.debug.print("{d}", .{codepoint});
                if (codepoint[0] == '\x1B') {
                    // We've hit the beginning of a terminal escape sequence, time to be greedy
                    while (utf8.nextCodepointSlice()) |c| {
                        if (c[0] == 'm') {
                            break;
                        }
                    }
                } else if (codepoint.len == 1 and codepoint[0] < 256) {
                    // ASCII character
                    chars += 1;
                } else {
                    // non-ASCII character
                    chars += 2;
                }
            }

            return chars;
        } else {
            return null;
        }
    }
};
