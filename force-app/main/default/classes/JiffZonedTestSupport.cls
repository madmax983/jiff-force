/**
 * Shared fixtures for the zoned datetime tests.
 *
 * The expected values in those tests are RFC 9557 strings printed by the real Jiff, and their
 * inputs are easiest to state the same way. `JiffZonedDateTime.parse` does not exist yet, so
 * `zoned` reads the one shape Jiff prints, `2024-11-03T01:30:00-05:00[America/New_York]`, and
 * builds the zoned datetime from its parts. It then checks that the result prints as the same
 * text, which fails loudly if the platform's time zone data disagrees with the fixture.
 */
@IsTest
public class JiffZonedTestSupport {
    /**
     * Builds the zoned datetime that Jiff prints as `text`. The year must have four digits and
     * the offset whole minutes.
     */
    public static JiffZonedDateTime zoned(String text) {
        Integer open = text.indexOf('[');
        String head = text.substring(0, open);
        String zoneName = text.substring(open + 1, text.length() - 1);
        JiffDateTime wallClock = civil(head.substring(0, head.length() - 6));
        JiffOffset fromUtc = offset(head.substring(head.length() - 6));
        JiffZonedDateTime result = fromUtc.toTimestamp(wallClock).toZonedDateTime(zone(zoneName));
        Assert.areEqual(text, result.toString(), 'the fixture is not a valid zoned datetime');
        return result;
    }

    /** Reads a civil datetime such as `2024-11-03T01:30:00` or `2024-11-03T01:30:00.5`. */
    public static JiffDateTime civil(String text) {
        Integer nanos = 0;
        if (text.length() > 20) {
            nanos = Integer.valueOf(text.substring(20).rightPad(9, '0'));
        }
        return JiffDateTime.newInstance(
            Integer.valueOf(text.substring(0, 4)),
            Integer.valueOf(text.substring(5, 7)),
            Integer.valueOf(text.substring(8, 10)),
            Integer.valueOf(text.substring(11, 13)),
            Integer.valueOf(text.substring(14, 16)),
            Integer.valueOf(text.substring(17, 19)),
            nanos
        );
    }

    /** Reads an offset such as `-05:00` or `+05:30`. */
    public static JiffOffset offset(String text) {
        Integer seconds =
            Integer.valueOf(text.substring(1, 3)) * 3600 +
            Integer.valueOf(text.substring(4, 6)) * 60;
        return JiffOffset.fromSeconds(text.startsWith('-') ? -seconds : seconds);
    }

    /** A time zone by IANA name, or a fixed offset zone for a name such as `-05:30`. */
    public static JiffTimeZone zone(String name) {
        if (name.startsWith('+') || name.startsWith('-')) {
            return JiffTimeZone.fixed(offset(name));
        }
        return JiffTimeZone.get(name);
    }

    /** The rounding mode with the given Jiff name, such as `HalfExpand`. */
    public static JiffRoundMode mode(String name) {
        for (JiffRoundMode candidate : JiffRoundMode.values()) {
            if (candidate.name().replace('_', '').equalsIgnoreCase(name)) {
                return candidate;
            }
        }
        throw new JiffException('unknown rounding mode ' + name);
    }

    /** The unit with the given Jiff name, such as `Hour`. */
    public static JiffUnit unit(String name) {
        for (JiffUnit candidate : JiffUnit.values()) {
            if (candidate.name().equalsIgnoreCase(name)) {
                return candidate;
            }
        }
        throw new JiffException('unknown unit ' + name);
    }
}
