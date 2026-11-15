use (import "./__deps__.ks").*;
use (import "./model.ks").*;
const config = import "./config.ks";
const collisions = import "./collisions.ks";
const json = import "./json.ks";
const gltf = import "../gltf/_lib.ks";
use std.rc.Rc;

module:

const MUSIC_VOLUME = 0.5;

const Assets = (
    module:

    const t = newtype {
        .music :: geng.audio.Effect,
        .music_high :: geng.audio.Effect,
        .sfx :: Sfx,
        .shaders :: Shaders,
        .textures :: Textures,
        .models :: Models,
        .powers :: Powers,
        .volleyball :: Model.t,
        .config :: config.Config,
        .level :: Level,
    };

    const Powers = newtype {
        .parachute :: {
            .model :: Model.t,
        },
        .jetpack :: {
            .model :: Model.t,
            .particle :: ugli.Texture,
            .sfx :: geng.audio.Buffer,
        },
    };

    const Ctx = @context type (&mut t);

    const Shaders = newtype {
        .model :: ugli.Program,
    };

    const Sfx = newtype {
        .deflation :: geng.audio.Buffer,
        .inflation :: geng.audio.Buffer,
        .jetpack :: geng.audio.Buffer,
        .ground :: geng.audio.Buffer,
        .splash :: geng.audio.Buffer,
        .win :: geng.audio.Buffer,
        .collect :: geng.audio.Buffer,
        .volleyball :: geng.audio.Buffer,
        .score :: geng.audio.Buffer,
    };

    const Textures = newtype {
        .emotes :: ArrayList.t[ugli.Texture],
        .fullscreen :: ugli.Texture,
        .mute :: ugli.Texture,
        .muted :: ugli.Texture,
        .water :: ugli.Texture,
        .fire :: ugli.Texture,
        .water_particle :: ugli.Texture,
        .sparkle :: ugli.Texture,
    };

    const Level = newtype {
        .gltf :: gltf.Asset,
        .parts :: ArrayList.t[LevelPart],
    };

    const LevelPart = newtype {
        .collision_mesh :: collisions.Mesh,
        .material :: Rc.t[LevelMaterial],
    };

    const LevelMaterial = newtype {
        .name :: &str,
        .sfx :: geng.audio.Buffer,
        .properties :: collisions.MeshProperties,
        .particle :: ugli.Texture,
    };

    impl Level as module = (
        module:

        const load = () -> Level => (
            let gltf_asset = gltf.Asset.load("assets/level/model.glb");
            let materials_config :: OrdMap.t[String, Option.t[String]] = (
                with json.ErrorHandler = (msg => panic(msg));
                let source = std.fs.read_file("assets/level/materials.json");
                let value = json.parse(&mut json.Reader.create(&source |> as_str))
                    |> Result.unwrap;
                (include_ast json.parse_map(`(value), Option.t[String])).actual_map
            );
            const Impl = (
                module:

                const Ctx = @context newtype {
                    .materials_config :: &OrdMap.t[String, Option.t[String]],
                    .part_by_material :: &mut OrdMap.t[&str, LevelPart],
                    .loaded_materials :: &mut OrdMap.t[&str, Rc.t[LevelMaterial]],
                    .matrix :: Mat4,
                };

                const load_material = (name :: &str) -> Rc.t[LevelMaterial] => (
                    let path = format!("assets/level/materials/\(name)");
                    ((@current Ctx).loaded_materials |> OrdMap.get_or_init(name, () => Rc.new({
                        .particle = geng.load_texture(
                            &format!("\(path)/particle.png") |> as_str,
                            :Nearest,
                        ),
                        .properties = (
                            let source = std.fs.read_file(
                                &format!("\(path)/properties.json") |> as_str
                            );
                            include_ast json.parse_str(`(&source |> as_str), collisions.MeshProperties)
                        ),
                        .sfx = geng.audio.Buffer.load(
                            &format!("\(path)/sfx.wav") |> as_str
                        ),
                        .name,
                    })))^
                );

                const init_part = (material_name :: &str) -> LevelPart => {
                    .collision_mesh = collisions.Mesh.new(),
                    .material = load_material(material_name),
                };

                const walk_primitive = (primitive :: &gltf.MeshPrimitive) => with_return (
                    let material :: &gltf.Material = &primitive^.material^;
                    let material_name = match material^.name with (
                        | :None => return
                        | :Some ref name => (
                            match (@current Ctx).materials_config |> OrdMap.get(name) with (
                                | :None => panic_fmt!("setup material \(name^) in materials.json")
                                | :Some &(:None) => return
                                | :Some &(:Some ref name) => name |> as_str
                            )
                        )
                    );
                    let part = (@current Ctx).part_by_material
                        |> OrdMap.get_or_init(
                            material_name,
                            () => init_part(material_name),
                        );
                    let transform = (pos :: Vec3) -> Vec3 => (
                        Mat4.mul_vec((@current Ctx).matrix, { ...pos, 1 })
                            |> Vec4.xyz
                    );
                    for face in gltf.MeshPrimitive.faces(primitive) do (
                        let vs = {
                            transform(face.vertices.0.position),
                            transform(face.vertices.1.position),
                            transform(face.vertices.2.position),
                        };
                        let face = {
                            .vs,
                            .normal = Vec3.normalize(
                                Vec3.cross(
                                    Vec3.sub(vs.1, vs.0),
                                    Vec3.sub(vs.2, vs.0),
                                )
                            ),
                        };
                        &mut part^.collision_mesh |> collisions.Mesh.add_face(face);
                    );
                );

                const walk_mesh = (mesh :: &gltf.Mesh) => (
                    for primitive in &mesh^.primitives |> ArrayList.iter do (
                        walk_primitive(primitive);
                    );
                );

                const walk_node = (node :: &gltf.Node) => (
                    with Ctx = {
                        ...(@current Ctx),
                        .matrix = Mat4.mul_mat((@current Ctx).matrix, node^.local_transform),
                    };
                    if node^.mesh is :Some ref mesh then (
                        walk_mesh(&mesh^^);
                    );
                    for child in &node^.children |> ArrayList.iter do (
                        walk_node(&child^^);
                    );
                );

                const walk_scene = (scene :: &gltf.Scene) => (
                    for node in &scene^.nodes |> ArrayList.iter do (
                        walk_node(&node^^);
                    );
                );
            );
            let mut part_by_material = OrdMap.new();
            let mut loaded_materials = OrdMap.new();
            with Impl.Ctx = {
                .materials_config = &materials_config,
                .part_by_material = &mut part_by_material,
                .loaded_materials = &mut loaded_materials,
                .matrix = gltf_to_geng_matrix(),
            };
            Impl.walk_scene(&gltf_asset.scene^);
            let mut parts = ArrayList.new();
            for { .key = _, .value = part } in part_by_material |> OrdMap.into_iter do (
                &mut parts |> ArrayList.push_back(part);
            );
            {
                .gltf = gltf_asset,
                .parts,
            }
        );
    );

    const Models = newtype {
        .skins :: ArrayList.t[Model.t],
        .jetpack :: Model.t,
        .badarms :: Model.t,
        .dragon_scale :: Model.t,
        .wormy :: Model.t,
    };

    const load_config = () -> config.Config => (
        (include_ast json.loader(config.Config))("assets/config.json")
    );

    const reload = () => (
        let assets = @current Ctx;
        assets^.config = load_config();
    );

    const load = () -> t => (
        let config = load_config();
        let level = Level.load();
        let music = geng.audio.Buffer.load("assets/music.wav");
        let music = geng.audio.play_with(
            &music,
            {
                .@"loop" = true,
                .volume = MUSIC_VOLUME,
            },
        );
        let music_high = geng.audio.Buffer.load("assets/music_high.wav");
        let music_high = geng.audio.play_with(
            &music_high,
            {
                .@"loop" = true,
                .volume = 0,
            },
        );
        let sfx = {
            .deflation = geng.audio.Buffer.load("assets/sfx/deflation.wav"),
            .inflation = geng.audio.Buffer.load("assets/sfx/inflation.wav"),
            .jetpack = geng.audio.Buffer.load("assets/sfx/jetpack.wav"),
            .ground = geng.audio.Buffer.load("assets/sfx/ground.wav"),
            .splash = geng.audio.Buffer.load("assets/sfx/splash.wav"),
            .win = geng.audio.Buffer.load("assets/sfx/trumpet.mp3"),
            .collect = geng.audio.Buffer.load("assets/sfx/collect.wav"),
            .score = geng.audio.Buffer.load("assets/sfx/score.wav"),
            .volleyball = geng.audio.Buffer.load("assets/sfx/volleyball.wav"),
        };

        let shaders = {
            .model = geng.load_shader("assets/shaders/model"),
        };

        let load_texture = path => geng.load_texture(
            &format!("assets/textures/\(path)") |> as_str,
            :Nearest,
        );

        let textures = {
            .fullscreen = load_texture("ui/fullscreen.png"),
            .mute = load_texture("ui/mute.png"),
            .muted = load_texture("ui/muted.png"),
            .water = (
                let mut texture = geng.load_texture("assets/textures/surfaces/water.png", :Nearest);
                &mut texture |> ugli.Texture.set_wrap(:Repeat);
                texture
            ),
            .emotes = (
                let mut list = ArrayList.new();
                let add = path => (
                    &mut list |> ArrayList.push_back(geng.load_texture(path, :Nearest));
                );
                add("assets/sprites/emote/heart.png");
                add("assets/sprites/emote/lol.png");
                add("assets/sprites/emote/pog.png");
                add("assets/sprites/emote/rage.png");
                add("assets/sprites/emote/kast.png");
                list
            ),
            .fire = geng.load_texture("assets/sprites/particle/fire.png", :Nearest),
            .water_particle = geng.load_texture("assets/sprites/particle/water.png", :Nearest),
            .sparkle = geng.load_texture("assets/sprites/particle/sparkle.png", :Nearest),
        };

        let models = {
            .skins = (
                let mut list = ArrayList.new();
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/fish"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/unicorn"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/daivy"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/fart"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/pgorley"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/badball"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/vezball"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/cabbage"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/categon"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/dog"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/gob"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/howl"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/krab"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/moo"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/penguin"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/pomo"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/wormy"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/togis"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/bu"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/aeron"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/nertsal"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/jerogma"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/temptic"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/trumpet"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/gondo"));
                &mut list |> ArrayList.push_back(Model.load("assets/models/player/debug"));
                list
            ),
            .jetpack = Model.load("assets/models/jetpack"),
            .dragon_scale = Model.load("assets/models/collectable/dragonScale"),
            .badarms = Model.load("assets/models/player/badball/arms"),
            .wormy = Model.load("assets/models/player/wormy/worm"),
        };

        {
            .level,
            .music,
            .music_high,
            .sfx,
            .shaders,
            .textures,
            .models,
            .powers = {
                .parachute = {
                    .model = Model.load("assets/powers/parachute"),
                },
                .jetpack = {
                    .model = Model.load("assets/powers/jetpack"),
                    .particle = geng.load_texture("assets/powers/jetpack/particle.png", :Nearest),
                    .sfx = geng.audio.Buffer.load("assets/powers/jetpack/sfx.wav"),
                },
            },
            .volleyball = Model.load("assets/models/volleyball"),
            .config,
        }
    );
);
