use std.target.c;
const json = import "../src/json.ks";

const types = (
    module:

    const Index = Int32;
    const GLint = Int32;
    const GLenum = UInt32;

    const Node = newtype {
        .name :: String,
        .mesh :: Option.t[Index],
        .children :: Option.t[ArrayList.t[Index]],
        .translation :: Option.t[Array.t[Float32, 3]],
        .scale :: Option.t[Array.t[Float32, 3]],
        .rotation :: Option.t[Array.t[Float32, 4]],
        .matrix :: Option.t[Array.t[Float32, 16]],
    };

    const Mesh = newtype {
        .primitives :: ArrayList.t[MeshPrimitive],
        .name :: Option.t[String],
    };

    const MeshPrimitive = newtype {
        .attributes :: json.Map,
        .indices :: Option.t[Index],
        .material :: Option.t[Index],
        .mode :: Option.t[GLenum],
    };

    const Scene = newtype {
        .name :: String,
        .nodes :: Option.t[ArrayList.t[Index]],
    };

    const Buffer = newtype {
        .byteLength :: Int32,
        .uri :: Option.t[String],
    };

    const BufferView = newtype {
        .buffer :: Index,
        .byteLength :: Int32,
        .byteOffset :: Option.t[Int32],
        .byteStride :: Option.t[Int32],
        .target :: Option.t[GLenum],
        .name :: Option.t[String],
    };

    const Accessor = newtype {
        .bufferView :: Index,
        .byteOffset :: Option.t[Int32],
        .componentType :: GLenum,
        .normalized :: Option.t[Bool],
        .count :: Int32,
        .@"type" :: String,
        # .min :: Option.t[ArrayList.t[Float32]],
        # .max :: Option.t[ArrayList.t[Float32]],
        .name :: Option.t[String],
    };

    const TextureInfo = newtype {
        .index :: Index,
        .texCoord :: Option.t[Int32],
    };

    const Image = newtype {
        .uri :: Option.t[String],
        .mimeType :: Option.t[String],
        .bufferView :: Option.t[Index],
        .name :: Option.t[String],
    };

    const Texture = newtype {
        .sampler :: Option.t[Index],
        .source :: Option.t[Index],
        .name :: Option.t[String],
    };

    const Sampler = newtype {
        .magFilter :: Option.t[GLint],
        .minFilter :: Option.t[GLint],
        .wrapS :: Option.t[GLint],
        .wrapT :: Option.t[GLint],
        .name :: Option.t[String],
    };

    const PbrMetallicRoughness = newtype {
        .baseColorFactor :: Option.t[Array.t[Float32, 4]],
        .baseColorTexture :: Option.t[TextureInfo],
    };

    const Material = newtype {
        .name :: Option.t[String],
        .pbrMetallicRoughness :: Option.t[PbrMetallicRoughness],
        .emissiveFactor :: Option.t[Array.t[Float32, 3]],
        .alphaMode :: Option.t[String],
        .alphaCutoff :: Option.t[Float32],
        .doubleSided :: Option.t[Bool],
    };

    const Json = newtype {
        .scenes :: ArrayList.t[Scene],
        .nodes :: ArrayList.t[Node],
        .scene :: Index,
        .buffers :: ArrayList.t[Buffer],
        .bufferViews :: ArrayList.t[BufferView],
        .accessors :: ArrayList.t[Accessor],
        .meshes :: ArrayList.t[Mesh],
        .materials :: ArrayList.t[Material],
        .textures :: ArrayList.t[Texture],
        .images :: ArrayList.t[Image],
        .samplers :: ArrayList.t[Sampler],
    };

);

const Document = newtype {
    .raw_data :: ArrayList.t[Byte],
    .json :: types.Json,
    .bin_data :: Slice.t[Byte],
};

impl Document as module = (
    module:

    use types.*;

    const Header = newtype {
        .version :: UInt32,
        .length :: UInt32,
    };

    const read = (data :: &mut Slice.t[Byte], size :: UInt32) -> Slice.t[Byte] => (
        # TODO types
        let size :: Int32 = @native "\(size)";
        if size > data^.length then (
            panic("tried to read more bytes than there is");
        );
        let result = Slice.subslice(data^, 0, size);
        data^ = Slice.subslice(data^, size, data^.length - size);
        result
    );

    const read_uint32 = (data :: &mut Slice.t[Byte]) -> UInt32 => (
        let bytes = read(data, 4);
        @native "*(const uint32_t*)\(bytes).array"
    );

    const read_header = (data :: &mut Slice.t[Byte]) -> Header => (
        let magic = read_uint32(data);
        if magic != 0x46546C67 then (
            panic_fmt!("magic mismatch: \(magic)");
        );
        let version = read_uint32(data);
        let length = read_uint32(data);
        { .version, .length }
    );

    const Chunk = newtype {
        .typ :: UInt32,
        .data :: Slice.t[Byte],
    };

    const read_chunk = (data :: &mut Slice.t[Byte]) -> Chunk => (
        let length = read_uint32(data);
        let typ = read_uint32(data);
        let data = read(data, length);
        { .typ, .data }
    );

    const load = (path :: &str) -> Document => (
        let mut f = c.File.open(path, "rb");
        @defer c.File.close(f);
        let raw_data = &mut f |> c.File.read_to_end;
        let mut unread = &raw_data |> ArrayList.as_slice;
        let header = read_header(&mut unread);
        let json = (
            let chunk = read_chunk(&mut unread);
            if chunk.typ != 0x4E4F534A then (
                panic_fmt!("first chunk is not json but \(chunk.typ)");
            );
            # TODO check utf8
            let s :: &str = @native ''
                (StringView) {
                    .buf = \(chunk.data.array),
                    .length = \(chunk.data.length),
                }'';
            with json.ErrorHandler = panic[Never];
            include_ast json.parse_str(`(s), Json)
        );
        let bin_data = if unread.length == 0 then (
            Slice.subslice(unread, 0, 0)
        ) else (
            let chunk = read_chunk(&mut unread);
            if chunk.typ != 0x004E4942 then (
                panic_fmt!("second chunk is not bin but \(chunk.typ)");
            );
            chunk.data
        );
        {
            .raw_data,
            .json,
            .bin_data,
        }
    );

    const drop = (self :: Document) => (
    );
);

Document
