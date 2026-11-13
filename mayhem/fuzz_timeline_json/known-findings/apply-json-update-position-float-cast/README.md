# Timeline::apply_json_to_clips: out-of-range clip position overflows an `int64_t` conversion

`input.json` is an `ApplyJsonDiff` change list (a `[` document, taken from Mayhem run #4 of
`fuzz-timeline-json`, sha256 `973ef05ed2a8aecbf9298b3a6b284c02caf0252fd4307c8a5152899eae87a232`) with one
`update` of clip `c2` whose `position` is `8.9e81`. `Clip::SetJsonValue` reads it as a `double` and stores it in the
`float position` member (src/ClipBase.cpp:90), where it becomes `inf`. `Timeline::apply_json_to_clips`
(src/Timeline.cpp:1571, column 33) then computes
`int64_t new_starting_frame = (existing_clip->Position() * info.fps.ToDouble()) + 1;`: `inf * 30` is `inf`,
and the conversion to `int64_t` has no range check. Any finite position above about `3e17` seconds overflows the same way.
The next line, `new_ending_frame` (line 1572), has the same pattern with `Position() + Duration()`, and so
does the pre-update computation of `old_starting_frame`/`old_ending_frame`; this entry is the first one the
run reached. It is a different expression from `duration-inf-float-cast` (`Timeline::SetJsonValue`, line 1393),
and Mayhem reports it as its own defect.

UBSan (`float-cast-overflow`, halting) reports: `inf is outside the range of representable values of type 'long'`.
Impact: undefined behaviour reachable from any `ApplyJsonDiff` payload that moves or resizes an existing clip;
the cache ranges passed to `final_cache->Remove` are then garbage. Fix: reject or clamp non-finite and
out-of-range `position`/`duration` (in `Clip::SetJsonValue` or before these conversions), or compute the
frame numbers through a saturating conversion.

Reproduce: `/mayhem/fuzz_timeline_json-standalone input.json`
