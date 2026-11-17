/**
 * The parser for the "friendly" duration format. Most code should call `JiffSpan.parse`,
 * `JiffSignedDuration.parse` or the methods on `JiffFriendly` rather than this class.
 *
 * A friendly duration is a list of unit values written from largest to smallest, each followed
 * by a unit label:
 *
 *     2h 30m
 *     1 year, 2 months, 3 days
 *     3d 4h 59m ago
 *     -1.5 hours
 *     5 days, 01:02:03.5
 *
 * - Whitespace may separate a value from its label and one unit from the next. A comma may
 *   follow a label, and must itself be followed by whitespace and another unit.
 * - A sign is written either as a leading `+` or `-`, or as a trailing ` ago`, never both.
 * - The last unit may have a fraction of up to nine digits, after `.` or `,`, provided it is
 *   hours or smaller and not nanoseconds. The fraction is carried into the smaller units.
 * - `HH:MM:SS`, optionally with a fraction, may stand in for the hours, minutes and seconds.
 *   It can only follow years, months, weeks or days.
 *
 * The accepted labels are:
 *
 * | Unit | Labels |
 * | --- | --- |
 * | years | `years` `year` `yrs` `yr` `y` |
 * | months | `months` `month` `mos` `mo` |
 * | weeks | `weeks` `week` `wks` `wk` `w` |
 * | days | `days` `day` `d` |
 * | hours | `hours` `hour` `hrs` `hr` `h` |
 * | minutes | `minutes` `minute` `mins` `min` `m` |
 * | seconds | `seconds` `second` `secs` `sec` `s` |
 * | milliseconds | `milliseconds` `millisecond` `millis` `milli` `msecs` `msec` `ms` |
 * | microseconds | `microseconds` `microsecond` `micros` `micro` `usecs` `usec` `us` |
 * | nanoseconds | `nanoseconds` `nanosecond` `nanos` `nano` `nsecs` `nsec` `ns` |
 *
 * Microseconds may also be written with U+00B5 MICRO SIGN in place of the `u`: the micro sign
 * followed by `secs`, `sec` or `s`.
 *
 * Labels are case sensitive, and `M` is deliberately not a label because it could mean months
 * or minutes.
 *
 * Mirrors `jiff::fmt::friendly::SpanParser`.
 */
public class JiffFriendlyParser {
    private static final String CONTEXT = 'failed to parse input in the "friendly" duration format: ';
    // U+00B5 MICRO SIGN, which may stand in for the `u` of `us`, `usec` and `usecs`.
    private static final String MICRO = String.fromCharArray(new List<Integer>{ 181 });
    private static final Integer MAX_LABEL_LENGTH = 12;
    private static final Map<String, JiffUnit> LABELS = labels();

    /**
     * Parses a friendly duration into a span, keeping each unit as written: `90m` is ninety
     * minutes, not an hour and a half. Throws `JiffException` when the text is not a friendly
     * duration or a unit is beyond what a span holds.
     */
    public static JiffSpan parseSpan(String text) {
        try {
            JiffDurationScanner scanner = new JiffDurationScanner(text);
            JiffSpan span = parseUnits(scanner).toSpan();
            scanner.finish(span.toString());
            return span;
        } catch (JiffException e) {
            throw new JiffException(CONTEXT + e.getMessage(), e);
        }
    }

    /**
     * Parses a friendly duration into a signed duration. Only hours and smaller units are
     * accepted, because a day or a month has no fixed length; parse into a span for those.
     */
    public static JiffSignedDuration parseDuration(String text) {
        try {
            JiffDurationScanner scanner = new JiffDurationScanner(text);
            JiffSignedDuration duration = parseUnits(scanner).toSignedDuration();
            scanner.finish(duration.toString());
            return duration;
        } catch (JiffException e) {
            throw new JiffException(CONTEXT + e.getMessage(), e);
        }
    }

    /** Parses the sign and every unit, leaving the scanner after the last thing it accepted. */
    private static JiffDurationUnits parseUnits(JiffDurationScanner scanner) {
        if (scanner.isDone()) {
            throw new JiffException('an empty string is not valid');
        }
        Integer prefixSign = 0;
        if (scanner.eat(43)) {
            prefixSign = 1;
        } else if (scanner.eat(45)) {
            prefixSign = -1;
        }
        JiffI128 first = scanner.unitValue();
        if (first == null) {
            throw new JiffException(
                'expected duration to start with a unit value (a decimal integer) ' +
                'after an optional sign, but no integer was found'
            );
        }
        JiffDurationUnits units = new JiffDurationUnits();
        parseDurationUnits(scanner, first, units);
        units.setSign(parseSuffixSign(scanner, prefixSign));
        return units;
    }

