const std = @import("std");
const gl = @import("gl");
const zigimg = @import("zigimg");

const glutil = @import("glutil.zig");
const mth = @import("math.zig");
const assets = @import("assets.zig");

const log = std.log.scoped(.SpriteRenderer);

pub const RendererSprite = struct { pos: mth.f32x2 = undefined, size: mth.f32x2 = undefined, texture: i32 = -1 };
pub const max_sprites = 256;

pub fn SpriteRenderer(comptime extract: fn (*[max_sprites]RendererSprite) void) type {
    return struct {
        ssbo: gl.GLuint = undefined,
        vbo: gl.GLuint = undefined,
        vao: gl.GLuint = undefined,
        shader_program: gl.GLuint = undefined,
        texture_buffer: gl.GLuint = undefined,
        vertical_scale_loc: gl.GLint = undefined,
        resolution_loc: gl.GLint = undefined,

        textures: std.ArrayList(gl.GLuint) = undefined,
        texture_handles: std.ArrayList(gl.GLuint64) = undefined,

        object_data: [max_sprites]RendererSprite = @splat(.{}),

        const Self = @This();

        pub fn init(alloc: std.mem.Allocator) !Self {
            var r: Self = .{};

            gl.createBuffers(1, &r.ssbo);
            errdefer gl.deleteBuffers(1, &r.ssbo);
            gl.namedBufferData(r.ssbo, @sizeOf(@TypeOf(r.object_data)), &r.object_data, gl.DYNAMIC_DRAW);

            const points = [_]mth.f32x2{ .{ 0.0, 0.0 }, .{ 0.0, 1.0 }, .{ 1.0, 0.0 }, .{ 1.0, 1.0 } };

            gl.createBuffers(1, &r.vbo);
            errdefer gl.deleteBuffers(1, &r.vbo);
            gl.namedBufferStorage(r.vbo, @sizeOf(@TypeOf(points)), &points, 0);

            gl.createVertexArrays(1, &r.vao);
            errdefer gl.deleteVertexArrays(1, &r.vao);
            gl.vertexArrayVertexBuffer(r.vao, 0, r.vbo, 0, @sizeOf(mth.f32x2));
            gl.enableVertexArrayAttrib(r.vao, 0);
            gl.vertexArrayAttribFormat(r.vao, 0, 2, gl.FLOAT, gl.FALSE, 0);
            gl.vertexArrayAttribBinding(r.vao, 0, 0);

            r.textures = try .initCapacity(alloc, assets.textures.len);
            errdefer {
                for (r.textures.items) |texture| {
                    gl.deleteTextures(1, &texture);
                }
                r.textures.deinit(alloc);
            }
            r.texture_handles = try .initCapacity(alloc, assets.textures.len);
            errdefer r.texture_handles.deinit(alloc);
            for (assets.textures) |image_bytes| {
                log.info("Loading texture {s}...", .{image_bytes.@"0"});

                var image = try zigimg.Image.fromMemory(alloc, image_bytes.@"1");
                defer image.deinit(alloc);

                var texture: gl.GLuint = undefined;

                gl.createTextures(gl.TEXTURE_2D, 1, &texture);
                gl.textureStorage2D(texture, 1, gl.RGBA8, @intCast(image.width), @intCast(image.height));
                gl.textureSubImage2D(texture, 0, 0, 0, @intCast(image.width), @intCast(image.height), gl.RGBA, gl.UNSIGNED_BYTE, image.rawBytes().ptr);

                const handle = gl.GL_ARB_bindless_texture.getTextureHandleARB(texture);
                gl.GL_ARB_bindless_texture.makeTextureHandleResidentARB(handle);

                r.textures.appendAssumeCapacity(texture);
                r.texture_handles.appendAssumeCapacity(handle);
            }

            gl.createBuffers(1, &r.texture_buffer);
            errdefer gl.deleteBuffers(1, r.texture_buffer);
            gl.namedBufferStorage(r.texture_buffer, @intCast(assets.textures.len * @sizeOf(gl.GLuint64)), r.texture_handles.items.ptr, gl.DYNAMIC_STORAGE_BIT);

            const vs = try glutil.compileShader(gl.VERTEX_SHADER, assets.SpriteShader.vert.@"1", assets.SpriteShader.vert.@"0", alloc);
            defer gl.deleteShader(vs);
            const fs = try glutil.compileShader(gl.FRAGMENT_SHADER, assets.SpriteShader.frag.@"1", assets.SpriteShader.frag.@"0", alloc);
            defer gl.deleteShader(fs);
            r.shader_program = gl.createProgram();
            errdefer gl.deleteProgram(r.shader_program);
            gl.attachShader(r.shader_program, vs);
            gl.attachShader(r.shader_program, fs);
            gl.linkProgram(r.shader_program);
            gl.detachShader(r.shader_program, vs);
            gl.detachShader(r.shader_program, fs);

            r.vertical_scale_loc = gl.getUniformLocation(r.shader_program, "verticalScale");
            r.resolution_loc = gl.getUniformLocation(r.shader_program, "resolution");

            return r;
        }

        pub fn render(self: *Self, width: u32, height: u32) void {
            extract(&self.object_data);

            gl.namedBufferData(self.ssbo, @sizeOf(@TypeOf(self.object_data)), &self.object_data, gl.DYNAMIC_DRAW);

            gl.bindVertexArray(self.vao);
            gl.useProgram(self.shader_program);
            gl.uniform1f(self.vertical_scale_loc, 240.0);
            gl.uniform2i(self.resolution_loc, @intCast(width), @intCast(height));

            gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 0, self.ssbo);
            gl.bindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, self.texture_buffer);

            gl.drawArraysInstanced(gl.TRIANGLE_STRIP, 0, 4, max_sprites);
        }

        pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
            gl.deleteProgram(self.shader_program);

            gl.deleteBuffers(1, &self.texture_buffer);

            self.texture_handles.deinit(alloc);
            for (self.textures.items) |texture| {
                gl.deleteTextures(1, &texture);
            }
            self.textures.deinit(alloc);

            gl.deleteVertexArrays(1, &self.vao);
            gl.deleteBuffers(1, &self.vbo);
            gl.deleteBuffers(1, &self.ssbo);
        }
    };
}
