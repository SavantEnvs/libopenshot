# FFmpegReader: a 92-byte GIF with huge declared dimensions exhausts the 2 GB RSS limit

`input.gif` is 92 bytes. Its logical screen declares 14898 x 17714 pixels. `FFmpegReader::Open` accepts the
dimensions as probed, and `FFmpegReader::GetFrame` -> `ReadStream` -> `ProcessVideoPacket` -> `GetAVFrame`
(src/FFmpegReader.cpp:1691, `avcodec_send_packet`) makes FFmpeg's GIF decoder allocate one decoded frame
buffer of about 1.06 GB (`av_buffer_pool_get` -> `av_malloc` -> `posix_memalign`, a single allocation), and the
process passes libFuzzer's 2048 MB limit (`libFuzzer: out-of-memory (used: 2123Mb; limit: 2048Mb)`, CWE-789).

Root cause: huge decoded dimensions in the library (no size cap before decoding), not accumulation across inputs.
Replaying this one file alone reproduces it, and the harness keeps no state between inputs other than the Qt
application. The crash frame is in libavutil, so Mayhem reports no libopenshot frame; the first libopenshot frame
is `GetAVFrame`.
Impact: a tiny file makes the reader allocate gigabytes. Fix: reject or cap `info.width * info.height` in
`FFmpegReader::Open` before decoding.

Reproduce (the limit is libFuzzer's, so use the fuzz binary, not `-standalone`, which has no RSS limit):
`/mayhem/fuzz_ffmpeg_reader -rss_limit_mb=2048 input.gif`
