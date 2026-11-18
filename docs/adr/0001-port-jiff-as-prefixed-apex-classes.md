# 1. Port Jiff 1.0.0 as `Jiff`-prefixed Apex classes

Date: 2026-11-17

## Status

Accepted

## Context

Jiff is a Rust datetime library organised into modules (`jiff::civil`, `jiff::tz`, `jiff::fmt`)
with free functions, traits, operator overloading, `Result`/`Option`, and many small option
structs. Apex has none of those:

- There are no namespaces short of a registered package namespace. Every class in an org shares
  one flat name space, and the platform already owns `Date`, `Time`, `Datetime` and `TimeZone`.
- Inner classes cannot have static members, so `Jiff.Date.newInstance(...)` is not possible.
- There is no operator overloading, no generics for user types, and enums cannot have methods.
- A long list of ordinary words is reserved, including `date`, `time`, `of`, `on`, `in`, `from`,
  `end`, `limit`, `system` and `new`.

We need a mapping that an Apex developer can use without knowing Rust, that a Jiff user can
predict, and that cannot collide with anything already in a subscriber org.

## Decision

- **Every class is top level and prefixed `Jiff`**: `JiffDate`, `JiffTime`, `JiffDateTime`,
  `JiffTimestamp`, `JiffZonedDateTime`, `JiffSpan`, `JiffSignedDuration`, `JiffTimeZone`,
  `JiffOffset`, and so on. The prefix works with or without a package namespace.
- **Method names are Jiff's, in camelCase**, with a small set of systematic substitutions forced
  by Apex:

  | Jiff | Apex | Why |
  | --- | --- | --- |
  | `Type::new(..)` | `Type.newInstance(..)` | `new` and `of` are reserved; this is the platform idiom |
  | `checked_add` / `checked_sub` | `add` / `subtract` | there is no unchecked variant to distinguish from |
  | `a.date()`, `a.time()` | `a.toDate()`, `a.toTime()` | `date` and `time` are reserved |
  | `"..".parse::<T>()`, `Display` | `T.parse(String)`, `toString()` | no traits |
  | `<`, `==`, `+`, `-` | `compareTo`/`isBefore`/`isAfter`, `equals`, `add`, `subtract` | no operator overloading |
  | `Result<T, Error>` | returns `T` or throws `JiffException` | no `Result` |
  | `Option<T>` | nullable return | no `Option` |
  | `TimeZone::system()` | `JiffTimeZone.userTimeZone()` | `system` is reserved, and on the platform the meaningful "local" zone is the running user's |

- **One exception type**, `JiffException`, mirroring Jiff's single `Error`.
- **Option structs are consolidated.** Jiff has a rounding struct and a difference struct per
  type (`TimeRound`, `DateTimeRound`, ... / `DateDifference`, `TimeDifference`, ...), all
  carrying the same fields. The port has `JiffRound`, `JiffDifference` and `JiffSpanRound`.
  Where Jiff folds the other operand into the options (`DateDifference::new(other)`), the port
  passes it separately: `a.until(b, options)`.
- **Enums that have methods in Rust** become an Apex enum plus a companion class of statics
  (`JiffWeekday` + `JiffWeekdays`).
- **All value types are immutable**, as in Jiff.
- **Interop with platform types is explicit and named `System`**: `JiffDate.fromSystemDate`,
  `toSystemDate`, `JiffTimestamp.fromSystemDatetime`, `toSystemDatetime`.

## Consequences

- The API is predictable from Jiff's documentation by applying the table above.
- Class names are longer than Jiff's, and there are more top level classes than a Rust user would
  expect (builders, series, enums and their companions are all separate files).
- Jiff's "panicking vs fallible" pairs collapse into one throwing method, so the port's surface is
  smaller than Jiff's.
- Renaming later would be a breaking change for subscribers, so the mapping rules are recorded in
  `CLAUDE.md` and applied mechanically.
