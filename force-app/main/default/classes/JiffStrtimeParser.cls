/**
 * The `strptime` side of `JiffStrtime`: reads text according to a format string into a
 * `JiffBrokenDownTime`. Internal: use `JiffBrokenDownTime.parse`, `JiffStrtime.parse` or the
 * `strptime` methods of the datetime types.
 *
 * Literal text in the format must appear in the input, except that one whitespace character
 * in the format matches any run of whitespace (or none) in the input. Each directive reads
 * one field. Numbers may have fewer digits than their default width, and leading whitespace
 * before a number is skipped; a width in the format raises how many digits are read, so
 * `%03d` reads `005`. Names of months and weekdays and `AM`/`PM` are matched without regard to
 * ASCII case. The flags are read but, apart from changing the width, ignored.
 *
 * Positions are UTF-16 code units. Where Jiff reports a byte of UTF-8 in an error (a literal
 * that does not match, an unknown directive), the port reports the same byte.
 *
 * Mirrors `jiff::fmt::strtime::parse::Parser`.
 */
public class JiffStrtimeParser {
    private static final JiffTemporalOffsetParser OFFSET_NO_COLON = new JiffTemporalOffsetParser()
        .zulu(false)
        .requireMinute(true)
        .subminute(true)
        .subsecond(false)
        .colon(JiffTemporalOffsetColon.ABSENT);
    private static final JiffTemporalOffsetParser OFFSET_COLON = OFFSET_NO_COLON.colon(
        JiffTemporalOffsetColon.REQUIRED
    );
    private static final JiffTemporalOffsetParser OFFSET_COLON_SECONDS = OFFSET_COLON.requireSecond(
        true
    );
    private static final JiffTemporalOffsetParser OFFSET_COLON_HOURS = OFFSET_COLON.requireMinute(
        false
    );

    private static final List<String> AMPM = new List<String>{ 'am', 'pm' };

    private final JiffStrtimeFormatReader reader;
    private final String inp;
    private final Integer size;
    private Integer ipos = 0;
    private JiffBrokenDownTime tm;

    private JiffStrtimeParser(
        JiffStrtimeFormatReader reader,
        String inp,
        Integer ipos,
        JiffBrokenDownTime tm
    ) {
        this.reader = reader;
        this.inp = inp;
        this.size = inp.length();
        this.ipos = ipos;
        this.tm = tm;
    }

    /**
     * Parses all of `input` according to `fmt`. Throws, with the message prefixed by
     * `strptime parsing failed`, when the format is invalid or the input does not match it,
     * and with a message of its own when input is left over.
     */
    public static JiffBrokenDownTime parse(String fmt, String input) {
        JiffStrtimeParser parser = run(fmt, input);
        if (parser.ipos < parser.size) {
            throw new JiffException(
                'strptime expects to consume the entire input, but `' +
                    JiffFmtUtil.describeText(input.substring(parser.ipos)) +
                    '` remains unparsed'
            );
        }
        return parser.tm;
    }

    /**
     * Parses a prefix of `input` according to `fmt`, and returns what was parsed together with
     * the length of the prefix in UTF-16 code units.
     */
    public static JiffBrokenDownTimePrefix parsePrefix(String fmt, String input) {
        JiffStrtimeParser parser = run(fmt, input);
        return new JiffBrokenDownTimePrefix(parser.tm, parser.ipos);
    }

    private static JiffStrtimeParser run(String fmt, String input) {
        if (input == null) {
            throw new JiffException('strptime input must not be null');
        }
        JiffStrtimeParser parser = new JiffStrtimeParser(
            new JiffStrtimeFormatReader(fmt),
            input,
            0,
            new JiffBrokenDownTime()
        );
        try {
            parser.parseAll();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('strptime parsing failed', e);
        }
        return parser;
    }

