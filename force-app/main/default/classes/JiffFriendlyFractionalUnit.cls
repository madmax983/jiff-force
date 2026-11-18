/**
 * The smallest unit `JiffFriendlyPrinter` writes as a whole number when fractions are turned
 * on. Anything smaller is folded into a decimal fraction of this unit, so three thousand six
 * hundred and sixty three seconds is `1.0175h` with `HOUR`, `1h 1.05m` with `MINUTE` and
 * `1h 1m 3s` with `SECOND`.
 *
 * A fraction has at most nine digits. That is exact for seconds, milliseconds and
 * microseconds, but `HOUR` and `MINUTE` can lose precision: one nanosecond is `0h`.
 *
 * Mirrors `jiff::fmt::friendly::FractionalUnit`.
 */
public enum JiffFriendlyFractionalUnit {
    HOUR,
    MINUTE,
    SECOND,
    MILLISECOND,
    MICROSECOND
}
