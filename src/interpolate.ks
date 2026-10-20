use (import "./__deps__.ks").*;

module:

const Interpolatable = [Self] newtype {
    .add :: (Self, Self) -> Self,
    .mul :: (Self, Float32) -> Self,
    .sub :: (Self, Self) -> Self,
    .lerp :: (Self, Self, Float32) -> Self,
};

impl Float32 as Interpolatable = {
    .add = std.op.add[Float32],
    .mul = std.op.mul[Float32],
    .sub = std.op.sub[Float32],
    .lerp = (a, b, t) => a * (1 - t) + b * t,
};

impl Vec3 as Interpolatable = {
    .add = Vec3.add,
    .mul = Vec3.mul,
    .sub = Vec3.sub,
    .lerp = (a, b, t) => Vec3.add(Vec3.mul(a, 1 - t), Vec3.mul(b, t)),
};

impl Quat as Interpolatable = {
    .add = Quat.add,
    .mul = Quat.mul,
    .sub = Quat.sub,
    .lerp = (a, b, t) => Quat.normalize(Quat.add(Quat.mul(a, 1 - t), Quat.mul(b, t))),
};
