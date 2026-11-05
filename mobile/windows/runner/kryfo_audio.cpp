// SPDX-License-Identifier: GPL-3.0-or-later
// the mic and the speakers through wasapi, shared mode. windows converts
// between our 16-bit pcm and the device's own format (autoconvertpcm), so
// nothing here reads a codec or a container. one mic at a time; a player
// per note. all com work happens on each one's own thread
#include "kryfo_audio.h"

#include <windows.h>
#include <audioclient.h>
#include <mmdeviceapi.h>

#include <cstring>
#include <new>

namespace {

// what open and load answer
constexpr int32_t kOk = 0;
constexpr int32_t kBlocked = 1;  // windows' privacy settings refuse the mic
constexpr int32_t kNone = 2;     // no device, or it went away
constexpr int32_t kFailed = 3;

// the most the mic holds for dart: a minute of 16 khz mono. dart takes every
// 100 ms; past this the newest samples are dropped
constexpr size_t kMicMax = 16000 * 2 * 60;

constexpr REFERENCE_TIME kBufferHns = 2000000;  // 200 ms

const CLSID kEnumerator = __uuidof(MMDeviceEnumerator);
const IID kEnumeratorIid = __uuidof(IMMDeviceEnumerator);
const IID kClientIid = __uuidof(IAudioClient);
const IID kCaptureIid = __uuidof(IAudioCaptureClient);
const IID kRenderIid = __uuidof(IAudioRenderClient);

int32_t WordOf(HRESULT hr) {
  if (SUCCEEDED(hr)) return kOk;
  if (hr == E_ACCESSDENIED) return kBlocked;
  if (hr == HRESULT_FROM_WIN32(ERROR_NOT_FOUND) || hr == AUDCLNT_E_DEVICE_INVALIDATED ||
      hr == AUDCLNT_E_ENDPOINT_CREATE_FAILED) {
    return kNone;
  }
  return kFailed;
}

template <class T>
void Release(T*& p) {
  if (p) p->Release();
  p = nullptr;
}

void Zero(void* p, size_t n) {
  if (p && n) SecureZeroMemory(p, n);
}

// a shared-mode client on the default device of [flow], set to 16-bit pcm
// at [rate] and [channels], with its event. the caller releases it
HRESULT OpenClient(EDataFlow flow, int rate, int channels, HANDLE event, IAudioClient** out) {
  *out = nullptr;
  IMMDeviceEnumerator* en = nullptr;
  IMMDevice* dev = nullptr;
  IAudioClient* client = nullptr;
  HRESULT hr = CoCreateInstance(kEnumerator, nullptr, CLSCTX_ALL, kEnumeratorIid,
                                reinterpret_cast<void**>(&en));
  if (SUCCEEDED(hr)) hr = en->GetDefaultAudioEndpoint(flow, eConsole, &dev);
  if (SUCCEEDED(hr)) {
    hr = dev->Activate(kClientIid, CLSCTX_ALL, nullptr, reinterpret_cast<void**>(&client));
  }
  if (SUCCEEDED(hr)) {
    WAVEFORMATEX wf = {};
    wf.wFormatTag = WAVE_FORMAT_PCM;
    wf.nChannels = static_cast<WORD>(channels);
    wf.nSamplesPerSec = static_cast<DWORD>(rate);
    wf.wBitsPerSample = 16;
    wf.nBlockAlign = static_cast<WORD>(channels * 2);
    wf.nAvgBytesPerSec = wf.nSamplesPerSec * wf.nBlockAlign;
    hr = client->Initialize(AUDCLNT_SHAREMODE_SHARED,
                            AUDCLNT_STREAMFLAGS_EVENTCALLBACK | AUDCLNT_STREAMFLAGS_AUTOCONVERTPCM |
                                AUDCLNT_STREAMFLAGS_SRC_DEFAULT_QUALITY,
                            kBufferHns, 0, &wf, nullptr);
  }
  if (SUCCEEDED(hr) && event) hr = client->SetEventHandle(event);
  Release(dev);
  Release(en);
  if (FAILED(hr)) {
    Release(client);
    return hr;
  }
  *out = client;
  return S_OK;
}

// ---- the mic

struct Mic {
  CRITICAL_SECTION lock;
  uint8_t* buf = nullptr;
  size_t len = 0;
  HANDLE thread = nullptr;
  HANDLE stop = nullptr;
  HANDLE ready = nullptr;
  int rate = 16000;
  int channels = 1;
  bool probe = false;
  volatile LONG word = kFailed;
  volatile LONG gone = 0;
};

Mic* g_mic = nullptr;

void MicAdd(Mic* m, const BYTE* data, size_t n, bool silent) {
  EnterCriticalSection(&m->lock);
  if (m->len + n > kMicMax) n = kMicMax - m->len;
  if (n) {
    if (silent || !data) {
      memset(m->buf + m->len, 0, n);
    } else {
      memcpy(m->buf + m->len, data, n);
    }
    m->len += n;
  }
  LeaveCriticalSection(&m->lock);
}

DWORD WINAPI MicMain(LPVOID arg) {
  Mic* m = static_cast<Mic*>(arg);
  HRESULT co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  HANDLE event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  IAudioClient* client = nullptr;
  IAudioCaptureClient* cap = nullptr;
  HRESULT hr = event ? OpenClient(eCapture, m->rate, m->channels, event, &client) : E_FAIL;
  if (SUCCEEDED(hr) && !m->probe) {
    hr = client->GetService(kCaptureIid, reinterpret_cast<void**>(&cap));
    if (SUCCEEDED(hr)) hr = client->Start();
  }
  m->word = WordOf(hr);
  SetEvent(m->ready);
  if (SUCCEEDED(hr) && !m->probe) {
    const size_t frame = static_cast<size_t>(m->channels) * 2;
    HANDLE waits[2] = {m->stop, event};
    for (;;) {
      DWORD w = WaitForMultipleObjects(2, waits, FALSE, 500);
      if (w == WAIT_OBJECT_0) break;
      UINT32 next = 0;
      HRESULT got = cap->GetNextPacketSize(&next);
      while (SUCCEEDED(got) && next > 0) {
        BYTE* data = nullptr;
        UINT32 frames = 0;
        DWORD flags = 0;
        got = cap->GetBuffer(&data, &frames, &flags, nullptr, nullptr);
        if (FAILED(got)) break;
        MicAdd(m, data, frames * frame, (flags & AUDCLNT_BUFFERFLAGS_SILENT) != 0);
        got = cap->ReleaseBuffer(frames);
        if (SUCCEEDED(got)) got = cap->GetNextPacketSize(&next);
      }
      if (FAILED(got)) {
        // unplugged, or the device changed under it: what came stays
        InterlockedExchange(&m->gone, 1);
        break;
      }
    }
    client->Stop();
  }
  Release(cap);
  Release(client);
  if (event) CloseHandle(event);
  if (SUCCEEDED(co)) CoUninitialize();
  return 0;
}

void MicEnd(Mic* m) {
  if (!m) return;
  if (m->thread) {
    SetEvent(m->stop);
    WaitForSingleObject(m->thread, INFINITE);
    CloseHandle(m->thread);
  }
  if (m->stop) CloseHandle(m->stop);
  if (m->ready) CloseHandle(m->ready);
  Zero(m->buf, kMicMax);
  delete[] m->buf;
  DeleteCriticalSection(&m->lock);
  delete m;
}

Mic* MicStart(int32_t rate, int32_t channels, bool probe, int32_t* word) {
  *word = kFailed;
  if (rate < 8000 || rate > 48000 || channels < 1 || channels > 2) return nullptr;
  Mic* m = new Mic();
  InitializeCriticalSection(&m->lock);
  m->rate = rate;
  m->channels = channels;
  m->probe = probe;
  // no throw across dart's ffi: out of memory is a failure
  if (!probe) m->buf = new (std::nothrow) uint8_t[kMicMax];
  m->stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  m->ready = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (m->stop && m->ready && (probe || m->buf)) m->thread = CreateThread(nullptr, 0, MicMain, m, 0, nullptr);
  if (!m->thread) {
    MicEnd(m);
    return nullptr;
  }
  // the device answers in well under a second; a stuck one is a failure
  if (WaitForSingleObject(m->ready, 5000) != WAIT_OBJECT_0) {
    MicEnd(m);
    return nullptr;
  }
  *word = m->word;
  if (*word != kOk || probe) {
    MicEnd(m);
    return nullptr;
  }
  return m;
}

// whether the mic opens now, without recording
int32_t MicProbe() {
  if (g_mic) return kOk;
  int32_t word = kFailed;
  MicStart(16000, 1, true, &word);
  return word;
}

int32_t MicOpen(int32_t rate, int32_t channels) {
  if (g_mic) return kFailed;
  int32_t word = kFailed;
  g_mic = MicStart(rate, channels, false, &word);
  return word;
}

// up to [cap] bytes of what came, into dart's [dst]; what was handed over is
// zeroed here. -1 once the device is gone and nothing is left
int32_t MicTake(uint8_t* dst, int32_t cap) {
  Mic* m = g_mic;
  if (!m || !dst || cap <= 0) return 0;
  EnterCriticalSection(&m->lock);
  size_t n = m->len < static_cast<size_t>(cap) ? m->len : static_cast<size_t>(cap);
  // whole samples only
  n -= n % 2;
  if (n) {
    memcpy(dst, m->buf, n);
    memmove(m->buf, m->buf + n, m->len - n);
    Zero(m->buf + m->len - n, n);
    m->len -= n;
  }
  LeaveCriticalSection(&m->lock);
  if (n == 0 && m->gone) return -1;
  return static_cast<int32_t>(n);
}

void MicClose() {
  Mic* m = g_mic;
  g_mic = nullptr;
  MicEnd(m);
}

// ---- the speakers

struct Player {
  CRITICAL_SECTION lock;
  uint8_t* pcm = nullptr;
  int64_t len = 0;   // bytes
  int64_t pos = 0;   // bytes handed to windows
  int64_t queued = 0;  // frames windows holds and has not played
  int rate = 16000;
  int channels = 1;
  double volume = 1;
  bool playing = false;
  int64_t seek_to = -1;  // bytes, -1 for none
  HANDLE thread = nullptr;
  HANDLE stop = nullptr;
  HANDLE wake = nullptr;
  HANDLE ready = nullptr;
  volatile LONG word = kFailed;
  volatile LONG ended = 0;
  volatile LONG failed = 0;
};

// as many frames as there is room for, at the volume; true at the end
bool Fill(Player* p, IAudioClient* client, IAudioRenderClient* render, UINT32 size,
          HRESULT* hr) {
  UINT32 padding = 0;
  *hr = client->GetCurrentPadding(&padding);
  if (FAILED(*hr)) return false;
  const int64_t frame = static_cast<int64_t>(p->channels) * 2;
  EnterCriticalSection(&p->lock);
  int64_t left = (p->len - p->pos) / frame;
  UINT32 n = size - padding;
  if (left < n) n = static_cast<UINT32>(left);
  if (n > 0) {
    BYTE* out = nullptr;
    *hr = render->GetBuffer(n, &out);
    if (SUCCEEDED(*hr)) {
      const int16_t* from = reinterpret_cast<const int16_t*>(p->pcm + p->pos);
      int16_t* to = reinterpret_cast<int16_t*>(out);
      const size_t samples = static_cast<size_t>(n) * p->channels;
      if (p->volume >= 1) {
        memcpy(to, from, samples * 2);
      } else {
        for (size_t i = 0; i < samples; i++) {
          to[i] = static_cast<int16_t>(from[i] * p->volume);
        }
      }
      *hr = render->ReleaseBuffer(n, 0);
      p->pos += n * frame;
    }
  }
  p->queued = padding + n;
  bool done = SUCCEEDED(*hr) && left == n && padding == 0 && n == 0;
  LeaveCriticalSection(&p->lock);
  return done;
}

DWORD WINAPI PlayMain(LPVOID arg) {
  Player* p = static_cast<Player*>(arg);
  HRESULT co = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  HANDLE event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  IAudioClient* client = nullptr;
  IAudioRenderClient* render = nullptr;
  UINT32 size = 0;
  HRESULT hr = event ? OpenClient(eRender, p->rate, p->channels, event, &client) : E_FAIL;
  if (SUCCEEDED(hr)) hr = client->GetBufferSize(&size);
  if (SUCCEEDED(hr)) hr = client->GetService(kRenderIid, reinterpret_cast<void**>(&render));
  p->word = WordOf(hr);
  SetEvent(p->ready);
  if (SUCCEEDED(hr)) {
    bool started = false;
    HANDLE waits[3] = {p->stop, p->wake, event};
    for (;;) {
      DWORD w = WaitForMultipleObjects(3, waits, FALSE, 200);
      if (w == WAIT_OBJECT_0) break;
      EnterCriticalSection(&p->lock);
      bool want = p->playing;
      int64_t seek = p->seek_to;
      p->seek_to = -1;
      LeaveCriticalSection(&p->lock);
      if (seek >= 0) {
        if (started) client->Stop();
        started = false;
        hr = client->Reset();
        EnterCriticalSection(&p->lock);
        p->pos = seek;
        p->queued = 0;
        LeaveCriticalSection(&p->lock);
      }
      if (want && !started) {
        Fill(p, client, render, size, &hr);
        if (FAILED(hr)) break;
        hr = client->Start();
        if (FAILED(hr)) break;
        started = true;
      } else if (!want && started) {
        client->Stop();
        started = false;
      }
      if (!started) continue;
      if (Fill(p, client, render, size, &hr)) {
        client->Stop();
        client->Reset();
        started = false;
        EnterCriticalSection(&p->lock);
        p->playing = false;
        p->queued = 0;
        LeaveCriticalSection(&p->lock);
        InterlockedExchange(&p->ended, 1);
      }
      if (FAILED(hr)) break;
    }
    if (FAILED(hr)) InterlockedExchange(&p->failed, 1);
    if (started) client->Stop();
  }
  Release(render);
  Release(client);
  if (event) CloseHandle(event);
  if (SUCCEEDED(co)) CoUninitialize();
  return 0;
}

void PlayEnd(Player* p) {
  if (p->thread) {
    SetEvent(p->stop);
    WaitForSingleObject(p->thread, INFINITE);
    CloseHandle(p->thread);
    p->thread = nullptr;
  }
  for (HANDLE* h : {&p->stop, &p->wake, &p->ready}) {
    if (*h) CloseHandle(*h);
    *h = nullptr;
  }
  Zero(p->pcm, static_cast<size_t>(p->len));
  delete[] p->pcm;
  p->pcm = nullptr;
  p->len = p->pos = p->queued = 0;
  p->playing = false;
  p->seek_to = -1;
}

int64_t PlayNew() {
  Player* p = new Player();
  InitializeCriticalSection(&p->lock);
  return reinterpret_cast<int64_t>(p);
}

// [n] bytes of 16-bit pcm copied in, replacing what was loaded; dart zeroes
// its own copy after
int32_t PlayLoad(int64_t h, const uint8_t* data, int64_t n, int32_t rate, int32_t channels) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p) return kFailed;
  PlayEnd(p);
  if (!data || n <= 0 || rate < 8000 || rate > 48000 || channels < 1 || channels > 2) {
    return kFailed;
  }
  n -= n % (channels * 2);
  p->pcm = new (std::nothrow) uint8_t[static_cast<size_t>(n > 0 ? n : 1)];
  if (!p->pcm) return kFailed;
  memcpy(p->pcm, data, static_cast<size_t>(n));
  p->len = n;
  p->rate = rate;
  p->channels = channels;
  p->ended = 0;
  p->failed = 0;
  p->stop = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  p->wake = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  p->ready = CreateEventW(nullptr, TRUE, FALSE, nullptr);
  if (p->stop && p->wake && p->ready) {
    p->thread = CreateThread(nullptr, 0, PlayMain, p, 0, nullptr);
  }
  if (!p->thread || WaitForSingleObject(p->ready, 5000) != WAIT_OBJECT_0) {
    PlayEnd(p);
    return kFailed;
  }
  int32_t word = p->word;
  if (word != kOk) PlayEnd(p);
  return word;
}

