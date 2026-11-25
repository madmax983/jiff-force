/**
 * An instant in time: a count of nanoseconds since the Unix epoch, `1970-01-01T00:00:00Z`.
 *
 * A timestamp is always in UTC and always identifies one precise instant. It has no year,
 * month or hour of its own: to get civil fields, combine it with a `JiffOffset` or a
 * `JiffTimeZone` (`offset.toDateTime(ts)`, `tz.toDateTime(ts)`). Going the other way, from
 * what a clock shows to an instant, needs a time zone and may be ambiguous; see
 * `JiffTimeZone.toAmbiguousTimestamp`.
 *
 *     JiffTimestamp ts = JiffTimestamp.fromSecond(123456789L);
 *     ts.toString();                                    // 1973-11-29T21:33:09Z
 *     ts.add(new JiffSpan().hours(5)).toString();       // 1973-11-30T02:33:09Z
 *     JiffOffset.fromHours(-5).toDateTime(ts);          // 1973-11-29T16:33:09
 *
 * The count is kept as whole seconds plus a nanosecond remainder, and the two always share a
 * sign: half a second before the epoch is `0` seconds and `-500,000,000` nanoseconds. Every
 * getter reports values with that sign.
 *
 * The supported range is `-009999-01-02T01:59:59Z` through `9999-12-30T22:00:00.999999999Z`.
 * It is a day short of the civil range at each end so that every timestamp has a civil
 * datetime at every supported offset. There are no leap seconds.
 *
 * Arithmetic accepts a `JiffSignedDuration` or a `JiffSpan` whose units are hours or smaller.
 * A timestamp has no time zone, so it cannot know how long a day or a month is; use a zoned
 * datetime for calendar arithmetic.
 *
 * Instances are immutable and ordered chronologically.
 *
 * Mirrors `jiff::Timestamp`.
 */
public class JiffTimestamp implements Comparable {
    private static final Long MIN_SECOND = -377705023201L;
    private static final Long MAX_SECOND = 253402207200L;
    private static final Integer NANOS_PER_SEC = 1000000000;
    private static final String WHAT_SECONDS = 'Unix timestamp seconds';

    /** The earliest supported instant, `-009999-01-02T01:59:59Z`. */
    public static final JiffTimestamp MIN = new JiffTimestamp(MIN_SECOND, 0);
    /** The latest supported instant, `9999-12-30T22:00:00.999999999Z`. */
    public static final JiffTimestamp MAX = new JiffTimestamp(MAX_SECOND, 999999999);
    /** The Unix epoch, `1970-01-01T00:00:00Z`. */
    public static final JiffTimestamp UNIX_EPOCH = new JiffTimestamp(0L, 0);

    private final Long secs;
    private final Integer nanos;

    private JiffTimestamp(Long secs, Integer nanos) {
        this.secs = secs;
        this.nanos = nanos;
    }

    // ---- construction ---------------------------------------------------

    /** The current instant. The platform clock has millisecond precision. */
    public static JiffTimestamp now() {
        return fromMillisecond(System.currentTimeMillis());
    }

    /**
     * Creates a timestamp from seconds since the epoch plus a fraction in nanoseconds.
     *
     * The nanoseconds must be in `-999,999,999..999,999,999`. The two components need not have
     * the same sign: `newInstance(2, -999999999)` is one nanosecond past the first second.
     * Throws if either component is out of range or the instant is before `MIN`.
     */
    public static JiffTimestamp newInstance(Long second, Integer nanosecond) {
        JiffMath.check(second, MIN_SECOND, MAX_SECOND, WHAT_SECONDS);
        JiffMath.check(nanosecond, -999999999L, 999999999L, 'subsecond nanosecond');
        return balance(second, nanosecond);
    }

