/**
 * A calendar date together with a time of day, with nanosecond precision and no time zone.
 *
 * A civil datetime is what a calendar and a wall clock show. It does not identify a precise
 * instant, because the same wall clock reading happens at different instants in different
 * places. Combine it with a time zone to get a `JiffZonedDateTime` when you need an instant.
 *
 *     JiffDateTime dt = JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 0);
 *     dt.toDate();    // 2024-02-29
 *     dt.toTime();    // 15:22:45
 *     dt.toString();  // 2024-02-29T15:22:45
 *
 * The supported range is `-9999-01-01T00:00:00` through `9999-12-31T23:59:59.999999999`.
 * Instances are immutable and ordered chronologically.
 *
 * ## Arithmetic
 *
 * `add` and `subtract` move a datetime by a `JiffSpan` (calendar and clock units, so "one
 * month" means the same day and time next month) or by a `JiffSignedDuration` (an exact
 * length of time). They throw when the result leaves the supported range; `saturatingAdd` and
 * `saturatingSubtract` stop at `MIN` or `MAX` instead.
 *
 *     JiffDateTime dt = JiffDateTime.newInstance(2019, 1, 31, 15, 30, 0, 0);
 *     dt.add(new JiffSpan().months(1));           // 2019-02-28T15:30:00
 *     dt.add(JiffSignedDuration.fromHours(10));   // 2019-02-01T01:30:00
 *
 * `until` and `since` go the other way and report the span between two datetimes, in days
 * and smaller units unless you ask for a larger unit. `durationUntil` and `durationSince`
 * give the same difference as an exact duration.
 *
 *     JiffDateTime dt1 = JiffDateTime.newInstance(1995, 12, 7, 3, 24, 30, 3500);
 *     JiffDateTime dt2 = JiffDateTime.newInstance(2019, 1, 31, 15, 30, 0, 0);
 *     dt1.until(dt2);                  // P8456DT12H5M29.9999965S
 *     dt1.until(dt2, JiffUnit.YEAR);   // P23Y1M24DT12H5M29.9999965S
 *
 * `round` rounds to a unit of a day or smaller, `with()` replaces individual fields and
 * `series` steps through datetimes a fixed span apart.
 *
 * A civil datetime knows nothing of daylight saving time, so wherever a length of time is
 * involved a day is always exactly 24 hours.
 *
 * Mirrors `jiff::civil::DateTime`.
 */
public class JiffDateTime implements Comparable {
    /** The earliest supported datetime, `-9999-01-01T00:00:00`. */
    public static final JiffDateTime MIN = new JiffDateTime(JiffDate.MIN, JiffTime.MIN);
    /** The latest supported datetime, `9999-12-31T23:59:59.999999999`. */
    public static final JiffDateTime MAX = new JiffDateTime(JiffDate.MAX, JiffTime.MAX);
    /**
     * Midnight on January 1st of year zero, `0000-01-01T00:00:00`. This is also what Jiff's
     * `DateTime::default()` returns.
     */
    public static final JiffDateTime ZERO = new JiffDateTime(JiffDate.ZERO, JiffTime.MIN);

    private final JiffDate dateValue;
    private final JiffTime timeValue;

    private JiffDateTime(JiffDate dateValue, JiffTime timeValue) {
        this.dateValue = dateValue;
        this.timeValue = timeValue;
    }

    // ---- construction ---------------------------------------------------

    /** Creates a datetime from its civil fields. Throws if any is out of range. */
    public static JiffDateTime newInstance(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return new JiffDateTime(
            JiffDate.newInstance(year, month, day),
            JiffTime.newInstance(hour, minute, second, subsecNanosecond)
        );
    }

