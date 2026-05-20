const std = @import("std");

pub const textures = [_]struct { []const u8, []const u8 } {
    .{"crate.png", std.mem.bytesAsSlice(u8, @embedFile("assets/textures/crate.png"))}
};

// @compileLog(@TypeOf(textures))
