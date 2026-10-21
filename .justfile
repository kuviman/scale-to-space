default:
    echo "Hi"

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

build:
    geng transpile-to-c
    geng build-tcc

run *args:
    geng run-podman --connect 15.204.212.176:5555 {{args}}

run-and-profile:
    geng exec perf record -g ./target/compiled/main.exe --connect 15.204.212.176:5555

test-blend:
    (cd blend-parser && make)
    ./blend-parser/main.exe "assets/source_assets.blend" --generate-bindings blend-parser/generated.ks
    geng transpile-to-c blend-parser/test.ks
    geng compile-exe --sanitize
    ./target/compiled/main.exe
    # just build-tcc
    # just run-podman

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