    private void parseAll() {
        while (!reader.isDone()) {
            if (reader.f() != 37) {
                parseLiteral();
                continue;
            }
            if (!reader.bump()) {
                throw new JiffException(
                    'invalid format string, expected byte after `%`, ' +
                    'but found end of format string'
                );
            }
            // `%.f` may match nothing at all, so it is the one directive allowed at the end.
            if (ipos >= size && reader.f() != 46) {
                throw new JiffException(
                    'expected non-empty input for directive `%' +
                        reader.describeCurrent() +
                        '`, but found end of input'
                );
            }
            JiffStrtimeExtension ext = reader.parseExtension();
            parseDirective(ext);
            reader.bump();
        }
    }

    private void parseDirective(JiffStrtimeExtension ext) {
        Integer directive = reader.f();
        String name = reader.text().substring(reader.position(), reader.position() + 1);
        if (directive == 46) {
            parseDotFraction(ext);
            return;
        }
        rejectUnparseable(directive, ext);
        try {
            parseField(directive, ext);
        } catch (JiffException e) {
            String colons = directive == 81 || directive == 122 ? ':'.repeat(ext.colons()) : '';
            throw JiffFmtUtil.context('%' + colons + name + ' failed', e);
        }
    }

    // Directives that cannot be parsed, and directives that do not exist.
    private void rejectUnparseable(Integer directive, JiffStrtimeExtension ext) {
        if (directive == 81 && ext.colons() > 1) {
            throw new JiffException('invalid number of `:` in `%Q` directive');
        } else if (directive == 99) {
            throw new JiffException('parsing locale date and time is not allowed');
        } else if (directive == 114) {
            throw new JiffException('parsing locale 12-hour clock time is not allowed');
        } else if (directive == 88) {
            throw new JiffException('parsing locale clock time is not allowed');
        } else if (directive == 120) {
            throw new JiffException('parsing locale date is not allowed');
        } else if (directive == 90) {
            throw new JiffException('parsing time zone abbreviation is not allowed');
        }
        String parseable = '%AaBbCDdeFfGgHhIjklMmNnPpQRSsTtUuVWwYyz';
        String name = reader.text().substring(reader.position(), reader.position() + 1);
        if (directive >= 128 || !parseable.contains(name)) {
            throw new JiffException(
                'found unrecognized specifier directive `' + reader.describeCurrent() + '`'
            );
        }
    }

    private void parseDotFraction(JiffStrtimeExtension ext) {
        if (!reader.bump()) {
            throw new JiffException('invalid format string, expected directive after `%.`');
        }
        // A precision may follow the dot; like any width, it is ignored when parsing.
        reader.parseWidth();
        if (reader.f() != 102) {
            throw new JiffException(
                'found unrecognized specifier directive `' +
                    reader.describeCurrent() +
                    '` following `%.`'
            );
        }
        if (ipos >= size || inp.charAt(ipos) != 46) {
            return;
        }
        try {
            ipos++;
            parseFraction();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('%.f failed', e);
        }
    }

