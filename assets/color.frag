#version 410 core

in vec2 uv;

uniform sampler2D u_texture;
uniform vec3 color;

out vec4 fragColor;

void main() {
  fragColor = vec4(color, 1.0);
}
