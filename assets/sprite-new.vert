#version 460 core

struct RendererObjectInfo {
  vec2 pos;
  vec2 size;
  int tex;
};

layout(binding = 0, std430) readonly buffer ssbo0 {
    RendererObjectInfo[] object_infos;
};

uniform float scale;
uniform ivec2 resolution;

in vec2 uvi;
out int tex;
out vec2 uv;
out vec2 screenPos;

void main() {
  uv = uvi;
  vec2 vertex_position = (uvi - vec2(0.5)) * object_infos[gl_InstanceID].size + object_infos[gl_InstanceID].pos;
  gl_Position = vec4(vec2(2.)/resolution * vertex_position - vec2(1.), 0, 1);
  tex = object_infos[gl_InstanceID].tex;
  screenPos = gl_Position.xy / 2.0 + vec2(0.5) * resolution;
  if(object_infos[gl_InstanceID].tex == -1) {
    // offscreen
    gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
  }
}
