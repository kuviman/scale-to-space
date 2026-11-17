#define inverse geng_inverse
mat4 inverse(mat4 m) {
  float
      a00 = m[0][0], a01 = m[0][1], a02 = m[0][2], a03 = m[0][3],
      a10 = m[1][0], a11 = m[1][1], a12 = m[1][2], a13 = m[1][3],
      a20 = m[2][0], a21 = m[2][1], a22 = m[2][2], a23 = m[2][3],
      a30 = m[3][0], a31 = m[3][1], a32 = m[3][2], a33 = m[3][3],

      b00 = a00 * a11 - a01 * a10,
      b01 = a00 * a12 - a02 * a10,
      b02 = a00 * a13 - a03 * a10,
      b03 = a01 * a12 - a02 * a11,
      b04 = a01 * a13 - a03 * a11,
      b05 = a02 * a13 - a03 * a12,
      b06 = a20 * a31 - a21 * a30,
      b07 = a20 * a32 - a22 * a30,
      b08 = a20 * a33 - a23 * a30,
      b09 = a21 * a32 - a22 * a31,
      b10 = a21 * a33 - a23 * a31,
      b11 = a22 * a33 - a23 * a32,

      det = b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;

  return mat4(
      a11 * b11 - a12 * b10 + a13 * b09,
      a02 * b10 - a01 * b11 - a03 * b09,
      a31 * b05 - a32 * b04 + a33 * b03,
      a22 * b04 - a21 * b05 - a23 * b03,
      a12 * b08 - a10 * b11 - a13 * b07,
      a00 * b11 - a02 * b08 + a03 * b07,
      a32 * b02 - a30 * b05 - a33 * b01,
      a20 * b05 - a22 * b02 + a23 * b01,
      a10 * b10 - a11 * b08 + a13 * b06,
      a01 * b08 - a00 * b10 - a03 * b06,
      a30 * b04 - a31 * b02 + a33 * b00,
      a21 * b02 - a20 * b04 - a23 * b00,
      a11 * b07 - a10 * b09 - a12 * b06,
      a00 * b09 - a01 * b07 + a02 * b06,
      a31 * b01 - a30 * b03 - a32 * b00,
      a20 * b03 - a21 * b01 + a22 * b00) / det;
}

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

uniform sampler2D u_depth_texture;
uniform sampler2D u_normal_texture;
uniform vec2 u_framebuffer_size;

uniform vec3 u_player_pos;
uniform float u_player_radius;

uniform vec3 u_volleyball_pos;
uniform float u_volleyball_radius;

vec3 lerp(vec3 a, vec3 b, float t) {
    return a * (1.0 - t) + b * t;
}
vec4 lerp(vec4 a, vec4 b, float t) {
    return a * (1.0 - t) + b * t;
}

uniform mat4 u_projection_matrix;
mat4 inv_projection_matrix;

// (x, y, z, 1) = inv_projection_matrix * (xx, yy, zz, w)

// #define MAX_DEPTH 256.0
float depth_at(vec2 screen_pos) {
    float d = unpack4(texture2D(u_depth_texture, screen_pos / u_framebuffer_size));
    vec3 v = vec3(screen_pos / u_framebuffer_size, d) * 2.0 - 1.0;
    vec4 r = inv_projection_matrix * vec4(v, 1.0);
    return -r.z / r.w;
}

vec3 normal_at(vec2 screen_pos) {
    return texture2D(u_normal_texture, screen_pos / u_framebuffer_size).xyz * 2.0 - 1.0;
}

float sqr(float x) { return x * x; }

