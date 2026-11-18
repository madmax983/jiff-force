/**
 * Options for `until` and `since`: which units the resulting span may use and how it is
 * rounded.
 *
 * - `largest` is the biggest unit allowed in the result. Left unset, each type picks a default
 *   that never involves a variable length unit unless you ask for one (for example, the
 *   difference between two dates is reported in days rather than months).
 * - `smallest` is the smallest unit allowed. Anything below it is rounded away. Left unset it
 *   is the finest unit the type can express (days for dates, nanoseconds otherwise).
 * - `mode` controls that rounding and defaults to `JiffRoundMode.TRUNC`, so that by default a
 *   difference never overshoots.
 * - `increment` is the rounding increment in multiples of `smallest`, and defaults to `1`.
 *
 *     // Whole months between two dates, rounding to the nearest month.
 *     JiffSpan span = start.until(
 *         finish,
 *         new JiffDifference().largest(JiffUnit.MONTH).smallest(JiffUnit.MONTH).mode(JiffRoundMode.HALF_EXPAND)
 *     );
 *
 * Options are immutable; each setter returns a new instance. This one class stands in for
 * Jiff's `DateDifference`, `TimeDifference`, `DateTimeDifference`, `TimestampDifference` and
 * `ZonedDateTimeDifference`. Where Jiff bundles the other datetime into the options, the port
 * passes it as a separate argument: `a.until(b, options)`.
 */
public class JiffDifference {
    private final JiffUnit smallestUnit;
    private final JiffUnit largestUnit;
    private final JiffRoundMode roundMode;
    private final Long incrementValue;

    public JiffDifference() {
        this(null, null, JiffRoundMode.TRUNC, 1L);
    }

    private JiffDifference(
        JiffUnit smallestUnit,
        JiffUnit largestUnit,
        JiffRoundMode roundMode,
        Long incrementValue
    ) {
        this.smallestUnit = smallestUnit;
        this.largestUnit = largestUnit;
        this.roundMode = roundMode;
        this.incrementValue = incrementValue;
    }

    /** Sets the smallest unit allowed in the result. Pass null to restore the type's default. */
    public JiffDifference smallest(JiffUnit unit) {
        return new JiffDifference(unit, largestUnit, roundMode, incrementValue);
    }

    /** Sets the largest unit allowed in the result. Pass null to restore the type's default. */
    public JiffDifference largest(JiffUnit unit) {
        return new JiffDifference(smallestUnit, unit, roundMode, incrementValue);
    }

    /** Sets how the difference is rounded to the smallest unit. */
    public JiffDifference mode(JiffRoundMode mode) {
        if (mode == null) {
            throw new JiffException('rounding mode must not be null');
        }
        return new JiffDifference(smallestUnit, largestUnit, mode, incrementValue);
    }

    /** Sets the rounding increment, in multiples of the smallest unit. */
    public JiffDifference increment(Long increment) {
        return new JiffDifference(smallestUnit, largestUnit, roundMode, increment);
    }

    /** The configured smallest unit, or null when the type's default applies. */
    public JiffUnit getSmallest() {
        return smallestUnit;
    }

    /** The configured largest unit, or null when the type's default applies. */
    public JiffUnit getLargest() {
        return largestUnit;
    }

    public JiffRoundMode getMode() {
        return roundMode;
    }

    public Long getIncrement() {
        return incrementValue;
    }
}
