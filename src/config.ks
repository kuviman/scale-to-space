const collisions = import "./collisions.ks";

module:

const Config = newtype {
    .min_physics_delta_time :: Float32,
    .time_scale :: Float32,
    .gravity :: Float32,
    .player :: {
        .core :: {
            .radius :: Float32,
        },
        .shell :: {
            .min_radius :: Float32,
            .max_radius :: Float32,
            .soft :: collisions.SoftEntity,
            .scale_time :: Float32,
        },
        .max_speed :: Float32,
        .jump_modifier :: Float32,
    },
};
