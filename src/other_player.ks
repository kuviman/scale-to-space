use (import "./interpolate.ks").*;

const Interpolated = [T] newtype {
    .value :: T,
    .target_value :: T,
    .time_remaining :: Float32,
};

const init_interpolated = [T] (value :: T) -> Interpolated[T] => {
    .value,
    .target_value = value,
    .time_remaining = 0,
};

const update_interpolated = [T] (
    self :: &mut Interpolated[T],
    delta_time :: Float32,
) => (
    let delta_time = min(delta_time, self^.time_remaining);
    if self^.time_remaining > 0.0001 then (
        self^.value = (T as Interpolatable).lerp(
            self^.value,
            self^.target_value,
            delta_time / self^.time_remaining,
        );
        self^.time_remaining -= delta_time;
    );
);

const update_interpolated_net = [T] (
    self :: &mut Interpolated[T],
    new_value :: T,
    new_speed :: T,
) => (
    let predicted_value = (T as Interpolatable).add(
        new_value,
        (T as Interpolatable).mul(new_speed, PREDICTION_T),
    );
    self^.target_value = predicted_value;
    self^.time_remaining = PREDICTION_T;
);

const OtherPlayer = newtype {
    .skin :: Int32,
    .position :: Interpolated[Vec3],
    .rotation :: Interpolated[Quat],
    .scale :: Interpolated[Float32],
    .jetpack :: Bool,
    .flat_rot :: Angle,
    .vel :: Vec3,
};

const PREDICTION_T :: Float32 = 0.3;

impl OtherPlayer as module = (
    module:

    const new = () -> OtherPlayer => {
        .skin = 0,
        .position = init_interpolated({ 0, 0, 0 }),
        .rotation = init_interpolated(Quat.IDENTITY),
        .scale = init_interpolated(0),
        .jetpack = false,
        .flat_rot = Angle.from_degrees(0),
        .vel = { 0, 0, 0 },
    };

    const update_net = (self :: &mut OtherPlayer, data :: badcop.PlayerData) => (
        update_interpolated_net(&mut self^.position, data.position, data.velocity);
        update_interpolated_net(&mut self^.rotation, data.rotation, Quat.ZERO);
        update_interpolated_net(&mut self^.scale, data.scale, 0);
        self^.skin = data.skin;
        self^.jetpack = data.jetpack;
    );

    const update = (self :: &mut OtherPlayer, delta_time :: Float32) => (
        update_interpolated(&mut self^.position, delta_time);
        update_interpolated(&mut self^.rotation, delta_time);
        update_interpolated(&mut self^.scale, delta_time);
        if self^.position.time_remaining > 0.001 then (
            self^.vel = Vec3.div(
                Vec3.sub(self^.position.target_value, self^.position.value),
                self^.position.time_remaining,
            );
        ) else (
            self^.vel = { 0, 0, 0 };
        );
        let xy = Vec3.xy(self^.vel);
        if abs(xy.0) + abs(xy.1) > 0.001 then (
            self^.flat_rot = Vec2.arg(xy);
        );
    );

    const draw = (self :: &OtherPlayer) => (
        draw_skin(
            self^.skin,
            self^.position.value,
            self^.vel,
            clamp(self^.scale.value, .min = 1, .max = 2),
            self^.flat_rot,
            self^.rotation.value,
            .jetpack = self^.jetpack,
            .power = :None,
            .volley = false,
        );
    );
);
