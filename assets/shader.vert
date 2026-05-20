#version 410 core

in vec2 vertex_position;

uniform float aspectRatio;
uniform float verticalResolution;
uniform vec2 size;
uniform vec2 position;

out vec2 uv;

void main() {
  uv = vertex_position;
  gl_Position = vec4((vertex_position - vec2(0.5) + position) * vec2(1, aspectRatio) / verticalResolution * size, 0.0, 1.0);
}

