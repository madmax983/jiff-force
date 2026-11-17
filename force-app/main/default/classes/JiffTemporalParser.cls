/**
 * The parser behind `JiffTemporal`'s datetime functions: dates, times, UTC offsets and RFC
 * 9557 annotations in the Temporal ISO 8601 grammar, plus ISO 8601 week dates and time zone
 * names. Internal: call `JiffTemporal.parseDate` and friends, or `parse` on the types.
 *
 * The grammar, informally:
 *
 *     datetime   = date [ ("T" | "t" | " ") time [ offset ] ] [ annotations ]
 *     date       = year "-" month "-" day  |  year month day
 *     year       = 4 digits  |  ("+" | "-") 6 digits
 *     time       = hour [ ":" minute [ ":" second [ fraction ] ] ]
 *                | hour [ minute [ second [ fraction ] ] ]
 *     fraction   = ("." | ",") 1 to 9 digits
 *     offset     = "Z" | "z" | ("+" | "-") hour [ minute [ second [ fraction ] ] ]
 *     annotations = [ "[" ["!"] (zone name | offset) "]" ] { "[" ["!"] key "=" value "]" }
 *
 * A second of `60` is accepted and read as `59`, since a leap second cannot be represented.
 * Signs are ASCII only.
 *
 * Jiff's parser walks a byte slice and returns "the rest of the input" from every step. Here
 * a `JiffDurationScanner` holds the position instead, and each method of this class consumes
 * what it parses.
 *
 * Mirrors `jiff::fmt::temporal::parser::DateTimeParser` and `jiff::fmt::rfc9557::Parser`.
 */
public class JiffTemporalParser {
    // The offset that may follow a time: `Z` is allowed, and so is sub-minute precision.
    private static final JiffTemporalOffsetParser DATETIME_OFFSET = new JiffTemporalOffsetParser();
    // The offset inside a time zone annotation: no `Z`, and whole minutes only.
    private static final JiffTemporalOffsetParser ANNOTATION_OFFSET = new JiffTemporalOffsetParser()
        .zulu(false)
        .subminute(false);
    // An offset given as a time zone: no `Z`, whole seconds at most.
    private static final JiffTemporalOffsetParser TIME_ZONE_OFFSET = new JiffTemporalOffsetParser()
        .zulu(false)
        .subsecond(false);

    private final String input;
    private final JiffDurationScanner scanner;
    // Whether the time most recently parsed by `timeSpec` used `:` between its components.
    private Boolean timeExtended = false;
    // The time zone annotation most recently parsed, the way an error message echoes it: a
    // name as written, an offset in the extended format (`[+01]`, `[!-05:30]`).
    private String annotationEcho = '';

    private JiffTemporalParser(String input) {
        if (input == null) {
            throw new JiffException('cannot parse a datetime from a null string');
        }
        this.input = input;
        this.scanner = new JiffDurationScanner(input);
    }

    // ---- entry points ---------------------------------------------------

    /**
     * Parses a whole string as a datetime: a date, optionally followed by a time, an offset
     * and annotations. Which of those parts are required or allowed is decided by the
     * conversion called on the result.
     *
     * Mirrors `DateTimeParser::parse_temporal_datetime` followed by `Parsed::into_full`.
     */
    public static JiffTemporalParsed parseDateTime(String text) {
        JiffTemporalParser parser = new JiffTemporalParser(text);
        JiffTemporalParsed parsed = parser.temporalDateTime();
        if (!parser.scanner.isDone()) {
            parser.scanner.finish(parsed.toString());
        }
        return parsed;
    }

    /**
     * Parses a whole string as a time of day. The string may be a bare time (`15:22:45`), a
     * time behind a `T` designator (`T152245`), or a full datetime, whose date is ignored.
     *
     * A bare time in the basic format (`1214`) is rejected when it could also be read as a
     * month and day or as a year and month; the `T` designator settles it.
     *
     * Mirrors `DateTimeParser::parse_temporal_time` followed by `Parsed::into_full`.
     */
    public static JiffTime parseTime(String text) {
        JiffTemporalParser parser = new JiffTemporalParser(text);
        JiffTime parsed = parser.temporalTime();
        if (!parser.scanner.isDone()) {
            parser.scanner.finish(JiffTemporal.printTime(parsed));
        }
        return parsed;
    }

