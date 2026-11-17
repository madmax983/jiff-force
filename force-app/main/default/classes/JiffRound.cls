/**
 * Options for rounding a time, datetime, timestamp, zoned datetime, time zone offset or signed
 * duration: the smallest unit to keep, the rounding mode, and the rounding increment.
 *
 * The defaults are `JiffUnit.NANOSECOND`, `JiffRoundMode.HALF_EXPAND` and an increment of `1`,
 * which together leave a value unchanged. Options are immutable; each setter returns a new
 * instance.
 *
 *     // Round to the nearest quarter hour.
 *     JiffTime rounded = time.round(JiffRound.to(JiffUnit.MINUTE).increment(15));
 *
 * This one class stands in for Jiff's `TimeRound`, `DateTimeRound`, `TimestampRound`,
 * `ZonedDateTimeRound`, `OffsetRound` and `SignedDurationRound`, which all carry the same three
 * settings. Spans have more to configure and use `JiffSpanRound`.
 */
public class JiffRound {
    private final JiffUnit smallestUnit;
    private final JiffRoundMode roundMode;
    private final Long incrementValue;

    public JiffRound() {
        this(JiffUnit.NANOSECOND, JiffRoundMode.HALF_EXPAND, 1L);
    }

    private JiffRound(JiffUnit smallestUnit, JiffRoundMode roundMode, Long incrementValue) {
        this.smallestUnit = smallestUnit;
        this.roundMode = roundMode;
        this.incrementValue = incrementValue;
    }

    /** Shorthand for `new JiffRound().smallest(unit)`. */
    public static JiffRound to(JiffUnit unit) {
        return new JiffRound().smallest(unit);
    }

    /** Sets the smallest unit to keep. Everything below it is rounded away. */
    public JiffRound smallest(JiffUnit unit) {
        if (unit == null) {
            throw new JiffException('smallest unit must not be null');
        }
        return new JiffRound(unit, roundMode, incrementValue);
    }

    /** Sets how values between two increments are resolved. */
    public JiffRound mode(JiffRoundMode mode) {
        if (mode == null) {
            throw new JiffException('rounding mode must not be null');
        }
        return new JiffRound(smallestUnit, mode, incrementValue);
    }

    /**
     * Sets the rounding increment, in multiples of the smallest unit. For example, a smallest
     * unit of minutes with an increment of 15 rounds to the nearest quarter hour.
     */
    public JiffRound increment(Long increment) {
        return new JiffRound(smallestUnit, roundMode, increment);
    }

    public JiffUnit getSmallest() {
        return smallestUnit;
    }

    public JiffRoundMode getMode() {
        return roundMode;
    }

    public Long getIncrement() {
        return incrementValue;
    }
}
