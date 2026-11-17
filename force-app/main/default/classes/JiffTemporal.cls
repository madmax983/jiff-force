/**
 * Printing and parsing in the Temporal ISO 8601 / RFC 3339 / RFC 9557 family of formats.
 *
 * This is the format every jiff-force type uses for `toString()` and `parse(String)`. The
 * methods here are the shared implementation behind those; most code should call the methods
 * on the types themselves.
 *
 * Mirrors `jiff::fmt::temporal`.
 */
public class JiffTemporal {
    /** Formats a date as `YYYY-MM-DD`. Years before zero are written as `-00YYYY`. */
    public static String printDate(JiffDate value) {
        Integer year = value.year();
        return (year < 0 ? '-00' + JiffMath.pad(-year, 4) : JiffMath.pad(year, 4)) +
            '-' +
            JiffMath.pad(value.month(), 2) +
            '-' +
            JiffMath.pad(value.day(), 2);
    }

    /** Formats a time as `HH:MM:SS`, followed by a fraction only when it is non-zero. */
    public static String printTime(JiffTime value) {
        String out =
            JiffMath.pad(value.hour(), 2) +
            ':' +
            JiffMath.pad(value.minute(), 2) +
            ':' +
            JiffMath.pad(value.second(), 2);
        Integer nanos = value.subsecNanosecond();
        return nanos == 0 ? out : out + '.' + fraction(nanos);
    }

    /** Formats a datetime as a date and a time separated by `T`. */
    public static String printDateTime(JiffDateTime value) {
        return printDate(value.toDate()) + 'T' + printTime(value.toTime());
    }

    /**
     * Formats a duration as an ISO 8601 duration with hours as the largest unit, for example
     * `PT2H30M`, `-PT1.5S` or `PT0S`.
     */
    public static String printDuration(JiffSignedDuration duration) {
        // Work on the components separately and negate each one, so that the most negative
        // duration (whose seconds have no positive counterpart) still prints.
        Long secs = duration.asSecs();
        Integer nanos = duration.subsecNanos();
        String out = duration.isNegative() ? '-PT' : 'PT';
        Boolean atLeastAMinute = secs >= 60 || secs <= -60;
        Long seconds = JiffMath.abs(JiffMath.truncMod(secs, 60L));
        if (atLeastAMinute) {
            Long hours = secs / 3600L;
            Long minutes = JiffMath.abs(JiffMath.truncMod(secs, 3600L) / 60L);
            if (hours != 0) {
                // Negate after dividing: the quotient always has a positive counterpart.
                out += (hours < 0 ? -hours : hours) + 'H';
            }
            if (minutes != 0) {
                out += minutes + 'M';
            }
        }
        if (!atLeastAMinute || seconds != 0 || nanos != 0) {
            out += String.valueOf(seconds);
            if (nanos != 0) {
                out += '.' + fraction(nanos < 0 ? -nanos : nanos);
            }
            out += 'S';
        }
        return out;
    }

    /**
     * Formats a span as an ISO 8601 duration, for example `P1Y2M3DT4H5M6.5S`, `-P1W` or `PT0S`.
     *
     * Units that are zero are omitted. Milliseconds, microseconds and nanoseconds have no
     * designator in ISO 8601, so they are folded into a fractional number of seconds.
     */
    public static String printSpan(JiffSpan span) {
        String out = span.isNegative() ? '-P' : 'P';
        if (span.hasUnit(JiffUnit.YEAR)) {
            out += span.getAbs(JiffUnit.YEAR) + 'Y';
        }
        if (span.hasUnit(JiffUnit.MONTH)) {
            out += span.getAbs(JiffUnit.MONTH) + 'M';
        }
        if (span.hasUnit(JiffUnit.WEEK)) {
            out += span.getAbs(JiffUnit.WEEK) + 'W';
        }
        if (span.hasUnit(JiffUnit.DAY)) {
            out += span.getAbs(JiffUnit.DAY) + 'D';
        }
        if (!span.hasTimeUnits()) {
            return span.hasCalendarUnits() ? out : out + 'T0S';
        }
        out += 'T';
        if (span.hasUnit(JiffUnit.HOUR)) {
            out += span.getAbs(JiffUnit.HOUR) + 'H';
        }
        if (span.hasUnit(JiffUnit.MINUTE)) {
            out += span.getAbs(JiffUnit.MINUTE) + 'M';
        }
        if (span.hasFractionalSeconds()) {
            Long millis = span.getAbs(JiffUnit.MILLISECOND);
            Long micros = span.getAbs(JiffUnit.MICROSECOND);
            Long nanos = span.getAbs(JiffUnit.NANOSECOND);
            Long subsec =
                JiffMath.truncMod(millis, 1000L) * 1000000L +
                JiffMath.truncMod(micros, 1000000L) * 1000L +
                JiffMath.truncMod(nanos, 1000000000L);
            Long secs =
                span.getAbs(JiffUnit.SECOND) +
                millis / 1000L +
                micros / 1000000L +
                nanos / 1000000000L +
                subsec / 1000000000L;
            subsec = JiffMath.truncMod(subsec, 1000000000L);
            out += String.valueOf(secs);
            if (subsec != 0) {
                out += '.' + fraction(subsec.intValue());
            }
            out += 'S';
        } else if (span.hasUnit(JiffUnit.SECOND)) {
            out += span.getAbs(JiffUnit.SECOND) + 'S';
        }
        return out;
    }

    /** Nine fractional digits with trailing zeros removed. `nanos` must be in `1..999999999`. */
    public static String fraction(Integer nanos) {
        String digits = String.valueOf(nanos).leftPad(9, '0');
        Integer endIndex = digits.length();
        while (endIndex > 1 && digits.charAt(endIndex - 1) == 48) {
            endIndex--;
        }
        return digits.substring(0, endIndex);
    }
}
