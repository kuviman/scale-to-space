module:

use (
    const geng_lib_path = (
        let geng_path = std.sys.get_env("GENG_PATH")
            |> Option.unwrap();
        format!("file://\(geng_path)/src/_lib.ks")
    );
    import (&geng_lib_path |> as_str)
).*;

# use (import "env://GENG_PATH/src/_lib.ks").*;

const sqr = [T] (x :: T) -> T => x * x;

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