    /**
     * Parses a whole string as an ISO 8601 week date: `2024-W10-6` or `2024W106`.
     *
     * Mirrors `DateTimeParser::parse_iso_week_date` followed by `Parsed::into_full`.
     */
    public static JiffIsoWeekDate parseIsoWeekDate(String text) {
        JiffTemporalParser parser = new JiffTemporalParser(text);
        JiffIsoWeekDate parsed = parser.isoWeekDate();
        if (!parser.scanner.isDone()) {
            parser.scanner.finish(JiffTemporal.printIsoWeekDate(parsed));
        }
        return parsed;
    }

    /**
     * Parses a whole string as a time zone: an IANA name such as `America/New_York`, or a UTC
     * offset such as `-05:00` for a fixed offset zone.
     *
     * Mirrors `DateTimeParser::parse_time_zone`, except that POSIX TZ strings are not
     * supported: anything that is not an offset is looked up as a name.
     */
    public static JiffTimeZone parseTimeZone(String text) {
        JiffTemporalParser parser = new JiffTemporalParser(text);
        return parser.timeZone();
    }

    // ---- shared helpers -------------------------------------------------

    /**
     * Consumes exactly `count` ASCII digits and returns their value, which must lie in
     * `min..max`.
     *
     * Throws `endOfInput` when fewer than `count` bytes are left. Otherwise throws `context`
     * followed by the reason: the first character that is not a digit, or the range `what`
     * must be in.
     *
     * Jiff measures the input in UTF-8 bytes. This does too, so that a character outside
     * ASCII gives the same error here as there.
     *
     * Mirrors `jiff::util::parse::split` followed by `jiff::util::parse::bi64`.
     */
    public static Integer digits(
        JiffDurationScanner scanner,
        Integer count,
        String endOfInput,
        String context,
        String what,
        Integer min,
        Integer max
    ) {
        String text = scanner.upcoming(count);
        Integer available = 0;
        for (Integer i = 0; i < text.length(); i++) {
            Integer unit = text.charAt(i);
            if (unit < 128) {
                available += 1;
            } else if (unit < 2048 || (unit >= 55296 && unit <= 57343)) {
                // Two bytes, or half of a surrogate pair that is four bytes in all.
                available += 2;
            } else {
                available += 3;
            }
        }
        if (available < count) {
            throw new JiffException(endOfInput);
        }
        Integer value = 0;
        for (Integer i = 0; i < text.length(); i++) {
            Integer unit = text.charAt(i);
            if (!isDigit(unit)) {
                scanner.advance(i);
                throw new JiffException(
                    context + ': invalid digit, expected 0-9 but got ' + scanner.describeNext()
                );
            }
            value = value * 10 + (unit - 48);
        }
        if (value < min || value > max) {
            throw new JiffException(
                context + ': ' + JiffMath.rangeError(what, min, max).getMessage()
            );
        }
        scanner.advance(count);
        return value;
    }

    /**
     * Consumes an optional fraction (`.` or `,` and up to nine digits) and returns it in
     * nanoseconds, or -1 when the next character is not a decimal separator. Throws `context`
     * followed by the reason when the separator has no digits after it.
     *
     * Mirrors `jiff::fmt::util::parse_temporal_fraction`.
     */
    public static Integer fraction(JiffDurationScanner scanner, String context) {
        try {
            return scanner.fraction();
        } catch (JiffException e) {
            throw new JiffException(context + ': ' + e.getMessage(), e);
        }
    }

    /** Whether the next two characters are both ASCII digits. Consumes nothing. */
    public static Boolean atTwoDigits(JiffDurationScanner scanner) {
        String text = scanner.upcoming(2);
        return text.length() == 2 && isDigit(text.charAt(0)) && isDigit(text.charAt(1));
    }

    private static Boolean isDigit(Integer ch) {
        return ch >= 48 && ch <= 57;
    }

