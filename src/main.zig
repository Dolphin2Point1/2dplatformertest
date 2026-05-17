const std = @import("std");
const Io = std.Io;
const glfw = @import("zglfw.zig");
const gl = @import("gl");

fn getProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.WindowHint.context_version_major, 4);
    glfw.windowHint(glfw.WindowHint.context_version_minor, 6);

    const window = try glfw.createWindow(600, 600, "test", null, null);
    defer glfw.destroyWindow(window);
    glfw.makeContextCurrent(window);
    try gl.load({}, getProcAddress);

    while(!window.shouldClose()) {
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clearColor(0.0, 0.0, 1.0, 1.0);
        
        window.swapBuffers();
        glfw.pollEvents();
    }
}
