// Caption effect: WebVTT/SRT-style caption text is split by a regex into cues, wrapped and painted
// onto frames with Qt.
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>

#include "Exceptions.h"
#include "Frame.h"
#include "effects/Caption.h"
#include "harness_common.h"

extern "C" int LLVMFuzzerInitialize(int *, char ***) {
  mayhem_init_qt();
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return -1;
  const std::string text(reinterpret_cast<const char *>(data), size);

  openshot::Caption caption(text);
  try {
    for (int64_t frame_number : {1, 20, 300}) {
      auto frame = std::make_shared<openshot::Frame>(frame_number, 320, 180, "#000000");
      caption.GetFrame(frame, frame_number);
    }
  } catch (const openshot::ExceptionBase &) {
    return -1;
  }
  return 0;
}
