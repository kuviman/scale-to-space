use (import "./lib/common.ks").*;

module:

const Args = newtype {
    .server :: Option.t[String],
    .connect :: Option.t[String],
    .vsync :: Bool,
};

const default_address = "127.0.0.1:1234";

const parse = () -> Args => with_return (
    let mut result :: Args = {
        .server = :None,
        .connect = :None,
        .vsync = true,
    };
    if is_emscripten() then (
        result.connect = :Some default_address;
        return result;
    );
    let mut i = 1;
    while i < std.sys.argc() do (
        let arg = std.sys.argv_at(i);
        if arg == "--server" then (
            let address = std.sys.argv_at(i + 1);
            result.server = :Some address;
            i += 2;
            continue;
        );
        if arg == "--connect" then (
            let address = std.sys.argv_at(i + 1);
            result.connect = :Some address;
            i += 2;
            continue;
        );
        if arg == "--vsync" then (
            let value = std.sys.argv_at(i + 1);
            result.vsync = if value == "true" then (
                true
            ) else if value == "false" then (
                false
            ) else (
                panic("true or false for vsync pls")
            );
            i += 2;
            continue;
        );
        panic("Unexpected arg " + arg);
    );
    if { result.server, result.connect } is { :None, :None } then (
        result.connect = :Some default_address;
    );
    result
);
