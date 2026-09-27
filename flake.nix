# Declarative development environment for the Andiweli OpenMW Android port.
#
# Mirrors the flake used by the openmw-android-xyzz port: every host tool
# (Android SDK/NDK, JDK, cmake/ninja, ccache) comes from this flake instead
# of being downloaded by the build scripts. The one deliberate difference
# is the NDK: Andiweli's buildscripts pin r26b (26.1.10909125) and the
# source tree is tuned for it, so this flake supplies exactly that version
# through ANDROID_NDK_ROOT; buildscripts/build.sh consumes it directly
# instead of downloading its own toolchain copy.
#
# Usage (from this directory):
#   nix develop -c bash -c 'cd source/buildscripts && ./build.sh --arch arm64 --ccache'
#   nix develop -c bash -c 'cd source && ./gradlew assembleMainlineDebug'

{
  description = "OpenMW-Android (Andiweli) build environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          androidSdk = (pkgs.androidenv.composeAndroidPackages {
            includeNDK = true;
            # Andiweli's pinned NDK (include/version.sh: NDK_VERSION r26b);
            # app/build.gradle declares the same ndkVersion.
            ndkVersions = [ "26.1.10909125" ];
            # compileSdk 35 (mainline targets 29, automotive 35).
            buildToolsVersions = [ "34.0.0" "35.0.0" ];
            platformVersions = [ "34" "35" ];
            includeCmake = false;
          }).androidsdk;

          ndkVersion = "26.1.10909125";
        in
        {
          default = pkgs.mkShell {
            name = "openmw-android-andiweli-env";

            packages = with pkgs; [
              cmake
              ninja
              gnumake
              ccache
              pkg-config
              patchelf

              autoconf
              automake
              libtool
              perl
              python3
              gettext # envsubst, used by buildscripts/build.sh
              unzip
              p7zip
              zip
              which
              file

              # Host compiler for the host-ICU bootstrap (setup-icu.sh
              # invokes gcc/g++ directly).
              gcc

              git
              curl
              wget # setup-icu.sh fetches the host-ICU source with wget

              openjdk17
            ];

            shellHook = ''
              export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
              export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/${ndkVersion}"
              export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"
              unset ANDROID_HOME || true
              # nix's pkg-config hook exports PKG_CONFIG_PATH covering the
              # whole shell closure (curl pulls in brotli, etc.). Cross
              # configure scripts then "find" host libraries, freetype links
              # brotli, and the openmw link fails on undefined symbols. The
              # builds must only ever see the android prefix
              # (PKG_CONFIG_LIBDIR, set by command_wrapper.sh).
              unset PKG_CONFIG_PATH || true
              # llvm-strip and friends are invoked without a prefix by
              # build.sh once the compatibility wrappers run out.
              export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"

              echo "[openmw-android-andiweli-env] NDK: $ANDROID_NDK_ROOT"
              test -d "$ANDROID_NDK_ROOT" || echo "WARNING: NDK missing at $ANDROID_NDK_ROOT"
            '';
          };
        });
    };
}