    private static void parseDurationUnits(
        JiffDurationScanner scanner,
        JiffI128 first,
        JiffDurationUnits units
    ) {
        Boolean parsedAnyAfterComma = true;
        JiffI128 value = first;
        while (true) {
            if (scanner.eat(58)) {
                parseHms(scanner, value, units);
                break;
            }
            Integer fraction = scanner.fraction();
            // Whitespace is allowed between the value and its label.
            scanner.skipWhitespace();
            JiffUnit unit = parseUnitDesignator(scanner);
            // A comma may immediately follow the label.
            if (scanner.eat(44)) {
                requireWhitespaceAfterComma(scanner);
                parsedAnyAfterComma = false;
            }
            units.setUnitValue(unit, value);
            if (fraction >= 0) {
                // A fraction is only allowed on the last unit.
                units.setFraction(fraction);
                break;
            }
            // Whitespace before the next value is skipped, but only when a value follows:
            // otherwise it may be the space before a trailing `ago`.
            Integer mark = scanner.position();
            scanner.skipWhitespace();
            value = scanner.unitValue();
            if (value == null) {
                scanner.rewind(mark);
                break;
            }
            parsedAnyAfterComma = true;
        }
        if (!parsedAnyAfterComma) {
            throw new JiffException(
                'found comma at the end of duration, ' +
                'but a comma indicates at least one more unit follows'
            );
        }
    }

    /** Parses `MM:SS[.fraction]`; the hours and the colon after them are already consumed. */
    private static void parseHms(
        JiffDurationScanner scanner,
        JiffI128 hours,
        JiffDurationUnits units
    ) {
        JiffI128 minutes = scanner.unitValue();
        if (minutes == null) {
            throw new JiffException(
                'when parsing the `HH:MM:SS` format, expected to parse minute following hour'
            );
        }
        if (!scanner.eat(58)) {
            throw new JiffException(
                'when parsing the `HH:MM:SS` format, expected to parse `:` following minute'
            );
        }
        JiffI128 seconds = scanner.unitValue();
        if (seconds == null) {
            throw new JiffException(
                'when parsing the `HH:MM:SS` format, expected to parse second following minute'
            );
        }
        units.setHms(hours, minutes, seconds, scanner.fraction());
    }

    /** Consumes the longest unit label the input continues with. */
    private static JiffUnit parseUnitDesignator(JiffDurationScanner scanner) {
        String window = scanner.upcoming(MAX_LABEL_LENGTH);
        for (Integer size = window.length(); size > 0; size--) {
            JiffUnit unit = LABELS.get(window.substring(0, size));
            if (unit != null) {
                scanner.advance(size);
                return unit;
            }
        }
        throw new JiffException(
            'expected to find unit designator suffix ' +
            '(e.g., `years` or `secs`) after parsing integer'
        );
    }

    /** Consumes the whitespace that must follow a comma. */
    private static void requireWhitespaceAfterComma(JiffDurationScanner scanner) {
        if (scanner.isDone()) {
            throw new JiffException('expected whitespace after comma, but found end of input');
        }
        if (!scanner.isAtWhitespace()) {
            throw new JiffException(
                'expected whitespace after comma, but found `' + scanner.describeNext() + '`'
            );
        }
        scanner.advance(1);
    }

    /**
     * Consumes trailing whitespace and an optional `ago`, and returns the sign of the duration
     * given the sign prefix already seen (0 for none).
     */
    private static Integer parseSuffixSign(JiffDurationScanner scanner, Integer prefixSign) {
        Boolean ago = false;
        if (scanner.isAtWhitespace()) {
            scanner.skipWhitespace();
            ago = scanner.eatText('ago');
        }
        if (ago && prefixSign != 0) {
            throw new JiffException(
                'expected to find either a prefix sign (+/-) or a suffix sign (`ago`), ' +
                'but found both'
            );
        }
        if (ago) {
            return -1;
        }
        return prefixSign == 0 ? 1 : prefixSign;
    }

    private static Map<String, JiffUnit> labels() {
        Map<String, JiffUnit> out = new Map<String, JiffUnit>();
        addLabels(out, JiffUnit.YEAR, new List<String>{ 'years', 'year', 'yrs', 'yr', 'y' });
        addLabels(out, JiffUnit.MONTH, new List<String>{ 'months', 'month', 'mos', 'mo' });
        addLabels(out, JiffUnit.WEEK, new List<String>{ 'weeks', 'week', 'wks', 'wk', 'w' });
        addLabels(out, JiffUnit.DAY, new List<String>{ 'days', 'day', 'd' });
        addLabels(out, JiffUnit.HOUR, new List<String>{ 'hours', 'hour', 'hrs', 'hr', 'h' });
        addLabels(
            out,
            JiffUnit.MINUTE,
            new List<String>{ 'minutes', 'minute', 'mins', 'min', 'm' }
        );
        addLabels(
            out,
            JiffUnit.SECOND,
            new List<String>{ 'seconds', 'second', 'secs', 'sec', 's' }
        );
        addLabels(
            out,
            JiffUnit.MILLISECOND,
            new List<String>{
                'milliseconds',
                'millisecond',
                'millis',
                'milli',
                'msecs',
                'msec',
                'ms'
            }
        );
        addLabels(
            out,
            JiffUnit.MICROSECOND,
            new List<String>{
                'microseconds',
                'microsecond',
                'micros',
                'micro',
                'usecs',
                'usec',
                'us',
                MICRO + 'secs',
                MICRO + 'sec',
                MICRO + 's'
            }
        );
        addLabels(
            out,
            JiffUnit.NANOSECOND,
            new List<String>{ 'nanoseconds', 'nanosecond', 'nanos', 'nano', 'nsecs', 'nsec', 'ns' }
        );
        return out;
    }

    private static void addLabels(Map<String, JiffUnit> out, JiffUnit unit, List<String> names) {
        for (String name : names) {
            out.put(name, unit);
        }
    }
}
