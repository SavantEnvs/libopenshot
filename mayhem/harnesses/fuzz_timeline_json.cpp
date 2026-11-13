// Timeline JSON: a '[' document is a change list for ApplyJsonDiff (insert/update/delete of clips,
// effects and timeline properties), anything else is a whole project for SetJson.
#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>

#include "Clip.h"
#include "DummyReader.h"
#include "Exceptions.h"
#include "Fraction.h"
#include "Timeline.h"
#include "harness_common.h"

extern "C" int LLVMFuzzerInitialize(int *, char ***) {
  mayhem_init_qt();
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0) return -1;
  const std::string json(reinterpret_cast<const char *>(data), size);

  // Clips with known ids so a diff can target existing clips; the timeline does not own them.
  openshot::DummyReader reader1(openshot::Fraction(30, 1), 320, 180, 44100, 2, 10.0f);
  openshot::DummyReader reader2(openshot::Fraction(30, 1), 320, 180, 44100, 2, 10.0f);
  openshot::Clip clip1(&reader1);
  openshot::Clip clip2(&reader2);
  clip1.Id("c1");
  clip2.Id("c2");
  clip2.Position(2.0);
  openshot::Timeline timeline(320, 180, openshot::Fraction(30, 1), 44100, 2, openshot::LAYOUT_STEREO);
  timeline.AddClip(&clip1);
  timeline.AddClip(&clip2);

  try {
    const size_t first = json.find_first_not_of(" \t\r\n");
    if (first != std::string::npos && json[first] == '[') {
      timeline.ApplyJsonDiff(json);
    } else {
      timeline.SetJson(json);
    }
  } catch (const openshot::ExceptionBase &) {
    return -1;
  } catch (const Json::Exception &) {
    return -1;
  }
  return 0;
}
