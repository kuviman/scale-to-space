const asset = import "./asset.ks";
const SDL = import "../sdl3/_lib.ks";

module:

const ContextT = newtype {
    .mixer :: SDL.MIX.Mixer,
};

const Context = @context ContextT;

const init = () -> ContextT => (
    SDL.MIX.Init();
    let mixer = SDL.MIX.CreateMixerDevice(
        @native "SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK",
        @native "NULL",
    );
    { .mixer }
);

const PlayOptions = newtype {
    .@"loop" :: Bool,
    .volume :: Float32,
};

impl PlayOptions as module = (
    module:

    const default = () -> PlayOptions => {
        .@"loop" = false,
        .volume = 1,
    };
);

const Effect = newtype {
    .track :: SDL.MIX.Track,
};

impl Effect as module = (
    module:

    const stop = (effect :: Effect) => (
        SDL.MIX.StopTrack(effect.track, 0);
    );

    const set_volume = (effect :: Effect, volume :: Float32) => (
        SDL.MIX.SetTrackGain(effect.track, volume);
    );

    const get_volume = (effect :: Effect) -> Float32 => (
        SDL.MIX.GetTrackGain(effect.track)
    );
);

const play_with = (buffer :: Buffer, options :: PlayOptions) -> Effect => (
    let ctx = (@current Context);
    let track = SDL.MIX.CreateTrack(ctx.mixer);
    SDL.MIX.SetTrackAudio(track, buffer.audio);
    SDL.MIX.SetTrackGain(track, options.volume);
    # This one doesnt work
    # SDL.MIX.SetTrackLoops(track, if options.@"loop" then (-1) else 0);
    let props = SDL.CreateProperties();
    if options.@"loop" then (
        SDL.SetNumberProperty(props, @native "MIX_PROP_PLAY_LOOPS_NUMBER", -1);
    );
    SDL.MIX.PlayTrack(track, props);
    SDL.DestroyProperties(props);
    { .track }
);

const play = (buffer :: Buffer) -> Effect => (
    play_with(buffer, PlayOptions.default())
);

const set_master_volume = (volume :: Float32) -> () => (
    let ctx = (@current Context);
    SDL.MIX.SetMixerGain(ctx.mixer, volume);
);

const Buffer = newtype {
    .audio :: SDL.MIX.Audio,
};

const load = (path :: &str) -> Buffer => (
    let ctx = (@current Context);
    let audio = SDL.MIX.LoadAudio(ctx.mixer, path, true);
    { .audio }
);

impl Buffer as asset.Load = {
    .load,
    .default_ext = :Some "wav",
};
