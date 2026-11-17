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
 * Mirrors `jiff::civil::Date`.
 */
public class JiffDate implements Comparable {
    private static final Long MIN_EPOCH_DAY = -4371587L;
    private static final Long MAX_EPOCH_DAY = 2932896L;
    private static final List<JiffWeekday> WEEKDAYS = JiffWeekday.values();

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
        JiffMath.check(year, -9999L, 9999L, 'year');
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

    // ---- comparison -----------------------------------------------------

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

    public Boolean isBefore(JiffDate other) {
        return compareTo(other) < 0;
    }

    public Boolean isAfter(JiffDate other) {
        return compareTo(other) > 0;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffDate)) {
            return false;
        }
        JiffDate that = (JiffDate) other;
        return yearValue == that.yearValue &&
            monthValue == that.monthValue &&
            dayValue == that.dayValue;
    }

    public Integer hashCode() {
        return (yearValue * 13 + monthValue) * 32 + dayValue;
    }

    /** Formats this date as ISO 8601, for example `2024-02-29`. */
    public override String toString() {
        return JiffTemporal.printDate(this);
    }
}
