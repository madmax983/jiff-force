/**
 * Printing and parsing of the RFC 2822 datetime format used in email (`Date:` headers), and
 * printing of the RFC 9110 format used in HTTP.
 *
 *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 6, 15).at(7, 0, 0, 0)
 *         .inTz('Australia/Hobart');
 *     JiffRfc2822.toString(zdt);                   // Sat, 15 Jun 2024 07:00:00 +1000
 *     JiffRfc2822.parse('Sat, 15 Jun 2024 07:00:00 +1000');
 *     // 2024-06-15T07:00:00+10:00[+10:00]
 *     JiffRfc2822.timestampToRfc9110String(JiffTimestamp.fromSecond(1L));
 *     // Thu, 01 Jan 1970 00:00:01 GMT
 *
 * RFC 2822 holds an instant and an offset, but no time zone and no fraction of a second. A
 * zoned datetime that is printed and parsed back therefore has a fixed offset time zone, which
 * does not follow daylight saving time in arithmetic, and has lost its fraction. Use it where
 * it is required, not as a general interchange format; `toString()` and `parse` on the
 * datetime types keep everything.
 *
 * ## Parsing
 *
 * The weekday is optional, as are the seconds; a parsed weekday must match the date unless
 * `relaxedWeekday` is true. Two and three digit years are read as RFC 2822 says (`00..49` are
 * 2000 to 2049, the rest add 1900). Besides numeric offsets (`-0500`), the obsolete names are
 * understood: `UT`, `GMT` and `Z` are UTC, `EST`, `EDT`, `CST`, `CDT`, `MST`, `MDT`, `PST` and
 * `PDT` their usual offsets, and any other single letter (except `J`) or other name of three to
 * five letters means UTC as RFC 2822 asks. Any ASCII whitespace separates the parts, and a
 * comment in parentheses (nesting and backslash escapes allowed) may follow the offset.
 * Comments elsewhere are not supported. A leap second (`60`) is read as `59`.
 *
 * ## Printing
 *
 * A zoned datetime prints with its offset rounded to the nearest minute (never `-0000`); a
 * timestamp prints in UTC with the offset `-0000`, meaning "the local offset is unknown".
 * Fractions of a second are dropped. A negative year cannot be printed.
 *
 * Jiff spreads this over the `DateTimeParser` and `DateTimePrinter` types and two functions.
 * The port has no configuration objects: the one parser option is the `relaxedWeekday`
 * argument.
 *
 * Mirrors `jiff::fmt::rfc2822`.
 */
public class JiffRfc2822 {
    private static final String WHITESPACE_AFTER_TIME = 'expected whitespace after parsing time: expected at least one whitespace character (space or tab), but found none';
    private static final Map<String, Integer> OBSOLETE_OFFSET_HOURS = new Map<String, Integer>{
        'ut' => 0,
        'gmt' => 0,
        'z' => 0,
        'est' => -5,
        'edt' => -4,
        'cst' => -6,
        'cdt' => -5,
        'mst' => -7,
        'mdt' => -6,
        'pst' => -8,
        'pdt' => -7
    };
    private static final List<String> WEEKDAYS = new List<String>{
        'sun',
        'mon',
        'tue',
        'wed',
        'thu',
        'fri',
        'sat'
    };
    private static final List<String> MONTHS = new List<String>{
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec'
    };

    private final String input;
    private final Integer size;
    private final Boolean relaxed;
    private Integer pos = 0;
    // The results of `parseDateTimeOffset`.
    private JiffDateTime parsedDateTime;
    private JiffOffset parsedOffset;

    private JiffRfc2822(String input, Boolean relaxed) {
        this.input = input;
        this.size = input.length();
        this.relaxed = relaxed;
    }

    // ---- parsing ----------------------------------------------------------------

