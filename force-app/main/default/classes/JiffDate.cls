/**
 * A calendar date with no time of day and no time zone: a year, a month and a day in the
 * proleptic Gregorian calendar.
 *
 * Use a civil date for things that are the same day everywhere, such as a birthday or a
 * contract's effective date. It says nothing about a precise instant; pair it with a time and
 * a time zone (see `JiffZonedDateTime`) when you need one.
 *
 *     JiffDate leapDay = JiffDate.newInstance(2024, 2, 29);
 *     leapDay.year();      // 2024
 *     leapDay.weekday();   // JiffWeekday.THURSDAY
 *     leapDay.toString();  // 2024-02-29
 *
 * The supported range is `-9999-01-01` through `9999-12-31`. Instances are immutable and
 * ordered chronologically.
 *
 * ## Arithmetic
 *
 * `add` and `subtract` move a date by a `JiffSpan` (calendar units, so "one month" means the
 * same day next month) or by a `JiffSignedDuration` (an exact length of time, of which only
 * whole 24 hour days count). They throw when the result leaves the supported range;
 * `saturatingAdd` and `saturatingSubtract` stop at `MIN` or `MAX` instead.
 *
 *     JiffDate.newInstance(2024, 1, 31).add(new JiffSpan().months(1));   // 2024-02-29
 *
 * `until` and `since` go the other way and report the span between two dates, in days unless
 * you ask for a larger unit:
 *
 *     JiffDate d1 = JiffDate.newInstance(1995, 12, 7);
 *     JiffDate d2 = JiffDate.newInstance(2019, 1, 31);
 *     d1.until(d2);                  // P8456D
 *     d1.until(d2, JiffUnit.YEAR);   // P23Y1M24D
 *
 * A civil date knows nothing of daylight saving time, so wherever a length of time is
 * involved a day is always exactly 24 hours.
 *
 * Mirrors `jiff::civil::Date`.
 */
public class JiffDate implements Comparable {
    private static final Long MIN_EPOCH_DAY = -4371587L;
    private static final Long MAX_EPOCH_DAY = 2932896L;
    private static final Integer MIN_YEAR = -9999;
    private static final Integer MAX_YEAR = 9999;
    // The largest count accepted by `nthWeekday`: the number of whole weeks in the longest
    // length of time a span can describe.
    private static final Long MAX_NTH_WEEKDAY = 1043497L;
    private static final List<JiffWeekday> WEEKDAYS = JiffWeekday.values();
    // Indexed by month (1..12): the number of days in a common year before that month starts.
    private static final List<Integer> DAYS_BEFORE_MONTH = new List<Integer>{
        0,
        0,
        31,
        59,
        90,
        120,
        151,
        181,
        212,
        243,
        273,
        304,
        334
    };

    /** The earliest supported date, `-9999-01-01`. */
    public static final JiffDate MIN = new JiffDate(-9999, 1, 1);
    /** The latest supported date, `9999-12-31`. */
    public static final JiffDate MAX = new JiffDate(9999, 12, 31);
    /** January 1st of year zero, `0000-01-01`. */
    public static final JiffDate ZERO = new JiffDate(0, 1, 1);

    private final Integer yearValue;
    private final Integer monthValue;
    private final Integer dayValue;

