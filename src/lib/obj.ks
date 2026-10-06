use (import "./la/_lib.ks").*;
use (import "./common.ks").*;
const ugli = import "./ugli/_lib.ks";

module:

const Vertex = newtype {
    .a_pos :: Vec3,
    .a_uv :: Vec2,
    .a_normal :: Vec3,
};

impl Vertex as std.fmt.Display = {
    .display = (self, fmt) => (
        std.fmt.write!(fmt, "\(self^.a_pos)");
    ),
};

include_ast ugli.Vertex_derive(Vertex);

const Face = newtype {
    Vertex,
    Vertex,
    Vertex,
};

const parse = (s :: &str) -> ArrayList.t[Face] => (
    let mut result = ArrayList.new();
    let mut vs = ArrayList.new();
    let mut vts = ArrayList.new();
    let mut vns = ArrayList.new();
    let vertex = (s :: &str) -> Vertex => (
        let { v, vt_vn } = s |> String.split_once('/');
        let { vt, vn } = vt_vn |> String.split_once('/');
        let v :: Int32 = String.parse(v);
        let vt :: Int32 = String.parse(vt);
        let vn :: Int32 = String.parse(vn);
        # print("vertex index: " + to_string(v));
        {
            .a_pos = vs.[v - 1],
            .a_uv = vts.[vt - 1],
            .a_normal = vns.[vn - 1],
        }
    );
    let mut i = 0;
    for line in s |> String.lines do (
        if i % 1000 == 0 then yield();
        i += 1;
        if line |> String.strip_prefix(.prefix = "v ") is :Some (s) then (
            let { x, yz } = s |> String.split_once(' ');
            let { y, z } = yz |> String.split_once(' ');
            let x = x |> String.parse;
            let y = y |> String.parse;
            let z = z |> String.parse;
            &mut vs |> ArrayList.push_back({ x, y, z });
        ) else if line |> String.strip_prefix(.prefix = "vt ") is :Some (s) then (
            let { u, v } = s |> String.split_once(' ');
            let u = u |> String.parse;
            let v = v |> String.parse;
            &mut vts |> ArrayList.push_back({ u, v });
        ) else if line |> String.strip_prefix(.prefix = "vn ") is :Some (s) then (
            let { x, yz } = s |> String.split_once(' ');
            let { y, z } = yz |> String.split_once(' ');
            let x = x |> String.parse;
            let y = y |> String.parse;
            let z = z |> String.parse;
            &mut vns |> ArrayList.push_back({ x, y, z });
        ) else if line |> String.strip_prefix(.prefix = "f ") is :Some (s) then (
            let mut vertices = ArrayList.new();
            for v in s |> String.split(' ') do (
                &mut vertices |> ArrayList.push_back(vertex(v));
            );
            for i in 2..ArrayList.length(&vertices) do (
                let face = {
                    vertices.[0],
                    vertices.[i - 1],
                    vertices.[i],
                };
                &mut result |> ArrayList.push_back(face);
            );
        );
    );
    result
);
