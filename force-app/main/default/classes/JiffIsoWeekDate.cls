/**
 * A date in the ISO 8601 week calendar: a year, a week number and a day of the week.
 *
 * The week calendar has no months. Every week starts on a Monday and belongs wholly to one
 * year, and week `1` of a year is the week that contains that year's first Thursday. A year
 * therefore has either 52 or 53 whole weeks, and near the turn of the year the week year can
 * differ from the Gregorian year: `1995-01-01` is `1994-W52-7`, the Sunday of the last week of
 * 1994.
 *
 *     JiffIsoWeekDate weekDate = JiffDate.newInstance(2019, 12, 30).toIsoWeekDate();
 *     weekDate.year();      // 2020
 *     weekDate.week();      // 1
 *     weekDate.weekday();   // JiffWeekday.MONDAY
 *     weekDate.toString();  // 2020-W01-1
 *     weekDate.toDate();    // 2019-12-30
 *
 * Use this type when work is organised by numbered weeks. Otherwise `JiffDate` is the type you
 * want.
 *
 * The supported range matches `JiffDate` exactly, from `-9999-W01-1` (`-9999-01-01`) through
 * `9999-W52-5` (`9999-12-31`), so converting between the two never fails. Instances are
 * immutable and ordered chronologically.
 *
 * Mirrors `jiff::civil::ISOWeekDate`.
 */
public class JiffIsoWeekDate implements Comparable {
    private static final Integer MIN_YEAR = -9999;
    private static final Integer MAX_YEAR = 9999;

    /** The earliest supported week date, `-9999-W01-1`, which is `-9999-01-01`. */
    public static final JiffIsoWeekDate MIN = new JiffIsoWeekDate(MIN_YEAR, 1, JiffWeekday.MONDAY);
    /** The latest supported week date, `9999-W52-5`, which is `9999-12-31`. */
    public static final JiffIsoWeekDate MAX = new JiffIsoWeekDate(MAX_YEAR, 52, JiffWeekday.FRIDAY);
    /** The first day of week year zero, `0000-W01-1`. Note that this is `0000-01-03`. */
    public static final JiffIsoWeekDate ZERO = new JiffIsoWeekDate(0, 1, JiffWeekday.MONDAY);

    private final Integer yearValue;
    private final Integer weekValue;
    private final JiffWeekday weekdayValue;

