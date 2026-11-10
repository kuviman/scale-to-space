use (import "../src/__deps__.ks").*;
const gltf = import "./_lib.ks";

const Game = newtype {
    .gltf_renderer :: gltf.Renderer,
    .camera :: geng.Camera,
    .asset :: gltf.Asset,
};

@eval (impl Game as geng.App = {
    .init = () -> Game => (
        let gltf_renderer = gltf.Renderer.init();
        with gltf.Renderer.Ctx = &gltf_renderer;
        let asset = gltf.Asset.load("assets/gltf/cube.glb");
        {
            .gltf_renderer,
            .asset,
            .camera = {
                .position = { 0, 0, 0 },
                .distance = 50,
                .attack = Angle.from_degrees(0),
                .rotation = Angle.from_degrees(0),
                .fov = :Vertical Angle.from_degrees(90),
            },
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
        ugli.clear({ 0.5, 0.5, 0.5, 1.0 });
        let node = &self^.asset |> gltf.Asset.find_node("old.mainIsland");
        gltf.Node.draw(node, false, Mat4.IDENTITY);
    ),
});

geng.run[Game](
    .title = "Geng Example",
    .vsync = true,
);
