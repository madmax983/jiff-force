/**
 * A builder that makes a new `JiffDateTime` by replacing some of the fields of an existing
 * one.
 *
 * Start it with `JiffDateTime.with()`, name the fields to change, and finish with `build()`.
 * Any field you do not set keeps the value it has in the original datetime.
 *
 *     JiffDateTime dt1 = JiffDateTime.newInstance(2024, 10, 31, 0, 0, 0, 0);
 *     JiffDateTime dt2 = dt1.with().month(11).day(30).build();   // 2024-11-30T00:00:00
 *
 * Nothing is validated until `build()`, so fields can be set in any order. Changing the month
 * of `2024-10-31T00:00:00` to November on its own would be invalid (there is no November
 * 31st), but it is fine as an intermediate step on the way to `2024-11-30T00:00:00`.
 * The one exception is a null value, which every setter rejects at once.
 *
 * The date fields follow the rules of `JiffDateWith` and the time fields those of
 * `JiffTimeWith`. In short:
 *
 * - `year` and `eraYear` both set the year, and the last one set wins.
 * - `day`, `dayOfYear` and `dayOfYearNoLeap` all set the day, and the last one set wins. The
 *   two day-of-year forms also determine the month.
 * - `millisecond`, `microsecond` and `nanosecond` each replace three digits of the fractional
 *   second, while `subsecNanosecond` replaces all of it. Setting `subsecNanosecond` together
 *   with any of the other three makes `build()` throw.
 * - `withDate` replaces the whole date and forgets every date field set before it; `withTime`
 *   does the same for the time of day.
 *
 * Builders are immutable; each setter returns a new builder.
 *
 * Mirrors `jiff::civil::DateTimeWith`.
 */
public class JiffDateTimeWith {
    private final JiffDateWith dateWith;
    private final JiffTimeWith timeWith;

    /**
     * Creates a builder whose fields all come from `original`. `JiffDateTime.with()` is the
     * usual way to get one.
     */
    public JiffDateTimeWith(JiffDateTime original) {
        this(new JiffDateWith(dateOf(original)), new JiffTimeWith(original.toTime()));
    }

    private JiffDateTimeWith(JiffDateWith dateWith, JiffTimeWith timeWith) {
        this.dateWith = dateWith;
        this.timeWith = timeWith;
    }

    private static JiffException missing(String field) {
        return new JiffException(field + ' must not be null');
    }

    private static JiffDate dateOf(JiffDateTime original) {
        if (original == null) {
            throw new JiffException('the datetime to build from must not be null');
        }
        return original.toDate();
    }

    /**
     * Sets the year, month and day from `datePart`. Overrides every date field set earlier;
     * date fields set afterwards replace fields of `datePart`. (`DateTimeWith::date` in Jiff;
     * `date` is a reserved word in Apex.)
     *
     *     JiffDateTime dt1 = JiffDateTime.newInstance(2005, 11, 5, 15, 30, 0, 0);
     *     dt1.with().withDate(JiffDate.newInstance(2017, 10, 31)).build();
     *     // 2017-10-31T15:30:00: the date changes but the time remains the same
     */
    public JiffDateTimeWith withDate(JiffDate datePart) {
        return new JiffDateTimeWith(new JiffDateWith(datePart), timeWith);
    }

    /**
     * Sets the hour, minute, second and fractional second from `timePart`. Overrides every
     * time field set earlier; time fields set afterwards replace fields of `timePart`.
     * (`DateTimeWith::time` in Jiff; `time` is a reserved word in Apex.)
     *
     *     JiffDateTime dt1 = JiffDateTime.newInstance(2005, 11, 5, 15, 30, 0, 0);
     *     dt1.with().withTime(JiffTime.newInstance(23, 59, 59, 123456789)).build();
     *     // 2005-11-05T23:59:59.123456789: the time changes but the date remains the same
     */
    public JiffDateTimeWith withTime(JiffTime timePart) {
        if (timePart == null) {
            throw new JiffException('the time to build from must not be null');
        }
        return new JiffDateTimeWith(dateWith, new JiffTimeWith(timePart));
    }

    /**
     * Sets the year, in `-9999..9999`. Overrides any earlier `year` or `eraYear`.
     *
     * `build()` throws if the year is out of range, or if the date does not exist in that
     * year: `2024-02-29T01:30:00` cannot simply move to 2023.
     */
    public JiffDateTimeWith year(Integer year) {
        if (year == null) {
            throw missing('year');
        }
        return new JiffDateTimeWith(dateWith.year(year), timeWith);
    }

