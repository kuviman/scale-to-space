module:

const join_path = (a :: &str, b :: &str) -> String => (
    format!("\(a)/\(b)")
);

const Load = [Self] newtype {
    .load :: &str -> Self,
    .default_ext :: Option.t[&str],
};

const derive_Load = (ty :: Type) -> std.Ast => @cfg (
    | target.name == "interpreter" => match std.reflection.type_info(ty) with (
        | :Tuple { .unnamed, .named } => (
            match unnamed with (
                | :Nil => ()
                | :Cons _ => panic("Expected zero unnamed fields")
            );
            let path = `(path);
            let load_fields = std.collections.SList.iter[type { String, Type }](&named)
                |> std.iter.map(
                    &{ name, field_ty } => (
                        let name_ident = std.Ast.ident(name);
                        `(
                            .$name_ident = (
                                let mut field_filename = name;
                                if (field_ty as Load).default_ext is :Some ext then (
                                    field_filename = field_filename + "." + ext;
                                );
                                let field_path = join_path($path, field_filename);
                                (field_ty as Load).load(field_path)
                            )
                        )
                    )
                )
                |> std.iter.reduce((a, b) => `($a, $b))
                |> Option.unwrap_or(`());
            `(
                impl ty as Load = {
                    .load = $path => {
                        $load_fields
                    },
                    .default_ext = :None,
                };
            )
        )
        | _ => panic("Can't derive Load")
    )
    | true => panic("Only usable at comptime")
);