    /**
     * Builds a timestamp from in-range components whose signs may disagree, rejecting the one
     * combination that falls before `MIN`: the minimum second with a negative fraction.
     */
    private static JiffTimestamp balance(Long second, Integer nanosecond) {
        if (second == MIN_SECOND && nanosecond < 0) {
            throw JiffMath.rangeError(WHAT_SECONDS, MIN_SECOND, MAX_SECOND);
        }
        if (nanosecond == 0 || second == 0 || (second < 0) == (nanosecond < 0)) {
            return new JiffTimestamp(second, nanosecond);
        }
        if (second < 0) {
            return new JiffTimestamp(second + 1, nanosecond - NANOS_PER_SEC);
        }
        return new JiffTimestamp(second - 1, nanosecond + NANOS_PER_SEC);
    }

    /** Creates a timestamp a whole number of seconds from the epoch. Throws if out of range. */
    public static JiffTimestamp fromSecond(Long second) {
        return new JiffTimestamp(JiffMath.check(second, MIN_SECOND, MAX_SECOND, WHAT_SECONDS), 0);
    }

    /** Creates a timestamp a number of milliseconds from the epoch. Throws if out of range. */
    public static JiffTimestamp fromMillisecond(Long millisecond) {
        JiffMath.check(
            millisecond,
            MIN_SECOND * 1000L,
            MAX_SECOND * 1000L,
            'Unix timestamp milliseconds'
        );
        Long second = millisecond / 1000L;
        return new JiffTimestamp(second, (millisecond - second * 1000L).intValue() * 1000000);
    }

    /** Creates a timestamp a number of microseconds from the epoch. Throws if out of range. */
    public static JiffTimestamp fromMicrosecond(Long microsecond) {
        JiffMath.check(
            microsecond,
            MIN_SECOND * 1000000L,
            MAX_SECOND * 1000000L,
            'Unix timestamp microseconds'
        );
        Long second = microsecond / 1000000L;
        return new JiffTimestamp(second, (microsecond - second * 1000000L).intValue() * 1000);
    }

    /**
     * Creates a timestamp a number of nanoseconds from the epoch. A Long holds about 292 years
     * of nanoseconds either side of the epoch, all of which is in range, so this cannot fail.
     * Jiff takes an `i128` here; `fromNanosecondI128` covers the rest of the range.
     */
    public static JiffTimestamp fromNanosecond(Long nanosecond) {
        Long second = nanosecond / 1000000000L;
        return new JiffTimestamp(second, (nanosecond - second * 1000000000L).intValue());
    }

    /** Internal: creates a timestamp from a wide count of nanoseconds since the epoch. */
    public static JiffTimestamp fromNanosecondI128(JiffI128 nanosecond) {
        List<JiffI128> parts = nanosecond.divRem(JiffI128.valueOf(1000000000L));
        if (!parts.get(0).fitsLong()) {
            throw new JiffException(
                'parameter \'Unix timestamp nanoseconds\' is not in the required range of ' +
                '-377705023201000000000..=253402207200000000000'
            );
        }
        Long second = JiffMath.check(parts.get(0).toLong(), MIN_SECOND, MAX_SECOND, WHAT_SECONDS);
        return balance(second, parts.get(1).toLong().intValue());
    }

    /**
     * Creates the timestamp that is the given duration after the epoch (or before it, for a
     * negative duration). Throws if out of range.
     */
    public static JiffTimestamp fromDuration(JiffSignedDuration duration) {
        return newInstance(duration.asSecs(), duration.subsecNanos());
    }

    /**
     * Converts a platform `Datetime`, which has millisecond precision, to a timestamp. A null
     * `Datetime`, such as an empty record field, gives null. Throws if the `Datetime` is
     * outside the supported range.
     */
    public static JiffTimestamp fromSystemDatetime(Datetime value) {
        if (value == null) {
            return null;
        }
        return fromMillisecond(value.getTime());
    }

