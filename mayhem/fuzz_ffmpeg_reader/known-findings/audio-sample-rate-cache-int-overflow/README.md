# CacheBase::SetMaxBytesFromInfo: `int` overflow in the per-frame byte count

`input.wav` is a truncated WAV whose header declares a sample rate of 1627397952 Hz, 1 channel. `FFmpegReader::Open`
(src/FFmpegReader.cpp:797) passes `info.sample_rate` and `info.channels` to `SetMaxBytesFromInfo`, which computes
`number_of_frames * (height * width * 4 + (sample_rate * channels * 4))` (src/CacheBase.cpp:31). The inner
products are `int * int`, and only the final multiplication by `number_of_frames` is 64-bit.

UBSan (`signed-integer-overflow`, halting), column 83: `1627397952 * 4 cannot be represented in type 'int'`.
This entry covers only the `* 4` after the audio product (column 83). The inner `sample_rate * channels` product
(column 72, for example `1769108595 * 6`) is a separate defect with its own entry,
`audio-sample-rate-channels-cache-int-overflow`, and so is the video product `height * width * 4` (column 53,
`frame-size-cache-int-overflow`); Mayhem reports the three columns as separate defects.
Impact: undefined behaviour (and a wrong, possibly negative, cache size) from a media file with a large sample
rate. Fix: widen before multiplying, for example
`int64_t bytes = number_of_frames * ((int64_t) height * width * 4 + (int64_t) sample_rate * channels * 4);`.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.wav`
