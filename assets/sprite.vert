#version 460 core

struct RendererObjectInfo {
  vec2 pos;
  vec2 size;
  int tex;
};

layout(binding = 0, std430) readonly buffer ssbo0 {
    RendererObjectInfo[] object_infos;
};

uniform float verticalScale;
uniform ivec2 resolution;

in vec2 vertex_position;
out int tex;
out vec2 uv;
out vec2 screenPos;

void main() {
  uv = vertex_position;
  //gl_Position = vec4(vertex_position, 0.0, 1.0);
  gl_Position = vec4((vertex_position - vec2(0.5) + object_infos[gl_InstanceID].pos) * vec2(resolution.x / resolution.y, 1) / verticalScale * object_infos[gl_InstanceID].size, 0.5, 1.0);
  tex = object_infos[gl_InstanceID].tex;
  screenPos = gl_Position.xy / 2.0 + vec2(0.5) * resolution;
  if(object_infos[gl_InstanceID].tex == -1) {
    // offscreen
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
  }
}
