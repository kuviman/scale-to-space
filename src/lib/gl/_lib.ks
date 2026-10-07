use (import "../c.ks").*;

module:

include "./types.ks";
include "./constants.ks";

const ContextT = type ();
const Context = @context ContextT;

const get_error = () -> GLenum => (
    @native "glGetError()"
);

const clear = (bits :: GLbitfield) -> () => (
    @native "glClear(\(bits))";
);

const clear_color = (
    r :: GLclampf,
    g :: GLclampf,
    b :: GLclampf,
    a :: GLclampf,
) -> () => (
    @native "glClearColor(\(r), \(g), \(b), \(a))";
);

const Shader = @opaque_type "GLuint";

const get_error = () -> GLenum => (
    @native "glGetError()"
);

const throw_error = (fn_name :: &str) => (
    panic_fmt!("\(fn_name) failed: \(get_error())");
);

const create_shader = (shader_type :: GLenum) -> Shader => (
    let shader = @native "glCreateShader(\(shader_type))";
    if @native "\(shader) == 0" then (
        throw_error("glCreateShader");
    );
    shader
);

const shader_source = (
    shader :: Shader,
    source :: &str,
) -> () => (
    let length :: GLint = @native "\(source).length";
    @native "glShaderSource(\(shader), 1, &\(source).buf, &\(length))";
);

const compile_shader = (shader :: Shader) -> () => (
    @native "glCompileShader(\(shader))";
);

const get_shader_parameter_bool = (
    shader :: Shader,
    pname :: GLenum,
) -> GLboolean => (
    let mut result :: GLint = @native "0";
    @native "glGetShaderiv(\(shader), \(pname), \(&mut result))";
    @native "\(result) == GL_TRUE"
);

const get_shader_parameter_int = (
    shader :: Shader,
    pname :: GLenum,
) -> GLint => (
    let mut result :: GLint = @native "0";
    @native "glGetShaderiv(\(shader), \(pname), \(&mut result))";
    result
);

const get_shader_info_log = (shader :: Shader) -> String => (
    let buf_size = get_shader_parameter_int(shader, @native "GL_INFO_LOG_LENGTH");
    let buf :: @opaque_type "char*" = @native "Kast_allocate_array(&Byte_TypeInfo, \(buf_size))";
    let mut length :: GLsizei = 0;
    @native "glGetShaderInfoLog(\(shader), \(buf_size), \(&mut length), \(buf))";
    @native "String_from_raw_parts(\(buf), \(length))"
);

const Program = @opaque_type "GLuint";

const create_program = () -> Program => (
    let program = @native "glCreateProgram()";
    if @native "\(program) == 0" then (
        throw_error("glCreateProgram");
    );
    program
);

const attach_shader = (
    program :: Program,
    shader :: Shader,
) -> () => (
    @native "glAttachShader(\(program), \(shader))";
);

const link_program = (program :: Program) -> () => (
    @native "glLinkProgram(\(program))";
);

const get_program_parameter_bool = (
    program :: Program,
    pname :: GLenum,
) -> GLboolean => (
    let mut result :: GLint = 0;
    @native "glGetProgramiv(\(program), \(pname), \(&mut result))";
    @native "\(result) == GL_TRUE"
);

const get_program_parameter_int = (
    program :: Program,
    pname :: GLenum,
) -> GLint => (
    let mut result :: GLint = 0;
    @native "glGetProgramiv(\(program), \(pname), \(&mut result))";
    result
);

const get_program_info_log = (program :: Program) -> String => (
    let buf_size = get_program_parameter_int(program, @native "GL_INFO_LOG_LENGTH");
    let buf :: @opaque_type "char*" = @native "Kast_allocate_array(&Byte_TypeInfo, \(buf_size))";
    let mut length :: GLsizei = 0;
    @native "glGetProgramInfoLog(\(program), \(buf_size), \(&mut length), \(buf))";
    @native "String_from_raw_parts(\(buf), \(length))"
);

const use_program = (program :: Program) -> () => (
    @native "glUseProgram(\(program))";
);

const get_active_fn = type (
    fn @call "C" (
        Program,
        GLuint,
        GLsizei,
        &mut GLsizei,
        &mut GLint,
        &mut GLenum,
        @opaque_type "GLchar*",
    ) -> ()
);

