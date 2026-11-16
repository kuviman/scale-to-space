const float PACK_UPSCALE = 256.0 / 255.0; // fraction -> 0..1 (including 1)
const float UNPACK_DOWNSCALE = 255.0 / 256.0; // 0..1 -> fraction (excluding 1)

const vec3 PACK_FACTORS = vec3(256.0 * 256.0 * 256.0, 256.0 * 256.0, 256.0);
const vec4 UNPACK_FACTORS = UNPACK_DOWNSCALE / vec4(PACK_FACTORS, 1.0);

const float SHIFT_RIGHT_8 = 1.0 / 256.0;

float unpack4(vec4 v) {
    return dot(v, UNPACK_FACTORS);
}

vec4 pack4(float value) {
    float v = clamp(value, 0.0, 1.0);
    vec4 r = vec4(fract(v * PACK_FACTORS), v);
    r.yzw -= r.xyz * SHIFT_RIGHT_8;
    return r * PACK_UPSCALE;
}
// ----
varying vec2 v_uv;
varying vec3 v_normal;
varying vec3 v_camera_normal;
varying vec3 v_world_pos;
varying vec3 v_camera_pos;

uniform vec4 u_base_color_factor;
uniform sampler2D u_base_color_texture;

uniform vec3 u_player_pos;
uniform float u_player_radius;

uniform vec3 u_volleyball_pos;
uniform float u_volleyball_radius;

vec4 lerp(vec4 a, vec4 b, float t) {
    return a * (1.0 - t) + b * t;
}

#define MAX_DEPTH 256.0
void main() {
    // gl_FragColor = pack4(-v_camera_pos.z / MAX_DEPTH);
    gl_FragColor = pack4(gl_FragCoord.z);
}
