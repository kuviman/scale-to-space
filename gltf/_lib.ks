use (import "../src/__deps__.ks").*;
use std.rc.Rc;

module:

const Document = import "./document.ks";

const Index = Document.Index;

const Asset = newtype {
    .document :: Document,
    .nodes_by_name :: OrdMap.t[&str, Rc.t[Node]],
};

const Renderer = newtype {
    .program :: ugli.Program,
};

impl Renderer as module = (
    module:

    const Ctx = @context type (&Renderer);

    const init = () -> Renderer => (
        {
            .program = geng.load_shader("assets/shaders/gltf"),
        }
    );
);

const BufferView = newtype {
    .target :: gl.GLenum,
    .gl :: gl.Buffer,
    .stride :: Option.t[Int32],
};

const Attribute = newtype {
    .info :: &ugli.AttributeInfo,
    .buffer :: Rc.t[BufferView],
    .accessor :: &Document.Accessor,
    .component_count :: Int32,
    .stride :: Int32,
};

const MeshPrimitive = newtype {
    .attributes :: ArrayList.t[Attribute],
    # .material :: Material,
    .mode :: gl.GLenum,
};

const Mesh = newtype {
    .primitives :: ArrayList.t[MeshPrimitive],
};

impl Mesh as module = (
    module:

    const draw = (self :: &Mesh, animated :: Bool, matrix :: Mat4) => (
        let renderer = @current Renderer.Ctx;
        let ref camera = @current geng.CameraUniforms.Ctx;

        let program = &renderer^.program;
        program |> ugli.Program.@"use";
        let mut draw_state = ugli.DrawState.init();
        let draw_state = &mut draw_state;
        program
            |> ugli.set_uniform(
                "u_time",
                geng.time_since_start(),
                draw_state
            );
        program
            |> ugli.set_uniform(
                "u_animated",
                if animated then 1 else 0 :: Float32,
                draw_state
            );
        program
            |> ugli.set_uniform(
                "u_model_matrix",
                matrix,
                draw_state
            );
        program
            |> ugli.set_uniform(
                "u_view_matrix",
                camera^.view_matrix,
                draw_state
            );
        program
            |> ugli.set_uniform(
                "u_projection_matrix",
                camera^.projection_matrix,
                draw_state
            );
        @comment_out (
            program
                |> ugli.set_uniform(
                    "u_texture",
                    &model^.texture,
                    draw_state
                );
            let collisions = (@current PlayerCtx).collisions;
            program
                |> ugli.set_uniform(
                    "u_collisions_len",
                    collisions |> ArrayList.length,
                    draw_state
                );
            for { i, collision } in collisions |> ArrayList.iter |> std.iter.enumerate do (
                program
                    |> ugli.set_uniform(
                        &format!("u_collisions[\(i)].normal") |> as_str,
                        collision^.normal,
                        draw_state
                    );
                program
                    |> ugli.set_uniform(
                        &format!("u_collisions[\(i)].penetration") |> as_str,
                        collision^.penetration,
                        draw_state
                    );
            );
            program
                |> ugli.set_uniform(
                    "u_player_pos",
                    (@current PlayerCtx).position,
                    draw_state
                );
            program
                |> ugli.set_uniform(
                    "u_player_radius",
                    (@current PlayerCtx).radius,
                    draw_state
                );
            program
                |> ugli.set_uniform(
                    "u_volleyball_pos",
                    (@current PlayerCtx).volleyball_position,
                    draw_state
                );
            program
                |> ugli.set_uniform(
                    "u_volleyball_radius",
                    (@current PlayerCtx).volleyball_radius,
                    draw_state
                );
        );

        for primitive in &self^.primitives |> ArrayList.iter do (
            let mut count = 0;
            for (attribute :: &Attribute) in &primitive^.attributes |> ArrayList.iter do (
                gl.bind_buffer(attribute^.buffer^.target, attribute^.buffer^.gl);
                count = attribute^.accessor^.count;
                gl.vertex_attrib_pointer(
                    attribute^.info^.location,
                    attribute^.component_count,
                    attribute^.accessor^.componentType,
                    false,
                    attribute^.stride,
                    attribute^.accessor^.byteOffset |> Option.unwrap_or(0),
                );
                gl.enable_vertex_attrib_array(attribute^.info^.location);
            );
            gl.draw_arrays(primitive^.mode, 0, count);
        );
    )
);

const Node = newtype {
    .name :: &str,
    .mesh :: Option.t[Rc.t[Mesh]],
    .children :: ArrayList.t[Rc.t[Node]],
};

impl Node as module = (
    module:

    const draw = (self :: &Node, animated :: Bool, matrix :: Mat4) => (
        # TODO local transform
        if self^.mesh is :Some ref mesh then (
            Mesh.draw(&mesh^^, animated, matrix);
        );
        for child in &self^.children |> ArrayList.iter do (
            Node.draw(&child^^, animated, matrix);
        );
    );
);

