/**
 * A signed span of absolute time with nanosecond precision.
 *
 * A signed duration is a count of seconds plus a count of sub-second nanoseconds, and nothing
 * else. It has no calendar units, so its length never depends on a date or a time zone: an
 * hour is always 3,600 seconds. Use it when you care about elapsed time. Use `JiffSpan` when
 * you care about calendar units such as months, whose length varies.
 *
 * The seconds component covers the full range of a 64 bit integer and the nanosecond
 * component is always within `-999,999,999..999,999,999`. Both components always share a
 * sign, so `-1.5` seconds is stored as `-1` second and `-500,000,000` nanoseconds.
 *
 * Instances are immutable. Operations that would overflow throw `JiffException`, except for
 * the `saturating*` variants, which clamp to `MIN` or `MAX`.
 *
 * Mirrors `jiff::SignedDuration`.
 */
public class JiffSignedDuration implements Comparable {
    private static final Integer NANOS_PER_SEC = 1000000000;
    private static final Integer NANOS_PER_MILLI = 1000000;
    private static final Integer NANOS_PER_MICRO = 1000;
    // Typed constants: a bare `0.5` is a Decimal in Apex, and mixing Decimal into Double
    // arithmetic changes the result type.
    private static final Double NANOS_PER_SEC_D = 1000000000;
    private static final Double NANOS_PER_MILLI_D = 1000000;
    private static final Double MILLIS_PER_SEC_D = 1000;
    private static final Double HALF = 0.5;

    /** A duration of zero length. */
    public static final JiffSignedDuration ZERO = new JiffSignedDuration(0L, 0);
    /** The most negative duration representable. */
    public static final JiffSignedDuration MIN = new JiffSignedDuration(
        JiffMath.LONG_MIN,
        -999999999
    );
    /** The most positive duration representable. */
    public static final JiffSignedDuration MAX = new JiffSignedDuration(
        JiffMath.LONG_MAX,
        999999999
    );

    private final Long secs;
    private final Integer nanos;

