use (import "../common.ks").*;
use (import "../la/_lib.ks").*;
const SDL = import "../sdl3/_lib.ks";

use std.collections.Queue;

module:

const ContextT = newtype {
    .events :: Queue.t[Event],
};
const Context = @context ContextT;

const init = () -> ContextT => (
    let mut events = Queue.new();
    {
        .events,
    }
);

const Key = newtype (
    | :PageUp
    | :PageDown
    | :A
    | :B
    | :C
    | :D
    | :E
    | :F
    | :G
    | :H
    | :I
    | :J
    | :K
    | :L
    | :M
    | :N
    | :O
    | :P
    | :Q
    | :R
    | :S
    | :T
    | :U
    | :V
    | :W
    | :X
    | :Y
    | :Z
    | :ArrowLeft
    | :ArrowRight
    | :ArrowUp
    | :ArrowDown
    | :Space
    | :Backspace
    | :Enter
    | :LeftShift
    | :Digit1
    | :Digit2
    | :Digit3
    | :Digit4
    | :Digit5
    | :Digit6
    | :Digit7
    | :Digit8
    | :Digit9
    | :Digit0
);

impl Key as module = (
    module:

    const from_scancode = (code :: SDL.Scancode) -> Option.t[Key] => with_return (
        if @native "\(code) == SDL_SCANCODE_A" then return :Some :A;
        if @native "\(code) == SDL_SCANCODE_B" then return :Some :B;
        if @native "\(code) == SDL_SCANCODE_C" then return :Some :C;
        if @native "\(code) == SDL_SCANCODE_D" then return :Some :D;
        if @native "\(code) == SDL_SCANCODE_E" then return :Some :E;
        if @native "\(code) == SDL_SCANCODE_F" then return :Some :F;
        if @native "\(code) == SDL_SCANCODE_G" then return :Some :G;
        if @native "\(code) == SDL_SCANCODE_H" then return :Some :H;
        if @native "\(code) == SDL_SCANCODE_I" then return :Some :I;
        if @native "\(code) == SDL_SCANCODE_J" then return :Some :J;
        if @native "\(code) == SDL_SCANCODE_K" then return :Some :K;
        if @native "\(code) == SDL_SCANCODE_L" then return :Some :L;
        if @native "\(code) == SDL_SCANCODE_M" then return :Some :M;
        if @native "\(code) == SDL_SCANCODE_N" then return :Some :N;
        if @native "\(code) == SDL_SCANCODE_O" then return :Some :O;
        if @native "\(code) == SDL_SCANCODE_P" then return :Some :P;
        if @native "\(code) == SDL_SCANCODE_Q" then return :Some :Q;
        if @native "\(code) == SDL_SCANCODE_R" then return :Some :R;
        if @native "\(code) == SDL_SCANCODE_S" then return :Some :S;
        if @native "\(code) == SDL_SCANCODE_T" then return :Some :T;
        if @native "\(code) == SDL_SCANCODE_U" then return :Some :U;
        if @native "\(code) == SDL_SCANCODE_V" then return :Some :V;
        if @native "\(code) == SDL_SCANCODE_W" then return :Some :W;
        if @native "\(code) == SDL_SCANCODE_X" then return :Some :X;
        if @native "\(code) == SDL_SCANCODE_Y" then return :Some :Y;
        if @native "\(code) == SDL_SCANCODE_Z" then return :Some :Z;
        if @native "\(code) == SDL_SCANCODE_LEFT" then return :Some :ArrowLeft;
        if @native "\(code) == SDL_SCANCODE_RIGHT" then return :Some :ArrowRight;
        if @native "\(code) == SDL_SCANCODE_UP" then return :Some :ArrowUp;
        if @native "\(code) == SDL_SCANCODE_DOWN" then return :Some :ArrowDown;
        if @native "\(code) == SDL_SCANCODE_SPACE" then return :Some :Space;
        if @native "\(code) == SDL_SCANCODE_LSHIFT" then return :Some :LeftShift;
        if @native "\(code) == SDL_SCANCODE_RETURN" then return :Some :Enter;
        if @native "\(code) == SDL_SCANCODE_BACKSPACE" then return :Some :Backspace;
        if @native "\(code) == SDL_SCANCODE_0" then return :Some :Digit0;
        if @native "\(code) == SDL_SCANCODE_1" then return :Some :Digit1;
        if @native "\(code) == SDL_SCANCODE_2" then return :Some :Digit2;
        if @native "\(code) == SDL_SCANCODE_3" then return :Some :Digit3;
        if @native "\(code) == SDL_SCANCODE_4" then return :Some :Digit4;
        if @native "\(code) == SDL_SCANCODE_5" then return :Some :Digit5;
        if @native "\(code) == SDL_SCANCODE_6" then return :Some :Digit6;
        if @native "\(code) == SDL_SCANCODE_7" then return :Some :Digit7;
        if @native "\(code) == SDL_SCANCODE_8" then return :Some :Digit8;
        if @native "\(code) == SDL_SCANCODE_9" then return :Some :Digit9;
        if @native "\(code) == SDL_SCANCODE_PAGEUP" then return :Some :PageUp;
        if @native "\(code) == SDL_SCANCODE_PAGEDOWN" then return :Some :PageDown;
        :None
    );

    const scancode = (key :: Key) -> SDL.Scancode => match key with (
        | :A => @native "SDL_SCANCODE_A"
        | :B => @native "SDL_SCANCODE_B"
        | :C => @native "SDL_SCANCODE_C"
        | :D => @native "SDL_SCANCODE_D"
        | :E => @native "SDL_SCANCODE_E"
        | :F => @native "SDL_SCANCODE_F"
        | :G => @native "SDL_SCANCODE_G"
        | :H => @native "SDL_SCANCODE_H"
        | :I => @native "SDL_SCANCODE_I"
        | :J => @native "SDL_SCANCODE_J"
        | :K => @native "SDL_SCANCODE_K"
        | :L => @native "SDL_SCANCODE_L"
        | :M => @native "SDL_SCANCODE_M"
        | :N => @native "SDL_SCANCODE_N"
        | :O => @native "SDL_SCANCODE_O"
        | :P => @native "SDL_SCANCODE_P"
        | :Q => @native "SDL_SCANCODE_Q"
        | :R => @native "SDL_SCANCODE_R"
        | :S => @native "SDL_SCANCODE_S"
        | :T => @native "SDL_SCANCODE_T"
        | :U => @native "SDL_SCANCODE_U"
        | :V => @native "SDL_SCANCODE_V"
        | :W => @native "SDL_SCANCODE_W"
        | :X => @native "SDL_SCANCODE_X"
        | :Y => @native "SDL_SCANCODE_Y"
        | :Z => @native "SDL_SCANCODE_Z"
        | :Digit0 => @native "SDL_SCANCODE_0"
        | :Digit1 => @native "SDL_SCANCODE_1"
        | :Digit2 => @native "SDL_SCANCODE_2"
        | :Digit3 => @native "SDL_SCANCODE_3"
        | :Digit4 => @native "SDL_SCANCODE_4"
        | :Digit5 => @native "SDL_SCANCODE_5"
        | :Digit6 => @native "SDL_SCANCODE_6"
        | :Digit7 => @native "SDL_SCANCODE_7"
        | :Digit8 => @native "SDL_SCANCODE_8"
        | :Digit9 => @native "SDL_SCANCODE_9"
        | :ArrowLeft => @native "SDL_SCANCODE_LEFT"
        | :ArrowRight => @native "SDL_SCANCODE_RIGHT"
        | :ArrowUp => @native "SDL_SCANCODE_UP"
        | :ArrowDown => @native "SDL_SCANCODE_DOWN"
        | :Space => @native "SDL_SCANCODE_SPACE"
        | :LeftShift => @native "SDL_SCANCODE_LSHIFT"
        | :Enter => @native "SDL_SCANCODE_RETURN"
        | :Backspace => @native "SDL_SCANCODE_BACKSPACE"
        | :PageUp => @native "SDL_SCANCODE_PAGEUP"
        | :PageDown => @native "SDL_SCANCODE_PAGEDOWN"
    );

    const is_pressed = (key :: Key) -> Bool => (
        @native "SDL_GetKeyboardState(NULL)[\(scancode(key))]"
    );
);

