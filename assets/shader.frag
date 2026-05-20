#version 410 core

in vec2 uv;

uniform sampler2D u_texture;

out vec4 fragColor;

void main() {
  fragColor = vec4(0.0, 0.0, 0.0, 1.0);
//  fragColor = texture2D(u_texture, uv * vec2(1.0, -1.0));
}
