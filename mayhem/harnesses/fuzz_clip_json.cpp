// Clip JSON: parse a clip description (keyframes, effects, optional reader) with SetJson, serialize
// it back, and render two frames (after Open) through the clip's effect chain.
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>

#include "Clip.h"
#include "DummyReader.h"
#include "Exceptions.h"
#include "Fraction.h"
#include "harness_common.h"

extern "C" int LLVMFuzzerInitialize(int *, char ***) {
  mayhem_init_qt();
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return -1;
  const std::string json(reinterpret_cast<const char *>(data), size);

  openshot::DummyReader reader(openshot::Fraction(30, 1), 160, 90, 44100, 2, 4.0f);
  openshot::Clip clip(&reader);

  try {
    clip.SetJson(json);
    (void)clip.Json();
    clip.Open();
    (void)clip.GetFrame(1);
    (void)clip.GetFrame(45);
    clip.Close();
  } catch (const openshot::ExceptionBase &) {
    return -1;
  } catch (const Json::Exception &) {
    return -1;
  }
  return 0;
}