    /**
     * Parses an RFC 2822 datetime into a zoned datetime with a fixed offset time zone. Throws
     * when the text is not a valid RFC 2822 datetime, when its weekday does not match its
     * date, or when it is outside the supported range.
     *
     *     JiffRfc2822.parse('Thu, 29 Feb 2024 05:34 -0500');   // 2024-02-29T05:34:00-05:00[-05:00]
     */
    public static JiffZonedDateTime parse(String text) {
        return parse(text, false);
    }

    /**
     * Like `parse`, but when `relaxedWeekday` is true a weekday that does not match the date
     * is accepted (it must still be a weekday). Some systems write such dates.
     *
     *     JiffRfc2822.parse('Sun, 13 Jul 2024 15:09:59 -0400', true);
     *     // 2024-07-13T15:09:59-04:00[-04:00] (13 July 2024 was a Saturday)
     *
     * Mirrors `DateTimeParser::relaxed_weekday` with `DateTimeParser::parse_zoned_datetime`.
     */
    public static JiffZonedDateTime parse(String text, Boolean relaxedWeekday) {
        if (relaxedWeekday == null) {
            throw new JiffException('relaxedWeekday must not be null');
        }
        JiffRfc2822 parser = newParser(text, relaxedWeekday);
        JiffZonedDateTime zdt;
        try {
            parser.parseDateTimeOffset();
            JiffTimestamp ts = parser.parsedOffset.toTimestamp(parser.parsedDateTime);
            zdt = ts.toZonedDateTime(JiffTimeZone.fixed(parser.parsedOffset));
        } catch (JiffException e) {
            throw JiffFmtUtil.context(
                'failed to parse RFC 2822 datetime into Jiff zoned datetime',
                e
            );
        }
        parser.requireAllConsumed(zdt.toString());
        return zdt;
    }

    /**
     * Parses an RFC 2822 datetime into the instant it names.
     *
     *     JiffRfc2822.parseTimestamp('Thu, 29 Feb 2024 05:34 -0500');   // 2024-02-29T10:34:00Z
     */
    public static JiffTimestamp parseTimestamp(String text) {
        return parseTimestamp(text, false);
    }

    /**
     * Like `parseTimestamp`, but when `relaxedWeekday` is true a weekday that does not match
     * the date is accepted.
     */
    public static JiffTimestamp parseTimestamp(String text, Boolean relaxedWeekday) {
        if (relaxedWeekday == null) {
            throw new JiffException('relaxedWeekday must not be null');
        }
        JiffRfc2822 parser = newParser(text, relaxedWeekday);
        JiffTimestamp ts;
        try {
            parser.parseDateTimeOffset();
            ts = parser.parsedOffset.toTimestamp(parser.parsedDateTime);
        } catch (JiffException e) {
            throw JiffFmtUtil.context('failed to parse RFC 2822 datetime into Jiff timestamp', e);
        }
        parser.requireAllConsumed(ts.toString());
        return ts;
    }

    private static JiffRfc2822 newParser(String text, Boolean relaxedWeekday) {
        if (text == null) {
            throw new JiffException('cannot parse an RFC 2822 datetime from a null string');
        }
        return new JiffRfc2822(text, relaxedWeekday);
    }

    private void requireAllConsumed(String parsed) {
        if (pos < size) {
            throw new JiffException(
                'parsed value \'' +
                    parsed +
                    '\', but unparsed input ' +
                    JiffDurationScanner.quote(input.substring(pos)) +
                    ' remains (expected no unparsed input)'
            );
        }
    }

    // The datetime and offset, then any whitespace and a trailing comment.
    private void parseDateTimeOffset() {
        parsedDateTime = parseDateTime();
        parsedOffset = parseOffset();
        skipWhitespace();
        if (pos < size) {
            skipComment();
        }
    }

