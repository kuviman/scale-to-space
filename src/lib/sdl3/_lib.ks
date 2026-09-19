module:

const Int = Int32;

const GetError = () -> String => (
    @native "String_from_C_String(SDL_GetError())"
);

const throw_error = (fn_name :: String) => (
    panic(fn_name + " failed: " + GetError());
);

const PropertiesID = @opaque_type "SDL_PropertiesID";

const CreateProperties = () -> PropertiesID => (
    let id = @native "SDL_CreateProperties()";
    if @native "\(id) == 0" then (
        throw_error("SDL_CreateProperties");
    );
    id
);

const DestroyProperties = (props :: PropertiesID) => (
    @native "SDL_DestroyProperties(\(props))";
);

const PropertyName = @opaque_type "const char*";

const SetBooleanProperty = (props :: PropertiesID, name :: PropertyName, value :: Bool) => (
    if @native "!SDL_SetBooleanProperty(\(props), \(name), \(value))" then (
        throw_error("SDL_SetBooleanProperty");
    );
);

const SetNumberProperty = (props :: PropertiesID, name :: PropertyName, value :: Int64) => (
    if @native "!SDL_SetNumberProperty(\(props), \(name), \(value))" then (
        throw_error("SDL_SetNumberProperty");
    );
);

const InitFlags = @opaque_type "SDL_InitFlags";

const Init = (flags :: InitFlags) => (
    @native "#include <SDL3/SDL.h>";
    @native "#include <SDL3/SDL_main.h>";
    if @native "!SDL_Init(\(flags))" then (
        throw_error("SDL_Init");
    );
);

const Quit = () => (
    @native "SDL_Quit()";
);

const Window = @opaque_type "SDL_Window*";

const WindowFlags = @opaque_type "SDL_WindowFlags";

const CreateWindow = (
    title :: String,
    width :: Int,
    height :: Int,
    window_flags :: WindowFlags,
) -> Window => (
    let window = @native ''
        SDL_CreateWindow(
            String_to_C_String(\(
                title
            )),
            \(width),
            \(height),
            \(window_flags)
        )
    '';
    if @native "\(window) == NULL" then (
        throw_error("SDL_CreateWindow");
    );
    window
);

const GL = (
    module:

    const Context = @opaque_type "SDL_GLContext";

    const CreateContext = (window :: Window) -> GL.Context => (
        let ctx = @native "SDL_GL_CreateContext(\(window))";
        if @native "\(ctx) == NULL" then (
            throw_error("GL_CreateContext");
        );
        ctx
    );

    const MakeCurrent = (window :: Window, gl :: GL.Context) => (
        if @native "!SDL_GL_MakeCurrent(\(window), \(gl))" then (
            throw_error("SDL_GL_MakeCurrent");
        );
    );

    const SetSwapInterval = (interval :: Int) => (
        if @native "!SDL_GL_SetSwapInterval(\(interval))" then (
            throw_error("SDL_GL_SetSwapInterval");
        );
    );

    const SwapWindow = (window :: Window) => (
        if @native "!SDL_GL_SwapWindow(\(window))" then (
            throw_error("SDL_GL_SwapWindow");
        );
    );
);

const Scancode = @opaque_type "SDL_Scancode";

const Event = @opaque_type "SDL_Event";
const PollEvent = () -> Option.t[Event] => (
    let event = @native "(SDL_Event){}";
    if @native "SDL_PollEvent(\(&event))" then (
        :Some event
    ) else (
        :None
    )
);

const SetWindowRelativeMouseMode = (window :: Window, enabled :: Bool) => (
    if @native "!SDL_SetWindowRelativeMouseMode(\(window), \(enabled))" then (
        throw_error("SDL_SetWindowRelativeMouseMode");
    );
);

const GetWindowSize = (window :: Window) -> { Int32, Int32 } => (
    let mut width = 0;
    let mut height = 0;
    if @native "!SDL_GetWindowSize(\(window), \(&mut width), \(&mut height))" then (
        throw_error("SDL_GetWindowSize");
    );
    { width, height }
);

const Surface = @opaque_type "SDL_Surface*";

const PixelFormat = @opaque_type "SDL_PixelFormat";

const ConvertSurface = (surface :: Surface, format :: PixelFormat) -> Surface => (
    let result = @native "SDL_ConvertSurface(\(surface), \(format))";
    if @native "\(result) == NULL" then (
        throw_error("SDL_ConvertSurface");
    );
    result
);

const DestroySurface = (surface :: Surface) => (
    @native "SDL_DestroySurface(\(surface))";
);

const FlipMode = @opaque_type "SDL_FlipMode";

