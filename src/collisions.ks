use (import "./__deps__.ks").*;

module:

const APPROX_ZERO :: Float32 = 0.0001;

const Collision = newtype {
    .penetration :: Float32,
    .normal :: Vec3,
    .point :: Vec3,
};

const Entity = newtype {
    .position :: Vec3,
    .radius :: Float32,
};

const Face = newtype {
    .vs :: { Vec3, Vec3, Vec3 },
    .normal :: Vec3,
};

const Face_get_v = (face :: &Face, i :: Int32) -> Vec3 => (
    if i == 0 then (
        face^.vs.0
    ) else if i == 1 then (
        face^.vs.1
    ) else if i == 2 then (
        face^.vs.2
    ) else panic("aaaaah")
);

const ChunkCoord = newtype { Int32, Int32, Int32 };

impl ChunkCoord as std.cmp.Ord = {
    .compare = (&a, &b) => with_return (
        match std.cmp.default_compare(&a.0, &b.0) with (
            | :Equal => ()
            | other => return other
        );
        match std.cmp.default_compare(&a.1, &b.1) with (
            | :Equal => ()
            | other => return other
        );
        match std.cmp.default_compare(&a.2, &b.2) with (
            | :Equal => ()
            | other => return other
        );
        :Equal
    ),
};

const Chunk = newtype {
    .faces :: ArrayList.t[Face],
};

const CHUNK_SIZE :: Float32 = 10;

impl Chunk as module = (
    module:

    const new = () -> Chunk => {
        .faces = ArrayList.new(),
    };
);

const Mesh = newtype {
    .faces :: ArrayList.t[Face],
    .chunks :: OrdMap.t[ChunkCoord, Chunk],
};

const chunk_box = (from :: ChunkCoord, to :: ChunkCoord) -> std.iter.Iterable[ChunkCoord] => {
    .iter = @move consumer => (
        for x in from.0..to.0 do (
            for y in from.1..to.1 do (
                for z in from.2..to.2 do (
                    consumer({ x, y, z });
                );
            );
        );
    ),
};

impl Mesh as module = (
    module:

    const new = (faces :: ArrayList.t[Face]) -> Mesh => (
        let mut chunks = OrdMap.new();
        let mut i = 0;
        for &face in &faces |> ArrayList.iter do (
            if i % 1000 == 0 then yield();
            i += 1;
            let from = {
                math.floor(min(min(face.vs.0.0, face.vs.1.0), face.vs.2.0) / CHUNK_SIZE),
                math.floor(min(min(face.vs.0.1, face.vs.1.1), face.vs.2.1) / CHUNK_SIZE),
                math.floor(min(min(face.vs.0.2, face.vs.1.2), face.vs.2.2) / CHUNK_SIZE),
            };
            let to = {
                math.ceil(max(max(face.vs.0.0, face.vs.1.0), face.vs.2.0) / CHUNK_SIZE),
                math.ceil(max(max(face.vs.0.1, face.vs.1.1), face.vs.2.1) / CHUNK_SIZE),
                math.ceil(max(max(face.vs.0.2, face.vs.1.2), face.vs.2.2) / CHUNK_SIZE),
            };
            for co in chunk_box(from, to) do (
                let chunk_center = Vec3.mul({
                    Int32_to_Float32(co.0) + 0.5,
                    Int32_to_Float32(co.1) + 0.5,
                    Int32_to_Float32(co.2) + 0.5,
                }, CHUNK_SIZE);
                if distance_to_face(chunk_center, &face).distance |> abs < CHUNK_SIZE then (
                    let chunk = &mut chunks |> OrdMap.get_or_init(co, Chunk.new);
                    &mut chunk^.faces |> ArrayList.push_back(face);
                );
            );
        );
        { .faces, .chunks }
    );
);

const update = (result :: &mut Collision, collision :: Collision) => (
    if collision.penetration > result^.penetration then (
        result^ = collision;
    );
);