    private JiffSignedDuration(Long secs, Integer nanos) {
        this.secs = secs;
        this.nanos = nanos;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Creates a duration from whole seconds and nanoseconds.
     *
     * The nanoseconds may be any integer: anything beyond one second carries into the seconds,
     * and if the two components have different signs the result is rebalanced so they agree.
     * Throws if the carry overflows the seconds.
     */
    public static JiffSignedDuration newInstance(Long secs, Integer nanos) {
        Long s = secs;
        Integer n = nanos;
        if (n <= -NANOS_PER_SEC || n >= NANOS_PER_SEC) {
            Integer addSecs = n / NANOS_PER_SEC;
            s = JiffMath.checkedAdd(s, addSecs, 'signed duration seconds');
            n = n - addSecs * NANOS_PER_SEC;
        }
        return balance(s, n);
    }

    /** Fixes up a seconds/nanoseconds pair whose components may disagree in sign. */
    private static JiffSignedDuration balance(Long secs, Integer nanos) {
        if (nanos == 0 || secs == 0 || (secs < 0) == (nanos < 0)) {
            return new JiffSignedDuration(secs, nanos);
        }
        if (secs < 0) {
            return new JiffSignedDuration(secs + 1, nanos - NANOS_PER_SEC);
        }
        return new JiffSignedDuration(secs - 1, nanos + NANOS_PER_SEC);
    }

    public static JiffSignedDuration fromSecs(Long secs) {
        return new JiffSignedDuration(secs, 0);
    }

    public static JiffSignedDuration fromMillis(Long millis) {
        Long s = millis / 1000L;
        return new JiffSignedDuration(s, (millis - s * 1000L).intValue() * NANOS_PER_MILLI);
    }

    public static JiffSignedDuration fromMicros(Long micros) {
        Long s = micros / 1000000L;
        return new JiffSignedDuration(s, (micros - s * 1000000L).intValue() * NANOS_PER_MICRO);
    }

    public static JiffSignedDuration fromNanos(Long nanos) {
        Long s = nanos / 1000000000L;
        return new JiffSignedDuration(s, (nanos - s * 1000000000L).intValue());
    }

    /** Throws if the number of hours overflows a 64 bit count of seconds. */
    public static JiffSignedDuration fromHours(Long hours) {
        return new JiffSignedDuration(
            JiffMath.checkedMul(hours, 3600L, 'signed duration seconds'),
            0
        );
    }

    /** Throws if the number of minutes overflows a 64 bit count of seconds. */
    public static JiffSignedDuration fromMins(Long mins) {
        return new JiffSignedDuration(JiffMath.checkedMul(mins, 60L, 'signed duration seconds'), 0);
    }

    /**
     * Creates a duration from a fractional number of seconds, rounded to the nearest
     * nanosecond. Throws if the value is not finite or does not fit.
     */
    public static JiffSignedDuration fromSecsDouble(Double secs) {
        // NaN is the only value that is not equal to itself.
        if (secs != secs) {
            throw new JiffException('could not convert non-finite seconds to signed duration');
        }
        Double bound = JiffMath.LONG_MAX;
        if (secs < -bound || secs > bound) {
            throw new JiffException(
                'parameter \'floating point seconds\' is not in the required range of ' +
                    JiffMath.LONG_MIN +
                    '..=' +
                    JiffMath.LONG_MAX
            );
        }
        Long whole = secs.longValue();
        Double wholeAsDouble = whole;
        Double scaled = (secs - wholeAsDouble) * NANOS_PER_SEC_D;
        // Round half away from zero, as Rust's `f64::round` does.
        Double nudged = scaled < 0 ? scaled - HALF : scaled + HALF;
        Long n = nudged.longValue();
        if (n == 1000000000L || n == -1000000000L) {
            whole = JiffMath.checkedAdd(whole, n < 0 ? -1L : 1L, 'signed duration seconds');
            n = 0L;
        }
        return new JiffSignedDuration(whole, n.intValue());
    }

    /** Internal: builds a duration from a wide nanosecond count. */
    public static JiffSignedDuration fromNanosI128(JiffI128 nanos) {
        List<JiffI128> parts = nanos.divRem(JiffI128.valueOf(1000000000L));
        if (!parts.get(0).fitsLong()) {
            throw JiffMath.rangeError(
                'signed duration seconds',
                JiffMath.LONG_MIN,
                JiffMath.LONG_MAX
            );
        }
        return new JiffSignedDuration(parts.get(0).toLong(), parts.get(1).toLong().intValue());
    }

    // ---- accessors ------------------------------------------------------

    public Boolean isZero() {
        return secs == 0 && nanos == 0;
    }

    /** The whole seconds in this duration, truncated toward zero. */
    public Long asSecs() {
        return secs;
    }

    /** The fractional part of this duration in whole milliseconds, with the duration's sign. */
    public Integer subsecMillis() {
        return nanos / NANOS_PER_MILLI;
    }

    /** The fractional part of this duration in whole microseconds, with the duration's sign. */
    public Integer subsecMicros() {
        return nanos / NANOS_PER_MICRO;
    }

    /** The fractional part of this duration in nanoseconds, with the duration's sign. */
    public Integer subsecNanos() {
        return nanos;
    }

    /** Whole hours, truncated toward zero. */
    public Long asHours() {
        return secs / 3600L;
    }

    /** Whole minutes, truncated toward zero. */
    public Long asMins() {
        return secs / 60L;
    }

    /**
     * Whole milliseconds, truncated toward zero. Jiff returns an `i128` here; this throws
     * instead when the count does not fit in a Long (durations beyond roughly 292 million years).
     */
    public Long asMillis() {
        return JiffMath.checkedAdd(
            JiffMath.checkedMul(secs, 1000L, 'signed duration milliseconds'),
            subsecMillis(),
            'signed duration milliseconds'
        );
    }

    /** Whole microseconds, truncated toward zero. Throws beyond roughly 292,000 years. */
    public Long asMicros() {
        return JiffMath.checkedAdd(
            JiffMath.checkedMul(secs, 1000000L, 'signed duration microseconds'),
            subsecMicros(),
            'signed duration microseconds'
        );
    }

    /** Total nanoseconds. Throws beyond roughly 292 years; see `asNanosI128` for the rest. */
    public Long asNanos() {
        return JiffMath.checkedAdd(
            JiffMath.checkedMul(secs, 1000000000L, 'signed duration nanoseconds'),
            nanos,
            'signed duration nanoseconds'
        );
    }

    /** Internal: total nanoseconds as a wide integer, for any duration. */
    public JiffI128 asNanosI128() {
        return JiffI128.ofSecondsAndNanos(secs, nanos);
    }

    /** Whether the total nanosecond count fits in a Long. */
    public Boolean fitsNanos() {
        return asNanosI128().fitsLong();
    }

    public Double asSecsDouble() {
        Double s = secs;
        Double n = nanos;
        return s + n / NANOS_PER_SEC_D;
    }

    public Double asMillisDouble() {
        Double s = secs;
        Double n = nanos;
        return s * MILLIS_PER_SEC_D + n / NANOS_PER_MILLI_D;
    }

    public Integer signum() {
        if (secs != 0) {
            return secs < 0 ? -1 : 1;
        }
        return nanos < 0 ? -1 : (nanos > 0 ? 1 : 0);
    }

    public Boolean isPositive() {
        return secs > 0 || nanos > 0;
    }

    public Boolean isNegative() {
        return secs < 0 || nanos < 0;
    }

    // ---- arithmetic -----------------------------------------------------

    /** The absolute value. Throws for `MIN`, whose magnitude is not representable. */
    public JiffSignedDuration abs() {
        return isNegative() ? negate() : this;
    }

    /** Throws for `MIN`, whose negation is not representable. */
    public JiffSignedDuration negate() {
        return new JiffSignedDuration(JiffMath.checkedNeg(secs, 'signed duration seconds'), -nanos);
    }

    public JiffSignedDuration add(JiffSignedDuration other) {
        Long s = JiffMath.checkedAdd(secs, other.secs, 'signed duration seconds');
        Integer n = nanos + other.nanos;
        if (n >= NANOS_PER_SEC) {
            n -= NANOS_PER_SEC;
            s = JiffMath.checkedAdd(s, 1L, 'signed duration seconds');
        } else if (n <= -NANOS_PER_SEC) {
            n += NANOS_PER_SEC;
            s = JiffMath.checkedSub(s, 1L, 'signed duration seconds');
        }
        return balance(s, n);
    }

    public JiffSignedDuration subtract(JiffSignedDuration other) {
        // As in Jiff, this fails when `other` cannot be negated, even in the rare case where
        // the mathematical difference would have been representable.
        return add(other.negate());
    }

    public JiffSignedDuration saturatingAdd(JiffSignedDuration other) {
        try {
            return add(other);
        } catch (JiffException e) {
            return other.isNegative() ? MIN : MAX;
        }
    }

    public JiffSignedDuration saturatingSubtract(JiffSignedDuration other) {
        try {
            return subtract(other);
        } catch (JiffException e) {
            return other.isPositive() ? MIN : MAX;
        }
    }

    public JiffSignedDuration multiply(Integer factor) {
        Long f = factor;
        Long n = nanos * f;
        Long addSecs = n / 1000000000L;
        Long s = JiffMath.checkedMul(secs, f, 'signed duration seconds');
        s = JiffMath.checkedAdd(s, addSecs, 'signed duration seconds');
        return balance(s, (n - addSecs * 1000000000L).intValue());
    }

    public JiffSignedDuration saturatingMultiply(Integer factor) {
        try {
            return multiply(factor);
        } catch (JiffException e) {
            return (signum() < 0) != (factor < 0) ? MIN : MAX;
        }
    }

    /** Divides by an integer, truncating toward zero. Throws on division by zero. */
    public JiffSignedDuration divide(Integer divisor) {
        if (divisor == 0) {
            throw new JiffException('division of a signed duration by zero');
        }
        if (secs == JiffMath.LONG_MIN && divisor == -1) {
            throw JiffMath.overflow('signed duration seconds');
        }
        Long d = divisor;
        Long s = secs / d;
        Long remSecs = secs - s * d;
        Long n = nanos / d;
        Long remNanos = nanos - n * d;
        n += (remSecs * 1000000000L + remNanos) / d;
        return new JiffSignedDuration(s, n.intValue());
    }

    public JiffSignedDuration multiplyDouble(Double factor) {
        return fromSecsDouble(factor * asSecsDouble());
    }

    public JiffSignedDuration divideDouble(Double divisor) {
        return fromSecsDouble(asSecsDouble() / divisor);
    }

    /** How many times `other` goes into this duration, as a fraction. */
    public Double divDuration(JiffSignedDuration other) {
        return asNanosDouble() / other.asNanosDouble();
    }

    private Double asNanosDouble() {
        Double s = secs;
        Double n = nanos;
        return s * NANOS_PER_SEC_D + n;
    }

    // ---- rounding -------------------------------------------------------

    /** Rounds to the nearest multiple of `unit`, with ties rounding away from zero. */
    public JiffSignedDuration round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this duration. The smallest unit must be hours or smaller; rounding to calendar
     * units needs a `JiffSpan`, because only a span can know how long a day or month is.
     */
    public JiffSignedDuration round(JiffRound options) {
        Long increment = JiffRounding.incrementForSignedDuration(
            options.getSmallest(),
            options.getIncrement()
        );
        try {
            return JiffRounding.roundDuration(
                options.getMode(),
                this,
                options.getSmallest(),
                increment
            );
        } catch (JiffException e) {
            throw new JiffException(
                'rounding signed duration to nearest ' +
                    JiffMath.singular(options.getSmallest()) +
                    ' resulted in a value outside the supported range of a `JiffSignedDuration`',
                e
            );
        }
    }

    // ---- comparison -----------------------------------------------------

    public Integer compareTo(Object other) {
        JiffSignedDuration that = (JiffSignedDuration) other;
        if (secs != that.secs) {
            return JiffMath.compare(secs, that.secs);
        }
        return nanos < that.nanos ? -1 : (nanos > that.nanos ? 1 : 0);
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffSignedDuration)) {
            return false;
        }
        JiffSignedDuration that = (JiffSignedDuration) other;
        return secs == that.secs && nanos == that.nanos;
    }

    public Integer hashCode() {
        return JiffMath.floorMod(JiffMath.floorMod(secs, 1000000007L) * 31 + nanos, 1000000007L)
            .intValue();
    }

    /**
     * Formats this duration in the ISO 8601 duration format, using hours as the largest unit.
     * For example `PT2H30M`, `-PT1.5S` or `PT0S`.
     */
    public override String toString() {
        return JiffTemporal.printDuration(this);
    }

    /**
     * Parses a duration from either an ISO 8601 duration (`PT2H30M`) or a friendly duration
     * (`2h 30m`, `2 hours, 30 minutes`, `02:30:00`, `2.5 hours`).
     *
     * Text that starts with `P` or `p`, optionally after a sign, is read as ISO 8601;
     * anything else is read as the friendly format. Only hours and smaller units are
     * accepted, because a day or a month has no fixed length; parse into a `JiffSpan` for
     * those. Throws `JiffException` when the text is neither format or the total overflows.
     *
     * See `JiffTemporal.parseDuration` and `JiffFriendly` for the two formats.
     */
    public static JiffSignedDuration parse(String text) {
        return JiffFriendly.parseIsoOrFriendlyDuration(text);
    }

    /**
     * Formats this duration in the friendly format, for example `2h 30m` or `1s 500ms ago`.
     * The largest unit used is hours. Use `JiffFriendlyPrinter` for other styles.
     */
    public String toFriendly() {
        return JiffFriendly.printDuration(this);
    }
}
