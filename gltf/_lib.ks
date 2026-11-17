use (import "../src/__deps__.ks").*;
use std.rc.Rc;

const component_size = (ty :: gl.GLenum) -> Int32 => with_return (
    if ty == gl.BYTE then (return 1);
    if ty == gl.UNSIGNED_BYTE then (return 1);
    if ty == gl.SHORT then (return 2);
    if ty == gl.UNSIGNED_SHORT then (return 2);
    if ty == gl.INT then (return 4);
    if ty == gl.UNSIGNED_INT then (return 4);
    if ty == gl.FLOAT then (return 4);
    panic_fmt!("unsupported component type: \(ty)")
);

module:

const Document = import "./document.ks";

const Index = Document.Index;

const Asset = newtype {
    .document :: Document,
    .nodes_by_name :: OrdMap.t[&str, Rc.t[Node]],
    .scenes_by_name :: OrdMap.t[&str, Rc.t[Scene]],
    .scene :: Rc.t[Scene],
};

const Renderer = newtype {
    .program :: ugli.Program,
    .white_texture :: Rc.t[ugli.Texture],
};

impl Renderer as module = (
    module:

    const Ctx = @context type {
        .renderer :: &Renderer,
        .depth :: Option.t[type (&ugli.Texture)],
        .normal :: Option.t[type (&ugli.Texture)],
    };

    const init = () -> Renderer => init_with("assets/shaders/gltf");

    const init_with = (path :: &str) -> Renderer => (
        {
            .program = geng.load_shader(path),
            .white_texture = Rc.new(ugli.Texture.load("assets/white.png", :Nearest)),
        }
    );
);

const BufferView = newtype {
    .data :: ArrayList.t[Byte],
    .target :: gl.GLenum,
    .gl :: gl.Buffer,
    .stride :: Option.t[Int32],
};

impl BufferView as module = (
    module:

    const as_slice = [T] (self :: &BufferView) -> Slice.t[T] => (
        let raw_data = &self^.data |> ArrayList.as_slice;
        @native ''
            (\(type (Slice.t[T]))) {
                .array = \(raw_data).array,
                .length = \(raw_data).length / sizeof(\(type T)),
            }''
    );
);

const Attribute = newtype {
    .name :: &str,
    .buffer :: Rc.t[BufferView],
    .accessor :: &Document.Accessor,
    .component_count :: Int32,
    .stride :: Int32,
};

const MeshIndices = newtype {
    .buffer :: Rc.t[BufferView],
    .accessor :: &Document.Accessor,
};

const MeshPrimitive = newtype {
    .attributes :: ArrayList.t[Attribute],
    .indices :: Option.t[MeshIndices],
    .material :: Rc.t[Material],
    .mode :: gl.GLenum,
};

impl MeshPrimitive as module = (
    module:

    const Vertex = newtype {
        .position :: Vec3,
        .uv :: Vec2,
        .normal :: Vec3,
    };

    const Face = newtype {
        .vertices :: { Vertex, Vertex, Vertex },
    };

    const faces = (self :: &MeshPrimitive) -> std.iter.Iterable[Face] => {
        .iter = @move consumer => (
            if self^.mode != gl.TRIANGLES then (
                panic("faces only work for TRIANGLES");
            );
            let find_attribute = name => with_return (
                for attribute in &self^.attributes |> ArrayList.iter do (
                    if attribute^.name == name then (
                        return attribute;
                    );
                );
                panic_fmt!("\(name) attribute not found")
            );
            let positions :: Slice.t[Vec3] = &find_attribute("a_pos")^.buffer^
                |> BufferView.as_slice;
            let uvs :: Slice.t[Vec2] = &find_attribute("a_uv")^.buffer^
                |> BufferView.as_slice;
            let normals :: Slice.t[Vec3] = &find_attribute("a_normal")^.buffer^
                |> BufferView.as_slice;
            let vertex = i -> Vertex => {
                .position = (positions |> Slice.at(i))^,
                .uv = (uvs |> Slice.at(i))^,
                .normal = (normals |> Slice.at(i))^,
            };
            let face = (i0, i1, i2) => (
                let face :: Face = {
                    .vertices = {
                        vertex(i0),
                        vertex(i1),
                        vertex(i2),
                    },
                };
                consumer(face);
            );
            match self^.indices with (
                | :None => (
                    let mut i = 0;
                    while i < positions.length do (
                        face(i, i + 1, i + 2);
                        i += 3;
                    );
                )
                | :Some ref indices => (
                    let index_size = component_size(indices^.accessor^.componentType);
                    let indices_data :: Slice.t[Byte] = &indices^.buffer^.data |> ArrayList.as_slice;
                    let idx_at = with_return (
                        if index_size == 1 then (
                            return (offset => (
                                @native ''
                                    *(uint8_t*)((char*)\(indices_data).array + \(offset))''
                            ));
                        );
                        if index_size == 2 then (
                            return (offset => (
                                @native ''
                                    *(uint16_t*)((char*)\(indices_data).array + \(offset))''
                            ));
                        );
                        if index_size == 4 then (
                            return (offset => (
                                @native ''
                                    *(uint32_t*)((char*)\(indices_data).array + \(offset))''
                            ));
                        );
                        panic_fmt!("index size is \(index_size)")
                    );
                    let mut i = 0;
                    while i < indices_data.length do (
                        face(idx_at(i), idx_at(i + index_size), idx_at(i + 2 * index_size));
                        i += 3 * index_size;
                    );
                )
            )
        ),
    };
);