const distance_to_face = (
    point :: Vec3,
    face :: &Face,
) -> { .normal :: Vec3, .distance :: Float32 } => (
    let mut result = :None;
    let update = (.normal, .distance) => (
        let better = match result with (
            | :None => true
            | :Some result => distance < result.distance
        );
        if better then (
            result = :Some { .normal, .distance };
        );
    );
    for i in 0..3 do (
        let face_p = Face_get_v(face, i);
        let dv = Vec3.sub(point, face_p);
        let distance = Vec3.length(dv);
        update(.distance, .normal = Vec3.normalize_or_zero(dv));
    );
    for i in 0..3 do (
        let a = face |> Face_get_v(i);
        let b = face |> Face_get_v((i + 1) % 3);
        if Vec3.dot(Vec3.sub(b, a), Vec3.sub(point, a)) <= 0 then (
            continue;
        );
        if Vec3.dot(Vec3.sub(a, b), Vec3.sub(point, b)) <= 0 then (
            continue;
        );
        let v = Vec3.normalize(Vec3.sub(b, a));
        let t = Vec3.dot(Vec3.sub(point, a), v);
        let closest_point = Vec3.add(a, Vec3.mul(v, t));
        let delta = Vec3.sub(point, closest_point);
        update(.distance = Vec3.length(delta), .normal = Vec3.normalize_or_zero(delta))
    );
    let distance = Vec3.dot(Vec3.sub(point, face^.vs.0), face^.normal);
    let closest_point = Vec3.sub(point, Vec3.mul(face^.normal, distance));
    with_return (
        for i in 0..3 do (
            let a = face |> Face_get_v(i);
            let b = face |> Face_get_v((i + 1) % 3);
            if Vec3.dot(Vec3.cross(face^.normal, Vec3.sub(b, a)), Vec3.sub(closest_point, a)) < 0 then (
                return;
            );
        );
        update(.distance, .normal = face^.normal);
    );
    result |> Option.unwrap
);

const collide_face = (result :: &mut Collision, entity :: Entity, face :: &Face) => (
    let { .normal, .distance } = distance_to_face(entity.position, face);
    if 0 < distance and distance < entity.radius then (
        let penetration = entity.radius - distance;
        let point = Vec3.sub(entity.position, Vec3.mul(normal, distance));
        update(result, { .penetration, .normal, .point });
    );
);

const collide = (entity :: Entity, mesh :: &Mesh) -> Option.t[Collision] => with_return (
    let mut result :: Collision = {
        .penetration = -1,
        .normal = { 0, 0, 0 },
        .point = { 0, 0, 0 },
    };
    let from = {
        math.floor((entity.position.0 - entity.radius) / CHUNK_SIZE),
        math.floor((entity.position.1 - entity.radius) / CHUNK_SIZE),
        math.floor((entity.position.2 - entity.radius) / CHUNK_SIZE),
    };
    let to = {
        math.ceil((entity.position.0 + entity.radius) / CHUNK_SIZE),
        math.ceil((entity.position.1 + entity.radius) / CHUNK_SIZE),
        math.ceil((entity.position.2 + entity.radius) / CHUNK_SIZE),
    };
    for co in chunk_box(from, to) do (
        if &mesh^.chunks |> OrdMap.get(&co) is :Some chunk then (
            for face in &chunk^.faces |> ArrayList.iter do (
                collide_face(&mut result, entity, face);
            );
        );
    );
    if result.penetration <= 0 then (
        :None
    ) else (
        :Some result
    )
);

const MeshProperties = newtype {
    .bounciness :: Float32,
    .friction :: Float32,
    .animated :: Bool,
    .particles :: Int32,
    .particle_t :: Float32,
    .particle_spread :: Float32,
};

const CollisionResult = newtype {
    .velocity_along_normal :: Float32,
    .normal :: Vec3,
    .penetration :: Float32,
    .point :: Vec3,
};

const Entity = newtype {
    .position :: &mut Vec3,
    .velocity :: &mut Vec3,
    .acceleration :: &mut Vec3,
    .angular_velocity :: &mut Vec3,
    .radius_change_speed :: Float32,
    .jump_modifier :: Float32,
    .radius :: Float32,
    .inverse_mass :: Float32,
    .soft :: Option.t[SoftEntity],
};

