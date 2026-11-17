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
 * Mirrors `jiff::civil::DateTime`.
 */
public class JiffDateTime implements Comparable {
    /** The earliest supported datetime, `-9999-01-01T00:00:00`. */
    public static final JiffDateTime MIN = new JiffDateTime(JiffDate.MIN, JiffTime.MIN);
    /** The latest supported datetime, `9999-12-31T23:59:59.999999999`. */
    public static final JiffDateTime MAX = new JiffDateTime(JiffDate.MAX, JiffTime.MAX);

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

    /** Combines a date and a time. */
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

    // ---- accessors ------------------------------------------------------

    /** The date part of this datetime. */
    public JiffDate toDate() {
        return dateValue;
    }

    /** The time of day part of this datetime. */
    public JiffTime toTime() {
        return timeValue;
    }

    public Integer year() {
        return dateValue.year();
    }

    public Integer month() {
        return dateValue.month();
    }

    public Integer day() {
        return dateValue.day();
    }

    public Integer hour() {
        return timeValue.hour();
    }

    public Integer minute() {
        return timeValue.minute();
    }

    public Integer second() {
        return timeValue.second();
    }

    public Integer millisecond() {
        return timeValue.millisecond();
    }

    public Integer microsecond() {
        return timeValue.microsecond();
    }

    public Integer nanosecond() {
        return timeValue.nanosecond();
    }

    public Integer subsecNanosecond() {
        return timeValue.subsecNanosecond();
    }

    /** The day of the week this datetime falls on. */
    public JiffWeekday weekday() {
        return dateValue.weekday();
    }

    /**
     * Whole seconds between `1970-01-01T00:00:00` and this datetime, counting every day as
     * exactly 86,400 seconds and rounding toward negative infinity. The inverse of
     * `fromEpochSecond`; the fractional second is `subsecNanosecond()`.
     */
    public Long toEpochSecond() {
        return dateValue.toEpochDay() * JiffMath.SECS_PER_CIVIL_DAY + timeValue.toSecondOfDay();
    }

    // ---- comparison -----------------------------------------------------

    public Integer compareTo(Object other) {
        JiffDateTime that = (JiffDateTime) other;
        Integer byDate = dateValue.compareTo(that.dateValue);
        return byDate != 0 ? byDate : timeValue.compareTo(that.timeValue);
    }

    public Boolean isBefore(JiffDateTime other) {
        return compareTo(other) < 0;
    }

    public Boolean isAfter(JiffDateTime other) {
        return compareTo(other) > 0;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffDateTime)) {
            return false;
        }
        JiffDateTime that = (JiffDateTime) other;
        return dateValue.equals(that.dateValue) && timeValue.equals(that.timeValue);
    }

    public Integer hashCode() {
        return dateValue.hashCode() * 31 + timeValue.hashCode();
    }

    /** Formats this datetime as ISO 8601, for example `2024-02-29T15:22:45.5`. */
    public override String toString() {
        return JiffTemporal.printDateTime(this);
    }
}
