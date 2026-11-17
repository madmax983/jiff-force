/**
 * A time of day with nanosecond precision and no date or time zone: what a wall clock shows.
 *
 *     JiffTime time = JiffTime.newInstance(15, 22, 45, 123000000);
 *     time.hour();         // 15
 *     time.millisecond();  // 123
 *     time.toString();     // 15:22:45.123
 *
 * The supported range is `00:00:00` through `23:59:59.999999999`. There is no leap second.
 * Instances are immutable and ordered from midnight onward.
 *
 * ## Arithmetic
 *
 * A `JiffSpan` or a `JiffSignedDuration` can be added to or subtracted from a time in three
 * ways, which differ only in what happens when the result leaves the day:
 *
 * - `wrappingAdd` / `wrappingSubtract` wrap around midnight, the way a clock does. This is
 *   what Jiff's `+` and `-` operators do.
 * - `add` / `subtract` throw `JiffException`.
 * - `saturatingAdd` / `saturatingSubtract` stop at `MIN` or `MAX`.
 *
 *     JiffTime t = JiffTime.newInstance(23, 30, 0, 0);
 *     t.wrappingAdd(new JiffSpan().hours(1));    // 00:30:00
 *     t.saturatingAdd(new JiffSpan().hours(1));  // 23:59:59.999999999
 *     t.add(new JiffSpan().hours(1));            // throws JiffException
 *
 * `until` and `since` give the span between two times, `durationUntil` and `durationSince`
 * give it as an absolute duration, `round` rounds to a unit and `series` steps through the
 * day at a fixed interval.
 *
 * Mirrors `jiff::civil::Time`.
 */
public class JiffTime implements Comparable {
    /** The first moment of the day, `00:00:00`. */
    public static final JiffTime MIN = new JiffTime(0, 0, 0, 0);
    /** The last representable moment of the day, `23:59:59.999999999`. */
    public static final JiffTime MAX = new JiffTime(23, 59, 59, 999999999);

    // 2^64 and 2^63: the modulus and the sign boundary of 64 bit wrapping arithmetic.
    private static final JiffI128 TWO_POW_64 = JiffI128.parse('18446744073709551616');
    private static final JiffI128 TWO_POW_63 = JiffI128.parse('9223372036854775808');

    private final Integer hourValue;
    private final Integer minuteValue;
    private final Integer secondValue;
    private final Integer subsecValue;

