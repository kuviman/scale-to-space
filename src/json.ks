use std.Ast;

use (import "./__deps__.ks").*;
const json_lib = json;

module:

use json_lib.*;

# TODO hacks here
const Map = newtype {
    .actual_map :: OrdMap.t[String, Int32],
};

const parse_map = (map :: Ast) -> Ast => (
    let key = `(key);
    let value = `(value);
    `(
        let mut map :: Map = { .actual_map = OrdMap.new() };
        let values = match $map with (
            | :Object pairs => pairs
            | _ => error("expected map")
        );
        for { $key, $value } in values |> ArrayList.into_iter do (
            let value = $(parse_value(value, Int32));
            &mut map.actual_map |> OrdMap.add($key, value);
        );
        map
    )
);

const ErrorHandler = @context (type (&str -> Never));

const error = [T] (s :: &str) -> T => (
    (@current ErrorHandler)(s) |> from_never
);

const error_fmt = (args :: Ast) -> Ast => `(
    error(&format!($args) |> as_str)
);

const make_number_int32 = (x :: Int32) -> Number => (
    let neg = x < 0;
    let x = if neg then -x else x;
    {
        .neg,
        .digits = to_string(x),
        .fraction_digits = String.from_str(""),
        .exponent = { .neg = false, .digits = String.from_str("") },
    }
);
const make_number_float32 = (x :: Float32) -> Number => (
    let neg = x < 0;
    let x = abs(x);
    let s = to_string(x);
    let { digits, fraction_digits } = String.split_once(&s |> as_str, '.');
    {
        .neg,
        .digits = String.from_str(fraction_digits),
        .fraction_digits = String.from_str(fraction_digits),
        .exponent = { .neg = false, .digits = String.from_str("") },
    }
);

const construct_value = (value :: std.Ast, T :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => (
        let result = match std.reflection.type_info(T) with (
            | :Bool => `(
                :Bool $value
            )
            | :Float32 => `(
                :Number make_number_float32($value)
            )
            | :Int32 => `(
                :Number make_number_int32($value)
            )
            | :Tuple { .unnamed, .named } => (
                let fields = `(fields);
                let mut pairs = `(
                    let mut $fields = ArrayList.new[Pair]();
                );
                for { i, FieldT } in (
                    std.collections.SList.into_iter(unnamed)
                        |> std.iter.enumerate
                ) do (
                    let json_field = to_string(i);
                    let i = std.Ast.number_literal(i);
                    pairs = `(
                        $pairs;
                        let field = { json_field, $(construct_value(`($value.$i), FieldT)) };
                        &mut $fields |> ArrayList.push_back(field);
                    );
                );
                for { name, FieldT } in std.collections.SList.into_iter(named) do (
                    let name_ident = std.Ast.ident(name);
                    let json_field = name;
                    pairs = `(
                        $pairs;
                        let field = { json_field, $(construct_value(`($value.$name_ident), FieldT)) };
                        &mut $fields |> ArrayList.push_back(field);
                    );
                );
                `(
                    $pairs;
                    :Object $fields
                )
            )
            | :Variant { .variants } => (
                let mut handle_variants = `();
                let mut first_variant = true;
                let handle_variant = ast => (
                    if first_variant then (
                        first_variant = false;
                        handle_variants = ast;
                    ) else (
                        handle_variants = `(
                            $handle_variants
                            | $ast
                        );
                    )
                );
                for { .name, .data } in std.collections.SList.into_iter(variants) do (
                    let name_ident = std.Ast.ident(name);
                    let construct_variant = match data with (
                        | :None => handle_variant(
                            `(
                                :$name_ident => (
                                    let mut obj_field_pairs = ArrayList.new();
                                    &mut obj_field_pairs |> ArrayList.push_back({ "tag", :String name });
                                    :Object obj_field_pairs
                                )
                            )
                        )
                        | :Some DataType => (
                            let data_ident = `(data);
                            handle_variant(
                                `(
                                    :$name_ident $data_ident => (
                                        let mut obj_field_pairs = ArrayList.new();
                                        &mut obj_field_pairs |> ArrayList.push_back({ "tag", :String name });
                                        &mut obj_field_pairs
                                            |> ArrayList.push_back(
                                                { "data", $(construct_value(data_ident, DataType)) }
                                            );
                                        :Object obj_field_pairs
                                    )
                                )
                            )
                        )
                    );
                );
                `(
                    match $value with (
                        $handle_variants
                    )
                )
            )
        );
        `($result :: Value)
    )
    | true => panic("comptime only")
);

const find_field = (pairs :: &ArrayList.t[Pair], name :: &str) -> Value => with_return (
    for &{ ref key, ref value } in pairs |> ArrayList.iter do (
        if key |> as_str == name then (
            return value^;
        );
    );
    return :Null;
    # TODO
    for &{ ref key, ref value } in pairs |> ArrayList.iter do (
        println!("existing key: \(key |> as_str)");
    );
    error_fmt!("Expected field: \(name)")
);

const parse_option = (value :: std.Ast, T :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => `(
        match $value with (
            | :Null => :None
            | _ => :Some $(parse_value(value, T))
        ) :: Option.t[T]
    )
    | true => panic("comptime only")
);
const parse_value = (value :: std.Ast, T :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => (
        let result = match std.reflection.type_info(T) with (
            | :Bool => `(
                match $value with (
                    | :Bool b => b
                    | _ => error("Expected a bool")
                )
            )
            | :Float32 => `(
                match $value with (
                    | :Number n => &n
                        |> Number.to_f64
                        |> Float64_to_Float32
                    | _ => error("Expected a float32")
                )
            )
            | :Int32 => `(
                match $value with (
                    | :Number n => match &n |> Number.try_u32 with (
                        | :Ok n => n
                        | :Error s => error_fmt!("Expected int: \(s)")
                    )
                    | _ => error("Expected a int32")
                )
            )
            | :UInt32 => `(
                match $value with (
                    | :Number n => match &n |> Number.try_u32 with (
                        | :Ok n => Int32_to_UInt32(n)
                        | :Error s => error_fmt!("Expected int: \(s)")
                    )
                    | _ => error("Expected a uint32")
                )
            )
            | :String => `(
                match $value with (
                    | :String s => s
                    | _ => error("Expected a string")
                )
            )
            | :Tuple { .unnamed, .named } => with_return (
                (
                    for &{ ref name, _ } in std.collections.SList.iter(&named) do (
                        if name |> as_str == "actual_map" then (
                            return parse_map(value);
                        );
                    );
                );
                let field_pairs = `(field_pairs);
                let mut fields = `();
                let mut first_field = true;
                let add_field = field => (
                    if first_field then (
                        first_field = false;
                        fields = field;
                    ) else (
                        fields = `($fields, $field);
                    )
                );
                for { i, FieldT } in (
                    std.collections.SList.into_iter(unnamed)
                        |> std.iter.enumerate
                ) do (
                    let field_ident = `(field);
                    let field = `(
                        let $field_ident = find_field(&$field_pairs, to_string(i));
                        $(parse_value(field_ident, FieldT))
                    );
                    add_field(field);
                );
                for { name, FieldT } in std.collections.SList.into_iter(named) do (
                    let field_ident = `(field);
                    let field = `(
                        let $field_ident = find_field(&$field_pairs, &name |> as_str);
                        $(parse_value(field_ident, FieldT))
                    );
                    let name_ident = std.Ast.ident(name);
                    add_field(`(.$name_ident = $field));
                );
                `(
                    (
                        # TODO extra scope because $field_pairs is shadowing but same symbol
                        let $field_pairs = match $value with (
                            | :Object fields => fields
                            | _ => error("Expected an obj")
                        );
                        { $fields }
                    )
                )
            )
            | :Array { .element_ty, .length } => (
                let a = `(a);
                let mut elements = `();
                for i in 0..length do (
                    let element = parse_value(`($a.[i]), element_ty);
                    if i == 0 then (
                        elements = element;
                    ) else (
                        elements = `($elements, $element);
                    );
                );
                `(
                    let $a = match $value with (
                        | :Array a => a
                        | _ => error("Expected an array")
                    );
                    if &$a |> ArrayList.length != length then (
                        error("wrong array length");
                    );
                    @array {$elements}
                )
            )
            | :ArrayList element_ty => (
                let element = `(element);
                `(
                    let a = match $value with (
                        | :Array a => a
                        | _ => error("Expected an array")
                    );
                    let mut result = ArrayList.new();
                    for $element in a |> ArrayList.into_iter do (
                        let element = $(parse_value(element, element_ty));
                        &mut result |> ArrayList.push_back(element);
                    );
                    result
                )
            )
            | :Variant { .variants } => with_return (
                (
                    # Option
                    let mut none = false;
                    let mut some = :None;
                    for &{ .name = ref name, .data } in std.collections.SList.iter(&variants) do (
                        if name |> as_str == "None" then (
                            none = true;
                        );
                        if name |> as_str == "Some" then (
                            if data is :Some data then (
                                some = :Some data;
                            );
                        );
                    );
                    if none then (
                        if some is :Some T then (
                            return parse_option(value, T);
                        );
                    );
                );
                let mut variants = variants;
                let field_pairs = `(field_pairs);
                let tag = `(tag);
                let calculate_tag = `(
                    let $field_pairs = match $value with (
                        | :Object fields => fields
                        | _ => error("Expected an object")
                    );
                    let $tag = find_field(&$field_pairs, "tag");
                    let $tag = match $tag with (
                        | :String s => s
                        | _ => error("Tag must be string")
                    );
                );
                let mut handle_variants = `();
                while variants is :Cons { .value = { .name, .data }, .tail } do (
                    let name_ident = std.Ast.ident(name);
                    let construct_variant = match data with (
                        | :None => `(
                            :$name_ident
                        )
                        | :Some DataType => (
                            let data_ident = `(data);
                            `(
                                let $data_ident = find_field(&$field_pairs, "data");
                                :$name_ident $(parse_value(data_ident, DataType))
                            )
                        )
                    );
                    handle_variants = `(
                        $handle_variants;
                        if $tag == name then (
                            return $construct_variant;
                        );
                    );
                    variants = tail;
                );
                `(
                    $calculate_tag;
                    with_return (
                        $handle_variants;
                        error_fmt!("Unrecognized tag: \($tag)")
                    ) :: T
                )
            )
        );
        result
    )
    | true => panic("comptime only")
);

const parse_str = (s :: Ast, T :: Type) -> Ast => `(
    let value = parse(&mut Reader.create($s))
        |> Result.unwrap;
    include_ast parse_value(`(value), T)
);

const loader = (T :: Type) -> Ast => `(
    (path :: &str) -> T => (
        with ErrorHandler = (msg => panic(msg));
        let source = std.fs.read_file(path);
        include_ast parse_str(`(&source |> as_str), T)
    )
);
