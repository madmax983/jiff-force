# Handoff: jiff-force

State of the port at the point work was paused (2026-11-17), and what to do next. Everything
described as merged is on branch `claude/focused-einstein-lxjnw2`, in
[PR 1](https://github.com/madmax983/jiff-force/pull/1).

Read `CLAUDE.md` first: it has the Apex subset rules, the naming rules and the testing rules.
The ADRs in `docs/adr/` explain the main design decisions.

## Where things stand

1,115 tests pass on the JVM harness (`npm test`), and every test class passes on AER when run one
class at a time. 63 library classes, 66 test classes.

| Area | State | How well verified |
| --- | --- | --- |
| Units, rounding, `JiffI128`, `JiffMath` | Merged | Tests + oracle vectors + adversarial review (findings open, see below) |
| `JiffSignedDuration`, `JiffSpan` data model | Merged | Same |
| `JiffDate`, `JiffTime`, `JiffIsoWeekDate`, `JiffWeekdays` | Merged | Porter's tests with values from Jiff |
| `JiffDateTime` | Merged | Differential test of ~104,000 cases against real Jiff, 0 mismatches; review findings fixed |
| `JiffTimestamp`, `JiffOffset`, `JiffTimeZone`, ambiguity types | Merged | Porter's tests with values from Jiff; no independent review |
| ISO 8601 duration parsing, friendly duration format | Merged | Porter's tests (Jiff's snapshot cases); no independent review |
| ISO 8601 / RFC 9557 datetime parsing, printer options, `JiffPieces` | Merged | Built, reviewed two ways, fixes committed; the fixer's final report was not collected |
| `JiffZonedDateTime`, `JiffAmbiguousZonedDateTime`, `JiffOffsetConflicts` | Merged | **Porter's tests only.** Independent verification was started and stopped |
| Oracle expansion (`oracle/`, `JiffOracle*`) | Merged | **Generator not independently reviewed.** `npm run oracle:check` passes |
| Platform interop (`fromSystem*` / `toSystem*`) | Merged per type | See "Record interop" below; one known locale bug |

## What is left, in dependency order

1. **Fix the foundation review findings.** `docs/handoff/foundation-review-findings.md` lists 39
   confirmed findings with reproduction notes and fixes. None is fixed. The ones that matter most:
   - 29: platform `Date` conversion is wrong under a non-Gregorian user locale (for example
     `th_TH`). Route every `fromSystem*` / `toSystem*` through locale-neutral values (epoch
     milliseconds) and make all of them null in, null out. `JiffDate.fromSystemDate` and
     `JiffTime.fromSystemTime` currently throw on null.
   - 0, 1, 9, 12: `JiffSignedDuration.fromSecsDouble` accepts NaN and mishandles values at 2^63.
   - 5, 11: `JiffSpan.fromInvariantDuration` wraps instead of throwing for extreme durations.
   - 15 to 28: gaps in the JVM harness's fidelity. AER catches most of these independently.
2. **Verify `JiffZonedDateTime`.** Run a differential test against real Jiff concentrated around
   DST transitions (the approach that worked for `JiffDateTime`), and review `equals`,
   `until`/`since` for calendar units, and rounding on 23 and 25 hour days.
3. **Span operations that need a reference date**: `JiffSpan.add`/`subtract` with another span,
   `compare`, `total`, `round` (with a new `JiffSpanRound` options class and a `JiffSpanRelativeTo`),
   and `toDuration`. Source: `jiff-1.0.0/src/span.rs`. This is the largest remaining piece.
4. **`until`/`since` with `JiffDifference`** on `JiffDate`, `JiffTime`, `JiffDateTime`,
   `JiffTimestamp` and `JiffZonedDateTime`. Each type already exposes the unrounded computation
   as `until(other, JiffUnit largest)`; the overload calls that and then `JiffSpan.round` relative
   to the receiver, as Jiff does. Needs item 3.
5. **`JiffZonedDateTime.parse`** and a zoned printer in `JiffTemporal`, on top of `JiffPieces`
   and `JiffOffsetConflicts.resolve`.
6. **`strftime` / `strptime`** (`jiff-1.0.0/src/fmt/strtime/`) and **RFC 2822**
   (`fmt/rfc2822.rs`). Neither is started.
7. **Record interop** (requested by the project owner; "otherwise it isn't much use"):
   - Value conversions exist on `JiffDate`, `JiffTime`, `JiffTimestamp`, `JiffDateTime` (with a
     zone) and `JiffZonedDateTime`. Fix them per finding 29 first.
   - Not started: a `JiffRecords` helper for dynamic access, for example
     `JiffRecords.getDate(record, Opportunity.CloseDate)` and matching `put` methods, by field
     token or name. It touches `SObject`, which the JVM harness does not model, so test it under
     AER only and exclude it from the harness.
   - Add a "Working with records" section to the README.
8. **Oracle follow-ups**: findings 32 and 33 (the date driver never asserts the day-of-year
   column; rounding vectors rarely land on a tie), then vectors for zoned datetimes and spans.
9. **Finish the docs**: README status table and API examples, PR description, a short ADR for
   record interop.

## Decisions waiting on the project owner

- **AER licence.** The free tier runs at most 100 test methods per invocation and the suite has
  over 1,100. Locally, run one class at a time (`npm run test:aer -- -f JiffDateTest`). The AER CI
  job is a no-op until an `AER_LICENSE_KEY` repository secret exists. With a key, the JVM harness
  (`tools/apexjvm`) could be retired.
- **A real org.** No Salesforce org has compiled this code. The CI `org` job runs when an
  `SFDX_AUTH_URL` secret exists.
- **A Jiff bug reproduced on purpose.** Jiff 1.0.0 multiplies the day carried by
  `DateTime::round` by the sign of the year, so rounding is wrong for years 0 and below. The port
  matches Jiff and pins it in `JiffDateTimeRoundTest`. Removing one line in `JiffDateTime.round`
  gives the mathematically expected result.

## Things worth reporting upstream

- **AER 1.7.3**: `<`, `>`, `<=`, `>=` on `Long` go through a 64 bit float, so
  `9223372036854775807L > 9223372036854775806L` is false. The library works around it with
  `JiffMath.compare`.
- **AER 1.7.3**: rejects `System.Integer` as a type name.
- **Jiff 1.0.0**: the `DateTime::round` year-sign bug above.

## How to work on it

```bash
npm install
```

```bash
npm test
```

```bash
npm run test:aer -- -f JiffZonedDateTimeTest
```

```bash
npm run oracle:check
```

- The Jiff source is the specification: `cd oracle && cargo fetch`, then read
  `~/.cargo/registry/src/*/jiff-1.0.0/src`.
- AER is installed separately (release zip from `octoberswimmer/aer-dist`, v1.7.3 was used).
- Before each commit: `npm run meta && npm run fmt && npm test`, then AER on the classes touched.

### Keeping the cost down

Most of the usage in the first session went to one broad review (85 agents). What gave the most
confidence per unit of effort was much narrower:

- One porter per module, working from the Jiff source with the conventions in `CLAUDE.md`.
- One differential test per module: a small Rust program prints a few thousand cases from real
  Jiff, and the same cases are replayed through the port with `aer exec`.
- Fold any vectors worth keeping into `oracle/` so they can be regenerated.

Broad multi-reviewer passes found mostly edge cases and harness gaps; save them for the end.
