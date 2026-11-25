/**
 * The "broken down time" that `strptime` parses into and `strftime` formats from: a set of
 * individually optional datetime fields, like C's `struct tm`.
 *
 * Parsing fills in only the fields the format names; the `to...` methods then assemble the
 * value you ask for and say what is missing:
 *
 *     JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%m/%d/%y', '7/14/24');
 *     tm.toDate();   // 2024-07-14
 *     tm.month();    // 7
 *     tm.hour();     // null: the format had no hour
 *
 * Formatting starts from a value converted with one of the `from...` methods:
 *
 *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 7, 9).at(16, 24, 0, 0)
 *         .inTz('America/New_York');
 *     JiffBrokenDownTime.fromZonedDateTime(zdt).format('%a %b %e %I:%M:%S %p %Z %Y');
 *     // Tue Jul  9 04:24:00 PM EDT 2024
 *
 * The conversion specifiers are listed in `JiffStrtime`. Most code uses the `strftime` and
 * `strptime` methods of the datetime types instead; this type gives more control: formatting
 * that reports errors rather than writing a specifier literally, access to fields that were
 * parsed but are not part of the result (a weekday, a day of the year), and setters to fill in
 * or clear fields between parsing and conversion.
 *
 * Instances are immutable. Each `with...` setter returns a copy with that field changed; null
 * clears it. Setters check that a value is legal for the field in some context (a day of `31`
 * is accepted even with a month of `4`); whether the fields fit together is checked only when
 * a value is assembled.
 *
 * Fields that hold small numbers in Jiff (`i8`, `i16`, `i32`) are `Integer` here; every getter
 * returns null for a field that is not set.
 *
 * Mirrors `jiff::fmt::strtime::BrokenDownTime`.
 */
public class JiffBrokenDownTime {
    private Integer yearValue;
    private Integer monthValue;
    private Integer dayValue;
    private Integer dayOfYearValue;
    private Integer isoWeekYearValue;
    private Integer isoWeekValue;
    private Integer weekSunValue = null;
    private Integer weekMonValue = null;
    private Integer hourValue;
    private Integer minuteValue;
    private Integer secondValue;
    private Integer subsecValue;
    private JiffOffset offsetValue;
    private JiffWeekday weekdayValue;
    private JiffMeridiem meridiemValue;
    private JiffTimestamp timestampValue;
    // The time zone of a zoned datetime this was made from. Only `%Z` uses it.
    private JiffTimeZone zoneValue;
    private String ianaValue;

    /** A broken down time with no fields set. */
    public JiffBrokenDownTime() {
    }

    // ---- parsing and formatting -------------------------------------------

    /**
     * Parses `input` according to `format`, which must match all of it. Throws when the format
     * is invalid or the input does not match it.
     *
     *     JiffBrokenDownTime.parse('%m/%d/%y', '7/14/24').toDate();   // 2024-07-14
     */
    public static JiffBrokenDownTime parse(String format, String input) {
        return JiffStrtimeParser.parse(format, input);
    }

    /**
     * Like `parse`, but the format only has to match a prefix of `input`. The result also says
     * how much of the input was used:
     *
     *     JiffBrokenDownTimePrefix p = JiffBrokenDownTime.parsePrefix('%m/%d/%y', '7/14/2499');
     *     p.value().toDate();   // 2024-07-14
     *     p.consumed();         // 7: `99` is left over
     */
    public static JiffBrokenDownTimePrefix parsePrefix(String format, String input) {
        return JiffStrtimeParser.parsePrefix(format, input);
    }

    /**
     * Formats this broken down time with the default configuration. Throws when the format is
     * invalid, or when it asks for a field that is not available: formatting a date with `%H`
     * or a civil datetime with `%z`.
     */
    public String format(String format) {
        return format(format, new JiffStrtimeConfig());
    }

    /**
     * Formats this broken down time with the given configuration: lenient mode, or another
     * `JiffStrtimeCustom` for `%c`, `%r`, `%X` and `%x`.
     */
    public String format(String format, JiffStrtimeConfig config) {
        if (config == null) {
            throw new JiffException('strtime configuration must not be null');
        }
        return JiffStrtimeFormatter.format(config, format, this);
    }

    // ---- conversions from datetime types ------------------------------------

    /** The year, month and day of a date. */
    public static JiffBrokenDownTime fromDate(JiffDate value) {
        require(value, 'date');
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        tm.yearValue = value.year();
        tm.monthValue = value.month();
        tm.dayValue = value.day();
        return tm;
    }

