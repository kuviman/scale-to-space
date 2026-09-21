use (import "./lib/_lib.ks").*;
use (import "./model.ks").*;
const collisions = import "./collisions.ks";
const json = import "./json.ks";

module:

const MUSIC_VOLUME = 0.5;

const Assets = (
    module:

    const t = newtype {
        .music :: geng.audio.Effect,
        .music_high :: geng.audio.Effect,
        .sfx :: Sfx,
        .font :: font.Font,
        .shaders :: Shaders,
        .textures :: Textures,
        .models :: Models,
        .powers :: Powers,
    };

    const Powers = newtype {
        .parachute :: {
            .model :: Model.t,
        },
    };

    const Ctx = @context t;

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
    };

    const Textures = newtype {
        .emotes :: ArrayList.t[ugli.Texture],
        .fullscreen :: ugli.Texture,
        .mute :: ugli.Texture,
        .muted :: ugli.Texture,
        .ground :: ugli.Texture,
        .water :: ugli.Texture,
        .fire :: ugli.Texture,
        .water_particle :: ugli.Texture,
        .sparkle :: ugli.Texture,
    };

    const LevelModel = newtype {
        .collision_mesh :: collisions.Mesh,
        .model :: Model.t,
        .sfx :: geng.audio.Buffer,
        .properties :: collisions.MeshProperties,
        .particle :: ugli.Texture,
    };

    impl LevelModel as module = (
        module:

        const load = (path :: String) -> LevelModel => (
            let mut collision_mesh = ArrayList.new();
            let obj = obj.parse(std.fs.read_file(path + "/model.obj"));
            for face in obj |> ArrayList.into_iter do (
                let mut mesh_face = {
                    .vs = ArrayList.new(),
                    .normal = Vec3.normalize(
                        Vec3.cross(
                            Vec3.sub(face.1.a_pos, face.0.a_pos),
                            Vec3.sub(face.2.a_pos, face.0.a_pos),
                        )
                    ),
                };
                &mut mesh_face.vs |> ArrayList.push_back(face.0.a_pos);
                &mut mesh_face.vs |> ArrayList.push_back(face.1.a_pos);
                &mut mesh_face.vs |> ArrayList.push_back(face.2.a_pos);
                &mut collision_mesh |> ArrayList.push_back(mesh_face);
            );
            let collision_mesh = collisions.Mesh.new(collision_mesh);
            let model = Model.load(path);
            let particle = geng.load_texture(path + "/particle.png", :Nearest);
            let properties = (
                let source = std.fs.read_file(path + "/properties.json");
                let value = json.parse(&mut json.Reader.create(&source))
                    |> Result.unwrap;
                include_ast json.parse_value(`(value), collisions.MeshProperties)
            );
            let sfx = geng.audio.load(path + "/sfx.wav");
            {
                .collision_mesh,
                .model,
                .sfx,
                .properties,
                .particle,
            }
        );
    );

    const Models = newtype {
        .skins :: ArrayList.t[Model.t],
        .level :: ArrayList.t[LevelModel],
        .level_nocollisions :: ArrayList.t[Model.t],
        .jetpack :: Model.t,
        .badarms :: Model.t,
        .dragon_scale :: Model.t,
        .wormy :: Model.t,
    };

    const load = () -> t => (
        let music = geng.audio.load("assets/music.wav");
        let music = geng.audio.play_with(
            music,
            {
                .@"loop" = true,
                .volume = MUSIC_VOLUME,
            },
        );
        let music_high = geng.audio.load("assets/music_high.wav");
        let music_high = geng.audio.play_with(
            music_high,
            {
                .@"loop" = true,
                .volume = 0,
            },
        );
        let sfx = {
            .deflation = geng.audio.load("assets/sfx/deflation.wav"),
            .inflation = geng.audio.load("assets/sfx/inflation.wav"),
            .jetpack = geng.audio.load("assets/sfx/jetpack.wav"),
            .ground = geng.audio.load("assets/sfx/ground.wav"),
            .splash = geng.audio.load("assets/sfx/splash.wav"),
            .win = geng.audio.load("assets/sfx/trumpet.mp3"),
            .collect = geng.audio.load("assets/sfx/collect.wav"),
        };
        let font = font.Font.load("assets/font");

        let shaders = {
            .model = geng.load_shader("assets/shaders/model"),
        };

        let load_texture = path => geng.load_texture("assets/textures/" + path, :Nearest);

        let textures = {
            .fullscreen = load_texture("fullscreen.png"),
            .mute = load_texture("mute.png"),
            .muted = load_texture("muted.png"),
            .ground = (
                let mut texture = geng.load_texture("assets/textures/ground.png", :Nearest);
                &mut texture |> ugli.Texture.set_wrap(:Repeat);
                texture
            ),
            .water = (
                let mut texture = geng.load_texture("assets/textures/water.png", :Nearest);
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
                list
            ),
            .level = (
                let mut list = ArrayList.new();
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/grass"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/lava"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/logs"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/rock"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/sand"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/ice"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/metal"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/trampoline"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/mushroom"));
                &mut list |> ArrayList.push_back(LevelModel.load("assets/models/level/rocket"));
                list
            ),
            .level_nocollisions = (
                let mut list = ArrayList.new();
                &mut list |> ArrayList.push_back(Model.load(
                    "assets/models/level/nocollisions/leaves"));
                &mut list |> ArrayList.push_back(Model.load(
                    "assets/models/level/nocollisions/outline"));
                &mut list |> ArrayList.push_back(Model.load(
                    "assets/models/level/nocollisions/flag"));
                &mut list |> ArrayList.push_back(Model.load(
                    "assets/models/level/nocollisions/secret"));
                list
            ),
            .jetpack = Model.load("assets/models/jetpack"),
            .dragon_scale = Model.load("assets/models/collectable/dragonScale"),
            .badarms = Model.load("assets/models/player/badball/arms"),
            .wormy = Model.load("assets/models/player/wormy/worm"),
        };

        {
            .music,
            .music_high,
            .sfx,
            .font,
            .shaders,
            .textures,
            .models,
            .powers = {
                .parachute = {
                    .model = Model.load("assets/powers/parachute"),
                },
            },
        }
    );
);
