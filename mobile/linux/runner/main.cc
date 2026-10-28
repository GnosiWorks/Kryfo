#include <sys/prctl.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // no core dump of a process holding keys and messages, and no other
  // process of the same user may attach to read its memory
  prctl(PR_SET_DUMPABLE, 0, 0, 0, 0);
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