    private static Boolean isLower(Integer ch) {
        return ch >= 97 && ch <= 122;
    }

    private static Boolean isAlpha(Integer ch) {
        return isLower(ch) || (ch >= 65 && ch <= 90);
    }

    // ---- datetimes ------------------------------------------------------

    private JiffTemporalParsed temporalDateTime() {
        JiffDate datePart = dateSpec();
        JiffTime timePart = null;
        JiffTemporalParsedOffset offsetPart = null;
        // Without a separator there is no time, and so no offset either: only annotations
        // may follow a bare date.
        if (scanner.eat(32) || scanner.eatEither(84, 116)) {
            timePart = timeSpec();
            offsetPart = DATETIME_OFFSET.parseOptional(scanner);
        }
        JiffPiecesTimeZoneAnnotation annotationPart = null;
        if (scanner.peek() == 91) {
            annotationPart = timeZoneAnnotation();
            otherAnnotations();
        }
        return new JiffTemporalParsed(
            datePart,
            timePart,
            offsetPart,
            annotationPart,
            annotationPart == null ? '' : annotationEcho
        );
    }

    private JiffTime temporalTime() {
        Integer start = scanner.position();
        if (scanner.eatEither(84, 116)) {
            JiffTime designated = timeSpec();
            JiffTemporalParsed.rejectZulu(DATETIME_OFFSET.parseOptional(scanner));
            annotations();
            return designated;
        }
        // Look for a full datetime before a bare time. Otherwise the `2024-06` of
        // `2024-06-01T01:02:03` would be read as the time `20:24` with an offset of `-06`.
        JiffTemporalParsed full = null;
        try {
            full = temporalDateTime();
        } catch (JiffException e) {
            scanner.rewind(start);
        }
        if (full != null) {
            JiffTemporalParsed.rejectZulu(full.offset());
            if (full.civilTime() == null) {
                throw new JiffException(
                    'successfully parsed date, but no time component was found'
                );
            }
            return full.civilTime();
        }

        JiffTime bare = timeSpec();
        JiffTemporalParsed.rejectZulu(DATETIME_OFFSET.parseOptional(scanner));
        // A time without colons can look like part of a date: `1214` is 12:14, but also
        // December 14th, and `202012` is also December 2020. The time and its offset together
        // are what is ambiguous, so both are checked.
        if (!timeExtended) {
            String consumed = input.substring(start, scanner.position());
            if (isMonthDay(consumed)) {
                throw new JiffException('parsed time is ambiguous with a month-day date');
            }
            if (isYearMonth(consumed)) {
                throw new JiffException('parsed time is ambiguous with a year-month date');
            }
        }
        annotations();
        return bare;
    }

    private JiffDate dateSpec() {
        Integer year = year();
        Boolean extended = scanner.peek() == 45;
        dateSeparator(extended, 'failed to parse separator after year');
        Integer month = digits(
            scanner,
            2,
            'expected two digit month, but found end of input',
            'failed to parse two digit integer as month',
            'month',
            1,
            12
        );
        dateSeparator(extended, 'failed to parse separator after month');
        Integer day = digits(
            scanner,
            2,
            'expected two digit day, but found end of input',
            'failed to parse two digit integer as day',
            'day',
            1,
            31
        );
        try {
            return JiffDate.newInstance(year, month, day);
        } catch (JiffException e) {
            throw new JiffException('parsed date is not valid: ' + e.getMessage(), e);
        }
    }

    private JiffTime timeSpec() {
        Integer hour = digits(
            scanner,
            2,
            'expected two digit hour, but found end of input',
            'failed to parse two digit integer as hour',
            'hour',
            0,
            23
        );
        timeExtended = scanner.peek() == 58;
        if (!hasNextTimeComponent()) {
            return JiffTime.newInstance(hour, 0, 0, 0);
        }
        Integer minute = digits(
            scanner,
            2,
            'expected two digit minute, but found end of input',
            'failed to parse two digit integer as minute',
            'minute',
            0,
            59
        );
        if (!hasNextTimeComponent()) {
            return JiffTime.newInstance(hour, minute, 0, 0);
        }
        Integer second = digits(
            scanner,
            2,
            'expected two digit second, but found end of input',
            'failed to parse two digit integer as second',
            'second',
            0,
            60
        );
        // A leap second cannot be represented, so it is clamped to the second before it.
        if (second == 60) {
            second = 59;
        }
        Integer nanosecond = fraction(scanner, 'failed to parse fractional seconds in time');
        return JiffTime.newInstance(hour, minute, second, nanosecond < 0 ? 0 : nanosecond);
    }

