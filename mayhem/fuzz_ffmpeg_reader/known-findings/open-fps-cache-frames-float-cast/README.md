# FFmpegReader::Open: hostile frame rate converted to `int` out of range

`input.bin` is a small MP4 file whose video stream declares an enormous frame rate. `FFmpegReader::Open`
(src/FFmpegReader.cpp:795) sizes the working cache with
`int(OPEN_MP_NUM_PROCESSORS * info.fps.ToDouble() * 2)`; the `double` is converted to `int` with no range check.

UBSan (`float-cast-overflow`, halting): `4.6471e+10 is outside the range of representable values of type 'int'`.
Impact: undefined behaviour (and a wrong cache frame count) from a malformed file. Fix: clamp the `double` to
`INT_MAX` (and reject a non-finite or non-positive rate) before the cast.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.bin`
