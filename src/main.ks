use (import "lib/_lib.ks").*;
use (import "./assets.ks").*;
use (import "./model.ks").*;

const badcop = import "../net/bindings.ks";

const collisions = import "./collisions.ks";

const FINISH :: Vec3 = { -120.198761, -1.251943, 147.323959 };
# TODO IDK why but with const :: Float32 it thinks its Float64???
const BEACHBALL_NET_X = `(-68.147575);

module:

const Power = newtype (
    | :None
    | :Parachute {
        .active :: Bool,
        .rotation :: Quat,
    }
    | :Jetpack {
        .active :: Bool,
        .next_particle :: Float32,
        .sfx :: Option.t[geng.audio.Effect],
    }
    | :BeachballVertical {
        .active :: Bool,
    }
    | :Antigravity {
        .active :: Bool,
    }
);

# { -112.411026, -195.230301, 8.988006 }
# { -68.147575, -223.581848, 24.811840 }
# { -23.389166, -251.719894, 8.988012 }
const beachball_side = (pos :: Vec3) -> Int32 => (
    if (
        -112.411026 < pos.0 and pos.0 < -23.389166 and
        -251.719894 < pos.1 and pos.1 < -195.230301
    ) then (
        if pos.0 < (include_ast BEACHBALL_NET_X) then 1 else -1
    ) else 0
);

const Entity = newtype {
    .skin :: Int32,
    .position :: Vec3,
    .velocity :: Vec3,
    .flat_rot :: Angle,
    .rotation :: Quat,
    .angular_velocity :: Vec3,
    .can_jump :: Bool,
    .scale :: Float32,
    .scale_speed :: Float32,
    .power :: Power,
    .is_player :: Bool,
    .input :: PlayerInput,
    .min_scale :: Float32,
    .max_scale :: Float32,
    .mass :: Float32,
};

const player_speed = 15;
const player_acceleration = 20;

const MAX_SPEED = 200;

const PlayerInput = newtype {
    .wasd :: Vec2,
    .shift :: Bool,
    .space :: Bool,
    .use_power :: Bool,
    .jetpack_enabled :: Bool,
    .control_mode :: ControlMode,
};

impl Entity as module = (
    module:

    const draw = (self :: &Entity, .jetpack :: Bool) => (
        draw_skin(
            self^.skin,
            self^.position,
            self^.velocity,
            self^.scale,
            self^.flat_rot,
            self^.rotation,
            .jetpack,
            .power = self^.power,
            .volley = not self^.is_player,
        );
    );

    const update_input = (
        self :: &mut Game,
        entity :: &mut Entity,
        delta_time :: Float32,
        input :: PlayerInput,
    ) => (
        entity^.input = input;
        if input.jetpack_enabled then (
            let target_velocity :: Vec3 = {
                ...Vec2.rotate(
                    Vec2.mul(Vec2.normalize_or_zero(input.wasd), player_speed),
                    self^.camera.rotation,
                ),
                (
                    let mut z = 0;
                    if input.space then (
                        z += 1;
                    );
                    if input.shift then (
                        z -= 1;
                    );
                    z * player_speed
                ),
            };
            entity^.velocity = Vec3.add(
                entity^.velocity,
                Vec3.mul(
                    Vec3.sub(target_velocity, entity^.velocity),
                    min(player_acceleration * delta_time, 1),
                ),
            );
        ) else (
            if entity^.position.2 < 0 then (
                let water_force = 5;
                let target_velocity :: Vec3 = {
                    ...Vec2.rotate(
                        Vec2.mul(Vec2.normalize_or_zero(input.wasd), player_speed),
                        self^.camera.rotation,
                    ),
                    player_speed,
                };
                entity^.velocity = Vec3.add(
                    entity^.velocity,
                    Vec3.mul(
                        Vec3.sub(target_velocity, entity^.velocity),
                        min(water_force * delta_time, 1),
                    ),
                );
            ) else (
                let target_velocity :: Vec3 = {
                    ...Vec2.rotate(
                        Vec2.mul(Vec2.normalize_or_zero(input.wasd), player_speed),
                        self^.camera.rotation,
                    ),
                    entity^.velocity.2,
                };
                let air_control = 0.5;
                entity^.velocity = Vec3.add(
                    entity^.velocity,
                    Vec3.mul(
                        Vec3.sub(target_velocity, entity^.velocity),
                        min(air_control * delta_time, 1),
                    ),
                );
                let antigravity = if entity^.power is :Antigravity { .active, ... } then active else false;
                let gravity = if antigravity then 30 else 50;
                entity^.velocity.2 -= gravity * delta_time;
                if antigravity then (
                    let damp = 0.50;
                    entity^.velocity = Vec3.sub(
                        entity^.velocity,
                        Vec3.mul(entity^.velocity, min(1, delta_time * damp)),
                    );
                    let damp_z = 2;
                    entity^.velocity = Vec3.sub(
                        entity^.velocity,
                        Vec3.mul({ 0, 0, entity^.velocity.2 }, min(1, delta_time * damp_z)),
                    );
                );
            );
        );

        let scale_dir = if not input.jetpack_enabled and input.space then (
            if entity^.scale < entity^.max_scale then (
                1
            ) else 0
        ) else (
            if entity^.scale > entity^.min_scale then (
                -1
            ) else 0
        );
        let scale_speed = Int32_to_Float32(scale_dir);
        let scale_time = 0.2;
        let scale_speed = scale_speed / scale_time;
        entity^.scale_speed = scale_speed;
        entity^.scale = clamp(
            entity^.scale + entity^.scale_speed * delta_time,
            .min = entity^.min_scale,
            .max = entity^.max_scale,
        );
        if scale_dir != 0 then (
            let play = if self^.flate_sfx is :Some { sfx, .dir = cur_dir } then (
                if cur_dir != scale_dir then (
                    geng.audio.Effect.stop(sfx);
                    true
                ) else (
                    false
                )
            ) else true;
            if play then (
                let volume = if scale_dir > 0 then 1 else (
                    (entity^.scale - entity^.min_scale) / (entity^.max_scale - entity^.min_scale)
                );
                let sfx = geng.audio.play_with(
                    if scale_dir > 0 then self^.assets.sfx.inflation else self^.assets.sfx.deflation,
                    { .volume = volume * 0.3, .@"loop" = false },
                );
                self^.flate_sfx = :Some { sfx, .dir = scale_dir };
            );
        );

        let max_angular_velocity = 10;
        let target_angular_velocity = (
            let w = (
                let mut w :: Vec3 = { ...Vec2.rotate_90(input.wasd), 0 };
                if input.shift then (
                    w = { 0, w.1, -w.0 };
                );
                { ...w, 0 }
            );
            let mat = match self^.control_mode with (
                | :RelativeToCamera => Mat4.rotate_z(self^.camera.rotation)
                | :RelativeToFace => Quat.into_mat4(entity^.rotation)
            );
            mat |> Mat4.mul_vec(w)
                |> Vec4.xyz
                |> Vec3.mul(max_angular_velocity)
        );
        let angular_acceleration = 10;
        entity^.angular_velocity = Vec3.add(
            entity^.angular_velocity,
            Vec3.mul(
                Vec3.sub(target_angular_velocity, entity^.angular_velocity),
                min(angular_acceleration * delta_time, 1),
            ),
        );
        entity^.rotation = Quat.add(
            entity^.rotation,
            Quat.mul(
                Quat.mul_quat(
                    (
                        let { i, j, k } = entity^.angular_velocity;
                        { .i, .j, .k, .w = 0 }
                    ),
                    entity^.rotation,
                ),
                delta_time / 2,
            )
        )
            |> Quat.normalize;
        match entity^.power with (
            | :None => ()
            | :Antigravity ref mut power => (
                power^.active = input.use_power;
            )
            | :BeachballVertical ref mut power => (
                power^.active = input.use_power;
            )
            | :Jetpack ref mut jet => (
                jet^.active = input.use_power;
                if jet^.active then (
                    if jet^.sfx is :None then (
                        let sfx = geng.audio.play_with(
                            self^.assets.powers.jetpack.sfx,
                            { .volume = 0.6, .@"loop" = false },
                        );
                        jet^.sfx = :Some sfx;
                    );
                ) else (
                    if jet^.sfx is :Some sfx then (
                        geng.audio.Effect.stop(sfx);
                        jet^.sfx = :None;
                    );
                );
            )
            | :Parachute ref mut par => (
                par^.active = input.use_power;
                let target_rotation = Quat.mul_quat(
                    Quat.from_axis_angle(
                        { 0, 0, 1 },
                        entity^.flat_rot,
                    ),
                    Quat.from_axis_angle(
                        { 0, 1, 0 },
                        Angle.from_degrees(30 * Vec2.length(input.wasd)),
                    ),
                );
                par^.rotation = Quat.normalize(Quat.add(
                    par^.rotation,
                    Quat.mul(Quat.sub(target_rotation, par^.rotation), min(1, delta_time / 0.2)),
                ));
            )
        );
    );
);

const emote = (
    self :: &mut Game,
    position :: Vec3,
    index :: Int32,
) => (
    let index = clamp_int(index, .min = 0, .max = ArrayList.length(&self^.assets.textures.emotes) - 1);
    let particle = {
        .position = Vec3.add(position, { 0, 0, 2 }),
        .t = 0,
        .texture = self^.assets.textures.emotes.[index],
    };
    &mut self^.particles |> ArrayList.push_back(particle);
);

const draw_skin = (
    skin :: Int32,
    position :: Vec3,
    velocity :: Vec3,
    scale :: Float32,
    flat_rot :: Angle,
    rotation :: Quat,
    .jetpack :: Bool,
    .power :: Power,
    .volley :: Bool,
) => (
    let assets = @current Assets.Ctx;
    let skin = clamp_int(skin, .min = 0, .max = ArrayList.length(&assets.models.skins) - 1);
    if jetpack then (
        let angle = Angle.from_degrees(1000 * geng.time_since_start());
        Model.draw(
            if skin == 5 then assets.models.badarms else assets.models.jetpack,
            false,
            Mat4.translate(position)
                |> Mat4.mul_mat(Mat4.rotate(Vec3.cross({ 0, 0, 1 }, velocity), Angle.from_degrees(30 / player_speed)))
                |> Mat4.mul_mat(Mat4.rotate_z(angle)),
        );
    );
    if skin == 16 then (
        Model.draw(
            assets.models.wormy,
            false,
            Mat4.translate(Vec3.add(position, { 0, 0, -scale + 1 }))
                |> Mat4.mul_mat(Mat4.rotate_z(flat_rot)),
        );
    );
    if not jetpack or skin != 5 then (
        let matrix = Mat4.translate(position)
            |> Mat4.mul_mat(Mat4.scale_uniform(scale))
            |> Mat4.mul_mat(Quat.into_mat4(rotation));
        if volley then (
            @native "glCullFace(GL_FRONT)";
            Model.draw(
                assets.volleyball,
                false,
                matrix,
            );
            @native "glCullFace(GL_BACK)";
            Model.draw(
                assets.volleyball,
                false,
                matrix,
            );
        ) else (
            Model.draw(
                assets.models.skins.[skin],
                false,
                matrix,
            );
        );
    );
    match power with (
        | :None => ()
        | :Antigravity _ => ()
        | :BeachballVertical _ => ()
        | :Jetpack ref jet => (
            Model.draw(
                assets.powers.jetpack.model,
                false,
                Mat4.translate(position)
                    |> Mat4.mul_mat(Quat.into_mat4(rotation))
                    |> Mat4.mul_mat(Mat4.translate({ 0, 0, scale - 1 })),
            );
        )
        | :Parachute ref par => (
            if par^.active then (
                Model.draw(
                    assets.powers.parachute.model,
                    false,
                    Mat4.translate(position)
                        |> Mat4.mul_mat(Mat4.translate({ 0, 0, scale}))
                        |> Mat4.mul_mat(Quat.into_mat4(par^.rotation)),
                );
            );
        )
    )
);

include "./other_player.ks";

const TimerState = newtype (
    | :WaitForMove
    | :Working Float32
    | :Win Float32
    | :Disabled
);

const FpsCounter = newtype {
    .frames :: Float32,
    .start :: Float32,
};

impl FpsCounter as module = (
    module:

    const new = () -> FpsCounter => {
        .frames = 0,
        .start = geng.time_since_start(),
    };

    const frame = (self :: &mut FpsCounter) => (
        self^.frames += 1;
        if geng.time_since_start() - self^.start > 1 then (
            self^ = new();
        );
    );

    const fps = (self :: &FpsCounter) -> Float32 => (
        let seconds = geng.time_since_start() - self^.start;
        if seconds > 0.01 then (
            self^.frames / seconds
        ) else 0
    );
);

const BeachballScoringState = newtype (
    | :CanScore { .last_touched_side :: Int32 }
    | :WaitingToCrossTheNet { .serving_side :: Int32 }
);

const Beachball = newtype {
    .old :: Entity,
    .current :: Entity,
    .new :: Entity,
    .lerp :: Float32,
    .scoring :: BeachballScoringState,
};

const Game = newtype {
    .draw_player :: Bool,
    .server_meta :: badcop.ServerMeta,
    .send_beachball_update :: Bool,
    .fps_counter :: FpsCounter,
    .camera :: geng.Camera,
    .assets :: Assets.t,
    .model_renderer :: Model.Renderer,
    .water :: Model.t,
    .player :: Entity,
    .beachball :: Beachball,
    .other_players :: OrdMap.t[badcop.Id, OtherPlayer],
    .jetpack_enabled :: Bool,
    .cheated :: Bool,
    .jetpack_sfx :: geng.audio.Effect,
    .flate_sfx :: Option.t[type { geng.audio.Effect, .dir :: Int32 }],
    .timer :: TimerState,
    .next_physics :: Float32,
    .dragon_scales :: ArrayList.t[DragonScale],
    .next_send :: Float32,
    .dead :: Bool,
    .dead_timer :: Float32,
    .connected :: Bool,
    .show_timer :: Bool,
    .particle_buffer :: ugli.VertexBuffer.t[obj.Vertex],
    .particles :: ArrayList.t[Particle],
    .next_fire_particle :: Float32,
    .sens :: Float32,
    .power_index :: Int32,
    .control_mode :: ControlMode,
    .music_volume :: Float32,
};

const ControlMode = newtype (
    | :RelativeToCamera
    | :RelativeToFace
);

const FIREPLACES :: ArrayList.t[Vec3] = (
    let mut list = ArrayList.new[Vec3]();
    &mut list |> ArrayList.push_back({ -3.354541, -0.000820, 10.327483 });
    &mut list |> ArrayList.push_back({ 400.877594, 0.000273, 6.669017 });
    list
);

const Particle = newtype {
    .position :: Vec3,
    .texture :: ugli.Texture,
    .t :: Float32,
};

const DragonScale = newtype {
    .position :: Vec3,
    .collected :: Bool,
};

const respawn_dragon_scales = () => (
    let mut dragon_scales = ArrayList.new();
    let add = position => (
        let scale = {
            .position,
            .collected = false,
        };
        &mut dragon_scales |> ArrayList.push_back(scale);
    );
    add({ -166.625580, -0.227342, 21.092628 });
    add({ 46.816666, -0.005385, 0.049985 });
    add({ -138.585251, -59.781757, 47.580807 });
    add({ -80.768204, 0.142232, 101.941040 });
    add({ -71.015900, 28.825523, 25.515934 });
    add({ -25.596405, -4.421812, 117.133064 });
    add({ 403.696320, 5.528301, 6.410315 });
    dragon_scales
);

const reset_beachball = () -> Beachball => (
    let mut entity = reset_player(.skin = 1, .power = :Antigravity { .active = true });
    entity.position = { -47.435856, -224.922592, 20.447927 };
    entity.is_player = false;
    entity.scale = 3;
    entity.max_scale = entity.scale;
    entity.mass = 0.1;
    {
        .old = entity,
        .current = entity,
        .new = entity,
        .scoring = :WaitingToCrossTheNet { .serving_side = 0 },
        .lerp = 1,
    }
);

const reset_player = (.skin, .power) -> Entity => {
    .input = {
        .wasd = { 0, 0 },
        .space = false,
        .shift = false,
        .use_power = false,
        .jetpack_enabled = false,
        .control_mode = :RelativeToCamera,
    },
    .position = { 0, 0, 10 },
    .velocity = { 0, 0, 0 },
    .is_player = true,
    .rotation = Quat.IDENTITY,
    .mass = 1,
    .flat_rot = Angle.from_degrees(0),
    .angular_velocity = { 0, 0, 0 },
    .skin,
    .can_jump = false,
    .scale = 1,
    .min_scale = 1,
    .max_scale = 2,
    .scale_speed = 0,
    .power,
};

const draw_particle = (
    self :: &mut Game,
    position :: Vec3,
    scale :: Float32,
    texture :: ugli.Texture,
) => (
    let model = {
        .buffer = self^.particle_buffer,
        .texture,
    };
    Model.draw(
        model,
        false,
        Mat4.translate(position)
            |> Mat4.mul_mat(Mat4.scale_uniform(scale))
            |> Mat4.mul_mat(Mat4.rotate_z(self^.camera.rotation))
    );
);

const restart = (self :: &mut Game) => (
    self^.dead = false;
    self^.dead_timer = 0;
    self^.player = reset_player(
        .skin = self^.player.skin,
        .power = self^.player.power,
    );
    self^.beachball = reset_beachball();
    self^.timer = :WaitForMove;
    self^.cheated = false;
    self^.jetpack_enabled = false;
    self^.dragon_scales = respawn_dragon_scales();
);

const is_jump_pressed = () => (
    geng.input.Key.is_pressed(:Space) or geng.input.Key.is_pressed(:Backspace)
);

const update_step = (
    self :: &mut Game,
    entity :: &mut Entity,
    delta_time :: Float32,
    .score_beachball :: Bool,
) => with_return (
    if self^.dead then return;

    match entity^.power with (
        | :None => ()
        | :Antigravity _ => ()
        | :BeachballVertical _ => ()
        | :Jetpack ref mut jet => (
            if jet^.active then (
                let mat = Quat.into_mat4(entity^.rotation);
                let forward = Mat4.mul_vec(mat, { 1, 0, 0, 0})
                    |> Vec4.xyz;
                let up = Mat4.mul_vec(mat, { 0, 0, 1, 0})
                    |> Vec4.xyz;
                entity^.velocity = Vec3.add(
                    entity^.velocity,
                    Vec3.mul(forward, 75 * delta_time),
                );
                entity^.angular_velocity = Vec3.add(
                    entity^.angular_velocity,
                    Vec3.mul(
                        Mat4.mul_vec(mat, { 0, 1, 0, 0 })
                            |> Vec4.xyz,
                        75 * delta_time,
                    ),
                );
                jet^.next_particle -= delta_time;
                while jet^.next_particle < 0 do (
                    jet^.next_particle += 1 / 30;
                    let particle = {
                        .position = Vec3.add(
                            entity^.position,
                            Vec3.mul(up, entity^.scale + 0.2),
                        ),
                        .texture = self^.assets.powers.jetpack.particle,
                        .t = 0.2,
                    };
                    &mut self^.particles |> ArrayList.push_back(particle);
                );
            );
        )
        | :Parachute ref mut par => (
            if par^.active then (
                let up = Quat.into_mat4(par^.rotation)
                    |> Mat4.mul_vec({ 0, 0, 1, 0 })
                    |> Vec4.xyz
                    |> Vec3.normalize;
                let up_velocity = Vec3.dot(up, entity^.velocity);
                if up_velocity < 0 then (
                    let force = Vec3.mul(up, -up_velocity * 10);
                    entity^.velocity = Vec3.add(
                        entity^.velocity,
                        Vec3.mul(force, delta_time),
                    );
                );
            );
        )
    );

    let old_z = entity^.position.2;
    entity^.position = Vec3.add(
        entity^.position,
        Vec3.mul(entity^.velocity, delta_time),
    );
    let new_z = entity^.position.2;
    if old_z >= 0 and new_z < 0 or old_z < 0 and new_z >= 0 then (
        let volume = min(abs(entity^.velocity.2) / player_speed * 2 - 1, 1);
        if volume > 0.1 then (
            for (_ :: Int32) in 0..5 do (
                let deg = std.random.gen_range(.min = 0, .max = 360);
                let particle = {
                    .position = Vec3.add(
                        entity^.position,
                        { ...Vec2.rotate({ entity^.scale, 0 }, Angle.from_degrees(deg)), 0 }
                    ),
                    .texture = self^.assets.textures.water_particle,
                    .t = 0,
                };
                &mut self^.particles |> ArrayList.push_back(particle);
            );
            geng.audio.play_with(
                self^.assets.sfx.splash,
                { .volume, .@"loop" = false },
            );
        );
    );
    let mut max_speed = MAX_SPEED;
    for { type_index, level_model } in (
        &self^.assets.models.level
            |> ArrayList.iter
            |> std.iter.enumerate
    ) do (
        let collision_entity = {
            .position = &mut entity^.position,
            .velocity = &mut entity^.velocity,
            .angular_velocity = &mut entity^.angular_velocity,
            .radius_change_speed = entity^.scale_speed,
            .radius = entity^.scale,
            .inverse_mass = 1,
        };
        if collisions.collide_and_react(
            collision_entity,
            .mesh = &level_model^.collision_mesh,
            .properties = &level_model^.properties,
        ) is :Some collision then (
            if type_index == 4 and score_beachball then (
                if self^.beachball.scoring is :CanScore { .last_touched_side } then (
                    self^.beachball.scoring = :WaitingToCrossTheNet { .serving_side = 0 };
                    let side = beachball_side(entity^.position);
                    let who_scored = if side == 0 then -last_touched_side else -side;
                    badcop.send_beachball_scored(who_scored);
                );
            );
            if type_index == 1 and entity^.is_player then (
                self^.dead = true;
                for (_ :: Int32) in 0..10 do (
                    const rng = () => std.random.gen_range(.min = -0.5, .max = 0.5);
                    let particle = {
                        .position = Vec3.add(
                            entity^.position,
                            { rng(), rng(), rng() },
                        ),
                        .t = 0,
                        .texture = self^.assets.textures.fire,
                    };
                    &mut self^.particles |> ArrayList.push_back(particle);
                );
            );
            let volume = min(abs(collision.velocity_along_normal) / 50, 1);
            if volume > 0.1 then (
                let collision_point = Vec3.sub(
                    entity^.position,
                    Vec3.mul(collision.normal, entity^.scale),
                );
                for _ in 0..level_model^.properties.particles do (
                    const rng = () => std.random.gen_range(.min = -0.5, .max = 0.5);
                    let p = Vec3.add(
                        collision_point,
                        Vec3.mul({ rng(), rng(), rng() }, level_model^.properties.particle_spread),
                    );
                    let particle = {
                        .position = Vec3.sub(
                            p,
                            Vec3.mul(
                                collision.normal,
                                Vec3.dot(
                                    collision.normal,
                                    Vec3.sub(p, collision_point),
                                ),
                            ),
                        ),
                        .t = level_model^.properties.particle_t,
                        .texture = level_model^.particle,
                    };
                    &mut self^.particles |> ArrayList.push_back(particle);
                );
                geng.audio.play_with(
                    level_model^.sfx,
                    { .volume, .@"loop" = false },
                );
            );
        );
    );
    entity^.velocity = Vec3.clamp_len(entity^.velocity, max_speed);
);

const send_update = (self :: &mut Game) => (
    let make_update = e => {
        .position = e^.position,
        .velocity = e^.velocity,
        .rotation = e^.rotation,
        .angular_velocity = e^.angular_velocity,
        .skin = e^.skin,
        .jetpack = self^.jetpack_enabled,
        .scale = e^.scale,
        .distance_to_beachball = Vec3.length(Vec3.sub(self^.beachball.current.position, e^.position)),
    };
    badcop.send_update(make_update(&self^.player));
    if self^.send_beachball_update then (
        badcop.send_beachball_update(make_update(&self^.beachball.current));
        self^.send_beachball_update = false;
    );
);

const handle_mmo = (self :: &mut Game) => (
    let new_connection_state = badcop.is_connected();
    if new_connection_state != self^.connected then (
        self^.connected = new_connection_state;
        if new_connection_state then (
                self^.other_players = OrdMap.new();
        );
    );
    while badcop.poll_message() is :Some msg do (
        match msg with (
            | :Connected id => (
                print("Player connected: " + to_string(id));
                &mut self^.other_players |> OrdMap.add(id, OtherPlayer.new());
            )
            | :Disconnected id => (
                print("Player disconnected: " + to_string(id));
                &mut self^.other_players |> OrdMap.remove(id);
            )
            | :Meta meta => (
                self^.server_meta = meta;
            )
            | :BeachballScored { .who } => (
                geng.audio.play(self^.assets.sfx.score);
            )
            | :UpdatePlayer { .id, .data } => (
                let player = &mut self^.other_players
                    |> OrdMap.get_mut(id)
                    |> Option.unwrap;
                OtherPlayer.update_net(player, data);
            )
            | :UpdateBeachball data => (
                self^.beachball = {
                    .old = self^.beachball.current,
                    .current = self^.beachball.current,
                    .new = (
                        let mut e = self^.beachball.new;
                        e.position = data.position;
                        e.velocity = data.velocity;
                        e.rotation = data.rotation;
                        e.angular_velocity = data.angular_velocity;
                        e
                    ),
                    .scoring = self^.beachball.scoring,
                    .lerp = 0,
                };
            )
            | :PlayerMeta _ => (
            )
            | :Emote { .id, .index } => (
                if &self^.other_players |> OrdMap.get(id) is :Some player then (
                    emote(self, player^.position.value, index)
                );
            )
        )
    );

    @comment_out (
    while client.poll_message() is :Some msg do (
        match msg with (
            | :Connected id => (
                print("Connected " + to_string(id));
                let player = {
                    .skin = 1,
                    .position = { 0, 0, 0 },
                    .rotation = Angle.from_degrees(0),
                };
                &mut self^.other_players |> OrdMap.add(id, player);
            )
            | :Disconnected id => (
                print("Disconnected " + to_string(id));
                &mut self^.other_players |> OrdMap.remove(id);
            )
            | :UpdatePlayer { .id, .state } => (
                print("Updated " + to_string(id));
                let player = &mut self^.other_players
                    |> OrdMap.get_mut(id)
                    |> Option.unwrap;
                player^.position = state.position;
            )
            | :RequestUpdate => (
                print("Update requested");
                client.send(:Update { .position = self^.player.position });
            )
        )
    );
    );
);

@eval (
    impl Game as geng.App = {
        .init = () => (
            SDL.SetWindowRelativeMouseMode((@current geng.Context).window, true);
            @native "glEnable(GL_BLEND)";
            @native "glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)";
            @native "glCullFace(GL_BACK)";
            let assets = Assets.load();
            let water = (
                let mut v :: Vec2 = Vec2.mul({ 1, -1 }, 1000);
                let mut vs = ArrayList.new();
                for (_ :: Int32) in 0..4 do (
                    &mut vs |> ArrayList.push_back(v);
                    v = { -v.1, v.0 };
                );
                let vertex = i => {
                    .a_pos = { ...vs.[i], 0 },
                    .a_uv = Vec2.mul(vs.[i], 0.3),
                    .a_normal = { 0, 0, 1 },
                };
                let mut data = ArrayList.new();
                &mut data |> ArrayList.push_back(vertex(0));
                &mut data |> ArrayList.push_back(vertex(1));
                &mut data |> ArrayList.push_back(vertex(2));
                &mut data |> ArrayList.push_back(vertex(0));
                &mut data |> ArrayList.push_back(vertex(2));
                &mut data |> ArrayList.push_back(vertex(3));
                {
                    .texture = assets.textures.water,
                    .buffer = ugli.VertexBuffer.init(&data),
                }
            );
            {
                .camera = {
                    .position = { 0, 0, 5 },
                    .distance = 5,
                    .attack = Angle.from_degrees(0),
                    .rotation = Angle.from_degrees(0),
                    .fov = Angle.from_degrees(90),
                },
                .dragon_scales = respawn_dragon_scales(),
                .next_send = 0,
                .dead = false,
                .dead_timer = 0,
                .assets,
                .water,
                .model_renderer = Model.Renderer.init(),
                .player = reset_player(
                    .skin = 0,
                    .power = :Parachute { .active = false, .rotation = Quat.IDENTITY },
                ),
                .beachball = reset_beachball(),
                .other_players = OrdMap.new(),
                .jetpack_enabled = false,
                .server_meta = badcop.ServerMeta.default(),
                .draw_player = true,
                .fps_counter = FpsCounter.new(),
                .cheated = false,
                .flate_sfx = :None,
                .jetpack_sfx = geng.audio.play_with(assets.sfx.jetpack, { .volume = 0, .@"loop" = true }),
                .timer = :WaitForMove,
                .sens = 1,
                .next_physics = 0,
                .connected = false,
                .show_timer = true,
                .send_beachball_update = false,
                .power_index = 0,
                .music_volume = 1,
                .particles = ArrayList.new(),
                .control_mode = :RelativeToCamera,
                .next_fire_particle = 0,
                .particle_buffer = (
                    let mut data :: ArrayList.t[obj.Vertex] = ArrayList.new();
                    ArrayList.push_back(
                        &mut data,
                        {
                            .a_pos = { 0, -1, -1 },
                            .a_normal = { 0, 0, 1 },
                            .a_uv = { 0, 0 },
                        },
                    );
                    ArrayList.push_back(
                        &mut data,
                        {
                            .a_pos = { 0.2, -1, +1 },
                            .a_normal = { 0, 0, 1 },
                            .a_uv = { 0, 1 },
                        },
                    );
                    ArrayList.push_back(
                        &mut data,
                        {
                            .a_pos = { 0, +1, +1 },
                            .a_normal = { 0, 0, 1 },
                            .a_uv = { 1, 1 },
                        },
                    );
                    ArrayList.push_back(&mut data, data.[0]);
                    ArrayList.push_back(&mut data, data.[2]);
                    ArrayList.push_back(
                        &mut data,
                        {
                            .a_pos = { 0, +1, -1 },
                            .a_normal = { 0, 0, 1 },
                            .a_uv = { 1, 0 },
                        },
                    );
                    ugli.VertexBuffer.init(&data)
                ),
            }
        ),
        .draw = self => with_return (
            self^.camera.position = Vec3.add(self^.player.position, { 0, 0, 3 });
            with Assets.Ctx = self^.assets;
            with Model.Renderer.Ctx = self^.model_renderer;
            with Model.PlayerCtx = {
                .position = self^.player.position,
                .radius = if self^.dead then 0 else self^.player.scale,
                .volleyball_position = self^.beachball.current.position,
                .volleyball_radius = self^.beachball.current.scale,
            };
            with geng.CameraUniforms.Ctx = geng.CameraUniforms.init(
                self^.camera,
                .framebuffer_size = geng.get_window_size(),
            );
            ugli.clear({ 0.8, 0.8, 1, 1 });
            for level_model in &self^.assets.models.level |> ArrayList.iter do (
                Model.draw(level_model^.model, level_model^.properties.animated, Mat4.IDENTITY);
            );
            @native "glEnable(GL_CULL_FACE)";
            for &model in &self^.assets.models.level_nocollisions |> ArrayList.iter do (
                Model.draw(model, false, Mat4.IDENTITY);
            );
            # @native "glDisable(GL_CULL_FACE)";
            let mut collected_scales :: Int32 = 0;
            for scale in &self^.dragon_scales |> ArrayList.iter do (
                if scale^.collected then (
                    collected_scales += 1;
                    continue;
                );
                let matrix = Mat4.translate(scale^.position)
                    |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(geng.time_since_start() * 90)));
                Model.draw(self^.assets.models.dragon_scale, false, matrix);
            );
            if not self^.dead then (
                with Model.PlayerCtx = {
                    .position = self^.player.position,
                    .radius = 0,
                    .volleyball_position = self^.beachball.current.position,
                    .volleyball_radius = self^.beachball.current.scale,
                };
                if self^.draw_player then (
                    Entity.draw(&self^.player, .jetpack = self^.jetpack_enabled);
                );
            );
            for &{ .key = _, .value = ref other_player } in &self^.other_players |> OrdMap.iter do (
                OtherPlayer.draw(other_player);
            );
            Entity.draw(&self^.beachball.current, .jetpack = false);
            Model.draw(self^.water, true, Mat4.IDENTITY);
            for p in &self^.particles |> ArrayList.iter do (
                draw_particle(self, p^.position, 1 - math.pow(p^.t, 2), p^.texture);
            );

            let height = 12;
            let distance = 8;

            let linksider_pos :: Vec3 = { 406.587189, -9.395210, 13 };
            if Vec3.length(Vec3.sub(self^.player.position, linksider_pos)) < 20 then (
                font.Font.draw(
                    &self^.assets.font,
                    "wishlist LinkSider on steam",
                    .matrix = Mat4.translate(linksider_pos)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-120)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
            );

            if Vec3.length(Vec3.sub(self^.player.position, FINISH)) < 20 then (
                let distance = 25;
                font.Font.draw(
                    &self^.assets.font,
                    "Scale to Space",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-90)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(45)))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, 15}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.scale_uniform(4)),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "made for Down2Jam 4",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-90)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(45)))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, 14}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "kuviman - programming, sfx",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-90)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(45)))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, 12}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "rickylee - level design, modeling",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-90)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(45)))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, 11}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "badcop - multiplayer",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-10)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(20)))
                        |> Mat4.mul_mat(Mat4.translate({ -5, distance, 10}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(30))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "howlingaf - consulting",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-10)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(20)))
                        |> Mat4.mul_mat(Mat4.translate({ -5, distance, 9}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(30))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "vesdev - music",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-170)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(20)))
                        |> Mat4.mul_mat(Mat4.translate({ 5, distance, 10}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-30))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "Martin_Lutter - trumpet sfx",
                    .matrix = Mat4.translate(FINISH)
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-170)))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(20)))
                        |> Mat4.mul_mat(Mat4.translate({ 5, distance, 9}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.rotate_z(Angle.from_degrees(-30))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
            );

            if Vec3.length(self^.player.position) < 40 then (
                font.Font.draw(
                    &self^.assets.font,
                    "Scale to Space",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(-90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance * 2, height + 6 }))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.scale_uniform(4)),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "WASD to ROLL",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(-90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height + 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "Mouse to LOOK",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(-90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height - 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "PageUp/PageDown to change sens",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(-90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height - 1.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                        |> Mat4.mul_mat(Mat4.scale_uniform(0.5)),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                if false then (
                    font.Font.draw(
                        &self^.assets.font,
                        "P to cycle POSTJAM power",
                        .matrix = Mat4.rotate_z(Angle.from_degrees(10))
                            |> Mat4.mul_mat(Mat4.translate({ 0, distance, height + 4}))
                            |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                        .color = { 0, 0, 0, 1 },
                        .align = 0.5,
                    );
                );
                font.Font.draw(
                    &self^.assets.font,
                    "RMB to use parachute (postjam)",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(10))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height + 3}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "R to RESTART",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(10))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height + 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "F to CHEAT",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(10))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height - 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "Left/Right to CHANGE SKIN",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height + 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "12345 to emote",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(90))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height - 0.5}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
                font.Font.draw(
                    &self^.assets.font,
                    "Space to SCALE",
                    .matrix = Mat4.rotate_z(Angle.from_degrees(-170))
                        |> Mat4.mul_mat(Mat4.translate({ 0, distance, height}))
                        |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90))),
                    .color = { 0, 0, 0, 1 },
                    .align = 0.5,
                );
            );
            font.Font.draw(
                &self^.assets.font,
                to_string(self^.server_meta.score.0) + ":" + to_string(self^.server_meta.score.1),
                .matrix = Mat4.translate({ -67.035286, -176.572922, 30.826015 })
                    |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(90)))
                    |> Mat4.mul_mat(Mat4.scale_uniform(5)),
                .color = { 0, 0, 0, 1 },
                .align = 0.5,
            );

            with geng.CameraUniforms.Ctx = geng.CameraUniforms.init(
                {
                    .position = { 0, 0, 0 },
                    .rotation = Angle.from_degrees(90),
                    .attack = Angle.from_degrees(90),
                    .fov = Angle.from_degrees(90),
                    .distance = 10,
                },
                .framebuffer_size = geng.get_window_size(),
            );
            if not self^.connected then (
                font.Font.draw(
                    &self^.assets.font,
                    "disconnected",
                    .matrix = Mat4.translate({ 0, 9.2, 0}),
                    .color = {1, 0, 0, 1},
                    .align = 0.5,
                );
            );
            if self^.show_timer then (
                let time :: Option.t[Float32] = match self^.timer with (
                    | :Working t => :Some t
                    | :Win t => :Some t
                    | _ => :None
                );
                let color = if self^.cheated then { 1, 0, 0, 1 } else { 0, 0, 0, 1 };
                if self^.timer is :Win _ then (
                    font.Font.draw(
                        &self^.assets.font,
                        "YOU HAVE SCALED THE MOUNTAIN",
                        .matrix = Mat4.translate({ 0, 5, 0})
                            |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(10))),
                        .color,
                        .align = 0.5,
                    );
                    font.Font.draw(
                        &self^.assets.font,
                        to_string(collected_scales) + " dragon scales collected",
                        .matrix = Mat4.translate({ 0, -1, 0}),
                        .color,
                        .align = 0.5,
                    );
                    if self^.cheated then (
                        font.Font.draw(
                            &self^.assets.font,
                            "with cheats",
                            .matrix = Mat4.translate({ 0, 4, 0}),
                            .color,
                            .align = 0.5,
                        );
                    );

                    font.Font.draw(
                        &self^.assets.font,
                        "press H to hide",
                        .matrix = Mat4.translate({ 0, 2, 0}),
                        .color,
                        .align = 0.5,
                    );
                );
                if time is :Some t then (
                    font.Font.draw(
                        &self^.assets.font,
                        (
                            let seconds :: Int32 = @native "\(t)";
                            let minutes = seconds / 60;
                            let seconds = seconds % 60;
                            to_string(minutes)
                            + ":"
                            + to_string(seconds / 10)
                            + to_string(seconds % 10)
                        ),
                        .matrix = Mat4.translate({ 0, 7, 0})
                            |> Mat4.mul_mat(Mat4.rotate_x(Angle.from_degrees(20)))
                            |> Mat4.mul_mat(Mat4.scale_uniform(2)),
                        .color,
                        .align = 0.5,
                    );
                );
                FpsCounter.frame(&mut self^.fps_counter);
                let fps = FpsCounter.fps(&self^.fps_counter);
                let fps = Float32_to_Int32(fps);
                @native "glDisable(GL_DEPTH_TEST)";
                with_return (
                    let power_text = match self^.player.power with (
                        | :None => return
                        | :Parachute _ => "parachute"
                        | :Jetpack _ => "jetpack"
                        | :Antigravity _ => "antigravity"
                        | :BeachballVertical _ => "beachball vertical hit"
                    );
                    font.Font.draw(
                        &self^.assets.font,
                        "postjam power: " + power_text,
                        .matrix = Mat4.translate({ 2, -9.5, 0})
                            |> Mat4.mul_mat(Mat4.scale_uniform(0.5)),
                        .color = { 0, 0, 0, 1 },
                        .align = 0,
                    );
                );
                with_return (
                    let text = match self^.control_mode with (
                        | :RelativeToCamera => return
                        | :RelativeToFace => "controls relative to face"
                    );
                    font.Font.draw(
                        &self^.assets.font,
                        text,
                        .matrix = Mat4.translate({ 2, -8.5, 0})
                            |> Mat4.mul_mat(Mat4.scale_uniform(0.5)),
                        .color = { 0, 0, 0, 1 },
                        .align = 0,
                    );
                );
                font.Font.draw(
                    &self^.assets.font,
                    "FPS: " + to_string(fps),
                    .matrix = Mat4.translate({ -2, -9.5, 0})
                        |> Mat4.mul_mat(Mat4.scale_uniform(0.5)),
                    .color = { 0, 0, 0, 1 },
                    .align = 1,
                );
                @native "glEnable(GL_DEPTH_TEST)";
            );
        ),
        .update = (self, delta_time) => with_return (
            let delta_time = min(delta_time, 0.050);
            self^.next_fire_particle -= delta_time;
            if self^.next_fire_particle < 0 then (
                self^.next_fire_particle = 1 / 5;
                for &pos in &FIREPLACES |> ArrayList.iter do (
                    if Vec3.length(Vec3.sub(pos, self^.player.position)) < 20 then (
                        const rng = () => std.random.gen_range(.min = -0.5, .max = 0.5);
                        let particle = {
                            .position = Vec3.add(pos, { rng(), rng(), rng() }),
                            .t = 0,
                            .texture = self^.assets.textures.fire,
                        };
                        &mut self^.particles |> ArrayList.push_back(particle);
                    );
                );
            );
            if self^.dead then (
                self^.dead_timer += delta_time;
                if self^.dead_timer > 1 then (
                    restart(self);
                );
            );
            for p in &mut self^.particles |> ArrayList.iter_mut do (
                p^.t += delta_time;
            );
            const swap = [T] (a :: &mut T, b :: &mut T) => (
                let t = a^;
                a^ = b^;
                b^ = t;
            );
            const retain = [T] (a :: &mut ArrayList.t[T], predicate :: &T -> Bool) => (
                let mut i = 0;
                while i < ArrayList.length(&a^) do (
                    if not predicate(&a^.[i]) then (
                        swap(
                            a |> ArrayList.at_mut(i),
                            a |> ArrayList.at_mut(ArrayList.length(&a^) - 1),
                        );
                        a |> ArrayList.pop_back();
                    );
                    i += 1;
                );
            );
            retain(&mut self^.particles, p => p^.t < 1);
            const MUSIC_FADE_TIME = 5;
            geng.audio.Effect.set_volume(
                self^.assets.music,
                (
                    let target_volume = if self^.player.position.2 < 67 then 1 else 0;
                    let current_volume = geng.audio.Effect.get_volume(self^.assets.music)
                        / MUSIC_VOLUME;
                    let max_delta = min(1, delta_time / MUSIC_FADE_TIME);
                    current_volume + clamp(
                        target_volume - current_volume,
                        .min = -max_delta,
                        .max = max_delta,
                    )
                )
                    * MUSIC_VOLUME * self^.music_volume,
            );
            geng.audio.Effect.set_volume(
                self^.assets.music_high,
                (
                    let target_volume = if self^.player.position.2 > 74 then 1 else 0;
                    let current_volume = geng.audio.Effect.get_volume(self^.assets.music_high)
                        / MUSIC_VOLUME;
                    let max_delta = min(1, delta_time / MUSIC_FADE_TIME);
                    current_volume + clamp(
                        target_volume - current_volume,
                        .min = -max_delta,
                        .max = max_delta,
                    )
                )
                    * MUSIC_VOLUME * self^.music_volume,
            );
            for &mut { .key = _, .value = ref mut o } in &mut self^.other_players |> OrdMap.iter_mut do (
                OtherPlayer.update(o, delta_time);
            );
            if self^.timer is :Win _ then () else (
                for scale in &mut self^.dragon_scales |> ArrayList.iter_mut do (
                    if scale^.collected then continue;
                    if Vec3.length(Vec3.sub(self^.player.position, scale^.position)) < self^.player.scale + 1 then (
                        geng.audio.play(self^.assets.sfx.collect);
                        scale^.collected = true;
                        for (_ :: Int32) in 0..10 do (
                            const rng = () => std.random.gen_range(.min = -1, .max = 1);
                            let particle = {
                                .position = Vec3.add(
                                    scale^.position,
                                    Vec3.mul(Vec3.normalize({ rng(), rng(), rng() }), 2),
                                ),
                                .t = 0.5,
                                .texture = self^.assets.textures.sparkle,
                            };
                            &mut self^.particles |> ArrayList.push_back(particle);
                        );
                    );
                );
            );
            self^.next_send -= delta_time;
            if self^.next_send < 0 then (
                self^.next_send = 1 / 10;
                send_update(self);
            );
            if self^.timer is :Working ref mut time then (
                time^ += delta_time;
            );
            handle_mmo(self);
            geng.audio.Effect.set_volume(self^.jetpack_sfx, if self^.jetpack_enabled then 0.5 else 0);
            if Vec3.length(Vec3.sub(self^.player.position, FINISH)) < self^.player.scale then (
                if self^.timer is :Working t then (
                    geng.audio.play(self^.assets.sfx.win);
                    badcop.beat_game(Float32_to_Int32(t));
                    self^.timer = :Win t;
                );
            );
            if self^.jetpack_enabled then (
                match self^.timer with (
                    | :Win _ => ()
                    | _ => (
                        self^.cheated = true;
                    )
                )
            );
            if false and self^.jetpack_enabled then (
                let disable = match self^.timer with (
                    | :WaitForMove => true
                    | :Working _ => true
                    | _ => false
                );
                if disable then (
                    self^.timer = :Disabled;
                );
            );
            let mut wasd :: Vec2 = { 0, 0 };
            if geng.input.Key.is_pressed(:W) or geng.input.Key.is_pressed(:ArrowUp) then (
                wasd.0 += 1;
            );
            if geng.input.Key.is_pressed(:A) or geng.input.Key.is_pressed(:ArrowLeft) then (
                wasd.1 += 1;
            );
            if geng.input.Key.is_pressed(:S) or geng.input.Key.is_pressed(:ArrowDown) then (
                wasd.0 -= 1;
            );
            if geng.input.Key.is_pressed(:D) or geng.input.Key.is_pressed(:ArrowRight) then (
                wasd.1 -= 1;
            );
            if Vec2.length(wasd) > 0.1 then (
                if self^.timer is :WaitForMove then (
                    self^.timer = :Working 0;
                );
                self^.player.flat_rot = Angle.add(Vec2.arg(wasd), self^.camera.rotation);
            );
            let player_input = {
                .wasd,
                .space = is_jump_pressed(),
                .shift = geng.input.Key.is_pressed(:LeftShift),
                .use_power = geng.input.MouseButton.is_pressed(:Right),
                .jetpack_enabled = self^.jetpack_enabled,
                .control_mode = self^.control_mode,
            };
            Entity.update_input(self, &mut self^.player, delta_time, player_input);
            let beachball_input = {
                .wasd = { 0, 0 },
                .space = true,
                .shift = false,
                .use_power = true,
                .jetpack_enabled = false,
                .control_mode = :RelativeToCamera,
            };
            Entity.update_input(self, &mut self^.beachball.old, delta_time, beachball_input);
            Entity.update_input(self, &mut self^.beachball.new, delta_time, beachball_input);
            self^.next_physics -= delta_time;
            while self^.next_physics < -0.0001 do (
                const MAX_DISTANCE_A_FRAME = 0.2;
                let max_delta_time = MAX_DISTANCE_A_FRAME / max(Vec3.length(self^.player.velocity), 0.1);
                let step = min(max_delta_time, -self^.next_physics);
                self^.next_physics += step;
                update_step(self, &mut self^.player, step, .score_beachball = false);
                update_step(self, &mut self^.beachball.old, step, .score_beachball = false);
                (
                    let pos = self^.beachball.current.position;
                    let side = beachball_side(pos);
                    if self^.beachball.scoring is :WaitingToCrossTheNet { .serving_side } then (
                        if serving_side == 0 then (
                            self^.beachball.scoring = :WaitingToCrossTheNet { .serving_side = side };
                        ) else if side != 0 and serving_side != side then (
                            self^.beachball.scoring = :CanScore { .last_touched_side = serving_side };
                        );
                    );
                    update_step(self, &mut self^.beachball.new, step, .score_beachball = true);
                );
                self^.beachball.current = (
                    self^.beachball.lerp = min(1, self^.beachball.lerp + step / 0.3);
                    let k_old = 1 - self^.beachball.lerp;
                    let k_new = self^.beachball.lerp;
                    let old = &self^.beachball.old;
                    let new = &self^.beachball.new;
                    {
                        ...self^.beachball.current,
                        .position = Vec3.add(
                            Vec3.mul(old^.position, k_old),
                            Vec3.mul(new^.position, k_new),
                        ),
                        .velocity = Vec3.add(
                            Vec3.mul(old^.velocity, k_old),
                            Vec3.mul(new^.velocity, k_new),
                        ),
                        .angular_velocity = Vec3.add(
                            Vec3.mul(old^.angular_velocity, k_old),
                            Vec3.mul(new^.angular_velocity, k_new),
                        ),
                        .rotation = Quat.add(
                            Quat.mul(old^.rotation, k_old),
                            Quat.mul(new^.rotation, k_new),
                        )
                            |> Quat.normalize,
                    }
                );
                let entity = e => {
                    .position = &mut e^.position,
                    .velocity = &mut e^.velocity,
                    .angular_velocity = &mut e^.angular_velocity,
                    .radius_change_speed = e^.scale_speed,
                    .radius = e^.scale,
                    .inverse_mass = 1 / e^.mass,
                };
                if collisions.collide_and_react_entities(
                    entity(&mut self^.player),
                    entity(&mut self^.beachball.current),
                ) is :Some result then (
                    if self^.beachball.scoring is :CanScore { .last_touched_side = ref mut last_touched_side } then (
                        last_touched_side^ = if self^.beachball.current.position.0 < (include_ast BEACHBALL_NET_X) then 1 else -1;
                    );
                    let vertical = true;
                    # if self^.player.power is :BeachballVertical { .active } then active else false;
                    if vertical then (
                        self^.beachball.current.velocity.2 += 30 * min(
                            abs(result.velocity_along_normal) / player_speed,
                            1,
                        );
                    );
                    self^.beachball = {
                        .old = self^.beachball.current,
                        .current = self^.beachball.current,
                        .new = self^.beachball.current,
                        .scoring = self^.beachball.scoring,
                        .lerp = 1,
                    };
                    let volume = min(abs(result.velocity_along_normal) / player_speed * 4, 1);
                    if volume > 0.1 then (
                        geng.audio.play_with(
                            self^.assets.sfx.volleyball,
                            { .volume, .@"loop" = false },
                        );
                    );
                    self^.send_beachball_update = true;
                );
            );
        ),
        .handle_event = (self, event) => (
            match event with (
                | :KeyPress :Digit1 => (
                    emote(self, self^.player.position, 0);
                    badcop.emote(0);
                )
                | :KeyPress :Digit2 => (
                    emote(self, self^.player.position, 1);
                    badcop.emote(1);
                )
                | :KeyPress :Digit3 => (
                    emote(self, self^.player.position, 2);
                    badcop.emote(2);
                )
                | :KeyPress :Digit4 => (
                    emote(self, self^.player.position, 3);
                    badcop.emote(3);
                )
                | :KeyPress :Digit5 => (
                    emote(self, self^.player.position, 4);
                    badcop.emote(4);
                )
                | :KeyPress :PageUp => (
                    self^.sens = self^.sens * 1.2;
                )
                | :KeyPress :PageDown => (
                    self^.sens = self^.sens / 1.2;
                )
                | :KeyPress :R => (
                    restart(self);
                )
                | :KeyPress :C => (
                    self^.control_mode = match self^.control_mode with (
                        | :RelativeToCamera => :RelativeToFace
                        | :RelativeToFace => :RelativeToCamera
                    );
                )
                | :KeyPress :F => (
                    self^.jetpack_enabled = not self^.jetpack_enabled;
                )
                | :KeyPress :ArrowLeft => (
                    let len = ArrayList.length(&self^.assets.models.skins);
                    self^.player.skin = (self^.player.skin + len - 1) % len;
                )
                | :KeyPress :ArrowRight => (
                    self^.player.skin = (self^.player.skin + 1) % ArrayList.length(&self^.assets.models.skins);
                )
                | :KeyPress :K => (
                    print(to_string(self^.player.position));
                )
                | :KeyPress :H => (
                    self^.show_timer = not self^.show_timer;
                )
                | :KeyPress :Digit0 => (
                    badcop.reset_beachball_score();
                )
                | :KeyPress :M => (
                    self^.music_volume = 1 - self^.music_volume;
                )
                | :KeyPress :L => (
                    self^.draw_player = not self^.draw_player;
                )
                | :KeyPress :I => (
                    let mut e = self^.beachball.current;
                    e.position = Vec3.add(
                        self^.player.position,
                        { ...Vec2.rotate({ 5, 0 }, self^.camera.rotation), 10 },
                    );
                    e.velocity = { 0, 0, 0 };
                    e.rotation = Quat.IDENTITY;
                    e.angular_velocity = { 0, 0, 0 };
                    self^.beachball = {
                        .old = e,
                        .current = e,
                        .new = e,
                        .scoring = :WaitingToCrossTheNet { .serving_side = 0 },
                        .lerp = 1,
                    };
                    self^.send_beachball_update = true;
                )
                | :KeyPress :P => if false then (
                    self^.power_index = (self^.power_index + 1) % 3;
                    if self^.power_index == 0 then (
                        self^.player.power = :None;
                    ) else if self^.power_index == 1 then (
                        self^.player.power = :Parachute {
                            .active = false,
                            .rotation = Quat.IDENTITY,
                        };
                    ) else if self^.power_index == 2 then (
                        self^.player.power = :Jetpack {
                            .active = true,
                            .next_particle = 0,
                            .sfx = :None,
                        };
                    ) else if self^.power_index == 3 then (
                        self^.player.power = :BeachballVertical { .active = false };
                    ) else panic("TOO BIG POWER INDEX");
                )
                | :KeyPress :Enter => (
                    geng.toggle_fullscreen();
                )
                | :MousePress _ => (
                    SDL.SetWindowRelativeMouseMode((@current geng.Context).window, true);
                )
                | :MouseMove { .delta, ... } => (
                    let degree_per_pixel :: Float32 = 360 / 2000;
                    let delta = Vec2.mul(delta, self^.sens);
                    self^.camera.rotation = Angle.sub(
                        self^.camera.rotation,
                        Angle.from_degrees(delta.0 * degree_per_pixel),
                    );
                    self^.camera.attack = Angle.from_degrees(
                        clamp(
                            Angle.degrees(self^.camera.attack)
                            - delta.1 * degree_per_pixel,
                            .min = -90,
                            .max = 90,
                        )
                    );
                )
                | _ => ()
            );
        ),
    }
);

const cli = import "./cli.ks";

let args = cli.parse();
@comment_out (
if args.server is :Some address then (
    const server = import "./server.ks";
    let run = () => server.run(address);
    match args.connect with (
        | :None => (
            run();
        )
        | :Some _ => (
            std.thread.spawn(run);
        )
    );
);
);
if args.connect is :Some address then (
    badcop.init(address);
    badcop.set_name("<todo name>");
    # let c = client.connect(address);
    # with client.Ctx = c;
    geng.run[Game]();
);
