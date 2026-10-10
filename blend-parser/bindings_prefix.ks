use std.collections.OrdMap;
const Array = [T :: Type, Size :: UInt32] std.collections.ArrayList.t[T];

module:

const Ptr = @opaque_type "void*";

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

const State = newtype {
    .blocks :: OrdMap.t[Ptr, Ptr],
};

const init = () -> State => {
    .blocks = OrdMap.new(),
};

const Ctx = @context State;

const Blend_Obj = @opaque_type "Blend_Obj";

impl Blend_Obj as module = (
    module:

    const field = (obj :: Blend_Obj, field_name :: &str) -> Blend_Obj => (
        @native ''
            Blend_Obj_get_field(
                \(obj),
                (Blend_String) {
                    .s = \(field_name).s,
                    .length = \(field_name).length,
                }
            )''
    );
);

const FromBlend = [Self] newtype {
    .from_blend :: Blend_Obj -> Self,
};

const ref_from_blend = [T] (obj :: Blend_Obj) -> &T => (
    let state = &(@current Ctx);
    let original_ptr :: Ptr = @native "(void*)\(obj).data";
    match &state^.blocks |> OrdMap.get(&original_ptr) with (
        | :None => panic_fmt!("ptr not present in blocks")
        | :Some new_ptr => (
            @native "(\(type T)*)\(new_ptr)"
        )
    )
);

const impl_FromBlend_for_ref = (T :: Type) -> std.Ast => `(
    impl type (&T) as FromBlend = {
        .from_blend = ref_from_blend[T],
    };
);