const Material = newtype {
    .name :: Option.t[String],
    .base_color_factor :: Vec4,
    .texture :: Rc.t[ugli.Texture],
};

const Mesh = newtype {
    .name :: Option.t[&str],
    .primitives :: ArrayList.t[MeshPrimitive],
};

impl Mesh as module = (
    module:

    const draw = (self :: &Mesh, animated :: Bool, matrix :: Mat4) => (
        let ctx = @current Renderer.Ctx;
        let ref camera = @current geng.CameraUniforms.Ctx;

        let program = &ctx.renderer^.program;
        program |> ugli.Program.@"use";
        let mut draw_state = ugli.DrawState.init();
        @native "glDisable(GL_BLEND)";
        let draw_state = &mut draw_state;
        if ctx.depth is :Some texture then (
            program
                |> ugli.set_uniform(
                    "u_depth_texture",
                    texture,
                    draw_state
                );
        );
        if ctx.normal is :Some texture then (
            program
                |> ugli.set_uniform(
                    "u_normal_texture",
                    texture,
                    draw_state
                );
        );
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
                "u_framebuffer_size",
                (@current ugli.Context).framebuffer.size |> Vec2i.into_vec2,
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
            # save draw state
            let mut draw_state = draw_state^;
            let draw_state = &mut draw_state;
            program
                |> ugli.set_uniform(
                    "u_base_color_factor",
                    primitive^.material^.base_color_factor,
                    draw_state
                );
            program
                |> ugli.set_uniform(
                    "u_base_color_texture",
                    &primitive^.material^.texture^,
                    draw_state
                );
            let mut count = 0;
            for (attribute :: &Attribute) in &primitive^.attributes |> ArrayList.iter do (
                let attribute_info = match (
                    &(@current Renderer.Ctx).renderer^.program.attributes
                        |> OrdMap.get(&String.from_str(attribute^.name))
                ) with (
                    | :None => continue
                    | :Some info => info
                );
                gl.bind_buffer(attribute^.buffer^.target, attribute^.buffer^.gl);
                count = attribute^.accessor^.count;
                gl.vertex_attrib_pointer(
                    attribute_info^.location,
                    attribute^.component_count,
                    attribute^.accessor^.componentType,
                    false,
                    attribute^.stride,
                    attribute^.accessor^.byteOffset |> Option.unwrap_or(0),
                );
                gl.enable_vertex_attrib_array(attribute_info^.location);
            );
            match primitive^.indices with (
                | :Some ref indices => (
                    gl.bind_buffer(indices^.buffer^.target, indices^.buffer^.gl);
                    gl.draw_elements(
                        primitive^.mode,
                        indices^.accessor^.count,
                        indices^.accessor^.componentType,
                        @native "NULL",
                    );
                )
                | :None => (
                    gl.draw_arrays(primitive^.mode, 0, count);
                )
            );
        );
    )
);

