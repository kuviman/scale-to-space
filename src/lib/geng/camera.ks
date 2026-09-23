use (import "../la/_lib.ks").*;

module:

const Camera = newtype {
    .position :: Vec3,
    .distance :: Float32,
    .rotation :: Angle,
    .attack :: Angle,
    .fov :: Angle,
};

const CameraUniforms = newtype {
    .view_matrix :: Mat4,
    .projection_matrix :: Mat4,
};

impl CameraUniforms as module = (
    module:

    const Ctx = @context CameraUniforms;

    const init = (
        camera :: Camera,
        .framebuffer_size :: Vec2,
    ) -> CameraUniforms => (
        let view_matrix = Mat4.translate({ 0, 0, -camera.distance })
            |> Mat4.mul_mat(Mat4.rotate_x(Angle.sub(camera.attack, Angle.from_degrees(90))))
            |> Mat4.mul_mat(Mat4.rotate_z(Angle.sub(Angle.from_degrees(90), camera.rotation)))
            |> Mat4.mul_mat(Mat4.translate(Vec3.neg(camera.position)));
        let aspect = framebuffer_size.0 / framebuffer_size.1;
        let projection_matrix = Mat4.perspective(camera.fov, aspect, 1, 5000);
        {
            .view_matrix,
            .projection_matrix,
        }
    );
);
