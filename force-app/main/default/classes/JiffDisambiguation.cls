/**
 * How to pick an instant for a civil datetime that a time zone maps to no instant (a gap,
 * usually when clocks spring forward) or to two instants (a fold, usually when clocks fall
 * back).
 *
 * - `COMPATIBLE` picks the later instant in a gap and the earlier instant in a fold. This is
 *   what RFC 5545 specifies and what most people expect: `02:30` on a spring-forward day
 *   becomes `03:30`, and `01:30` on a fall-back day is the first `01:30`. It is the default
 *   wherever the port needs one.
 * - `EARLIER` always picks the earlier instant.
 * - `LATER` always picks the later instant.
 * - `REJECT` refuses to choose and makes the operation throw `JiffException`.
 *
 * Pass a value to `JiffAmbiguousTimestamp.disambiguate`, or call the matching method there
 * (`compatible()`, `earlier()`, `later()`, `unambiguous()`).
 *
 * Mirrors `jiff::tz::Disambiguation`.
 */
public enum JiffDisambiguation {
    COMPATIBLE,
    EARLIER,
    LATER,
    REJECT
}