    /** The hour, minute, second, fraction and meridiem of a time. */
    public static JiffBrokenDownTime fromTime(JiffTime value) {
        require(value, 'time');
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        tm.setTimeFields(value);
        return tm;
    }

    /** The date and time fields of a civil datetime. */
    public static JiffBrokenDownTime fromDateTime(JiffDateTime value) {
        require(value, 'datetime');
        JiffBrokenDownTime tm = fromDate(value.toDate());
        tm.setTimeFields(value.toTime());
        return tm;
    }

    /** The week year, week and weekday of an ISO 8601 week date. */
    public static JiffBrokenDownTime fromIsoWeekDate(JiffIsoWeekDate value) {
        require(value, 'ISO week date');
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        tm.isoWeekYearValue = value.year();
        tm.isoWeekValue = value.week();
        tm.weekdayValue = value.weekday();
        return tm;
    }

    /** A timestamp, with its civil datetime in UTC and a UTC offset of zero. */
    public static JiffBrokenDownTime fromTimestamp(JiffTimestamp value) {
        require(value, 'timestamp');
        JiffBrokenDownTime tm = fromDateTime(JiffOffset.UTC.toDateTime(value));
        tm.offsetValue = JiffOffset.UTC;
        tm.timestampValue = value;
        return tm;
    }

    /**
     * A zoned datetime: its civil datetime, offset, timestamp, time zone (for `%Z`) and the
     * IANA name of the time zone when it has one.
     */
    public static JiffBrokenDownTime fromZonedDateTime(JiffZonedDateTime value) {
        require(value, 'zoned datetime');
        JiffBrokenDownTime tm = fromDateTime(value.toDateTime());
        tm.offsetValue = value.offset();
        tm.timestampValue = value.toTimestamp();
        tm.zoneValue = value.timeZone();
        tm.ianaValue = value.timeZone().ianaName();
        return tm;
    }

    private void setTimeFields(JiffTime value) {
        hourValue = value.hour();
        minuteValue = value.minute();
        secondValue = value.second();
        subsecValue = value.subsecNanosecond();
        meridiemValue = value.hour() < 12 ? JiffMeridiem.AM : JiffMeridiem.PM;
    }

    private static void require(Object value, String what) {
        if (value == null) {
            throw new JiffException('cannot make a broken down time from a null ' + what);
        }
    }

    // ---- conversions to datetime types --------------------------------------

    /**
     * The zoned datetime these fields describe. An explicitly set timestamp (from `%s`) wins
     * over the civil fields. The time zone is the one named by the IANA identifier (from `%Q`),
     * looked up with `JiffTimeZone.get`, or else a fixed zone at the offset (from `%z`).
     *
     * When both an offset and an IANA identifier are present they must agree, or this throws.
     * With an identifier and no offset, an ambiguous civil datetime is resolved with the
     * `compatible` strategy. A timestamp without either gives a zoned datetime in
     * `JiffTimeZone.unknown()`.
     *
     *     JiffBrokenDownTime.parse('%F %H:%M %:z %:Q', '2024-07-14 21:14 -04:00 America/New_York')
     *         .toZonedDateTime();   // 2024-07-14T21:14:00-04:00[America/New_York]
     */
    public JiffZonedDateTime toZonedDateTime() {
        String iana = ianaTimeZone();
        if (offsetValue == null && iana == null) {
            if (timestampValue != null) {
                return timestampValue.toZonedDateTime(JiffTimeZone.unknown());
            }
            throw new JiffException(
                'either offset (from `%z`) or IANA time zone identifier ' +
                '(from `%Q`) is required for parsing zoned datetime'
            );
        }
        if (iana == null) {
            JiffTimestamp ts = timestampValue;
            if (ts == null) {
                ts = toTimestampAt(offsetValue, dateTimeForZoned());
            }
            return ts.toZonedDateTime(JiffTimeZone.fixed(offsetValue));
        }
        JiffTimeZone tz = JiffTimeZone.get(iana);
        if (offsetValue == null) {
            if (timestampValue != null) {
                return timestampValue.toZonedDateTime(tz);
            }
            return tz.toZonedDateTime(dateTimeForZoned());
        }
        if (timestampValue != null) {
            JiffZonedDateTime zdt = timestampValue.toZonedDateTime(tz);
            if (!zdt.offset().equals(offsetValue)) {
                throw new JiffException(
                    'parsed time zone offset `' +
                        offsetValue +
                        '`, but offset from timestamp and time zone is `' +
                        zdt.offset() +
                        '`'
                );
            }
            return zdt;
        }
        return JiffOffsetConflicts.resolve(
                JiffOffsetConflict.REJECT,
                dateTimeForZoned(),
                offsetValue,
                tz
            )
            .unambiguous();
    }

