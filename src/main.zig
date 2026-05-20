const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");

const sprite_render = @import("engine/sprite_render.zig");
const glutil = @import("engine/glutil.zig");
const world = @import("world.zig");

fn extract(data: struct { *world.World, std.mem.Allocator }, sprites: *[sprite_render.max_sprites]sprite_render.RendererSprite) !void {
    // TODO add and sort by depth
    var map = try world.WorldFn.extractHashMap(struct { world.Position, world.Sprite }, @src().fn_name, data.@"0", data.@"1");
    defer map.deinit();
    var iter = map.iterator();

    var current_sprite: usize = 0;
    while(iter.next()) |entry| {
        sprites[current_sprite] = sprite_render.RendererSprite{ .pos = entry.value_ptr.@"0".pos, .size = @splat(16), .texture = @intCast(entry.value_ptr.@"1".sprite) };
        current_sprite += 1;
    }

}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

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

    var w: world.World = world.WorldFn.init(gpa);
    defer world.WorldFn.deinit(&w);
    try world.WorldFn.attach_components(&w, world.WorldFn.create_entity(&w), .{
        world.Position {
            .pos = @splat(0),
        },
        world.PositionDerivatives {
            .vel = .{1, 0}
        },
        world.GravityAffected {},
        world.Sprite {
            .sprite = 0
        }
    });
    try world.WorldFn.attach_components(&w, world.WorldFn.create_entity(&w), .{
        world.Position {
            .pos = @splat(0),
        },
        world.PositionDerivatives {
            .vel = .{0, 1}
        },
        world.Sprite {
            .sprite = 0
        }
    });
    
    
    var renderer: sprite_render.SpriteRenderer(struct { *world.World, std.mem.Allocator }, error {OutOfMemory}, extract) = try .init(gpa);
    defer renderer.deinit(gpa);

    const Clock = std.Io.Clock;

    var prev_time = Clock.now(.awake, init.io);
    while (!window.shouldClose()) {
        const curr_time = Clock.now(.awake, init.io);
        const elapsed = prev_time.durationTo(curr_time);
        prev_time = curr_time;
        const dt: f32 = @as(f32, @floatFromInt(elapsed.toMilliseconds())) / 1e3;

        var width: c_int = undefined;
        var height: c_int = undefined;

        glfw.getWindowSize(window, &width, &height);
        gl.viewport(0, 0, width, height);

        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clearColor(0.0, 0.0, 1.0, 1.0);

        try world.WorldFn.tick(&w, gpa, .{.dt = dt });

        try renderer.render(.{&w, gpa}, @intCast(width), @intCast(height));

        window.swapBuffers();
        glfw.pollEvents();
    }
}
