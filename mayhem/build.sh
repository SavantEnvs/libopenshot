#!/usr/bin/env bash
#
# mayhem/build.sh — build libopenshot (sanitized) + its fuzz harnesses + the Catch2 test binaries.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
: "${STANDALONE_FUZZ_MAIN:=/opt/mayhem/StandaloneFuzzTargetMain.c}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

: "${SRC:=/mayhem}"
cd "$SRC"

AUDIO_SRC=$(ls -d /opt/toolchains/deps/openshot-audio-*/src | head -n1)
AUDIO_PREFIX="$SRC/build-audio/install"
COMMON_CMAKE=(-G "Unix Makefiles" -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_PREFIX_PATH="$AUDIO_PREFIX" -DOpenShotAudio_ROOT="$AUDIO_PREFIX"
  -DENABLE_PYTHON=0 -DENABLE_RUBY=0 -DENABLE_JAVA=0 -DENABLE_LIB_DOCS=OFF -DENABLE_OPENCV=OFF -DENABLE_WAYLAND_CAPTURE=OFF -DUSE_HW_ACCEL=OFF
  -DENABLE_MAGICK=ON -DUSE_SYSTEM_JSONCPP=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo)

# 1) libopenshot-audio (pinned source from the image cache), built out of tree, normal flags: it is a
#    dependency, shared by the sanitized library and the test build.
if [ ! -f "$AUDIO_PREFIX/lib/libopenshot-audio.so" ]; then
  cmake -S "$AUDIO_SRC" -B "$SRC/build-audio" -G "Unix Makefiles" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-g -gdwarf-3" -DCMAKE_CXX_FLAGS="-g -gdwarf-3" \
    -DCMAKE_INSTALL_PREFIX="$AUDIO_PREFIX" -DBUILD_DOCS=OFF -DENABLE_DOCS=OFF
  cmake --build "$SRC/build-audio" -j"$MAYHEM_JOBS"
  cmake --install "$SRC/build-audio"
fi

# CMake wipes and half-reconfigures a cache whose compiler was recorded as an absolute path (the first
# run resolves `clang`), losing the OpenShotAudio location; configure the libopenshot trees from scratch.
rm -rf "$SRC/build-fuzz" "$SRC/build-tests"

# 2) Sanitized libopenshot. -fsanitize=fuzzer-no-link puts SanCov on the library so libFuzzer sees its edges.
# -fno-sanitize=enum: Point/Keyframe JSON loads an out-of-range InterpolationType value into the enum
# (src/Point.cpp:76); that halts on the first mutated "interpolation" number and hides everything behind it.
NO_ENUM="-fno-sanitize=enum"
FUZZ_FLAGS="$SANITIZER_FLAGS $NO_ENUM $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
cmake -S "$SRC" -B "$SRC/build-fuzz" "${COMMON_CMAKE[@]}" -DDISABLE_TESTS=ON \
  -DCMAKE_C_FLAGS="$FUZZ_FLAGS" -DCMAKE_CXX_FLAGS="$FUZZ_FLAGS" \
  -DCMAKE_SHARED_LINKER_FLAGS="$SANITIZER_FLAGS" -DCMAKE_EXE_LINKER_FLAGS="$SANITIZER_FLAGS"
cmake --build "$SRC/build-fuzz" -j"$MAYHEM_JOBS" --target openshot

# 3) Harnesses: fuzzer binary + standalone reproducer, each with LSan switched off.
QT_CFLAGS=$(pkg-config --cflags Qt5Widgets Qt5Gui Qt5Core libavutil)
QT_LIBS=$(pkg-config --libs Qt5Widgets Qt5Gui Qt5Core libavutil)
JSON_CFLAGS=$(pkg-config --cflags jsoncpp)
INCS=(-I"$SRC/src" -I"$SRC/build-fuzz/src" -I"$AUDIO_PREFIX/include/libopenshot-audio" $QT_CFLAGS $JSON_CFLAGS)
LIBS=("$SRC/build-fuzz/src/libopenshot.so" -L"$AUDIO_PREFIX/lib" -lopenshot-audio $QT_LIBS -ljsoncpp
  "-Wl,-rpath,$SRC/build-fuzz/src:$AUDIO_PREFIX/lib")
HFLAGS=(-std=c++17 -fPIC $SANITIZER_FLAGS $NO_ENUM $DEBUG_FLAGS)

$CC $SANITIZER_FLAGS $DEBUG_FLAGS -c "$STANDALONE_FUZZ_MAIN" -o /tmp/standalone_main.o
$CXX $SANITIZER_FLAGS -c "$SRC/mayhem/lsan_off.cc" -o /tmp/lsan_off.o

for h in fuzz_timeline_json fuzz_clip_json fuzz_caption fuzz_ffmpeg_reader; do
  $CXX "${HFLAGS[@]}" $LIB_FUZZING_ENGINE "${INCS[@]}" -I"$SRC/mayhem/harnesses" \
    "$SRC/mayhem/harnesses/$h.cpp" /tmp/lsan_off.o "${LIBS[@]}" -o "$SRC/$h"
  $CXX "${HFLAGS[@]}" "${INCS[@]}" -I"$SRC/mayhem/harnesses" \
    "$SRC/mayhem/harnesses/$h.cpp" /tmp/standalone_main.o /tmp/lsan_off.o "${LIBS[@]}" -o "$SRC/$h-standalone"
done

# 4) Test suite, normal flags, independent tree. Subset that needs no audio device, GPU or display.
TESTS=(Fraction Coordinate Point KeyFrame Color Clip Timeline Frame DummyReader FrameMapper Caption
  Settings Profiles ReaderBase CacheMemory QtImageReader FFmpegReader Blur Crop Saturation Sharpen Mask)
cmake -S "$SRC" -B "$SRC/build-tests" "${COMMON_CMAKE[@]}" -DENABLE_TESTS=ON -DBUILD_TESTING=ON \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS" \
  -DCMAKE_EXE_LINKER_FLAGS="$COVERAGE_FLAGS" -DCMAKE_SHARED_LINKER_FLAGS="$COVERAGE_FLAGS"
TARGETS=(); for t in "${TESTS[@]}"; do TARGETS+=("openshot-$t-test"); done
cmake --build "$SRC/build-tests" -j"$MAYHEM_JOBS" --target "${TARGETS[@]}"
