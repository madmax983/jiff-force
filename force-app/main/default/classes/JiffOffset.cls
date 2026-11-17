/**
 * A fixed offset from UTC, in whole seconds.
 *
 * An offset says how far a civil clock is ahead of (positive) or behind (negative) UTC at one
 * moment. `-05:00` is New York in winter; in summer New York is at `-04:00`, which is why an
 * offset alone is not a time zone. Use an offset to convert between an instant and a civil
 * datetime when you already know which offset applies, and a `JiffTimeZone` when the offset
 * has to be looked up.
 *
 *     JiffOffset offset = JiffOffset.fromHours(-5);
 *     offset.seconds();                                  // -18000
 *     offset.toDateTime(JiffTimestamp.UNIX_EPOCH);       // 1969-12-31T19:00:00
 *     offset.toString();                                 // -05
 *
 * The supported range is `-25:59:59` through `+25:59:59`. Instances are immutable and ordered
 * from the most negative offset to the most positive.
 *
 * Mirrors `jiff::tz::Offset`.
 */
public class JiffOffset implements Comparable {
    private static final Long MAX_SECONDS = 93599L;
    private static final String WHAT = 'time zone offset total seconds';

    /** The offset of UTC itself: zero. */
    public static final JiffOffset UTC = new JiffOffset(0);
    /** An offset of zero. The same value as `UTC`. */
    public static final JiffOffset ZERO = UTC;
    /** The most negative offset supported, `-25:59:59`. */
    public static final JiffOffset MIN = new JiffOffset(-93599);
    /** The most positive offset supported, `+25:59:59`. */
    public static final JiffOffset MAX = new JiffOffset(93599);

    private final Integer secs;

