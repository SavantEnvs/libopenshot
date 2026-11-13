# CacheBase::SetMaxBytesFromInfo: `int` overflow in `sample_rate * channels`

`input.wav` is a small WAV (taken from Mayhem run #5 of `fuzz-ffmpeg-reader`, sha256
`0a800b22797cefb4c2fe85766c99f16b74492a79787b36d48de29e37339ef276`) whose header declares 6 channels and a sample
rate of 1769108595 Hz. `FFmpegReader::Open` (src/FFmpegReader.cpp:797) passes `info.sample_rate` and `info.channels`
to `SetMaxBytesFromInfo`, which computes
`number_of_frames * (height * width * 4 + (sample_rate * channels * 4))` (src/CacheBase.cpp:31). The audio product
`sample_rate * channels` is `int * int`, and only the final multiplication by `number_of_frames` is 64-bit.

UBSan (`signed-integer-overflow`, halting), column 72: `1769108595 * 6 cannot be represented in type 'int'`.
This is the inner `sample_rate * channels` product, evaluated before the `* 4`. It is a separate defect from
`audio-sample-rate-cache-int-overflow` (column 83, the `* 4` after it, which a rate of 1627397952 with 1 channel
reaches) and from `frame-size-cache-int-overflow` (column 53, the video `* 4`); Mayhem reports the three columns as
separate defects.
Impact: undefined behaviour (and a wrong, possibly negative, cache size) from a media file with a large sample rate
and several channels.
Fix: widen before multiplying, for example
`int64_t bytes = number_of_frames * ((int64_t) height * width * 4 + (int64_t) sample_rate * channels * 4);`.
The same change fixes all three columns.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.wav` (replayed on a local build of the image: it stops at
`src/CacheBase.cpp:31:72` with the message above).
