const SDL = import "../src/lib/sdl3/_lib.ks";

const App = newtype {
    .window :: SDL.Window,
    .a :: Box[Int32],
};

@eval (impl App as SDL.App = {
    .init = () => (
        SDL.Init(@native "SDL_INIT_VIDEO");
        let window = SDL.CreateWindow(
            "Scale to Space",
            640,
            480,
            @native "SDL_WINDOW_RESIZABLE | SDL_WINDOW_OPENGL",
        );
        let sdl_gl_context = SDL.GL.CreateContext(window);
        SDL.GL.MakeCurrent(window, sdl_gl_context);
        { .window, .a = Box_new(123) }
    ),
    .iterate = self => (
        SDL.GL.SwapWindow(self^.window);
        :Continue
    ),
    .event = (self, event) => (
        if @native "\(event)->type == SDL_EVENT_QUIT" then (
            :Success
        ) else (
            :Continue
        )
    ),
    .quit = (self, result) => (
        SDL.Quit();
    ),
});

SDL.EnterAppMainCallbacks[App](App as SDL.App);
