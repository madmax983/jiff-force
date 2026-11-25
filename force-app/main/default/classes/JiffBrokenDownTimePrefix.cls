/**
 * The result of `JiffBrokenDownTime.parsePrefix`: the broken down time parsed from the start
 * of the input, and how much of the input that took.
 *
 *     String input = '2024-01-20T17:55Z';
 *     JiffBrokenDownTimePrefix p = JiffBrokenDownTime.parsePrefix('%Y-%m-%d', input);
 *     p.value().toDate();                  // 2024-01-20
 *     input.substring(p.consumed());       // T17:55Z
 *
 * Jiff returns a tuple of the two, and counts the consumed part in bytes of UTF-8. The port
 * counts UTF-16 code units, the unit of Apex string positions, so `consumed()` can be passed
 * straight to `String.substring`. The two agree for ASCII input.
 *
 * Mirrors the `(BrokenDownTime, usize)` returned by
 * `jiff::fmt::strtime::BrokenDownTime::parse_prefix`.
 */
public class JiffBrokenDownTimePrefix {
    private final JiffBrokenDownTime parsed;
    private final Integer consumedLength;

    /** A parsed broken down time and the number of code units of input it came from. */
    public JiffBrokenDownTimePrefix(JiffBrokenDownTime value, Integer consumed) {
        if (value == null || consumed == null) {
            throw new JiffException('a parsed prefix needs a value and a length');
        }
        this.parsed = value;
        this.consumedLength = consumed;
    }

    /** The broken down time parsed from the prefix. */
    public JiffBrokenDownTime value() {
        return parsed;
    }

    /** The length of the prefix that was parsed, in UTF-16 code units. */
    public Integer consumed() {
        return consumedLength;
    }
}
