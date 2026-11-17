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
- **Civil time to instant**: probe `getOffset` on either side of the civil time, treated as if it
  were UTC, to find the candidate offsets, and classify the result as unambiguous, a gap or a
  fold. This yields the same `AmbiguousOffset` Jiff computes, and the same four disambiguation
  strategies apply.
- **Transitions**: found by scanning `getOffset` and bisecting to the second.
- **Abbreviation**: `Datetime.format('z', zoneId)`.
- **DST flag**: inferred from the offset relative to the zone's standard offset.
- **Unknown zone names**: the platform silently returns GMT, so `JiffTimeZone.get` detects that
  and throws.

`JiffTimeZone.userTimeZone()` (the running user's zone) takes the place of Jiff's system zone.

## Consequences

- No static resource, no SOQL, and zone data that is always as current as the platform's and
  always agrees with `Datetime`.
- Results depend on the zone data release the platform ships, so they can differ from a given
  Jiff build for recent or far-past rule changes. Tests use well-known zones and dates from 1970
  onward.
- A transition that changes only an abbreviation or the DST flag, with no change of offset, is
  invisible. The inferred DST flag can differ from the database for zones with unusual rules.
- POSIX TZ strings and TZif input (`TimeZone::posix`, `TimeZone::tzif`) are not provided.
- Finding a transition costs a bounded number of `getOffset` calls rather than a table lookup.
- The time zone type hides its backend behind Jiff's interface, so a bundled database could be
  added later without changing callers.
