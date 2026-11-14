use (import "../src/__deps__.ks").*;
const gltf = import "./_lib.ks";

const RenderThing = newtype (
    | :Scene &gltf.Scene
    | :Node &gltf.Node
);

const Game = newtype {
    .gltf_renderer :: gltf.Renderer,
    .camera :: geng.Camera,
    .asset :: gltf.Asset,
    .render :: RenderThing,
};

@eval (impl Game as geng.App = {
    .init = () -> Game => (
        let gltf_renderer = gltf.Renderer.init();
        with gltf.Renderer.Ctx = &gltf_renderer;
        let asset = gltf.Asset.load("assets/source_assets.glb");
        let render = if std.sys.argc() <= 1 then (
            :Scene &asset.scene^
        ) else (
            :Node (&asset |> gltf.Asset.find_node(std.sys.argv_at(1)))
        );
        {
            .gltf_renderer,
            .asset,
            .camera = {
                .position = { 0, 0, 0 },
                .distance = 100,
                .attack = Angle.from_degrees(30),
                .rotation = Angle.from_degrees(30),
                .fov = :Vertical Angle.from_degrees(90),
            },
            .render,
        }
    ),
    .update = (self :: &mut Game, delta_time :: Float32) => (),
    .handle_event = (self :: &mut Game, event :: geng.Event) => (),
    .draw = (self :: &mut Game) => (
        with gltf.Renderer.Ctx = &self^.gltf_renderer;
        with geng.CameraUniforms.Ctx = geng.CameraUniforms.init(
            self^.camera,
            .framebuffer_size = geng.get_window_size(),
        );
        @native "glEnable(GL_DEPTH_TEST)";
        ugli.clear({ 0.5, 0.5, 0.5, 1.0 });
        match self^.render with (
            | :Scene scene => (
                for node in &scene^.nodes |> ArrayList.iter do (
                    # println!("Rendering node \(node^^.name)");
                    gltf.Node.draw(&node^^, false, Mat4.IDENTITY);
                );
            )
            | :Node node => gltf.Node.draw(node, false, Mat4.IDENTITY)
        );
    ),
});

geng.run[Game](
    .title = "Geng Example",
    .vsync = true,
);
