use (import "../common.ks").*;
use (import "../la/_lib.ks").*;
const gl = import "../gl/_lib.ks";
const SDL = import "../sdl3/_lib.ks";

use std.collections.OrdMap;

module:

const init = () => (
    @native "#include <GL/glew.h>";
    let err :: gl.GLenum = @native "glewInit()";
    if @native "\(err) != GLEW_OK" then (
        let error :: String = @native "String_from_C_String(glewGetErrorString(\(err)))";
        panic("glewInit failed: " + error);
    );
    gl.enable(gl.DEPTH_TEST);
    @native "glPixelStorei(GL_UNPACK_ALIGNMENT, 1)";

    @native ''
        {
            GLuint vao;
            glGenVertexArrays(1, &vao);
            glBindVertexArray(vao);
        }
    '';

    check_error();
);

const check_error = () => with_return (
    # TODO
    if is_emscripten() then return;
    let error = gl.get_error();
    let error_string = if error == (@native "GL_NO_ERROR") then (
        return
    ) else if error == (@native "GL_INVALID_ENUM") then (
        "GL_INVALID_ENUM"
    ) else if error == (@native "GL_INVALID_VALUE") then (
        "GL_INVALID_VALUE"
    ) else if error == (@native "GL_INVALID_OPERATION") then (
        "GL_INVALID_OPERATION"
    ) else if error == (@native "GL_INVALID_FRAMEBUFFER_OPERATION") then (
        "GL_INVALID_FRAMEBUFFER_OPERATION"
    ) else if error == (@native "GL_OUT_OF_MEMORY") then (
        "GL_OUT_OF_MEMORY"
    ) else if error == (@native "GL_STACK_UNDERFLOW") then (
        "GL_STACK_UNDERFLOW"
    ) else if error == (@native "GL_STACK_OVERFLOW") then (
        "GL_STACK_OVERFLOW"
    ) else (
        "Unrecognized GL error"
    );
    panic("OpenGL error: " + error_string);
);

const clear = (color :: Vec4) => (
    gl.clear_color(...color);
    gl.clear(@native "GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT");
);

const SizedType = [Self :: Type] newtype {
    .size :: Int32,
};

impl Float32 as SizedType = {
    .size = 4,
};

const compile_shader = (shader_type, source) => (
    let source_prefix = if is_emscripten() then ''
        precision highp float;
    '' else ''
        #version 130
    '';
    let source = source_prefix + "\n" + source;
    let shader = gl.create_shader(shader_type);
    gl.shader_source(shader, source);
    gl.compile_shader(shader);
    let compile_status = gl.get_shader_parameter_bool(
        shader, gl.COMPILE_STATUS
    );
    if not compile_status then (
        let log = gl.get_shader_info_log(shader);
        panic("Shader compilation failed: " + log);
    );
    shader
);

const AttributeInfo = newtype {
    .raw :: gl.ActiveInfo,
    .location :: gl.AttribLocation,
    .index :: UInt32,
};

const ExistingUniformInfo = newtype {
    .raw :: gl.ActiveInfo,
    .location :: gl.UniformLocation,
    .index :: UInt32,
};

const UniformInfo = Option.t[ExistingUniformInfo];

