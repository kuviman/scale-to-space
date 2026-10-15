default:
    echo "Hi"

build-c source="src/main.ks" output="target/compiled/main.c":
    mkdir -p $(dirname {{output}})
    echo "#define SDL_MAIN_HANDLED 1" > {{output}}
    ${KASTC:-kastc} compile \
        --target c \
        {{source}} \
        >> {{output}}
    # --c-debug true \

[arg("sanitize", long, value="true")]
[arg("opt_level", short="O")]
build-native source="target/compiled/main.c" opt_level="1" sanitize="":
    #!/usr/bin/env bash
    if [ -z "$KAST_PATH" ]; then
        KAST_ARGS="-lkast"
    else
        KAST_ARGS="-I${KAST_PATH}/c-runtime/include"
        KAST_ARGS="$KAST_ARGS ${KAST_PATH}/c-runtime/src/*.c"
    fi
    ${CC:-gcc} \
        blend-parser/blend.c \
        {{source}} \
        -o target/compiled/main.exe \
        $KAST_ARGS \
        -I. \
        -pthread \
        -lm -lSDL3 -lSDL3_image -lSDL3_mixer -lGL -lGLEW -lbacktrace \
        {{ if sanitize == "true" { "-fsanitize=address,leak,undefined" } else { "" } }} \
        -Wfatal-errors \
        -g -O{{opt_level}}
    # -fsanitize=memory \
    # -fno-omit-frame-pointer \

build-windows-do source:
    $CC \
        -lkernel32 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lversion -luuid -ladvapi32 -lsetupapi -lshell32 -lhid -lmincore \
        -lm -lSDL3 -lSDL3_image -lSDL3_mixer -lbacktrace -lpthread \
        -lglew32 -lglu32 -lopengl32 \
        -I${KAST_PATH}/c-runtime/include \
        ${KAST_PATH}/c-runtime/src/*.c \
        blend-parser/blend.c \
        {{source}} \
        -o target/compiled/main.exe \
        -I. \
        -lkernel32 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lversion -luuid -ladvapi32 -lsetupapi -lshell32 -lhid -lmincore \
        -lm -lSDL3 -lSDL3_image -lSDL3_mixer -lbacktrace -lpthread \
        -lglew32 -lglu32 -lopengl32 \
        -Wfatal-errors \
        -g -O3
    # -mwindows \

build-win:
    nix build '.?submodules=1#game-win'

run-win *args:
    just build-win && wine result/bin/ScaleToSpace.exe {{args}}

build-emscripten source="target/compiled/main.c":
    rm -rf target/web
    mkdir -p target/web
    CC=emcc kastc cc {{source}} \
        -I. \
        --shell-file shell.html \
        -o target/web/index.html \
        -I ${SDL3_WEB}/include \
        -L ${SDL3_WEB}/lib \
        -l SDL3 \
        -I ${SDL3_IMAGE_WEB}/include \
        -L ${SDL3_IMAGE_WEB}/lib \
        -l SDL3_image \
        -I ${SDL3_MIXER_WEB}/include \
        -L ${SDL3_MIXER_WEB}/lib \
        -l SDL3_mixer \
        -O0 \
        --use-preload-plugins \
        --preload-file assets \
        -s TOTAL_STACK=64MB \
        -s INITIAL_MEMORY=512MB \
        -s ALLOW_MEMORY_GROWTH \
        -s ASSERTIONS \
        -s WEBSOCKET_URL="wss://d2jam4.badcop.games" \
        -sMAX_WEBGL_VERSION=2 \
        -s BINARYEN_EXTRA_PASSES='--spill-pointers' \
        -w
    # -s ASYNCIFY \
    # -s ASYNCIFY_STACK_SIZE=64MB \
    # -sMAX_WEBGL_VERSION=2 \

build src="src/main.ks":
    just build-c {{src}}
    just build-native

run *args:
    ./target/compiled/main.exe --connect 15.204.212.176:5555 {{args}}
    # ./target/compiled/main.exe --server 127.0.0.1:1235 --connect 127.0.0.1:1235

run-and-profile:
    perf record -g ./target/compiled/main.exe --connect 15.204.212.176:5555

test-blend:
    (cd blend-parser && make)
    ./blend-parser/main.exe "assets/source_assets.blend" --generate-bindings blend-parser/generated.ks
    just build-c blend-parser/test.ks
    just build-native --sanitize
    ./target/compiled/main.exe
    # just build-tcc
    # just run-podman

build-tcc:
    CC=tcc just build-podman

build-podman:
    podman build -t notnix .
    podman run -it \
        -e CC=$CC \
        -v $HOME/projects/kast-lang/bootstrap:/kast:ro \
        -e KAST_PATH=/kast \
        -v $(pwd):/src -w /src \
        notnix \
        just build-native

run-podman *args:
    xhost +local:users
    podman run -it \
        --env DISPLAY=$DISPLAY \
        -e PULSE_SERVER=unix:/tmp/pulse/native \
        -e PULSE_COOKIE=/tmp/pulse/cookie \
        -v $XDG_RUNTIME_DIR/pulse/native:/tmp/pulse/native:ro \
        -v ~/.config/pulse/cookie:/tmp/pulse/cookie:ro \
        -e XDG_RUNTIME_DIR=/tmp/runtime \
        --volume /tmp/.X11-unix:/tmp/.X11-unix \
        --device /dev/dri \
        --device /dev/kfd \
        --group-add keep-groups \
        -v $XDG_RUNTIME_DIR/pipewire-0:/tmp/runtime/pipewire-0:ro \
        -v $(pwd):/src -w /src \
        notnix \
        ./target/compiled/main.exe {{args}}

server:
    LSAN_OPTIONS='suppresions=suppr.txt' \
        ./target/compiled/main.exe --server 127.0.0.1:1235

client:
    LSAN_OPTIONS='suppresions=suppr.txt' \
        ./target/compiled/main.exe --connect 127.0.0.1:1235

serve:
    just build-c
    just build-emscripten
    caddy run

publish-dev:
    butler push --dereference target/web kuviman/scale-to-space-dev:html5

publish-dev-win:
    butler push --dereference result/bin kuviman/scale-to-space-dev:windows
