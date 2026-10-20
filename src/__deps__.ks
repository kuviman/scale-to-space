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

