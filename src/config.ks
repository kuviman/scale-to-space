module:

const SoftEntity = newtype {
    .min_spring_k :: Float32,
    .max_spring_k :: Float32,
};

const Config = newtype {
    .time_scale :: Float32,
    .gravity :: Float32,
    .player :: {
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