    /**
     * Combines a date and a time.
     *
     * Jiff also converts a `Date` straight into the `DateTime` at midnight on that date
     * (`DateTime::from(date)`). Here that is `date.toDateTime(JiffTime.midnight())`, or
     * `JiffDateTime.fromParts(date, JiffTime.midnight())`.
     */
    public static JiffDateTime fromParts(JiffDate datePart, JiffTime timePart) {
        if (datePart == null || timePart == null) {
            throw new JiffException('a datetime needs both a date and a time');
        }
        return new JiffDateTime(datePart, timePart);
    }

    /**
     * Creates the datetime that is `second` seconds and `subsecNanosecond` nanoseconds after
     * `1970-01-01T00:00:00`, counting every day as exactly 86,400 seconds. With a UTC offset
     * of zero this is the conversion from a Unix timestamp to a civil datetime.
     *
     * `subsecNanosecond` must be in `0..999,999,999`; for instants before the epoch the
     * fraction still counts forward from the whole second.
     */
    public static JiffDateTime fromEpochSecond(Long second, Integer subsecNanosecond) {
        JiffMath.check(subsecNanosecond, 0L, 999999999L, 'subsecond nanosecond');
        Long epochDay = JiffMath.floorDiv(second, JiffMath.SECS_PER_CIVIL_DAY);
        Long secondOfDay = second - epochDay * JiffMath.SECS_PER_CIVIL_DAY;
        return new JiffDateTime(
            JiffDate.fromEpochDay(epochDay),
            JiffTime.fromNanosecondOfDay(secondOfDay * JiffMath.NANOS_PER_SEC + subsecNanosecond)
        );
    }

    /**
     * Parses a datetime in ISO 8601 format, such as `2024-06-19T15:22:45`. This is the inverse
     * of `toString()`.
     *
     *     JiffDateTime.parse('2024-06-19T15:22:45');      // 2024-06-19T15:22:45
     *     JiffDateTime.parse('2024-06-19 15:22:45.5');    // a space may separate date and time
     *     JiffDateTime.parse('2024-06-19');               // midnight
     *     JiffDateTime.parse('2024-06-19T15:22:45-04:00[America/New_York]');
     *                                                     // offset and time zone are ignored
     *
     * A string with a `Z` offset names an instant in UTC, not a civil datetime somewhere, and
     * is rejected; parse it with `JiffTimestamp.parse` and convert that. See
     * `JiffTemporal.parseDateTime` for everything that is accepted. Throws `JiffException`
     * when the text is not a valid datetime.
     *
     * Mirrors `impl FromStr for jiff::civil::DateTime`.
     */
    public static JiffDateTime parse(String text) {
        return JiffTemporal.parseDateTime(text);
    }

    /**
     * Starts building a new datetime from this one with some fields replaced:
     *
     *     JiffDateTime dt1 = JiffDateTime.newInstance(2024, 10, 31, 0, 0, 0, 0);
     *     dt1.with().month(11).day(30).build();   // 2024-11-30T00:00:00
     *
     * Nothing is validated until `build()`, so the fields can be set in any order. See
     * `JiffDateTimeWith` for the fields that can be set.
     */
    public JiffDateTimeWith with() {
        return new JiffDateTimeWith(this);
    }

    // ---- accessors ------------------------------------------------------

    /** The date part of this datetime. */
    public JiffDate toDate() {
        return dateValue;
    }

    /** The time of day part of this datetime. */
    public JiffTime toTime() {
        return timeValue;
    }

    /** The year, in `-9999..9999`. */
    public Integer year() {
        return dateValue.year();
    }

    /**
     * The year within its era, in `1..10000`. Pair it with `era()`.
     *
     * Years from `1` onward are unchanged (`2024` is `2024 CE`). Year `0` is `1 BCE`, year
     * `-1` is `2 BCE`, and so on back to year `-9999`, which is `10000 BCE`. Jiff returns the
     * year and the era together as a tuple; here they are two accessors.
     */
    public Integer eraYear() {
        return dateValue.eraYear();
    }

    /** The era of this datetime's year: `CE` for years from `1` onward, `BCE` for the rest. */
    public JiffEra era() {
        return dateValue.era();
    }