const Node = newtype {
    .name :: &str,
    .local_transform :: Mat4,
    .mesh :: Option.t[Rc.t[Mesh]],
    .children :: ArrayList.t[Rc.t[Node]],
};

impl Node as module = (
    module:

    const draw = (self :: &Node, animated :: Bool, matrix :: Mat4) => (
        let matrix = Mat4.mul_mat(matrix, self^.local_transform);
        if self^.mesh is :Some ref mesh then (
            Mesh.draw(&mesh^^, animated, matrix);
        );
        for child in &self^.children |> ArrayList.iter do (
            Node.draw(&child^^, animated, matrix);
        );
    );
);

const Scene = newtype {
    .name :: &str,
    .nodes :: ArrayList.t[Rc.t[Node]],
};

const Load = (
    module:

    const Context = @context newtype {
        .document :: &Document,
        .nodes :: OrdMap.t[Index, Rc.t[Node]],
        .scenes :: OrdMap.t[Index, Rc.t[Scene]],
        .meshes :: OrdMap.t[Index, Rc.t[Mesh]],
        .materials :: OrdMap.t[Index, Rc.t[Material]],
        .textures :: OrdMap.t[Index, Rc.t[ugli.Texture]],
    };

    const material = (index :: Index) -> Rc.t[Material] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.materials |> OrdMap.get(&index) is :Some &material then (
            return material;
        );
        let json_material = &ctx^.document^.json.materials.[index];
        let name = &json_material^.name |> Option.as_ref |> Option.map(String.clone);
        let material = Rc.new(match json_material^.pbrMetallicRoughness with (
            | :None => {
                .name,
                .texture = (@current Renderer.Ctx).renderer^.white_texture,
                .base_color_factor = { 1, 1, 1, 1 },
            }
            | :Some ref pbr => {
                .name,
                .base_color_factor = match pbr^.baseColorFactor with (
                    | :None => { 1, 1, 1, 1 }
                    | :Some a => (
                        let a = Slice.of_array(&a);
                        let a = i => (a |> Slice.at(i))^;
                        { a(0), a(1), a(2), a(3) }
                    )
                ),
                .texture = match pbr^.baseColorTexture with (
                    | :None => (@current Renderer.Ctx).renderer^.white_texture
                    | :Some ref texture => (
                        # TODO texture^.texCoord
                        Load.texture(texture^.index)
                    )
                ),
            }
        ));
        &mut ctx^.materials |> OrdMap.add(index, material);
        material
    );
    const texture = (index :: Index) -> Rc.t[ugli.Texture] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.textures |> OrdMap.get(&index) is :Some &texture then (
            return texture;
        );
        let json_texture = &ctx^.document^.json.textures.[index];
        let image_index = json_texture^.source
            |> Option.unwrap_or_else(() => panic("texture with no source"));
        let image = &ctx^.document^.json.images.[image_index];
        let image = match image^.uri with (
            | :Some _ => panic("TODO load external images")
            | :None => (
                let buffer_view_index = image^.bufferView
                    |> Option.unwrap_or_else(() => panic("image with no uri or bufferView"));
                let data = Load.buffer_view_as_slice(&ctx^.document^.json.bufferViews.[buffer_view_index]);
                let io = SDL.IOFromConstMem(data);
                let mime_type = &image^.mimeType
                    |> Option.as_ref
                    |> Option.map(as_str)
                    |> Option.unwrap_or_else(() => panic("mime type not specified"));
                match mime_type |> String.strip_prefix(.prefix = "image/") with (
                    | :Some ext => SDL.IMG.LoadTyped_IO(io, true, ext)
                    | :None => SDL.IMG.Load_IO(io, true)
                )
            )
        );
        @defer SDL.DestroySurface(image);
        let ugli_texture = ugli.Texture.from_sdl_surface(&image, :Nearest);
        let sampler_index = json_texture^.sampler
            |> Option.unwrap_or_else(() => panic("texture with no sampler"));
        let sampler = &ctx^.document^.json.samplers.[sampler_index];
        if sampler^.minFilter is :Some filter then (
            gl.tex_parameter_i(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, filter);
        );
        if sampler^.magFilter is :Some filter then (
            gl.tex_parameter_i(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, filter);
        );
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_S,
            sampler^.wrapS
                |> Option.unwrap_or(UInt32_to_Int32(gl.REPEAT)),
        );
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_T,
            sampler^.wrapT
                |> Option.unwrap_or(UInt32_to_Int32(gl.REPEAT)),
        );
        let is_pot = (mut x :: Int32) => with_return (
            while x % 2 == 0 do (
                x /= 2;
            );
            x == 1
        );
        let is_pot = is_pot(@native "\(image)->w") and is_pot(@native "\(image)->h");
        if is_pot then (
            gl.generate_mipmap(gl.TEXTURE_2D);
        );
        let texture = Rc.new(ugli_texture);
        &mut ctx^.textures |> OrdMap.add(index, texture);
        texture
    );
    const scene = (index :: Index) -> Rc.t[Scene] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.scenes |> OrdMap.get(&index) is :Some &scene then (
            return scene;
        );
        let json_scene = &ctx^.document^.json.scenes.[index];
        let mut nodes = ArrayList.new();
        if json_scene^.nodes is :Some ref node_indices then (
            for &node_index in node_indices |> ArrayList.iter do (
                &mut nodes |> ArrayList.push_back(Load.node(node_index));
            );
        );
        let scene = Rc.new({
            .name = &json_scene^.name |> as_str,
            .nodes,
        });
        &mut ctx^.scenes |> OrdMap.add(index, scene);
        scene
    );
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
        let mut local_transform = Mat4.IDENTITY;
        const arr_at = [T, N] (a :: &Array.t[T, N], i) => (
            (Slice.of_array(a) |> Slice.at(i))^
        );
        if json_node^.scale is :Some ref scale then (
            local_transform = Mat4.mul_mat(
                Mat4.scale({
                    arr_at(scale, 0),
                    arr_at(scale, 1),
                    arr_at(scale, 2),
                }),
                local_transform,
            );
        );
        if json_node^.rotation is :Some ref q then (
            local_transform = Mat4.mul_mat(
                Quat.into_mat4({
                    .i = arr_at(q, 0),
                    .j = arr_at(q, 1),
                    .k = arr_at(q, 2),
                    .w = arr_at(q, 3),
                }),
                local_transform,
            );
        );
        if json_node^.translation is :Some ref v then (
            local_transform = Mat4.mul_mat(
                Mat4.translate({
                    arr_at(v, 0),
                    arr_at(v, 1),
                    arr_at(v, 2),
                }),
                local_transform,
            );
        );
        if json_node^.matrix is :Some _ then (
            panic("TODO matrix transform");
        );
        let node = Rc.new({
            .name = &json_node^.name |> as_str,
            .local_transform,
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

    const buffer_view = (
        index :: Index,
        postprocess :: Slice.mutable[Byte] -> (),
    ) -> Rc.t[BufferView] => (
        let ref ctx = @current Context;
        let json_buffer_view = &ctx^.document^.json.bufferViews.[index];
        let target = match json_buffer_view^.target with (
            | :Some target => target
            | :None => panic("buffer view target unspecified")
        );
        let buffer = gl.create_buffer();
        gl.bind_buffer(target, buffer);
        let original_data = buffer_view_as_slice(json_buffer_view);
        let mut data = ArrayList.with_capacity(Int32_to_UInt32(original_data.length));
        @native "memcpy(\(&mut data)->buf, \(original_data.array), \(original_data.length))";
        @native "\(&mut data)->length = \(original_data.length)";
        postprocess(&mut data |> ArrayList.as_slice_mut);

        gl.buffer_data(
            target,
            &data |> ArrayList.length,
            @native "\(&data)->buf",
            gl.STATIC_DRAW,
        );
        let buffer = Rc.new({
            .data,
            .target,
            .stride = json_buffer_view^.byteStride,
            .gl = buffer,
        });
        buffer
    );

    const mesh = (index :: Document.Index) -> Rc.t[Mesh] => with_return (
        let ref mut ctx = @current Context;
        if &ctx^.meshes |> OrdMap.get(&index) is :Some &mesh then (
            return mesh;
        );
        let json_mesh = &ctx^.document^.json.meshes.[index];
        let mut primitives = ArrayList.new();
        for json_primitive in &json_mesh^.primitives |> ArrayList.iter do (
            let material = match json_primitive^.material with (
                | :None => continue
                | :Some index => Load.material(index)
            );
            let mut attributes = ArrayList.new();
            for &{ .key = ref name, .value = accessor_index } in (
                &json_primitive^.attributes.actual_map |> OrdMap.iter
            ) do (
                let mut name = name |> as_str;
                if name == "POSITION" then (
                    name = "a_pos";
                ) else if name == "NORMAL" then (
                    name = "a_normal";
                ) else if name == "TEXCOORD_0" then (
                    name = "a_uv";
                );
                let accessor = &ctx^.document^.json.accessors.[accessor_index];
                let buffer = Load.buffer_view(accessor^.bufferView, raw_data => (
                    if name == "a_uv" then (
                        let data :: Slice.mutable[Vec2] = @native "#uninitialized";
                        @native "\(data).array = \(raw_data).array";
                        @native "\(data).length = \(raw_data).length / (sizeof(Float32) * 2)";
                        for v in data |> Slice.iter_mut do (
                            v^.1 = 1 - v^.1;
                        );
                    );
                ));
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
                let component_size = component_size(accessor^.componentType);
                let stride = match buffer^.stride with (
                    | :Some stride => stride
                    | :None => component_count * component_size
                );
                let attribute = {
                    .name,
                    .buffer,
                    .component_count,
                    .accessor,
                    .stride,
                };
                &mut attributes |> ArrayList.push_back(attribute);
            );
            let indices = json_primitive^.indices |> Option.map(accessor_index => (
                let accessor = &ctx^.document^.json.accessors.[accessor_index];
                let buffer = Load.buffer_view(accessor^.bufferView, _ => ());
                let ty = &accessor^.@"type" |> as_str;
                if ty != "SCALAR" then panic("indices are not SCALAR???");
                {
                    .accessor,
                    .buffer,
                }
            ));
            let primitive = {
                .attributes,
                .indices,
                .mode = match json_primitive^.mode with (
                    | :Some mode => mode
                    | :None => gl.TRIANGLES
                ),
                .material,
            };
            &mut primitives |> ArrayList.push_back(primitive);
        );
        let mesh = Rc.new({
            .name = &json_mesh^.name |> Option.as_ref |> Option.map(as_str),
            .primitives,
        });
        &mut ctx^.meshes |> OrdMap.add(index, mesh);
        mesh
    );
);

impl Asset as module = (
    module:

    const load = (path :: &str) -> Asset => (
        let mut document = Document.load(path);
        let mut nodes_by_name = OrdMap.new();
        let mut scenes_by_name = OrdMap.new();
        with Load.Context = {
            .document = &document,
            .nodes = OrdMap.new(),
            .meshes = OrdMap.new(),
            .scenes = OrdMap.new(),
            .textures = OrdMap.new(),
            .materials = OrdMap.new(),
        };
        for { index, json_node } in (
            &document.json.nodes
                |> ArrayList.iter
                |> std.iter.enumerate
        ) do (
            let node :: Rc.t[Node] = Load.node(index);
            &mut nodes_by_name |> OrdMap.add(&json_node^.name |> as_str, node);
        );
        for { index, json_scene } in (
            &document.json.scenes
                |> ArrayList.iter
                |> std.iter.enumerate
        ) do (
            let scene :: Rc.t[Scene] = Load.scene(index);
            &mut scenes_by_name |> OrdMap.add(&json_scene^.name |> as_str, scene);
        );
        let scene = Load.scene(document.json.scene);
        {
            .document,
            .nodes_by_name,
            .scenes_by_name,
            .scene,
        }
    );

    const drop = (self :: Asset) => (
        Document.drop(self.document);
    );

    const find_node = (self :: &Asset, name :: &str) -> &Node => (
        let node = &self^.nodes_by_name |> OrdMap.get(&name) |> Option.unwrap;
        &node^^
    );
);
