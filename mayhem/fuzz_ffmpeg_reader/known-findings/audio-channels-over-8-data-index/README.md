# FFmpegReader::ProcessAudioPacket: `audio_converted->data[channel]` indexed past 8

`input.wav` is a truncated WAV whose header declares 37 channels of `pcm_s16le`. After the resample,
`ProcessAudioPacket` loops `channel_filter` over `info.channels` and reads
`audio_converted->data[channel_filter]` (src/FFmpegReader.cpp:2561). `AVFrame::data` is `uint8_t *[8]`,
so every channel from 8 up is out of bounds. With 37 channels the overflowing `av_samples_alloc` write at
line 2506 stays inside the `AVFrame` struct (ASan does not see it), so this read is where the run stops.

UBSan (`array-bounds`, halting): `index 8 out of bounds for type 'uint8_t *[8]'`.
Impact: out-of-bounds pointer read, then reads through whatever pointer is there, from a malformed media file.
Fix: same as `audio-channels-over-8-heap-overflow`: use `extended_data` for the planes, or reject streams
with more than `AV_NUM_DATA_POINTERS` channels. Both entries are one root cause with two crash sites,
recorded separately because Mayhem reports them as separate defects.

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.wav`
