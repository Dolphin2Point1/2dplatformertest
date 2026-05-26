#version 410 core

in vec2 vertex_position;

uniform float verticalScale;
uniform ivec2 resolution;

out vec2 uv;

void main() {
  gl_Position = vec4(vertex_position / vec2(float(resolution.x) / float(resolution.y), 1) / verticalScale * 2 - vec2(1.0, -1.0), 0.0, 1.0);
}

