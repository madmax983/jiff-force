/**
 * Internal rounding machinery: increment validation and the rounding rule itself.
 * Not part of the public API. Ported from `jiff::util::round`.
 */
public class JiffRounding {
    private static final Long MAX_INCREMENT = 1000000000L;

    // Indexed by unit ordinal: how many of each unit make up the next unit.
    private static final List<Long> UNIT_LIMITS = new List<Long>{
        1000L,
        1000L,
        1000L,
        60L,
        60L,
        24L
    };
    // Indexed by unit ordinal: how many of each unit make up one civil day.
    private static final List<Long> DAY_MAXIMUMS = new List<Long>{
        86400000000000L,
        86400000000L,
        86400000L,
        86400L,
        1440L,
        24L
    };

    // ---- increment validation -------------------------------------------

    /**
     * For spans: a time unit's increment must divide evenly into the next unit up, while a
     * calendar unit accepts any increment in range.
     */
    public static Long incrementForSpan(JiffUnit unit, Long value) {
        if (unit.ordinal() < JiffUnit.DAY.ordinal()) {
            return forLimits(unit, value, UNIT_LIMITS, false);
        }
        return checkIncrement(value);
    }

    /** For signed durations: any increment in range, but no calendar units. */
    public static Long incrementForSignedDuration(JiffUnit unit, Long value) {
        if (unit.ordinal() > JiffUnit.HOUR.ordinal()) {
            throw new JiffException(
                'rounding `JiffSignedDuration` failed because the smallest unit provided, \'' +
                    JiffMath.plural(unit) +
                    '\', is a calendar unit (to round by calendar units, you must use a `JiffSpan`)'
            );
        }
        return checkIncrement(value);
    }

    /** For time zone offsets: hours, minutes or seconds with any increment in range. */
    public static Long incrementForOffset(JiffUnit unit, Long value) {
        if (
            unit.ordinal() < JiffUnit.SECOND.ordinal() ||
            unit.ordinal() > JiffUnit.HOUR.ordinal()
        ) {
            throw new JiffException(
                '\'' +
                    JiffMath.singular(unit) +
                    '\' not allowed when rounding time zone offset (must use hours, minutes or seconds)'
            );
        }
        return checkIncrement(value);
    }

    /** For civil datetimes: as for times, plus rounding to whole days with an increment of 1. */
    public static Long incrementForDateTime(JiffUnit unit, Long value) {
        if (unit == JiffUnit.DAY) {
            checkIncrement(value);
            if (value != 1) {
                throw new JiffException('increment for rounding to \'days\' must be equal to `1`');
            }
            return value;
        }
        return forLimits(unit, value, UNIT_LIMITS, false);
    }

    /** For civil times: the increment must divide evenly into the next unit up. */
    public static Long incrementForTime(JiffUnit unit, Long value) {
        return forLimits(unit, value, UNIT_LIMITS, false);
    }

    /** For timestamps: the increment must divide evenly into one civil day. */
    public static Long incrementForTimestamp(JiffUnit unit, Long value) {
        return forLimits(unit, value, DAY_MAXIMUMS, true);
    }

    private static Long forLimits(JiffUnit unit, Long value, List<Long> limits, Boolean inclusive) {
        if (unit.ordinal() >= limits.size()) {
            throw new JiffException(
                'rounding to \'' + JiffMath.plural(unit) + '\' is not supported'
            );
        }
        checkIncrement(value);
        Long mustDivide = limits.get(unit.ordinal());
        Boolean small = inclusive ? value <= mustDivide : value < mustDivide;
        if (small && JiffMath.truncMod(mustDivide, value) == 0) {
            return value;
        }
        throw new JiffException(
            'increment for rounding to \'' +
                JiffMath.plural(unit) +
                '\' must divide into `' +
                mustDivide +
                '` evenly'
        );
    }

    private static Long checkIncrement(Long value) {
        return JiffMath.check(value, 1L, MAX_INCREMENT, 'rounding increment');
    }

    // ---- rounding -------------------------------------------------------

    /**
     * Rounds `quantity` to a multiple of `increment` (which must be positive).
     * See https://tc39.es/proposal-temporal/#sec-temporal-roundnumbertoincrement
     */
    public static JiffI128 round(JiffRoundMode mode, JiffI128 quantity, JiffI128 increment) {
        List<JiffI128> parts = quantity.divRem(increment);
        JiffI128 quotient = parts.get(0);
        JiffI128 remainder = parts.get(1);
        if (remainder.isZero()) {
            return quantity;
        }
        Integer sign = remainder.signum();
        Integer nearer = remainder.abs().add(remainder.abs()).compareTo(increment);
        Boolean expand = shouldExpand(mode, sign, nearer, quotient.isOdd());
        JiffI128 truncated = quantity.subtract(remainder);
        if (!expand) {
            return truncated;
        }
        return sign > 0 ? truncated.add(increment) : truncated.subtract(increment);
    }

    /**
     * `round` for quantities small enough that neither the doubled remainder nor the result
     * can overflow a Long. Callers must guarantee that; nanoseconds within a day qualify.
     */
    public static Long roundLong(JiffRoundMode mode, Long quantity, Long increment) {
        Long quotient = quantity / increment;
        Long remainder = quantity - quotient * increment;
        if (remainder == 0) {
            return quantity;
        }
        Integer sign = remainder < 0 ? -1 : 1;
        Integer nearer = JiffMath.compare(JiffMath.abs(remainder) * 2, increment);
        Boolean odd = quotient - (quotient / 2) * 2 != 0;
        Long truncated = quantity - remainder;
        if (!shouldExpand(mode, sign, nearer, odd)) {
            return truncated;
        }
        return sign > 0 ? truncated + increment : truncated - increment;
    }

    /**
     * Decides whether to move one increment away from zero.
     *
     * @param sign    sign of the remainder (never zero)
     * @param nearer  -1 when the truncated value is nearer, 0 on a tie, 1 when expanding is nearer
     * @param odd     whether the truncated quotient is odd
     */
    private static Boolean shouldExpand(
        JiffRoundMode mode,
        Integer sign,
        Integer nearer,
        Boolean odd
    ) {
        Boolean tie = nearer == 0;
        Boolean expandIsNearer = nearer > 0;
        switch on mode {
            when CEIL {
                return sign > 0;
            }
            when FLOOR {
                return sign < 0;
            }
            when EXPAND {
                return true;
            }
            when TRUNC {
                return false;
            }
            when HALF_CEIL {
                return expandIsNearer || (tie && sign > 0);
            }
            when HALF_FLOOR {
                return expandIsNearer || (tie && sign < 0);
            }
            when HALF_EXPAND {
                return expandIsNearer || tie;
            }
            when HALF_TRUNC {
                return expandIsNearer;
            }
            when else {
                // HALF_EVEN
                return expandIsNearer || (tie && odd);
            }
        }
    }

    /** Rounds a duration to a multiple of `increment` nanoseconds of the given unit. */
    public static JiffSignedDuration roundDuration(
        JiffRoundMode mode,
        JiffSignedDuration quantity,
        JiffUnit unit,
        Long increment
    ) {
        JiffI128 step = JiffI128.product(JiffMath.nanosPerUnit(unit), increment);
        return JiffSignedDuration.fromNanosI128(round(mode, quantity.asNanosI128(), step));
    }
}
