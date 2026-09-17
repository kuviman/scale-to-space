default:
    echo "Hi"

build-c source="src/main.ks":
    ${KASTC:-kastc} compile \
        --target c \
        --output target/compiled/main.c \
        {{source}}

build-native source="target/compiled/main.c":
    ${CC:-gcc} \
        {{source}} \
        -o target/compiled/main.exe \
        -I. \
        -pthread \
        -lm -lgc -lSDL3 -lSDL3_image -lSDL3_mixer -lGL -lGLEW -lbacktrace \
        -Wfatal-errors \
        -g -O0 \
        -fsanitize=address,leak,undefined \
    # -fno-omit-frame-pointer \

build-windows-do source:
    $CC \
        -lkernel32 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lversion -luuid -ladvapi32 -lsetupapi -lshell32 -lhid -lmincore \
        -lm -lgc -lSDL3 -lSDL3_image -lSDL3_mixer -lbacktrace -lpthread \
        -lglew32 -lglu32 -lopengl32 \
        {{source}} \
        -o target/compiled/main.exe \
        -I. \
        -lkernel32 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -lversion -luuid -ladvapi32 -lsetupapi -lshell32 -lhid -lmincore \
        -lm -lgc -lSDL3 -lSDL3_image -lSDL3_mixer -lbacktrace -lpthread \
        -lglew32 -lglu32 -lopengl32 \
        -Wfatal-errors \
        -g -O0
    # -mwindows \

build-windows source="target/compiled/main.c":
    nix develop .#win --command just build-windows-do {{source}}

build-emscripten source="target/compiled/main.c":
    rm -rf target/web
    mkdir -p target/web
    emcc {{source}} \
        -I. \
        --shell-file shell.html \
        -o target/web/index.html \
        -I ${BOEHMGC_WEB}/include \
        -L ${BOEHMGC_WEB}/lib \
        -lgc \
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
        -s ASSERTIONS \
        -s ASYNCIFY \
        -s ASYNCIFY_STACK_SIZE=64MB \
        -s WEBSOCKET_URL="wss://d2jam4.badcop.games" \
        -w
    # -s BINARYEN_EXTRA_PASSES='--spill-pointers' \
    # -sMAX_WEBGL_VERSION=2 \

build src="src/main.ks":
    just build-c {{src}}
    just build-native

run:
    LSAN_OPTIONS='suppresions=suppr.txt' \
        ./target/compiled/main.exe --connect 15.204.212.176:5555
    # ./target/compiled/main.exe --server 127.0.0.1:1235 --connect 127.0.0.1:1235

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

publish:
    butler push target/web kuviman/scale-to-space:html5