const calculate_uniforms = (program :: std.Ast, T :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => (
        match std.reflection.type_info(T) with (
            | :Tuple { .unnamed, .named } => (
                use std.collections.SList;
                for _ in SList.into_iter(unnamed) do (
                    panic("No unnamed fields for uniforms, thank you");
                );
                let mut fields = `();
                for { name, field_T } in SList.into_iter(named) do (
                    let name_ident = std.Ast.ident(name);
                    fields = `(
                        $fields,
                        .$name_ident = &$program.uniforms
                            |> OrdMap.get(name)
                            |> Option.map(&info => info)
                    )
                );
                `({ $fields })
            )
        )
    )
    | true => panic("comptime only")
);

const Program = newtype {
    .ctx :: gl.ContextT,
    .handle :: gl.Program,
    .attributes :: OrdMap.t[String, AttributeInfo],
    .uniforms :: OrdMap.t[String, ExistingUniformInfo],
};

impl Program as module = (
    module:

    const init = (
        .vertex_glsl :: String,
        .fragment_glsl :: String,
    ) -> Program => (
        let vertex_shader = compile_shader(gl.VERTEX_SHADER, vertex_glsl);
        let fragment_shader = compile_shader(gl.FRAGMENT_SHADER, fragment_glsl);
        init_impl(vertex_shader, fragment_shader)
    );

    const init_impl = (
        vertex_shader :: gl.Shader,
        fragment_shader :: gl.Shader,
    ) -> Program => (
        let ctx = (@current gl.Context);
        let program = gl.create_program();
        gl.attach_shader(program, vertex_shader);
        gl.attach_shader(program, fragment_shader);
        gl.link_program(program);
        let link_status = gl.get_program_parameter_bool(program, gl.LINK_STATUS);
        if not link_status then (
            let log = gl.get_program_info_log(program);
            panic("Program link failed: " + log);
        );
        let active_attributes = gl.get_program_parameter_int(program, gl.ACTIVE_ATTRIBUTES)
            |> Int32_to_UInt32;
        let mut attributes = OrdMap.new();
        for index in 0..active_attributes do (
            let active_info = gl.get_active_attrib(program, index);
            if active_info.size != 1 then (
                dbg.print(active_info);
                panic("active_info.size != 1");
            );
            let location = gl.get_attrib_location(program, active_info.name)
                |> Option.unwrap;
            let attribute_info = {
                .raw = active_info,
                .location,
                .index,
            };
            OrdMap.add(&mut attributes, attribute_info.raw.name, attribute_info);
        );
        let active_uniforms = gl.get_program_parameter_int(program, gl.ACTIVE_UNIFORMS)
            |> Int32_to_UInt32;
        let mut uniforms = OrdMap.new();
        for index in 0..active_uniforms do (
            let active_info = gl.get_active_uniform(program, index);
            if active_info.size != 1 then (
                dbg.print(active_info);
                panic("active_info.size != 1");
            );
            let location = gl.get_uniform_location(program, active_info.name)
                |> Option.unwrap;
            let uniform_info = {
                .raw = active_info,
                .location,
                .index,
            };
            OrdMap.add(&mut uniforms, uniform_info.raw.name, uniform_info);
        );
        {
            .ctx,
            .handle = program,
            .attributes,
            .uniforms,
        }
    );

    const @"use" = (program :: Program) => (
        gl.use_program(program.handle);
    );
);

const Texture = newtype {
    .size :: Vec2,
    .handle :: gl.Texture,
};

const Filter = newtype (
    | :Nearest
    | :Linear
);

const Wrap = newtype (
    | :Repeat
    | :ClampToEdge
);

impl Wrap as module = (
    module:

    const to_gl = (wrap :: Wrap) -> gl.GLenum => (
        match wrap with (
            | :Repeat => gl.REPEAT
            | :ClampToEdge => gl.CLAMP_TO_EDGE
        )
    );
);

impl Texture as module = (
    module:

    const init = (
        image :: SDL.Surface,
        filter :: Filter,
    ) -> Texture => (
        let handle = gl.create_texture();
        gl.bind_texture(gl.TEXTURE_2D, handle);
        if is_emscripten() then (
            gl.pixel_store_bool(gl.UNPACK_FLIP_Y_WEBGL, true);
            gl.pixel_store_bool(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
        );
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_MIN_FILTER,
            UInt32_to_Int32(gl.LINEAR),
        );
        match filter with (
            | :Linear => ()
            | :Nearest => (
                gl.tex_parameter_i(
                    gl.TEXTURE_2D,
                    gl.TEXTURE_MAG_FILTER,
                    UInt32_to_Int32(gl.NEAREST),
                );
            )
        );
        let width = @native "\(image)->w";
        let height = @native "\(image)->h";
        gl.tex_image_2d(
            gl.TEXTURE_2D,
            0,
            gl.RGBA,
            width,
            height,
            0,
            gl.RGBA,
            gl.UNSIGNED_BYTE,
            @native "\(image)->pixels",
        );
        # gl.generate_mipmap(gl.TEXTURE_2D);
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_S,
            UInt32_to_Int32(gl.CLAMP_TO_EDGE),
        );
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_T,
            UInt32_to_Int32(gl.CLAMP_TO_EDGE),
        );
        {
            .size = {
                Int32_to_Float32(width),
                Int32_to_Float32(height),
            },
            .handle,
        }
    );

    const load = (
        path :: String,
        filter :: Filter,
    ) -> Texture => (
        let surface = SDL.IMG.Load(path);
        let rgba_surface = SDL.ConvertSurface(
            surface,
            @native "SDL_PIXELFORMAT_RGBA32",
        );
        SDL.DestroySurface(surface);
        if not is_emscripten() then (
            SDL.FlipSurface(rgba_surface, @native "SDL_FLIP_VERTICAL");
        );
        let texture = Texture.init(rgba_surface, filter);
        SDL.DestroySurface(rgba_surface);
        texture
    );

    const set_wrap_separate = (
        texture :: &mut Texture,
        s :: Wrap,
        t :: Wrap,
    ) -> () => (
        gl.bind_texture(gl.TEXTURE_2D, texture^.handle);
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_S,
            UInt32_to_Int32(s |> Wrap.to_gl),
        );
        gl.tex_parameter_i(
            gl.TEXTURE_2D,
            gl.TEXTURE_WRAP_T,
            UInt32_to_Int32(t |> Wrap.to_gl),
        );
    );

    const set_wrap = (texture :: &mut Texture, wrap :: Wrap) => (
        set_wrap_separate(texture, wrap, wrap);
    );
);

const DrawState = newtype {
    .active_texture_index :: UInt32,
};

impl DrawState as module = (
    module:

    const init = () -> DrawState => (
        let ctx = (@current gl.Context);

        gl.enable(gl.BLEND);
        gl.blend_func_separate(
            gl.SRC_ALPHA,
            gl.ONE_MINUS_SRC_ALPHA,
            gl.ONE_MINUS_DST_ALPHA,
            gl.ONE,
        );

        { .active_texture_index = 0 }
    );
);

const Uniform = [Self] newtype {
    .set :: (gl.UniformLocation, Self, &mut DrawState) -> (),
};

impl Float32 as Uniform = {
    .set = (location, x, state) => (
        let ctx = (@current gl.Context);
        @native "glUniform1f(\(location), \(x))";
    ),
};

impl Vec2 as Uniform = {
    .set = (location, value, state) => (
        let ctx = (@current gl.Context);
        let { x, y } = value;
        @native "glUniform2f(\(location), \(x), \(y))";
    ),
};

impl Vec3 as Uniform = {
    .set = (location, value, state) => (
        let ctx = (@current gl.Context);
        let { x, y, z } = value;
        @native "glUniform3f(\(location), \(x), \(y), \(z))";
    ),
};

impl Vec4 as Uniform = {
    .set = (location, value, state) => (
        let ctx = (@current gl.Context);
        let { x, y, z, w } = value;
        @native "glUniform4f(\(location), \(x), \(y), \(z), \(w))";
    ),
};

impl Mat3 as Uniform = {
    .set = (location, value, state) => (
        let ctx = (@current gl.Context);
        let mut list = ArrayList.new();
        let { a, b, c } = value;
        let add = (f) => (
            &mut list |> ArrayList.push_back(f(a));
            &mut list |> ArrayList.push_back(f(b));
            &mut list |> ArrayList.push_back(f(c));
        );
        add(row => row.0);
        add(row => row.1);
        add(row => row.2);
        @native "glUniformMatrix3fv(\(location), 1, \(false), \(list).buf)";
    ),
};

impl Mat4 as Uniform = {
    .set = (location, value, state) => (
        let ctx = (@current gl.Context);
        let mut list = ArrayList.new();
        let add = (f) => (
            &mut list |> ArrayList.push_back(f(value.0));
            &mut list |> ArrayList.push_back(f(value.1));
            &mut list |> ArrayList.push_back(f(value.2));
            &mut list |> ArrayList.push_back(f(value.3));
        );
        add(row => row.0);
        add(row => row.1);
        add(row => row.2);
        add(row => row.3);
        @native "glUniformMatrix4fv(\(location), 1, \(false), \(list).buf)";
    ),
};

impl Texture as Uniform = {
    .set = (location, texture, state) => (
        let ctx = (@current gl.Context);
        @native "glActiveTexture(\(gl.TEXTURE0 + state^.active_texture_index))";
        gl.bind_texture(gl.TEXTURE_2D, texture.handle);
        @native "glUniform1i(\(location), \(state^.active_texture_index))";
        state^.active_texture_index += 1;
    ),
};

const set_uniform = [T] (
    program :: Program,
    name :: String,
    value :: T,
    state :: &mut DrawState,
) -> () => with_return (
    let ctx = program.ctx;
    let uniform_info = match &program.uniforms |> OrdMap.get(name) with (
        | :Some (info) => info
        | :None => return
    );
    (T as Uniform).set(uniform_info^.location, value, state);
);

const set_uniform_eff = [T] (
    program :: Program,
    info :: UniformInfo,
    value :: T,
    state :: &mut DrawState,
) -> () => with_return (
    let info = info |> Option.unwrap_or_else(() => return);
    let ctx = program.ctx;
    (T as Uniform).set(info.location, value, state);
);

const Vertex = [Self] newtype {
    .init_fields :: (&ArrayList.t[Self], (String, VertexBuffer.Field) -> ()) -> (),
};

const Vertex_derive = (ty :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => match std.reflection.type_info(ty) with (
        | :Tuple { .unnamed, .named } => (
            match unnamed with (
                | :Nil => ()
                | :Cons _ => panic("Expected zero unnamed fields")
            );
            const f = `(f);
            const data = `(data);
            let mut init_fields = `();
            for &{ name, field_ty } in std.collections.SList.iter(&named) do (
                let name_ident = std.Ast.ident(name);
                init_fields = `(
                    $init_fields;
                    $f(name, VertexBuffer.init_field($data, v => v^.$name_ident));
                );
            );
            `(
                @eval (
                    impl ty as Vertex = {
                        .init_fields = ($data, $f) => (
                            $init_fields
                        ),
                    }
                );
            )
        )
        | _ => panic("Can't derive vertex")
    )
    | true => panic("Only usable at comptime")
);

const VertexBuffer = (
    module:

    const Field = newtype {
        .buffer :: gl.Buffer,
        .stride :: Int32,
        .offset :: Int32,
        .@"type" :: VertexAttributeType,
    };

    const t = [V] newtype {
        .fields :: OrdMap.t[String, Field],
        .length :: Int32,
    };

    const init = [V] (data :: &ArrayList.t[V]) -> t[V] => (
        let mut fields = OrdMap.new();
        (V as Vertex).init_fields(
            data,
            (name, field) => (
                OrdMap.add(&mut fields, name, field);
            )
        );
        let length = data |> ArrayList.length;
        { .fields, .length }
    );

    const init_field = [V, T] (
        data :: &ArrayList.t[V],
        get :: &V -> T,
    ) -> Field => (
        let mut field_data = ArrayList.new();
        for vertex in ArrayList.iter(data) do (
            let field = get(vertex);
            &mut field_data |> ArrayList.push_back(field);
        );
        let field_data = (T as VertexAttribute).construct_data(&field_data);

        let buffer = gl.create_buffer();
        gl.bind_buffer(gl.ARRAY_BUFFER, buffer);
        gl.buffer_data(
            gl.ARRAY_BUFFER,
            field_data.size,
            field_data.buf,
            gl.STATIC_DRAW,
        );

        let offset = 0;
        let @"type" = (T as VertexAttribute).@"type";
        let stride = @"type".size * @"type".type_size;
        {
            .buffer,
            .stride,
            .offset,
            .@"type",
        }
    );
);

const set_vertex_data_source = [V] (
    program :: Program,
    buffer :: VertexBuffer.t[V],
) -> () => (
    let ctx = program.ctx;
    for &{ .key = name, .value = field } in &buffer.fields |> OrdMap.iter do (
        let attribute_info = match &program.attributes |> OrdMap.get(name) with (
            | :Some (info) => info
            | :None => continue
        );
        gl.bind_buffer(gl.ARRAY_BUFFER, field.buffer);
        gl.vertex_attrib_pointer(
            attribute_info^.location,
            field.@"type".size,
            field.@"type".@"type",
            false,
            field.stride,
            field.offset,
        );
        gl.enable_vertex_attrib_array(attribute_info^.location);
    );
);

const VertexAttributeType = newtype {
    .size :: gl.GLint,
    .@"type" :: gl.GLenum,
    .type_size :: Int32,
};

const RawData = newtype {
    .size :: Int32,
    .buf :: gl.const_void_star,
};

impl RawData as module = (
    module:

    const new = [T] (data :: &ArrayList.t[T]) -> RawData => {
        .size = (data |> ArrayList.length) * (@native "sizeof(\(type T))"),
        .buf = @native "\(data)->buf",
    };
);

const VertexAttribute = [Self] newtype {
    .@"type" :: VertexAttributeType,
    .construct_data :: &ArrayList.t[Self] -> RawData,
};

impl Vec2 as VertexAttribute = {
    .@"type" = {
        .size = 2,
        .@"type" = gl.FLOAT,
        .type_size = 4,
    },
    .construct_data = data => (
        let mut list = ArrayList.new();
        for &{ x, y } in ArrayList.iter(data) do (
            &mut list |> ArrayList.push_back(x);
            &mut list |> ArrayList.push_back(y);
        );
        RawData.new(&list)
    ),
};

impl Vec3 as VertexAttribute = {
    .@"type" = {
        .size = 3,
        .@"type" = gl.FLOAT,
        .type_size = 4,
    },
    .construct_data = data => (
        let mut list = ArrayList.new();
        for &{ x, y, z } in ArrayList.iter(data) do (
            &mut list |> ArrayList.push_back(x);
            &mut list |> ArrayList.push_back(y);
            &mut list |> ArrayList.push_back(z);
        );
        RawData.new(&list)
    ),
};

impl Vec4 as VertexAttribute = {
    .@"type" = {
        .size = 4,
        .@"type" = gl.FLOAT,
        .type_size = 4,
    },
    .construct_data = data => (
        let mut list = ArrayList.new();
        for &{ x, y, z, w } in ArrayList.iter(data) do (
            &mut list |> ArrayList.push_back(x);
            &mut list |> ArrayList.push_back(y);
            &mut list |> ArrayList.push_back(z);
            &mut list |> ArrayList.push_back(w);
        );
        RawData.new(&list)
    ),
};
