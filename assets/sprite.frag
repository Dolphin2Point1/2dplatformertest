#version 460 core

#extension GL_ARB_bindless_texture : require

layout(binding = 1, std430) readonly buffer ssbo1 {
    sampler2D textures[];
};

flat in int tex;
in vec2 uv;
in vec2 screenPos;

out vec4 fragColor;

void main() {
  // box filter in texel units
  vec2 boxSize = clamp(fwidth(uv) * textureSize(textures[tex], 0), 1e-5, 1);
  // scale uv by texture size to get texture coordinate
  vec2 tx = uv * textureSize(textures[tex], 0) - 0.5 * boxSize;
  // compute offset for pixel-sized box filter
  vec2 txOffset = smoothstep(1 - boxSize, vec2(1), fract(tx));
  // compute billinear sample coordinate
  vec2 sampleUV = (floor(tx) + 0.5 + txOffset) / textureSize(textures[tex], 0);

  fragColor = texture(textures[tex], sampleUV * vec2(1.0, -1.0));
}
