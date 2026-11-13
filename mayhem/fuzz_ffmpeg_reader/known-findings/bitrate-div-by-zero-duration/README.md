# FFmpegReader: non-finite value converted to `int`

`input.bin` is a truncated MP4 (no usable codec parameters). `FFmpegReader` (src/FFmpegReader.cpp:3333)
computes `info.video_bit_rate = info.file_size / info.duration`; with a zero duration the division is
infinite and its conversion to `int` has no range check.

UBSan (`float-cast-overflow`, halting): `inf is outside the range of representable values of type 'int'`.
Impact: undefined behaviour from a malformed media file. Fix: check `std::isfinite` and the range before the cast.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.bin`
