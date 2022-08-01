# zig-decor

A super simple utility to help you print pretty strings to the terminal

### Installation

### Usage

The following program outputs `Hello World!` in red, against a white background:

```zig
const std = @import("std");
const Decor = @import("decor").Decor;

pub fn main() !void {
  var stdout = std.io.getStdOut().writer();
  try Decor
    .init()
    .bold()
    .fg(.Red)
    .bg(.White)
    .println(stdout, "Hello {s}!", .{"World"});
}
```

The 8 basic colors have aliases as demonstrated above. If you're looking for more specific colors, you can also provide an 8-bit ANSI color code:

```zig
const std = @import("std");
const Decor = @import("decor").Decor;

pub fn main() !void {
  var stdout = std.io.getStdOut().writer();
  try Decor
    .init()
    .fgANSI(33)
    .println(stdout, "I'm blue!", .{});
}
```

### Reference

`decor` is tiny on purpose.
