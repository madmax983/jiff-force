/**
 * A moment at which a time zone's UTC offset changes, together with what is in effect from
 * that moment on.
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     JiffTimestamp start = JiffTimestamp.fromSecond(1709960400L); // 2024-03-09T05:00:00Z
 *     JiffTimeZoneTransition next = tz.nextTransition(start);
 *     next.toTimestamp();   // 2024-03-10T07:00:00Z, which is 03:00 local time
 *     next.offset();        // -04
 *     next.abbreviation();  // EDT
 *     next.dst();           // JiffDst.YES
 *
 * `JiffTimeZone.previousTransition` and `JiffTimeZone.nextTransition` return these; that class
 * documents how transitions are found on the platform and what cannot be detected.
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::tz::TimeZoneTransition`.
 */
public class JiffTimeZoneTransition {
    private final JiffTimestamp timestampValue;
    private final JiffTimeZoneOffsetInfo info;

    /** Internal: `JiffTimeZone` creates these. */
    public JiffTimeZoneTransition(JiffTimestamp timestampValue, JiffTimeZoneOffsetInfo info) {
        this.timestampValue = timestampValue;
        this.info = info;
    }

    /** The first instant at which the new offset applies. */
    public JiffTimestamp toTimestamp() {
        return timestampValue;
    }

    /** The UTC offset in effect from the transition onward. */
    public JiffOffset offset() {
        return info.offset();
    }

    /** The time zone's abbreviation from the transition onward, such as `EDT`. */
    public String abbreviation() {
        return info.abbreviation();
    }

    /** Whether daylight saving time is in effect from the transition onward. */
    public JiffDst dst() {
        return info.dst();
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffTimeZoneTransition)) {
            return false;
        }
        JiffTimeZoneTransition that = (JiffTimeZoneTransition) other;
        return timestampValue.equals(that.timestampValue) && info.equals(that.info);
    }

    public Integer hashCode() {
        Long hash = timestampValue.hashCode() * 31L + info.hashCode();
        return JiffMath.floorMod(hash, 1000000007L).intValue();
    }

    /** For example `2024-03-10T07:00:00Z -04 EDT (DST)`. */
    public override String toString() {
        return timestampValue.toString() + ' ' + info.toString();
    }
}
