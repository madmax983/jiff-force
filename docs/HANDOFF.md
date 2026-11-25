# Handoff: jiff-force

State of the port as of 2026-11-25. Everything here is on branch `claude/focused-einstein-lxjnw2`
([PR 2](https://github.com/madmax983/jiff-force/pull/2)); the first round of work is on `main`
([PR 1](https://github.com/madmax983/jiff-force/pull/1)).

Read `CLAUDE.md` first: it has the Apex subset rules, the naming rules and the testing rules.
The ADRs in `docs/adr/` explain the main design decisions.

## Where things stand

Every area of Jiff 1.0.0 that makes sense on the platform is ported, and there is a bridge to
Salesforce record fields. 1,353 tests pass on the JVM harness (`npm test`), and every test class
passes on AER when run one class at a time.

| Area | How it was checked |
| --- | --- |
| Units, rounding, `JiffI128`, `JiffMath`, `JiffSignedDuration`, `JiffSpan` data | Jiff's own tests, oracle vectors (incl. every rounding tie), adversarial review |
| `JiffDate`, `JiffTime`, `JiffDateTime`, `JiffIsoWeekDate` | Oracle vectors; `JiffDateTime` also by a ~104,000-case differential run |
| `JiffTimestamp`, `JiffOffset`, `JiffTimeZone` | Oracle vectors for nine zones, 1970–2037 |
| `JiffZonedDateTime`, `parse` | 2,364 oracle vectors crowded around every change of offset |
| Span `round`/`total`/`compare`/relative arithmetic, `until`/`since` with `JiffDifference` | 2,180 oracle vectors, totals bit for bit |
| ISO 8601 / RFC 9557 parsing and printing, friendly durations | Jiff's snapshot cases and oracle vectors |
| `strftime`/`strptime`, RFC 2822 / RFC 9110 | 1,200 oracle vectors plus Jiff's snapshot cases |
| Platform `Date`/`Time`/`Datetime` conversion, `JiffRecords` | AER under `en_US`, `th_TH`, `de_DE`, `ar_EG` in several zones; CI runs the record tests in `en_US` and `th_TH` |

"Oracle vectors" are rows recorded from the real Jiff crate by `oracle/` (`npm run oracle`) and
replayed by the `JiffOracle*Test` classes. The porters' own tests also embed vectors from Jiff
(`JiffSpanArithmeticVectors` and friends); their generators were throwaway programs and are not
in the repo, so those tables cannot be regenerated. The oracle topics cover the same behaviour
reproducibly.

## What is left

1. **Compile on a real org.** Nothing has run on Salesforce itself. Add an `SFDX_AUTH_URL`
   repository secret and the CI `org` job validates a deployment and runs every test. Expect a
   few surprises where the platform differs from both local runners; the most likely places are
   CPU limits on the large vector classes and the `Long` comparison behaviour noted below.
2. **Open harness findings** (`docs/handoff/foundation-review-findings.md`, numbers 15, 16 and
   21–28). They are cases where the JVM harness would accept Apex that behaves differently on a
   real runtime. AER runs every class independently, so none can hide a library bug on its own;
   they matter only if the harness is used without AER. Everything else in that file is fixed
   (finding 4 was not applicable: Apex has no `SystemTime`).
3. **Optional polish.** Measure CPU and heap for common operations in an org; consider a bulk
   API for triggers (for example converting a list of records at once) if measurements show the
   per-call cost matters.

## Decisions waiting on the project owner

- **AER licence.** The free tier runs at most 100 test methods per invocation; the suite has
  over 1,300. CI runs the full AER suite only when an `AER_LICENSE_KEY` secret exists; without it,
  it runs the record tests, which need no licence.
- **Two Jiff bugs reproduced on purpose.** The port matches Jiff exactly, including:
  - `DateTime::round` multiplies the carried day by the sign of the year, so rounding is wrong
    for years 0 and below (pinned in `JiffDateTimeRoundTest`).
  - `Nudge::relative_zoned_time` adds a spilled day as +1 whatever the span's sign, so rounding a
    negative span relative to a zoned datetime can be off by a day (pinned in
    `JiffSpanRoundTest`).

  Either can be "fixed" with a one-line change; both are worth reporting upstream.

## Things worth reporting upstream

- **AER 1.7.3**: `<`, `>`, `<=`, `>=` on `Long` go through a 64 bit float, so
  `9223372036854775807L > 9223372036854775806L` is false. The library works around it with
  `JiffMath.compare`.
- **AER 1.7.3**: rejects `System.Integer` as a type name.
- **Jiff 1.0.0**: the two rounding bugs above.

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
- AER is installed separately (release zip from `octoberswimmer/aer-dist`; v1.7.3 was used).
- Before each commit: `npm run meta && npm run fmt && npm test`, then AER on the classes touched.
  Interop changes also need `--locale th_TH --timezone Asia/Bangkok` on AER.

### What worked

- One porter per module, working from the Jiff source and `CLAUDE.md`.
- Recording vectors from real Jiff in `oracle/` *before* or alongside the port, then replaying
  them with an independent driver. Every disagreement so far was either a port bug or a vector
  that strayed outside the period where the platform's zone data and Jiff's agree.
- Running AER under unusual locales: it found the Buddhist calendar bug no unit test would have.

Broad multi-agent review passes were expensive and found mostly harness gaps and edge cases.
