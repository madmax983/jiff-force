/**
 * Options for `JiffSpan.round`: the units the rounded span may use, how it is rounded, and the
 * point it is measured from.
 *
 * - `smallest` is the smallest unit allowed to be non-zero in the result. Anything smaller is
 *   rounded away. The default, `NANOSECOND`, rounds nothing.
 * - `largest` is the biggest unit allowed to be non-zero in the result. Bigger units are
 *   folded into it, and smaller ones that overflow are carried up to it. Left unset (null) it
 *   is the bigger of `smallest` and the biggest non-zero unit of the span being rounded.
 *   Setting only `largest` balances a span without rounding it.
 * - `mode` decides how a remainder is rounded, and defaults to `HALF_EXPAND`.
 * - `increment` rounds to a multiple of that many `smallest` units, and defaults to `1`. For
 *   hours and smaller units it must divide evenly into the next unit up (24 hours, 60 minutes,
 *   ...); for days and bigger units it can be anything from 1 to 1,000,000,000.
 * - `relative` is where the span is measured from. It is required whenever days or bigger
 *   units are involved, either in the span or in the options; see `JiffSpanRelativeTo`.
 *
 *     // 1,000 days, as years, months and days counted from 2000-01-01.
 *     new JiffSpan().days(1000).round(
 *         new JiffSpanRound().largest(JiffUnit.YEAR)
 *             .relative(JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2000, 1, 1)))
 *     );   // P2Y8M26D
 *
 *     // To the nearest half hour.
 *     JiffSpan.parse('PT23H50M3.123S').round(JiffSpanRound.to(JiffUnit.MINUTE).increment(30));
 *     // PT24H
 *
 * Options are immutable; each setter returns a new instance. Nothing is validated until the
 * options are used.
 *
 * Mirrors `jiff::SpanRound`.
 */
public class JiffSpanRound {
    private final JiffUnit smallestUnit;
    private final JiffUnit largestUnit;
    private final JiffRoundMode roundMode;
    private final Long incrementValue;
    private final JiffSpanRelativeTo relativeTo;

    /**
     * Options that round nothing: smallest unit `NANOSECOND`, no largest unit, mode
     * `HALF_EXPAND`, increment `1` and no reference point. Rounding with them still balances
     * the units below the span's biggest one, as in Jiff: `PT90M1.5S` stays `PT90M1.5S`, but
     * 90 minutes and 1,500 milliseconds become 90 minutes, 1 second and 500 milliseconds.
     */
    public JiffSpanRound() {
        this(JiffUnit.NANOSECOND, null, JiffRoundMode.HALF_EXPAND, 1L, null);
    }

    private JiffSpanRound(
        JiffUnit smallestUnit,
        JiffUnit largestUnit,
        JiffRoundMode roundMode,
        Long incrementValue,
        JiffSpanRelativeTo relativeTo
    ) {
        this.smallestUnit = smallestUnit;
        this.largestUnit = largestUnit;
        this.roundMode = roundMode;
        this.incrementValue = incrementValue;
        this.relativeTo = relativeTo;
    }

    /** Shorthand for `new JiffSpanRound().smallest(unit)`. */
    public static JiffSpanRound to(JiffUnit smallest) {
        return new JiffSpanRound().smallest(smallest);
    }

    /** Sets the smallest unit allowed in the result. Throws when `unit` is null. */
    public JiffSpanRound smallest(JiffUnit unit) {
        if (unit == null) {
            throw new JiffException('smallest unit must not be null');
        }
        return new JiffSpanRound(unit, largestUnit, roundMode, incrementValue, relativeTo);
    }

    /**
     * Sets the largest unit allowed in the result. Pass null for the default: the bigger of
     * the smallest unit and the span's own biggest non-zero unit.
     */
    public JiffSpanRound largest(JiffUnit unit) {
        return new JiffSpanRound(smallestUnit, unit, roundMode, incrementValue, relativeTo);
    }

    /** Sets how a remainder is rounded. Throws when `mode` is null. */
    public JiffSpanRound mode(JiffRoundMode mode) {
        if (mode == null) {
            throw new JiffException('rounding mode must not be null');
        }
        return new JiffSpanRound(smallestUnit, largestUnit, mode, incrementValue, relativeTo);
    }

    /**
     * Sets the rounding increment, in multiples of the smallest unit. It is checked when the
     * options are used. Throws when `increment` is null.
     */
    public JiffSpanRound increment(Long increment) {
        if (increment == null) {
            throw new JiffException('rounding increment must not be null');
        }
        return new JiffSpanRound(smallestUnit, largestUnit, roundMode, increment, relativeTo);
    }

    /** Sets the point the span is measured from. Pass null for none. */
    public JiffSpanRound relative(JiffSpanRelativeTo relative) {
        return new JiffSpanRound(smallestUnit, largestUnit, roundMode, incrementValue, relative);
    }

    /** The smallest unit allowed in the result. */
    public JiffUnit getSmallest() {
        return smallestUnit;
    }

    /** The largest unit allowed in the result, or null when the default applies. */
    public JiffUnit getLargest() {
        return largestUnit;
    }

    /** The rounding mode. */
    public JiffRoundMode getMode() {
        return roundMode;
    }

    /** The rounding increment, in multiples of the smallest unit. */
    public Long getIncrement() {
        return incrementValue;
    }

    /** The point the span is measured from, or null when none was given. */
    public JiffSpanRelativeTo getRelative() {
        return relativeTo;
    }
}
