/**
 * The "friendly" duration format: an easy to read and write alternative to ISO 8601 durations
 * for `JiffSpan` and `JiffSignedDuration`.
 *
 *     2h 30m
 *     1 year, 2 months
 *     3d 4h 59m ago
 *     -2h30m
 *     5 days, 01:30:00
 *
 * Most code does not need this class. `JiffSpan.parse` and `JiffSignedDuration.parse` accept
 * the friendly format as well as ISO 8601, and `toFriendly()` on either type prints it:
 *
 *     JiffSpan span = JiffSpan.parse('2 months, 35 days, 02:30:00');
 *     span.toString();     // P2M35DT2H30M
 *     span.toFriendly();   // 2mo 35d 2h 30m
 *
 * Use the methods here to accept *only* the friendly format, or to print with settings other
 * than the defaults (see `JiffFriendlyPrinter`).
 *
 * ## Why another format
 *
 * ISO 8601 durations such as `P1Y2M3DT4H59M1.1S` are hard to read, and they can only express
 * time below a second as a fraction of a second. A span of `1 second 100 milliseconds` and a
 * span of `1100 milliseconds` are both `PT1.1S`, so a span does not survive being written as
 * ISO 8601 and read back. The friendly format writes every unit on its own
 * (`1s 100ms` and `1100ms`), so it does.
 *
 * ## Spans and signed durations
 *
 * A signed duration only accepts hours and smaller units, because a day, a month or a year has
 * no fixed length. Parse into a span when the text may contain those.
 *
 * See `JiffFriendlyParser` for the grammar and the full list of unit labels.
 *
 * Mirrors `jiff::fmt::friendly`.
 */
public class JiffFriendly {
    private static final JiffFriendlyPrinter DEFAULT_PRINTER = new JiffFriendlyPrinter();
    private static final String NEITHER_FORMAT =
        'not a valid duration in either ' + 'the ISO 8601 format or Jiff\'s "friendly" format';

    /**
     * Parses a friendly duration into a span. Each unit is kept as written. Throws
     * `JiffException` when the text is not in the friendly format.
     */
    public static JiffSpan parseSpan(String text) {
        return JiffFriendlyParser.parseSpan(text);
    }

    /**
     * Parses a friendly duration into a signed duration. Throws `JiffException` when the text
     * is not in the friendly format or uses a unit of days or larger.
     */
    public static JiffSignedDuration parseDuration(String text) {
        return JiffFriendlyParser.parseDuration(text);
    }

    /** Formats a span with the default settings, for example `1y 2mo 15h` or `3d ago`. */
    public static String printSpan(JiffSpan span) {
        return DEFAULT_PRINTER.spanToString(span);
    }

    /** Formats a span with the settings of `printer`. */
    public static String printSpan(JiffSpan span, JiffFriendlyPrinter printer) {
        return printer.spanToString(span);
    }

    /**
     * Formats a signed duration with the default settings, for example `2h 30m` or
     * `1s 500ms ago`. The largest unit used is hours.
     */
    public static String printDuration(JiffSignedDuration duration) {
        return DEFAULT_PRINTER.durationToString(duration);
    }

    /** Formats a signed duration with the settings of `printer`. */
    public static String printDuration(JiffSignedDuration duration, JiffFriendlyPrinter printer) {
        return printer.durationToString(duration);
    }

    /**
     * Parses a span written in either the ISO 8601 duration format or the friendly format.
     * This is what `JiffSpan.parse` does.
     *
     * The two formats cannot be confused: after an optional sign, an ISO 8601 duration always
     * starts with `P` or `p` and a friendly duration always starts with a digit.
     */
    public static JiffSpan parseIsoOrFriendlySpan(String text) {
        return startsLikeIso(text) ? JiffTemporal.parseSpan(text) : parseSpan(text);
    }

    /**
     * Parses a signed duration written in either the ISO 8601 duration format or the friendly
     * format. This is what `JiffSignedDuration.parse` does.
     */
    public static JiffSignedDuration parseIsoOrFriendlyDuration(String text) {
        return startsLikeIso(text) ? JiffTemporal.parseDuration(text) : parseDuration(text);
    }

    /** Whether `text` has to be ISO 8601 if it is a duration at all. */
    private static Boolean startsLikeIso(String text) {
        if (text == null) {
            throw new JiffException('cannot parse a duration from a null string');
        }
        if (text.length() == 0) {
            throw new JiffException('an empty string is ' + NEITHER_FORMAT);
        }
        Integer first = text.charAt(0);
        if (first == 43 || first == 45) {
            if (text.length() == 1) {
                throw new JiffException(
                    'found nothing after sign `' + text + '`, which is ' + NEITHER_FORMAT
                );
            }
            first = text.charAt(1);
        }
        return first == 80 || first == 112;
    }
}
