/**
 * Internal arithmetic helpers shared by the jiff-force types. Not part of the public API.
 *
 * Apex integers wrap silently on overflow, so every operation here that can overflow checks
 * its operands *before* computing and throws `JiffException` instead. Nothing in this class
 * depends on wrap-around behaviour.
 */
public class JiffMath {
    public static final Long LONG_MAX = 9223372036854775807L;
    public static final Long LONG_MIN = -9223372036854775807L - 1L;
    public static final Integer INT_MAX = 2147483647;
    public static final Integer INT_MIN = -2147483647 - 1;

    public static final Long NANOS_PER_MICRO = 1000L;
    public static final Long NANOS_PER_MILLI = 1000000L;
    public static final Long NANOS_PER_SEC = 1000000000L;
    public static final Long NANOS_PER_MIN = 60000000000L;
    public static final Long NANOS_PER_HOUR = 3600000000000L;
    public static final Long NANOS_PER_CIVIL_DAY = 86400000000000L;
    public static final Long NANOS_PER_CIVIL_WEEK = 604800000000000L;
    public static final Long MICROS_PER_SEC = 1000000L;
    public static final Long MILLIS_PER_SEC = 1000L;
    public static final Long SECS_PER_MIN = 60L;
    public static final Long SECS_PER_HOUR = 3600L;
    public static final Long SECS_PER_CIVIL_DAY = 86400L;
    public static final Long SECS_PER_CIVIL_WEEK = 604800L;

    /** Division rounding toward negative infinity. `divisor` must be positive. */
    public static Long floorDiv(Long dividend, Long divisor) {
        Long quotient = dividend / divisor;
        if (dividend < 0 && quotient * divisor != dividend) {
            quotient -= 1;
        }
        return quotient;
    }

    /** The non-negative remainder of `floorDiv`. `divisor` must be positive. */
    public static Long floorMod(Long dividend, Long divisor) {
        return dividend - floorDiv(dividend, divisor) * divisor;
    }

    /** The remainder of truncating division; it takes the sign of the dividend. */
    public static Long truncMod(Long dividend, Long divisor) {
        return dividend - (dividend / divisor) * divisor;
    }

    public static Long checkedAdd(Long a, Long b, String what) {
        if (b > 0 ? a > LONG_MAX - b : a < LONG_MIN - b) {
            throw overflow(what);
        }
        return a + b;
    }

    public static Long checkedSub(Long a, Long b, String what) {
        if (b > 0 ? a < LONG_MIN + b : a > LONG_MAX + b) {
            throw overflow(what);
        }
        return a - b;
    }

    public static Long checkedNeg(Long a, String what) {
        if (a == LONG_MIN) {
            throw overflow(what);
        }
        return -a;
    }

    public static Long checkedMul(Long a, Long b, String what) {
        if (!mulFits(a, b)) {
            throw overflow(what);
        }
        return a * b;
    }

    /** Whether `a * b` is representable as a Long. */
    public static Boolean mulFits(Long a, Long b) {
        if (a == 0 || b == 0) {
            return true;
        }
        if (a == LONG_MIN) {
            return b == 1;
        }
        if (b == LONG_MIN) {
            return a == 1;
        }
        Long absA = a < 0 ? -a : a;
        Long absB = b < 0 ? -b : b;
        if ((a < 0) == (b < 0)) {
            return absA <= LONG_MAX / absB;
        }
        // A negative product may reach LONG_MIN, one further than LONG_MAX.
        return -absA >= LONG_MIN / absB;
    }

    public static Long abs(Long value) {
        return value < 0 ? -value : value;
    }

    public static Integer signum(Long value) {
        return value < 0 ? -1 : (value > 0 ? 1 : 0);
    }

    public static Integer compare(Long a, Long b) {
        return a < b ? -1 : (a > b ? 1 : 0);
    }

    /**
     * Returns `value` when it lies in `min..max` inclusive, and otherwise throws with the same
     * wording Jiff uses for an out of range parameter.
     */
    public static Long check(Long value, Long min, Long max, String what) {
        if (value < min || value > max) {
            throw rangeError(what, min, max);
        }
        return value;
    }

    /** `check` for values that are returned as an Integer. */
    public static Integer checkInt(Long value, Long min, Long max, String what) {
        return check(value, min, max, what).intValue();
    }

    public static JiffException rangeError(String what, Long min, Long max) {
        return new JiffException(
            'parameter \'' + what + '\' is not in the required range of ' + min + '..=' + max
        );
    }

    public static JiffException overflow(String what) {
        return new JiffException(what + ' overflowed');
    }

    // ---- units ----------------------------------------------------------

    /** Nanoseconds in one `unit`, for the units with a fixed civil length (weeks and below). */
    public static Long nanosPerUnit(JiffUnit unit) {
        switch on unit {
            when NANOSECOND {
                return 1L;
            }
            when MICROSECOND {
                return NANOS_PER_MICRO;
            }
            when MILLISECOND {
                return NANOS_PER_MILLI;
            }
            when SECOND {
                return NANOS_PER_SEC;
            }
            when MINUTE {
                return NANOS_PER_MIN;
            }
            when HOUR {
                return NANOS_PER_HOUR;
            }
            when DAY {
                return NANOS_PER_CIVIL_DAY;
            }
            when WEEK {
                return NANOS_PER_CIVIL_WEEK;
            }
            when else {
                throw new JiffException(
                    'unit \'' + singular(unit) + '\' does not have a fixed length'
                );
            }
        }
    }

    public static String singular(JiffUnit unit) {
        return unit.name().toLowerCase();
    }

    public static String plural(JiffUnit unit) {
        return unit.name().toLowerCase() + 's';
    }

    /** Whether `unit` is strictly larger than `other`. */
    public static Boolean isLarger(JiffUnit unit, JiffUnit other) {
        return unit.ordinal() > other.ordinal();
    }

    /** Whether `unit` is a calendar unit (days and above). */
    public static Boolean isCalendar(JiffUnit unit) {
        return unit.ordinal() >= JiffUnit.DAY.ordinal();
    }

    public static JiffUnit largerOf(JiffUnit a, JiffUnit b) {
        return a.ordinal() >= b.ordinal() ? a : b;
    }

    public static JiffUnit smallerOf(JiffUnit a, JiffUnit b) {
        return a.ordinal() <= b.ordinal() ? a : b;
    }

    // ---- text -----------------------------------------------------------

    /** Zero pads `value` (which must be non-negative) to at least `width` digits. */
    public static String pad(Long value, Integer width) {
        return String.valueOf(value).leftPad(width, '0');
    }
}
