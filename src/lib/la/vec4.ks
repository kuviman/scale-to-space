const Vec4 = newtype { Float32, Float32, Float32, Float32 };

impl Vec4 as std.fmt.Display = {
    .display = (self, fmt) => (
        std.fmt.write!(fmt, "{ \(self^.0), \(self^.1), \(self^.2), \(self^.3) }");
    ),
};

impl Vec4 as module = (
    module:

    const xyz = ({ x, y, z, w } :: Vec4 ) -> Vec3 => { x, y, z };

    const dot = (a :: Vec4, b :: Vec4) -> Float32 => (
        a.0 * b.0 + a.1 * b.1 + a.2 * b.2 + a.3 * b.3
    );
);