    /**
     * Parses an RFC 3339 timestamp, such as `2024-06-19T19:22:45Z`. This is the inverse of
     * `toString()`.
     *
     *     JiffTimestamp.parse('2024-06-19T19:22:45Z');
     *     JiffTimestamp.parse('2024-06-19T15:22:45-04:00');   // the same instant
     *     JiffTimestamp.parse('2024-06-19 19:22:45.123+00');  // space, fraction, short offset
     *     JiffTimestamp.parse('2024-06-19T15:22:45-04:00[America/New_York]');
     *                                                         // the annotation is ignored
     *
     * The string must have a time and an offset (`Z` or numeric), since otherwise it does not
     * identify an instant. See `JiffTemporal.parseTimestamp` for everything that is accepted.
     * Throws `JiffException` when the text is not a valid timestamp or is out of range, which
     * includes the instants less than a second before `MIN` that Jiff 1.0.0 lets through.
     *
     * Mirrors `impl FromStr for jiff::Timestamp`.
     */
    public static JiffTimestamp parse(String text) {
        return JiffTemporal.parseTimestamp(text);
    }

    // ---- accessors ------------------------------------------------------

    /** Whole seconds since the epoch, truncated toward zero. */
    public Long asSecond() {
        return secs;
    }

    /** Whole milliseconds since the epoch, truncated toward zero. */
    public Long asMillisecond() {
        return secs * 1000L + subsecMillisecond();
    }

    /** Whole microseconds since the epoch, truncated toward zero. */
    public Long asMicrosecond() {
        return secs * 1000000L + subsecMicrosecond();
    }

    /**
     * Nanoseconds since the epoch. Jiff returns an `i128` here; this throws instead when the
     * count does not fit in a Long, which happens beyond roughly 292 years either side of the
     * epoch (before 1677 or after 2262). See `asNanosecondI128` for the rest.
     */
    public Long asNanosecond() {
        return JiffMath.checkedAdd(
            JiffMath.checkedMul(secs, 1000000000L, 'timestamp nanoseconds'),
            nanos,
            'timestamp nanoseconds'
        );
    }

    /** Internal: nanoseconds since the epoch as a wide integer, for any timestamp. */
    public JiffI128 asNanosecondI128() {
        return JiffI128.ofSecondsAndNanos(secs, nanos);
    }

    /** The fraction of a second in whole milliseconds, `-999..999`, with the timestamp's sign. */
    public Integer subsecMillisecond() {
        return nanos / 1000000;
    }

    /** The fraction of a second in whole microseconds, with the timestamp's sign. */
    public Integer subsecMicrosecond() {
        return nanos / 1000;
    }

    /** The fraction of a second in nanoseconds, with the timestamp's sign. */
    public Integer subsecNanosecond() {
        return nanos;
    }

    /** The time elapsed since the epoch; negative for instants before it. */
    public JiffSignedDuration asDuration() {
        return JiffSignedDuration.newInstance(secs, nanos);
    }

    /** -1, 0 or 1 according to whether this instant is before, at, or after the epoch. */
    public Integer signum() {
        if (secs != 0) {
            return secs < 0 ? -1 : 1;
        }
        return nanos < 0 ? -1 : (nanos > 0 ? 1 : 0);
    }

    /** Whether this instant is the Unix epoch. */
    public Boolean isZero() {
        return secs == 0 && nanos == 0;
    }

    /**
     * Converts to a platform `Datetime`. A `Datetime` has millisecond precision, so anything
     * finer is dropped, truncating toward the epoch exactly as `asMillisecond` does.
     */
    public Datetime toSystemDatetime() {
        return Datetime.newInstance(asMillisecond());
    }

    /**
     * This instant as it reads in the given time zone: a zoned datetime that carries the
     * instant, the civil datetime and the time zone together. This never fails.
     *
     *     JiffTimestamp.UNIX_EPOCH.toZonedDateTime(JiffTimeZone.get('America/New_York'));
     *     // 1969-12-31T19:00:00-05:00[America/New_York]
     */
    public JiffZonedDateTime toZonedDateTime(JiffTimeZone tz) {
        return JiffZonedDateTime.newInstance(this, tz);
    }

