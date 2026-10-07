const Mat4 = newtype { Vec4, Vec4, Vec4, Vec4 };

impl Mat4 as std.fmt.Display = {
    .display = (self, fmt) => (
        std.fmt.write!(fmt, "{ \(self^.0), \(self^.1), \(self^.2), \(self^.3) }");
    ),
};

impl Mat4 as module = (
    module:

    const IDENTITY :: Mat4 = {
        { 1, 0, 0, 0 },
        { 0, 1, 0, 0 },
        { 0, 0, 1, 0 },
        { 0, 0, 0, 1 },
    };

    const transpose = (m :: Mat4) -> Mat4 => {
        { m.0.0, m.1.0, m.2.0, m.3.0 },
        { m.0.1, m.1.1, m.2.1, m.3.1 },
        { m.0.2, m.1.2, m.2.2, m.3.2 },
        { m.0.3, m.1.3, m.2.3, m.3.3 },
    };

    const div = (m :: Mat4, k :: Float32) -> Mat4 => {
        { m.0.0 / k, m.0.1 / k, m.0.2 / k, m.0.3 / k },
        { m.1.0 / k, m.1.1 / k, m.1.2 / k, m.1.3 / k },
        { m.2.0 / k, m.2.1 / k, m.2.2 / k, m.2.3 / k },
        { m.3.0 / k, m.3.1 / k, m.3.2 / k, m.3.3 / k },
    };

    const mul_mat = (a :: Mat4, b :: Mat4) -> Mat4 => (
        let b = transpose(b);
        const dot = Vec4.dot;
        let result = {
            { dot(a.0, b.0), dot(a.0, b.1), dot(a.0, b.2), dot(a.0, b.3) },
            { dot(a.1, b.0), dot(a.1, b.1), dot(a.1, b.2), dot(a.1, b.3) },
            { dot(a.2, b.0), dot(a.2, b.1), dot(a.2, b.2), dot(a.2, b.3) },
            { dot(a.3, b.0), dot(a.3, b.1), dot(a.3, b.2), dot(a.3, b.3) },
        };
        result
    );

    const mul_vec = (m :: Mat4, v :: Vec4) -> Vec4 => (
        let result = {
            Vec4.dot(m.0, v),
            Vec4.dot(m.1, v),
            Vec4.dot(m.2, v),
            Vec4.dot(m.3, v),
        };
        result
    );

    const translate = (dv :: Vec3) -> Mat4 => {
        { 1, 0, 0, dv.0 },
        { 0, 1, 0, dv.1 },
        { 0, 0, 1, dv.2 },
        { 0, 0, 0, 1 },
    };

    const scale = ({ x, y, z } :: Vec3) -> Mat4 => {
        { x, 0, 0, 0 },
        { 0, y, 0, 0 },
        { 0, 0, z, 0 },
        { 0, 0, 0, 1 },
    };

    const scale_uniform = (k :: Float32) -> Mat4 => (
        scale({ k, k, k })
    );

    const ortho = (
        .left :: Float32,
        .right :: Float32,
        .bottom :: Float32,
        .top :: Float32,
        .near :: Float32,
        .far :: Float32,
    ) -> Mat4 => {
        { 2 / (right - left), 0, 0, 1 - 2 * right / (right - left) },
        { 0, 2 / (top - bottom), 0, 1 - 2 * top / (top - bottom) },
        { 0, 0, 2 / (near - far), 1 - 2 * near / (near - far) },
        { 0, 0, 0, 1 },
    };

    const perspective = (
        fov :: Angle,
        aspect :: Float32,
        near :: Float32,
        far :: Float32,
    ) -> Mat4 => (
        let ymax = near * math.tan(fov.radians / 2);
        let xmax = ymax * aspect;
        frustum(
            .left = -xmax,
            .right = xmax,
            .bottom = -ymax,
            .top = ymax,
            .near,
            .far,
        )
    );

    const frustum = (
        .left :: Float32,
        .right :: Float32,
        .bottom :: Float32,
        .top :: Float32,
        .near :: Float32,
        .far :: Float32,
    ) -> Mat4 => (
        let double_near = near + near;
        let width = right - left;
        let height = top - bottom;
        let depth = far - near;
        {
            { double_near / width, 0, (right + left) / width, 0 },
            { 0, double_near / height, (top + bottom) / height, 0 },
            { 0, 0, (-far - near) / depth, (-double_near * far) / depth },
            { 0, 0, -1, 0 },
        }
    );

    const rotate = (v :: Vec3, angle :: Angle) -> Mat4 => (
        let { sin, cos } = Angle.sin_cos(angle);
        {
            {
                v.0 * v.0 * (1 - cos) + cos,
                v.0 * v.1 * (1 - cos) - v.2 * sin,
                v.0 * v.2 * (1 - cos) + v.1 * sin,
                0
            },
            {
                v.1 * v.0 * (1 - cos) + v.2 * sin,
                v.1 * v.1 * (1 - cos) + cos,
                v.1 * v.2 * (1 - cos) - v.0 * sin,
                0,
            },
            {
                v.2 * v.0 * (1 - cos) - v.1 * sin,
                v.2 * v.1 * (1 - cos) + v.0 * sin,
                v.2 * v.2 * (1 - cos) + cos,
                0,
            },
            { 0, 0, 0, 1 },
        }
    );

    const rotate_x = (angle :: Angle) -> Mat4 => (
        rotate({ 1, 0, 0 }, angle)
    );

    const rotate_y = (angle :: Angle) -> Mat4 => (
        rotate({ 0, 1, 0 }, angle)
    );

    const rotate_z = (angle :: Angle) -> Mat4 => (
        rotate({ 0, 0, 1 }, angle)
    );
);