    private JiffDateTime dateTimeForZoned() {
        try {
            return toDateTime();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('datetime required to parse zoned datetime', e);
        }
    }

    /**
     * The instant these fields describe. An explicitly set timestamp (from `%s`) wins;
     * otherwise this needs a civil datetime and an offset.
     *
     *     JiffBrokenDownTime.parse('%F %H:%M %:z', '2024-07-14 21:14 -04:00').toTimestamp();
     *     // 2024-07-15T01:14:00Z
     */
    public JiffTimestamp toTimestamp() {
        if (timestampValue != null) {
            return timestampValue;
        }
        JiffDateTime dt;
        try {
            dt = toDateTime();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('datetime required to parse timestamp', e);
        }
        if (offsetValue == null) {
            throw new JiffException('offset required to parse timestamp');
        }
        return toTimestampAt(offsetValue, dt);
    }

    private static JiffTimestamp toTimestampAt(JiffOffset offset, JiffDateTime dt) {
        try {
            return offset.toTimestamp(dt);
        } catch (JiffException e) {
            throw JiffFmtUtil.context(
                'parsed datetime and offset, but combining them into a zoned datetime ' +
                'is outside Jiff\'s supported timestamp range',
                e
            );
        }
    }

    /**
     * The civil datetime these fields describe: a date (see `toDate`) and a time (see
     * `toTime`, which defaults to midnight).
     */
    public JiffDateTime toDateTime() {
        JiffDate datePart;
        try {
            datePart = toDate();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('date required to parse datetime', e);
        }
        JiffTime timePart;
        try {
            timePart = toTime();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('time required to parse datetime', e);
        }
        return JiffDateTime.fromParts(datePart, timePart);
    }

    /**
     * The civil date these fields describe. This needs a year (Gregorian, or an ISO 8601 week
     * year) and a way to find the day in it, tried in this order: a month and day, an ISO week
     * and weekday, a day of the year, a Sunday based week and weekday, a Monday based week and
     * weekday. A parsed weekday must agree with the date.
     *
     *     JiffBrokenDownTime.parse('%Y-%j', '2024-60').toDate();   // 2024-02-29
     */
    public JiffDate toDate() {
        JiffDate result;
        if (yearValue == null) {
            result = dateFromIso();
            if (result != null) {
                return result;
            }
            throw new JiffException('year required to parse date');
        }
        result = dateFromGregorian();
        if (result == null) {
            result = dateFromIso();
        }
        if (result == null) {
            result = dateFromDayOfYear();
        }
        if (result == null) {
            result = dateFromWeek(weekSunValue, JiffWeekday.SUNDAY);
        }
        if (result == null) {
            result = dateFromWeek(weekMonValue, JiffWeekday.MONDAY);
        }
        if (result == null) {
            throw new JiffException(
                'a month/day, day-of-year or week date must be present to create a date, ' +
                'but none were found'
            );
        }
        if (weekdayValue != null && weekdayValue != result.weekday()) {
            throw new JiffException(
                'parsed weekday `' +
                    JiffFmtUtil.weekdayName(weekdayValue) +
                    '` does not match weekday `' +
                    JiffFmtUtil.weekdayName(result.weekday()) +
                    '` from parsed date'
            );
        }
        return result;
    }

    private JiffDate dateFromGregorian() {
        if (monthValue == null || dayValue == null) {
            return null;
        }
        try {
            return JiffDate.newInstance(yearValue, monthValue, dayValue);
        } catch (JiffException e) {
            throw JiffFmtUtil.context('invalid date', e);
        }
    }

    private JiffDate dateFromIso() {
        if (isoWeekYearValue == null || isoWeekValue == null || weekdayValue == null) {
            return null;
        }
        try {
            return JiffIsoWeekDate.newInstance(isoWeekYearValue, isoWeekValue, weekdayValue)
                .toDate();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('invalid ISO 8601 week date', e);
        }
    }

    private JiffDate dateFromDayOfYear() {
        if (dayOfYearValue == null) {
            return null;
        }
        return dayOfYearInYear(dayOfYearValue);
    }

    private JiffDate dayOfYearInYear(Integer dayOfYear) {
        try {
            return JiffDate.newInstance(yearValue, 1, 1).with().dayOfYear(dayOfYear).build();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('invalid date', e);
        }
    }