const get_active_impl = (
    program :: std.Ast,
    index :: std.Ast,
    get_fn :: &str,
) -> std.Ast => @cfg (
    | target.name == "interpreter" => `(
        let name_buf_size :: GLsizei = 100; # TODO
        let name_buf :: @opaque_type "GLchar*" = @native "Kast_allocate_array(&Byte_TypeInfo, \(name_buf_size))";
        let mut name_length :: GLsizei = 0;
        let mut size :: GLint = 0;
        let mut @"type" :: GLenum = 0;
        @native ''\[](get_fn)(
            \($program),
            \($index),
            \(name_buf_size),
            \(&mut name_length),
            \(&mut size),
            \(&mut @"type"),
            \(name_buf)
        )'';
        let name :: String = @native ''
            String_from_raw_parts(\(name_buf), \(name_length))
        '';
        { .name, .size, .@"type" }
    )
    | true => panic("comptime only")
);

const get_active_attrib = (
    program :: Program,
    index :: GLuint,
) -> ActiveInfo => (
    include_ast get_active_impl(`(program), `(index), "glGetActiveAttrib")
);

const get_active_uniform = (
    program :: Program,
    index :: GLuint,
) -> ActiveInfo => (
    include_ast get_active_impl(`(program), `(index), "glGetActiveUniform")
);

const get_attrib_location = (
    program :: Program,
    name :: &str,
) -> Option.t[AttribLocation] => (
    let name = C_String_from_str(name);
    let location = @native "glGetAttribLocation(\(program), \(name))";
    C_String_drop(name);
    if @native "\(location) == -1" then (
        :None
    ) else (
        :Some location
    )
);

const get_uniform_location = (
    program :: Program,
    name :: &str,
) -> Option.t[UniformLocation] => (
    let name = C_String_from_str(name);
    let location = @native "glGetUniformLocation(\(program), \(name))";
    C_String_drop(name);
    if @native "\(location) == -1" then (
        :None
    ) else (
        :Some location
    )
);

const draw_arrays = (
    mode :: GLenum,
    first :: GLint,
    count :: GLsizei,
) -> () => (
    @native "glDrawArrays(\(mode), \(first), \(count))";
);

const viewport = (
    x :: GLint,
    y :: GLint,
    width :: GLsizei,
    height :: GLsizei,
) => (
    @native "glViewport(\(x), \(y), \(width), \(height))";
);

const enable = (cap :: GLenum) -> () => (
    @native "glEnable(\(cap))";
);

const blend_color = (
    red :: GLclampf,
    green :: GLclampf,
    blue :: GLclampf,
    alpha :: GLclampf,
) -> () => (
    @native "glBlendColor(\(red), \(green), \(blue), \(alpha))";
);

const blend_func = (src_factor :: GLenum, dst_factor :: GLenum) -> () => (
    @native "glBlendFunc(\(src_factor), \(dst_factor))";
);

const blend_func_separate = (
    src_rgb :: GLenum,
    dst_rgb :: GLenum,
    src_alpha :: GLenum,
    dst_alpha :: GLenum,
) -> () => (
    @native "glBlendFuncSeparate(\(src_rgb), \(dst_rgb), \(src_alpha), \(dst_alpha))";
);

const blend_equation = (mode :: GLenum) -> () => (
    @native "glBlendEquation(\(mode))"
);

const blend_equation_separate = (
    mode_rgb :: GLenum,
    mode_alpha :: GLenum,
) -> () => (
    @native "glBlendEquationSeparate(\(mode_rgb), \(mode_alpha))"
);
# blendEq(src * srcFactor, dst * dstFactor)

const create_buffer = () -> Buffer => (
    let mut buffer = @native "0";
    @native "glGenBuffers(1, \(&mut buffer))";
    buffer
);

const bind_buffer = (
    target :: GLenum,
    buffer :: Buffer,
) -> () => (
    @native "glBindBuffer(\(target), \(buffer))";
);

const buffer_data = (
    target :: GLenum,
    size :: GLsizeiptr,
    data :: const_void_star,
    usage :: GLenum,
) -> () => (
    @native "glBufferData(\(target), \(size), \(data), \(usage))";
);

const vertex_attrib_pointer = (
    index :: AttribLocation,
    size :: GLint,
    @"type" :: GLenum,
    normalized :: GLboolean,
    stride :: GLsizei,
    offset :: GLintptr,
) -> () => (
    @native ''glVertexAttribPointer(
            \(index),
            \(size),
            \(@"type"),
            \(normalized),
            \(stride),
            (const void*) (size_t) \(offset)
        )
    '';
);

const enable_vertex_attrib_array = (index :: AttribLocation) -> () => (
    @native "glEnableVertexAttribArray(\(index))";
);

const disable_vertex_attrib_array = (index :: AttribLocation) -> () => (
    @native "glDisableVertexAttribArray(\(index))";
);

const create_texture = () -> Texture => (
    let mut texture :: Texture = @native "0";
    @native "glGenTextures(1, \(&mut texture))";
    texture
);

const bind_texture = (
    target :: GLenum,
    texture :: Texture,
) => (
    @native "glBindTexture(\(target), \(texture))";
);

const tex_image_2d = (
    target :: GLenum,
    level :: GLint,
    internal_format :: GLenum,
    width :: GLsizei,
    height :: GLsizei,
    border :: GLint,
    format :: GLenum,
    @"type" :: GLenum,
    data :: const_void_star,
) => (
    @native ''glTexImage2D(
                \(target),
                \(level),
                \(internal_format),
                \(width),
                \(height),
                \(border),
                \(format),
                \(@"type"),
                \(data)
            )
        '';
);

const tex_parameter_i = (
    target :: GLenum,
    pname :: GLenum,
    param :: GLint,
) => (
    @native "glTexParameteri(\(target), \(pname), \(param))";
);

const tex_parameter_f = (
    target :: GLenum,
    pname :: GLenum,
    param :: GLfloat,
) => (
    @native "glTexParameterf(\(target), \(pname), \(param))";
);

const generate_mipmap = (target :: GLenum) -> () => (
    @native "glGenerateMipmap(\(target))";
);

const pixel_store_bool = (
    pname :: GLenum,
    value :: GLboolean,
) -> () => (
    @native "glPixelStorei(\(pname), \(value))";
);

const Buffer = @opaque_type "GLuint";

const ActiveInfo = newtype {
    .name :: String,
    .size :: GLsizei,
    .@"type" :: GLenum,
};
const AttribLocation = @opaque_type "GLint";
const UniformLocation = @opaque_type "GLint";
const Texture = @opaque_type "GLuint";