    private JiffTime(
        Integer hourValue,
        Integer minuteValue,
        Integer secondValue,
        Integer subsecValue
    ) {
        this.hourValue = hourValue;
        this.minuteValue = minuteValue;
        this.secondValue = secondValue;
        this.subsecValue = subsecValue;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Creates a time from an hour (`0..23`), minute (`0..59`), second (`0..59`) and fractional
     * second in nanoseconds (`0..999,999,999`). Throws if any component is out of range.
     */
    public static JiffTime newInstance(
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        JiffMath.check(hour, 0L, 23L, 'hour');
        JiffMath.check(minute, 0L, 59L, 'minute');
        JiffMath.check(second, 0L, 59L, 'second');
        JiffMath.check(subsecNanosecond, 0L, 999999999L, 'subsecond nanosecond');
        return new JiffTime(hour, minute, second, subsecNanosecond);
    }

    /** The first moment of the day, `00:00:00`. */
    public static JiffTime midnight() {
        return MIN;
    }

    /**
     * Creates a time from the number of nanoseconds since midnight, which must be within one
     * civil day (`0..86,399,999,999,999`).
     */
    public static JiffTime fromNanosecondOfDay(Long nanosecond) {
        JiffMath.check(
            nanosecond,
            0L,
            JiffMath.NANOS_PER_CIVIL_DAY - 1,
            'nanoseconds (in one civil day)'
        );
        Long secondOfDay = nanosecond / JiffMath.NANOS_PER_SEC;
        return new JiffTime(
            (secondOfDay / 3600).intValue(),
            (JiffMath.truncMod(secondOfDay, 3600L) / 60).intValue(),
            JiffMath.truncMod(secondOfDay, 60L).intValue(),
            JiffMath.truncMod(nanosecond, JiffMath.NANOS_PER_SEC).intValue()
        );
    }

    /**
     * Creates a time from a platform `Time`. A platform `Time` has millisecond precision, so
     * the microsecond and nanosecond components of the result are always zero.
     *
     *     JiffTime.fromSystemTime(Time.newInstance(15, 22, 45, 123));  // 15:22:45.123
     */
    public static JiffTime fromSystemTime(Time value) {
        if (value == null) {
            throw new JiffException('cannot convert a null system time to a `JiffTime`');
        }
        return new JiffTime(
            value.hour(),
            value.minute(),
            value.second(),
            value.millisecond() * 1000000
        );
    }

    /**
     * Starts building a new time from the fields of this one. Set any of the fields on the
     * returned `JiffTimeWith`, then call `build()`. Fields that are not set keep their value.
     *
     *     JiffTime t1 = JiffTime.newInstance(0, 0, 24, 0);
     *     JiffTime t2 = t1.with().hour(15).minute(30).millisecond(10).build();  // 15:30:24.01
     */
    public JiffTimeWith with() {
        return new JiffTimeWith(this);
    }

    // ---- accessors ------------------------------------------------------

    /** The hour, in `0..23`. */
    public Integer hour() {
        return hourValue;
    }

    /** The minute, in `0..59`. */
    public Integer minute() {
        return minuteValue;
    }

    /** The second, in `0..59`. */
    public Integer second() {
        return secondValue;
    }

    /** The millisecond component of the fractional second, in `0..999`. */
    public Integer millisecond() {
        return subsecValue / 1000000;
    }

    /** The microsecond component of the fractional second, in `0..999`. */
    public Integer microsecond() {
        return Math.mod(subsecValue / 1000, 1000);
    }

    /** The nanosecond component of the fractional second, in `0..999`. */
    public Integer nanosecond() {
        return Math.mod(subsecValue, 1000);
    }

    /** The whole fractional second in nanoseconds, in `0..999,999,999`. */
    public Integer subsecNanosecond() {
        return subsecValue;
    }

    /** The number of nanoseconds since midnight. */
    public Long toNanosecondOfDay() {
        Long secondOfDay = hourValue * 3600L + minuteValue * 60L + secondValue;
        return secondOfDay * JiffMath.NANOS_PER_SEC + subsecValue;
    }

    /** The number of whole seconds since midnight. */
    public Integer toSecondOfDay() {
        return hourValue * 3600 + minuteValue * 60 + secondValue;
    }

    /**
     * Converts this time to a platform `Time`. A platform `Time` has millisecond precision, so
     * the microsecond and nanosecond components are dropped. The value is truncated, never
     * rounded: `23:59:59.999999999` becomes `23:59:59.999`.
     */
    public Time toSystemTime() {
        return Time.newInstance(hourValue, minuteValue, secondValue, millisecond());
    }

    // ---- wrapping arithmetic --------------------------------------------

    /**
     * Adds a span to this time, wrapping around midnight the way a clock does.
     *
     * Only the hours through nanoseconds of the span take part. Days and larger units are
     * whole turns of the clock, so they are ignored.
     *
     *     JiffTime t = JiffTime.newInstance(20, 10, 1, 0);
     *     t.wrappingAdd(new JiffSpan().hours(1).minutes(49).seconds(59));  // 22:00:00
     *     JiffTime.MAX.wrappingAdd(new JiffSpan().nanoseconds(1));         // 00:00:00
     *     t.wrappingAdd(new JiffSpan().days(1));                           // 20:10:01
     */
    public JiffTime wrappingAdd(JiffSpan span) {
        JiffI128 sum = span.toInvariantDurationTimeOnly().asNanosI128().add(toNanosecondOfDay());
        // Jiff forms this sum in a 64 bit integer that itself wraps on overflow, and only
        // then reduces it to a time of day. A day does not divide 2^64, so for spans beyond
        // roughly 292 years that is a different answer from reducing the exact sum. The port
        // reproduces Jiff's answer rather than the mathematically "right" one.
        return ofWrappedNanosecond(sum.fitsLong() ? sum.toLong() : wrapToLong(sum));
    }

    /**
     * Adds an absolute duration to this time, wrapping around midnight the way a clock does.
     *
     *     JiffTime.MAX.wrappingAdd(JiffSignedDuration.fromNanos(1));  // 00:00:00
     */
    public JiffTime wrappingAdd(JiffSignedDuration duration) {
        return ofWrappedNanosecond(toNanosecondOfDay() + nanosecondOfDay(duration));
    }

    /**
     * Subtracts a span from this time, wrapping around midnight the way a clock does. The
     * same as `wrappingAdd` with the span negated.
     *
     *     JiffTime.MIN.wrappingSubtract(new JiffSpan().nanoseconds(1));  // 23:59:59.999999999
     */
    public JiffTime wrappingSubtract(JiffSpan span) {
        return wrappingAdd(span.negate());
    }

    /**
     * Subtracts an absolute duration from this time, wrapping around midnight the way a clock
     * does. Unlike `subtract`, this accepts every duration, including `JiffSignedDuration.MIN`.
     *
     *     JiffTime.MIN.wrappingSubtract(JiffSignedDuration.fromNanos(1));  // 23:59:59.999999999
     */
    public JiffTime wrappingSubtract(JiffSignedDuration duration) {
        return ofWrappedNanosecond(toNanosecondOfDay() - nanosecondOfDay(duration));
    }

    /**
     * Where a clock that started at midnight would point after `duration`, in nanoseconds
     * since midnight. A negative fraction can leave the result just below zero.
     */
    private static Long nanosecondOfDay(JiffSignedDuration duration) {
        // Not `floorMod`: its intermediate product overflows for seconds near `LONG_MIN`.
        Long secondOfDay = JiffMath.truncMod(duration.asSecs(), JiffMath.SECS_PER_CIVIL_DAY);
        if (secondOfDay < 0) {
            secondOfDay += JiffMath.SECS_PER_CIVIL_DAY;
        }
        return secondOfDay * JiffMath.NANOS_PER_SEC + duration.subsecNanos();
    }

    /** The time of day for a count of nanoseconds that may lie outside the day. */
    private static JiffTime ofWrappedNanosecond(Long nanosecond) {
        return fromNanosecondOfDay(JiffMath.floorMod(nanosecond, JiffMath.NANOS_PER_CIVIL_DAY));
    }

    /** Reduces `value` to the 64 bit two's complement integer that wrapping arithmetic gives. */
    private static Long wrapToLong(JiffI128 value) {
        JiffI128 wrapped = value.remainder(TWO_POW_64);
        if (wrapped.compareTo(TWO_POW_63) >= 0) {
            wrapped = wrapped.subtract(TWO_POW_64);
        } else if (wrapped.compareTo(TWO_POW_63.negate()) < 0) {
            wrapped = wrapped.add(TWO_POW_64);
        }
        return wrapped.toLong();
    }

    // ---- checked arithmetic ---------------------------------------------

    /**
     * Adds a span to this time. Throws if the result would fall outside the day, or if the
     * span has any non-zero unit larger than hours.
     *
     *     JiffTime t = JiffTime.newInstance(20, 10, 1, 0);
     *     t.add(new JiffSpan().hours(1).minutes(49).seconds(59));  // 22:00:00
     *     JiffTime.MAX.add(new JiffSpan().nanoseconds(1));         // throws
     *     t.add(new JiffSpan().days(1));                           // throws
     */
    public JiffTime add(JiffSpan span) {
        Overflow sum = overflowingAdd(span);
        if (sum.days() != 0) {
            throw overflowed();
        }
        return sum.toTime();
    }

    /**
     * Adds an absolute duration to this time. Throws if the result would fall outside the day.
     *
     *     JiffTime t = JiffTime.newInstance(23, 0, 0, 0);
     *     t.add(JiffSignedDuration.fromMins(30));   // 23:30:00
     *     t.add(JiffSignedDuration.fromMins(-30));  // 22:30:00
     *     t.add(JiffSignedDuration.fromHours(1));   // throws
     */
    public JiffTime add(JiffSignedDuration duration) {
        if (!duration.fitsNanos()) {
            throw overflowed();
        }
        Long start = toNanosecondOfDay();
        Long nanos = duration.asNanos();
        // `start` is never negative, so the sum can only overflow upward.
        if (JiffMath.greaterThan(nanos, JiffMath.LONG_MAX - start)) {
            throw overflowed();
        }
        return fromNanosecondOfDay(start + nanos);
    }

    /**
     * Subtracts a span from this time. The same as `add` with the span negated, and it throws
     * in the same circumstances.
     *
     *     JiffTime t = JiffTime.newInstance(22, 0, 0, 0);
     *     t.subtract(new JiffSpan().hours(1).minutes(49).seconds(59));  // 20:10:01
     */
    public JiffTime subtract(JiffSpan span) {
        return add(span.negate());
    }

    /**
     * Subtracts an absolute duration from this time. The same as `add` with the duration
     * negated, and it throws in the same circumstances.
     *
     *     JiffTime.newInstance(22, 0, 0, 0).subtract(JiffSignedDuration.fromHours(1));  // 21:00:00
     */
    public JiffTime subtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Jiff negates such a duration into an unsigned one, which it then cannot turn
            // back into a signed duration. The port reports that failure in Jiff's words.
            throw new JiffException(
                'unsigned duration exceeds Jiff\'s limits: ' +
                JiffMath.rangeError('signed duration seconds', JiffMath.LONG_MIN, JiffMath.LONG_MAX)
                    .getMessage()
            );
        }
        return add(duration.negate());
    }

    private static JiffException overflowed() {
        return new JiffException('adding duration to time overflowed');
    }

    // ---- saturating arithmetic ------------------------------------------

    /**
     * Adds a span to this time, stopping at `MIN` or `MAX` instead of leaving the day.
     *
     * A span with a non-zero unit larger than hours always saturates, toward `MAX` when the
     * span is positive and toward `MIN` when it is negative.
     *
     *     JiffTime.MAX.saturatingAdd(new JiffSpan().nanoseconds(1));  // 23:59:59.999999999
     *     JiffTime.MIN.saturatingAdd(new JiffSpan().days(1));         // 23:59:59.999999999
     */
    public JiffTime saturatingAdd(JiffSpan span) {
        try {
            return add(span);
        } catch (JiffException e) {
            return span.isNegative() ? MIN : MAX;
        }
    }

    /**
     * Adds an absolute duration to this time, stopping at `MIN` or `MAX` instead of leaving
     * the day.
     *
     *     JiffTime.MAX.saturatingAdd(JiffSignedDuration.MAX);  // 23:59:59.999999999
     *     JiffTime.MAX.saturatingAdd(JiffSignedDuration.MIN);  // 00:00:00
     */
    public JiffTime saturatingAdd(JiffSignedDuration duration) {
        try {
            return add(duration);
        } catch (JiffException e) {
            return duration.isNegative() ? MIN : MAX;
        }
    }

    /**
     * Subtracts a span from this time, stopping at `MIN` or `MAX` instead of leaving the day.
     * The same as `saturatingAdd` with the span negated.
     *
     *     JiffTime.MIN.saturatingSubtract(new JiffSpan().nanoseconds(1));  // 00:00:00
     */
    public JiffTime saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /**
     * Subtracts an absolute duration from this time, stopping at `MIN` or `MAX` instead of
     * leaving the day. The same as `saturatingAdd` with the duration negated.
     *
     *     JiffTime.MIN.saturatingSubtract(JiffSignedDuration.MAX);  // 00:00:00
     *     JiffTime.MIN.saturatingSubtract(JiffSignedDuration.MIN);  // 23:59:59.999999999
     */
    public JiffTime saturatingSubtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Too negative to negate, so subtracting it overshoots every time of day.
            return MAX;
        }
        return saturatingAdd(duration.negate());
    }

    // ---- arithmetic that carries into days (internal) ---------------------

    /**
     * Internal: adds a span to this time and reports how many days the sum carried.
     *
     * This is the building block for datetime arithmetic and is not meant for general use.
     * The result holds the wrapped time of day (`toTime()`) and the whole number of civil
     * days, always 24 hours long, that were carried out of it (`days()`). The carry is
     * negative when the sum fell before midnight: `00:00:00` plus `-1s` is `23:59:59`
     * carrying `-1`.
     *
     * Throws if the span has a non-zero unit larger than hours (callers add those to the date
     * themselves, so pass `span.onlyLower(JiffUnit.DAY)`), or if the carry exceeds the largest
     * number of days a `JiffSpan` can hold.
     *
     * Mirrors the crate-private `jiff::civil::Time::overflowing_add`.
     */
    public Overflow overflowingAdd(JiffSpan span) {
        JiffUnit calendar = span.largestCalendarUnit();
        if (calendar != null) {
            throw new JiffException(
                'operation can only be performed with units of hours or smaller, ' +
                    'but found non-zero \'' +
                    JiffMath.singular(calendar) +
                    '\' units (operations on `JiffTimestamp`, `JiffOffset` and `JiffTime` ' +
                    'don\'t support calendar units in a `JiffSpan`)'
            );
        }
        return overflowingAdd(span.toInvariantDurationTimeOnly());
    }

    /**
     * Internal: adds an absolute duration to this time and reports how many days the sum
     * carried. See `overflowingAdd(JiffSpan)`, which this otherwise matches; a duration has
     * no calendar units, so the only failure is a carry of more days than a `JiffSpan` can
     * hold.
     *
     * Mirrors the crate-private `jiff::civil::Time::overflowing_add_duration`.
     */
    public Overflow overflowingAdd(JiffSignedDuration duration) {
        // Split off the whole days first, so that nothing below can overflow a Long even for
        // the largest durations. Both parts take the sign of the duration.
        Long days = duration.asSecs() / JiffMath.SECS_PER_CIVIL_DAY;
        Long seconds = JiffMath.truncMod(duration.asSecs(), JiffMath.SECS_PER_CIVIL_DAY);
        Long nanosecond =
            toNanosecondOfDay() +
            seconds * JiffMath.NANOS_PER_SEC +
            duration.subsecNanos();
        days += JiffMath.floorDiv(nanosecond, JiffMath.NANOS_PER_CIVIL_DAY);
        // Jiff hands the carry back as a span of days; this applies that span's limit.
        new JiffSpan().days(days);
        return new Overflow(ofWrappedNanosecond(nanosecond), days);
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this time until `other`, using hours as the largest unit. The span is
     * negative when `other` is earlier than this time.
     *
     *     JiffTime t1 = JiffTime.newInstance(22, 35, 1, 0);
     *     JiffTime t2 = JiffTime.newInstance(22, 35, 3, 500000000);
     *     t1.until(t2);  // PT2.5S
     *     t2.until(t1);  // -PT2.5S
     *
     * Adding the result to this time always gives `other` back.
     */
    public JiffSpan until(JiffTime other) {
        return until(other, JiffUnit.HOUR);
    }

    /**
     * The span from this time until `other`, balanced so that `largest` is its biggest unit.
     * Throws if `largest` is bigger than hours.
     *
     *     JiffTime t1 = JiffTime.newInstance(3, 24, 30, 3500);
     *     JiffTime t2 = JiffTime.newInstance(15, 30, 0, 0);
     *     t1.until(t2);                   // PT12H5M29.9999965S
     *     t1.until(t2, JiffUnit.MINUTE);  // PT725M29.9999965S
     */
    public JiffSpan until(JiffTime other, JiffUnit largest) {
        if (JiffMath.isCalendar(largest)) {
            throw new JiffException(
                '\'' +
                    JiffMath.singular(largest) +
                    '\' not allowed as a time unit for rounding span'
            );
        }
        return JiffSpan.fromInvariantDuration(largest, durationUntil(other));
    }

    /**
     * The span from `other` until this time, using hours as the largest unit: `until` with the
     * operands swapped. The span is negative when `other` is later than this time.
     *
     *     JiffTime.newInstance(22, 30, 0, 0).since(JiffTime.newInstance(1, 0, 0, 0));  // PT21H30M
     */
    public JiffSpan since(JiffTime other) {
        return since(other, JiffUnit.HOUR);
    }

    /**
     * The span from `other` until this time, balanced so that `largest` is its biggest unit.
     * Throws if `largest` is bigger than hours.
     *
     *     JiffTime t1 = JiffTime.newInstance(23, 30, 0, 0);
     *     t1.since(JiffTime.newInstance(7, 0, 0, 0), JiffUnit.MINUTE);  // PT990M
     */
    public JiffSpan since(JiffTime other, JiffUnit largest) {
        return until(other, largest).negate();
    }

    /**
     * The absolute duration from this time until `other`. It is negative when `other` is
     * earlier than this time, and its magnitude is always less than 24 hours.
     *
     *     JiffTime t1 = JiffTime.newInstance(22, 35, 1, 0);
     *     JiffTime t2 = JiffTime.newInstance(22, 35, 3, 500000000);
     *     t1.durationUntil(t2);  // PT2.5S
     *     t2.durationUntil(t1);  // -PT2.5S
     */
    public JiffSignedDuration durationUntil(JiffTime other) {
        return JiffSignedDuration.fromNanos(other.toNanosecondOfDay() - toNanosecondOfDay());
    }

    /**
     * The absolute duration from `other` until this time: `durationUntil` with the operands
     * swapped.
     *
     *     JiffTime later = JiffTime.newInstance(22, 30, 0, 0);
     *     later.durationSince(JiffTime.newInstance(1, 0, 0, 0));  // PT21H30M
     */
    public JiffSignedDuration durationSince(JiffTime other) {
        return other.durationUntil(this);
    }

    // ---- rounding -------------------------------------------------------

    /**
     * Rounds this time to the nearest multiple of `unit`, with ties rounding up.
     *
     *     JiffTime.newInstance(15, 45, 10, 500000001).round(JiffUnit.SECOND);  // 15:45:11
     *     JiffTime.MAX.round(JiffUnit.HOUR);                                   // 00:00:00
     */
    public JiffTime round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this time according to `options`: a smallest unit, a rounding mode and a rounding
     * increment.
     *
     *     // The nearest five minutes.
     *     JiffTime t = JiffTime.newInstance(15, 27, 30, 0);
     *     t.round(JiffRound.to(JiffUnit.MINUTE).increment(5));  // 15:30:00
     *
     * The smallest unit must be hours or smaller, and the increment must divide evenly into
     * the next unit up without being equal to it: with minutes, `1`, `5`, `15` and `30` are
     * fine but `7` and `60` are not. Those are the only ways this can fail. Rounding up past
     * the end of the day wraps around to `00:00:00`.
     */
    public JiffTime round(JiffRound options) {
        Long increment;
        try {
            increment = JiffRounding.incrementForTime(
                options.getSmallest(),
                options.getIncrement()
            );
        } catch (JiffException e) {
            throw new JiffException('failed rounding time: ' + e.getMessage(), e);
        }
        Long rounded = JiffRounding.roundLong(
            options.getMode(),
            toNanosecondOfDay(),
            increment * JiffMath.nanosPerUnit(options.getSmallest())
        );
        // The increment divides evenly into a day, so the only value past the end of the day
        // that rounding can produce is the start of the next one.
        return rounded == JiffMath.NANOS_PER_CIVIL_DAY ? MIN : fromNanosecondOfDay(rounded);
    }

    // ---- series ---------------------------------------------------------

    /**
     * The times `this`, `this + period`, `this + 2 * period` and so on, for as long as they
     * stay within the day. A negative period steps backwards.
     *
     *     for (JiffTime t : JiffTime.MIN.series(new JiffSpan().hours(3))) {
     *         // 00:00:00, 03:00:00, 06:00:00, ... 21:00:00
     *     }
     */
    public JiffTimeSeries series(JiffSpan period) {
        return new JiffTimeSeries(this, period);
    }

    // ---- comparison -----------------------------------------------------

    public Integer compareTo(Object other) {
        JiffTime that = (JiffTime) other;
        return JiffMath.compare(toNanosecondOfDay(), that.toNanosecondOfDay());
    }

    public Boolean isBefore(JiffTime other) {
        return compareTo(other) < 0;
    }

    public Boolean isAfter(JiffTime other) {
        return compareTo(other) > 0;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffTime)) {
            return false;
        }
        return toNanosecondOfDay() == ((JiffTime) other).toNanosecondOfDay();
    }

    public Integer hashCode() {
        return toSecondOfDay() * 31 + Math.mod(subsecValue, 1000003);
    }

    /** Formats this time as ISO 8601, for example `15:22:45` or `15:22:45.123`. */
    public override String toString() {
        return JiffTemporal.printTime(this);
    }

    /**
     * Internal: the result of `overflowingAdd`, a time of day together with the number of
     * whole days that were carried out of it. Not part of the public API.
     */
    public class Overflow {
        private final JiffTime wrapped;
        private final Long carried;

        /** Internal: use `JiffTime.overflowingAdd`. */
        public Overflow(JiffTime wrapped, Long carried) {
            this.wrapped = wrapped;
            this.carried = carried;
        }

        /** The time of day the sum landed on. */
        public JiffTime toTime() {
            return wrapped;
        }

        /**
         * The whole civil days (24 hours each) carried out of the time of day: zero when the
         * sum stayed within the day, negative when it fell before midnight.
         */
        public Long days() {
            return carried;
        }
    }
}