const FlipSurface = (surface :: Surface, mode :: FlipMode) => (
    if @native "!SDL_FlipSurface(\(surface), \(mode))" then (
        throw_error("SDL_FlipSurface");
    );
);

const IMG = (
    module:

    const Load = (path :: String) -> Surface => (
        @native "#include <SDL3_image/SDL_image.h>";
        let surface = @native "IMG_Load(String_to_C_String(\(path)))";
        if @native "\(surface) == NULL" then (
            throw_error("IMG_Load");
        );
        surface
    );
);

const MIX = (
    module:

    const Init = () => (
        @native "#include <SDL3_mixer/SDL_mixer.h>";
        if @native "!MIX_Init()" then (
            throw_error("MIX_Init");
        );
    );

    const AudioDeviceID = @opaque_type "SDL_AudioDeviceID";
    const AudioSpec = @opaque_type "SDL_AudioSpec*";

    const Mixer = @opaque_type "MIX_Mixer*";

    const CreateMixerDevice = (
        devid :: AudioDeviceID,
        spec :: AudioSpec,
    ) -> Mixer => (
        let mixer = @native "MIX_CreateMixerDevice(\(devid), \(spec))";
        if @native "\(mixer) == NULL" then (
            throw_error("MIX_CreateMixerDevice");
        );
        mixer
    );

    const Audio = @opaque_type "MIX_Audio*";

    const LoadAudio = (
        mixer :: Mixer,
        path :: String,
        predecode :: Bool,
    ) -> Audio => (
        let path_c :: @opaque_type "const char*" = @native "String_to_C_String(\(path))";
        let audio = @native "MIX_LoadAudio(\(mixer), \(path_c), \(predecode))";
        if @native "\(audio) == NULL" then (
            throw_error("MIX_LoadAudio");
        );
        audio
    );

    const DestroyAudio = (audio :: Audio) => (
        @native "MIX_DestroyAudio(\(audio))";
    );

    const Track = @opaque_type "MIX_Track*";

    const CreateTrack = (mixer :: Mixer) -> Track => (
        let track = @native "MIX_CreateTrack(\(mixer))";
        if @native "\(track) == NULL" then (
            throw_error("MIX_CreateTrack");
        );
        track
    );

    const SetTrackAudio = (track :: Track, audio :: Audio) => (
        if @native "!MIX_SetTrackAudio(\(track), \(audio))" then (
            throw_error("MIX_SetTrackAudio");
        );
    );

    const PlayTrack = (track :: Track, options :: PropertiesID) => (
        if @native "!MIX_PlayTrack(\(track), \(options))" then (
            throw_error("MIX_PlayTrack");
        );
    );

    const SetMixerGain = (mixer :: Mixer, gain :: Float32) => (
        if @native "!MIX_SetMixerGain(\(mixer), \(gain))" then (
            throw_error("MIX_SetMixerGain");
        );
    );

    const SetTrackGain = (track :: Track, gain :: Float32) => (
        if @native "!MIX_SetTrackGain(\(track), \(gain))" then (
            throw_error("MIX_SetTrackGain");
        );
    );

    const GetTrackGain = (track :: Track) -> Float32 => (
        @native "MIX_GetTrackGain(\(track))"
    );

    const SetTrackLoops = (track :: Track, loops :: Int32) => (
        if @native "!MIX_SetTrackLoops(\(track), \(loops))" then (
            throw_error("MIX_SetTrackLoops");
        );
    );

    const StopTrack = (track :: Track, fade_out_frames :: Int64) => (
        if @native "!MIX_StopTrack(\(track), \(fade_out_frames))" then (
            throw_error("MIX_StopTrack");
        );
    );

    const DestroyTrack = (track :: Track) => (
        @native "MIX_DestroyTrack(\(track))";
    );

    const Quit = () => (
        @native "MIX_Quit()";
    );
);

const SetWindowFullscreen = (window :: Window, fullscreen :: Bool) => (
    if @native "!SDL_SetWindowFullscreen(\(window), \(fullscreen))" then (
        throw_error("SDL_SetWindowFullscreen");
    );
);

const GetTicks = () -> UInt64 => (
    @native "SDL_GetTicks()"
);

const RawAppResult = @opaque_type "SDL_AppResult";

const AppResult = newtype (
    | :Success
    | :Failure
    | :Continue
);

