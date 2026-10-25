const FpsCounter = newtype {
    .frames :: Float32,
    .start :: Float32,
};

impl FpsCounter as module = (
    module:

    const new = () -> FpsCounter => {
        .frames = 0,
        .start = geng.time_since_start(),
    };

    const frame = (self :: &mut FpsCounter) => (
        self^.frames += 1;
        if geng.time_since_start() - self^.start > 1 then (
            self^ = new();
        );
    );

    const fps = (self :: &FpsCounter) -> Float32 => (
        let seconds = geng.time_since_start() - self^.start;
        if seconds > 0.01 then (
            self^.frames / seconds
        ) else 0
    );

    const draw = (
        self :: &mut FpsCounter,
        .font :: &geng.Font,
        .matrix :: Mat4,
        .color :: Vec4,
        .align :: Float32,
    ) => (
        frame(self);
        let fps = Float32_to_Int32(fps(&self^));
        geng.Font.draw(
            font,
            &format!("FPS: \(fps)")
                |> as_str,
            .matrix,
            .color,
            .align,
        );
    );
);