    /** The month, in `1..12`. */
    public Integer month() {
        return dateValue.month();
    }

    /** The day of the month, in `1..31`. */
    public Integer day() {
        return dateValue.day();
    }

    /** The hour, in `0..23`. */
    public Integer hour() {
        return timeValue.hour();
    }

    /** The minute, in `0..59`. */
    public Integer minute() {
        return timeValue.minute();
    }

    /** The second, in `0..59`. */
    public Integer second() {
        return timeValue.second();
    }

    /** The millisecond component of the fractional second, in `0..999`. */
    public Integer millisecond() {
        return timeValue.millisecond();
    }

    /** The microsecond component of the fractional second, in `0..999`. */
    public Integer microsecond() {
        return timeValue.microsecond();
    }

    /** The nanosecond component of the fractional second, in `0..999`. */
    public Integer nanosecond() {
        return timeValue.nanosecond();
    }

    /** The whole fractional second in nanoseconds, in `0..999,999,999`. */
    public Integer subsecNanosecond() {
        return timeValue.subsecNanosecond();
    }

    /** The day of the week this datetime falls on. */
    public JiffWeekday weekday() {
        return dateValue.weekday();
    }

    /**
     * The position of this datetime's date within its year, where January 1st is day `1`.
     * December 31st is day `365`, or day `366` in a leap year.
     */
    public Integer dayOfYear() {
        return dateValue.dayOfYear();
    }

    /**
     * The position of this datetime's date within its year as if leap days did not exist, in
     * `1..365`. December 31st is always day `365`, in leap years too.
     *
     * Returns null for February 29th, which has no position in this scheme.
     */
    public Integer dayOfYearNoLeap() {
        Integer position = dateValue.dayOfYearNoLeap();
        if (position == null) {
            return null;
        }
        return position;
    }

    /** The number of days in this datetime's month: 28, 29, 30 or 31. */
    public Integer daysInMonth() {
        return dateValue.daysInMonth();
    }

    /** The number of days in this datetime's year: 366 in a leap year, otherwise 365. */
    public Integer daysInYear() {
        return dateValue.daysInYear();
    }

    /** Whether this datetime's year is a leap year. */
    public Boolean inLeapYear() {
        return dateValue.inLeapYear();
    }

    /**
     * Whole seconds between `1970-01-01T00:00:00` and this datetime, counting every day as
     * exactly 86,400 seconds and rounding toward negative infinity. The inverse of
     * `fromEpochSecond`; the fractional second is `subsecNanosecond()`.
     */
    public Long toEpochSecond() {
        return dateValue.toEpochDay() * JiffMath.SECS_PER_CIVIL_DAY + timeValue.toSecondOfDay();
    }

    /**
     * Converts the date of this datetime to its ISO 8601 week date: a week year, a week
     * number and a weekday. The time of day plays no part. This never fails. See
     * `JiffIsoWeekDate` for how the week calendar works.
     */
    public JiffIsoWeekDate toIsoWeekDate() {
        return dateValue.toIsoWeekDate();
    }

    // ---- neighbouring datetimes -----------------------------------------

    /** The first moment of this datetime's day: the same date at `00:00:00`. */
    public JiffDateTime startOfDay() {
        return new JiffDateTime(dateValue, JiffTime.MIN);
    }

    /** The last representable moment of this datetime's day: the same date at `23:59:59.999999999`. */
    public JiffDateTime endOfDay() {
        return new JiffDateTime(dateValue, JiffTime.MAX);
    }

    /** The first day of this datetime's month, at the same time of day. */
    public JiffDateTime firstOfMonth() {
        return new JiffDateTime(dateValue.firstOfMonth(), timeValue);
    }

    /** The last day of this datetime's month, at the same time of day. */
    public JiffDateTime lastOfMonth() {
        return new JiffDateTime(dateValue.lastOfMonth(), timeValue);
    }