impl AppResult as module = (
    module:

    const into_raw = (self :: AppResult) -> RawAppResult => (
        match self with (
            | :Success => @native "SDL_APP_SUCCESS"
            | :Failure => @native "SDL_APP_FAILURE"
            | :Continue => @native "SDL_APP_CONTINUE"
        )
    );

    const from_raw = (raw :: RawAppResult) -> AppResult => (
        if @native "\(raw) == SDL_APP_SUCCESS" then (
            :Success
        ) else if @native "\(raw) == SDL_APP_FAILURE" then (
            :Failure
        ) else if @native "\(raw) == SDL_APP_CONTINUE" then (
            :Continue
        ) else (
            panic("Unrecognized SDL_AppResult")
        )
    );
);

const App = [Self] newtype {
    .init :: () -> Self,
    .iterate :: &mut Self -> AppResult,
    .event :: (&mut Self, &Event) -> AppResult,
    .quit :: (Self, AppResult) -> (),
};

const EnterAppMainCallbacks = [A :: Type] (app_impl :: App[A]) => (
    @comment_out (
    let mut app = app_impl.init();
    let result = unwindable main (
        let handle_app_result = result => match result with (
            | :Continue => ()
            | _ => unwind main result
        );
        @loop (
            app_impl.iterate(&mut app) |> handle_app_result;
            while PollEvent() is :Some event do (
                app_impl.event(&mut app, &event) |> handle_app_result;
            );
        )
    );
    app_impl.quit(app, result);
    match result with (
        | :Success => ()
        | :Continue => panic("unreachable")
        | :Failure => std.sys.exit(-1)
    )
    );
    # Actual impl
    const mut STORE_CONTEXT :: Option.t[type (@context)] = :None;
    const void_star = @opaque_type "void*";
    const void_star_star = @opaque_type "void**";
    const mut STORE_APP_IMPL :: Option.t[void_star] = :None;
    STORE_CONTEXT = :Some (@context);
    STORE_APP_IMPL = :Some (@native "(void*)\(&app_impl)");
    const init_callback = [A] fn @call "C" (
        app_state :: void_star_star,
        _argc :: @opaque_type "int",
        _argv :: @opaque_type "char**",
    ) -> RawAppResult => (
        let mut context = @native "(Context) {}";
        let &@context = &mut context;
        let mut context = STORE_CONTEXT |> Option.unwrap;
        let &@context = &mut context;
        let app_impl = STORE_APP_IMPL |> Option.unwrap;
        let app_impl :: &App[A] = @native "\(app_impl)";
        let app_impl = app_impl^;
        let mut initialized_app = app_impl.init();
        @native "*\(app_state) = (void*) \(&mut initialized_app)";
        @native "SDL_APP_CONTINUE"
    );
    const iterate_callback = [A] fn @call "C" (
        app_state :: void_star,
    ) -> RawAppResult => (
        let mut context = @native "(Context) {}";
        let &@context = &mut context;
        let mut context = STORE_CONTEXT |> Option.unwrap;
        let &@context = &mut context;
        let app_impl = STORE_APP_IMPL |> Option.unwrap;
        let app_impl :: &App[A] = @native "\(app_impl)";
        let app_impl = app_impl^;
        let app_state :: &mut A = @native "\(app_state)";
        app_impl.iterate(app_state)
            |> AppResult.into_raw
    );
    const event_callback = [A] fn @call "C" (
        app_state :: void_star,
        event :: &Event,
    ) -> RawAppResult => (
        let mut context = @native "(Context) {}";
        let &@context = &mut context;
        let mut context = STORE_CONTEXT |> Option.unwrap;
        let &@context = &mut context;
        let app_impl = STORE_APP_IMPL |> Option.unwrap;
        let app_impl :: &App[A] = @native "\(app_impl)";
        let app_impl = app_impl^;
        let app_state :: &mut A = @native "\(app_state)";
        app_impl.event(app_state, event)
            |> AppResult.into_raw
    );
    const quit_callback = [A] fn @call "C" (
        app_state :: void_star,
        result ::RawAppResult,
    ) -> () => (
        let mut context = @native "(Context) {}";
        let &@context = &mut context;
        let mut context = STORE_CONTEXT |> Option.unwrap;
        let &@context = &mut context;
        let app_impl = STORE_APP_IMPL |> Option.unwrap;
        let app_impl :: &App[A] = @native "\(app_impl)";
        let app_impl = app_impl^;
        let app_state :: &mut A = @native "\(app_state)";
        app_impl.quit(app_state^, result |> AppResult.from_raw);
    );
    @native ''
        SDL_EnterAppMainCallbacks(
            CLI_ARGS.argc,
            CLI_ARGS.original_argv,
            \(init_callback[A]),
            \(iterate_callback[A]),
            \(event_callback[A]),
            \(quit_callback[A])
        )
    '';
);
