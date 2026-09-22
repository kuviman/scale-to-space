use (import "../src/lib/_lib.ks").*;

module:

const init = (address :: String) => (
    @native "#include <net/client.h>";
    @native "badcop_init(String_to_C_String(\(address)))";
);

const PlayerData = newtype {
    .position :: Vec3,
    .velocity :: Vec3,
    .rotation :: Quat,
    .angular_velocity :: Vec3,
    .skin :: Int32,
    .jetpack :: Bool,
    .scale :: Float32,
    .distance_to_beachball :: Float32,
};

const set_name = (name :: String) => (
    @native "badcop_set_name(String_to_C_String(\(name)))";
);

const beat_game = (score :: Int32) => (
    @native "badcop_beat_game(\(score))";
);

const is_connected = () -> Bool => with_return (
    @native "badcop_is_connected()"
);

const emote = (index :: Int32) => (
    @native "badcop_emote(\(index))";
);

const send_beachball_update = (u :: PlayerData) => (
    @native ''
        badcop_send_beachball_update((ClientMsgUpdate) {
            .px = \(u.position.0),
            .py = \(u.position.1),
            .pz = \(u.position.2),
            .vx = \(u.velocity.0),
            .vy = \(u.velocity.1),
            .vz = \(u.velocity.2),
            .rx = \(u.rotation.i),
            .ry = \(u.rotation.j),
            .rz = \(u.rotation.k),
            .rw = \(u.rotation.w),
            .angular_vel = {
                .x = \(u.angular_velocity.0),
                .y = \(u.angular_velocity.1),
                .z = \(u.angular_velocity.2),
            },
            .skin = \(u.skin),
            .scale = \(u.scale),
            .jetpack = \(if u.jetpack then 1 else 0),
            .distance_to_beachball = \(u.distance_to_beachball),
        })
    '';
);

const send_beachball_scored = (who :: Int32) => (
    @native "badcop_send_beachball_scored(\(who))";
);

const send_update = (u :: PlayerData) => (
    @native ''
        badcop_send_update((ClientMsgUpdate) {
            .px = \(u.position.0),
            .py = \(u.position.1),
            .pz = \(u.position.2),
            .vx = \(u.velocity.0),
            .vy = \(u.velocity.1),
            .vz = \(u.velocity.2),
            .rx = \(u.rotation.i),
            .ry = \(u.rotation.j),
            .rz = \(u.rotation.k),
            .rw = \(u.rotation.w),
            .angular_vel = {
                .x = \(u.angular_velocity.0),
                .y = \(u.angular_velocity.1),
                .z = \(u.angular_velocity.2),
            },
            .skin = \(u.skin),
            .scale = \(u.scale),
            .jetpack = \(if u.jetpack then 1 else 0),
            .distance_to_beachball = \(u.distance_to_beachball),
        })
    '';
);

const Id = Int64;

const ServerMessage = newtype (
    | :Connected Id
    | :Disconnected Id
    | :BeachballScored {
        .who :: Int32,
    }
    | :UpdatePlayer {
        .id :: Id,
        .data :: PlayerData,
    }
    | :PlayerMeta {
        .id :: Id,
        .best_time :: Int32,
        .name :: String,
    }
    | :Emote {
        .id :: Id,
        .index :: Int32,
    }
    | :UpdateBeachball PlayerData
);

const poll_message = () -> Option.t[ServerMessage] => with_return (
    let msg :: @opaque_type "void*" = @native "badcop_poll_msg()";
    if @native "\(msg) == NULL" then (
        return :None;
    );
    let tag :: @opaque_type "ServerMsgTag" = @native "*((ServerMsgTag*)\(msg))";
    let data :: @opaque_type "void*" = @native "\(msg) + sizeof(ServerMsgTag)";
    if @native "\(tag) == ServerUpdatePlayer" then (
        let data :: @opaque_type "ServerMsgUpdatePlayer*" = @native "\(data)";
        return :Some :UpdatePlayer {
            .id = @native "\(data)->id",
            .data = {
                .position = {
                    @native "\(data)->stuff.px",
                    @native "\(data)->stuff.py",
                    @native "\(data)->stuff.pz",
                },
                .velocity = {
                    @native "\(data)->stuff.vx",
                    @native "\(data)->stuff.vy",
                    @native "\(data)->stuff.vz",
                },
                .rotation = {
                    .i = @native "\(data)->stuff.rx",
                    .j = @native "\(data)->stuff.ry",
                    .k = @native "\(data)->stuff.rz",
                    .w = @native "\(data)->stuff.rw",
                },
                .angular_velocity = {
                    @native "\(data)->stuff.angular_vel.x",
                    @native "\(data)->stuff.angular_vel.y",
                    @native "\(data)->stuff.angular_vel.z",
                },
                .skin = @native "\(data)->stuff.skin",
                .scale = @native "\(data)->stuff.scale",
                .jetpack = @native "\(data)->stuff.jetpack != 0",
                .distance_to_beachball = @native "\(data)->stuff.distance_to_beachball",
            },
        };
    );
    if @native "\(tag) == ServerUpdateBeachball" then (
        let data :: @opaque_type "ServerMsgUpdateBeachball*" = @native "\(data)";
        return :Some :UpdateBeachball {
            .position = {
                @native "\(data)->stuff.px",
                @native "\(data)->stuff.py",
                @native "\(data)->stuff.pz",
            },
            .velocity = {
                @native "\(data)->stuff.vx",
                @native "\(data)->stuff.vy",
                @native "\(data)->stuff.vz",
            },
            .rotation = {
                .i = @native "\(data)->stuff.rx",
                .j = @native "\(data)->stuff.ry",
                .k = @native "\(data)->stuff.rz",
                .w = @native "\(data)->stuff.rw",
            },
            .angular_velocity = {
                @native "\(data)->stuff.angular_vel.x",
                @native "\(data)->stuff.angular_vel.y",
                @native "\(data)->stuff.angular_vel.z",
            },
            .skin = @native "\(data)->stuff.skin",
            .scale = @native "\(data)->stuff.scale",
            .jetpack = @native "\(data)->stuff.jetpack != 0",
            .distance_to_beachball = @native "\(data)->stuff.distance_to_beachball",
        };
    );
    if @native "\(tag) == ServerConnected" then (
        let data :: @opaque_type "ServerMsgConnected*" = @native "\(data)";
        return :Some :Connected (@native "\(data)->id");
    );
    if @native "\(tag) == ServerDisconnected" then (
        let data :: @opaque_type "ServerMsgDisconnected*" = @native "\(data)";
        return :Some :Disconnected (@native "\(data)->id");
    );
    if @native "\(tag) == ServerBeachballScored" then (
        let data :: @opaque_type "int*" = @native "\(data)";
        return :Some :BeachballScored {
            .who = @native "*\(data)"
        };
    );
    if @native "\(tag) == ServerPlayerMeta" then (
        let data :: @opaque_type "ServerMsgPlayerMeta*" = @native "\(data)";
        return :Some :PlayerMeta {
            .id = @native "\(data)->id",
            .best_time = @native "\(data)->best_time",
            .name = @native "String_from_C_String(\(data)->name)",
        };
    );
    if @native "\(tag) == ServerEmote" then (
        let data :: @opaque_type "ServerMsgEmote*" = @native "\(data)";
        return :Some :Emote {
            .id = @native "\(data)->id",
            .index = @native "\(data)->index",
        };
    );
    @native ''printf("tag = %d\\n", \(tag))'';
    panic("Unrecognized tag in server message")
);
