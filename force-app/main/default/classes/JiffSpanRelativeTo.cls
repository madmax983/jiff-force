/**
 * The point a span is measured from, for the span operations that need one: `add` and
 * `subtract`, `compare`, `total`, `round` and `toDuration` on `JiffSpan`.
 *
 * Years and months have no fixed length, and neither does a day in a time zone with daylight
 * saving time. A span holding such units can only be added, compared, totalled or rounded once
 * it is known where it starts:
 *
 * - `fromDate` and `fromDateTime` measure from a civil datetime (a date means its midnight).
 *   Months and years then have their calendar lengths and every day is 24 hours long.
 * - `fromZonedDateTime` measures from a zoned datetime, so a day can also be 23 or 25 hours
 *   long when it contains a change of offset.
 * - `daysAre24Hours()` gives no starting point at all, but declares that every day is 24 hours
 *   and every week seven such days. That is enough for spans of weeks and smaller units, and an
 *   error for spans that use months or years.
 *
 *     JiffSpan span = new JiffSpan().months(1);
 *     span.toDuration(JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2024, 2, 1)));   // PT696H
 *     new JiffSpan().weeks(1).total(JiffUnit.HOUR, JiffSpanRelativeTo.daysAre24Hours()); // 168.0
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::SpanRelativeTo`.
 */
public class JiffSpanRelativeTo {
    // Exactly one of the two is set, or neither for `daysAre24Hours()`.
    private final JiffDateTime civil;
    private final JiffZonedDateTime zoned;

    private static final JiffSpanRelativeTo DAYS_ARE_24_HOURS = new JiffSpanRelativeTo(null, null);

    private JiffSpanRelativeTo(JiffDateTime civil, JiffZonedDateTime zoned) {
        this.civil = civil;
        this.zoned = zoned;
    }

    /**
     * Measures spans from midnight at the start of `day`, with civil (always 24 hour) days.
     * Throws when `day` is null.
     */
    public static JiffSpanRelativeTo fromDate(JiffDate day) {
        if (day == null) {
            throw new JiffException('the date to measure a span from must not be null');
        }
        return new JiffSpanRelativeTo(day.toDateTime(JiffTime.MIN), null);
    }

    /**
     * Measures spans from a civil datetime, with civil (always 24 hour) days. Throws when
     * `civilDateTime` is null.
     */
    public static JiffSpanRelativeTo fromDateTime(JiffDateTime civilDateTime) {
        if (civilDateTime == null) {
            throw new JiffException('the datetime to measure a span from must not be null');
        }
        return new JiffSpanRelativeTo(civilDateTime, null);
    }

    /**
     * Measures spans from a zoned datetime, so that a day containing a change of offset has
     * its real length. Throws when `zoned` is null.
     */
    public static JiffSpanRelativeTo fromZonedDateTime(JiffZonedDateTime zoned) {
        if (zoned == null) {
            throw new JiffException('the zoned datetime to measure a span from must not be null');
        }
        return new JiffSpanRelativeTo(null, zoned);
    }

    /**
     * No starting point, but a promise that every day is 24 hours long and every week seven
     * days. Spans of weeks and smaller units can then be handled without a date; months and
     * years still need one.
     */
    public static JiffSpanRelativeTo daysAre24Hours() {
        return DAYS_ARE_24_HOURS;
    }

    /** Whether this is the `daysAre24Hours()` marker rather than a starting point. */
    public Boolean isDaysAre24Hours() {
        return civil == null && zoned == null;
    }

    /** The civil datetime spans are measured from, or null when this is not a civil one. */
    public JiffDateTime getDateTime() {
        return civil;
    }

    /** The zoned datetime spans are measured from, or null when this is not a zoned one. */
    public JiffZonedDateTime getZonedDateTime() {
        return zoned;
    }

    /**
     * Internal: the starting point to measure a span whose biggest unit is `unit` from, or null
     * when every unit up to `unit` has a fixed length here and the span can be treated as an
     * exact duration. Throws when `unit` is a month or year and this is `daysAre24Hours()`.
     */
    public JiffSpanRelative toRelative(JiffUnit unit) {
        if (!JiffMath.isCalendar(unit)) {
            return null;
        }
        if (civil != null) {
            return JiffSpanRelative.ofCivil(civil);
        }
        if (zoned != null) {
            return JiffSpanRelative.ofZoned(zoned);
        }
        if (unit == JiffUnit.YEAR || unit == JiffUnit.MONTH) {
            throw new JiffException(
                'using unit \'' +
                    JiffMath.singular(unit) +
                    '\' in span or configuration requires that a relative reference time be ' +
                    'given (`JiffSpanRelativeTo.daysAre24Hours()` was given but this only ' +
                    'permits using days and weeks without a relative reference time)'
            );
        }
        return null;
    }

    /**
     * Internal: throws Jiff's error for using `unit` with no reference point at all, when
     * `unit` is a day or bigger.
     */
    public static void requireRelative(JiffUnit unit) {
        if (!JiffMath.isCalendar(unit)) {
            return;
        }
        if (unit == JiffUnit.WEEK || unit == JiffUnit.DAY) {
            throw new JiffException(
                'using unit \'' +
                    JiffMath.singular(unit) +
                    '\' in a span or configuration requires that either a relative reference ' +
                    'time be given or `JiffSpanRelativeTo.daysAre24Hours()` is used to indicate ' +
                    'invariant 24-hour days, but neither were provided'
            );
        }
        throw new JiffException(
            'using unit \'' +
                JiffMath.singular(unit) +
                '\' in a span or configuration requires that a relative reference time be ' +
                'given, but none was provided'
        );
    }

    /** Equal when both are the same kind of reference with equal datetimes. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffSpanRelativeTo)) {
            return false;
        }
        JiffSpanRelativeTo that = (JiffSpanRelativeTo) other;
        if (civil != null) {
            return civil.equals(that.civil);
        }
        if (zoned != null) {
            return zoned.equals(that.zoned);
        }
        return that.isDaysAre24Hours();
    }

    /** Consistent with `equals`. */
    public Integer hashCode() {
        if (civil != null) {
            return civil.hashCode();
        }
        if (zoned != null) {
            return zoned.hashCode() * 31 + 1;
        }
        return 7;
    }

    /**
     * The datetime spans are measured from, as `toString()` prints it, or `days are 24 hours`
     * for the marker.
     */
    public override String toString() {
        if (civil != null) {
            return civil.toString();
        }
        if (zoned != null) {
            return zoned.toString();
        }
        return 'days are 24 hours';
    }
}
