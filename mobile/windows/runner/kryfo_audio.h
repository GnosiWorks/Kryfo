// SPDX-License-Identifier: GPL-3.0-or-later
// voice notes on windows: the mic and the speakers through wasapi in shared
// mode, 16-bit pcm both ways, no decoder and no file. dart calls these over
// ffi; the samples go to dart's own buffers and every copy kept here is
// zeroed once it is used
#ifndef RUNNER_KRYFO_AUDIO_H_
#define RUNNER_KRYFO_AUDIO_H_

#include <cstdint>
#include <vector>

namespace kryfo {

// the calls' addresses, in the order lib/desktop/win_audio.dart reads them
std::vector<int64_t> AudioCalls();

}  // namespace kryfo

#endif  // RUNNER_KRYFO_AUDIO_H_
