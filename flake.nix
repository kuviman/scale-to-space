{
  description = "A devShell example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    kast.url = "github:kast-lang/kast/bootstrap-ocaml";
    kast-selfhost.url = "git+https://github.com/kast-lang/kast?rev=9cbd998cdb9adf1e3b25cf9599f1e26743f80016&submodules=1";
    # kast.url = "git+file:/home/kuviman/projects/kast-lang/kast";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        nix-filter = inputs.nix-filter.lib;
        pkgs-25-11 = import inputs.nixpkgs-25-11 { inherit system; };
        pkgs = import inputs.nixpkgs { inherit system; };
        emscripten = pkgs-25-11.emscripten;
        kast = inputs.kast.packages.${system}.default;
        kast-selfhost = pkgs.writeShellApplication {
          name = "kast";
          runtimeInputs = [ pkgs.nodejs ];
          text = ''
            node ${inputs.kast-selfhost.packages.${system}.kast-js}/kast.mjs "$@"
          '';
        };
        clang = pkgs.clang_22;
        # clang = pkgs.clang;
        sdl3-web = with pkgs-25-11;
          stdenv.mkDerivation {
            name = "sdl3-web";
            src = fetchFromGitHub {
              owner = "libsdl-org";
              repo = "SDL";
              rev = "release-3.4.14";
              hash = "sha256-HzV5Fq+PhJr/dQBCVm2WL1BdaI4GG+W+B0scttjdRuQ=";
            };
            buildInputs = [
              emscripten
              cmake
            ];
            dontUseCmakeConfigure = true;
            buildPhase = ''
              emcmake cmake .
              emmake make
            '';
            installPhase = ''
              cmake --install . --prefix $out
            '';
          };
        sdl3-image-web = with pkgs-25-11;
          stdenv.mkDerivation {
            name = "sdl3-image-web";
            src = fetchFromGitHub {
              owner = "libsdl-org";
              repo = "SDL_image";
              rev = "release-3.4.4";
              hash = "sha256-ttnoe9bTtA8+eUMOs55v58xb+cWpNEiiTDEeX9GBxaw=";
            };
            buildInputs = [
              emscripten
              cmake
            ];
            dontUseCmakeConfigure = true;
            buildPhase = ''
              emcmake cmake . \
                -DSDL3_DIR=${sdl3-web}/lib/cmake/SDL3
              emmake make
            '';
            installPhase = ''
              cmake --install . --prefix $out
            '';
          };
        sdl3-mixer-web = with pkgs-25-11;
          stdenv.mkDerivation {
            name = "sdl3-mixer-web";
            src = fetchFromGitHub {
              owner = "libsdl-org";
              repo = "SDL_mixer";
              rev = "release-3.2.4";
              hash = "sha256-mPk6xU1/GkBtWgF8S9ttha7/PNxcBEiSxpzo6ARLC9I=";
            };
            buildInputs = [
              emscripten
              cmake
            ];
            dontUseCmakeConfigure = true;
            buildPhase = ''
              emcmake cmake . \
                -DSDL3_DIR=${sdl3-web}/lib/cmake/SDL3
              emmake make
            '';
            installPhase = ''
              cmake --install . --prefix $out
            '';
          };
        boehmgc-web = with pkgs-25-11;
          stdenv.mkDerivation {
            name = "boehmgc-web";
            src = fetchFromGitHub {
              owner = "bdwgc";
              repo = "bdwgc";
              rev = "331e007fffa19b6344982b7eb3f4ea8f973f68c7";
              hash = "sha256-dlcXJNDSMXlbeQqUd5deghJuS3dXrn3MQENpI8BE/ZE=";
            };
            buildInputs = [
              emscripten
              automake
              autoconf
              libtool
            ];
            buildPhase = ''
              ./autogen.sh
              export EM_CACHE="$(pwd)/.cache/emscripten"
              # LDFLAGS="-sBINARYEN_EXTRA_PASSES='--spill-pointers'"
              emconfigure ./configure
              emmake make
            '';
            installPhase = ''
              emmake make DESTDIR=$(pwd)/dest install
              cp -r dest/usr/local $out
            '';
          };
        sdl3-win = with pkgs.pkgsCross.mingwW64;
          sdl3.overrideAttrs
            (prev: {
              openglSupport = true;
              cmakeFlags = prev.cmakeFlags ++ [
                (lib.cmakeBool "WINDOWS" true)
                (lib.cmakeBool "SDL_OPENGL" true)
                (lib.cmakeBool "SDL_VIDEO" true)
                # (lib.cmakeBool "SDL_STATIC" true)
                # (lib.cmakeBool "SDL_SHARED" false)
              ];
            });
        game-c-source = with pkgs; stdenv.mkDerivation {
          name = "scale-to-space-c-source";
          src = nix-filter {
            root = ./.;
            include = [
              "deps"
              "src"
              "net"
              ".justfile"
            ];
          };
          nativeBuildInputs = [ kast just ];
          buildPhase = ''
            KASTC=kast just build-c
          '';
          installPhase = ''
            mkdir -p $out
            cp target/compiled/main.c $out/main.c
          '';
        };
        game-win = with pkgs.pkgsCross.mingwW64; stdenv.mkDerivation {
          name = "scale-to-space";
          src = nix-filter {
            root = ./.;
            include = [
              "net"
              ".justfile"
              "assets"
            ];
          };
          buildPhase = ''
            mkdir -p target/compiled
            just build-windows-do ${game-c-source}/main.c
          '';
          installPhase = ''
            set -e
            mkdir -p $out/bin
            cp target/compiled/main.exe $out/bin/
            cp -r assets
          '';
          nativeBuildInputs = [
            libGL
            gcc
            pkgs.just
          ];
          propagatedBuildInputs = [
            (glew.overrideAttrs {
              meta.platforms = [ "x86_64-windows" ];
              buildInputs = [ ];
              propagatedBuildInputs = [ ];
            })
            windows.pthreads
            libbacktrace
            sdl3-win
            (sdl3-image.overrideAttrs
              (prev: {
                cmakeFlags = [
                  # fail when a dependency could not be found
                  (lib.cmakeBool "SDLIMAGE_STRICT" true)
                  # disable shared dependencies as they're opened at runtime using SDL_LoadObject otherwise.
                  (lib.cmakeBool "SDLIMAGE_DEPS_SHARED" false)
                  # enable stb conditionally
                  (lib.cmakeBool "SDLIMAGE_BACKEND_STB" false)
                  # enable imageio backend
                  (lib.cmakeBool "SDLIMAGE_BACKEND_IMAGEIO" false)
                  # enable tests
                  (lib.cmakeBool "SDLIMAGE_TESTS" false)
                  # enable jxl
                  (lib.cmakeBool "SDLIMAGE_JXL" false)
                  (lib.cmakeBool "SDLIMAGE_JPG" false)
                  (lib.cmakeBool "SDLIMAGE_TIF" false)
                  (lib.cmakeBool "SDLIMAGE_WEBP" false)
                  # disable avif on darwin (see https://github.com/NixOS/nixpkgs/issues/400910)
                  (lib.cmakeBool "SDLIMAGE_AVIF" false)
                ];
                buildInputs = [ sdl3-win libpng ];
              }))
            (sdl3-mixer.overrideAttrs {
              meta.platforms = [ "x86_64-windows" ];
              buildInputs = [ sdl3-win libogg ];
              propagatedBuildInputs = [ ];
              postPatch = null;
              cmakeFlags = [
                # "-DBUILD_SHARED_LIBS=OFF"
                "-DSDLMIXER_OPUS=OFF"
              ];
            })
            boehmgc
          ];
        };
      in
      {
        packages = {
          inherit boehmgc-web;
          inherit sdl3-win;
          inherit game-c-source;
          inherit game-win;
        };
        devShells.default = with pkgs;
          mkShell
            {
              packages = [
                (pkgs.writeShellScriptBin "kastc" ''
                  systemd-run --user --scope -p MemoryMax=10G \
                    rlwrap ${kast}/bin/kast "$@"
                '')
                kast-selfhost
                rlwrap
                nixfmt
                nodejs
                just
                caddy
                inotify-tools
                sdl3
                sdl3-image
                sdl3-mixer
                boehmgc
                boehmgc-web
                libGL
                glew
                clang
                valgrind
                emscripten
                libbacktrace
                butler
                python314Packages.websockify
              ];
              # Since I dont have cmake or whatever
              CLANGD_FLAGS = "--query-driver=${clang}/bin/clang*";
              KAST_PATH = "./kast_path";
              BOEHMGC_WEB = "${boehmgc-web}";
              SDL3_WEB = "${sdl3-web}";
              SDL3_IMAGE_WEB = "${sdl3-image-web}";
              SDL3_MIXER_WEB = "${sdl3-mixer-web}";
              SERVER_ADDRESS = "d2jam4.badcop.games:5555";
            };
      });
}

