const blender = import "./bindings.ks";

let mut blend = blender.load("assets/source_assets.blend");

let scene :: blender.types.Scene = &mut blend |> blender.find_singleton();

let mut iter = Option.unwrap(scene.master_collection)^.children.first;
while iter is :Some iter_node do (
    let child = Option.unwrap(iter_node^.collection);
    dbg.print(child^.id.name);
    iter = iter_node^.next;
);

blender.drop(blend);