    /**
     * Sets the year by its era and its number within that era. Overrides any earlier `year`
     * or `eraYear`.
     *
     * `CE` years are the same as plain years and must be in `1..9999`. `BCE` years count
     * backwards from year zero and must be in `1..10000`: `1 BCE` is year `0` and `509 BCE` is
     * year `-508`. `build()` throws if the year is outside the range for its era.
     */
    public JiffDateTimeWith eraYear(Integer year, JiffEra era) {
        if (year == null) {
            throw missing('eraYear');
        }
        return new JiffDateTimeWith(dateWith.eraYear(year, era), timeWith);
    }

    /**
     * Sets the month, in `1..12`. Overrides any earlier `month`.
     *
     * `build()` throws if the month is out of range, or if the day does not exist in that
     * month: `2024-10-31T00:00:00` cannot simply move to November.
     */
    public JiffDateTimeWith month(Integer month) {
        if (month == null) {
            throw missing('month');
        }
        return new JiffDateTimeWith(dateWith.month(month), timeWith);
    }

    /**
     * Sets the day of the month. Overrides any earlier `day`, `dayOfYear` or
     * `dayOfYearNoLeap`.
     *
     * `build()` throws if the resulting year and month have no such day.
     */
    public JiffDateTimeWith day(Integer day) {
        if (day == null) {
            throw missing('day');
        }
        return new JiffDateTimeWith(dateWith.day(day), timeWith);
    }

    /**
     * Sets the day by its position in the year, where `1` is January 1st. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..366`. In a leap year day `60` is February 29th; in any other year
     * it is March 1st. `build()` throws if the value is out of range, or if it is `366` and
     * the year is not a leap year.
     */
    public JiffDateTimeWith dayOfYear(Integer day) {
        if (day == null) {
            throw missing('dayOfYear');
        }
        return new JiffDateTimeWith(dateWith.dayOfYear(day), timeWith);
    }

    /**
     * Sets the day by its position in the year as if leap days did not exist. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..365`. Day `60` is always March 1st and day `365` is always
     * December 31st, in leap years too; February 29th can never be produced. `build()` throws
     * if the value is out of range.
     */
    public JiffDateTimeWith dayOfYearNoLeap(Integer day) {
        if (day == null) {
            throw missing('dayOfYearNoLeap');
        }
        return new JiffDateTimeWith(dateWith.dayOfYearNoLeap(day), timeWith);
    }

    /** Sets the hour. `build()` throws unless it is in `0..23`. */
    public JiffDateTimeWith hour(Integer hour) {
        if (hour == null) {
            throw missing('hour');
        }
        return new JiffDateTimeWith(dateWith, timeWith.hour(hour));
    }

    /** Sets the minute. `build()` throws unless it is in `0..59`. */
    public JiffDateTimeWith minute(Integer minute) {
        if (minute == null) {
            throw missing('minute');
        }
        return new JiffDateTimeWith(dateWith, timeWith.minute(minute));
    }

    /** Sets the second. `build()` throws unless it is in `0..59`. */
    public JiffDateTimeWith second(Integer second) {
        if (second == null) {
            throw missing('second');
        }
        return new JiffDateTimeWith(dateWith, timeWith.second(second));
    }

    /**
     * Sets the millisecond component of the fractional second, leaving the microsecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffDateTimeWith millisecond(Integer millisecond) {
        if (millisecond == null) {
            throw missing('millisecond');
        }
        return new JiffDateTimeWith(dateWith, timeWith.millisecond(millisecond));
    }

    /**
     * Sets the microsecond component of the fractional second, leaving the millisecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffDateTimeWith microsecond(Integer microsecond) {
        if (microsecond == null) {
            throw missing('microsecond');
        }
        return new JiffDateTimeWith(dateWith, timeWith.microsecond(microsecond));
    }

    /**
     * Sets the nanosecond component of the fractional second, leaving the millisecond and
     * microsecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffDateTimeWith nanosecond(Integer nanosecond) {
        if (nanosecond == null) {
            throw missing('nanosecond');
        }
        return new JiffDateTimeWith(dateWith, timeWith.nanosecond(nanosecond));
    }

    /**
     * Sets the whole fractional second, in nanoseconds. `build()` throws unless it is in
     * `0..999,999,999`, or if any of `millisecond`, `microsecond` or `nanosecond` is also set.
     */
    public JiffDateTimeWith subsecNanosecond(Integer subsecNanosecond) {
        if (subsecNanosecond == null) {
            throw missing('subsecNanosecond');
        }
        return new JiffDateTimeWith(dateWith, timeWith.subsecNanosecond(subsecNanosecond));
    }

    /**
     * Creates the datetime described by this builder: the original datetime with every field
     * that was set replaced. With nothing set, this returns a datetime equal to the original.
     *
     * Throws if a field is out of range or the fields do not combine into a real datetime.
     * The date is checked before the time of day.
     */
    public JiffDateTime build() {
        JiffDate datePart = dateWith.build();
        return JiffDateTime.fromParts(datePart, timeWith.build());
    }
}
