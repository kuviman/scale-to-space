use (import "./common.ks").*;
use (import "./la/_lib.ks").*;
const gl = import "./gl/_lib.ks";
const ugli = import "./ugli/_lib.ks";
const geng = import "./geng/_lib.ks";
use std.collections.OrdMap;

module:

const TilePos = Vec2;

const RangeConfig = newtype {
    .start :: Char,
    .end :: Char,
    .at :: TilePos,
};

const Config = newtype {
    .tile_size :: Vec2,
    .kerning :: Float32,
    .space_size :: Float32,
    .chars :: OrdMap.t[Char, TilePos],
    .ranges :: ArrayList.t[RangeConfig],
};

impl Config as module = (
    module:

    const parse = (s :: String) -> Config => (
        let get_char = (value :: json.Value) -> Char => (
            match value with (
                | :String s => String.at(s, 0)
                | _ => panic("expected char")
            )
        );
        let get_float32 = (value :: json.Value) -> Float32 => (
            match value with (
                | :Number number => number
                    |> json.Number.into_f64
                    |> Float64_to_Float32
                | _ => panic("expected number")
            )
        );
        let get_field = (
            json :: &json.Value,
            field :: String,
        ) -> &json.Value => with_return (
            match json^ with (
                | :Object ref pairs => (
                    for &{ key, ref value } in pairs |> ArrayList.iter do (
                        if key == field then (
                            return value;
                        );
                    );
                    panic("no field " + field)
                )
                | _ => panic("expected json obj")
            )
        );
        let get_vec2 = (value :: json.Value) -> Vec2 => (
            match value with (
                | :Array list => (
                    { list.[0] |> get_float32, list.[1] |> get_float32 }
                )
                | _ => panic("expected list for vec2")
            )
        );
        let json = json.parse(&mut json.Reader.create(&s)) |> Result.unwrap;
        {
            .tile_size = get_field(&json, "tile_size")^
                |> get_vec2,
            .kerning = get_field(&json, "kerning")^
                |> get_float32,
            .space_size = get_field(&json, "space_size")^
                |> get_float32,
            .chars = (
                let mut chars = OrdMap.new();
                match get_field(&json, "chars")^ with (
                    | :Object ref pairs => (
                        for &{ key, value } in pairs |> ArrayList.iter do (
                            let c = String.at(key, 0);
                            let tile_pos = value |> get_vec2;
                            &mut chars |> OrdMap.add(c, tile_pos);
                        );
                    )
                    | _ => panic("chars must be obj")
                );
                chars
            ),
            .ranges = (
                let mut result = ArrayList.new();
                match get_field(&json, "ranges")^ with (
                    | :Array ref list => (
                        for range in list |> ArrayList.iter do (
                            let range = {
                                .start = get_field(range, "start")^ |> get_char,
                                .end = get_field(range, "end")^ |> get_char,
                                .at = get_field(range, "at")^ |> get_vec2,
                            };
                            &mut result |> ArrayList.push_back(range);
                        );
                    )
                    | _ => panic("ranges must be array")
                );
                result
            ),
        }
    );
);

const UvRect = newtype {
    .pos :: Vec2,
    .size :: Vec2,
};

const Font = newtype {
    .config :: Config,
    .unit_space_size :: Float32,
    .texture :: ugli.Texture,
    .chars :: OrdMap.t[Char, UvRect],
    .program :: ugli.Program,
};

const single_char = (s :: String) -> Char => (
    if s |> String.length != 1 then (
        panic("c.length != 1");
    );
    s |> String.at(0)
);

impl Font as module = (
    module:

    const load = (path :: String) -> Font => (
        let config :: Config = fetch_string(path + "/config.json") |> Config.parse;
        let texture = geng.load_texture(path + "/texture.png", :Nearest);
        let mut chars = OrdMap.new();
        let tile_size_uv = Vec2.vdiv(config.tile_size, texture.size);
        let uv_rect = (tile_pos :: Vec2) -> UvRect => {
            .pos = Vec2.vdiv(Vec2.vmul(tile_pos, config.tile_size), texture.size),
            .size = tile_size_uv,
        };
        let texture_size_tiles = Vec2.vdiv(texture.size, config.tile_size);
        let add_c = (c :: Char, tile_pos :: Vec2) => (
            let tile_pos :: Vec2 = {
                tile_pos.0,
                texture_size_tiles.1 - 1 - tile_pos.1,
            };
            # dbg.print(.c, .tile_pos, .uv_rect = uv_rect(tile_pos));
            &mut chars
                |> OrdMap.add(c, uv_rect(tile_pos));
        );
        for &{ .key = c, .value = tile_pos } in &config.chars |> OrdMap.iter do (
            add_c(c, tile_pos);
        );
        for &range in &config.ranges |> ArrayList.iter do (
            let mut tile_pos = range.at;
            for c in Char.code(range.start)..Char.code(range.end) + 1 do (
                add_c(Char.from_code(c), tile_pos);
                tile_pos.0 += 1;
            );
        );
        let program = geng.load_shader("assets/shaders/font");
        {
            .unit_space_size = config.space_size / config.tile_size.1,
            .config,
            .texture,
            .chars,
            .program,
        }
    );

    const measure = (font :: &Font, text :: String) -> Float32 => (
        let size :: Float32 = 1;
        let tile_size = font^.config.tile_size;
        let single_char_size = Vec2.mul({ tile_size.0 / tile_size.1, 1 }, size);
        let mut result = 0;
        for c in String.iter(text) do (
            if c == ' ' then (
                result += font^.unit_space_size * size;
                continue;
            );
            result += single_char_size.0;
        );
        result
    );

    const draw = (
        font :: &Font,
        text :: String,
        .matrix :: Mat4,
        .color :: Vec4,
        .align :: Float32,
    ) => (
        let ctx = (@current geng.Context);
        let camera = (@current geng.CameraUniforms.Ctx);
        let program = font^.program;
        program |> ugli.Program.@"use";

        let mut draw_state = ugli.DrawState.init();
        let draw_state = &mut draw_state;

        program |> ugli.set_vertex_data_source(ctx.quad.buffer);

        program |> ugli.set_uniform("u_view_matrix", camera.view_matrix, draw_state);
        program |> ugli.set_uniform("u_projection_matrix", camera.projection_matrix, draw_state);
        program |> ugli.set_uniform("u_model_matrix", matrix, draw_state);
        program |> ugli.set_uniform("u_texture", font^.texture, draw_state);
        program |> ugli.set_uniform("u_color", color, draw_state);

        let tile_size = font^.config.tile_size;
        let single_char_size :: Vec2 = { tile_size.0 / tile_size.1, 1 };
        let mut pos :: Vec2 = { -measure(font, text) * align, 0 };
        for c in text |> String.iter do (
            if c == ' ' then (
                pos.0 += font^.unit_space_size;
                continue;
            );
            match &font^.chars |> OrdMap.get(c) with (
                | :None => panic(
                    "Char "
                    + to_string(c)
                    + "("
                    + to_string(Char.code(c))
                    + ") is not in font"
                )
                | :Some (&uv) => (
                    program |> ugli.set_uniform("u_uv_rect_pos", uv.pos, draw_state);
                    program |> ugli.set_uniform("u_uv_rect_size", uv.size, draw_state);
                )
            );
            program |> ugli.set_uniform("u_pos", pos, draw_state);
            gl.draw_arrays(gl.TRIANGLE_FAN, 0, 4);

            pos.0 += single_char_size.0;
        );
    );
);
