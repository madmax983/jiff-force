/**
 * A unit of time, from nanoseconds up to years.
 *
 * Units are ordered from smallest to largest, so `ordinal()` can be compared to ask whether one
 * unit is bigger than another. Units up to and including `HOUR` always have the same length.
 * `DAY` and `WEEK` have a fixed length for civil datetimes but can vary for zoned datetimes
 * (a day containing a daylight saving time transition may be 23 or 25 hours long). `MONTH` and
 * `YEAR` always vary.
 *
 * Mirrors `jiff::Unit`.
 */
public enum JiffUnit {
    NANOSECOND,
    MICROSECOND,
    MILLISECOND,
    SECOND,
    MINUTE,
    HOUR,
    DAY,
    WEEK,
    MONTH,
    YEAR
}
