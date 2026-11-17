/**
 * How `JiffFriendlyPrinter` shows the sign of a duration.
 *
 * - `AUTO` picks based on the other settings. It writes a trailing ` ago` for a negative
 *   duration, except that it writes a leading `-` when spacing is
 *   `JiffFriendlySpacing.NONE`, or when the hours-minutes-seconds form is used and there are
 *   no calendar units. This is the default.
 * - `SIGN` writes a leading `-` for a negative duration and nothing otherwise.
 * - `FORCE_SIGN` always writes a leading sign: `-` when negative, `+` otherwise.
 * - `SUFFIX` writes a trailing ` ago` for a negative duration and nothing otherwise.
 *
 * Mirrors `jiff::fmt::friendly::Direction`.
 */
public enum JiffFriendlyDirection {
    AUTO,
    SIGN,
    FORCE_SIGN,
    SUFFIX
}