const MouseButton = newtype (
    | :Left
    | :Middle
    | :Right
);

impl MouseButton as module = (
    module:

    const Raw = @opaque_type "int";

    const from_raw = (raw :: Raw) -> Option.t[MouseButton] => (
        if @native "\(raw) == SDL_BUTTON_LEFT" then (
            :Some :Left
        ) else if @native "\(raw) == SDL_BUTTON_MIDDLE" then (
            :Some :Middle
        ) else if @native "\(raw) == SDL_BUTTON_RIGHT" then (
            :Some :Right
        ) else (
            :None
        )
    );

    const into_raw = (button :: MouseButton) -> Raw => (
        match button with (
            | :Left => @native "SDL_BUTTON_LEFT"
            | :Middle => @native "SDL_BUTTON_MIDDLE"
            | :Right => @native "SDL_BUTTON_RIGHT"
        )
    );

    const is_pressed = (button :: MouseButton) -> Bool => (
        let mask :: @opaque_type "SDL_MouseButtonFlags" = @native "SDL_BUTTON_MASK(\(into_raw(button)))";
        @native "(SDL_GetMouseState(NULL, NULL) & \(mask)) != 0"
    );
);

const Event = newtype (
    | :MouseMove {
        .position :: Vec2,
        .delta :: Vec2,
    }
    | :KeyPress Key
    | :MousePress { .button :: MouseButton }
    | :PointerPress { .pos :: Vec2 }
    | :Quit
);

const convert = (event :: SDL.Event) -> Option.t[Event] => with_return (
    if @native "\(event).type == SDL_EVENT_MOUSE_BUTTON_DOWN" then (
        let pos :: Vec2 = { @native "\(event).button.x", @native "\(event).button.y" };
        let window_size = geng.get_window_size();
        let pos = { pos.0, window_size.1 - 1 - pos.1 };
        return :Some :PointerPress { .pos };
        let button = MouseButton.from_raw(@native "\(event).button.button")
            |> Option.unwrap_or_else(() => return :None);
        :Some :MousePress { .button }
    ) else if @native "\(event).type == SDL_EVENT_QUIT" then (
        :Some :Quit
    ) else if @native "\(event).type == SDL_EVENT_MOUSE_MOTION" then (
        let window_size = geng.get_window_size();
        :Some :MouseMove {
            .position = {
                @native "\(event).motion.x",
                window_size.1 - 1 - (@native "\(event).motion.y"),
            },
            .delta = {
                @native "\(event).motion.xrel",
                @native "-\(event).motion.yrel",
            },
        }
    ) else if @native "\(event).type == SDL_EVENT_KEY_DOWN" then (
        Key.from_scancode(@native "\(event).key.scancode")
            |> Option.map(key => :KeyPress key)
    ) else (
        :None
    )
);

const iter_events = () -> std.iter.Iterable[Event] => (
    let mut ctx = (@current Context);
    {
        .iter = consumer => (
            while SDL.PollEvent() is :Some sdl_event do (
                if convert(sdl_event) is :Some event then (
                    consumer(event);
                );
            );
        ),
    }
);

const is_any_pointer_pressed = () -> Bool => (
    @native "SDL_GetMouseState(NULL, NULL) != 0"
);
