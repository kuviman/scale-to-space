const float PACK_UPSCALE = 256.0 / 255.0; // fraction -> 0..1 (including 1)
const float UNPACK_DOWNSCALE = 255.0 / 256.0; // 0..1 -> fraction (excluding 1)

const vec3 PACK_FACTORS = vec3(256.0 * 256.0 * 256.0, 256.0 * 256.0, 256.0);
const vec4 UNPACK_FACTORS = UNPACK_DOWNSCALE / vec4(PACK_FACTORS, 1.0);

const float SHIFT_RIGHT_8 = 1.0 / 256.0;

float unpack4(vec4 v) {
    return v.x;
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
uniform vec2 u_framebuffer_size;

uniform vec3 u_player_pos;
uniform float u_player_radius;

uniform vec3 u_volleyball_pos;
uniform float u_volleyball_radius;

vec4 lerp(vec4 a, vec4 b, float t) {
    return a * (1.0 - t) + b * t;
}

float depth_at(vec2 screen_pos) {
    return unpack4(texture2D(u_depth_texture, screen_pos / u_framebuffer_size)) * 256.0;
}

#define OUTLINE_DEPTH_DIFF 1.5

void main() {
    vec2 screen_pos = gl_FragCoord.xy;
    float depth = depth_at(screen_pos);
    if (abs(depth_at(screen_pos + vec2(5.0, 0.0)) - depth) > OUTLINE_DEPTH_DIFF) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    };
    if (abs(depth_at(screen_pos + vec2(-5.0, 0.0)) - depth) > OUTLINE_DEPTH_DIFF) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    };
    if (abs(depth_at(screen_pos + vec2(0.0, -5.0)) - depth) > OUTLINE_DEPTH_DIFF) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    };
    if (abs(depth_at(screen_pos + vec2(0.0, 5.0)) - depth) > OUTLINE_DEPTH_DIFF) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    };
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
        // fog
        gl_FragColor = lerp(
            gl_FragColor,
            vec4(0.8, 0.8, 1.0, 1.0),
            1.0 - pow(0.9, -v_camera_pos.z / 50.0)
        );
    }
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
