const Vec2 = newtype { Float32, Float32 };

impl Vec2 as module = (
    module:

    const add = (a :: Vec2, b :: Vec2) -> Vec2 => (
        { a.0 + b.0, a.1 + b.1 }
    );

    const sub = (a :: Vec2, b :: Vec2) -> Vec2 => (
        { a.0 - b.0, a.1 - b.1 }
    );

    const mul = (v :: Vec2, k :: Float32) -> Vec2 => (
        { v.0 * k, v.1 * k }
    );

    const div = (v :: Vec2, k :: Float32) -> Vec2 => (
        { v.0 / k, v.1 / k }
    );

    const vmul = (a :: Vec2, b :: Vec2) -> Vec2 => (
        { a.0 * b.0, a.1 * b.1 }
    );

    const vdiv = (a :: Vec2, b :: Vec2) -> Vec2 => (
        { a.0 / b.0, a.1 / b.1 }
    );

    const map = (v :: Vec2, f :: Float32 -> Float32) -> Vec2 => (
        { f(v.0), f(v.1) }
    );

    const rotate_90 = (v :: Vec2) -> Vec2 => (
        { -v.1, v.0 }
    );

    const rotate = (v :: Vec2, angle :: Angle) -> Vec2 => (
        let { sin, cos } = Angle.sin_cos(angle);
        { v.0 * cos - v.1 * sin, v.0 * sin + v.1 * cos }
    );

    const dot = (a :: Vec2, b :: Vec2) -> Float32 => (
        a.0 * b.0 + a.1 * b.1
    );

    const length2 = (v :: Vec2) -> Float32 => (
        dot(v, v)
    );

    const length = (v :: Vec2) -> Float32 => (
        math.sqrt(length2(v))
    );

    const normalize_or_zero = (v :: Vec2) -> Vec2 => (
        if abs(v.0) + abs(v.1) < EPS then (
            v
        ) else (
            normalize(v)
        )
    );

    const normalize = (v :: Vec2) -> Vec2 => (
        div(v, length(v))
    );

    const arg = ({ x, y } :: Vec2) -> Angle => (
        { .radians = math.atan2(y, x) }
    );
);