    private void parseField(Integer directive, JiffStrtimeExtension ext) {
        switch on directive {
            when 37 {
                // %
                if (inp.charAt(ipos) != 37) {
                    throw new JiffException(
                        'expected to match literal byte `%` from format string, ' +
                            'but found byte `' +
                            JiffFmtUtil.describeLeadByte(inp, ipos) +
                            '` in input'
                    );
                }
                ipos++;
            }
            when 65 {
                // A
                Integer index = parseChoice(
                    JiffFmtUtil.WEEKDAY_NAMES,
                    'unrecognized weekday abbreviation'
                );
                tm = tm.withWeekday(JiffWeekdays.fromSundayZeroOffset(index));
            }
            when 97 {
                // a
                Integer index = parseAbbreviation(
                    JiffFmtUtil.WEEKDAY_NAMES,
                    3,
                    'expected to find weekday abbreviation'
                );
                tm = tm.withWeekday(JiffWeekdays.fromSundayZeroOffset(index));
            }
            when 66 {
                // B
                tm = tm.withMonth(
                    parseChoice(JiffFmtUtil.MONTH_NAMES, 'unrecognized month name') + 1
                );
            }
            when 98, 104 {
                // b, h
                Integer index = parseAbbreviation(
                    JiffFmtUtil.MONTH_NAMES,
                    3,
                    'expected to find month name abbreviation'
                );
                tm = tm.withMonth(index + 1);
            }
            when 67 {
                // C
                Long sign = parseSign();
                Long century = parseNumber(
                    ext,
                    2,
                    '-',
                    0L,
                    99L,
                    'century',
                    'failed to parse year number for century'
                );
                tm = tm.withYear((sign * century * 100).intValue());
            }
            when 68 {
                // D
                parseNested('%m/%d/%y');
            }
            when 100, 101 {
                // d, e
                tm = tm.withDay(
                    parseNumber(ext, 2, '0', 1L, 31L, 'day', 'failed to parse day number')
                        .intValue()
                );
            }
            when 70 {
                // F
                parseNested('%Y-%m-%d');
            }
            when 102, 78 {
                // f, N
                parseFraction();
            }
            when 71 {
                // G
                Long sign = parseSign();
                Long year = parseNumber(
                    ext,
                    4,
                    '0',
                    null,
                    null,
                    null,
                    'failed to parse ISO 8601 week year'
                );
                tm = tm.withIsoWeekYear(
                    checkedYear(sign * year, 'iso-year', 'failed to parse ISO 8601 week year')
                );
            }
            when 103 {
                // g
                tm = tm.withIsoWeekYear(
                    parseTwoDigitYear(ext, 'failed to parse 2-digit ISO 8601 week year')
                );
            }
            when 72, 107 {
                // H, k
                tm = tm.withHour(
                    parseNumber(ext, 2, '0', 0L, 23L, 'hour', 'failed to parse hour number')
                        .intValue()
                );
            }
            when 73, 108 {
                // I, l
                Long hour = parseNumber(
                    ext,
                    2,
                    '0',
                    1L,
                    12L,
                    'hour (12 hour clock)',
                    'failed to parse hour number'
                );
                tm = tm.withHour(hour.intValue());
            }
            when 106 {
                // j
                Long day = parseNumber(
                    ext,
                    3,
                    '0',
                    1L,
                    366L,
                    'day-of-year',
                    'failed to parse day of year number'
                );
                tm = tm.withDayOfYear(day.intValue());
            }
            when 77 {
                // M
                Long minute = parseNumber(
                    ext,
                    2,
                    '0',
                    0L,
                    59L,
                    'minute',
                    'failed to parse minute number'
                );
                tm = tm.withMinute(minute.intValue());
            }
            when 109 {
                // m
                tm = tm.withMonth(
                    parseNumber(ext, 2, '0', 1L, 12L, 'month', 'failed to parse month number')
                        .intValue()
                );
            }
            when 110, 116 {
                // n, t
                skipWhitespace();
            }
            when 80, 112 {
                // P, p
                parseAmPm();
            }
            when 81 {
                // Q
                parseIanaOrOffset(ext.colons() == 1);
            }
            when 82 {
                // R
                parseNested('%H:%M');
            }
            when 83 {
                // S
                parseSecond(ext);
            }
            when 115 {
                // s
                parseTimestamp(ext);
            }
            when 84 {
                // T
                parseNested('%H:%M:%S');
            }
            when 85 {
                // U
                Long week = parseNumber(
                    ext,
                    2,
                    '0',
                    0L,
                    53L,
                    'week-number',
                    'failed to parse Sunday-based week number'
                );
                tm = tm.withSundayBasedWeek(week.intValue());
            }
            when 87 {
                // W
                Long week = parseNumber(
                    ext,
                    2,
                    '0',
                    0L,
                    53L,
                    'week-number',
                    'failed to parse Monday-based week number'
                );
                tm = tm.withMondayBasedWeek(week.intValue());
            }
            when 86 {
                // V
                Long week = parseNumber(
                    ext,
                    2,
                    '0',
                    1L,
                    53L,
                    'iso-week',
                    'failed to parse ISO 8601 week number'
                );
                tm = tm.withIsoWeek(week.intValue());
            }
            when 117, 119 {
                // u, w
                parseWeekdayNumber(ext, directive == 117);
            }
            when 89 {
                // Y
                Long sign = parseSign();
                Long year = parseNumber(ext, 4, '0', null, null, null, 'failed to parse year');
                tm = tm.withYear(checkedYear(sign * year, 'year', 'failed to parse year'));
            }
            when 121 {
                // y
                tm = tm.withYear(parseTwoDigitYear(ext, 'failed to parse 2-digit year'));
            }
            when else {
                // z
                parseOffset(ext.colons());
            }
        }
    }

