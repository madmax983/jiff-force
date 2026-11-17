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
 * Mirrors `jiff::civil::Time`.
 */
public class JiffTime implements Comparable {
    /** The first moment of the day, `00:00:00`. */
    public static final JiffTime MIN = new JiffTime(0, 0, 0, 0);
    /** The last representable moment of the day, `23:59:59.999999999`. */
    public static final JiffTime MAX = new JiffTime(23, 59, 59, 999999999);

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
}