void PlayOn(int64_t h, int32_t on) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p || !p->thread) return;
  EnterCriticalSection(&p->lock);
  p->playing = on != 0;
  if (on) p->ended = 0;
  LeaveCriticalSection(&p->lock);
  SetEvent(p->wake);
}

void PlaySeek(int64_t h, int64_t ms) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p || !p->thread) return;
  EnterCriticalSection(&p->lock);
  const int64_t frame = static_cast<int64_t>(p->channels) * 2;
  int64_t at = (ms < 0 ? 0 : ms) * p->rate / 1000 * frame;
  p->seek_to = at > p->len ? p->len : at;
  p->ended = 0;
  LeaveCriticalSection(&p->lock);
  SetEvent(p->wake);
}

void PlayVolume(int64_t h, double v) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p) return;
  EnterCriticalSection(&p->lock);
  p->volume = v < 0 ? 0 : (v > 1 ? 1 : v);
  LeaveCriticalSection(&p->lock);
}

// where the speakers are in the note, in ms
int64_t PlayAt(int64_t h) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p || p->rate <= 0) return 0;
  EnterCriticalSection(&p->lock);
  const int64_t frame = static_cast<int64_t>(p->channels) * 2;
  int64_t frames = (p->seek_to >= 0 ? p->seek_to : p->pos) / frame -
                   (p->seek_to >= 0 ? 0 : p->queued);
  int64_t rate = p->rate;
  LeaveCriticalSection(&p->lock);
  return frames < 0 ? 0 : frames * 1000 / rate;
}