    // ---- literals and whitespace -----------------------------------------------

    private void parseLiteral() {
        Integer expected = reader.f();
        if (JiffFmtUtil.isAsciiWhitespace(expected)) {
            skipWhitespace();
        } else if (ipos >= size) {
            throw new JiffException(
                'expected to match literal byte `' +
                    reader.describeCurrent() +
                    '` from format string, but found end of input'
            );
        } else if (expected != inp.charAt(ipos)) {
            throw literalMismatch();
        } else {
            ipos++;
        }
        reader.bump();
    }

    // Jiff compares the format and the input byte by byte, so the error names the first byte
    // of UTF-8 where the two characters differ.
    private JiffException literalMismatch() {
        String fmt = reader.text();
        Integer fmtStart = characterStart(fmt, reader.position());
        Integer inputStart = characterStart(inp, ipos);
        List<Integer> expected = JiffFmtUtil.utf8Bytes(fmt, fmtStart);
        List<Integer> found = JiffFmtUtil.utf8Bytes(inp, inputStart);
        Integer index = 0;
        while (
            index < expected.size() - 1 &&
            index < found.size() - 1 &&
            expected.get(index) == found.get(index)
        ) {
            index++;
        }
        return new JiffException(
            'expected to match literal byte `' +
                JiffFmtUtil.describeByte(expected.get(index)) +
                '` from format string, but found byte `' +
                JiffFmtUtil.describeByte(found.get(index)) +
                '` in input'
        );
    }

    // The start of the character that the code unit at `index` belongs to: one code unit back
    // for the second half of a surrogate pair.
    private static Integer characterStart(String text, Integer index) {
        Integer unit = text.charAt(index);
        if (unit >= 56320 && unit <= 57343 && index > 0) {
            Integer previous = text.charAt(index - 1);
            if (previous >= 55296 && previous <= 56319) {
                return index - 1;
            }
        }
        return index;
    }

    private void skipWhitespace() {
        while (ipos < size && JiffFmtUtil.isAsciiWhitespace(inp.charAt(ipos))) {
            ipos++;
        }
    }

    private void parseNested(String fmt) {
        JiffStrtimeParser nested = new JiffStrtimeParser(
            new JiffStrtimeFormatReader(fmt),
            inp,
            ipos,
            tm
        );
        nested.parseAll();
        ipos = nested.ipos;
        tm = nested.tm;
    }

    // ---- numbers ----------------------------------------------------------------

    private Long parseSign() {
        if (ipos < size && inp.charAt(ipos) == 45) {
            ipos++;
            return -1L;
        }
        if (ipos < size && inp.charAt(ipos) == 43) {
            ipos++;
        }
        return 1L;
    }

