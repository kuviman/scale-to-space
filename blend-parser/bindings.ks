use (import "../src/lib/c.ks").*;

use std.collections.OrdMap;
use std.collections.Treap;
const Array = [T :: Type, Size :: UInt32] std.collections.ArrayList.t[T];

module:

const DoubleLinkedList = [Node] newtype {
    .first :: Option.t[type (&Node)],
    .last :: Option.t[type (&Node)],
};

const BlockState = newtype {
    .block :: Block,
};

const RawBlend = @opaque_type "Blend*";

const Blend = newtype {
    .raw :: RawBlend,
    .blocks :: Treap.t[BlockState],
    # TODO dont leak
    .converted_ptrs :: OrdMap.t[Ptr, Ptr],
};
const Block = @opaque_type "Blend_Block*";

const load = (path :: &str) -> Blend => (
    @native "#include <blend-parser/blend.h>";
    let path = C_String.from_str(path);
    let raw = @native "Blend_load(\(path))";
    C_String.drop(path);
    let mut blocks = Treap.new();
    for block in iter_blocks(raw) do (
        let { left, right } = Treap.split(blocks, data => (
            if @native "\(data^.value.block)->old < \(block)->old" then (
                :LeftSubtree
            ) else (
                :RightSubtree
            )
        ));
        let block = {
            .block,
        };
        blocks = Treap.join(Treap.join(left, Treap.singleton(block)), right);
    );
    { .raw, .blocks, .converted_ptrs = OrdMap.new() }
);

const drop = (self :: Blend) => (
    for { .key = _, .value = ptr } in self.converted_ptrs |> OrdMap.into_iter do (
        @native "Kast_free(\(ptr))";
    );
    @native "Blend_drop(\(self.raw))";
);

const Ptr = @opaque_type "uint8_t*";

impl Ptr as std.cmp.Ord = {
    .compare = (&a, &b) => (
        if @native "\(a) < \(b)" then (
            :Less
        ) else if @native "\(a) > \(b)" then (
            :Greater
        ) else (
            :Equal
        )
    ),
};

const Ctx = @context type (&mut Blend);
const RawType = @opaque_type "Blend_Full_Type";

const Obj = @opaque_type "Blend_Obj";

impl Obj as module = (
    module:

    const field = (obj :: Obj, field_name :: &str) -> Obj => (
        @native ''
            Blend_Obj_get_field(
                \(obj),
                (Blend_String) {
                    .s = \(field_name).buf,
                    .length = \(field_name).length,
                }
            )''
    );
);

const BlendType = [Self :: Type] newtype {
    .name :: &str,
    .from_blend :: Obj -> Self,
};

const find_ptr_block = (ptr :: Ptr) -> Block => with_return (
    for block in iter_blocks((@current Ctx)^.raw) do (
        # @native ''printf("considering old=%p\\n", \(block)->old)'';
        if @native "\(block)->old == \(ptr)" then (
            # @native ''printf("FOUND IT!!!")'';
            return block;
        );
    );
    panic("block not found")
);

const find_ptr_block2 = (ptr :: Ptr) -> Block => (
    match Treap.lookup(&(@current Ctx)^.blocks, data => (
        if @native "\(ptr) < \(data^.value.block)->old" then (
            :LeftSubtree
        ) else if @native "\(ptr) >= \(data^.value.block)->old + \(data^.value.block)->body_length" then (
            :RightSubtree
        ) else (
            :Here
        )
    )) with (
        | :None => (
            panic_fmt!("ptr not present in blocks")
        )
        | :Some block => block^.block
    )
);

const Ptr_write = [T] (ptr :: Ptr, value :: T) => (
    @native "*(\(type T)*)\(ptr) = \(value)";
    # std.mem.forget(value);
);

const ref_from_blend = [T] (
    obj :: Obj,
    referenced_type :: RawType,
    construct_obj :: Obj -> T,
) -> Option.t[type (&T)] => with_return (
    let blend = @current Ctx;
    let original_ptr :: Ptr = @native "Blend_Obj_as_ptr(\(obj))";
    if original_ptr == (@native "NULL") then (
        return :None;
    );
    let block = find_ptr_block(original_ptr);
    let offset :: @opaque_type "ptrdiff_t" = @native "\(original_ptr) - \(block)->old";
    if @native "\(offset) < 0 || \(offset) >= \(block)->body_length" then (
        panic("offset out of block");
    );
    # @native ''printf("%p %p %zu %zd\\n", \(original_ptr), \(block)->old, \(block)->body_length, \(offset))'';
    let ptr_inside_blend_data :: Ptr = @native "\(block)->body + \(offset)";
    if OrdMap.get(&blend^.converted_ptrs, &ptr_inside_blend_data) is :None then (
        let ptr = @native "Kast_allocate(\(T))";
        OrdMap.add(&mut blend^.converted_ptrs, ptr_inside_blend_data, ptr);
        let obj :: Obj = @native ''
            (Blend_Obj){
                .data=\(ptr_inside_blend_data),
                .type=\(referenced_type),
            }'';
        Ptr_write(ptr, construct_obj(obj));
    );
    let (&ptr_to_T) = OrdMap.get(&blend^.converted_ptrs, &ptr_inside_blend_data) |> Option.unwrap;
    :Some (@native "(void*)\(ptr_to_T)")
);

const Array_from_blend = [T, N] (obj :: Obj, el_f :: Obj -> T) -> Array[T, N] => (
    let mut result = ArrayList.new();
    for i in 0..N do (
        let element_obj :: Obj = @native "Blend_Obj_index(\(obj), \(i))";
        let element = el_f(element_obj);
        &mut result |> ArrayList.push_back(element);
    );
    result
);

const iter_blocks = (blend :: RawBlend) -> std.iter.Iterable[Block] => {
    .iter = @move consumer => (
        let saved_context = &mut (@context);
        let consumer = @call "C" block => (
            let &@context = saved_context;
            consumer(block);
            true
        );
        @native ''Blend_find_all_blocks(\(blend), \(consumer).f, \(consumer).captured)'';
    ),
};

const find_singleton = [T] (blend :: &mut Blend) -> T => (
    with Ctx = blend;
    let mut single_block :: Option.t[Block] = :None;
    for block in iter_blocks(blend^.raw) do (
        if str_from_C_str(@native "\(block)->type->name") == (T as BlendType).name then (
            if single_block is :Some _ then (
                panic_fmt!("\((T as BlendType).name) is appearing multiple times in .blend");
            );
            single_block = :Some block;
        );
    );
    let block = single_block |> Option.unwrap_or_else(() => (
        panic_fmt!("\((T as BlendType).name) is not found in .blend")
    ));
    let obj :: Obj = @native "Blend_Block_as_obj(\(block))";
    (T as BlendType).from_blend(obj)
);

const types = (
    module:
    include "./generated.ks";
);

