use std.target.c.*;

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
    .drop_fns :: ArrayList.t[type (() -> ())],
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
    {
        .raw,
        .blocks,
        .converted_ptrs = OrdMap.new(),
        .drop_fns = ArrayList.new(),
    }
);

const drop = (self :: Blend) => (
    for f in self.drop_fns |> ArrayList.into_iter do (
        f();
    );
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
);
const Ptr_read = [T] (ptr :: Ptr) -> T => (
    @native "*(\(type T)*)\(ptr)"
);

const relocate_ptr = (
    original_ptr :: Ptr,
    init :: (Block, Ptr) -> Ptr,
) -> Ptr => with_return (
    let blend = @current Ctx;
    if original_ptr == (@native "NULL") then (
        panic("relocate_ptr doesnt accept NULLs");
    );
    let block = find_ptr_block(original_ptr);
    let offset :: @opaque_type "ptrdiff_t" = @native "\(original_ptr) - \(block)->old";
    if @native "\(offset) < 0 || \(offset) >= \(block)->body_length" then (
        panic("offset out of block");
    );
    let ptr_inside_blend_data :: Ptr = @native "\(block)->body + \(offset)";
    if OrdMap.get(&blend^.converted_ptrs, &ptr_inside_blend_data) is :None then (
        let ptr = init(block, ptr_inside_blend_data);
        OrdMap.add(&mut blend^.converted_ptrs, ptr_inside_blend_data, ptr);
    );
    let (&ptr) = OrdMap.get(&blend^.converted_ptrs, &ptr_inside_blend_data)
        |> Option.unwrap;
    ptr
);

const str_from_blend = (obj :: Obj) -> Option.t[type (&str)] => with_return (
    let original_ptr :: Ptr = @native "Blend_Obj_as_ptr(\(obj))";
    if original_ptr == (@native "NULL") then (
        return :None;
    );
    let new_ptr = relocate_ptr(original_ptr, (block, ptr_inside_block) => (
        let length :: @opaque_type "size_t" = @native ''
            \(block)->body_length - (\(ptr_inside_block) - \(block)->body)'';
        @native ''
            printf("str_from_blend %p->%p: %s\\n",
                \(original_ptr),
                \(block)->old,
                \(ptr_inside_block))'';
        let ptr = @native "Kast_allocate_raw(\(length))";
        @native ''memcpy(\(ptr), \(ptr_inside_block), \(length))'';
        ptr
    ));
    :Some (@native "StringView_from_C_StringView(\(new_ptr))")
);

const ref_from_blend = [T] (
    obj :: Obj,
    referenced_type :: RawType,
    construct_obj :: Obj -> T,
) -> Option.t[type (&T)] => with_return (
    let original_ptr :: Ptr = @native "Blend_Obj_as_ptr(\(obj))";
    if original_ptr == (@native "NULL") then (
        return :None;
    );
    let mut do_init :: Option.t[Ptr] = :None;
    let new_ptr = relocate_ptr(original_ptr, (_, p) => (
        do_init = :Some p;
        @native "Kast_allocate(\(T))"
    ));
    if do_init is :Some ptr_inside_blend_data then (
        let obj :: Obj = @native ''
            (Blend_Obj){
                .data=\(ptr_inside_blend_data),
                .type=\(referenced_type),
            }'';
        Ptr_write(new_ptr, construct_obj(obj));
    );
    :Some (@native "(void*)\(new_ptr)")
);
const Array_ref_from_blend = [T] (
    obj :: Obj,
    len_obj :: Obj,
    referenced_type :: RawType,
    construct_element :: Obj -> T,
) -> Option.t[type (&ArrayList.t[T])] => with_return (
    let blend = @current Ctx;
    let original_ptr :: Ptr = @native "Blend_Obj_as_ptr(\(obj))";
    let len :: Int32 = @native "*(int*)\(len_obj).data";
    if original_ptr == (@native "NULL") then (
        if len != 0 then (
            panic("len != 0 on NULL ptr of array");
        );
        return :None;
    );
    let mut do_init :: Option.t[Ptr] = :None;
    let new_ptr = relocate_ptr(original_ptr, (_, ptr) => (
        do_init = :Some ptr;
        @native "Kast_allocate(\(ArrayList.t[T]))"
    ));
    if do_init is :Some ptr_inside_blend_data then (
        let mut list = ArrayList.new[T]();
        for i in 0..len do (
            let element_obj :: Obj = @native ''
                Blend_Obj_ptr_add((Blend_Obj){
                    .data=\(ptr_inside_blend_data),
                    .type=\(referenced_type),
                }, \(i))'';
            let element = construct_element(element_obj);
            &mut list |> ArrayList.push_back(element);
        );
        Ptr_write(new_ptr, list);
        let drop = @move () => (
            let list :: ArrayList.t[T] = Ptr_read(new_ptr);
        );
        &mut blend^.drop_fns |> ArrayList.push_back(drop);
    );
    :Some (@native "(void*)\(new_ptr)")
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
        @native ''
            Blend_find_all_blocks(
                \(blend),
                \(&consumer)->f,
                \(&consumer)->captured
            )'';
    ),
};

const find_all = [T] (blend :: &mut Blend) -> std.iter.Iterable[T] => {
    .iter = @move consumer => (
        with Ctx = blend;
        let mut single_block :: Option.t[Block] = :None;
        for block in iter_blocks(blend^.raw) do (
            if C_str.to_str(@native "\(block)->type->name") == (T as BlendType).name then (
                let obj :: Obj = @native "Blend_Block_as_obj(\(block))";
                consumer((T as BlendType).from_blend(obj));
            );
        );
    ),
};

const find_singleton = [T] (blend :: &mut Blend) -> T => (
    let mut single :: Option.t[T] = :None;
    for obj in find_all[T](blend) do (
        if single is :Some _ then (
            panic_fmt!("\((T as BlendType).name) is appearing multiple times in .blend");
        );
        single = :Some obj;
    );
    single |> Option.unwrap_or_else(() => (
        panic_fmt!("\((T as BlendType).name) is not found in .blend")
    ))
);

const types = (
    module:
    include "./generated.ks";
);

