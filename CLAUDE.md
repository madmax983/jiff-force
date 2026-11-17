# jiff-force

A port of [Jiff](https://github.com/BurntSushi/jiff) (Rust, v1.0.0) to Salesforce Apex: civil
dates and times, nanosecond timestamps, time zone aware datetimes, calendar-aware spans, rounding,
and ISO 8601 / RFC 9557 / RFC 2822 / strftime formatting.

## Layout

| Path | What |
| --- | --- |
| `force-app/main/default/classes/` | The library. Every class is `Jiff*`; tests are `Jiff*Test`. |
| `tools/apexjvm/` | Local test harness: translates the Apex to Java and runs the tests on the JVM. |
| `oracle/` | Rust crate pinned to `jiff = "=1.0.0"` that generates golden test vectors. |
| `docs/adr/` | Architecture decision records. |

The Jiff source is the specification. Get it with `cd oracle && cargo fetch`; it lands in
`~/.cargo/registry/src/*/jiff-1.0.0/` (plus `jiff-core-1.0.0/` for the low level algorithms).

## Commands

```bash
npm install                 # once
npm test                    # translate + compile + run every Apex test locally (~1s)
npm test -- --filter JiffDate          # only tests whose Class.method contains the text
npm run fmt                 # prettier-plugin-apex; also the only check that uses Salesforce's real parser
npm run fmt:check
npm run meta                # create missing *.cls-meta.xml files
npm run test:coverage       # line coverage via JaCoCo, gate at 85%
```

Before every commit: `npm run meta && npm run fmt && npm test`.

There is no Salesforce org wired into this repo's local loop. `npm test` is the red/green loop.
A real org is the final authority; see `docs/adr/0002-local-jvm-test-harness.md`.

## The Apex subset (enforced by the harness)

The harness translates Apex to Java, so the library is written in a disciplined subset of Apex.
The translator rejects anything outside it. The rules exist because of real differences between
Apex and Java; do not work around them.

1. **`Integer`, `Long`, `Boolean`, `Double` are never null.** They become Java primitives.
   - Fields of these types must be `final` or have an initializer.
   - When a value genuinely needs to be nullable, spell the type `System.Integer` /
     `System.Long` / `System.Boolean` / `System.Double`. Use this sparingly.
   - Collections hold boxed values as usual: `List<Long>`, `Map<String, Integer>`.
2. **Write `L` on Long literals** that go into a `List<Long>` or a `Long` varargs-like position:
   `new List<Long>{ 1L, 2L }`. Plain `Long x = 5;` is fine.
3. **No overflow reliance.** Use `JiffMath.checkedAdd/checkedSub/checkedMul/checkedNeg` whenever
   an operation could overflow. Never depend on wrap-around.
4. **Division truncates toward zero; `Math.mod` takes the dividend's sign.** For floor semantics
   use `JiffMath.floorDiv` / `JiffMath.floorMod`. Prefer `JiffMath.truncMod` over `Math.mod`.
5. **Strings: compare with `.equals()`** (case sensitive). `==` on strings is case-insensitive in
   Apex; use it only when you mean that.
6. **Objects: compare with `.equals()`.** `==` on two jiff-force objects is rejected at runtime
   by the harness. `==` is fine for primitives, enums and `null` checks.
7. **No reserved words as names.** Apex reserves many ordinary words: `date`, `time`, `of`,
   `on`, `in`, `from`, `end`, `begin`, `limit`, `list`, `map`, `set`, `sort`, `any`, `as`, `by`,
   `default`, `number`, `object`, `group`, `like`, `not`, `and`, `or`, `system`, `package`, ...
   The harness knows the full list and fails the build.
8. **No properties** (`{ get; set; }`), no arrays (`Integer[]`), no `?.`, no `??`, no SOQL/DML,
   no `switch on` over a `Long`, no type-pattern `when` clauses.
9. **`Decimal` is not used.** A bare `0.5` literal is a Decimal in Apex; assign it to a `Double`
   variable first and do arithmetic on the variable.
10. **Only call system methods the harness shims** (`tools/apexjvm/runtime/jiffapex/`). The
    shims expose methods that really exist in Apex with the same signature. If you need another
    system method, add it to the shim *only if you are certain of its Apex behaviour*, and add a
    case to `JiffHarnessTest` pinning that behaviour.
    - String instance methods routed by name (do not name your own methods any of these):
      `leftPad rightPad left right mid charAt getChars split repeat reverse isNumeric
      containsIgnoreCase substringBefore substringAfter removeStart removeEnd intValue
      longValue doubleValue`.
    - Java-only String methods (`isEmpty()`, `strip()`, `matches()`, ...) are rejected.
11. **Inner classes cannot have static members** (an Apex rule). Use top-level classes.
12. **Exceptions:** throw only `JiffException`. Never catch platform exceptions as control flow
    (validate input first, e.g. check digits before `Integer.valueOf`).
13. **Immutability:** every value type is immutable. Private fields, no setters; "setters"
    return a new instance.
14. `equals` and `hashCode` are declared without `override`; `toString` is declared
    `public override String toString()`.

When the harness reports a compile error it points at the `.cls` file and line.

## API conventions (how Jiff names map to Apex)

- Types: `jiff::civil::Date` → `JiffDate`, `Time` → `JiffTime`, `DateTime` → `JiffDateTime`,
  `ISOWeekDate` → `JiffIsoWeekDate`, `Weekday` → `JiffWeekday` (enum) + `JiffWeekdays` (statics),
  `Timestamp` → `JiffTimestamp`, `ZonedDateTime` → `JiffZonedDateTime`, `Span` → `JiffSpan`,
  `SignedDuration` → `JiffSignedDuration`, `tz::TimeZone` → `JiffTimeZone`,
  `tz::Offset` → `JiffOffset`, `Unit` → `JiffUnit`, `RoundMode` → `JiffRoundMode`,
  `Error` → `JiffException`.
- Methods are the camelCase of Jiff's snake_case, with these systematic changes:
  - `Type::new(...)` → `Type.newInstance(...)` (`new` and `of` are reserved; this is the Apex
    idiom). `Span::new()` is `new JiffSpan()`.
  - `checked_add` / `checked_sub` → `add` / `subtract` (they throw `JiffException`; there is no
    unchecked variant). `saturating_*` and `wrapping_*` keep their prefix.
  - `checked_mul` → `multiply`, `checked_div` → `divide`, `checked_neg` → `negate`.
  - `date()` / `time()` / `datetime()` / `timestamp()` accessors → `toDate()` / `toTime()` /
    `toDateTime()` / `toTimestamp()` (`date` and `time` are reserved).
  - `str.parse::<T>()` → `T.parse(String)`; `Display` → `toString()`.
  - Comparison operators → `compareTo(Object)` (all ordered types implement `Comparable`),
    `equals`, `hashCode`, plus `isBefore(other)` / `isAfter(other)`.
  - `Result<T, Error>` → return `T` or throw `JiffException`. `Option<T>` → nullable return.
  - `try_x` variants are dropped (the plain method already throws).
- Option structs are shared instead of one per type:
  `JiffRound` (smallest/mode/increment) for all rounding except spans, `JiffDifference`
  (smallest/largest/mode/increment) for all `until`/`since`, `JiffSpanRound` for span rounding.
  The other operand is a separate argument: `a.until(b, options)`.
- Interop with platform types uses the word `System`: `JiffDate.fromSystemDate(Date)`,
  `toSystemDate()`, `JiffTimestamp.fromSystemDatetime(Datetime)`, `toSystemDatetime()`.
- Integer-like civil fields (year, month, day, hour, ...) are `Integer`. Span units, seconds
  since the epoch and other potentially large counts are `Long`.
- Error messages follow Jiff's wording where practical, e.g.
  `parameter 'day' is not in the required range of 1..=31`.
- Every public class and public method has a doc comment. Class comments end with
  "Mirrors `jiff::...`" naming the Jiff item ported.

## Shared internals (use these; do not reimplement)

- `JiffMath`: checked arithmetic, floor/trunc division, range checks with Jiff's error wording,
  unit lengths (`nanosPerUnit`), unit names (`singular`/`plural`), zero padding.
- `JiffI128`: wide integer for nanosecond totals that exceed a `Long` (about ±292 years).
- `JiffRounding`: increment validation per type and `round` / `roundLong` / `roundDuration`.
- `JiffSpan` data helpers: `get`/`getAbs`/`withUnit`, `largestUnit`, `onlyCalendar`/`onlyTime`,
  `toInvariantDuration`, `fromInvariantDuration`.
- `JiffTemporal`: ISO 8601 / RFC 9557 printing and parsing shared by `toString()`/`parse()`.

## Testing rules

- No behaviour without a test. Each class `JiffX` has `JiffXTest`.
- Expected values come from Jiff, not from the port: use the examples in Jiff's doc comments
  and the assertions in its `#[cfg(test)]` modules (they are in the fetched source), or vectors
  from `oracle/`. Do not compute an expected value with the code under test.
- Test names say what is true: `addingAMonthClampsToTheLastDay`, not `testAdd1`.
- Assert with `Assert.areEqual(expected, actual[, message])` and friends. Expected-failure
  pattern:

  ```apex
  try {
      JiffDate.newInstance(2023, 2, 29);
      Assert.fail('expected an invalid date to be rejected');
  } catch (JiffException e) {
      Assert.isTrue(e.getMessage().contains('day'), e.getMessage());
  }
  ```

- `Assert.areEqual` is strict about types in the harness: `Assert.areEqual(5L, x)` for a
  `Long`, `Assert.areEqual(5, x)` for an `Integer`.
- Time zone tests should use well-known zones and dates from 1970 onward so they do not depend
  on which tz database release the platform ships.
