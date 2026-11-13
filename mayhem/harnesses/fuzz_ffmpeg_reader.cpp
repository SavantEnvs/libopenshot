// FFmpegReader on an arbitrary media file: probing, stream setup (Open) and decoding one frame.
#include <unistd.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>

extern "C" {
#include <libavutil/log.h>
}

#include "Exceptions.h"
#include "FFmpegReader.h"
#include "Frame.h"
#include "harness_common.h"

extern "C" int LLVMFuzzerInitialize(int *, char ***) {
  mayhem_init_qt();
  av_log_set_level(AV_LOG_QUIET);
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return -1;
  const char *tmp = getenv("TMPDIR");
  std::string path = std::string(tmp && *tmp ? tmp : "/tmp") + "/fuzz_ffmpeg_reader_XXXXXX";
  int fd = mkstemp(&path[0]);
  if (fd < 0) return -1;
  size_t off = 0;
  while (off < size) {
    ssize_t n = write(fd, data + off, size - off);
    if (n <= 0) break;
    off += static_cast<size_t>(n);
  }
  close(fd);

  int rc = 0;
  try {
    openshot::FFmpegReader reader(path);
    reader.Open();
    (void)reader.GetFrame(1);
    reader.Close();
  } catch (const openshot::ExceptionBase &) {
    rc = -1;
  }
  unlink(path.c_str());
  return rc;
}
