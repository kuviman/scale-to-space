# use (import "env://GENG_PATH/src/_lib.ks").*;
const deps = (
    const geng_lib_path = (
        let geng_path = std.sys.get_env("GENG_PATH")
            |> Option.unwrap();
        format!("file://\(geng_path)/src/_lib.ks")
    );
    import (&geng_lib_path |> as_str)
);

module:

use deps.*;

const math = (
    module:

    use deps.math.*;

    const log = (x :: Float32) -> Float32 => (
        @native "logf(\(x))"
    );
    const acos = (x :: Float32) -> Float32 => (
        @native "acosf(\(x))"
    );
    const asin = (x :: Float32) -> Float32 => (
        @native "asinf(\(x))"
    );
    const atan = (x :: Float32) -> Float32 => (
        @native "atanf(\(x))"
    );
    const sqr = [T] (x :: T) -> T => x * x;

    const floor = (x :: Float32) -> Int32 => (
        @native "floorf(\(x))"
    );
    const ceil = (x :: Float32) -> Int32 => (
        @native "ceilf(\(x))"
    );
);

const solve_quadratic = (
    a :: Float32,
    b :: Float32,
    c :: Float32,
) -> { Float32, Float32 } => (
    let d = b * b - 4 * a * c;
    let sqrt_d = math.sqrt(max(d, 0));
    {
        (-b - sqrt_d) / (2 * a),
        (-b + sqrt_d) / (2 * a),
    }
);

const binary_search = (
    ._in :: Float32,
    .out :: Float32,
    .is_in :: Float32 -> Bool,
) -> Float32 => (
    let mut _in = _in;
    let mut out = out;
    for _ in 0..40 do (
        let mid = (_in + out) / 2;
        if is_in(mid) then (
            _in = mid;
        ) else (
            out = mid;
        );
    );
    _in
);
