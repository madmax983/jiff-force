/**
 * A builder that makes a new `JiffDate` by replacing some of the fields of an existing one.
 *
 * Start it with `JiffDate.with()`, name the fields to change, and finish with `build()`. Any
 * field you do not set keeps the value it has in the original date.
 *
 *     JiffDate d1 = JiffDate.newInstance(2024, 10, 31);
 *     JiffDate d2 = d1.with().month(11).day(30).build();   // 2024-11-30
 *
 * Nothing is validated until `build()`, so fields can be set in any order. Changing the month
 * of `2024-10-31` to November on its own would be invalid (there is no November 31st), but it
 * is fine as an intermediate step on the way to `2024-11-30`.
 *
 * Fields that describe the same thing override each other, and the last one set wins:
 *
 * - `year` and `eraYear` both set the year.
 * - `day`, `dayOfYear` and `dayOfYearNoLeap` all set the day. The two day-of-year forms also
 *   determine the month, so the resulting month comes from them and not from `month` or the
 *   original date.
 *
 * Builders are immutable; each setter returns a new builder.
 *
 * Mirrors `jiff::civil::DateWith`.
 */
public class JiffDateWith {
    private static final Integer UNSET = 0;
    private static final Integer YEAR_PLAIN = 1;
    private static final Integer YEAR_OF_ERA = 2;
    private static final Integer DAY_OF_MONTH = 1;
    private static final Integer DAY_OF_YEAR = 2;
    private static final Integer DAY_OF_YEAR_NO_LEAP = 3;

    private final JiffDate original;
    // Which year setter was used last (UNSET, YEAR_PLAIN or YEAR_OF_ERA) and what it was given.
    private final Integer yearKind;
    private final Integer yearValue;
    private final JiffEra eraValue;
    private final Boolean monthSet;
    private final Integer monthValue;
    // Which day setter was used last (UNSET or one of the DAY_* kinds) and what it was given.
    private final Integer dayKind;
    private final Integer dayValue;

    /**
     * Creates a builder whose fields all come from `original`. `JiffDate.with()` is the usual
     * way to get one.
     */
    public JiffDateWith(JiffDate original) {
        this(original, UNSET, 0, null, false, 0, UNSET, 0);
    }

    private JiffDateWith(
        JiffDate original,
        Integer yearKind,
        Integer yearValue,
        JiffEra eraValue,
        Boolean monthSet,
        Integer monthValue,
        Integer dayKind,
        Integer dayValue
    ) {
        if (original == null) {
            throw new JiffException('the date to build from must not be null');
        }
        this.original = original;
        this.yearKind = yearKind;
        this.yearValue = yearValue;
        this.eraValue = eraValue;
        this.monthSet = monthSet;
        this.monthValue = monthValue;
        this.dayKind = dayKind;
        this.dayValue = dayValue;
    }

    /**
     * Sets the year, in `-9999..9999`. Overrides any earlier `year` or `eraYear`.
     *
     * `build()` throws if the year is out of range, or if the date does not exist in that
     * year: `2024-02-29` cannot simply move to 2023.
     */
    public JiffDateWith year(Integer year) {
        return new JiffDateWith(
            original,
            YEAR_PLAIN,
            year,
            null,
            monthSet,
            monthValue,
            dayKind,
            dayValue
        );
    }

    /**
     * Sets the year by its era and its number within that era. Overrides any earlier `year`
     * or `eraYear`.
     *
     * `CE` years are the same as plain years and must be in `1..9999`. `BCE` years count
     * backwards from year zero and must be in `1..10000`: `1 BCE` is year `0` and `509 BCE` is
     * year `-508`. `build()` throws if the year is outside the range for its era.
     */
    public JiffDateWith eraYear(Integer year, JiffEra era) {
        if (era == null) {
            throw new JiffException('era must not be null');
        }
        return new JiffDateWith(
            original,
            YEAR_OF_ERA,
            year,
            era,
            monthSet,
            monthValue,
            dayKind,
            dayValue
        );
    }

    /**
     * Sets the month, in `1..12`. Overrides any earlier `month`.
     *
     * `build()` throws if the month is out of range, or if the day does not exist in that
     * month: `2024-10-31` cannot simply move to November.
     */
    public JiffDateWith month(Integer month) {
        return new JiffDateWith(
            original,
            yearKind,
            yearValue,
            eraValue,
            true,
            month,
            dayKind,
            dayValue
        );
    }

    /**
     * Sets the day of the month. Overrides any earlier `day`, `dayOfYear` or
     * `dayOfYearNoLeap`.
     *
     * `build()` throws if the resulting year and month have no such day.
     */
    public JiffDateWith day(Integer day) {
        return withDay(DAY_OF_MONTH, day);
    }

    /**
     * Sets the day by its position in the year, where `1` is January 1st. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..366`. In a leap year day `60` is February 29th; in any other year
     * it is March 1st. `build()` throws if the value is out of range, or if it is `366` and
     * the year is not a leap year.
     */
    public JiffDateWith dayOfYear(Integer day) {
        return withDay(DAY_OF_YEAR, day);
    }

    /**
     * Sets the day by its position in the year as if leap days did not exist. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..365`. Day `60` is always March 1st and day `365` is always
     * December 31st, in leap years too; February 29th can never be produced. `build()` throws
     * if the value is out of range.
     */
    public JiffDateWith dayOfYearNoLeap(Integer day) {
        return withDay(DAY_OF_YEAR_NO_LEAP, day);
    }

    private JiffDateWith withDay(Integer kind, Integer day) {
        return new JiffDateWith(
            original,
            yearKind,
            yearValue,
            eraValue,
            monthSet,
            monthValue,
            kind,
            day
        );
    }

    /**
     * Creates the date described by this builder: the original date with every field that was
     * set replaced. With nothing set, this returns a date equal to the original.
     *
     * Throws if a field is out of range or the fields do not combine into a real date.
     */
    public JiffDate build() {
        Integer year = buildYear();
        Integer month = monthSet
            ? JiffMath.checkInt(monthValue, 1L, 12L, 'month')
            : original.month();
        if (dayKind == DAY_OF_YEAR) {
            return JiffDate.fromDayOfYear(year, dayValue);
        }
        if (dayKind == DAY_OF_YEAR_NO_LEAP) {
            return JiffDate.fromDayOfYearNoLeap(year, dayValue);
        }
        Integer day = dayKind == DAY_OF_MONTH
            ? JiffMath.checkInt(dayValue, 1L, 31L, 'day')
            : original.day();
        return JiffDate.newInstance(year, month, day);
    }

    private Integer buildYear() {
        if (yearKind == UNSET) {
            return original.year();
        }
        if (yearKind == YEAR_PLAIN) {
            return JiffMath.checkInt(yearValue, -9999L, 9999L, 'year');
        }
        if (eraValue == JiffEra.CE) {
            return JiffMath.checkInt(yearValue, 1L, 9999L, 'CE year');
        }
        return 1 - JiffMath.checkInt(yearValue, 1L, 10000L, 'BCE year');
    }
}
