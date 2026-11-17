# 3. Back time zones with the platform's zone data

Date: 2026-11-17

## Status

Accepted

## Context

Jiff embeds a copy of the IANA Time Zone Database, parses TZif and POSIX TZ strings itself, and
answers every time zone question from that data: the offset at an instant, the offsets a civil
time could map to, abbreviations, the DST flag, and the neighbouring transitions.

On Salesforce the choices are:

1. **Bundle the database** as a static resource and port the TZif and POSIX parsers. This is
   faithful and deterministic, but it costs a SOQL query and blob-to-hex parsing per transaction,
   needs a release every time the database changes, and gives answers that can disagree with
   every other datetime on the platform.
2. **Delegate to the platform.** `System.TimeZone.getOffset(Datetime)` returns the offset in
   effect at any instant for any IANA zone, using zone data Salesforce maintains. Nothing else is
   exposed: no transition list, no DST flag, and no way to resolve a civil time.

## Decision

Delegate to the platform, and derive everything else from `getOffset`:

- **Offset at an instant**: `getOffset` directly.
- **Civil time to instant**: probe `getOffset` 24 hours either side of the civil time, treated as
  if it were UTC, to find the candidate offsets, verify each candidate, and classify the result
  as unambiguous, a gap or a fold. This yields the same `AmbiguousOffset` Jiff computes, and the
  same four disambiguation strategies apply. It is exact unless a zone changes offset twice
  within 48 hours.
- **Transitions**: `previousTransition` / `nextTransition` scan `getOffset` in six day steps and
  bisect to the second. Six days is safe: the shortest there-and-back change in the IANA
  database is 6.96 days. The search covers 1800 through 2100.
- **Abbreviation**: `Datetime.format('z', zoneId)`, with the platform's `GMT+hh:mm` fallback
  rewritten to the database's numeric style (`+13`, `+0545`).
- **DST flag**: inferred. An instant is in DST when the offset 13 or 26 weeks either side of it
  is lower by at most two hours.
- **Unknown zone names**: the platform silently returns GMT, so `JiffTimeZone.get` detects that
  and throws. Names are case sensitive, as the platform cannot canonicalise them.

`JiffTimeZone.userTimeZone()` (the running user's zone) takes the place of Jiff's system zone.

## Consequences

- No static resource, no SOQL, and zone data that is always as current as the platform's and
  always agrees with `Datetime`.
- Results depend on the zone data release the platform ships, so they can differ from a given
  Jiff build for recent or far-past rule changes. Tests use well-known zones and dates from 1970
  onward.
- A transition that changes only an abbreviation or the DST flag, with no change of offset, is
  invisible.
- The inferred DST flag differs from the database for year-round DST (US "War Time"), for the
  26 weeks after a permanent forward shift of two hours or less (Moscow, 2011), for standard
  periods shorter than 13 weeks, and for zone data in the "negative DST" form.
- Abbreviations are platform locale data and can differ from the database's (`BRT` versus
  `-03`), and time zone aliases are not resolved to a primary name.
- Offsets before roughly 1900 differ between runtimes (local mean time versus the first standard
  offset), so behaviour there should not be relied on.
- A zone with no transitions makes `nextTransition` scan its whole search window: on the order
  of 18,000 `getOffset` calls.
- POSIX TZ strings and TZif input (`TimeZone::posix`, `TimeZone::tzif`) are not provided.
- Finding a transition costs a bounded number of `getOffset` calls rather than a table lookup.
- The time zone type hides its backend behind Jiff's interface, so a bundled database could be
  added later without changing callers.