    /**
     * Whether another time component follows, consuming the `:` that introduces it in the
     * extended format. In the basic format another component follows exactly when the next
     * two characters are digits.
     */
    private Boolean hasNextTimeComponent() {
        return timeExtended ? scanner.eat(58) : atTwoDigits(scanner);
    }

    /**
     * A four digit year, or a sign and a six digit year. A negative year can only be written
     * in the six digit form, and year zero may not have a negative sign.
     */
    private Integer year() {
        Boolean negative = scanner.peek() == 45;
        if (!negative && scanner.peek() != 43) {
            return digits(
                scanner,
                4,
                'expected four digit year (or leading sign for six digit year), ' +
                'but found end of input',
                'failed to parse four digit integer as year',
                'year',
                -9999,
                9999
            );
        }
        scanner.advance(1);
        Integer magnitude = digits(
            scanner,
            6,
            'expected six digit year (because of a leading sign), but found end of input',
            'failed to parse six digit integer as year',
            'year',
            -9999,
            9999
        );
        if (magnitude == 0 && negative) {
            throw new JiffException(
                'year zero must be written without a sign or a positive sign, ' +
                'but not a negative sign'
            );
        }
        return negative ? -magnitude : magnitude;
    }

    /**
     * The separator between date components. In the extended format a `-` is required. In the
     * basic format there is none, and finding a `-` is reported as such rather than as a bad
     * digit in the next component.
     */
    private void dateSeparator(Boolean extended, String context) {
        if (!extended) {
            if (scanner.peek() == 45) {
                throw new JiffException(
                    context +
                        ': expected no separator since none was found after the year, ' +
                        'but found a `-` separator'
                );
            }
            return;
        }
        if (scanner.isDone()) {
            throw new JiffException(context + ': expected `-` separator, but found end of input');
        }
        if (!scanner.eat(45)) {
            throw new JiffException(
                context + ': expected `-` separator, but found `' + scanner.describeNext() + '`'
            );
        }
    }

    /**
     * Whether `text` starts with a valid month and day, `MM-DD` or `MMDD`. February 29th
     * counts as valid.
     */
    private static Boolean isMonthDay(String text) {
        Integer month = twoDigitsAt(text, 0);
        if (month < 1 || month > 12) {
            return false;
        }
        Integer dayAt = text.length() > 2 && text.charAt(2) == 45 ? 3 : 2;
        Integer day = twoDigitsAt(text, dayAt);
        // 2024 is a leap year.
        return day >= 1 && day <= JiffDate.daysInMonth(2024, month);
    }

    /**
     * Whether `text` starts with a year and a valid month, `YYYY-MM` or `YYYYMM`. The text is
     * always what a bare time consumed, which starts with the two digits of an hour, so a
     * signed six digit year cannot occur and only the second half of the year needs checking.
     */
    private static Boolean isYearMonth(String text) {
        if (twoDigitsAt(text, 2) < 0) {
            return false;
        }
        Integer monthAt = text.length() > 4 && text.charAt(4) == 45 ? 5 : 4;
        Integer month = twoDigitsAt(text, monthAt);
        return month >= 1 && month <= 12;
    }

    /** The value of the two digits at `index`, or -1 when there are not two digits there. */
    private static Integer twoDigitsAt(String text, Integer index) {
        if (text.length() < index + 2) {
            return -1;
        }
        Integer tens = text.charAt(index);
        Integer ones = text.charAt(index + 1);
        return isDigit(tens) && isDigit(ones) ? (tens - 48) * 10 + (ones - 48) : -1;
    }

