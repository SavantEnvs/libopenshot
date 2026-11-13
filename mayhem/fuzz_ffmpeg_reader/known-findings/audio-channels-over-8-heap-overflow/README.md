# FFmpegReader::ProcessAudioPacket: audio with more than 8 channels overflows `AVFrame::data[]`

`input.wav` is a truncated WAV whose header declares 254 channels of `pcm_s16le`. `FFmpegReader` takes
`info.channels` straight from the stream (src/FFmpegReader.cpp:1036/1039) and `ProcessAudioPacket`
(src/FFmpegReader.cpp:2506) calls
`av_samples_alloc(audio_converted->data, audio_converted->linesize, info.channels, ...)` for a planar
float output. `AVFrame::data` has only `AV_NUM_DATA_POINTERS` (8) slots, so `av_samples_fill_arrays`
writes one pointer per channel past the end of the `AVFrame`.

ASan: `heap-buffer-overflow ... WRITE of size 2032` in `memset` <- `av_samples_fill_arrays` <- `av_samples_alloc`
<- `ProcessAudioPacket` (FFmpegReader.cpp:2506).
Impact: heap corruption from a malformed or merely unusual media file (any file with more than 8 audio channels).
Fix: for more than 8 channels allocate the planes through `extended_data` (`av_samples_alloc_array_and_samples`)
and read them from `extended_data`, or reject such streams in `Open()`.
Same root cause as `audio-channels-over-8-data-index` (a smaller channel count that stays inside the `AVFrame`).

Reproduce: `/mayhem/fuzz_ffmpeg_reader-standalone input.wav`