    private JiffOffset(Integer secs) {
        this.secs = secs;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Creates an offset of a whole number of hours, positive for east of UTC. Throws if the
     * offset is outside `-25:59:59..+25:59:59`, which in practice means outside `-25..25`.
     */
    public static JiffOffset fromHours(Integer hours) {
        return new JiffOffset(JiffMath.checkInt(hours * 3600L, -MAX_SECONDS, MAX_SECONDS, WHAT));
    }

    /** Creates an offset of a number of seconds, which must be in `-93,599..93,599`. */
    public static JiffOffset fromSeconds(Integer seconds) {
        return new JiffOffset(JiffMath.checkInt(seconds, -MAX_SECONDS, MAX_SECONDS, WHAT));
    }

    /**
     * Converts a duration to an offset, rounding a fractional second half away from zero.
     * Throws if the result is outside the supported range.
     */
    public static JiffOffset fromDuration(JiffSignedDuration duration) {
        Long seconds = duration.asSecs();
        Integer subsec = duration.subsecNanos();
        // Durations this close to the limits of a Long are far out of range, so the carry is
        // skipped for them rather than risk overflowing.
        if (subsec >= 500000000 && seconds != JiffMath.LONG_MAX) {
            seconds += 1;
        } else if (subsec <= -500000000 && seconds != JiffMath.LONG_MIN) {
            seconds -= 1;
        }
        if (
            JiffMath.lessThan(seconds, -MAX_SECONDS) || JiffMath.greaterThan(seconds, MAX_SECONDS)
        ) {
            throw new JiffException('signed duration overflows time zone offset');
        }
        return new JiffOffset(seconds.intValue());
    }

    // ---- accessors ------------------------------------------------------

    /** This offset as a number of seconds; negative for west of UTC. */
    public Integer seconds() {
        return secs;
    }

    /** The offset of the same size on the other side of UTC. */
    public JiffOffset negate() {
        return new JiffOffset(-secs);
    }

    /** -1, 0 or 1 according to whether this offset is behind, at, or ahead of UTC. */
    public Integer signum() {
        return secs < 0 ? -1 : (secs > 0 ? 1 : 0);
    }

    /** Whether this offset is ahead (east) of UTC. */
    public Boolean isPositive() {
        return secs > 0;
    }

    /** Whether this offset is behind (west) of UTC. */
    public Boolean isNegative() {
        return secs < 0;
    }

    /** Whether this offset is zero. */
    public Boolean isZero() {
        return secs == 0;
    }

    // ---- conversions ----------------------------------------------------

    /** A time zone that always uses this offset. The same as `JiffTimeZone.fixed(this)`. */
    public JiffTimeZone toTimeZone() {
        return JiffTimeZone.fixed(this);
    }

    /**
     * The civil datetime a clock at this offset shows at the given instant. This never fails:
     * the range of `JiffTimestamp` is chosen so that every instant has a civil datetime at
     * every offset.
     */
    public JiffDateTime toDateTime(JiffTimestamp timestamp) {
        Long second = timestamp.asSecond() + secs;
        Integer nanosecond = timestamp.subsecNanosecond();
        // A civil time counts its fraction forward from the whole second, so an instant
        // before the epoch borrows a second.
        if (nanosecond < 0) {
            second -= 1;
            nanosecond += 1000000000;
        }
        return JiffDateTime.fromEpochSecond(second, nanosecond);
    }

    /**
     * The instant at which a clock at this offset shows the given civil datetime. Throws if
     * that instant is outside the range of `JiffTimestamp`, which can only happen within about
     * a day of the limits of `JiffDateTime`.
     */
    public JiffTimestamp toTimestamp(JiffDateTime dt) {
        Long second = dt.toEpochSecond() - secs;
        Integer nanosecond = dt.subsecNanosecond();
        if (second < 0 && nanosecond != 0) {
            second += 1;
            nanosecond -= 1000000000;
        }
        try {
            return JiffTimestamp.newInstance(second, nanosecond);
        } catch (JiffException e) {
            throw new JiffException(
                'converting datetime with time zone offset `' +
                    toString() +
                    '` to timestamp overflowed: ' +
                    e.getMessage(),
                e
            );
        }
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * Adds a span to this offset. Only the whole seconds of the span count; any fraction of a
     * second is dropped. Throws if the span has non-zero units larger than hours or the result
     * is out of range.
     */
    public JiffOffset add(JiffSpan span) {
        JiffTimestamp.requireNoCalendarUnits(span);
        Long seconds = JiffMath.check(
            span.toInvariantDuration().asSecs(),
            -MAX_SECONDS,
            MAX_SECONDS,
            WHAT
        );
        return new JiffOffset(JiffMath.checkInt(seconds + secs, -MAX_SECONDS, MAX_SECONDS, WHAT));
    }

    /**
     * Adds a duration to this offset. Only the whole seconds of the duration count. Throws if
     * the result is out of range.
     */
    public JiffOffset add(JiffSignedDuration duration) {
        Long seconds = duration.asSecs();
        if (
            JiffMath.lessThan(seconds, -MAX_SECONDS) || JiffMath.greaterThan(seconds, MAX_SECONDS)
        ) {
            throw new JiffException(
                'adding signed duration to time zone offset overflowed: ' +
                JiffMath.rangeError(WHAT, -MAX_SECONDS, MAX_SECONDS).getMessage()
            );
        }
        return new JiffOffset(JiffMath.checkInt(seconds + secs, -MAX_SECONDS, MAX_SECONDS, WHAT));
    }

    /** Subtracts a span; the same as adding its negation. */
    public JiffOffset subtract(JiffSpan span) {
        return add(span.negate());
    }

    /** Subtracts a duration; the same as adding its negation. */
    public JiffOffset subtract(JiffSignedDuration duration) {
        return add(JiffTimestamp.negated(duration));
    }

    /**
     * Like `add`, except that a result beyond the supported range becomes `MIN` or `MAX`
     * instead of an error. A span with units larger than hours still throws.
     */
    public JiffOffset saturatingAdd(JiffSpan span) {
        JiffTimestamp.requireNoCalendarUnits(span);
        try {
            return add(span);
        } catch (JiffException e) {
            return span.isNegative() ? MIN : MAX;
        }
    }

    /** Like `add`, except that a result beyond the supported range becomes `MIN` or `MAX`. */
    public JiffOffset saturatingAdd(JiffSignedDuration duration) {
        try {
            return add(duration);
        } catch (JiffException e) {
            return duration.isNegative() ? MIN : MAX;
        }
    }

    /** Like `subtract`, except that the result saturates at `MIN` or `MAX`. */
    public JiffOffset saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /** Like `subtract`, except that the result saturates at `MIN` or `MAX`. */
    public JiffOffset saturatingSubtract(JiffSignedDuration duration) {
        // The most negative duration has no negation; subtracting it can only saturate upward.
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            return MAX;
        }
        return saturatingAdd(duration.negate());
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this offset to `other`, in seconds: positive when `other` is further east.
     * Unlike the other `until` methods this takes no options, exactly as in Jiff.
     */
    public JiffSpan until(JiffOffset other) {
        Long difference = other.secs - secs;
        return new JiffSpan().seconds(difference);
    }

    /** The span from `other` to this offset; the negation of `until`. */
    public JiffSpan since(JiffOffset other) {
        return until(other).negate();
    }

    /** The duration from this offset to `other`: positive when `other` is further east. */
    public JiffSignedDuration durationUntil(JiffOffset other) {
        Long difference = other.secs - secs;
        return JiffSignedDuration.fromSecs(difference);
    }

    /** The duration from `other` to this offset; the negation of `durationUntil`. */
    public JiffSignedDuration durationSince(JiffOffset other) {
        return other.durationUntil(this);
    }

    // ---- rounding -------------------------------------------------------

    /**
     * Rounds to the nearest multiple of `unit`, which must be hours, minutes or seconds. Ties
     * round away from zero.
     */
    public JiffOffset round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this offset. The smallest unit must be hours, minutes or seconds, and must be set
     * explicitly: `JiffRound` defaults to nanoseconds (Jiff's `OffsetRound` defaults to
     * seconds), which an offset cannot be rounded to. Throws if the rounded offset is out of
     * range, as it is when `MAX` is rounded to the nearest minute.
     */
    public JiffOffset round(JiffRound options) {
        Long increment = JiffRounding.incrementForOffset(
            options.getSmallest(),
            options.getIncrement()
        );
        Long seconds = secs;
        JiffSignedDuration rounded = JiffRounding.roundDuration(
            options.getMode(),
            JiffSignedDuration.fromSecs(seconds),
            options.getSmallest(),
            increment
        );
        Long roundedSeconds = rounded.asSecs();
        if (roundedSeconds < -MAX_SECONDS || roundedSeconds > MAX_SECONDS) {
            throw new JiffException(
                'rounding time zone offset resulted in a duration that overflows: ' +
                JiffMath.rangeError(WHAT, -MAX_SECONDS, MAX_SECONDS).getMessage()
            );
        }
        return new JiffOffset(roundedSeconds.intValue());
    }

    // ---- comparison -----------------------------------------------------

    public Integer compareTo(Object other) {
        JiffOffset that = (JiffOffset) other;
        return secs < that.secs ? -1 : (secs > that.secs ? 1 : 0);
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffOffset)) {
            return false;
        }
        return secs == ((JiffOffset) other).secs;
    }

    public Integer hashCode() {
        return secs;
    }

    /**
     * Formats this offset as compactly as it allows: `+00` for zero, `-05` for whole hours,
     * `+05:30` when there are minutes and `-00:44:30` when there are seconds. For the fixed
     * width `+HH:MM` form used inside RFC 3339 timestamps see `JiffTemporal.printOffset`.
     */
    public override String toString() {
        Integer magnitude = Math.abs(secs);
        Integer hours = magnitude / 3600;
        Integer minutes = Math.mod(magnitude / 60, 60);
        Integer seconds = Math.mod(magnitude, 60);
        if (magnitude == 0) {
            return '+00';
        }
        String out = (secs < 0 ? '-' : '+') + JiffMath.pad(hours, 2);
        if (minutes == 0 && seconds == 0) {
            return out;
        }
        out += ':' + JiffMath.pad(minutes, 2);
        return seconds == 0 ? out : out + ':' + JiffMath.pad(seconds, 2);
    }
}
