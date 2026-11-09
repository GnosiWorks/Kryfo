#include <sys/prctl.h>
#include <sys/resource.h>

#include "my_application.h"

int main(int argc, char** argv) {
  // no core dump of a process holding keys and messages
  struct rlimit rl = {0, 0};
  setrlimit(RLIMIT_CORE, &rl);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