    // A date from a week number where week 1 starts on the first `start` (Sunday or Monday)
    // of the year, and the days before it are in week 0.
    private JiffDate dateFromWeek(Integer week, JiffWeekday start) {
        if (week == null || weekdayValue == null) {
            return null;
        }
        Boolean sunday = start == JiffWeekday.SUNDAY;
        Integer weekdayNumber = sunday
            ? JiffWeekdays.toSundayZeroOffset(weekdayValue)
            : JiffWeekdays.toMondayZeroOffset(weekdayValue);
        // The setters keep the year in range, so January 1st always exists.
        JiffDate firstOfYear = JiffDate.newInstance(yearValue, 1, 1);
        Integer firstStart = firstOfYear.nthWeekdayOfMonth(1, start).dayOfYear();
        Integer dayOfYear;
        if (week == 0) {
            dayOfYear = firstStart - (7 - weekdayNumber);
            if (dayOfYear == 0) {
                throw new JiffException(
                    'weekday `' +
                        JiffFmtUtil.weekdayName(weekdayValue) +
                        '` is not valid for ' +
                        (sunday ? 'Sunday' : 'Monday') +
                        ' based week number'
                );
            }
        } else {
            dayOfYear = firstStart + (week - 1) * 7 + weekdayNumber;
        }
        return dayOfYearInYear(dayOfYear);
    }

    /**
     * The civil time these fields describe. Missing fields default to zero, and with no time
     * fields at all this is midnight. But a smaller unit without the larger ones (a minute
     * without an hour) throws.
     *
     *     JiffBrokenDownTime.parse('%H:%M:%S', '21:14:59').toTime();   // 21:14:59
     */
    public JiffTime toTime() {
        String smallerThanHour = 'parsing format did not include hour directive, but did include ';
        String smallerThanMinute = 'parsing format did not include minute directive, but did include ';
        String smallerThanSecond = 'parsing format did not include second directive, but did include ';
        String fraction = 'fractional second directive';
        if (hourValue == null) {
            if (minuteValue != null) {
                throw missingUnit(smallerThanHour + 'minute directive');
            }
            if (secondValue != null) {
                throw missingUnit(smallerThanHour + 'second directive');
            }
            if (subsecValue != null) {
                throw missingUnit(smallerThanHour + fraction);
            }
            return JiffTime.midnight();
        }
        if (minuteValue == null) {
            if (secondValue != null) {
                throw missingUnit(smallerThanMinute + 'second directive');
            }
            if (subsecValue != null) {
                throw missingUnit(smallerThanMinute + fraction);
            }
            return JiffTime.newInstance(hourValue, 0, 0, 0);
        }
        if (secondValue == null) {
            if (subsecValue != null) {
                throw missingUnit(smallerThanSecond + fraction);
            }
            return JiffTime.newInstance(hourValue, minuteValue, 0, 0);
        }
        return JiffTime.newInstance(
            hourValue,
            minuteValue,
            secondValue,
            subsecValue == null ? 0 : subsecValue
        );
    }

    private static JiffException missingUnit(String message) {
        return new JiffException(
            message + ' (cannot have smaller time units with bigger time units missing)'
        );
    }

    // ---- getters ------------------------------------------------------------

    /** The year, or null. A two digit year from `%y` is already in `1969..2068`. */
    public Integer year() {
        return yearValue;
    }

    /** The month, `1..12`, or null. */
    public Integer month() {
        return monthValue;
    }

    /** The day of the month, `1..31`, or null. */
    public Integer day() {
        return dayValue;
    }

    /** The day of the year, `1..366`, or null. */
    public Integer dayOfYear() {
        return dayOfYearValue;
    }

    /** The ISO 8601 week-based year, or null. */
    public Integer isoWeekYear() {
        return isoWeekYearValue;
    }

    /** The ISO 8601 week number, `1..53`, or null. */
    public Integer isoWeek() {
        return isoWeekValue;
    }

    /**
     * The Sunday based week number (`%U`), `0..53`, or null. Week 1 starts on the first Sunday
     * of the year; the days before it are in week 0.
     */
    public Integer sundayBasedWeek() {
        return weekSunValue;
    }

    /**
     * The Monday based week number (`%W`), `0..53`, or null. Week 1 starts on the first Monday
     * of the year; the days before it are in week 0.
     */
    public Integer mondayBasedWeek() {
        return weekMonValue;
    }

