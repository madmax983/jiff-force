# The oracle

A small Rust program that runs the real Jiff crate, pinned to the release this port tracks
(`jiff = "=1.0.0"`), and records what it does as golden vectors. The vectors are written as
Apex data classes, `JiffOracle*Data.cls`, and hand written Apex tests, `JiffOracle*Test.cls`,
replay every row against the port. That makes Jiff itself the judge of the port, instead of
anyone's reading of Jiff.

```bash
npm run oracle     # regenerate every data class, then format them
```

Regenerating is deterministic: the same sources always produce byte for byte the same classes.
Each topic draws its random cases from a stream seeded by the topic's name, so changing one
topic leaves the vectors of all the others alone. (The first three topics, `Date`, `Duration`
and `DurationRound`, predate that and share one stream.)

## What a row looks like

A row is a line of fields separated by `|`. The header comment of each data class names its
columns. Values are written the same way everywhere (`src/text.rs` on this side,
`JiffOracleSupport.cls` on the Apex side):

| Value | Written as | Example |
| --- | --- | --- |
| an error from Jiff | `ERR` | `ERR` |
| span | its non-zero units, each with its own sign, or `0` | `-1y -2mo`, `90m 500ms` |
| signed duration, timestamp | `seconds,nanoseconds` | `-1,-500000000` |
| date, time, datetime | ISO 8601, as Jiff prints it | `-009999-01-01`, `23:59:59.5` |
| offset | seconds east of UTC | `-18000` |
| weekday | days after Monday | `6` |
| ISO week date | `year,week,weekday` | `2020,53,3` |
| unit, rounding mode | the Apex enum constant | `MILLISECOND`, `HALF_EVEN` |
| the empty string, as a parser input | `<empty>` | `<empty>` |

The Apex readers build each value with plain constructors and setters, never with the port's
own parsers, so a row means the same thing whether or not the code under test is right.

Every topic mixes cases listed by hand (the limits of each range, leap days, month ends, ties
when rounding, inputs that must be rejected) with seeded random cases.

## Topics

| Data class suffix | What it pins down |
| --- | --- |
| `Date` | construction, epoch days, weekday, day of year, printing |
| `DateSpan`, `DateDuration` | adding and subtracting spans and durations, checked and saturating |
| `DateDifference` | `until` and `since` for each largest unit, `durationUntil` |
| `DateCalendar` | day of year, first and last of month and year, tomorrow and yesterday, date to ISO week date, era |
| `DateWeekday` | `nthWeekday`, `nthWeekdayOfMonth` |
| `IsoWeekDate` | ISO week date to date, weeks in the year, neighbouring week dates |
| `DateWith`, `TimeWith` | the `with` builders |
| `TimeSpan`, `TimeDuration` | checked, wrapping and saturating arithmetic |
| `TimeDifference` | `until` and `since` for each largest unit |
| `TimeRound` | rounding for every unit, increment and mode |
| `SpanIso`, `SpanFriendly` | printing in both formats and reading the result back |
| `SpanFriendlyConfig`, `DurationFriendlyConfig` | the friendly printer under a spread of configurations |
| `SpanParseIso`, `SpanParseFriendly`, `DurationParseIso`, `DurationParseFriendly` | each of the three parsers on good and bad input |
| `SpanMultiply`, `SpanSetter` | multiplication and the sign rules of the setters |
| `Duration`, `DurationRound`, `DurationText` | signed duration arithmetic, rounding, printing |
| `Timestamp` | construction from each unit, and the accessors |
| `TimestampSpan`, `TimestampDuration`, `TimestampDifference`, `TimestampRound`, `TimestampText` | arithmetic, differences, rounding, printing with and without an offset |
| `Offset`, `OffsetArithmetic`, `OffsetRound` | construction, printing, arithmetic, rounding |
| `TimeZoneAmericas`, `TimeZoneEurope`, `TimeZonePacific` | every change of offset in six zones from 1970 through 2037: the offset either side, and civil datetimes in and around the gap or fold |
| `TimeZoneOffset`, `TimeZoneCivil` | ordinary instants and civil datetimes in nine zones |
| `SpanRound`, `SpanTotal`, `SpanCompare`, `SpanArithmetic` | span rounding, totals, comparison and arithmetic with no reference, with days taken as 24 hours, or relative to a date, a datetime or a zoned datetime (written `-`, `24h`, `D:<date>`, `DT:<datetime>`, `Z:<zone>:<instant>`) |
| `DifferenceRound` | `until` and `since` with a largest unit, a smallest unit, an increment and a mode, for dates, datetimes, timestamps and zoned datetimes |
| `StrtimeFormat`, `StrtimeParse` | `strftime` with every directive and flag on dates, times, datetimes, timestamps and zoned datetimes, and `strptime` into each, on good and damaged input (`%Z` only where the platform and Jiff agree on abbreviations) |
| `Rfc2822Parse`, `Rfc2822Print` | RFC 2822 parsing into zoned datetimes and timestamps, and RFC 2822 / RFC 9110 printing |
| `ZonedSpan`, `ZonedDifference`, `ZonedRound`, `ZonedCalendar` | zoned datetime arithmetic, `until` for six largest units, rounding (including days of 23 and 25 hours), and the start/end of day, tomorrow/yesterday and month-end helpers, with inputs crowded within 36 hours of every change of offset |

### Time zones

Jiff reads its bundled copy of the time zone database (the `tzdb-bundle-always` feature, so
never the host's). The port asks the platform it runs on. The time zone vectors therefore hold
only where the two agree, and are limited to nine well known zones and to 1970 through 2037,
where every rule has been settled for years. If a platform's zone data ever disagrees with a
vector, the right response is to find out which side is out of date, not to edit the vector.

## Adding a topic

1. Write a function `fn rows(rng: &mut Rng) -> Result<Vec<String>>` in the module the topic
   belongs to, with a `COLUMNS` description beside it. Use the writers in `text.rs` and build
   rows with `text::row`. Record errors as `ERR`; never skip an input because Jiff rejects it.
2. Add it to the table in `main.rs`.
3. `npm run oracle`, then write the Apex test that replays the new data class. Keep a test
   method to a few hundred rows.

If a vector disagrees with the port, the port is wrong until proven otherwise. Never adjust a
vector to make a test pass.

The crate is held to the same standard as the rest of the repository: `cargo fmt`,
`cargo clippy --all-targets` clean under the pedantic and nursery lints, `cargo test`, and no
`unwrap` outside tests.
