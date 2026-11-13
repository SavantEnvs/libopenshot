# Timeline::SetJsonValue: infinite `duration` overflows a `long` conversion

`input.json` is a Timeline project whose `"duration"` is huge/infinite. `Timeline::SetJsonValue`
(src/Timeline.cpp:1393) computes `info.video_length = info.fps.ToFloat() * info.duration` and the
result is converted to `int64_t` (`long`) with no range check.

UBSan (`float-cast-overflow`, halting) reports: `inf is outside the range of representable values of type 'long'`.
Impact: undefined behaviour reachable from any project file or `ApplyJsonDiff` payload. Fix: reject or
clamp non-finite/out-of-range `duration` before the conversion.

Reproduce: `/mayhem/fuzz_timeline_json-standalone input.json`
