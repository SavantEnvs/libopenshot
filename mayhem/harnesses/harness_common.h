// Shared setup for the libopenshot fuzz harnesses.
#pragma once
#include <QApplication>
#include <cstdlib>

// Text effects/readers need a QGuiApplication (font database); the `minimal` platform is what
// upstream's own Caption/Timer tests use. Created once; it holds no per-input state.
inline void mayhem_init_qt() {
  static int argc = 1;
  static char arg0[] = "fuzz";
  static char *argv[] = {arg0, nullptr};
  setenv("QT_QPA_PLATFORM", "minimal", 0);
  static QApplication app(argc, argv);
}