void main() {
    inv_projection_matrix = inverse(u_projection_matrix);
    vec3 light_dir = normalize(vec3(2.0, 6.0, 7.0));
    float light_k = max(dot(light_dir, normalize(v_normal)), 0.0);
    float ambient_light = 0.8;
    light_k = ambient_light + light_k * (1.0 - ambient_light);
    float hightlight = 0.0;
    float shadow_d = length(u_volleyball_pos.xy - v_world_pos.xy);
    if (u_volleyball_pos.z > v_world_pos.z && shadow_d < u_volleyball_radius && v_normal.z > 0.05) {
        light_k -= 0.1;
    }
    if (u_player_radius > 0.1) {
        shadow_d = length(u_player_pos.xy - v_world_pos.xy);
        if (u_player_pos.z > v_world_pos.z && shadow_d < u_player_radius) {
            light_k -= 0.3;
        }
        float d = length(cross(v_normal, u_player_pos - v_world_pos));
        float hightlight_radius = 1.0;
        if (d < hightlight_radius && d > hightlight_radius - 0.1) {
            hightlight = 0.1;
        }
        if (length(u_player_pos - v_world_pos) > 2.0) {
            hightlight = 0.0;
        }
    }
    vec4 light_color = vec4(vec3(light_k), 1.0);
    gl_FragColor = texture2D(u_base_color_texture, v_uv) * u_base_color_factor * light_color;
    gl_FragColor = lerp(gl_FragColor, vec4(1.0), hightlight);
    if (true) {
        // normal-based outline
        vec2 screen_pos = gl_FragCoord.xy;
        float depth = depth_at(screen_pos);
        vec3 normal = normal_at(screen_pos);
        float normal_diff = -1.0;
        float total_weight = 0.0;
#define OUTLINE_PIXELS 2
        for (int i = -OUTLINE_PIXELS; i <= OUTLINE_PIXELS; i++) {
            for (int j = -OUTLINE_PIXELS; j <= OUTLINE_PIXELS; j++) {
                total_weight += max(0.0, float(OUTLINE_PIXELS) - length(vec2(float(i), float(j))));
                vec2 pixel_offset = vec2(float(i), float(j));
                vec2 pixel = screen_pos + pixel_offset;
                // if (depth_at(pixel) > depth) {
                    // normal_diff += length(normal_at(pi0.0xel) - normal);
                    float depth_diff_here = depth_at(pixel) - depth;
                    normal_diff = max(normal_diff, length(normal_at(pixel) - normal));
                // }
            }
        }
#undef OUTLINE_PIXELS
        // normal_diff /= total_weight;
        float outline = smoothstep(0.0, 1.0, normal_diff);
        outline *= 0.05 * smoothstep(-50.0, -10.0, -depth);
        gl_FragColor.xyz = lerp(gl_FragColor.xyz, vec3(0.0), outline);
        // gl_FragColor.xyz = vec3(normal_at(screen_pos));
    }
    if (true) {
        // depth-based outline
        vec2 screen_pos = gl_FragCoord.xy;
        float depth = depth_at(screen_pos);
        // float max_depth_diff = 0.0;
        float total_depth_diff = 0.0;
        float total_weight = 0.0;
        float max_diff = 0.05 * pow(depth, 1.0);
        // a*depth^b
#define OUTLINE_PIXELS 5
        for (int i = -OUTLINE_PIXELS; i <= OUTLINE_PIXELS; i++) {
            for (int j = -OUTLINE_PIXELS; j <= OUTLINE_PIXELS; j++) {
                if (i == 0 && j == 0) continue;
                vec2 pixel_offset = vec2(float(i), float(j));
                vec2 pixel = screen_pos + pixel_offset;
                float depth_diff = (depth_at(pixel) - depth) / length(pixel_offset) / max_diff;
                float k = 0.5;
                depth_diff = clamp(depth_diff / k, -1.0, 1.0) * k;
                // max_depth_diff = max(max_depth_diff, depth_diff);
                float weight = 1.0 / length(pixel_offset);
                total_depth_diff += depth_diff * weight;
                total_weight += weight;
            }
        }
#undef OUTLINE_PIXELS
        float avg_depth_diff = total_depth_diff / total_weight;
        float outline = smoothstep(0.05, 0.1, avg_depth_diff);
        // float outline = smoothstep(0.2, 0.5, 100.0 * avg_depth_diff / pow(depth, 1.5));
        // float outline = smoothstep(0.0, 0.01, depth_diff);
        gl_FragColor.xyz *= 1.0 - outline;
        float x = unpack4(texture2D(u_depth_texture, screen_pos / u_framebuffer_size));
        // gl_FragColor.xyz = vec3(x);
        // gl_FragColor.xyz = vec3(outline);
        // gl_FragColor.xyz = vec3(-depth / 100.0);
    }
    if (true) {
        // fog
        gl_FragColor = lerp(
            gl_FragColor,
            vec4(0.8, 0.8, 1.0, 1.0),
            1.0 - pow(0.9, -v_camera_pos.z / 50.0)
        );
    }
    gl_FragColor.a *= 0.5;
    if (gl_FragColor.a < 0.1) {
        discard;
    }
    // float verticality = 0.9;
    // float K = 0.1 * max(v_camera_normal.z - verticality, 0.0) / (1.0 - verticality);
    // K = step(cross(normalize(v_camera_normal), normalize(v_camera_pos)).y, 0) * 0.5;
    // gl_FragColor.xyz *= 1.0 - K;
    // gl_FragColor.xyz = v_camera_normal * 0.5 + 0.5;
    // float k = 1.0 - K + sin(v_world_pos.z * 10.0) * K;
    // gl_FragColor.xyz *= k;
}