    private JiffIsoWeekDate(Integer yearValue, Integer weekValue, JiffWeekday weekdayValue) {
        this.yearValue = yearValue;
        this.weekValue = weekValue;
        this.weekdayValue = weekdayValue;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Creates a week date from a week year (`-9999..9999`), a week number (`1..53`) and a day
     * of the week.
     *
     * Throws if a component is out of range, if week `53` is given for a year that has only
     * 52 weeks, or if the day falls after `9999-12-31` (the Saturday and Sunday of the last
     * week of year `9999`).
     */
    public static JiffIsoWeekDate newInstance(Integer year, Integer week, JiffWeekday weekday) {
        if (weekday == null) {
            throw new JiffException('weekday must not be null');
        }
        JiffMath.check(year, MIN_YEAR, MAX_YEAR, 'iso-year');
        JiffMath.check(week, 1L, 53L, 'iso-week');
        if (week == 53 && !isLongYear(year)) {
            throw JiffMath.rangeError('iso-week', 1L, 53L);
        }
        // The last supported date, 9999-12-31, is the Friday of week 52. The two days after
        // it are valid week dates on paper but have no Gregorian date this library can hold.
        if (year == MAX_YEAR && week == 52 && weekday.ordinal() > JiffWeekday.FRIDAY.ordinal()) {
            throw JiffMath.rangeError('weekday (Monday 1-indexed)', 1L, 7L);
        }
        return new JiffIsoWeekDate(year, week, weekday);
    }

    /**
     * Converts a Gregorian date to its ISO 8601 week date. This never fails. Equivalent to
     * `JiffDate.toIsoWeekDate()`.
     */
    public static JiffIsoWeekDate fromDate(JiffDate value) {
        Long epochDay = value.toEpochDay();
        Integer year = value.year();
        Long yearStart = weekYearStart(year);
        if (epochDay < yearStart) {
            // January 1st to 3rd can fall in the last week of the previous week year. This
            // cannot happen in year -9999, which starts on a Monday.
            year -= 1;
            yearStart = weekYearStart(year);
        } else if (value.month() == 12 && value.day() >= 29 && year < MAX_YEAR) {
            // December 29th to 31st can fall in the first week of the next week year. Year
            // 9999 needs no check: its last day is the Friday of week 52.
            Long nextYearStart = weekYearStart(year + 1);
            if (epochDay >= nextYearStart) {
                yearStart = nextYearStart;
                year += 1;
            }
        }
        Long week = (epochDay - yearStart) / 7 + 1;
        return new JiffIsoWeekDate(year, week.intValue(), value.weekday());
    }

    /**
     * The epoch day of the Monday that starts week 1 of week year `year`.
     *
     * A week belongs to the year its Thursday falls in, so January 4th is always in week 1.
     * The week's Monday is found by stepping back from there.
     */
    private static Long weekYearStart(Integer year) {
        JiffDate inFirstWeek = JiffDate.newInstance(year, 1, 4);
        return inFirstWeek.toEpochDay() - inFirstWeek.weekday().ordinal();
    }

    /**
     * Whether week year `year` has 53 weeks. That happens exactly when December 31st is a
     * Thursday, or a Friday in a leap year.
     */
    private static Boolean isLongYear(Integer year) {
        JiffWeekday lastDay = JiffDate.newInstance(year, 12, 31).weekday();
        return lastDay == JiffWeekday.THURSDAY ||
            (lastDay == JiffWeekday.FRIDAY && JiffDate.isLeapYear(year));
    }

    /**
     * Parses an ISO 8601 week date, such as `2024-W10-6`. This is the inverse of
     * `toString()`.
     *
     *     JiffIsoWeekDate.parse('2024-W10-6');  // Saturday of week 10 of 2024
     *     JiffIsoWeekDate.parse('2024W106');    // the same, in the basic format
     *
     * The `W` may be lowercase. Throws `JiffException` when the text is not a valid week date.
     *
     * Mirrors `impl FromStr for jiff::civil::ISOWeekDate`.
     */
    public static JiffIsoWeekDate parse(String text) {
        return JiffTemporal.parseIsoWeekDate(text);
    }

    // ---- accessors ------------------------------------------------------

    /**
     * The week year, in `-9999..9999`. Near the turn of the year this can differ from the
     * Gregorian year of the same day.
     */
    public Integer year() {
        return yearValue;
    }

    /** The week number, in `1..53`. Week `53` exists only in long years. */
    public Integer week() {
        return weekValue;
    }

    /** The day of the week. */
    public JiffWeekday weekday() {
        return weekdayValue;
    }

    /** The Monday of this date's week. This never fails. */
    public JiffIsoWeekDate firstOfWeek() {
        return new JiffIsoWeekDate(yearValue, weekValue, JiffWeekday.MONDAY);
    }

    /**
     * The Sunday of this date's week. Throws for the last week of year `9999`, whose Sunday
     * falls after the latest supported date.
     */
    public JiffIsoWeekDate lastOfWeek() {
        return newInstance(yearValue, weekValue, JiffWeekday.SUNDAY);
    }

    /** The Monday of week 1 of this date's week year. This never fails. */
    public JiffIsoWeekDate firstOfYear() {
        return new JiffIsoWeekDate(yearValue, 1, JiffWeekday.MONDAY);
    }

    /**
     * The Sunday of the last week of this date's week year. Throws for year `9999`, whose
     * last Sunday falls after the latest supported date.
     */
    public JiffIsoWeekDate lastOfYear() {
        return newInstance(yearValue, weeksInYear(), JiffWeekday.SUNDAY);
    }

    /** The number of days in this date's week year: `371` in a long year, otherwise `364`. */
    public Integer daysInYear() {
        return inLongYear() ? 371 : 364;
    }

    /** The number of weeks in this date's week year: `53` in a long year, otherwise `52`. */
    public Integer weeksInYear() {
        return inLongYear() ? 53 : 52;
    }

    /** Whether this date's week year is a "long" year, one with 53 weeks instead of 52. */
    public Boolean inLongYear() {
        return isLongYear(yearValue);
    }

    // ---- neighbours -----------------------------------------------------

    /** The day after this one. Throws for `MAX`. */
    public JiffIsoWeekDate tomorrow() {
        if (equals(MAX)) {
            throw JiffMath.rangeError('iso-year', MIN_YEAR, MAX_YEAR);
        }
        if (weekdayValue != JiffWeekday.SUNDAY) {
            return new JiffIsoWeekDate(yearValue, weekValue, JiffWeekdays.next(weekdayValue));
        }
        if (weekValue >= 52 && weekValue == weeksInYear()) {
            return new JiffIsoWeekDate(yearValue + 1, 1, JiffWeekday.MONDAY);
        }
        return new JiffIsoWeekDate(yearValue, weekValue + 1, JiffWeekday.MONDAY);
    }

    /** The day before this one. Throws for `MIN`. */
    public JiffIsoWeekDate yesterday() {
        if (weekdayValue != JiffWeekday.MONDAY) {
            return new JiffIsoWeekDate(yearValue, weekValue, JiffWeekdays.previous(weekdayValue));
        }
        if (weekValue > 1) {
            return new JiffIsoWeekDate(yearValue, weekValue - 1, JiffWeekday.SUNDAY);
        }
        Integer year = JiffMath.checkInt(yearValue - 1, MIN_YEAR, MAX_YEAR, 'iso-year');
        return new JiffIsoWeekDate(year, isLongYear(year) ? 53 : 52, JiffWeekday.SUNDAY);
    }

    // ---- conversion -----------------------------------------------------

    /**
     * Converts this week date to a Gregorian date. This never fails. Equivalent to
     * `JiffDate.fromIsoWeekDate(this)`.
     */
    public JiffDate toDate() {
        return JiffDate.fromEpochDay(
            weekYearStart(yearValue) + (weekValue - 1) * 7 + weekdayValue.ordinal()
        );
    }

    // ---- comparison -----------------------------------------------------

    /**
     * Orders week dates chronologically: by year, then week, then day of the week counted
     * from Monday.
     */
    public Integer compareTo(Object other) {
        JiffIsoWeekDate that = (JiffIsoWeekDate) other;
        if (yearValue != that.yearValue) {
            return yearValue < that.yearValue ? -1 : 1;
        }
        if (weekValue != that.weekValue) {
            return weekValue < that.weekValue ? -1 : 1;
        }
        Integer mine = weekdayValue.ordinal();
        Integer theirs = that.weekdayValue.ordinal();
        return mine < theirs ? -1 : (mine > theirs ? 1 : 0);
    }

    /** Whether this week date is strictly earlier than `other`. */
    public Boolean isBefore(JiffIsoWeekDate other) {
        return compareTo(other) < 0;
    }

    /** Whether this week date is strictly later than `other`. */
    public Boolean isAfter(JiffIsoWeekDate other) {
        return compareTo(other) > 0;
    }

    /** Whether `other` is a week date with the same year, week and weekday. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffIsoWeekDate)) {
            return false;
        }
        JiffIsoWeekDate that = (JiffIsoWeekDate) other;
        return yearValue == that.yearValue &&
            weekValue == that.weekValue &&
            weekdayValue == that.weekdayValue;
    }

    /** A hash consistent with `equals`, so week dates can be map keys and set members. */
    public Integer hashCode() {
        return (yearValue * 64 + weekValue) * 8 + weekdayValue.ordinal();
    }

    /**
     * Formats this week date as ISO 8601, for example `2024-W10-6`. The weekday is written as
     * a number from `1` (Monday) to `7` (Sunday), and years before zero as `-00YYYY`.
     */
    public override String toString() {
        return JiffTemporal.printIsoWeekDate(this);
    }
}