    /**
     * This instant as it reads in the time zone with the given IANA name. Shorthand for
     * `toZonedDateTime(JiffTimeZone.get(name))`; throws if the platform does not know the
     * name.
     */
    public JiffZonedDateTime inTz(String name) {
        return toZonedDateTime(JiffTimeZone.get(name));
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * Throws when `span` has a non-zero unit larger than hours. Internal: shared by the types
     * that only accept time units in arithmetic.
     */
    public static void requireNoCalendarUnits(JiffSpan span) {
        JiffUnit unit = span.largestCalendarUnit();
        if (unit != null) {
            throw new JiffException(
                'operation can only be performed with units of hours or smaller, but found ' +
                    'non-zero \'' +
                    JiffMath.singular(unit) +
                    '\' units (operations on `JiffTimestamp`, `JiffOffset` and `JiffTime` ' +
                    'don\'t support calendar units in a `JiffSpan`)'
            );
        }
    }

    /**
     * Adds a span of hours or smaller units. Throws if the span has a non-zero unit larger
     * than hours (a timestamp cannot know how long a day is) or the result is out of range.
     */
    public JiffTimestamp add(JiffSpan span) {
        requireNoCalendarUnits(span);
        if (span.isZero()) {
            return this;
        }
        if (nanos == 0 && !span.hasFractionalSeconds()) {
            Long second = secs + span.toHmsSeconds();
            if (second < MIN_SECOND || second > MAX_SECOND) {
                throw new JiffException(
                    'adding span overflowed timestamp: ' +
                    JiffMath.rangeError(WHAT_SECONDS, MIN_SECOND, MAX_SECOND).getMessage()
                );
            }
            return new JiffTimestamp(second, 0);
        }
        return fromDuration(asDuration().add(span.toInvariantDuration()));
    }

    /** Adds an exact duration. Throws if the result is out of range. */
    public JiffTimestamp add(JiffSignedDuration duration) {
        JiffSignedDuration sum;
        try {
            sum = asDuration().add(duration);
        } catch (JiffException e) {
            throw new JiffException('adding duration overflowed timestamp', e);
        }
        return fromDuration(sum);
    }

    /** Subtracts a span; the same as adding its negation. */
    public JiffTimestamp subtract(JiffSpan span) {
        return add(span.negate());
    }

    /** Subtracts an exact duration; the same as adding its negation. */
    public JiffTimestamp subtract(JiffSignedDuration duration) {
        return add(negated(duration));
    }

    /**
     * Negates a duration that is about to be subtracted. Internal: the most negative duration
     * has no negation, and Jiff reports that in terms of the unsigned duration it would need.
     */
    public static JiffSignedDuration negated(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            throw new JiffException(
                'unsigned duration exceeds Jiff\'s limits: ' +
                JiffMath.rangeError('signed duration seconds', JiffMath.LONG_MIN, JiffMath.LONG_MAX)
                    .getMessage()
            );
        }
        return duration.negate();
    }

    /**
     * Like `add`, except that a result beyond the supported range becomes `MIN` or `MAX`
     * instead of an error. A span with units larger than hours still throws.
     */
    public JiffTimestamp saturatingAdd(JiffSpan span) {
        requireNoCalendarUnits(span);
        try {
            return add(span);
        } catch (JiffException e) {
            return span.isNegative() ? MIN : MAX;
        }
    }

    /** Like `add`, except that a result beyond the supported range becomes `MIN` or `MAX`. */
    public JiffTimestamp saturatingAdd(JiffSignedDuration duration) {
        try {
            return add(duration);
        } catch (JiffException e) {
            return duration.isNegative() ? MIN : MAX;
        }
    }

    /** Like `subtract`, except that the result saturates at `MIN` or `MAX`. */
    public JiffTimestamp saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /** Like `subtract`, except that the result saturates at `MIN` or `MAX`. */
    public JiffTimestamp saturatingSubtract(JiffSignedDuration duration) {
        // The most negative duration has no negation; subtracting it can only saturate upward.
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            return MAX;
        }
        return saturatingAdd(duration.negate());
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this timestamp to `other`, in seconds and fractions of a second. It is
     * negative when `other` is earlier. This never fails.
     */
    public JiffSpan until(JiffTimestamp other) {
        return until(other, JiffUnit.SECOND);
    }

