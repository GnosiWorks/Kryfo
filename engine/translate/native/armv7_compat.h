// SPDX-License-Identifier: GPL-3.0-or-later
// put in front of every file of the armeabi-v7a build, for the armv8 neon
// calls marian's arm code makes:
// - simd_utils writes its float math with the fused vfmaq_f32 and
//   vfmaq_n_f32, which 32-bit neon has only on vfpv4 cores; the plain
//   multiply-add gives a + b * c too, so a cortex-a9 runs it as well
// - ruy_interface quantizes with vcvtnq_s32_f32 (round to nearest), which
//   is armv8 only: here halves round away from zero instead of to even,
//   which moves a value that sits exactly on .5 by one step
#ifndef KRYFO_ARMV7_COMPAT_H
#define KRYFO_ARMV7_COMPAT_H
#if defined(__arm__) && !defined(__aarch64__) && !defined(__ARM_FEATURE_FMA)
#include <arm_neon.h>
#define vfmaq_f32(a, b, c) vmlaq_f32((a), (b), (c))
#define vfmaq_n_f32(a, b, n) vmlaq_n_f32((a), (b), (n))
#endif
#if defined(__arm__) && !defined(__aarch64__) && __ARM_ARCH < 8
#include <arm_neon.h>
static inline int32x4_t kt_cvtnq_s32_f32(float32x4_t x) {
  // x + 0.5 with x's sign, then toward zero
  uint32x4_t sign = vandq_u32(vreinterpretq_u32_f32(x), vdupq_n_u32(0x80000000u));
  float32x4_t half = vreinterpretq_f32_u32(vorrq_u32(sign, vreinterpretq_u32_f32(vdupq_n_f32(0.5f))));
  return vcvtq_s32_f32(vaddq_f32(x, half));
}
#define vcvtnq_s32_f32(x) kt_cvtnq_s32_f32(x)
#endif
#endif