// 1 the end was reached, 2 the device failed, since the last ask
int32_t PlayState(int64_t h) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p) return 0;
  int32_t s = 0;
  if (InterlockedExchange(&p->ended, 0)) s |= 1;
  if (InterlockedExchange(&p->failed, 0)) s |= 2;
  return s;
}

void PlayFree(int64_t h) {
  Player* p = reinterpret_cast<Player*>(h);
  if (!p) return;
  PlayEnd(p);
  DeleteCriticalSection(&p->lock);
  delete p;
}

}  // namespace

namespace kryfo {

std::vector<int64_t> AudioCalls() {
  return {
      reinterpret_cast<int64_t>(&MicProbe),   reinterpret_cast<int64_t>(&MicOpen),
      reinterpret_cast<int64_t>(&MicTake),    reinterpret_cast<int64_t>(&MicClose),
      reinterpret_cast<int64_t>(&PlayNew),    reinterpret_cast<int64_t>(&PlayLoad),
      reinterpret_cast<int64_t>(&PlayOn),     reinterpret_cast<int64_t>(&PlaySeek),
      reinterpret_cast<int64_t>(&PlayVolume), reinterpret_cast<int64_t>(&PlayAt),
      reinterpret_cast<int64_t>(&PlayState),  reinterpret_cast<int64_t>(&PlayFree),
  };
}

}  // namespace kryfo
