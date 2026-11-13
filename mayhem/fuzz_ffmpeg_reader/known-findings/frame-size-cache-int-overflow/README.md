# CacheBase::SetMaxBytesFromInfo: `int` overflow in `height * width * 4`

`input.bin` is a small MP4 file (taken from Mayhem run #3 of `fuzz-ffmpeg-reader`, sha256
`f0ec05931e45d44870125a31aa8cf7d3c467cc208f23744c2e32188553426972`) whose video stream declares a frame size of
23173x23173. `FFmpegReader::Open` (src/FFmpegReader.cpp:797) passes `info.height` and `info.width` to
`SetMaxBytesFromInfo`, which computes
`number_of_frames * (height * width * 4 + (sample_rate * channels * 4))` (src/CacheBase.cpp:31). The video product
`height * width * 4` is `int * int * int`, and only the final multiplication by `number_of_frames` is 64-bit.

UBSan (`signed-integer-overflow`, halting), column 53: `536987929 * 4 cannot be represented in type 'int'`
(`23173 * 23173 = 536987929`, so the `height * width` step fits and the `* 4` step overflows).
This is a different root cause from `audio-sample-rate-cache-int-overflow`, which is column 83, the
`* 4` after `sample_rate * channels` on the same line (the inner `sample_rate * channels` product, column 72, is
`audio-sample-rate-channels-cache-int-overflow`); Mayhem reports the three columns as separate defects.
Impact: undefined behaviour (and a wrong, possibly negative, cache size) from a media file with a large frame size.
Fix: widen before multiplying, for example
`int64_t bytes = number_of_frames * ((int64_t) height * width * 4 + (int64_t) sample_rate * channels * 4);`.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.bin`
