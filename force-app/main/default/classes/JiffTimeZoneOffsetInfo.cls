/**
 * What a time zone says about one instant: the UTC offset in effect, the zone's abbreviation
 * at that moment, and whether daylight saving time applies.
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     JiffTimeZoneOffsetInfo info = tz.toOffsetInfo(JiffTimestamp.fromSecond(1720493204L));
 *     info.offset();        // -04
 *     info.abbreviation();  // EDT
 *     info.dst();           // JiffDst.YES
 *
 * For a zone backed by the platform, the abbreviation is whatever the platform's locale data
 * calls the zone at that instant and the daylight saving flag is inferred. `JiffTimeZone`
 * documents both, including where they can differ from the time zone database.
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::tz::TimeZoneOffsetInfo`.
 */
public class JiffTimeZoneOffsetInfo {
    private final JiffOffset offsetValue;
    private final String abbreviationValue;
    private final JiffDst dstValue;

    /** Internal: `JiffTimeZone.toOffsetInfo` is the way to get one of these. */
    public JiffTimeZoneOffsetInfo(
        JiffOffset offsetValue,
        String abbreviationValue,
        JiffDst dstValue
    ) {
        this.offsetValue = offsetValue;
        this.abbreviationValue = abbreviationValue;
        this.dstValue = dstValue;
    }

    /** The UTC offset in effect at the instant. */
    public JiffOffset offset() {
        return offsetValue;
    }

    /**
     * The time zone's abbreviation at the instant, such as `EST` or `EDT`. Abbreviations are
     * not unique and should only be shown to people, never parsed back.
     */
    public String abbreviation() {
        return abbreviationValue;
    }

    /** Whether daylight saving time is in effect at the instant. */
    public JiffDst dst() {
        return dstValue;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffTimeZoneOffsetInfo)) {
            return false;
        }
        JiffTimeZoneOffsetInfo that = (JiffTimeZoneOffsetInfo) other;
        return offsetValue.equals(that.offsetValue) &&
            abbreviationValue.equals(that.abbreviationValue) &&
            dstValue == that.dstValue;
    }

    public Integer hashCode() {
        Long hash = offsetValue.hashCode() * 31L + dstValue.ordinal();
        Long text = JiffMath.floorMod(abbreviationValue.hashCode(), 1000000007L);
        return JiffMath.floorMod(hash * 31 + text, 1000000007L).intValue();
    }

    /** For example `-04 EDT (DST)` or `-05 EST`. */
    public override String toString() {
        return offsetValue.toString() +
            ' ' +
            abbreviationValue +
            (dstValue == JiffDst.YES ? ' (DST)' : '');
    }
}
