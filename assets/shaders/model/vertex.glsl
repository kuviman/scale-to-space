#define MAX_COLLISIONS 10

attribute vec3 a_pos;
attribute vec2 a_uv;
attribute vec3 a_normal;

varying vec2 v_uv;
varying vec3 v_normal;
varying vec3 v_world_pos;
varying vec3 v_camera_normal;
varying vec3 v_camera_pos;

uniform mat4 u_model_matrix;
uniform mat4 u_view_matrix;
uniform mat4 u_projection_matrix;

uniform float u_player_radius;

struct Collision {
    vec3 normal;
    float penetration;
};

uniform Collision u_collisions[MAX_COLLISIONS];
uniform int u_collisions_len;

uniform float u_animated;
uniform float u_time;

void main() {
    v_uv = a_uv;
    v_uv += vec2(sin(u_time * 2.12), sin(u_time * 1.2345)) * u_animated * 0.1;
    float slope = length(a_normal.xy);
    v_uv += u_animated * u_time * slope * 0.3;
    v_normal = (u_model_matrix * vec4(a_normal, 0.0)).xyz;
    v_camera_normal = (u_view_matrix * vec4(v_normal, 0.0)).xyz;
    vec3 pos_relative_to_entity = (u_model_matrix * vec4(a_pos, 0.0)).xyz;
    vec3 dir = normalize(pos_relative_to_entity);

    float total_squish_weight = 0.0;
    vec3 total_squish = vec3(0.0, 0.0, 0.0);
    for (int i = 0; i < u_collisions_len; i++) {
        Collision collision = u_collisions[i];
        float cos_to_normal = dot(dir, collision.normal);
        if (cos_to_normal < 0.0) {
            vec3 flat_dir = normalize(dir - collision.normal * cos_to_normal);
            vec3 squish =
                flat_dir * collision.penetration * (-cos_to_normal)
                - collision.normal * collision.penetration * cos_to_normal;
            float squish_weight = -collision.penetration * cos_to_normal;
            total_squish += squish * squish_weight;
            total_squish_weight += squish_weight;
        }
    }
    if (total_squish_weight > 0.0) {
        pos_relative_to_entity += total_squish / total_squish_weight;
    }

    vec3 translation = (u_model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    v_world_pos = pos_relative_to_entity + translation;
    vec4 camera_pos = u_view_matrix * vec4(v_world_pos, 1.0);
    v_camera_pos = camera_pos.xyz;
    gl_Position = u_projection_matrix * camera_pos;
}