    /**
     * The hour, `0..23`, or null. A meridiem has already been applied: `1` with `PM` is `13`,
     * and the meridiem wins when the two disagree (`13` with `AM` is `1`).
     */
    public Integer hour() {
        return hourValue;
    }

    /** The minute, `0..59`, or null. */
    public Integer minute() {
        return minuteValue;
    }

    /** The second, `0..59`, or null. A parsed leap second of `60` is `59` here. */
    public Integer second() {
        return secondValue;
    }

    /** The fraction of the second in nanoseconds, or null. */
    public Integer subsecNanosecond() {
        return subsecValue;
    }

    /** The UTC offset, or null. */
    public JiffOffset offset() {
        return offsetValue;
    }

    /** The IANA time zone identifier, or null. */
    public String ianaTimeZone() {
        return ianaValue;
    }

    /**
     * The weekday, or null. Only a weekday that was parsed or set is returned, even when it
     * disagrees with the date; `toDate` is where they are checked against each other.
     */
    public JiffWeekday weekday() {
        return weekdayValue;
    }

    /** The meridiem (AM or PM), or null. */
    public JiffMeridiem meridiem() {
        return meridiemValue;
    }

    /**
     * The timestamp that was parsed (`%s`), set, or came from a timestamp or zoned datetime,
     * or null. Unlike `toTimestamp`, this never assembles one from the other fields.
     */
    public JiffTimestamp timestamp() {
        return timestampValue;
    }

    // ---- setters ------------------------------------------------------------

    /** Sets the year (`-9999..9999`). Throws when it is out of range. */
    public JiffBrokenDownTime withYear(Integer year) {
        JiffBrokenDownTime tm = copy();
        tm.yearValue = year == null ? null : checked(year, -9999L, 9999L, 'year');
        return tm;
    }

    /** Sets the month (`1..12`). Throws when it is out of range. */
    public JiffBrokenDownTime withMonth(Integer month) {
        JiffBrokenDownTime tm = copy();
        tm.monthValue = month == null ? null : checked(month, 1L, 12L, 'month');
        return tm;
    }

    /**
     * Sets the day of the month (`1..31`). Throws when it is out of range, but not when it is
     * too large for the month already set: that is checked when a date is assembled.
     */
    public JiffBrokenDownTime withDay(Integer day) {
        JiffBrokenDownTime tm = copy();
        tm.dayValue = day == null ? null : checked(day, 1L, 31L, 'day');
        return tm;
    }

    /** Sets the day of the year (`1..366`). Throws when it is out of range. */
    public JiffBrokenDownTime withDayOfYear(Integer day) {
        JiffBrokenDownTime tm = copy();
        tm.dayOfYearValue = day == null ? null : checked(day, 1L, 366L, 'day-of-year');
        return tm;
    }

    /** Sets the ISO 8601 week-based year (`-9999..9999`). Throws when it is out of range. */
    public JiffBrokenDownTime withIsoWeekYear(Integer year) {
        JiffBrokenDownTime tm = copy();
        tm.isoWeekYearValue = year == null ? null : checked(year, -9999L, 9999L, 'iso-year');
        return tm;
    }

    /** Sets the ISO 8601 week number (`1..53`). Throws when it is out of range. */
    public JiffBrokenDownTime withIsoWeek(Integer week) {
        JiffBrokenDownTime tm = copy();
        tm.isoWeekValue = week == null ? null : checked(week, 1L, 53L, 'iso-week');
        return tm;
    }

    /** Sets the Sunday based week number (`0..53`). Throws when it is out of range. */
    public JiffBrokenDownTime withSundayBasedWeek(Integer week) {
        JiffBrokenDownTime tm = copy();
        tm.weekSunValue = week == null ? null : checked(week, 0L, 53L, 'week-number');
        return tm;
    }

    /** Sets the Monday based week number (`0..53`). Throws when it is out of range. */
    public JiffBrokenDownTime withMondayBasedWeek(Integer week) {
        JiffBrokenDownTime tm = copy();
        tm.weekMonValue = week == null ? null : checked(week, 0L, 53L, 'week-number');
        return tm;
    }

    /**
     * Sets the hour (`0..23`). Throws when it is out of range. When a meridiem is set, it is
     * applied: `3` with `PM` becomes `15`.
     */
    public JiffBrokenDownTime withHour(Integer hour) {
        JiffBrokenDownTime tm = copy();
        tm.hourValue = hour == null ? null : checked(hour, 0L, 23L, 'hour');
        if (tm.hourValue != null && meridiemValue != null) {
            tm.hourValue = adjustHour(meridiemValue, tm.hourValue);
        }
        return tm;
    }

