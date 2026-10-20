use std.Ast;

use (import "./__deps__.ks").*;
const json_lib = json;

module:

use json_lib.*;

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
    error_fmt!("Expected field: \(name)")
);

const parse_value = (value :: std.Ast, T :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => (
        match std.reflection.type_info(T) with (
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
                    | _ => error("Expected a float32")
                )
            )
            | :Tuple { .unnamed, .named } => (
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
                    let $field_pairs = match $value with (
                        | :Object fields => fields
                        | _ => error("Expected an obj")
                    );
                    { $fields }
                )
            )
            | :Variant { .variants } => (
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
        )
    )
    | true => panic("comptime only")
);