    /**
     * Reads an unsigned number of at most `defaultWidth` digits, or more when the format gives
     * a larger width with zero padding. With zero padding, leading zeros up to the width do
     * not count against the limit. `defaultFlag` is used when the format has no flag. When
     * `what` is not null the number must be in `min..max`. Errors are prefixed by `context`.
     */
    private Long parseNumber(
        JiffStrtimeExtension ext,
        Integer defaultWidth,
        String defaultFlag,
        Long min,
        Long max,
        String what,
        String context
    ) {
        try {
            Long value = readNumber(ext, defaultWidth, defaultFlag);
            if (min != null && max != null) {
                JiffMath.check(value, min, max, what);
            }
            return value;
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
    }

    private Long readNumber(JiffStrtimeExtension ext, Integer defaultWidth, String defaultFlag) {
        String flag = ext.flag() == null ? defaultFlag : ext.flag();
        Integer zeroPadWidth = 0;
        if (!'_'.equals(flag) && !'-'.equals(flag)) {
            zeroPadWidth = ext.width() == null ? defaultWidth : ext.width();
        }
        Integer maxDigits = Math.max(defaultWidth, zeroPadWidth);
        skipWhitespace();
        Integer digits = 0;
        while (ipos + digits < size && digits < zeroPadWidth && inp.charAt(ipos + digits) == 48) {
            digits++;
        }
        Long value = 0L;
        while (
            ipos + digits < size &&
            digits < maxDigits &&
            JiffFmtUtil.isDigit(inp.charAt(ipos + digits))
        ) {
            Long digit = inp.charAt(ipos + digits) - 48;
            if (JiffMath.greaterThan(value, (JiffMath.LONG_MAX - digit) / 10)) {
                throw new JiffException('number too big to parse into 64-bit integer');
            }
            value = value * 10 + digit;
            digits++;
        }
        if (digits == 0) {
            throw new JiffException('invalid number, no digits found');
        }
        ipos += digits;
        return value;
    }

    private Integer checkedYear(Long year, String what, String context) {
        try {
            return JiffMath.checkInt(year, -9999L, 9999L, what);
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
    }

    // `%y` and `%g`: `69..99` are 1969 to 1999 and `00..68` are 2000 to 2068.
    private Integer parseTwoDigitYear(JiffStrtimeExtension ext, String context) {
        Long year = parseNumber(ext, 2, '0', 0L, 99L, 'year (2 digits)', context);
        return year.intValue() + (year <= 68 ? 2000 : 1900);
    }

    private void parseSecond(JiffStrtimeExtension ext) {
        String context = 'failed to parse second number';
        Long second = parseNumber(ext, 2, '0', null, null, null, context);
        // There are no leap seconds, so `60` is read as `59`.
        if (second == 60) {
            second = 59;
        }
        try {
            JiffMath.check(second, 0L, 59L, 'second');
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
        tm = tm.withSecond(second.intValue());
    }

    private void parseTimestamp(JiffStrtimeExtension ext) {
        String context = 'failed to parse Unix timestamp (in seconds)';
        Long sign = parseSign();
        Long seconds = parseNumber(ext, 19, '_', null, null, null, context);
        try {
            tm = tm.withTimestamp(JiffTimestamp.fromSecond(sign * seconds));
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
    }

    private void parseWeekdayNumber(JiffStrtimeExtension ext, Boolean mondayOne) {
        String context = 'failed to parse weekday number';
        Long value = parseNumber(ext, 1, '-', null, null, null, context);
        // Jiff first narrows the number to an 8 bit integer.
        if (JiffMath.greaterThan(value, 127L)) {
            throw new JiffException(context);
        }
        try {
            tm = tm.withWeekday(
                mondayOne
                    ? JiffWeekdays.fromMondayOneOffset(value.intValue())
                    : JiffWeekdays.fromSundayZeroOffset(value.intValue())
            );
        } catch (JiffException e) {
            throw JiffFmtUtil.context(context, e);
        }
    }

    // `%f` and `%N`, and `%.f` after its dot: one to nine digits of a fraction of a second.
    private void parseFraction() {
        Integer start = ipos;
        while (ipos - start < 9 && ipos < size && JiffFmtUtil.isDigit(inp.charAt(ipos))) {
            ipos++;
        }
        if (ipos == start) {
            throw new JiffException(
                'expected at least one fractional decimal digit, but did not find any'
            );
        }
        String digits = inp.substring(start, ipos).rightPad(9, '0');
        tm = tm.withSubsecNanosecond(Integer.valueOf(digits));
    }

    // ---- names ------------------------------------------------------------------

    // The index of the first of `choices` that the input starts with, ignoring ASCII case.
    private Integer parseChoice(List<String> choices, String context) {
        for (Integer i = 0; i < choices.size(); i++) {
            if (JiffFmtUtil.startsWithIgnoreAsciiCase(inp, ipos, choices.get(i))) {
                ipos += choices.get(i).length();
                return i;
            }
        }
        throw new JiffException(
            context +
                ': failed to find expected value, available choices are: ' +
                String.join(choices, ', ')
        );
    }

    // The index of the name whose first `length` letters the input starts with, ignoring
    // ASCII case. `expected` describes what was looked for.
    private Integer parseAbbreviation(List<String> names, Integer length, String expected) {
        if (JiffFmtUtil.utf8Length(inp, ipos, length) < length) {
            throw new JiffException(
                expected + ', but the remaining input is too short to contain one'
            );
        }
        for (Integer i = 0; i < names.size(); i++) {
            if (
                JiffFmtUtil.startsWithIgnoreAsciiCase(inp, ipos, names.get(i).substring(0, length))
            ) {
                ipos += length;
                return i;
            }
        }
        throw new JiffException(expected);
    }

    private void parseAmPm() {
        Integer index = parseAbbreviation(AMPM, 2, 'expected to find `AM` or `PM`');
        tm = tm.withMeridiem(index == 0 ? JiffMeridiem.AM : JiffMeridiem.PM);
    }

    // ---- time zones -------------------------------------------------------------

    private void parseIanaOrOffset(Boolean colon) {
        if (ipos < size && (inp.charAt(ipos) == 43 || inp.charAt(ipos) == 45)) {
            parseOffset(colon ? 1 : 0);
            return;
        }
        Integer start = ipos;
        parseIanaComponent();
        while (ipos < size && inp.charAt(ipos) == 47) {
            ipos++;
            parseIanaComponent();
        }
        tm = tm.withIanaTimeZone(inp.substring(start, ipos));
    }

    private void parseIanaComponent() {
        String expected = 'expected to find the start of an IANA time zone identifier name or component';
        if (ipos >= size) {
            throw new JiffException(expected + ', but found end of input instead');
        }
        Integer first = inp.charAt(ipos);
        if (first != 95 && first != 46 && !JiffFmtUtil.isAsciiAlphabetic(first)) {
            throw new JiffException(expected);
        }
        ipos++;
        while (ipos < size && isIanaCharacter(inp.charAt(ipos))) {
            ipos++;
        }
    }

    private static Boolean isIanaCharacter(Integer ch) {
        return ch == 95 ||
            ch == 46 ||
            ch == 43 ||
            ch == 45 ||
            JiffFmtUtil.isDigit(ch) ||
            JiffFmtUtil.isAsciiAlphabetic(ch);
    }

    // `%z` (no colons), `%:z`, `%::z` (seconds required) and `%:::z` (minutes optional).
    private void parseOffset(Integer colons) {
        JiffTemporalOffsetParser parser = OFFSET_NO_COLON;
        if (colons == 1) {
            parser = OFFSET_COLON;
        } else if (colons == 2) {
            parser = OFFSET_COLON_SECONDS;
        } else if (colons == 3) {
            parser = OFFSET_COLON_HOURS;
        }
        JiffDurationScanner scanner = new JiffDurationScanner(inp);
        scanner.advance(ipos);
        JiffTemporalParsedOffset parsed = parser.parse(scanner);
        tm = tm.withOffset(parsed.toOffset());
        ipos = scanner.position();
    }
}