    /** January 1st of this datetime's year, at the same time of day. */
    public JiffDateTime firstOfYear() {
        return new JiffDateTime(dateValue.firstOfYear(), timeValue);
    }

    /** December 31st of this datetime's year, at the same time of day. */
    public JiffDateTime lastOfYear() {
        return new JiffDateTime(dateValue.lastOfYear(), timeValue);
    }

    /**
     * The same time of day on the following day. Throws when this datetime falls on
     * `JiffDate.MAX`, which has no tomorrow.
     */
    public JiffDateTime tomorrow() {
        return new JiffDateTime(dateValue.tomorrow(), timeValue);
    }

    /**
     * The same time of day on the preceding day. Throws when this datetime falls on
     * `JiffDate.MIN`, which has no yesterday.
     */
    public JiffDateTime yesterday() {
        return new JiffDateTime(dateValue.yesterday(), timeValue);
    }

    /**
     * The `nth` occurrence of `weekday` in this datetime's month, at the same time of day.
     *
     * A positive `nth` counts from the start of the month and a negative one from the end, so
     * `2` with `FRIDAY` is the second Friday and `-1` with `THURSDAY` is the last Thursday.
     * The day of this datetime does not matter, only its year and month.
     *
     * Throws if `nth` is zero or outside `-5..5`, or if it is `5` or `-5` and the month has
     * only four of that weekday.
     */
    public JiffDateTime nthWeekdayOfMonth(Integer nth, JiffWeekday weekday) {
        return new JiffDateTime(dateValue.nthWeekdayOfMonth(nth, weekday), timeValue);
    }

