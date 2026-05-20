const std = @import("std");
const gl = @import("gl");
const builtin = @import("builtin");
const glfw = @import("zglfw");

const log = @import("logging.zig");

pub fn compileShader(shader_type: gl.GLenum, source: [*:0]const u8, name: []const u8, alloc: std.mem.Allocator) !gl.GLuint {
    log.gl.info("Compiling shader {s}...", .{name});

    const shader = gl.createShader(shader_type);
    errdefer gl.deleteShader(shader);
    gl.shaderSource(shader, 1, &source, null);
    gl.compileShader(shader);
    var result: gl.GLint = undefined;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, &result);

    if(result != gl.TRUE) {
        gl.getShaderiv(shader, gl.INFO_LOG_LENGTH, &result);

        const str = try alloc.allocSentinel(u8, @intCast(result), 0);
        gl.getShaderInfoLog(shader, result, null, str);
        log.gl.err("Could not compile shader {s}: \n{s}\n", .{ name, str });
        alloc.free(str);
        return error.CannotCompileShader;
    }

    return shader;
}

pub fn load() !void {
    try gl.load({}, getProcAddress);
    try gl.GL_ARB_bindless_texture.load({}, getProcAddress);
}

pub fn initDebugging() void {
    if(builtin.mode != .Debug) {
        return;
    }
    
    var gl_flags: gl.GLint = undefined;
    gl.getIntegerv(gl.CONTEXT_FLAGS, &gl_flags);
    log.gl.info("flags: {}", .{gl_flags});
    if((gl_flags & gl.CONTEXT_FLAG_DEBUG_BIT) != 0) {
        log.gl.info("Enabling errors!", .{});
        gl.enable(gl.DEBUG_OUTPUT);
        gl.enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
        gl.debugMessageCallback(gl_error, null);
        gl.debugMessageControl(gl.DONT_CARE, gl.DONT_CARE, gl.DONT_CARE, 0, null, gl.TRUE);
    }
}

fn getProcAddress(_: void, name: [:0]const u8) ?*const anyopaque {
    return glfw.getProcAddress(name);
}

fn gl_error(source: gl.GLenum, err_type: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: [*:0]const gl.GLchar, userParam: ?*anyopaque) callconv(.c) void {
    _ = source;
    _ = err_type;
    _ = id;
    _ = length;
    _ = userParam;

    const s = switch(severity) {
        gl.DEBUG_SEVERITY_NOTIFICATION => "NOTIFICATION",
        gl.DEBUG_SEVERITY_LOW => "LOW",
        gl.DEBUG_SEVERITY_MEDIUM => "MEDIUM",
        gl.DEBUG_SEVERITY_HIGH => "HIGH",
        else => "UNKNOWN"
    };
    
    switch(severity) {
        gl.DEBUG_SEVERITY_NOTIFICATION => log.gl.info("{s} - {s}", .{s, message}),
        gl.DEBUG_SEVERITY_LOW, gl.DEBUG_SEVERITY_MEDIUM => log.gl.warn("{s} - {s}", .{s, message}),
        gl.DEBUG_SEVERITY_HIGH => log.gl.err("{s} - {s}", .{s, message}),
        else => log.gl.info("{s} - {s}", .{s, message})
    }
}
