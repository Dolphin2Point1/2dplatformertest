const std = @import("std");

pub const textures = [_]struct { []const u8, []const u8 } {
    .{"crate.png", std.mem.bytesAsSlice(u8, @embedFile("assets/textures/crate.png"))}
};

pub const SpriteShader = struct {
    pub const vert = .{"sprite.vert", @embedFile("assets/sprite.vert")};
    pub const frag = .{"sprite.frag", @embedFile("assets/sprite.frag")};
};

// @compileLog(@TypeOf(textures))