    // ---- RFC 9557 annotations -------------------------------------------

    /** Parses any annotations at the scanner's position and discards them. */
    private void annotations() {
        if (scanner.peek() == 91) {
            timeZoneAnnotation();
            otherAnnotations();
        }
    }

    /**
     * Parses the time zone annotation that may come first: `[America/New_York]`, `[-05:00]`,
     * either with a leading `!`. Returns null, consuming nothing, when the next annotation is
     * a `key=value` one instead.
     */
    private JiffPiecesTimeZoneAnnotation timeZoneAnnotation() {
        Integer start = scanner.position();
        scanner.advance(1);
        Boolean critical = scanner.eat(33);
        // Neither a zone name nor a key can start with a sign, so this must be an offset.
        if (scanner.peek() == 43 || scanner.peek() == 45) {
            JiffTemporalParsedOffset offset = ANNOTATION_OFFSET.parse(scanner);
            timeZoneAnnotationClose();
            annotationEcho = (critical ? '[!' : '[') + offset.toString() + ']';
            return JiffPiecesTimeZoneAnnotation.fromOffset(offset.toOffset())
                .withCritical(critical);
        }
        // A zone name and a key look alike at first: zone names are a superset of keys. Read
        // one name component. If an `=` follows, this was a key all along.
        Integer nameStart = scanner.position();
        zoneNameComponent();
        if (scanner.peek() == 61) {
            scanner.rewind(start);
            return null;
        }
        while (scanner.eat(47)) {
            zoneNameComponent();
        }
        String name = input.substring(nameStart, scanner.position());
        timeZoneAnnotationClose();
        annotationEcho = (critical ? '[!' : '[') + name + ']';
        return JiffPiecesTimeZoneAnnotation.fromName(name).withCritical(critical);
    }