    /** Sets the minute (`0..59`). Throws when it is out of range. */
    public JiffBrokenDownTime withMinute(Integer minute) {
        JiffBrokenDownTime tm = copy();
        tm.minuteValue = minute == null ? null : checked(minute, 0L, 59L, 'minute');
        return tm;
    }

    /** Sets the second (`0..59`; there are no leap seconds). Throws when it is out of range. */
    public JiffBrokenDownTime withSecond(Integer second) {
        JiffBrokenDownTime tm = copy();
        tm.secondValue = second == null ? null : checked(second, 0L, 59L, 'second');
        return tm;
    }

    /**
     * Sets the fraction of the second in nanoseconds (`0..999,999,999`). Throws when it is out
     * of range.
     */
    public JiffBrokenDownTime withSubsecNanosecond(Integer subsecNanosecond) {
        JiffBrokenDownTime tm = copy();
        tm.subsecValue = subsecNanosecond == null
            ? null
            : checked(subsecNanosecond, 0L, 999999999L, 'subsecond nanosecond');
        return tm;
    }

    /**
     * Sets the UTC offset. Nothing else changes, even when the offset disagrees with the other
     * fields; this is useful to supply an offset that the parsed text lacked.
     */
    public JiffBrokenDownTime withOffset(JiffOffset offset) {
        JiffBrokenDownTime tm = copy();
        tm.offsetValue = offset;
        return tm;
    }

    /**
     * Sets the IANA time zone identifier. Any text is accepted; it is only looked up when a
     * zoned datetime is assembled. Nothing else changes.
     */
    public JiffBrokenDownTime withIanaTimeZone(String ianaTimeZone) {
        JiffBrokenDownTime tm = copy();
        tm.ianaValue = ianaTimeZone;
        return tm;
    }

    /**
     * Sets the weekday. Clearing a parsed weekday skips the check that it agrees with the
     * date.
     */
    public JiffBrokenDownTime withWeekday(JiffWeekday weekday) {
        JiffBrokenDownTime tm = copy();
        tm.weekdayValue = weekday;
        return tm;
    }

    /**
     * Sets the meridiem and applies it to the hour, if one is set: `3` becomes `15` with `PM`,
     * and `13` becomes `1` with `AM`.
     */
    public JiffBrokenDownTime withMeridiem(JiffMeridiem meridiem) {
        JiffBrokenDownTime tm = copy();
        if (meridiem != null && tm.hourValue != null) {
            tm.hourValue = adjustHour(meridiem, tm.hourValue);
        }
        tm.meridiemValue = meridiem;
        return tm;
    }

    /**
     * Sets an explicit timestamp, which `toTimestamp` and `toZonedDateTime` prefer over the
     * civil fields.
     */
    public JiffBrokenDownTime withTimestamp(JiffTimestamp timestamp) {
        JiffBrokenDownTime tm = copy();
        tm.timestampValue = timestamp;
        return tm;
    }

    private static Integer adjustHour(JiffMeridiem meridiem, Integer hour) {
        Integer onTwelve = Math.mod(hour, 12);
        return meridiem == JiffMeridiem.AM ? onTwelve : onTwelve + 12;
    }

    private static Integer checked(Integer value, Long min, Long max, String what) {
        JiffMath.check(value, min, max, what);
        return value;
    }

    private JiffBrokenDownTime copy() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        tm.yearValue = yearValue;
        tm.monthValue = monthValue;
        tm.dayValue = dayValue;
        tm.dayOfYearValue = dayOfYearValue;
        tm.isoWeekYearValue = isoWeekYearValue;
        tm.isoWeekValue = isoWeekValue;
        tm.weekSunValue = weekSunValue;
        tm.weekMonValue = weekMonValue;
        tm.hourValue = hourValue;
        tm.minuteValue = minuteValue;
        tm.secondValue = secondValue;
        tm.subsecValue = subsecValue;
        tm.offsetValue = offsetValue;
        tm.weekdayValue = weekdayValue;
        tm.meridiemValue = meridiemValue;
        tm.timestampValue = timestampValue;
        tm.zoneValue = zoneValue;
        tm.ianaValue = ianaValue;
        return tm;
    }

    /**
     * The time zone of the zoned datetime this was made from, or null. Internal: `%Z` reads
     * it. Jiff has no public accessor for it.
     */
    public JiffTimeZone timeZoneForAbbreviation() {
        return zoneValue;
    }
}
