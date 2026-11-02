module:

const SoftEntity = newtype {
    .min_spring_k :: Float32,
    .max_spring_k :: Float32,
};

const Config = newtype {
    .min_physics_delta_time :: Float32,
    .time_scale :: Float32,
    .time_scale_power :: Float32,
    .gravity :: Float32,
    .player :: {
        .air_control :: Float32,
        .core :: {
            .radius :: Float32,
        },
        .shell :: {
            .min_radius :: Float32,
            .max_radius :: Float32,
            .soft :: SoftEntity,
            .scale_time :: Float32,
        },
        .max_speed :: Float32,
        .jump_modifier :: Float32,
    },
};