const SoftEntity = newtype {
    .spring_k :: Float32,
    .min_penetration_for_jump :: Float32,
};

const JumpGraph = newtype {
    .amplitude :: Float32,
    .w :: Float32,
    .time_offset :: Float32,
    .bounciness :: Float32,
    .rest :: Float32,
};

impl JumpGraph as module = (
    module:
    const at = (
        self :: JumpGraph,
        t :: Float32,
    ) -> Float32 => (
        self.amplitude * math.cos(self.w * t + self.time_offset) * math.pow(self.bounciness, self.w / PI * t) + self.rest
    );
    const derivative_at = (
        self :: JumpGraph,
        t :: Float32,
    ) -> Float32 => (
        -self.amplitude * self.w * math.sin(self.w * t + self.time_offset) * math.pow(self.bounciness, self.w / PI * t)
        + self.amplitude * math.cos(self.w * t + self.time_offset) * self.w / PI * math.pow(self.bounciness, self.w / PI * t) * math.log(self.bounciness)
    );
);

const do_react_entities = (
    a :: Entity,
    b :: Entity,
    collision :: Collision,
    .properties :: &MeshProperties,
    .friction_into_linear :: Float32,
    .delta_time :: Float32,
) -> CollisionResult => (
    # TODO
    let jump_modifier = a.jump_modifier;
    let bounciness = properties^.bounciness;
    let ka = a.inverse_mass / (a.inverse_mass + b.inverse_mass);
    let kb = -b.inverse_mass / (a.inverse_mass + b.inverse_mass);
    let relative_velocity = () => Vec3.sub(a.velocity^, b.velocity^);
    let radius_change_speed = a.radius_change_speed + b.radius_change_speed;
    let velocity_along_normal = Vec3.dot(relative_velocity(), collision.normal);
    let bounce_rel_vel = Vec3.dot(relative_velocity(), collision.normal);
    if &a.soft |> Option.is_none and &b.soft |> Option.is_none then (
        a.position^ = Vec3.add(
            a.position^,
            Vec3.mul(collision.normal, collision.penetration * ka),
        );
        b.position^ = Vec3.add(
            b.position^,
            Vec3.mul(collision.normal, collision.penetration * kb),
        );
        if bounce_rel_vel < 0 then (
            a.velocity^ = Vec3.add(
                a.velocity^,
                Vec3.mul(collision.normal, -(1 + bounciness) * bounce_rel_vel * ka),
            );
            b.velocity^ = Vec3.add(
                b.velocity^,
                Vec3.mul(collision.normal, -(1 + bounciness) * bounce_rel_vel * kb),
            );
        );
        (
            let velocity_along_normal = Vec3.dot(relative_velocity(), collision.normal)
            - radius_change_speed * jump_modifier;
            if velocity_along_normal < 0 then (
                a.velocity^ = Vec3.add(
                    a.velocity^,
                    Vec3.mul(collision.normal, -velocity_along_normal * ka),
                );
                b.velocity^ = Vec3.add(
                    b.velocity^,
                    Vec3.mul(collision.normal, -velocity_along_normal * kb),
                );
            );
        );
    ) else (
        let soft_react = (a, b) => with_return (
            if collision.penetration <= APPROX_ZERO then return;
            if a.soft is :Some a_soft then (
                let acceleration_along_normal = Vec3.dot(
                    collision.normal,
                    Vec3.sub(a.acceleration^, b.acceleration^),
                );
                let jump_graph :: JumpGraph = (
                    let pos = -collision.penetration;
                    # spring_k * dist = force = mass * acc = mass * dist / time^2
                    # spring_k = )mass / time^2
                    # w2 :: 1/time^2
                    # w :: 1/time
                    let w2 = a_soft.spring_k * (a.inverse_mass + b.inverse_mass);
                    let w = math.sqrt(w2);
                    let rest = acceleration_along_normal / w2;
                    let pos_relative_to_rest = pos - rest;
                    # velocity_along_normal :: dist^2 / time^2
                    let amplitude = math.sqrt(
                        math.sqr(pos_relative_to_rest)
                        + math.sqr(pos_relative_to_rest * w / PI * math.log(bounciness) - velocity_along_normal) / w2
                    );
                    let mut time_offset = math.acos(pos_relative_to_rest / amplitude);
                    if velocity_along_normal > 0 then (
                        time_offset = 2 * PI - time_offset;
                    );
                    @comment_out (
                        dbg.print({
                            .pos,
                            .pos_relative_to_rest,
                            .w2,
                            .rest,
                        });
                    );
                    {
                        .amplitude,
                        .w,
                        .time_offset,
                        .bounciness,
                        .rest,
                    }
                );
                let time_until_jump = (
                    let highest_point_time = (2 * PI - jump_graph.time_offset) / jump_graph.w;
                    dbg.print({ .highest_point_time });
                    binary_search(
                        ._in = 0,
                        .out = highest_point_time,
                        .is_in = t => jump_graph |> JumpGraph.at(t) <= 0,
                    )
                );
                let contact_delta_time = min(delta_time, time_until_jump);
                let expected_velocity_along_normal_next_frame = jump_graph
                    |> JumpGraph.derivative_at(contact_delta_time);
                let mut target_normal_acceleration = (
                    expected_velocity_along_normal_next_frame
                    - velocity_along_normal
                ) / delta_time;

                let target_jump_speed = radius_change_speed * jump_modifier;
                if target_jump_speed > APPROX_ZERO then (
                    let velocity_diff_towards_jump = target_jump_speed - velocity_along_normal;
                    if velocity_diff_towards_jump > 0 then (
                        let time_until_jump = max(delta_time, time_until_jump);
                        let acceleration_needed_to_jump = velocity_diff_towards_jump / time_until_jump;
                        target_normal_acceleration = max(
                            acceleration_needed_to_jump,
                            target_normal_acceleration,
                        );
                    );
                );
                let normal_acceleration = target_normal_acceleration - acceleration_along_normal;
                if normal_acceleration < 0 then return;
                dbg.print({
                    .jump_graph,
                    .time_until_jump,
                    .delta_time,
                    .contact_delta_time,
                    .acceleration_along_normal,
                    .velocity_along_normal,
                    .target_normal_acceleration,
                    .normal_acceleration,
                    .expected_pen_next_frame = jump_graph |> JumpGraph.at(contact_delta_time),
                    .expected_velocity_along_normal_next_frame,
                    .zero = jump_graph |> JumpGraph.at(time_until_jump),
                    .penetration = collision.penetration,
                    .graph_0 = jump_graph |> JumpGraph.at(0),
                    .graph_der_0 = jump_graph |> JumpGraph.derivative_at(0),
                });
                let normal_acceleration_vec = Vec3.mul(
                    collision.normal,
                    normal_acceleration,
                );
                a.acceleration^ = Vec3.add(
                    a.acceleration^,
                    Vec3.mul(normal_acceleration_vec, ka),
                );
                b.acceleration^ = Vec3.add(
                    b.acceleration^,
                    Vec3.mul(normal_acceleration_vec, kb),
                );
                let relative_angular_velocity = Vec3.sub(a.angular_velocity^, b.angular_velocity^);
                let relative_angular_velocity = Vec3.add(
                    relative_angular_velocity,
                    Vec3.div(Vec3.cross(Vec3.sub(a.velocity^, b.velocity^), collision.normal), a.radius),
                );
                let angular_velocity_change = Vec3.mul(
                    Vec3.normalize_or_zero(relative_angular_velocity),
                    -min(
                        normal_acceleration * properties^.friction * delta_time,
                        Vec3.length(relative_angular_velocity),
                    ),
                );
                a.angular_velocity^ = Vec3.add(
                    a.angular_velocity^,
                    Vec3.mul(angular_velocity_change, ka),
                );
                b.angular_velocity^ = Vec3.add(
                    b.angular_velocity^,
                    Vec3.mul(angular_velocity_change, kb),
                );
                let friction_linear_velocity_change = Vec3.cross(
                    Vec3.mul(angular_velocity_change, friction_into_linear),
                    collision.normal,
                );
                a.velocity^ = Vec3.sub(
                    a.velocity^,
                    Vec3.mul(friction_linear_velocity_change, ka),
                );
                b.velocity^ = Vec3.sub(
                    b.velocity^,
                    Vec3.mul(friction_linear_velocity_change, kb),
                );
            );
        );
        soft_react(a, b);
        soft_react(b, a);
    );
    @comment_out (
        let relative_angular_velocity = Vec3.sub(a.angular_velocity^, b.angular_velocity^);
        let relative_angular_velocity = Vec3.add(
            relative_angular_velocity,
            Vec3.div(Vec3.cross(relative_velocity(), collision.normal), a.radius),
        );
        let friction = properties^.friction;
        let angular_impulse = Vec3.mul(
            relative_angular_velocity,
            -min(friction, max(0, -bounce_rel_vel) * friction),
        );
        (
            # TODO this is a hack for beachball
            let ka = 1;
            let kb = 1;
            a.angular_velocity^ = Vec3.add(a.angular_velocity^, Vec3.mul(angular_impulse, ka));
            b.angular_velocity^ = Vec3.add(b.angular_velocity^, Vec3.mul(angular_impulse, kb));
        );
        let angular_impulse = Vec3.mul(angular_impulse, friction_into_linear);
        a.velocity^ = Vec3.sub(
            a.velocity^,
            Vec3.mul(Vec3.cross(angular_impulse, collision.normal), ka),
        );
        b.velocity^ = Vec3.sub(
            b.velocity^,
            Vec3.mul(Vec3.cross(angular_impulse, collision.normal), kb),
        );
    );
    {
        .velocity_along_normal,
        .normal = collision.normal,
        .penetration = collision.penetration,
        .point = collision.point,
    }
);