    /**
     * The span from this timestamp to `other`, balanced so that `largest` is its biggest unit.
     *
     * `largest` may be hours or smaller; anything larger throws, because a timestamp has no
     * time zone to say how long a day is. Asking for a small unit can also throw: a span
     * cannot hold more than about 292 years of nanoseconds.
     *
     * Nothing is rounded here; `until(JiffTimestamp, JiffDifference)` can also round the
     * result.
     */
    public JiffSpan until(JiffTimestamp other, JiffUnit largest) {
        if (largest == null) {
            throw new JiffException('largest unit must not be null');
        }
        if (largest.ordinal() >= JiffUnit.DAY.ordinal()) {
            throw new JiffException(
                'rounding to \'' + JiffMath.plural(largest) + '\' is not supported'
            );
        }
        return JiffSpan.fromInvariantDuration(largest, durationUntil(other));
    }

    /** The span from `other` to this timestamp, in seconds; the negation of `until`. */
    public JiffSpan since(JiffTimestamp other) {
        return until(other).negate();
    }

    /** The span from `other` to this timestamp with `largest` as its biggest unit. */
    public JiffSpan since(JiffTimestamp other, JiffUnit largest) {
        return until(other, largest).negate();
    }

    /**
     * The span from this timestamp to `other`, with the units and rounding `options` ask for.
     *
     * The smallest unit defaults to `NANOSECOND`, and the largest to the bigger of `SECOND`
     * and the smallest unit; it must be hours or smaller. When the smallest unit is bigger
     * than a nanosecond, or the increment is not 1, the difference is rounded as
     * `JiffSpan.round` does.
     *
     *     JiffTimestamp t1 = JiffTimestamp.parse('2024-03-15T08:14:00.5Z');
     *     JiffTimestamp t2 = JiffTimestamp.parse('2024-03-15T10:00:00Z');
     *     t1.until(t2, new JiffDifference().largest(JiffUnit.HOUR).smallest(JiffUnit.MINUTE));
     *     // PT1H45M
     *
     * Throws when a unit is a day or bigger, the increment is not valid for the smallest
     * unit, or the result does not fit.
     *
     * Mirrors `Timestamp::until` with a `TimestampDifference`.
     */
    public JiffSpan until(JiffTimestamp other, JiffDifference options) {
        return difference(other, options, false);
    }

    /**
     * The span from `other` to this timestamp, with the units and rounding `options` ask for:
     * `until(other, options)` before rounding, negated. See
     * `until(JiffTimestamp, JiffDifference)`.
     *
     * Mirrors `Timestamp::since` with a `TimestampDifference`.
     */
    public JiffSpan since(JiffTimestamp other, JiffDifference options) {
        return difference(other, options, true);
    }

    private JiffSpan difference(JiffTimestamp other, JiffDifference options, Boolean negate) {
        JiffDifference config = options == null ? new JiffDifference() : options;
        JiffUnit smallest = config.getSmallest() == null
            ? JiffUnit.NANOSECOND
            : config.getSmallest();
        JiffUnit largest = config.getLargest() == null
            ? JiffMath.largerOf(smallest, JiffUnit.SECOND)
            : config.getLargest();
        JiffSpan span = until(other, largest);
        return JiffSpanRelative.roundDifference(
            negate ? span.negate() : span,
            config,
            smallest,
            null,
            false
        );
    }

    /** The exact time from this timestamp to `other`; negative when `other` is earlier. */
    public JiffSignedDuration durationUntil(JiffTimestamp other) {
        return other.asDuration().subtract(asDuration());
    }

    /** The exact time from `other` to this timestamp; negative when `other` is later. */
    public JiffSignedDuration durationSince(JiffTimestamp other) {
        return asDuration().subtract(other.asDuration());
    }

    // ---- rounding -------------------------------------------------------