    // Everything but the offset, including the whitespace that must follow the time.
    private JiffDateTime parseDateTime() {
        if (size == 0) {
            throw new JiffException('expected RFC 2822 datetime, but got empty string');
        }
        skipWhitespace();
        if (pos >= size) {
            throw new JiffException(
                'expected RFC 2822 datetime, but got empty string after trimming leading whitespace'
            );
        }
        JiffWeekday weekday = parseWeekday();
        Integer day = parseDay();
        Integer month = parseMonth();
        Integer year = parseYear();

        Integer hour = parseTwoDigits(
            'expected two digit hour, but found end of input',
            0L,
            23L,
            'hour',
            'failed to parse hour (expects a two digit integer)'
        );
        skipWhitespace();
        parseTimeSeparator();
        skipWhitespace();
        Integer minute = parseTwoDigits(
            'expected two digit minute, but found end of input',
            0L,
            59L,
            'minute',
            'failed to parse minute (expects a two digit integer)'
        );
        Boolean whitespaceAfterMinute = skipWhitespace();
        Integer second = 0;
        if (pos >= size || input.charAt(pos) != 58) {
            if (!whitespaceAfterMinute) {
                throw new JiffException(WHITESPACE_AFTER_TIME);
            }
        } else {
            parseTimeSeparator();
            skipWhitespace();
            second = parseTwoDigits(
                'expected two digit second, but found end of input',
                0L,
                60L,
                'second',
                'failed to parse second (expects a two digit integer)'
            );
            // There are no leap seconds.
            if (second == 60) {
                second = 59;
            }
            requireWhitespace(null);
        }

        JiffDate datePart;
        try {
            datePart = JiffDate.newInstance(year, month, day);
        } catch (JiffException e) {
            throw JiffFmtUtil.context('invalid date', e);
        }
        JiffDateTime dt = JiffDateTime.fromParts(
            datePart,
            JiffTime.newInstance(hour, minute, second, 0)
        );
        if (weekday != null && !relaxed && weekday != dt.weekday()) {
            throw new JiffException(
                'found parsed weekday of `' +
                    JiffFmtUtil.weekdayName(weekday) +
                    '`, but parsed datetime has weekday `' +
                    JiffFmtUtil.weekdayName(dt.weekday()) +
                    '`'
            );
        }
        return dt;
    }

    // An optional weekday and the comma after it. A leading digit means there is none; any
    // other character must start a weekday.
    private JiffWeekday parseWeekday() {
        if (JiffFmtUtil.isDigit(input.charAt(pos))) {
            return null;
        }
        Integer remaining = JiffFmtUtil.utf8Length(input, pos, 256);
        if (remaining < 4) {
            throw new JiffException(
                'expected day at beginning of RFC 2822 datetime since first non-whitespace ' +
                    'byte, `' +
                    JiffFmtUtil.describeLeadByte(input, pos) +
                    '`, is not a digit, but given string is too short (length is ' +
                    remaining +
                    ')'
            );
        }
        Integer index = indexOfAbbreviation(WEEKDAYS);
        if (index < 0) {
            throw new JiffException(
                'expected day at beginning of RFC 2822 datetime since first non-whitespace ' +
                    'byte, `' +
                    JiffFmtUtil.describeLeadByte(input, pos) +
                    '`, is not a digit, but did not recognize a valid weekday abbreviation'
            );
        }
        pos += 3;
        skipWhitespace();
        if (pos >= size) {
            throw new JiffException(
                'expected comma after parsed weekday in RFC 2822 datetime, ' +
                'but found end of input instead'
            );
        }
        if (input.charAt(pos) != 44) {
            throw new JiffException(
                'expected comma after parsed weekday in RFC 2822 datetime, but found `' +
                    JiffFmtUtil.describeLeadByte(input, pos) +
                    '` instead'
            );
        }
        pos++;
        skipWhitespace();
        return JiffWeekdays.fromSundayZeroOffset(index);
    }

    // A one or two digit day, and the whitespace after it.
    private Integer parseDay() {
        if (pos >= size) {
            throw new JiffException('expected numeric day, but found end of input');
        }
        Integer digits = pos + 1 < size && JiffFmtUtil.isDigit(input.charAt(pos + 1)) ? 2 : 1;
        Integer day = boundedNumber(digits, 1L, 31L, 'day', 'failed to parse day');
        requireWhitespace('expected whitespace after parsing day');
        return day;
    }

