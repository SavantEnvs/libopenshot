# FFmpegReader::UpdateVideoInfo: `int` overflow in `height * pixel_ratio.den`

`input.bin` is a small MP4 file whose stream declares a huge sample aspect ratio. `UpdateVideoInfo`
(src/FFmpegReader.cpp:1168) builds the display aspect ratio as
`Fraction size(info.width * info.pixel_ratio.num, info.height * info.pixel_ratio.den)`; both products are
`int * int` with the aspect ratio taken straight from the container.

UBSan (`signed-integer-overflow`, halting), column 63: `384 * 765833507 cannot be represented in type 'int'`.
This is the same root cause as `display-aspect-ratio-int-overflow-width` (column 27, the `width * num` product);
Mayhem reports the two columns as separate defects, so each has an entry.
Impact: undefined behaviour and a wrong display ratio from a malformed file. Fix: widen to 64-bit before
multiplying, then reduce (or reject a ratio that does not fit in `int`).

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.bin`