    /** Rounds to the nearest multiple of `unit` (hours or smaller), ties away from zero. */
    public JiffTimestamp round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this timestamp.
     *
     * The smallest unit must be hours or smaller, and the increment must divide evenly into
     * one 24 hour day: 15 minutes and 45 seconds are allowed, 7 seconds and 25 minutes are
     * not. Rounding is done on the count since the epoch, so "away from zero" means away
     * from the epoch. Throws if the result is out of range.
     */
    public JiffTimestamp round(JiffRound options) {
        Long increment = JiffRounding.incrementForTimestamp(
            options.getSmallest(),
            options.getIncrement()
        );
        return fromDuration(
            JiffRounding.roundDuration(
                options.getMode(),
                asDuration(),
                options.getSmallest(),
                increment
            )
        );
    }

    // ---- series and text ------------------------------------------------

    /**
     * An unending series of timestamps that starts at this one and steps by `period`, which
     * may be negative to walk backward. The series stops at the limits of `JiffTimestamp`. A
     * period with a non-zero unit larger than hours yields an empty series.
     */
    public JiffTimestampSeries series(JiffSpan period) {
        return new JiffTimestampSeries(this, period);
    }

    /**
     * Formats this instant as an RFC 3339 timestamp with the given offset instead of `Z`, for
     * example `1969-12-31T19:00:01-05:00`. The offset is written as `+HH:MM`, rounded to the
     * nearest minute. Jiff's `display_with_offset`.
     */
    public String toStringWithOffset(JiffOffset offset) {
        return JiffTemporal.printTimestampWithOffset(this, offset);
    }

    // ---- comparison -----------------------------------------------------

    public Integer compareTo(Object other) {
        JiffTimestamp that = (JiffTimestamp) other;
        if (secs != that.secs) {
            return secs < that.secs ? -1 : 1;
        }
        return nanos < that.nanos ? -1 : (nanos > that.nanos ? 1 : 0);
    }

    public Boolean isBefore(JiffTimestamp other) {
        return compareTo(other) < 0;
    }

    public Boolean isAfter(JiffTimestamp other) {
        return compareTo(other) > 0;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffTimestamp)) {
            return false;
        }
        JiffTimestamp that = (JiffTimestamp) other;
        return secs == that.secs && nanos == that.nanos;
    }

    public Integer hashCode() {
        return JiffMath.floorMod(JiffMath.floorMod(secs, 1000000007L) * 31 + nanos, 1000000007L)
            .intValue();
    }

    // ---- strftime / strptime ------------------------------------------------

    /**
     * Parses a timestamp from `input` according to the `strptime` format `format`. The
     * conversion specifiers are listed in `JiffStrtime`.
     *
     *     JiffTimestamp.strptime('%F %H:%M %:z', '2024-07-14 21:14 -04:00');
     *     // 2024-07-15T01:14:00Z
     *
     * Throws `JiffException` when the format is invalid, when the input does not match it, or
     * when the input has neither a Unix timestamp (`%s`) nor a datetime with an offset.
     *
     * Mirrors `jiff::Timestamp::strptime`.
     */
    public static JiffTimestamp strptime(String format, String input) {
        return JiffStrtime.parse(format, input).toTimestamp();
    }

    /**
     * Formats this timestamp according to the `strftime` format `format`. The conversion
     * specifiers are listed in `JiffStrtime`.
     *
     *     JiffTimestamp.fromSecond(86400L).strftime('%a %b %e %I:%M:%S %p UTC %Y');
     *     // Fri Jan  2 12:00:00 AM UTC 1970
     *
     * This never throws for a non-null format. A specifier that cannot be applied, such as
     * `%Z` (a timestamp has no time zone), or an unknown one, is written out literally. To
     * have such mistakes reported instead, use `JiffStrtime.format`.
     *
     * Mirrors `jiff::Timestamp::strftime`.
     */
    public String strftime(String format) {
        return JiffStrtime.formatLenient(format, JiffBrokenDownTime.fromTimestamp(this));
    }

    /** Formats this instant as an RFC 3339 timestamp in UTC, for example `2024-06-19T19:22:45Z`. */
    public override String toString() {
        return JiffTemporal.printTimestamp(this);
    }
}
