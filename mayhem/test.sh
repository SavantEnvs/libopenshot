#!/usr/bin/env bash
#
# mayhem/test.sh — RUN this repo's OWN functional test suite (already built by mayhem/build.sh).
# exit 0 = pass. EDIT per repo. PATCH-grade oracle: after an agent patches the source, the grader
# rebuilds (build.sh) then runs this. DELETE this file if the repo has no meaningful tests.
#
# IMPORTANT:
#  * Must assert BEHAVIOR/OUTPUT, not just exit status. The oracle has to check asserted values /
#    golden-output diffs / known-answer results — so a PATCH that "fixes" a bug by making the program
#    exit(0) (or any no-op) FAILS here. Running inputs and checking only "exit 0 / didn't crash" is
#    NOT a functional test (it's trivially reward-hackable) — use the project's real assertion suite.
#  * Do NOT build here — mayhem/build.sh already compiled the test suite (with the project's normal
#    flags). This script only RUNS the pre-built tests and reports counts. If the test runner is
#    missing, that's a build.sh bug — fail loudly rather than silently rebuilding.
#  * REQUIRED OUTPUT — a CTRF (https://ctrf.io) summary so Mayhem/the PATCH grader reads the counts:
#      - writes a CTRF JSON report to ${CTRF_REPORT:-$SRC/ctrf-report.json}, and
#      - prints a one-line `CTRF {...}` marker to stdout (same JSON, compact).
#    Only `results.summary` (with tests/passed/failed/pending/skipped/other) is required.
#    Use the emit_ctrf helper below; it computes tests = passed+failed+skipped and sets the exit
#    code (0 iff failed==0). Map your framework's output to passed/failed/skipped.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"   # build parallelism; env-overridable, falls back to nproc (use -j"$MAYHEM_JOBS")
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
# Writes a CTRF report (file + stdout `CTRF {...}` marker) and returns non-zero iff failed>0.
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

# Run the upstream Catch2 binaries directly and read their own summary line. A binary that prints no
# summary (crash, or an _exit(0) stub) counts as one failed test, so a no-op "fix" cannot pass.
export QT_QPA_PLATFORM=minimal
TESTS=(Fraction Coordinate Point KeyFrame Color Clip Timeline Frame DummyReader FrameMapper Caption
  Settings Profiles ReaderBase CacheMemory QtImageReader FFmpegReader Blur Crop Saturation Sharpen Mask)
# That Timeline case uses Catch2 assertions from several threads, which aborts inside Catch2 itself
# ("redirect is already active") under Debian's Catch2 3.7.1; it is a test-framework race, not a library result.
declare -A EXCLUDE=( [Timeline]="~Multi-threaded Timeline Add/Remove Effect" )
passed=0; failed=0
for t in "${TESTS[@]}"; do
  bin="$SRC/build-tests/tests/openshot-$t-test"
  if [ ! -x "$bin" ]; then echo "missing test binary $bin (build.sh bug)" >&2; failed=$((failed+1)); continue; fi
  out=$(cd "$SRC/build-tests/tests" && timeout 900 "$bin" ${EXCLUDE[$t]:+"${EXCLUDE[$t]}"} 2>&1) ; rc=$?
  if [ "$rc" -eq 0 ]; then printf '%s\n' "$out" | tail -n 4; else printf 'FAILED openshot-%s-test (rc=%s)\n%s\n' "$t" "$rc" "$out"; fi
  if [[ "$out" =~ All\ tests\ passed\ \([0-9]+\ assertions?\ in\ ([0-9]+)\ test\ cases? ]]; then
    n=${BASH_REMATCH[1]}; [ "$rc" -eq 0 ] && passed=$((passed+n)) || failed=$((failed+1))
  elif [[ "$out" =~ test\ cases:\ +([0-9]+)\ \|\ +([0-9]+)\ passed\ \|\ +([0-9]+)\ failed ]]; then
    passed=$((passed+BASH_REMATCH[2])); failed=$((failed+BASH_REMATCH[3]))
  else
    echo "no Catch2 summary from openshot-$t-test (rc=$rc)" >&2; failed=$((failed+1))
  fi
done

# Known-answer floor: the suites above must really have run (hundreds of test cases).
if [ "$passed" -lt 150 ]; then echo "only $passed test cases passed, expected >= 150" >&2; failed=$((failed+1)); fi

emit_ctrf "catch2" "$passed" "$failed" 0
