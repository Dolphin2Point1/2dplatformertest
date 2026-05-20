const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");

const sprite_render = @import("sprite_render.zig");
const log = @import("logging.zig");
const glutil = @import("glutil.zig");
const ecs = @import("ecs.zig");

fn extract(sprites: *[sprite_render.max_sprites]sprite_render.RendererSprite) void {
    sprites[0].pos = @splat(0);
    sprites[0].size = @splat(32);
    sprites[0].texture = 0;
}

pub fn main(init: std.process.Init) !void {
    try glfw.init();
    defer glfw.terminate();

    glfw.windowHint(glfw.WindowHint.context_version_major, 4);
    glfw.windowHint(glfw.WindowHint.context_version_minor, 6);
    glfw.windowHint(glfw.WindowHint.opengl_forward_compat, true);
    glfw.windowHint(glfw.WindowHint.opengl_profile, glfw.OpenGLProfile.opengl_core_profile);
    
    glfw.windowHint(glfw.WindowHint.opengl_debug_context, true);
    glfw.windowHint(glfw.WindowHint.scale_framebuffer, false);

    const window = try glfw.createWindow(600, 600, "test", null, null);
    defer glfw.destroyWindow(window);
    glfw.makeContextCurrent(window);
   
    try glutil.load();
    glutil.initDebugging();
    
    var renderer: sprite_render.SpriteRenderer(extract) = try .init(init.gpa);
    defer renderer.deinit(init.gpa);

    while (!window.shouldClose()) {
        var width: c_int = undefined;
        var height: c_int = undefined;
        
        glfw.getWindowSize(window, &width, &height);
        gl.viewport(0, 0, width, height);

        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clearColor(0.0, 0.0, 1.0, 1.0);

        renderer.render(@intCast(width), @intCast(height));

        window.swapBuffers();
        glfw.pollEvents();
    }
}

test {
    _ = @import("ecs.zig");
}