    // An abbreviated month name, and the whitespace after it.
    private Integer parseMonth() {
        if (pos >= size) {
            throw new JiffException('expected abbreviated month name, but found end of input');
        }
        Integer remaining = JiffFmtUtil.utf8Length(input, pos, 256);
        if (remaining < 3) {
            throw new JiffException(
                'expected abbreviated month name, but remaining input is too short ' +
                    '(remaining bytes is ' +
                    remaining +
                    ')'
            );
        }
        Integer index = indexOfAbbreviation(MONTHS);
        if (index < 0) {
            throw new JiffException(
                'expected abbreviated month name, ' +
                'but did not recognize a valid abbreviated month name'
            );
        }
        pos += 3;
        requireWhitespace('expected whitespace after parsing abbreviated month name');
        return index + 1;
    }

    // A two, three or four digit year, and the whitespace after it.
    private Integer parseYear() {
        Integer digits = 0;
        while (
            digits < 4 &&
            pos + digits < size &&
            JiffFmtUtil.isDigit(input.charAt(pos + digits))
        ) {
            digits++;
        }
        if (digits <= 1) {
            throw new JiffException(
                'expected at least two ASCII digits for parsing a year, but only found ' + digits
            );
        }
        Integer year = boundedNumber(
            digits,
            -9999L,
            9999L,
            'year',
            'failed to parse year (expects a two, three or four digit integer)'
        );
        if (digits == 2 && year <= 49) {
            year += 2000;
        } else if (digits < 4) {
            year += 1900;
        }
        requireWhitespace('expected whitespace after parsing year');
        return year;
    }

    // Exactly two characters, which must be digits forming a number in `min..max`.
    private Integer parseTwoDigits(
        String endOfInput,
        Long min,
        Long max,
        String what,
        String context
    ) {
        if (JiffFmtUtil.utf8Length(input, pos, 2) < 2) {
            throw new JiffException(endOfInput);
        }
        return boundedNumber(Math.min(2, size - pos), min, max, what, context);
    }

