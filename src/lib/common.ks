module:

use std.collections.OrdMap;

const json = import "../../deps/json/lib.ks";

const EPS :: Float32 = 0.0000001;

const UInt32_to_Int32 = (x :: UInt32) -> Int32 => @native "\(x)";
const Int32_to_UInt32 = (x :: Int32) -> UInt32 => @native "\(x)";
const Int32_to_Float32 = (x :: Int32) -> Float32 => @native "\(x)";
const UInt32_to_Float32 = (x :: UInt32) -> Float32 => @native "\(x)";
const UInt64_to_Float32 = (x :: UInt64) -> Float32 => @native "\(x)";
const Float64_to_Float32 = (x :: Float64) -> Float32 => @native "\(x)";
const Float32_to_Int32 = (x :: Float32) -> Int32 => @native "\(x)";

const is_emscripten = () -> Bool => @native ''
    #ifdef __EMSCRIPTEN__
        true
    #else
        false
    #endif
'';

const yield = () => (
    @native ''
        #if defined(__EMSCRIPTEN__) && defined(GC_ON_INTERVAL_EMSCRIPTEN)
            emscripten_sleep(0)
        #else
            (Unit){}
        #endif
    '';
);

const fetch_string = (path :: String) -> String => (
    std.fs.read_file(path)
);

const abs = (x :: Float32) -> Float32 => (
    if x < 0 then (
        -x
    ) else (
        x
    )
);

const min = (a :: Float32, b :: Float32) -> Float32 => (
    if a < b then a else b
);

const max = (a :: Float32, b :: Float32) -> Float32 => (
    if a > b then a else b
);

const clamp = (x :: Float32, .min :: Float32, .max :: Float32) -> Float32 => (
    if x < min then min else if x > max then max else x
);

const clamp_int = (x :: Int32, .min :: Int32, .max :: Int32) -> Int32 => (
    if x < min then min else if x > max then max else x
);

const math = import "./math.ks";
