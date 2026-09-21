use (import "./lib/la/_lib.ks").*;
use (import "./lib/common.ks").*;

module:

const Collision = newtype {
    .penetration :: Float32,
    .normal :: Vec3,
};

const Entity = newtype {
    .position :: Vec3,
    .radius :: Float32,
};

const Face = newtype {
    .vs :: ArrayList.t[Vec3],
    .normal :: Vec3,
};

const ChunkCoord = newtype { Int32, Int32, Int32 };

impl ChunkCoord as std.cmp.Ord = {
    .compare = (a, b) => with_return (
        match std.cmp.default_compare(a.0, b.0) with (
            | :Equal => ()
            | other => return other
        );
        match std.cmp.default_compare(a.1, b.1) with (
            | :Equal => ()
            | other => return other
        );
        match std.cmp.default_compare(a.2, b.2) with (
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
    .iter = consumer => (
        for x in from.0..to.0 do (
            for y in from.1..to.1 do (
                for z in from.2..to.2 do (
                    consumer({ x, y, z });
                );
            );
        );
    ),
};

const floor = (x :: Float32) -> Int32 => (
    @native "floorf(\(x))"
);
const ceil = (x :: Float32) -> Int32 => (
    @native "ceilf(\(x))"
);

impl Mesh as module = (
    module:

    const new = (faces :: ArrayList.t[Face]) -> Mesh => (
        let mut chunks = OrdMap.new();
        let mut i = 0;
        for &face in &faces |> ArrayList.iter do (
            if i % 1000 == 0 then yield();
            i += 1;
            let from = {
                floor(min(min(face.vs.[0].0, face.vs.[1].0), face.vs.[2].0) / CHUNK_SIZE),
                floor(min(min(face.vs.[0].1, face.vs.[1].1), face.vs.[2].1) / CHUNK_SIZE),
                floor(min(min(face.vs.[0].2, face.vs.[1].2), face.vs.[2].2) / CHUNK_SIZE),
            };
            let to = {
                ceil(max(max(face.vs.[0].0, face.vs.[1].0), face.vs.[2].0) / CHUNK_SIZE),
                ceil(max(max(face.vs.[0].1, face.vs.[1].1), face.vs.[2].1) / CHUNK_SIZE),
                ceil(max(max(face.vs.[0].2, face.vs.[1].2), face.vs.[2].2) / CHUNK_SIZE),
            };
            for co in chunk_box(from, to) do (
                let chunk = &mut chunks |> OrdMap.get_or_init(co, Chunk.new);
                &mut chunk^.faces |> ArrayList.push_back(face);
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

const collide_face = (result :: &mut Collision, entity :: Entity, face :: &Face) => (
    for &p in &face^.vs |> ArrayList.iter do (
        let dv = Vec3.sub(entity.position, p);
        let len = Vec3.length(dv);
        if len < entity.radius then (
            update(result, { .penetration = entity.radius - len, .normal = Vec3.normalize(dv) });
        );
    );
    for i in 0..3 do (
        let a = face^.vs.[i];
        let b = face^.vs.[(i + 1) % 3];
        if Vec3.dot(Vec3.sub(b, a), Vec3.sub(entity.position, a)) <= 0 then (
            continue;
        );
        if Vec3.dot(Vec3.sub(a, b), Vec3.sub(entity.position, b)) <= 0 then (
            continue;
        );
        let v = Vec3.normalize(Vec3.sub(b, a));
        let t = Vec3.dot(Vec3.sub(entity.position, a), v);
        let closest_point = Vec3.add(a, Vec3.mul(v, t));
        let delta = Vec3.sub(entity.position, closest_point);
        let length = Vec3.length(delta);
        if length < entity.radius then (
            update(result, { .penetration = entity.radius - length, .normal = Vec3.normalize(delta) });
        );
    );
    let d = Vec3.dot(Vec3.sub(entity.position, face^.vs.[0]), face^.normal);
    if 0 < d and d < entity.radius then (
        let closest_point = Vec3.sub(entity.position, Vec3.mul(face^.normal, d));
        with_return (
            for i in 0..3 do (
                let a = face^.vs.[i];
                let b = face^.vs.[(i + 1) % 3];
                if Vec3.dot(Vec3.cross(face^.normal, Vec3.sub(b, a)), Vec3.sub(closest_point, a)) < 0 then (
                    return;
                );
            );
            update(result, { .penetration = entity.radius - d, .normal = face^.normal });
        );
    );
);

const collide = (entity :: Entity, mesh :: &Mesh) -> Option.t[Collision] => with_return (
    let mut result :: Collision = {
        .penetration = -1,
        .normal = { 0, 0, 0 },
    };
    let from = {
        floor((entity.position.0 - entity.radius) / CHUNK_SIZE),
        floor((entity.position.1 - entity.radius) / CHUNK_SIZE),
        floor((entity.position.2 - entity.radius) / CHUNK_SIZE),
    };
    let to = {
        ceil((entity.position.0 + entity.radius) / CHUNK_SIZE),
        ceil((entity.position.1 + entity.radius) / CHUNK_SIZE),
        ceil((entity.position.2 + entity.radius) / CHUNK_SIZE),
    };
    for co in chunk_box(from, to) do (
        if &mesh^.chunks |> OrdMap.get(co) is :Some chunk then (
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
};

const Entity = newtype {
    .position :: &mut Vec3,
    .velocity :: &mut Vec3,
    .angular_velocity :: &mut Vec3,
    .radius_change_speed :: Float32,
    .radius :: Float32,
    .inverse_mass :: Float32,
};

const do_react_entities = (
    a :: Entity,
    b :: Entity,
    collision :: Collision,
    .properties :: &MeshProperties,
) -> CollisionResult => (
    let bounciness = properties^.bounciness;
    let jump_modifier = 4;
    let ka = a.inverse_mass / (a.inverse_mass + b.inverse_mass);
    let kb = -b.inverse_mass / (a.inverse_mass + b.inverse_mass);
    a.position^ = Vec3.add(
        a.position^,
        Vec3.mul(collision.normal, collision.penetration * ka),
    );
    b.position^ = Vec3.add(
        b.position^,
        Vec3.mul(collision.normal, collision.penetration * kb),
    );
    let relative_velocity = () => Vec3.sub(a.velocity^, b.velocity^);
    let radius_change_speed = a.radius_change_speed + b.radius_change_speed;
    let velocity_along_normal = Vec3.dot(relative_velocity(), collision.normal)
        - radius_change_speed * jump_modifier;
    let bounce_rel_vel = Vec3.dot(relative_velocity(), collision.normal);
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
    a.velocity^ = Vec3.sub(
        a.velocity^,
        Vec3.mul(Vec3.cross(angular_impulse, collision.normal), ka),
    );
    b.velocity^ = Vec3.sub(
        b.velocity^,
        Vec3.mul(Vec3.cross(angular_impulse, collision.normal), kb),
    );
    a.angular_velocity^ = Vec3.add(a.angular_velocity^, Vec3.mul(angular_impulse, ka));
    b.angular_velocity^ = Vec3.add(b.angular_velocity^, Vec3.mul(angular_impulse, kb));
    { .velocity_along_normal, .normal = collision.normal }
);

const collide_and_react_entities = (a :: Entity, b :: Entity) -> Option.t[CollisionResult] => (
    let delta_pos = Vec3.sub(a.position^, b.position^);
    let distance = delta_pos |> Vec3.length;
    let penetration = a.radius + b.radius - distance;
    if penetration > 0 then (
        let normal = delta_pos |> Vec3.normalize_or_zero;
        let properties = &{
            .bounciness = 0.5,
            .friction = 0.0,
            .animated = false,
            .particles = 0,
            .particle_t = 0,
            .particle_spread = 0,
        };
        :Some do_react_entities(a, b, { .normal, .penetration }, .properties)
    ) else :None
);

const collide_and_react = (
    entity :: Entity,
    .mesh :: &Mesh,
    .properties :: &MeshProperties,
) -> Option.t[CollisionResult] => (
    if collide({ .position = entity.position^, .radius = entity.radius }, mesh) is :Some collision then (
        let mesh_entity = {
            .position = &mut { 0, 0, 0 },
            .velocity = &mut { 0, 0, 0 },
            .angular_velocity = &mut { 0, 0, 0 },
            .radius_change_speed = 0,
            .radius = 0,
            .inverse_mass = 0,
        };
        :Some do_react_entities(entity, mesh_entity, collision, .properties)
    ) else (
        :None
    )
);
