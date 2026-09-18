use (import "./lib/_lib.ks").*;

module:

const Model = (
    module:

    const t = newtype {
        .buffer :: ugli.VertexBuffer.t[obj.Vertex],
        .texture :: ugli.Texture,
    };

    const PlayerCtx = @context newtype {
        .position :: Vec3,
        .radius :: Float32,
    };

    const load = (path :: String) -> Model.t => (
        let text = std.fs.read_file(path + "/model.obj");
        let faces = obj.parse(text);
        let mut data = ArrayList.new();
        for face in faces |> ArrayList.into_iter do (
            &mut data |> ArrayList.push_back(face.0);
            &mut data |> ArrayList.push_back(face.1);
            &mut data |> ArrayList.push_back(face.2);
        );
        let buffer = ugli.VertexBuffer.init(&data);
        let mut texture = ugli.Texture.load(path + "/texture.png", :Nearest);
        &mut texture |> ugli.Texture.set_wrap(:Repeat);
        { .buffer, .texture }
    );

    const Renderer = newtype {
        .program :: ugli.Program,
    };

    impl Renderer as module = (
        module:

        const Ctx = @context Renderer;

        const init = () -> Renderer => (
            {
                .program = geng.load_shader("assets/shaders/model"),
            }
        );
    );

    const draw = (model :: Model.t, animated :: Bool, matrix :: Mat4) => (
        let renderer = @current Renderer.Ctx;
        let camera = @current geng.CameraUniforms.Ctx;

        let program = renderer.program;
        program |> ugli.Program.@"use";

        ugli.check_error();

        let mut draw_state = ugli.DrawState.init();
        let draw_state = &mut draw_state;
        ugli.check_error();

        program
            |> ugli.set_uniform(
                "u_time",
                geng.time_since_start(),
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_animated",
                if animated then 1 else 0 :: Float32,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_model_matrix",
                matrix,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_view_matrix",
                camera.view_matrix,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_projection_matrix",
                camera.projection_matrix,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_texture",
                model.texture,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_player_pos",
                (@current PlayerCtx).position,
                draw_state
            );
        ugli.check_error();
        program
            |> ugli.set_uniform(
                "u_player_radius",
                (@current PlayerCtx).radius,
                draw_state
            );
        ugli.check_error();
        program |> ugli.set_vertex_data_source(model.buffer);
        ugli.check_error();
        gl.draw_arrays(gl.TRIANGLES, 0, model.buffer.length);
        ugli.check_error();
    );
);