    /**
     * The `nth` occurrence of `weekday` after this datetime's date, or before it when `nth`
     * is negative, at the same time of day.
     *
     * The date itself is never counted. If today is a Sunday, the first Sunday (`nth` of `1`)
     * is a week from today and the first Monday is tomorrow; the first Saturday backwards
     * (`nth` of `-1`) is yesterday.
     *
     * Throws if `nth` is zero, or if the result would fall outside the supported range.
     */
    public JiffDateTime nthWeekday(Integer nth, JiffWeekday weekday) {
        return new JiffDateTime(dateValue.nthWeekday(nth, weekday), timeValue);
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * Adds a span to this datetime. A negative span moves backwards.
     *
     * The hours through nanoseconds are added to the time of day, and whatever runs past
     * midnight is carried as whole days, each of them 24 hours. The years through days then
     * move the date as `JiffDate.add` does: years and months first, pulling the day back to
     * the end of the month when the month is too short (`2019-01-31T15:30 + 1 month` is
     * `2019-02-28T15:30`), then weeks and days. The carried days are added last.
     *
     *     JiffDateTime dt = JiffDateTime.newInstance(1995, 12, 7, 3, 24, 30, 3500);
     *     dt.add(new JiffSpan().years(20).months(4).nanoseconds(500));
     *     // 2016-04-07T03:24:30.000004
     *
     * Because of the end of month rule, adding a span with years or months and then
     * subtracting it again does not always return to the same datetime. Spans of weeks and
     * smaller units are always reversible.
     *
     * Throws if the result is outside the supported range.
     */
    public JiffDateTime add(JiffSpan span) {
        Boolean hasCalendar = span.hasCalendarUnits();
        Boolean hasTime = span.hasTimeUnits();
        if (!hasCalendar && !hasTime) {
            return this;
        }
        if (!hasTime) {
            return new JiffDateTime(addSpanToDate(dateValue, span), timeValue);
        }
        // The order below is Jiff's, and it decides which failure is reported when more than
        // one step would fail: the time of day first, then the calendar units, then the carry.
        JiffTime.Overflow sum;
        try {
            sum = timeValue.overflowingAdd(span.onlyLower(JiffUnit.DAY));
        } catch (JiffException e) {
            throw inContext('failed to add span to time', e);
        }
        JiffDate moved = hasCalendar
            ? addSpanToDate(dateValue, span.withoutLower(JiffUnit.DAY))
            : dateValue;
        try {
            moved = moved.add(new JiffSpan().days(sum.days()));
        } catch (JiffException e) {
            throw inContext('failed to add overflowing span', e);
        }
        return new JiffDateTime(moved, sum.toTime());
    }

    private static JiffDate addSpanToDate(JiffDate start, JiffSpan span) {
        try {
            return start.add(span);
        } catch (JiffException e) {
            throw inContext('failed to add span to date', e);
        }
    }

    /**
     * Adds an exact duration to this datetime. A negative duration moves backwards.
     *
     * The duration is added to the time of day, and each full 24 hours it runs past midnight
     * moves the date by one day. Unlike a span with months or years, this is always
     * reversible: subtracting the same duration gives this datetime back.
     *
     *     JiffDateTime dt = JiffDateTime.newInstance(2024, 2, 29, 0, 0, 0, 0);
     *     dt.add(JiffSignedDuration.fromHours(25));    // 2024-03-01T01:00:00
     *     dt.add(JiffSignedDuration.fromHours(-25));   // 2024-02-27T23:00:00
     *
     * Throws if the result is outside the supported range.
     */
    public JiffDateTime add(JiffSignedDuration duration) {
        JiffTime.Overflow sum = timeValue.overflowingAdd(duration);
        try {
            // Jiff hands the carried days to the date as a duration of that many 24 hour days.
            JiffDate moved = dateValue.add(JiffSignedDuration.fromHours(24 * sum.days()));
            return new JiffDateTime(moved, sum.toTime());
        } catch (JiffException e) {
            throw inContext('failed to add overflowing duration', e);
        }
    }

    /**
     * Subtracts a span from this datetime. The same as adding the span negated; see
     * `add(JiffSpan)` for how each unit is applied.
     *
     *     JiffDateTime dt = JiffDateTime.newInstance(1995, 12, 7, 3, 24, 30, 3500);
     *     dt.subtract(new JiffSpan().years(20).months(4).nanoseconds(500));
     *     // 1975-08-07T03:24:30.000003
     */
    public JiffDateTime subtract(JiffSpan span) {
        return add(span.negate());
    }

    /**
     * Subtracts an exact duration from this datetime. The same as adding the duration
     * negated; see `add(JiffSignedDuration)`.
     */
    public JiffDateTime subtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // The negation does not fit in a signed duration. Jiff reaches the same dead end
            // by way of an unsigned duration, and reports it like this.
            throw new JiffException(
                'unsigned duration exceeds Jiff\'s limits: ' +
                JiffMath.rangeError('signed duration seconds', JiffMath.LONG_MIN, JiffMath.LONG_MAX)
                    .getMessage()
            );
        }
        return add(duration.negate());
    }

    /**
     * Like `add(JiffSpan)`, except that instead of throwing when the result is out of range
     * it returns `MAX` (for a positive span) or `MIN` (for a negative one).
     */
    public JiffDateTime saturatingAdd(JiffSpan span) {
        try {
            return add(span);
        } catch (JiffException e) {
            return span.isNegative() ? MIN : MAX;
        }
    }

    /**
     * Like `add(JiffSignedDuration)`, except that instead of throwing when the result is out
     * of range it returns `MAX` (for a positive duration) or `MIN` (for a negative one).
     */
    public JiffDateTime saturatingAdd(JiffSignedDuration duration) {
        try {
            return add(duration);
        } catch (JiffException e) {
            return duration.isNegative() ? MIN : MAX;
        }
    }

    /**
     * Like `subtract(JiffSpan)`, except that instead of throwing when the result is out of
     * range it returns `MIN` (for a positive span) or `MAX` (for a negative one).
     */
    public JiffDateTime saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /**
     * Like `subtract(JiffSignedDuration)`, except that instead of throwing when the result is
     * out of range it returns `MIN` (for a positive duration) or `MAX` (for a negative one).
     */
    public JiffDateTime saturatingSubtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Too negative to negate, so subtracting it certainly overflows forwards.
            return MAX;
        }
        return saturatingAdd(duration.negate());
    }

    /** Wraps `cause` in the description of the step that failed, the way Jiff chains errors. */
    private static JiffException inContext(String step, JiffException cause) {
        return new JiffException(step + ': ' + cause.getMessage(), cause);
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this datetime until `other`, using days as the largest unit. It is
     * negative when `other` is earlier.
     *
     *     JiffDateTime earlier = JiffDateTime.newInstance(2006, 8, 24, 22, 30, 0, 0);
     *     JiffDateTime later = JiffDateTime.newInstance(2019, 1, 31, 21, 0, 0, 0);
     *     earlier.until(later);   // P4542DT22H30M
     *     later.until(earlier);   // -P4542DT22H30M
     *
     * This never fails, and subtracting the result from `other` always gives this datetime
     * back.
     */
    public JiffSpan until(JiffDateTime other) {
        return until(other, JiffUnit.DAY);
    }

    /**
     * The span from this datetime until `other`, using units up to `largest` (null means
     * `DAY`). It is negative when `other` is earlier.
     *
     *     JiffDateTime dt1 = JiffDateTime.newInstance(1995, 12, 7, 3, 24, 30, 3500);
     *     JiffDateTime dt2 = JiffDateTime.newInstance(2019, 1, 31, 15, 30, 0, 0);
     *     dt1.until(dt2, JiffUnit.YEAR);   // P23Y1M24DT12H5M29.9999965S
     *     dt1.until(dt2, JiffUnit.HOUR);   // PT202956H5M29.9999965S
     *
     * With `DAY` or a smaller unit the difference is an exact length of time, with every day
     * 24 hours long, spread over the units from `largest` down. With `WEEK`, `MONTH` or
     * `YEAR` the dates are compared on the calendar, as `JiffDate.until` does, after setting
     * aside the part of a day by which the times of day differ. Months differ in length, so
     * such a span is tied to its starting point: adding it to this datetime gives `other`,
     * but subtracting it from `other` may not give this datetime back.
     *
     * Nothing is rounded here. This is the exact difference, and the computation that every
     * other form of `until` and `since` builds on.
     *
     * Throws if the difference does not fit in the requested units. That can only happen
     * with `NANOSECOND`, for datetimes more than about 292 years apart, and with `MONTH`, for
     * datetimes more than 19,998 years apart.
     */
    public JiffSpan until(JiffDateTime other, JiffUnit largest) {
        JiffUnit unit = largest == null ? JiffUnit.DAY : largest;
        if (!JiffMath.isLarger(unit, JiffUnit.DAY)) {
            return JiffSpan.fromInvariantDuration(unit, durationUntil(other));
        }
        JiffDate target = other.dateValue;
        Integer sign = JiffMath.signum(target.compareTo(dateValue));
        Long timeDifference = other.timeValue.toNanosecondOfDay() - timeValue.toNanosecondOfDay();
        if (sign != 0 && JiffMath.signum(timeDifference) == -sign) {
            // The time of day falls short of a whole day, so count the dates one day closer
            // and give that day to the time instead. The neighbouring day always exists: it
            // lies between the two dates.
            target = sign > 0 ? target.yesterday() : target.tomorrow();
            timeDifference += sign * JiffMath.NANOS_PER_CIVIL_DAY;
        }
        JiffSpan dateSpan = dateValue.until(target, unit);
        // What is left of the time is less than a day and has the sign of the date span (or
        // one of them is zero), so the units can be combined into one span.
        return JiffSpan.fromInvariantDuration(
                JiffUnit.HOUR,
                JiffSignedDuration.fromNanos(timeDifference)
            )
            .years(dateSpan.getYears())
            .months(dateSpan.getMonths())
            .weeks(dateSpan.getWeeks())
            .days(dateSpan.getDays());
    }

    /**
     * The span from `other` until this datetime, using days as the largest unit. It is
     * negative when `other` is later. This is `until(other)` with the sign flipped.
     *
     *     JiffDateTime earlier = JiffDateTime.newInstance(2006, 8, 24, 22, 30, 0, 0);
     *     JiffDateTime later = JiffDateTime.newInstance(2019, 1, 31, 21, 0, 0, 0);
     *     later.since(earlier);   // P4542DT22H30M
     */
    public JiffSpan since(JiffDateTime other) {
        return until(other).negate();
    }

    /**
     * The span from `other` until this datetime, using units up to `largest` (null means
     * `DAY`). It is negative when `other` is later.
     *
     * This is `until(other, largest)` with the sign flipped: months and years are still
     * counted starting from this datetime, going back to `other`. That is not always the same
     * as `other.until(this, largest)`, which counts forward from `other`.
     */
    public JiffSpan since(JiffDateTime other, JiffUnit largest) {
        return until(other, largest).negate();
    }

    /**
     * The exact length of time from this datetime until `other`, counting every day as 24
     * hours. It is negative when `other` is earlier. This never fails.
     *
     *     JiffDateTime dt1 = JiffDateTime.newInstance(2024, 1, 1, 0, 0, 0, 0);
     *     JiffDateTime dt2 = JiffDateTime.newInstance(2025, 4, 1, 0, 0, 0, 0);
     *     dt1.durationUntil(dt2);   // PT10944H
     *
     * Prefer `until` unless you specifically need an absolute duration.
     */
    public JiffSignedDuration durationUntil(JiffDateTime other) {
        return dateValue.durationUntil(other.dateValue)
            .add(timeValue.durationUntil(other.timeValue));
    }

    /**
     * The exact length of time from `other` until this datetime, counting every day as 24
     * hours. It is negative when `other` is later. This never fails.
     */
    public JiffSignedDuration durationSince(JiffDateTime other) {
        return other.durationUntil(this);
    }

    // ---- rounding -------------------------------------------------------

    /**
     * Rounds this datetime to the nearest multiple of `unit`, with ties rounding up.
     *
     *     JiffDateTime dt = JiffDateTime.newInstance(2024, 6, 19, 15, 0, 0, 0);
     *     dt.round(JiffUnit.DAY);   // 2024-06-20T00:00:00
     *
     * See `round(JiffRound)` for the units allowed and the ways this can fail.
     */
    public JiffDateTime round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this datetime according to `options`: a smallest unit, a rounding mode and a
     * rounding increment.
     *
     *     // The nearest five minutes.
     *     JiffDateTime dt = JiffDateTime.newInstance(2024, 6, 19, 15, 27, 30, 0);
     *     dt.round(JiffRound.to(JiffUnit.MINUTE).increment(5));   // 2024-06-19T15:30:00
     *
     * The smallest unit must be days or smaller. With days the increment must be `1`; with a
     * smaller unit it must divide evenly into the next unit up without being equal to it
     * (with minutes, `1`, `5`, `15` and `30` are fine but `7` and `60` are not).
     *
     * Only the time of day is rounded. When it rounds up to the end of the day the result is
     * midnight on the following day, so this throws when that day is beyond `MAX`:
     * `JiffDateTime.MAX.round(JiffUnit.DAY)` fails. Rounding with `JiffRoundMode.TRUNC` never
     * fails for a valid unit and increment.
     *
     * One inherited quirk: Jiff 1.0.0 applies the sign of the year to that carried day, and
     * this port reproduces it. A datetime in year `0` that rounds up past the end of its day
     * lands on midnight of the same day, and one in a year before `0` lands on midnight of
     * the day before, where the following day is expected in both cases. Datetimes from year
     * `1` onward are not affected.
     */
    public JiffDateTime round(JiffRound options) {
        JiffUnit smallest = options.getSmallest();
        if (smallest == JiffUnit.NANOSECOND && options.getIncrement() == 1) {
            return this;
        }
        Long increment;
        try {
            increment = JiffRounding.incrementForDateTime(smallest, options.getIncrement());
        } catch (JiffException e) {
            throw inContext('failed rounding datetime', e);
        }
        Long rounded = JiffRounding.roundLong(
            options.getMode(),
            timeValue.toNanosecondOfDay(),
            increment * JiffMath.nanosPerUnit(smallest)
        );
        // The increment divides evenly into a day, so rounding carries one day at most.
        Long carriedDays = rounded / JiffMath.NANOS_PER_CIVIL_DAY;
        JiffTime roundedTime = JiffTime.fromNanosecondOfDay(
            rounded - carriedDays * JiffMath.NANOS_PER_CIVIL_DAY
        );
        // Jiff multiplies the carry by the sign of the year; see the note above.
        carriedDays = JiffMath.signum(dateValue.year()) * carriedDays;
        try {
            JiffDate roundedDate = dateValue.firstOfMonth()
                .add(new JiffSpan().days(dateValue.day() - 1 + carriedDays));
            return new JiffDateTime(roundedDate, roundedTime);
        } catch (JiffException e) {
            throw inContext('failed to add days to date', e);
        }
    }

    // ---- series ---------------------------------------------------------

    /**
     * The datetimes a fixed span apart, starting with this one: this datetime, this datetime
     * plus `period`, this datetime plus twice `period`, and so on. A negative period walks
     * backwards.
     *
     *     // When to scan a glucose monitor: every five hours for two days.
     *     JiffDateTime start = JiffDateTime.newInstance(2023, 7, 15, 16, 30, 0, 0);
     *     JiffDateTime finish = start.add(new JiffSpan().days(2));
     *     for (JiffDateTime scan : start.series(new JiffSpan().hours(5))) {
     *         if (scan.isAfter(finish)) {
     *             break;
     *         }
     *         // 2023-07-15T16:30:00, 2023-07-15T21:30:00, ... 2023-07-17T13:30:00
     *     }
     *
     * The series has no end of its own; it stops only when it leaves the supported range, so
     * a loop over it needs its own exit. See `JiffDateTimeSeries`.
     */
    public JiffDateTimeSeries series(JiffSpan period) {
        return new JiffDateTimeSeries(this, period);
    }

    // ---- comparison -----------------------------------------------------

    /**
     * Orders datetimes chronologically: negative when this datetime is earlier than `other`,
     * zero when they are the same and positive when it is later.
     */
    public Integer compareTo(Object other) {
        JiffDateTime that = (JiffDateTime) other;
        Integer byDate = dateValue.compareTo(that.dateValue);
        return byDate != 0 ? byDate : timeValue.compareTo(that.timeValue);
    }

    /** Whether this datetime is strictly earlier than `other`. */
    public Boolean isBefore(JiffDateTime other) {
        return compareTo(other) < 0;
    }

    /** Whether this datetime is strictly later than `other`. */
    public Boolean isAfter(JiffDateTime other) {
        return compareTo(other) > 0;
    }

    /** Whether `other` is a datetime with the same date and the same time of day. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffDateTime)) {
            return false;
        }
        JiffDateTime that = (JiffDateTime) other;
        return dateValue.equals(that.dateValue) && timeValue.equals(that.timeValue);
    }

    /** A hash consistent with `equals`, so datetimes can be map keys and set members. */
    public Integer hashCode() {
        return dateValue.hashCode() * 31 + timeValue.hashCode();
    }

    /** Formats this datetime as ISO 8601, for example `2024-02-29T15:22:45.5`. */
    public override String toString() {
        return JiffTemporal.printDateTime(this);
    }
}