const collide_and_react_entities = (
    a :: Entity,
    b :: Entity,
    .delta_time :: Float32,
) -> Option.t[CollisionResult] => (
    let delta_pos = Vec3.sub(a.position^, b.position^);
    let distance = delta_pos |> Vec3.length;
    let penetration = a.radius + b.radius - distance;
    if penetration > 0 then (
        let normal = delta_pos |> Vec3.normalize_or_zero;
        let point = Vec3.sub(a.position^, Vec3.mul(normal, a.radius - penetration / 2));
        let properties = &{
            .bounciness = 2,
            .friction = 1,
            .animated = false,
            .particles = 0,
            .particle_t = 0,
            .particle_spread = 0,
        };
        :Some do_react_entities(
            a,
            b,
            { .normal, .penetration, .point },
            .properties,
            .friction_into_linear = 0,
            .delta_time,
        )
    ) else :None
);

const collide_and_react = (
    entity :: Entity,
    .mesh :: &Mesh,
    .properties :: &MeshProperties,
    .delta_time :: Float32,
) -> Option.t[CollisionResult] => (
    if collide({ .position = entity.position^, .radius = entity.radius }, mesh) is :Some collision then (
        let mut zero_pos = { 0, 0, 0 };
        let mut zero_vel = { 0, 0, 0 };
        let mut zero_acc = { 0, 0, 0 };
        let mut zero_ang = { 0, 0, 0 };
        let mesh_entity = {
            .position = &mut zero_pos,
            .velocity = &mut zero_vel,
            .acceleration = &mut zero_acc,
            .angular_velocity = &mut zero_ang,
            .radius_change_speed = 0,
            .jump_modifier = 0,
            .radius = 0,
            .inverse_mass = 0,
            .soft = :None,
        };
        :Some do_react_entities(
            entity,
            mesh_entity,
            collision,
            .properties,
            .friction_into_linear = 1,
            .delta_time,
        )
    ) else (
        :None
    )
);
