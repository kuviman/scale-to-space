const blender = import "./bindings.ks";
use std.collections.OrdMap;

module:

let mut mesh_by_id = OrdMap.new[&str, blender.types.Mesh]();

let mut indent = 0;

let print_indent = () => (
    for i in 0..indent do (
        std.io.stdout.write("| ");
    );
);

let walk_mesh = (mesh :: &blender.types.Mesh) => (
    print_indent();
    let name = mesh^.id.name
        |> String.strip_prefix(.prefix = "ME")
        |> Option.unwrap;
    println!("\(name)");
    indent += 1;
    let attributes = mesh^.attribute_storage.dna_attributes |> Option.unwrap;
    for attribute in attributes |> ArrayList.iter do (
        let name = attribute^.name |> Option.unwrap;
        print_indent();
        println!("attribute \(name)");
    );
    indent -= 1;
);

let walk_object = (object :: &blender.types.Object) => (
    print_indent();
    let name = object^.id.name
        |> String.strip_prefix(.prefix = "OB")
        |> Option.unwrap;
    println!("\(name)");
    indent += 1;
    if object^.data is :Some data_id then (
        match &mesh_by_id |> OrdMap.get(&data_id^.name) with (
            | :Some mesh => (
                walk_mesh(mesh);
            )
            | :None => (
                print_indent();
                println!("<unknown> \(data_id^.name)");
            )
        );
    );
    indent -= 1;
);

let walk_collection = (collection :: &blender.types.Collection) => (
    print_indent();
    let name = collection^.id.name
        |> String.strip_prefix(.prefix = "GR")
        |> Option.unwrap;
    println!("\(name)");
    indent += 1;

    let mut iter = collection^.children.first;
    while iter is :Some iter_node do (
        let child = Option.unwrap(iter_node^.collection);
        walk_collection(child);
        iter = iter_node^.next;
    );
    
    let mut iter = collection^.gobject.first;
    while iter is :Some iter_node do (
        let object = Option.unwrap(iter_node^.ob);
        walk_object(object);
        iter = iter_node^.next;
    );

    indent -= 1;
);

let mut blend = blender.load("assets/source_assets.blend");
for mesh in &mut blend |> blender.find_all[blender.types.Mesh]() do (
    &mut mesh_by_id |> OrdMap.add(mesh.id.name, mesh);
);
let scene :: blender.types.Scene = &mut blend |> blender.find_singleton();
walk_collection(scene.master_collection |> Option.unwrap);
blender.drop(blend);

