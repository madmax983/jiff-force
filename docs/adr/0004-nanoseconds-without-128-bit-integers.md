# 4. Represent nanosecond totals without 128 bit integers

Date: 2026-11-17

## Status

Accepted

## Context

Jiff's range is the years -9999 through 9999 at nanosecond precision. A count of nanoseconds over
that range needs about 69 bits, and a `SignedDuration` (an `i64` of seconds plus nanoseconds)
needs 94. Jiff does its rounding and duration arithmetic on `i128`.

Apex's largest integer is a 64 bit `Long`, which holds about 292 years of nanoseconds. `Decimal`
is arbitrary precision, but it has no `add`/`multiply` methods (only operators), its division
rounds to a context dependent scale, and it cannot be modelled faithfully by the test harness.

## Decision

- Instants and durations are stored as a pair, never as one nanosecond count:
  `(Long seconds, Integer nanoseconds)`. Time of day is nanoseconds since midnight, which fits in
  a `Long` with room to spare.
- Where a single wide number is unavoidable (rounding a duration to an increment, converting
  between a duration and a nanosecond total), use `JiffI128`: a small immutable integer stored as
  `hi * 10^18 + lo`, bounded at 10^35, with add, subtract, multiply by a `Long`, truncating
  division, comparison and parity. Values that fit a `Long` take a fast path.
- All arithmetic that can overflow is checked before it is performed (`JiffMath.checkedAdd` and
  friends). Nothing depends on wrap-around.
- `Decimal` is not used anywhere. Floating point (`Double`) appears only where Jiff's API is
  itself floating point (`as_secs_f64`, `Span::total`).
- Jiff methods that return `i128` (`as_millis`, `as_nanos`) return `Long` and throw when the value
  does not fit, with an `...I128` variant for internal use.

## Consequences

- Results match Jiff exactly across the whole range, verified against arbitrary precision
  vectors.
- The slow path of `JiffI128` division is digit-by-digit and costs a few thousand operations. It
  is reached only for values beyond roughly 292 years of nanoseconds.
- Public methods returning nanosecond totals can throw where Jiff's cannot.