    /** One `/` separated component of a time zone name, such as `America` or `New_York`. */
    private void zoneNameComponent() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected the start of an RFC 9557 annotation or IANA time zone ' +
                'component name, but found end of input instead'
            );
        }
        Integer first = scanner.peek();
        if (!isAlpha(first) && first != 95 && first != 46) {
            throw new JiffException(
                'expected ASCII alphabetic byte (or underscore or period) at the start of ' +
                    'an RFC 9557 annotation or time zone component name, but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
        scanner.advance(1);
        Integer ch = scanner.peek();
        while (isAlpha(ch) || isDigit(ch) || ch == 95 || ch == 46 || ch == 43 || ch == 45) {
            scanner.advance(1);
            ch = scanner.peek();
        }
    }

    private void timeZoneAnnotationClose() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected an `]` after parsing an RFC 9557 time zone annotation, ' +
                'but found end of input instead'
            );
        }
        if (!scanner.eat(93)) {
            throw new JiffException(
                'expected an `]` after parsing an RFC 9557 time zone annotation, but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
    }

    /**
     * Parses every `[key=value]` annotation that follows. None of them mean anything to this
     * library, so they are only checked for syntax, and one marked critical is an error.
     */
    private void otherAnnotations() {
        while (scanner.peek() == 91) {
            scanner.advance(1);
            Boolean critical = scanner.eat(33);
            annotationKey();
            annotationSeparator();
            annotationValue();
            while (scanner.eat(45)) {
                annotationValue();
            }
            annotationClose();
            if (critical) {
                throw new JiffException(
                    'found unsupported RFC 9557 annotation with the critical flag (`!`) set'
                );
            }
        }
    }

    private void annotationKey() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected the start of an RFC 9557 annotation key, ' +
                'but found end of input instead'
            );
        }
        Integer first = scanner.peek();
        if (!isLower(first) && first != 95) {
            throw new JiffException(
                'expected lowercase alphabetic byte (or underscore) at the start of ' +
                    'an RFC 9557 annotation key, but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
        scanner.advance(1);
        Integer ch = scanner.peek();
        while (isLower(ch) || isDigit(ch) || ch == 95 || ch == 45) {
            scanner.advance(1);
            ch = scanner.peek();
        }
    }

    private void annotationSeparator() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected an `=` after parsing an RFC 9557 annotation key, ' +
                'but found end of input instead'
            );
        }
        if (scanner.eat(61)) {
            return;
        }
        // A `/` here most likely means a time zone annotation in the wrong place.
        if (scanner.peek() == 47) {
            throw new JiffException(
                'expected an `=` after parsing an RFC 9557 annotation key, ' +
                'but found `/` instead (time zone annotations must come first)'
            );
        }
        throw new JiffException(
            'expected an `=` after parsing an RFC 9557 annotation key, but found `' +
                scanner.describeNext() +
                '` instead'
        );
    }

    private void annotationValue() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected the start of an RFC 9557 annotation value, ' +
                'but found end of input instead'
            );
        }
        Integer ch = scanner.peek();
        if (!isAlpha(ch) && !isDigit(ch)) {
            throw new JiffException(
                'expected alphanumeric ASCII byte at the start of ' +
                    'an RFC 9557 annotation value, but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
        while (isAlpha(ch) || isDigit(ch)) {
            scanner.advance(1);
            ch = scanner.peek();
        }
    }

    private void annotationClose() {
        if (scanner.isDone()) {
            throw new JiffException(
                'expected an `]` after parsing an RFC 9557 annotation key and value, ' +
                'but found end of input instead'
            );
        }
        if (!scanner.eat(93)) {
            throw new JiffException(
                'expected an `]` after parsing an RFC 9557 annotation key and value, ' +
                    'but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
    }

    // ---- ISO 8601 week dates --------------------------------------------

    private JiffIsoWeekDate isoWeekDate() {
        Integer year = year();
        Boolean extended = scanner.peek() == 45;
        dateSeparator(extended, 'failed to parse separator after year');
        if (scanner.isDone()) {
            throw new JiffException(
                'failed to parse week number prefix in date: ' +
                'expected `W` or `w`, but found end of input'
            );
        }
        if (!scanner.eatEither(87, 119)) {
            throw new JiffException(
                'failed to parse week number prefix in date: expected `W` or `w`, but found `' +
                    scanner.describeNext() +
                    '` instead'
            );
        }
        Integer week = digits(
            scanner,
            2,
            'expected two digit week number, but found end of input',
            'failed to parse two digit integer as week number',
            'iso-week',
            1,
            53
        );
        dateSeparator(extended, 'failed to parse separator after week number');
        Integer weekday = digits(
            scanner,
            1,
            'expected one digit weekday, but found end of input',
            'failed to parse one digit integer as weekday',
            'weekday (Monday 1-indexed)',
            1,
            7
        );
        try {
            return JiffIsoWeekDate.newInstance(
                year,
                week,
                JiffWeekdays.fromMondayOneOffset(weekday)
            );
        } catch (JiffException e) {
            throw new JiffException('parsed week date is not valid: ' + e.getMessage(), e);
        }
    }

    // ---- time zones -----------------------------------------------------

    private JiffTimeZone timeZone() {
        if (scanner.isDone()) {
            throw new JiffException('an empty string is not a valid time zone');
        }
        Integer first = scanner.peek();
        if (first == 43 || first == 45) {
            JiffTemporalParsedOffset offset = TIME_ZONE_OFFSET.parse(scanner);
            requireWholeTimeZone();
            return JiffTimeZone.fixed(offset.toOffset());
        }
        // Anything else is taken to be a name, which runs to the first whitespace.
        while (!scanner.isDone() && !scanner.isAtWhitespace()) {
            scanner.advance(1);
        }
        String name = input.substring(0, scanner.position());
        requireWholeTimeZone();
        try {
            return JiffTimeZone.get(name);
        } catch (JiffException e) {
            throw new JiffException(
                'parsed apparent IANA time zone identifier, but the tzdb lookup failed: ' +
                e.getMessage(),
                e
            );
        }
    }

    /** Requires that a time zone took up the whole input. The error echoes all of it. */
    private void requireWholeTimeZone() {
        if (!scanner.isDone()) {
            String quoted = JiffDurationScanner.quote(input);
            scanner.finish(quoted.substring(1, quoted.length() - 1));
        }
    }
}