    private JiffDate(Integer yearValue, Integer monthValue, Integer dayValue) {
        this.yearValue = yearValue;
        this.monthValue = monthValue;
        this.dayValue = dayValue;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Creates a date from a year (`-9999..9999`), a month (`1..12`) and a day of the month.
     * Throws if any component is out of range or the day does not exist in that month.
     */
    public static JiffDate newInstance(Integer year, Integer month, Integer day) {
        checkYearAndMonth(year, month);
        if (day < 1) {
            throw JiffMath.rangeError('day', 1L, 31L);
        }
        if (day > 28 && day > daysInMonth(year, month)) {
            throw new JiffException(
                'parameter \'day\' for `' +
                    padYear(year) +
                    '-' +
                    JiffMath.pad(month, 2) +
                    '` is invalid, must be in range `1..=' +
                    daysInMonth(year, month) +
                    '`'
            );
        }
        return new JiffDate(year, month, day);
    }

    /**
     * Like `newInstance`, except that a day beyond the end of the month is pulled back to the
     * month's last day instead of being rejected. Used by calendar arithmetic, where
     * `January 31 + 1 month` lands on the last day of February.
     */
    public static JiffDate constrain(Integer year, Integer month, Integer day) {
        checkYearAndMonth(year, month);
        if (day < 1) {
            throw JiffMath.rangeError('day', 1L, 31L);
        }
        return new JiffDate(year, month, Math.min(day, daysInMonth(year, month)));
    }

    private static void checkYearAndMonth(Integer year, Integer month) {
        JiffMath.check(year, MIN_YEAR, MAX_YEAR, 'year');
        JiffMath.check(month, 1L, 12L, 'month');
    }

    private static String padYear(Integer year) {
        return year < 0 ? '-' + JiffMath.pad(-year, 3) : JiffMath.pad(year, 4);
    }

    /**
     * Creates a date from a count of days since the Unix epoch, where day zero is `1970-01-01`.
     * Throws if the day is outside the supported range.
     */
    public static JiffDate fromEpochDay(Long epochDay) {
        JiffMath.check(epochDay, MIN_EPOCH_DAY, MAX_EPOCH_DAY, 'Unix epoch days');
        // Days-to-civil conversion on a calendar that starts on March 1st, so that the leap
        // day falls at the end of the year. See Howard Hinnant's "chrono-Compatible Low-Level
        // Date Algorithms" for the derivation.
        Long shifted = epochDay + 719468L;
        Long era = JiffMath.floorDiv(shifted, 146097L);
        Long dayOfEra = shifted - era * 146097L;
        Long yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365;
        Long dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100);
        Long monthFromMarch = (5 * dayOfYear + 2) / 153;
        Long day = dayOfYear - (153 * monthFromMarch + 2) / 5 + 1;
        Long month = monthFromMarch < 10 ? monthFromMarch + 3 : monthFromMarch - 9;
        Long year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0);
        return new JiffDate(year.intValue(), month.intValue(), day.intValue());
    }

    /**
     * Creates the date that is day number `day` of `year`, where day `1` is January 1st.
     *
     * The day must be in `1..366`, and `366` is only valid in a leap year. Throws if the year
     * or the day is out of range. `with().dayOfYear(day)` is the usual way to reach this.
     */
    public static JiffDate fromDayOfYear(Integer year, Integer day) {
        JiffMath.check(year, MIN_YEAR, MAX_YEAR, 'year');
        JiffMath.check(day, 1L, 366L, 'day-of-year');
        if (day == 366 && !isLeapYear(year)) {
            throw new JiffException(
                'number of days for `' + padYear(year) + '` is invalid, must be in range `1..=365`'
            );
        }
        return fromEpochDay(new JiffDate(year, 1, 1).toEpochDay() + day - 1);
    }

    /**
     * Creates the date that is day number `day` of `year`, counting as if leap days did not
     * exist: day `60` is always March 1st and day `365` is always December 31st.
     *
     * The day must be in `1..365`. February 29th is never returned. Throws if the year or the
     * day is out of range. `with().dayOfYearNoLeap(day)` is the usual way to reach this.
     */
    public static JiffDate fromDayOfYearNoLeap(Integer year, Integer day) {
        JiffMath.check(year, MIN_YEAR, MAX_YEAR, 'year');
        JiffMath.check(day, 1L, 365L, 'day-of-year (skipping Feb 29)');
        return fromDayOfYear(year, day >= 60 && isLeapYear(year) ? day + 1 : day);
    }

    /**
     * Converts an ISO 8601 week date to the Gregorian date of the same day. This never fails:
     * the two types cover exactly the same range. Equivalent to `weekDate.toDate()`.
     */
    public static JiffDate fromIsoWeekDate(JiffIsoWeekDate weekDate) {
        return weekDate.toDate();
    }

    /**
     * Converts a platform `Date`, such as a record's date field, to a `JiffDate` for the same
     * day. A null `Date`, such as an empty field, gives null.
     *
     *     JiffDate closeDate = JiffDate.fromSystemDate(opportunity.CloseDate);
     *
     * The conversion goes through the day's position on the timeline rather than through
     * `year()`, `month()` and `day()`, so it gives the same answer whatever the running user's
     * locale and time zone. That matters: for a user whose locale uses the Buddhist calendar
     * (`th_TH`), the platform reports the year of 29 February 2024 as 2567.
     *
     * The platform calendar is Julian before 15 October 1582. A platform date before then is
     * converted to the same day on the timeline, which the proleptic Gregorian calendar used
     * here may number differently. Throws if the day is outside the supported range.
     */
    public static JiffDate fromSystemDate(Date value) {
        if (value == null) {
            return null;
        }
        Long millis = Datetime.newInstanceGmt(value, Time.newInstance(0, 0, 0, 0)).getTime();
        return fromEpochDay(JiffMath.floorDiv(millis, JiffMath.MILLIS_PER_CIVIL_DAY));
    }

    /**
     * Parses a date in ISO 8601 format, such as `2024-06-19`. This is the inverse of
     * `toString()`.
     *
     *     JiffDate.parse('2024-06-19');           // 2024-06-19
     *     JiffDate.parse('20240619');             // the same date, in the basic format
     *     JiffDate.parse('-000044-03-15');        // a year before zero has a sign and six digits
     *     JiffDate.parse('2024-06-19T15:22:45');  // the time of a datetime is ignored
     *
     * A string with a `Z` offset names an instant in UTC, not a date somewhere, and is
     * rejected. See `JiffTemporal.parseDate` for everything that is accepted. Throws
     * `JiffException` when the text is not a valid date.
     *
     * Mirrors `impl FromStr for jiff::civil::Date`.
     */
    public static JiffDate parse(String text) {
        return JiffTemporal.parseDate(text);
    }

    /**
     * Starts building a new date from this one with some fields replaced:
     *
     *     JiffDate.newInstance(2024, 10, 31).with().month(11).day(30).build();   // 2024-11-30
     *
     * Nothing is validated until `build()`, so the fields can be set in any order. See
     * `JiffDateWith` for the fields that can be set.
     */
    public JiffDateWith with() {
        return new JiffDateWith(this);
    }

    // ---- accessors ------------------------------------------------------

    /** The year, in `-9999..9999`. */
    public Integer year() {
        return yearValue;
    }

    /** The month, in `1..12`. */
    public Integer month() {
        return monthValue;
    }

    /** The day of the month, in `1..31`. */
    public Integer day() {
        return dayValue;
    }

    /** The day of the week this date falls on. */
    public JiffWeekday weekday() {
        // 1970-01-01 was a Thursday, three days after Monday.
        return WEEKDAYS.get(JiffMath.floorMod(toEpochDay() + 3, 7L).intValue());
    }

    /** The number of days since the Unix epoch; `1970-01-01` is day zero. */
    public Long toEpochDay() {
        Long year = yearValue - (monthValue <= 2 ? 1 : 0);
        Long era = JiffMath.floorDiv(year, 400L);
        Long yearOfEra = year - era * 400;
        Long dayOfYear = (153 * (monthValue + (monthValue > 2 ? -3 : 9)) + 2) / 5 + dayValue - 1;
        Long dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
        return era * 146097L + dayOfEra - 719468L;
    }

    /** Whether `year` is a leap year in the proleptic Gregorian calendar. */
    public static Boolean isLeapYear(Integer year) {
        return Math.mod(year, 4) == 0 && (Math.mod(year, 100) != 0 || Math.mod(year, 400) == 0);
    }

    /** The number of days in the given month of the given year. */
    public static Integer daysInMonth(Integer year, Integer month) {
        if (month == 2) {
            return isLeapYear(year) ? 29 : 28;
        }
        return month == 4 || month == 6 || month == 9 || month == 11 ? 30 : 31;
    }

    /**
     * The year within its era, in `1..10000`. Pair it with `era()`.
     *
     * Years from `1` onward are unchanged (`2024` is `2024 CE`). Year `0` is `1 BCE`, year
     * `-1` is `2 BCE`, and so on back to year `-9999`, which is `10000 BCE`. Jiff returns the
     * year and the era together as a tuple; here they are two accessors.
     */
    public Integer eraYear() {
        return yearValue >= 1 ? yearValue : 1 - yearValue;
    }

    /** The era of this date's year: `CE` for years from `1` onward, `BCE` for the rest. */
    public JiffEra era() {
        return yearValue >= 1 ? JiffEra.CE : JiffEra.BCE;
    }

    /**
     * The position of this date within its year, where January 1st is day `1`. December 31st
     * is day `365`, or day `366` in a leap year.
     */
    public Integer dayOfYear() {
        Integer leapDay = monthValue > 2 && inLeapYear() ? 1 : 0;
        return DAYS_BEFORE_MONTH.get(monthValue) + leapDay + dayValue;
    }

    /**
     * The position of this date within its year as if leap days did not exist, in `1..365`.
     * December 31st is always day `365`, in leap years too.
     *
     * Returns null for February 29th, which has no position in this scheme.
     */
    public Integer dayOfYearNoLeap() {
        Integer days = dayOfYear();
        if (!inLeapYear() || days < 60) {
            return days;
        }
        if (days == 60) {
            return null;
        }
        return days - 1;
    }

    /** The first day of this date's month. */
    public JiffDate firstOfMonth() {
        return new JiffDate(yearValue, monthValue, 1);
    }

    /** The last day of this date's month. */
    public JiffDate lastOfMonth() {
        return new JiffDate(yearValue, monthValue, daysInMonth());
    }

    /** The number of days in this date's month: 28, 29, 30 or 31. */
    public Integer daysInMonth() {
        return daysInMonth(yearValue, monthValue);
    }

    /** January 1st of this date's year. */
    public JiffDate firstOfYear() {
        return new JiffDate(yearValue, 1, 1);
    }

    /** December 31st of this date's year. */
    public JiffDate lastOfYear() {
        return new JiffDate(yearValue, 12, 31);
    }

    /** The number of days in this date's year: 366 in a leap year, otherwise 365. */
    public Integer daysInYear() {
        return inLeapYear() ? 366 : 365;
    }

    /** Whether this date's year is a leap year. */
    public Boolean inLeapYear() {
        return isLeapYear(yearValue);
    }

    // ---- neighbouring dates ---------------------------------------------

    /** The day after this one. Throws for `MAX`, which has no tomorrow. */
    public JiffDate tomorrow() {
        if (dayValue < 28 || dayValue < daysInMonth()) {
            return new JiffDate(yearValue, monthValue, dayValue + 1);
        }
        if (monthValue < 12) {
            return new JiffDate(yearValue, monthValue + 1, 1);
        }
        return new JiffDate(JiffMath.checkInt(yearValue + 1, MIN_YEAR, MAX_YEAR, 'year'), 1, 1);
    }

    /** The day before this one. Throws for `MIN`, which has no yesterday. */
    public JiffDate yesterday() {
        if (dayValue > 1) {
            return new JiffDate(yearValue, monthValue, dayValue - 1);
        }
        if (monthValue > 1) {
            return new JiffDate(yearValue, monthValue - 1, daysInMonth(yearValue, monthValue - 1));
        }
        return new JiffDate(JiffMath.checkInt(yearValue - 1, MIN_YEAR, MAX_YEAR, 'year'), 12, 31);
    }

    /**
     * The `nth` occurrence of `weekday` in this date's month.
     *
     * A positive `nth` counts from the start of the month and a negative one from the end, so
     * `2` with `FRIDAY` is the second Friday and `-1` with `THURSDAY` is the last Thursday.
     * The day of this date does not matter, only its year and month.
     *
     * Throws if `nth` is zero or outside `-5..5`, or if it is `5` or `-5` and the month has
     * only four of that weekday.
     */
    public JiffDate nthWeekdayOfMonth(Integer nth, JiffWeekday weekday) {
        JiffMath.check(nth, -5L, 5L, 'nth weekday of month');
        if (nth == 0) {
            throw JiffMath.rangeError('nth weekday of month', -5L, 5L);
        }
        if (nth > 0) {
            Integer toFirst = JiffWeekdays.since(weekday, firstOfMonth().weekday());
            return newInstance(yearValue, monthValue, 1 + toFirst + (nth - 1) * 7);
        }
        JiffDate last = lastOfMonth();
        Integer fromLast = JiffWeekdays.since(last.weekday(), weekday);
        return newInstance(yearValue, monthValue, last.day() - fromLast + (nth + 1) * 7);
    }

    /**
     * The `nth` occurrence of `weekday` after this date, or before it when `nth` is negative.
     *
     * This date itself is never counted. If today is a Sunday, the first Sunday (`nth` of
     * `1`) is a week from today and the first Monday is tomorrow; the first Saturday
     * backwards (`nth` of `-1`) is yesterday.
     *
     * Throws if `nth` is zero, or if the result would fall outside the supported range.
     */
    public JiffDate nthWeekday(Integer nth, JiffWeekday weekday) {
        JiffMath.check(nth, -MAX_NTH_WEEKDAY, MAX_NTH_WEEKDAY, 'nth weekday');
        if (nth == 0) {
            throw JiffMath.rangeError('nth weekday', -MAX_NTH_WEEKDAY, MAX_NTH_WEEKDAY);
        }
        JiffWeekday mine = weekday();
        Long days;
        if (nth > 0) {
            Integer toFirst = JiffWeekdays.since(weekday, JiffWeekdays.next(mine));
            days = (nth - 1) * 7L + toFirst + 1;
        } else {
            Integer toFirst = JiffWeekdays.since(JiffWeekdays.previous(mine), weekday);
            days = (nth + 1) * 7L - toFirst - 1;
        }
        return fromEpochDay(toEpochDay() + days);
    }

    // ---- conversions ----------------------------------------------------

    /**
     * Converts this date to its ISO 8601 week date: a week year, a week number and a weekday.
     * This never fails. See `JiffIsoWeekDate` for how the week calendar works.
     */
    public JiffIsoWeekDate toIsoWeekDate() {
        return JiffIsoWeekDate.fromDate(this);
    }

    /**
     * The datetime on this date at the time of day `timePart`. The same as
     * `JiffDateTime.fromParts(this, timePart)`.
     *
     *     JiffDate day = JiffDate.newInstance(2010, 3, 14);
     *     day.toDateTime(JiffTime.newInstance(2, 30, 0, 0));   // 2010-03-14T02:30:00
     */
    public JiffDateTime toDateTime(JiffTime timePart) {
        return JiffDateTime.fromParts(this, timePart);
    }

    /**
     * The datetime on this date at the time of day given by its fields. Throws if a field is
     * out of range; see `JiffTime.newInstance`.
     *
     *     JiffDate.newInstance(2010, 3, 14).at(2, 30, 0, 0);   // 2010-03-14T02:30:00
     *
     * `JiffTime.onDate` builds the same datetime starting from the time.
     */
    public JiffDateTime at(Integer hour, Integer minute, Integer second, Integer subsecNanosecond) {
        return JiffDateTime.fromParts(
            this,
            JiffTime.newInstance(hour, minute, second, subsecNanosecond)
        );
    }

    /**
     * This date at midnight on the clock in the given time zone, as a zoned datetime. If the
     * zone skips or repeats midnight on this date, it is resolved with the `COMPATIBLE`
     * strategy, so the result is not always at `00:00`:
     *
     *     JiffTimeZone saoPaulo = JiffTimeZone.get('America/Sao_Paulo');
     *     JiffDate.newInstance(2015, 10, 18).toZonedDateTime(saoPaulo);
     *     // 2015-10-18T01:00:00-02:00[America/Sao_Paulo]
     *
     * Throws if the instant is outside the range of `JiffTimestamp`.
     */
    public JiffZonedDateTime toZonedDateTime(JiffTimeZone tz) {
        return toDateTime(JiffTime.midnight()).toZonedDateTime(tz);
    }

    /**
     * This date at midnight on the clock in the time zone with the given IANA name. Shorthand
     * for `toZonedDateTime(JiffTimeZone.get(name))`; throws if the platform does not know the
     * name.
     */
    public JiffZonedDateTime inTz(String name) {
        return toZonedDateTime(JiffTimeZone.get(name));
    }

    /**
     * Converts this date to a platform `Date` for the same day, for example to store it in a
     * record's date field. The inverse of `fromSystemDate`.
     *
     *     opportunity.CloseDate = closeDate.toSystemDate();
     *
     * Like `fromSystemDate` this is independent of the running user's locale and time zone.
     * Dates before 15 October 1582 become the same day on the timeline in the platform's
     * Julian calendar, so their platform year, month and day can differ from this date's.
     */
    public Date toSystemDate() {
        return Datetime.newInstance(toEpochDay() * JiffMath.MILLIS_PER_CIVIL_DAY).dateGmt();
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * Adds a span to this date. A negative span moves backwards.
     *
     * The units are applied from largest to smallest. Years and months move the date on the
     * calendar first, and if that lands on a day the month does not have, the day is pulled
     * back to the end of the month: `2024-03-31 + 1 month` is `2024-04-30`. Weeks and days
     * are then counted off. Units of time count only as whole 24 hour days: `23 hours`
     * changes nothing and `28 hours` adds one day.
     *
     * Because of the end of month rule, adding a span with years or months and then
     * subtracting it again does not always return to the same date. Spans of weeks and days
     * are always reversible.
     *
     * Throws if the result is outside the supported range.
     */
    public JiffDate add(JiffSpan span) {
        if (span.isZero()) {
            return this;
        }
        if (span.largestUnit() == JiffUnit.DAY && span.smallestUnit() == JiffUnit.DAY) {
            return addDays(span.getDays());
        }
        Long monthIndex = monthValue - 1 + span.getMonths();
        Long year = yearValue + JiffMath.floorDiv(monthIndex, 12L);
        JiffMath.check(year, MIN_YEAR, MAX_YEAR, 'year');
        year = JiffMath.check(year + span.getYears(), MIN_YEAR, MAX_YEAR, 'year');
        JiffDate shifted = constrain(
            year.intValue(),
            JiffMath.floorMod(monthIndex, 12L).intValue() + 1,
            dayValue
        );
        // Every unit of a span has the same sign, so if the total is in range then so is each
        // partial sum, and a single range check at the end is enough.
        Long epochDay = shifted.toEpochDay() + 7 * span.getWeeks() + span.getDays();
        if (span.hasTimeUnits()) {
            // Jiff requires the day count carried by the time units to be a valid epoch day
            // in its own right, which is stricter than requiring the result to be in range.
            epochDay += JiffMath.check(
                span.toInvariantDurationTimeOnly().asSecs() / JiffMath.SECS_PER_CIVIL_DAY,
                MIN_EPOCH_DAY,
                MAX_EPOCH_DAY,
                'Unix epoch days'
            );
        }
        return fromEpochDay(epochDay);
    }

    /**
     * Adds an exact duration to this date. A negative duration moves backwards.
     *
     * Only the whole 24 hour days in the duration count; whatever is left over is dropped, so
     * adding 47 hours moves the date by one day. Throws if the result is outside the
     * supported range.
     */
    public JiffDate add(JiffSignedDuration duration) {
        Long days = duration.asSecs() / JiffMath.SECS_PER_CIVIL_DAY;
        if (JiffMath.lessThan(days, MIN_EPOCH_DAY) || JiffMath.greaterThan(days, MAX_EPOCH_DAY)) {
            throw new JiffException(
                'number of days derived from duration exceed\'s Jiff\'s datetime limits: ' +
                JiffMath.rangeError('Unix epoch days', MIN_EPOCH_DAY, MAX_EPOCH_DAY).getMessage()
            );
        }
        return addDays(days);
    }

    /**
     * Moves this date by a number of days that is small enough for the sum not to overflow.
     * Throws if the result is outside the supported range.
     */
    private JiffDate addDays(Long days) {
        if (days == 0) {
            return this;
        }
        if (days == 1) {
            return tomorrow();
        }
        if (days == -1) {
            return yesterday();
        }
        return fromEpochDay(toEpochDay() + days);
    }

    /**
     * Subtracts a span from this date. The same as adding the span negated; see
     * `add(JiffSpan)` for how each unit is applied.
     */
    public JiffDate subtract(JiffSpan span) {
        return add(span.negate());
    }

    /**
     * Subtracts an exact duration from this date. The same as adding the duration negated;
     * see `add(JiffSignedDuration)`.
     */
    public JiffDate subtract(JiffSignedDuration duration) {
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
    public JiffDate saturatingAdd(JiffSpan span) {
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
    public JiffDate saturatingAdd(JiffSignedDuration duration) {
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
    public JiffDate saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /**
     * Like `subtract(JiffSignedDuration)`, except that instead of throwing when the result is
     * out of range it returns `MIN` (for a positive duration) or `MAX` (for a negative one).
     */
    public JiffDate saturatingSubtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Too negative to negate, so subtracting it certainly overflows forwards.
            return MAX;
        }
        return saturatingAdd(duration.negate());
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this date until `other`, in days. It is negative when `other` is earlier.
     *
     * Subtracting the result from `other` always gives this date back.
     */
    public JiffSpan until(JiffDate other) {
        return until(other, JiffUnit.DAY);
    }

    /**
     * The span from this date until `other`, using units up to `largest`, which must be
     * `DAY`, `WEEK`, `MONTH` or `YEAR` (null means `DAY`). It is negative when `other` is
     * earlier.
     *
     *     JiffDate d1 = JiffDate.newInstance(1995, 12, 7);
     *     JiffDate d2 = JiffDate.newInstance(2019, 1, 31);
     *     d1.until(d2, JiffUnit.YEAR);    // P23Y1M24D
     *     d1.until(d2, JiffUnit.MONTH);   // P277M24D
     *
     * With months or years the answer is the number of whole months that can be added to this
     * date without passing `other`, and then the days left over. Months differ in length, so
     * such a span is tied to its starting point: adding it to this date gives `other`, but
     * subtracting it from `other` may not give this date back. Spans of weeks and days do not
     * have that problem.
     *
     * Nothing is rounded here. This is the exact difference, and the computation that every
     * other form of `until` and `since` builds on.
     *
     * Throws if `largest` is smaller than a day, or if the two dates are so far apart that
     * the difference does not fit in a span of months.
     */
    public JiffSpan until(JiffDate other, JiffUnit largest) {
        JiffUnit unit = largest == null ? JiffUnit.DAY : largest;
        if (!JiffMath.isCalendar(unit)) {
            throw new JiffException(
                '\'' + JiffMath.singular(unit) + '\' not allowed as a date unit for rounding span'
            );
        }
        if (equals(other)) {
            return new JiffSpan();
        }
        if (unit == JiffUnit.DAY) {
            return new JiffSpan().days(other.toEpochDay() - toEpochDay());
        }
        if (unit == JiffUnit.WEEK) {
            Long days = other.toEpochDay() - toEpochDay();
            return new JiffSpan().weeks(days / 7).days(JiffMath.truncMod(days, 7L));
        }
        return untilInMonths(other, unit == JiffUnit.YEAR);
    }

    /**
     * The difference to `other` in years, months and days, or in months and days when
     * `useYears` is false. The two dates must not be equal.
     *
     * This follows the Temporal specification (`CalendarDateUntil`): step from this date
     * toward `other` in whole months for as long as that does not overshoot, clamping to the
     * end of shorter months on the way, and count what remains in days.
     */
    private JiffSpan untilInMonths(JiffDate other, Boolean useYears) {
        Integer year2 = other.yearValue;
        Integer month2 = other.monthValue;
        Integer years = year2 - yearValue;
        Integer months = month2 - monthValue;
        Integer days = other.dayValue - dayValue;
        if (years != 0 || months != 0) {
            Integer sign = JiffMath.signum(years != 0 ? years : months);
            Integer daysInMonth2 = other.daysInMonth();
            Integer dayCorrection = 0;
            if (JiffMath.signum(days) == -sign) {
                // The day of the month falls short of a whole month, so measure the days from
                // the month before `other` (or after it, when going backwards). That month
                // always exists: the dates are on the far side of it from each other.
                Integer originalDaysInMonth2 = daysInMonth2;
                month2 -= sign;
                if (month2 < 1) {
                    year2 -= 1;
                    month2 += 12;
                } else if (month2 > 12) {
                    year2 += 1;
                    month2 -= 12;
                }
                years = year2 - yearValue;
                months = month2 - monthValue;
                daysInMonth2 = daysInMonth(year2, month2);
                dayCorrection = sign < 0 ? -originalDaysInMonth2 : daysInMonth2;
            }
            days = other.dayValue - Math.min(dayValue, daysInMonth2) + dayCorrection;
            if (years != 0 && JiffMath.signum(months) == -sign) {
                // Likewise the month falls short of a whole year.
                years -= sign;
                months += sign * 12;
            }
        }
        if (!useYears) {
            months += years * 12;
            years = 0;
        }
        return new JiffSpan().years(years).months(months).days(days);
    }

    /**
     * The span from `other` until this date, in days. It is negative when `other` is later.
     * This is `until(other)` with the sign flipped.
     */
    public JiffSpan since(JiffDate other) {
        return until(other).negate();
    }

    /**
     * The span from `other` until this date, using units up to `largest`. It is negative when
     * `other` is later.
     *
     * This is `until(other, largest)` with the sign flipped: the months are still counted
     * starting from this date, going back to `other`. That is not always the same as
     * `other.until(this, largest)`, which counts forward from `other`. From `2020-04-30` back
     * to `2020-02-29` is exactly two months, while from `2020-02-29` forward to `2020-04-30`
     * is two months and a day.
     */
    public JiffSpan since(JiffDate other, JiffUnit largest) {
        return until(other, largest).negate();
    }

    /**
     * The span from this date until `other`, with the units and rounding `options` ask for.
     *
     * The largest unit defaults to the smallest one, and the smallest to `DAY`; both must be
     * days or bigger. When the smallest unit is bigger than a day, or the increment is not 1,
     * the difference is rounded as `JiffSpan.round` does, measured from this date.
     *
     *     JiffDate d1 = JiffDate.newInstance(2024, 3, 15);
     *     JiffDate d2 = JiffDate.newInstance(2030, 9, 13);
     *     d1.until(d2, new JiffDifference().smallest(JiffUnit.YEAR).mode(JiffRoundMode.HALF_EXPAND));
     *     // P6Y
     *
     * Throws when a unit is smaller than a day, the increment is out of range, or the result
     * does not fit.
     *
     * Mirrors `Date::until` with a `DateDifference`.
     */
    public JiffSpan until(JiffDate other, JiffDifference options) {
        return difference(other, options, false);
    }

    /**
     * The span from `other` until this date, with the units and rounding `options` ask for.
     * This is `until(other, options)` before rounding, negated; the rounding is then measured
     * from this date. See `until(JiffDate, JiffDifference)`.
     *
     * Mirrors `Date::since` with a `DateDifference`.
     */
    public JiffSpan since(JiffDate other, JiffDifference options) {
        return difference(other, options, true);
    }

    private JiffSpan difference(JiffDate other, JiffDifference options, Boolean negate) {
        JiffDifference config = options == null ? new JiffDifference() : options;
        JiffUnit smallest = config.getSmallest() == null ? JiffUnit.DAY : config.getSmallest();
        if (!JiffMath.isCalendar(smallest)) {
            throw new JiffException(
                '\'' +
                    JiffMath.singular(smallest) +
                    '\' not allowed as a date unit for rounding span'
            );
        }
        JiffSpan span = until(other, config.getLargest() == null ? smallest : config.getLargest());
        return JiffSpanRelative.roundDifference(
            negate ? span.negate() : span,
            config,
            smallest,
            JiffSpanRelativeTo.fromDate(this),
            true
        );
    }

    /**
     * The exact length of time from this date until `other`, counting every day as 24 hours.
     * It is negative when `other` is earlier. This never fails.
     *
     * Prefer `until` unless you specifically need an absolute duration.
     */
    public JiffSignedDuration durationUntil(JiffDate other) {
        return JiffSignedDuration.fromHours(24 * (other.toEpochDay() - toEpochDay()));
    }

    /**
     * The exact length of time from `other` until this date, counting every day as 24 hours.
     * It is negative when `other` is later. This never fails.
     */
    public JiffSignedDuration durationSince(JiffDate other) {
        return other.durationUntil(this);
    }

    /**
     * The dates a fixed span apart, starting with this one: this date, this date plus
     * `period`, this date plus twice `period`, and so on. A negative period walks backwards.
     *
     *     // Every Halloween of the 2020s.
     *     JiffDate first = JiffDate.newInstance(2020, 10, 31);
     *     for (JiffDate halloween : first.series(new JiffSpan().years(1))) {
     *         if (halloween.year() > 2029) {
     *             break;
     *         }
     *         // ...
     *     }
     *
     * The series has no end of its own; it stops only when it leaves the supported range, so
     * a loop over it needs its own exit. See `JiffDateSeries`.
     */
    public JiffDateSeries series(JiffSpan period) {
        return new JiffDateSeries(this, period);
    }

    // ---- comparison -----------------------------------------------------

    /**
     * Orders dates chronologically: negative when this date is earlier than `other`, zero
     * when they are the same day and positive when it is later.
     */
    public Integer compareTo(Object other) {
        JiffDate that = (JiffDate) other;
        if (yearValue != that.yearValue) {
            return yearValue < that.yearValue ? -1 : 1;
        }
        if (monthValue != that.monthValue) {
            return monthValue < that.monthValue ? -1 : 1;
        }
        return dayValue < that.dayValue ? -1 : (dayValue > that.dayValue ? 1 : 0);
    }

    /** Whether this date is strictly earlier than `other`. */
    public Boolean isBefore(JiffDate other) {
        return compareTo(other) < 0;
    }

    /** Whether this date is strictly later than `other`. */
    public Boolean isAfter(JiffDate other) {
        return compareTo(other) > 0;
    }

    /** Whether `other` is a date with the same year, month and day. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffDate)) {
            return false;
        }
        JiffDate that = (JiffDate) other;
        return yearValue == that.yearValue &&
            monthValue == that.monthValue &&
            dayValue == that.dayValue;
    }

    /** A hash consistent with `equals`, so dates can be map keys and set members. */
    public Integer hashCode() {
        return (yearValue * 13 + monthValue) * 32 + dayValue;
    }

    // ---- strftime / strptime ------------------------------------------------

    /**
     * Parses a civil date from `input` according to the `strptime` format `format`. The
     * conversion specifiers are listed in `JiffStrtime`.
     *
     *     JiffDate.strptime('%m/%d/%y', '7/14/24');   // 2024-07-14
     *
     * Throws `JiffException` when the format is invalid, when the input does not match it, or
     * when the input has no year, or nothing that finds the day in the year.
     *
     * Mirrors `jiff::civil::Date::strptime`.
     */
    public static JiffDate strptime(String format, String input) {
        return JiffStrtime.parse(format, input).toDate();
    }

    /**
     * Formats this date according to the `strftime` format `format`. The conversion
     * specifiers are listed in `JiffStrtime`.
     *
     *     JiffDate.newInstance(2024, 7, 15).strftime('%Y-%m-%d is a %A');
     *     // 2024-07-15 is a Monday
     *
     * This never throws for a non-null format. A specifier that cannot be applied, such as
     * `%H` or `%z`, or an unknown one, is written out literally. To have such mistakes
     * reported instead, use `JiffStrtime.format`.
     *
     * Mirrors `jiff::civil::Date::strftime`.
     */
    public String strftime(String format) {
        return JiffStrtime.formatLenient(format, JiffBrokenDownTime.fromDate(this));
    }

    /** Formats this date as ISO 8601, for example `2024-02-29`. */
    public override String toString() {
        return JiffTemporal.printDate(this);
    }
}
