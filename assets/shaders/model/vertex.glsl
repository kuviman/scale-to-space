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
uniform vec3 u_collision_normal;
uniform float u_collision_penetration;

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
    float relative_to_surface = dot(pos_relative_to_entity, u_collision_normal) + u_player_radius;
    if (false && relative_to_surface < u_collision_penetration) {
        // float scale = length(pos_relative_to_entity);
        // float sin_to_collision = length(cross(pos_relative_to_entity / scale, collision_normal));
        pos_relative_to_entity += u_collision_normal * relative_to_surface;
    }
    vec3 dir = normalize(pos_relative_to_entity);
    float cos_to_normal = dot(dir, u_collision_normal);
    if (cos_to_normal < 0.0) {
        vec3 flat_dir = normalize(dir - u_collision_normal * cos_to_normal);
        pos_relative_to_entity += flat_dir * u_collision_penetration * (-cos_to_normal);
        pos_relative_to_entity -= u_collision_normal * u_collision_penetration * cos_to_normal;
    }
    vec3 translation = (u_model_matrix * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    v_world_pos = pos_relative_to_entity + translation;
    vec4 camera_pos = u_view_matrix * vec4(v_world_pos, 1.0);
    v_camera_pos = camera_pos.xyz;
    gl_Position = u_projection_matrix * camera_pos;
}