    // The next `count` characters as a number in `min..max`, consumed.
    private Integer boundedNumber(Integer count, Long min, Long max, String what, String context) {
        Integer value = 0;
        for (Integer i = 0; i < count; i++) {
            Integer ch = input.charAt(pos + i);
            if (!JiffFmtUtil.isDigit(ch)) {
                throw new JiffException(
                    context +
                        ': invalid digit, expected 0-9 but got ' +
                        JiffFmtUtil.describeLeadByte(input, pos + i)
                );
            }
            value = value * 10 + (ch - 48);
        }
        try {
            JiffMath.check(value, min, max, what);
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
        pos += count;
        return value;
    }

    // The index of the three letter abbreviation the input starts with, ignoring ASCII case,
    // or -1.
    private Integer indexOfAbbreviation(List<String> abbreviations) {
        for (Integer i = 0; i < abbreviations.size(); i++) {
            if (JiffFmtUtil.startsWithIgnoreAsciiCase(input, pos, abbreviations.get(i))) {
                return i;
            }
        }
        return -1;
    }

    private void parseTimeSeparator() {
        if (pos >= size) {
            throw new JiffException('expected time separator of `:`, but found end of input');
        }
        if (input.charAt(pos) != 58) {
            throw new JiffException(
                'expected time separator of `:`, but found `' +
                    JiffFmtUtil.describeLeadByte(input, pos) +
                    '`'
            );
        }
        pos++;
    }

    // A numeric offset (`+HHMM`) or an obsolete name.
    private JiffOffset parseOffset() {
        if (pos >= size) {
            throw new JiffException(
                'expected sign for time zone offset, (or a legacy time zone name abbreviation), ' +
                'but found end of input'
            );
        }
        Integer sign = input.charAt(pos);
        if (sign != 43 && sign != 45) {
            return parseObsoleteOffset();
        }
        pos++;
        if (JiffFmtUtil.utf8Length(input, pos, 4) < 4) {
            throw new JiffException(
                'expected at least four digits for time zone offset after sign, ' +
                'but found fewer than four bytes remaining'
            );
        }
        Integer hours = boundedNumber(
            Math.min(2, size - pos),
            -25L,
            25L,
            'time zone offset hours',
            'failed to parse hours from time zone offset'
        );
        Integer minutes = boundedNumber(
            Math.min(2, size - pos),
            -59L,
            59L,
            'time zone offset minutes',
            'failed to parse minutes from time zone offset'
        );
        Integer seconds = hours * 3600 + minutes * 60;
        return JiffOffset.fromSeconds(sign == 45 ? -seconds : seconds);
    }

    private JiffOffset parseObsoleteOffset() {
        Integer length = 0;
        while (
            length < 5 &&
            pos + length < size &&
            !JiffFmtUtil.isAsciiWhitespace(input.charAt(pos + length))
        ) {
            length++;
        }
        if (length == 0) {
            throw new JiffException(
                'expected obsolete RFC 2822 time zone abbreviation, ' +
                'but found no remaining non-whitespace characters after time'
            );
        }
        String name = JiffFmtUtil.toAsciiLowerCase(input.substring(pos, pos + length));
        Integer hours = OBSOLETE_OFFSET_HOURS.get(name);
        if (hours == null && !isUnknownZoneName(name)) {
            throw new JiffException(
                'expected obsolete RFC 2822 time zone abbreviation, ' +
                'but did not recognize a valid abbreviation'
            );
        }
        pos += length;
        return hours == null ? JiffOffset.UTC : JiffOffset.fromHours(hours);
    }

    // RFC 2822 asks that a military zone letter (other than `J`), or another alphabetic zone
    // name of three or more letters, be read as `-0000`.
    private static Boolean isUnknownZoneName(String name) {
        if (name.length() == 1) {
            Integer ch = name.charAt(0);
            return ch >= 97 && ch <= 122 && ch != 106;
        }
        if (name.length() < 3) {
            return false;
        }
        for (Integer i = 0; i < name.length(); i++) {
            Integer ch = name.charAt(i);
            if (ch < 97 || ch > 122) {
                return false;
            }
        }
        return true;
    }

    // A comment in parentheses, which may nest and may escape a character with a backslash,
    // and the whitespace after it.
    private void skipComment() {
        if (input.charAt(pos) != 40) {
            return;
        }
        pos++;
        Integer depth = 1;
        Boolean escaped = false;
        while (pos < size) {
            Integer ch = input.charAt(pos);
            pos++;
            if (escaped) {
                escaped = false;
            } else if (ch == 92) {
                escaped = true;
            } else if (ch == 41) {
                depth--;
                if (depth == 0) {
                    break;
                }
            } else if (ch == 40) {
                if (depth == 255) {
                    throw new JiffException('found too many nested parenthesis in comment');
                }
                depth++;
            }
        }
        if (depth > 0) {
            throw new JiffException(
                'found opening parenthesis in comment with no matching closing parenthesis'
            );
        }
        skipWhitespace();
    }

    // At least one whitespace character. `context`, when given, prefixes the error.
    private void requireWhitespace(String context) {
        if (!skipWhitespace()) {
            throw new JiffException(
                context == null ? WHITESPACE_AFTER_TIME : context + ': ' + WHITESPACE_AFTER_TIME
            );
        }
    }

    // Skips ASCII whitespace and says whether there was any.
    private Boolean skipWhitespace() {
        Integer start = pos;
        while (pos < size && JiffFmtUtil.isAsciiWhitespace(input.charAt(pos))) {
            pos++;
        }
        return pos > start;
    }

    // ---- printing ---------------------------------------------------------------

    /**
     * Formats a zoned datetime as RFC 2822: `Sat, 15 Jun 2024 07:00:00 -0400`. The offset is
     * rounded to the nearest minute and is never written as `-0000`; the fraction of the
     * second is dropped. Throws for a negative year.
     *
     * Mirrors `jiff::fmt::rfc2822::to_string` and `DateTimePrinter::zoned_datetime_to_string`.
     */
    public static String toString(JiffZonedDateTime zdt) {
        if (zdt == null) {
            throw new JiffException('cannot format a null zoned datetime as RFC 2822');
        }
        return printWithOffset(zdt.toDateTime(), zdt.offset());
    }

    /**
     * Formats a timestamp as RFC 2822, in UTC with the offset `-0000`, which says that the
     * local offset is unknown: `Thu, 1 Jan 1970 00:00:01 -0000`. For `+0000`, format a zoned
     * datetime in `JiffTimeZone.UTC` instead. Throws for a negative year.
     *
     * Mirrors `DateTimePrinter::timestamp_to_string`.
     */
    public static String timestampToString(JiffTimestamp timestamp) {
        if (timestamp == null) {
            throw new JiffException('cannot format a null timestamp as RFC 2822');
        }
        return printWithOffset(JiffOffset.UTC.toDateTime(timestamp), null);
    }

    /**
     * Formats a timestamp as RFC 9110 (HTTP) wants it: in UTC, with `GMT` and a two digit day,
     * always 29 characters: `Thu, 01 Jan 1970 00:00:01 GMT`. Throws for a negative year.
     *
     * Mirrors `DateTimePrinter::timestamp_to_rfc9110_string`.
     */
    public static String timestampToRfc9110String(JiffTimestamp timestamp) {
        if (timestamp == null) {
            throw new JiffException('cannot format a null timestamp as RFC 9110');
        }
        JiffDateTime dt = JiffOffset.UTC.toDateTime(timestamp);
        requireNonNegativeYear(dt);
        return datePart(dt, JiffMath.pad(dt.day(), 2)) + ' GMT';
    }

    private static String printWithOffset(JiffDateTime dt, JiffOffset offset) {
        requireNonNegativeYear(dt);
        String text = datePart(dt, String.valueOf(dt.day())) + ' ';
        if (offset == null) {
            return text + '-0000';
        }
        List<Integer> rounded = roundToNearestMinute(offset);
        return text +
            (offset.isNegative() ? '-' : '+') +
            JiffMath.pad(rounded.get(0), 2) +
            JiffMath.pad(rounded.get(1), 2);
    }

    private static void requireNonNegativeYear(JiffDateTime dt) {
        if (dt.year() < 0) {
            throw new JiffException(
                'datetime has negative year, which cannot be formatted with RFC 2822'
            );
        }
    }

    // `Sat, 15 Jun 2024 07:00:00`, with the day as given.
    private static String datePart(JiffDateTime dt, String day) {
        return JiffFmtUtil.weekdayAbbreviation(dt.weekday()) +
            ', ' +
            day +
            ' ' +
            JiffFmtUtil.monthAbbreviation(dt.month()) +
            ' ' +
            JiffMath.pad(dt.year(), 4) +
            ' ' +
            JiffMath.pad(dt.hour(), 2) +
            ':' +
            JiffMath.pad(dt.minute(), 2) +
            ':' +
            JiffMath.pad(dt.second(), 2);
    }

    // The hours and minutes of the offset's magnitude, rounded half up to the minute but
    // never beyond the largest offset, 25:59.
    private static List<Integer> roundToNearestMinute(JiffOffset offset) {
        Integer total = Math.abs(offset.seconds());
        Integer hours = total / 3600;
        Integer minutes = Math.mod(total / 60, 60);
        if (Math.mod(total, 60) >= 30) {
            if (minutes == 59) {
                hours++;
                minutes = 0;
                if (hours > 25) {
                    hours = 25;
                    minutes = 59;
                }
            } else {
                minutes++;
            }
        }
        return new List<Integer>{ hours, minutes };
    }
}
