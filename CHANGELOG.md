# Changelog

All notable changes to GMPMEE are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

---

## [3.0.0] - 2026-04-06

### ⚠ ABI BREAK — action required for downstream consumers

This release contains ABI-incompatible changes. Shared library consumers
**must** recompile against the new headers and relink against the new library.

The shared library SOVERSION has been incremented from 0 to 1:

| Platform | Before     | After      |
|----------|------------|------------|
| Linux    | libgmpmee.so.0 | libgmpmee.so.1 |
| Windows  | libgmpmee-0.dll | libgmpmee-1.dll |

The libtool version-info is now `1:0:0` (CURRENT:REVISION:AGE).

#### Why this is an ABI break

On platforms where `unsigned long int` is 32 bits (Windows 64-bit, Linux 32-bit),
the `uint64_t` replacement widens the involved struct field and function
parameter from 4 bytes to 8 bytes, changing both the struct memory layout
and the function calling convention.

On 64-bit Linux, `unsigned long int` and `uint64_t` are both 64 bits, so
there is no layout change. However, the signature change is visible in the
object file ABI and callers must still be recompiled.

### Changed

- `gmpmee_millerrabin_state.k` field type changed from `unsigned long int`
  to `uint64_t` (struct layout change on 32-bit and Windows platforms).
  Callers that read or write this field directly must be updated.

- `gmpmee_array_urandomb` parameter `n` type changed from `unsigned long int`
  to `uint64_t`. Callers passing values wider than 32 bits on Windows or
  32-bit Linux now work correctly.

### Fixed

- **[Security/Safety]** Null pointer dereference on allocation failure.
  `gmpmee_array_alloc` and `gmpmee_spowm_init` previously used `malloc`
  results without checking for NULL. Under memory pressure, subsequent
  writes through the null-backed pointer caused undefined behavior (heap
  corruption or crash). All allocation sites now call `abort()` immediately
  on NULL, giving a deterministic failure instead of silent corruption.
  This is consistent with GMP's own allocation strategy.
  Affected files: `array_alloc.c`, `spowm_init.c`.

- **[Safety]** Shift-width and integer-overflow undefined behavior in table
  sizing and mask arithmetic. Expressions of the form `1 << block_width` and
  `1 << w` used a signed 32-bit `int` literal `1`. Per C11 §6.5.7¶4, this
  is undefined behavior when the shift count reaches or exceeds 32, or when
  bit 31 is set (signed overflow). The `theoretical_block_width` loop iterated
  up to `w = 49`, which is always UB regardless of input.
  All shifts now use `(size_t)1 <<` to match the width of the result type.
  Mask accumulator variables in `getbits` functions changed from `int` to
  `unsigned int` to avoid signed left-shift UB. Width guards (`abort()` on
  `block_width >= CHAR_BIT * sizeof(size_t)`) were added at each shift site.
  Affected files: `spowm_init.c`, `spowm_clear.c`, `spowm_precomp.c`,
  `spowm.c`, `spowm_table.c`, `fpowm.c`.

### Build system

- Added `EXEEXT` suffix to the `extract_GMP_CFLAGS` helper binary name so
  that Windows cross-builds produce `extract_GMP_CFLAGS.exe` instead of a
  bare binary that Windows cannot execute.

- Added `${srcdir}` prefix to the helper source path in `configure.ac` so
  that out-of-tree builds can locate `extract_GMP_CFLAGS.c`.

- Added `-no-undefined` linker flag to `libgmpmee_la_LDFLAGS`. This is
  required by the Windows PE/DLL format and allows `libtool` to produce a
  working import library (`libgmpmee.dll.a`).

- Declared generated trial-division files as `BUILT_SOURCES` and added
  explicit `.lo` dependencies (`millerrabin_trial.lo`,
  `millerrabin_safe_trial.lo`) to guarantee correct parallel-build ordering.

---

## [2.1.0]

Internal release by Douglas Wikström. No structured changelog was maintained.

---

## [2.0.1] - 2016-05-18

Internal release by Douglas Wikström.

---

## [2.0.0] - 2016-05-16

Internal release by Douglas Wikström.

---

## [0.1.0] - 2009-06-15

Initial release.
