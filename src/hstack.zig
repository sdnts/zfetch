const std = @import("std");

const Self = @This();

comptime cols: u8 = 2,

pub fn init(comptime cols: u8) Self {
    if (cols > 3) {
        @compileError("Horizontal Layout only supports up to 3 columns currently");
    }

    return Self{ .cols = cols };
}

pub fn body(self: *Self, comptime b: anytype) void {
    const BodyType = @TypeOf(b);
    const body_type_info = @typeInfo(BodyType);
    if (body_type_info != .Struct) {
        @compileError("Expected tuple or struct argument as body, found " ++ @typeName(BodyType));
    }

    const fields_info = body_type_info.Struct.fields;
    if (fields_info.len != self.cols) {
        @compileError("Number of elements in body must match the number of columns");
    }
}
