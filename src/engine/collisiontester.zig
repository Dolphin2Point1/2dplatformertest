const std = @import("std");
const glfw = @import("zglfw");
const gl = @import("gl");

const collision2d = @import("collision2D.zig");
const window_util = @import("window.zig");
const glutil = @import("glutil.zig");
const math = @import("math.zig");

pub const Shader = struct {
    pub const vert = .{.name = "sprite.vert", .source = @embedFile("assets/shader.vert")};
    pub const frag = .{.name = "sprite.frag", .source = @embedFile("assets/color.frag")};
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const window = try window_util.create_window();
    defer window_util.destroy_window(window);
   
    try glutil.load(glfw);
    glutil.initDebugging();

    var finalPos: math.f32x2 = @splat(0);
    var sweptPos: math.f32x2 = @splat(0);
    const sweptBoxSize: math.f32x2 = @splat(16);

    var points = boxPoints(sweptPos, sweptBoxSize) ++ boxPoints(finalPos, sweptBoxSize) ** 2 ++ boxPoints(@splat(88), @splat(64)) ++ .{sweptPos, sweptPos};
    var state_dirty = false;
    var sweptBox = boxCollider(sweptPos, sweptBoxSize);
    var sweep: math.f32x2 = .{0, 16};
    const staticBox = boxCollider(@splat(88), @splat(64));

    var t: f32 = 1;
    var normal = collision2d.swept_box_collision_normal(sweptBox, sweep, staticBox);

    var vbo: gl.GLuint = undefined;
    var vao: gl.GLuint = undefined;

    const vs = try glutil.compileShader(gl.VERTEX_SHADER, Shader.vert.source, Shader.vert.name, gpa);
    defer gl.deleteShader(vs);
    const fs = try glutil.compileShader(gl.FRAGMENT_SHADER, Shader.frag.source, Shader.frag.name, gpa);
    defer gl.deleteShader(fs);
    const shader_program = gl.createProgram();
    defer gl.deleteProgram(shader_program);
    gl.attachShader(shader_program, vs);
    gl.attachShader(shader_program, fs);
    gl.linkProgram(shader_program);

    const vertical_scale_loc = gl.getUniformLocation(shader_program, "verticalScale");
    const resolution_loc = gl.getUniformLocation(shader_program, "resolution");
    const color_loc = gl.getUniformLocation(shader_program, "color");

    gl.createBuffers(1, &vbo);
    defer gl.deleteBuffers(1, &vbo);
    gl.namedBufferData(vbo, @sizeOf(@TypeOf(points)), &points, gl.DYNAMIC_DRAW);

    gl.createVertexArrays(1, &vao);
    defer gl.deleteVertexArrays(1, &vao);
    gl.vertexArrayVertexBuffer(vao, 0, vbo, 0, @sizeOf(math.f32x2));
    gl.enableVertexArrayAttrib(vao, 0);
    gl.vertexArrayAttribFormat(vao, 0, 2, gl.FLOAT, gl.FALSE, 0);
    gl.vertexArrayAttribBinding(vao, 0, 0);
    
    const Clock = std.Io.Clock;

    // var prev_ = Clock.now(.awake, init.io);
    while (!window.shouldClose()) {
        // const curr_time = Clock.now(.awake, init.io);
        // const elapsed = prev_time.durationTo(curr_time);
        // prev_time = curr_time;
        // const dt: f32 = @as(f32, @floatFromInt(elapsed.toMilliseconds())) / 1e3;
        var width: c_int = undefined;
        var height: c_int = undefined;

        glfw.getWindowSize(window, &width, &height);

        var mousePos: [2]f64 = @splat(0.0);
        glfw.getCursorPos(window, &mousePos[0], &mousePos[1]);
        const mousePixelPos: math.f32x2 = .{ @floatCast(mousePos[0]), @floatCast(height-mousePos[1]) };

        if(glfw.getMouseButton(window, glfw.MouseButton.left) == glfw.Action.press) {
            sweptPos = math.scale(mousePixelPos, 240.0/@as(f32, @floatFromInt(height)));
            sweep = math.sub(finalPos, sweptPos);
            sweptBox = boxCollider(sweptPos, sweptBoxSize);
            const newPoints = boxPoints(sweptPos, sweptBoxSize);
            @memcpy(points[0..4], &newPoints);
            state_dirty = true;
        }
        if(glfw.getMouseButton(window, glfw.MouseButton.right) == glfw.Action.press) {
            finalPos = math.scale(mousePixelPos, 240.0/@as(f32, @floatFromInt(height)));
            sweep = math.sub(finalPos, sweptPos);
            const newPoints = boxPoints(finalPos, sweptBoxSize);
            @memcpy(points[4..8], &newPoints);
            state_dirty = true;
        }

        if(state_dirty) {
            const start_time = Clock.now(.awake, init.io);
            t = collision2d.find_collision_time(sweptBox, sweep, staticBox, 1e-4, collision2d.swept_box_collision);
            normal = collision2d.swept_box_collision_normal(sweptBox, sweep, staticBox);
            const end_time = Clock.now(.awake, init.io);
            std.log.debug("Time: {d}ns\n", .{start_time.durationTo(end_time).toNanoseconds()});
        }
        state_dirty = false;
        const newPoints = boxPoints(math.add(sweptPos, math.scale(sweep, t)), sweptBoxSize);
        @memcpy(points[8..12], &newPoints);

        points[16] = math.add(sweptPos, math.scale(sweptBoxSize, 0.5)); 
        points[17] = math.add(points[16], math.scale(normal, 10));
        
        gl.namedBufferData(vbo, @sizeOf(@TypeOf(points)), &points, gl.DYNAMIC_DRAW);
        gl.viewport(0, 0, width, height);

        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.clearColor(0.0, 0.0, 0.0, 1.0);

        gl.bindVertexArray(vao);
        gl.useProgram(shader_program);
        gl.uniform1f(vertical_scale_loc, 240.0);
        gl.uniform2i(resolution_loc, @intCast(width), @intCast(height));

        gl.uniform3f(color_loc, 0.2, 0.2, 1.0);
        gl.drawArrays(gl.LINE_LOOP, 0, 4);
        gl.uniform3f(color_loc, 1.0, 0.2, 0.2);
        gl.drawArrays(gl.LINE_LOOP, 4, 4);
        gl.uniform3f(color_loc, 0.2, 1.0, 0.2);
        gl.drawArrays(gl.LINE_LOOP, 8, 4);
        gl.uniform3f(color_loc, 0.5, 0.5, 0.5);
        gl.drawArrays(gl.LINE_LOOP, 12, 4);
        gl.uniform3f(color_loc, 1, 0.75, 0);
        gl.drawArrays(gl.LINE_LOOP, 16, 2);

        window.swapBuffers();
        glfw.pollEvents();
    }
}

fn boxPoints(pos: math.f32x2, size: math.f32x2) [4]math.f32x2 {
    var output = [_]math.f32x2{ .{0, 0}, .{1, 0}, .{1, 1}, .{0, 1} };
    for(0..output.len) |i| {
        output[i] = math.add(pos, math.mul(output[i], size));
    }
    return output;
}

fn boxCollider(pos: math.f32x2, size: math.f32x2) collision2d.Box {
    return collision2d.Box { .lessPos = pos, .greaterPos = math.add(pos, size) };
}
