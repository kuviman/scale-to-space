use (import "../common.ks").*;
use (import "../la/_lib.ks").*;
const gl = import "../gl/_lib.ks";
const ugli = import "../ugli/_lib.ks";
const SDL = import "../sdl3/_lib.ks";

module:

const geng = @current_scope;

const asset = import "./asset.ks";
const audio = import "./audio.ks";
const input = (include "./input.ks");

use input.Event;

use (import "./camera.ks").*;

const Vertex = newtype {
    .a_pos :: Vec2,
    .a_uv :: Vec2,
};

include_ast ugli.Vertex_derive(Vertex);

const ContextT = newtype {
    .window :: SDL.Window,
    .gl_context :: SDL.GL.Context,
    .quad :: {
        .program :: ugli.Program,
        .buffer :: ugli.VertexBuffer.t[Vertex],
    },
};
const Context = @context ContextT;

const log = print;

const init = () -> { .geng :: ContextT, .gl :: gl.ContextT } => (
    log("Initializing");
    SDL.Init(@native "SDL_INIT_VIDEO");
    let window = SDL.CreateWindow(
        "Scale to Space",
        640,
        480,
        @native "SDL_WINDOW_RESIZABLE | SDL_WINDOW_OPENGL",
    );
    log("Created window");

    @native ''
        {
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3);
            SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
        }
    '';

    let gl_context = SDL.GL.CreateContext(window);
    SDL.GL.MakeCurrent(window, gl_context);
    let vsync = (import "../../cli.ks").parse().vsync;
    SDL.GL.SetSwapInterval(if vsync then 1 else 0);
    log("Created GL context");

    ugli.init();
    log("Initialized ugli");

    let quad = {
        .program = load_shader("assets/shaders/quad"),
        .buffer = (
            let mut data :: ArrayList.t[Vertex] = ArrayList.new();
            ArrayList.push_back(
                &mut data,
                {
                    .a_pos = { -1, -1 },
                    .a_uv = { 0, 0 },
                },
            );
            ArrayList.push_back(
                &mut data,
                {
                    .a_pos = { +1, -1 },
                    .a_uv = { 1, 0 },
                },
            );
            ArrayList.push_back(
                &mut data,
                {
                    .a_pos = { +1, +1 },
                    .a_uv = { 1, 1 },
                },
            );
            ArrayList.push_back(
                &mut data,
                {
                    .a_pos = { -1, +1 },
                    .a_uv = { 0, 1 },
                },
            );
            ugli.VertexBuffer.init(&data)
        ),
    };
    ugli.check_error();
    let mut geng = {
        .window,
        .gl_context,
        .quad,
    };
    {
        .geng,
        .gl = (),
    }
);

const draw_quad = (
    .pos :: Vec2,
    .half_size :: Vec2,
    .texture :: ugli.Texture,
) => (
    panic("TODO DRAW QUAD");
    (#
    let ctx = (@current Context);
    let camera = (@current CameraCtx);
    let program = ctx.quad.program;
    program |> ugli.Program.@"use";

    let mut draw_state = ugli.DrawState.init();
    let draw_state = &mut draw_state;

    program |> ugli.set_uniform("u_pos", pos, draw_state);
    program |> ugli.set_uniform("u_half_size", half_size, draw_state);
    program |> ugli.set_uniform("u_view_matrix", camera.view_matrix, draw_state);
    program |> ugli.set_uniform("u_projection_matrix", camera.projection_matrix, draw_state);
    program |> ugli.set_uniform("u_texture", texture, draw_state);
    program |> ugli.set_vertex_data_source(ctx.quad.buffer);
    gl.draw_arrays(gl.TRIANGLE_FAN, 0, 4);
    #)
);

const load_texture = (path :: String, filter :: ugli.Filter) -> ugli.Texture => (
    ugli.Texture.load(path, filter)
);

const load_shader = (path :: String) -> ugli.Program => (
    ugli.Program.init(
        .vertex_glsl = fetch_string(path + "/vertex.glsl"),
        .fragment_glsl = fetch_string(path + "/fragment.glsl"),
    )
);

const is_fullscreen = () -> Bool => (
    let ctx = @current Context;
    @native "(SDL_GetWindowFlags(\(ctx.window)) & SDL_WINDOW_FULLSCREEN) != 0"
);

const set_fullscreen = (full :: Bool) -> () => (
    let ctx = (@current Context);
    SDL.SetWindowFullscreen(ctx.window, full);
);

const toggle_fullscreen = () => (
    set_fullscreen(not is_fullscreen());
);

const get_window_size = () -> Vec2 => (
    let ctx = @current Context;
    let { width, height } = SDL.GetWindowSize(ctx.window);
    { Int32_to_Float32(width), Int32_to_Float32(height) }
);

const time_since_start = () -> Float32 => (
    let ticks = SDL.GetTicks();
    UInt64_to_Float32(ticks) / 1000
);

const await_next_frame = () => (
    let ctx = @current Context;
    SDL.GL.SwapWindow(ctx.window);
    let { width, height } = SDL.GetWindowSize(ctx.window);
    gl.viewport(0, 0, width, height);
);

const deinit = () => (
    let ctx = @current Context;
    SDL.Quit();
);

const App = [Self] newtype {
    .init :: () -> Self,
    .update :: (&mut Self, Float32) -> (),
    .handle_event :: (&mut Self, Event) -> (),
    .draw :: &mut Self -> (),
};

const run = [G :: Type] () => (
    let { .geng = geng_ctx, .gl = gl_ctx } = geng.init();

    with geng.Context = geng_ctx;
    with gl.Context = gl_ctx;

    with geng.input.Context = geng.input.init();
    with geng.audio.Context = geng.audio.init();

    let mut t = geng.time_since_start();

    let mut state = (G as App).init();
    # @native "GC_disable()";

    with_return (
        loop (
            let framebuffer_size = geng.get_window_size();
            let dt = (
                let new_t = geng.time_since_start();
                let dt = new_t - t;
                t = new_t;
                dt
            );
            for event in geng.input.iter_events() do (
                if event is :Quit then (
                    return;
                );
                (G as App).handle_event(&mut state, event);
            );
            (G as App).update(&mut state, dt);
            (G as App).draw(&mut state);

            ugli.check_error();
            geng.await_next_frame();
        );
    );

    geng.deinit();
);
