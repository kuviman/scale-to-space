{
  description = "A devShell example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-25-11.url = "github:NixOS/nixpkgs/nixos-25.11";
    # geng.url = "git+https://github.com/kast-lang/geng?submodules=1";
    geng.url = "git+file:///home/kuviman/projects/kast-lang/geng?submodules=1";
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs = inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        SERVER_ADDRESS = "15.204.212.176:5555";
        nix-filter = inputs.nix-filter.lib;
        pkgs-25-11 = import inputs.nixpkgs-25-11 { inherit system; };
        pkgs = import inputs.nixpkgs { inherit system; };
        emscripten = pkgs-25-11.emscripten;
        clang = pkgs.clang_22;
        sdl3-win = with pkgs.pkgsCross.mingwW64;
          sdl3.overrideAttrs
            (prev: {
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
            export SERVER_ADDRESS="${SERVER_ADDRESS}"
            KASTC=kast just build-c
          '';
          installPhase = ''
            mkdir -p $out
            cp target/compiled/main.c $out/main.c
          '';
        };
        windows-dep-attrs = with pkgs.pkgsCross.mingwW64; {
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
          ];
        };
        game-win = with pkgs.pkgsCross.mingwW64; stdenv.mkDerivation (windows-dep-attrs // {
          name = "scale-to-space";
          src = nix-filter {
            root = ./.;
            include = [
              "blend-parser"
              "net"
              ".justfile"
              "assets"
            ];
          };
          buildPhase = ''
            mkdir -p target/compiled
            KAST_PATH=${inputs.kast} just build-windows-do ${game-c-source}/main.c
          '';
          installPhase = ''
            set -e
            mkdir -p $out/bin
            cp target/compiled/main.exe $out/bin/ScaleToSpace.exe
            cp -r assets $out/bin/
          '';
        });
      in
      {
        packages = {
          inherit
            game-c-source
            game-win
            ;
        };
        devShells.default = with pkgs;
          mkShell
            {
              packages = [
                inputs.geng.packages.${system}.geng
                rlwrap
                nixfmt
                nodejs
                just
                caddy
                inotify-tools
                clang
                tinycc
                valgrind
                emscripten
                butler
                python314Packages.websockify
                xhost
              ];
              inherit SERVER_ADDRESS;
            };
      });
}