const Load = (
    module:

    const Context = @context newtype {
        .document :: &Document,
        .nodes :: OrdMap.t[Index, Rc.t[Node]],
        .meshes :: OrdMap.t[Index, Rc.t[Mesh]],
        .gl_buffers :: OrdMap.t[Index, Rc.t[BufferView]],
    };

    const node = (index :: Index) -> Rc.t[Node] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.nodes |> OrdMap.get(&index) is :Some &node then (
            return node;
        );
        let json_node = &ctx^.document^.json.nodes.[index];
        let mut children = ArrayList.new();
        if json_node^.children is :Some ref children_indices then (
            for &child_index in children_indices |> ArrayList.iter do (
                &mut children |> ArrayList.push_back(Load.node(child_index));
            );
        );
        let mesh = match json_node^.mesh with (
            | :None => :None
            | :Some index => :Some Load.mesh(index)
        );
        let node = Rc.new({
            .name = &json_node^.name |> as_str,
            .mesh,
            .children,
        });
        &mut ctx^.nodes |> OrdMap.add(index, node);
        node
    );

    const buffer_view_as_slice = (buffer_view :: &Document.BufferView) -> Slice.t[Byte] => (
        let ref mut ctx = @current Context;
        let buffer = &ctx^.document^.json.buffers.[buffer_view^.buffer];
        let buffer_data = match buffer^.uri with (
            | :None => ctx^.document^.bin_data
            | :Some _ => panic("no uris pls")
        );
        let offset = match buffer_view^.byteOffset with (
            | :Some offset => offset
            | :None => 0
        );
        Slice.subslice(buffer_data, offset, buffer_view^.byteLength)
    );

    const buffer_view = (index :: Index) -> Option.t[Rc.t[BufferView]] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.gl_buffers |> OrdMap.get(&index) is :Some &buffer then (
            return :Some buffer;
        );
        let json_buffer_view = &ctx^.document^.json.bufferViews.[index];
        let target = match json_buffer_view^.target with (
            | :Some target => target
            | :None => return :None
        );
        let buffer = gl.create_buffer();
        gl.bind_buffer(target, buffer);
        let data = buffer_view_as_slice(json_buffer_view);
        gl.buffer_data(
            target,
            data.length,
            @native "\(data.array)",
            gl.STATIC_DRAW,
        );
        let buffer = Rc.new({
            .target,
            .stride = json_buffer_view^.byteStride,
            .gl = buffer,
        });
        &mut ctx^.gl_buffers |> OrdMap.add(index, buffer);
        :Some buffer
    );

    const mesh = (index :: Document.Index) -> Rc.t[Mesh] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.meshes |> OrdMap.get(&index) is :Some &mesh then (
            return mesh;
        );
        let json_mesh = &ctx^.document^.json.meshes.[index];
        let mut primitives = ArrayList.new();
        for json_primitive in &json_mesh^.primitives |> ArrayList.iter do (
            let mut attributes = ArrayList.new();
            for &{ .key = ref name, .value = accessor_index } in (
                &json_primitive^.attributes.actual_map |> OrdMap.iter
            ) do (
                let mut name = name |> as_str;
                if name == "POSITION" then (
                    name = "a_position";
                ) else if name == "NORMAL" then (
                    name = "a_normal";
                ) else if name == "TEXCOORD_0" then (
                    name = "a_uv";
                );
                let accessor = &ctx^.document^.json.accessors.[accessor_index];
                let buffer = match Load.buffer_view(accessor^.bufferView) with (
                    | :None => continue
                    | :Some buffer => buffer
                );
                let attribute_info = match (
                    &(@current Renderer.Ctx)^.program.attributes
                        |> OrdMap.get(&String.from_str(name))
                ) with (
                    | :None => continue
                    | :Some info => info
                );
                let ty = &accessor^.@"type" |> as_str;
                let component_count = if ty == "SCALAR" then (
                    1
                ) else if ty == "VEC2" then (
                    2
                ) else if ty == "VEC3" then (
                    3
                ) else if ty == "VEC4" then (
                    4
                ) else (
                    panic("unsupported attribute type???")
                );
                let component_size = if accessor^.componentType == gl.FLOAT then (
                    4
                ) else (
                    panic("unsupported component type????")
                );
                let stride = match buffer^.stride with (
                    | :Some stride => stride
                    | :None => component_count * component_size
                );
                let attribute = {
                    .info = attribute_info,
                    .buffer,
                    .component_count,
                    .accessor,
                    .stride,
                };
                &mut attributes |> ArrayList.push_back(attribute);
            );
            let primitive = {
                .attributes,
                .mode = match json_primitive^.mode with (
                    | :Some mode => mode
                    | :None => gl.TRIANGLES
                ),
            };
            &mut primitives |> ArrayList.push_back(primitive);
        );
        let mesh = Rc.new({
            .primitives,
        });
        &mut ctx^.meshes |> OrdMap.add(index, mesh);
        mesh
    );
);

impl Asset as module = (
    module:

    const load = (path :: &str) -> Asset => (
        let mut asset = {
            .document = Document.load(path),
            .nodes_by_name = OrdMap.new(),
        };
        with Load.Context = {
            .document = &asset.document,
            .nodes = OrdMap.new(),
            .meshes = OrdMap.new(),
            .gl_buffers = OrdMap.new(),
        };
        for { index, json_node } in (
            &asset.document.json.nodes
                |> ArrayList.iter
                |> std.iter.enumerate
        ) do (
            let node :: Rc.t[Node] = Load.node(index);
            &mut asset.nodes_by_name |> OrdMap.add(&json_node^.name |> as_str, node);
        );
        asset
    );

    const drop = (self :: Asset) => (
        Document.drop(self.document);
    );

    const find_node = (self :: &Asset, name :: &str) -> &Node => (
        let node = &self^.nodes_by_name |> OrdMap.get(&name) |> Option.unwrap;
        &node^^
    );
);
