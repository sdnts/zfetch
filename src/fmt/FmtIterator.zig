const std = @import("std");

const Allocator = std.mem.Allocator;
const AllocatorError = std.mem.Allocator.Error;
const Writer = std.fs.File.Writer;
const WriteError = std.fs.File.WriteError;
const assert = std.debug.assert;

/// FmtIterator is supposed to define an interface that other formatting iterators must conform to.
///
/// Zig does not support interfaces out of the box, so we construct one this way:
/// 1. FmtIterator will be the interface that other structs "conform" to. Whenever we want a type that conforms to this interface, we accept an FmtIterator instead.
/// 2. FmtIterator will expose a set of methods that other structs must implement.
/// 3. FmtIterator will also hold a bunch of pointers to these implementations in a VTable.
///
/// If all three of these pre-requisites are true, consumers of this interface can just call methods on FmtIterator (remember they would get references to FmtIterator).
/// The FmtIterator will then forward these calls to the correct place in memory (because it holds a pointer to where the actual implementation is)
///
/// So how does this work in practice?
/// 1. Say a Struct MyCustomIterator wants to conform to FmtIterator. It will first implement all methods that FmtIterator needs (Look at NoopFmtIterator)
/// 2. Then, it implements one more method that returns FmtIterator. Here, we'll initialize an return an FmtIterator, and where we'll tell FmtIterator where the actual implementation is (Look at NoopFmtIterator.iter())
/// 3. In FmtIterator's `init` method, we erase ...
/// 4. This way, we've "converted" MyCustomIterator into an FmtIterator that can be passed around.
/// 5. Now when someone needs a struct that conforms to FmtIterator, we give it MyCustomIterator.iter() instead (which actually is FmtIterator)
/// 6. When that consumer calls a method on FmtIterator, it in turn calls the respective method on MyCustomIterator, because we saved the implementation's memory location.
/// 7. All of this remains type-safe.
pub const FmtIterator = @This();
const Self = @This();

/// Type erased pointer to the iterator implementation. Type erasure is needed so we can store a pointer to any struct here.
ptr: *anyopaque,
/// Locations of the actual implementations of methods
vtable: *const VTable,

const NextFnError = AllocatorError || WriteError;
/// Generic that constructs the type of the `.next()` method, based on the host's type
fn NextFn(comptime T: type) type {
    return fn (self: T, allocator: Allocator, writer: Writer) NextFnError!?void;
}

const VTable = struct { next: NextFn(*anyopaque) };

pub fn init(pointer: anytype, comptime nextFn: NextFn(@TypeOf(pointer))) Self {
    const Ptr = @TypeOf(pointer);
    const ptr_info = @typeInfo(Ptr);

    assert(ptr_info == .Pointer); // Must be a pointer
    assert(ptr_info.Pointer.size == .One); // Must be a single-item pointer

    const alignment = ptr_info.Pointer.alignment;

    // Construct the VTable using closure values. This is the only place we have actual memory addresses & types of things
    const Tmp = struct {
        const vtable = VTable{ .next = nextImpl };

        fn nextImpl(self: *anyopaque, allocator: Allocator, writer: Writer) !?void {
            return @call(.{}, nextFn, .{ @ptrCast(Ptr, @alignCast(alignment, self)), allocator, writer });
        }
    };

    return .{ .ptr = pointer, .vtable = &Tmp.vtable };
}

// The following functions are what consumers of this interface will call.
// We forward the function call here to the correct memory location of the actual implementation

pub fn next(self: Self, allocator: Allocator, writer: Writer) !?void {
    return self.vtable.next(self.ptr, allocator, writer);
}
