/**
 * Readers for the vectors in `JiffSpanArithmeticVectors`, `JiffSpanTotalVectors`,
 * `JiffSpanRoundVectors` and `JiffDifferenceVectors`, on top of `JiffOracleSupport`.
 *
 * - A reference point is `-` for none, `24h` for `JiffSpanRelativeTo.daysAre24Hours()`,
 *   `D:` and a date, `T:` and a datetime, or `Z:` and a zoned datetime.
 * - A zoned datetime is its time zone's name, `@`, and its instant as `seconds,nanoseconds`.
 * - A result is the value as `JiffOracleSupport` writes it, or `ERR:` and the error message.
 * - An option that was left at its default is `-`.
 *
 * Mismatches are collected rather than failing at the first one, so that a failing test
 * reports how many rows disagree and shows the first few.
 */
@IsTest
public class JiffSpanVectorSupport {
    private static final Integer MAX_SHOWN = 5;
    private static final Map<String, JiffTimeZone> ZONES = new Map<String, JiffTimeZone>();

    private final List<String> mismatches = new List<String>();
    private Integer checked = 0;

    /** Reads a reference point; null for `-`. */
    public static JiffSpanRelativeTo relative(String text) {
        if (text.equals('-')) {
            return null;
        }
        if (text.equals('24h')) {
            return JiffSpanRelativeTo.daysAre24Hours();
        }
        String body = text.substring(2);
        if (text.startsWith('D:')) {
            return JiffSpanRelativeTo.fromDate(JiffOracleSupport.toDate(body));
        }
        if (text.startsWith('T:')) {
            return JiffSpanRelativeTo.fromDateTime(JiffOracleSupport.toDateTime(body));
        }
        Assert.isTrue(text.startsWith('Z:'), 'unknown reference point in a vector: ' + text);
        return JiffSpanRelativeTo.fromZonedDateTime(zoned(body));
    }

    /** Reads a zoned datetime written as `Zone/Name@seconds,nanoseconds`. */
    public static JiffZonedDateTime zoned(String text) {
        Integer at = text.indexOf('@');
        String zone = text.substring(0, at);
        if (!ZONES.containsKey(zone)) {
            ZONES.put(zone, JiffTimeZone.get(zone));
        }
        return JiffOracleSupport.toTimestamp(text.substring(at + 1))
            .toZonedDateTime(ZONES.get(zone));
    }

    /** Reads an optional unit; null for `-`. */
    public static JiffUnit optionalUnit(String text) {
        return text.equals('-') ? null : JiffOracleSupport.unit(text);
    }

    /** How a failure is written in a vector. */
    public static String failure(JiffException e) {
        return 'ERR:' + e.getMessage();
    }

    /** Records whether `actual` matched `expected` for `row`. */
    public void check(String expected, String actual, String what, String row) {
        checked++;
        if (!expected.equals(actual)) {
            mismatches.add(
                what + ' of ' + row + '\n    expected ' + expected + '\n    actual   ' + actual
            );
        }
    }

    /** Fails with the first few mismatches when any row disagreed. */
    public void verify(Integer expectedChecks) {
        Assert.isTrue(
            checked >= expectedChecks,
            'expected at least ' + expectedChecks + ' checks but made ' + checked
        );
        if (mismatches.isEmpty()) {
            return;
        }
        List<String> shown = new List<String>();
        for (Integer i = 0; i < mismatches.size() && i < MAX_SHOWN; i++) {
            shown.add(mismatches.get(i));
        }
        Assert.fail(
            mismatches.size() +
                ' of ' +
                checked +
                ' checks disagree with Jiff:\n' +
                String.join(shown, '\n')
        );
    }
}
