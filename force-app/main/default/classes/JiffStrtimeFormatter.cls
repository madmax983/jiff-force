/**
 * The `strftime` side of `JiffStrtime`: writes a `JiffBrokenDownTime` according to a format
 * string. Internal: use `JiffBrokenDownTime.format`, `JiffStrtime.format` or the `strftime`
 * methods of the datetime types.
 *
 * Literal text is copied as it is. After each `%` comes an optional flag, width and colons
 * (read by `JiffStrtimeFormatReader`) and then the directive. Each directive takes what it
 * needs from the broken down time, falling back to the date assembled from it where Jiff does,
 * and fails with Jiff's wording when the value is not there: `%H failed: requires time to
 * format`.
 *
 * In lenient mode a directive that fails is written out literally, starting from its `%`;
 * anything it had already written stays, exactly as in Jiff.
 *
 * Mirrors `jiff::fmt::strtime::printer::Formatter`.
 */
public class JiffStrtimeFormatter {
    private static final Integer CASE_AS_IS = 0;
    private static final Integer CASE_UPPER = 1;
    private static final Integer CASE_LOWER = 2;
    // Jiff clamps padding to the length of the longest 64 bit integer.
    private static final Integer MAX_PAD = 20;
    private static final String KNOWN_DIRECTIVES = '%AaBbCcDdeFfGgHhIjklMmNnPpQqRrSsTtUuVWwXxYyZz';

    private static final String REQUIRES_DATE = 'requires date to format';
    private static final String REQUIRES_TIME = 'requires time to format';
    private static final String REQUIRES_OFFSET = 'requires time zone offset';
    private static final String REQUIRES_INSTANT = 'requires instant (a timestamp or a date, time and offset)';

    private final JiffStrtimeConfig config;
    private final JiffStrtimeFormatReader reader;
    private final JiffBrokenDownTime tm;
    private final List<String> out = new List<String>();

    private JiffStrtimeFormatter(
        JiffStrtimeConfig config,
        JiffStrtimeFormatReader reader,
        JiffBrokenDownTime tm
    ) {
        this.config = config;
        this.reader = reader;
        this.tm = tm;
    }

    /**
     * Formats `tm` according to `fmt`. Throws, with the message prefixed by `strftime
     * formatting failed`, when the format is invalid or asks for something `tm` lacks, unless
     * `config` is lenient.
     */
    public static String format(JiffStrtimeConfig config, String fmt, JiffBrokenDownTime tm) {
        if (config == null || tm == null) {
            throw new JiffException('strftime needs a configuration and a broken down time');
        }
        JiffStrtimeFormatter formatter = new JiffStrtimeFormatter(
            config,
            new JiffStrtimeFormatReader(fmt),
            tm
        );
        try {
            formatter.run();
        } catch (JiffException e) {
            throw JiffFmtUtil.context('strftime formatting failed', e);
        }
        return String.join(formatter.out, '');
    }

    private void run() {
        String text = reader.text();
        while (!reader.isDone()) {
            Integer start = reader.position();
            Integer percent = text.indexOf('%', start);
            if (percent != start) {
                Integer stop = percent < 0 ? text.length() : percent;
                out.add(text.substring(start, stop));
                reader.rewind(stop);
                continue;
            }
            if (!reader.bump()) {
                if (config.isLenient()) {
                    out.add('%');
                    break;
                }
                throw new JiffException(
                    'invalid format string, expected byte after `%`, ' +
                    'but found end of format string'
                );
            }
            Integer afterPercent = reader.position();
            try {
                formatOne(reader.parseExtension());
            } catch (JiffException e) {
                if (!config.isLenient()) {
                    throw e;
                }
                // Write the `%` and go on with what follows it as literal text.
                out.add('%');
                reader.rewind(afterPercent);
            }
        }
    }

    private void formatOne(JiffStrtimeExtension ext) {
        Integer directive = reader.f();
        if (directive == 46) {
            formatDotFraction(ext);
            reader.bump();
            return;
        }
        String name = reader.text().substring(reader.position(), reader.position() + 1);
        if (directive >= 128 || !KNOWN_DIRECTIVES.contains(name)) {
            throw new JiffException(
                'found unrecognized specifier directive `' + reader.describeCurrent() + '`'
            );
        }
        if (directive == 81 && ext.colons() > 1) {
            throw new JiffException('invalid number of `:` in `%Q` directive');
        }
        try {
            formatDirective(directive, ext);
        } catch (JiffException e) {
            throw JiffFmtUtil.context(failureName(name, ext), e);
        }
        reader.bump();
    }

    // The name Jiff gives a failed directive. `%I` reports itself as `%H` and `%h` as `%b`,
    // as Jiff does.
    private static String failureName(String name, JiffStrtimeExtension ext) {
        String colons = '';
        if (name.equals('z') || name.equals('Q')) {
            colons = ':'.repeat(ext.colons());
        } else if (name.equals('I')) {
            name = 'H';
        } else if (name.equals('h')) {
            name = 'b';
        }
        return '%' + colons + name + ' failed';
    }

    private void formatDotFraction(JiffStrtimeExtension ext) {
        if (!reader.bump()) {
            throw new JiffException('invalid format string, expected directive after `%.`');
        }
        // A precision after the dot replaces any width before it.
        JiffStrtimeExtension precision = ext.withWidth(reader.parseWidth());
        if (reader.f() != 102) {
            throw new JiffException(
                'found unrecognized specifier directive `' +
                    reader.describeCurrent() +
                    '` following `%.`'
            );
        }
        Integer subsec = tm.subsecNanosecond();
        Integer width = precision.width();
        if (subsec == null || (width == null && subsec == 0) || (width != null && width == 0)) {
            return;
        }
        out.add('.');
        writeFraction(width, subsec);
    }

    private void formatDirective(Integer directive, JiffStrtimeExtension ext) {
        switch on directive {
            when 37 {
                // %
                writeStr(ext, CASE_AS_IS, '%');
            }
            when 65 {
                // A
                writeStr(ext, CASE_AS_IS, JiffFmtUtil.weekdayName(weekday()));
            }
            when 97 {
                // a
                writeStr(ext, CASE_AS_IS, JiffFmtUtil.weekdayAbbreviation(weekday()));
            }
            when 66 {
                // B
                writeStr(ext, CASE_AS_IS, JiffFmtUtil.monthName(month()));
            }
            when 98, 104 {
                // b, h
                writeStr(ext, CASE_AS_IS, JiffFmtUtil.monthAbbreviation(month()));
            }
            when 67 {
                // C
                writeInt(ext, ' ', 0, year() / 100);
            }
            when 99 {
                // c
                writeCustom(config.getCustom().formatDateTime(config, ext, tm));
            }
            when 68 {
                // D
                formatAmericanDate();
            }
            when 100 {
                // d
                writeInt(ext, '0', 2, day());
            }
            when 101 {
                // e
                writeInt(ext, ' ', 2, day());
            }
            when 70 {
                // F
                formatIsoDate();
            }
            when 102 {
                // f
                formatFraction(ext);
            }
            when 71 {
                // G
                writeInt(ext, '0', 4, isoWeekYear());
            }
            when 103 {
                // g
                writeInt(ext, '0', 2, JiffMath.truncMod(isoWeekYear(), 100L));
            }
            when 72 {
                // H
                writeInt(ext, '0', 2, hour());
            }
            when 73 {
                // I
                writeInt(ext, '0', 2, hour12());
            }
            when 106 {
                // j
                writeInt(ext, '0', 3, dayOfYear());
            }
            when 107 {
                // k
                writeInt(ext, ' ', 2, hour());
            }
            when 108 {
                // l
                writeInt(ext, ' ', 2, hour12());
            }
            when 77 {
                // M
                writeInt(ext, '0', 2, required(tm.minute(), REQUIRES_TIME));
            }
            when 109 {
                // m
                writeInt(ext, '0', 2, month());
            }
            when 78 {
                // N
                formatNanoseconds(ext);
            }
            when 110 {
                // n
                writeStr(ext, CASE_AS_IS, '\n');
            }
            when 80 {
                // P
                writeStr(ext, CASE_AS_IS, meridiem() == JiffMeridiem.AM ? 'am' : 'pm');
            }
            when 112 {
                // p
                Boolean lower = '#'.equals(ext.flag());
                String marker = meridiem() == JiffMeridiem.AM ? 'AM' : 'PM';
                writeStr(ext, CASE_AS_IS, lower ? marker.toLowerCase() : marker);
            }
            when 81 {
                // Q
                formatIana(ext.colons() == 1);
            }
            when 113 {
                // q
                writeInt(ext, '0', 0, (month() - 1) / 3 + 1);
            }
            when 82 {
                // R
                formatClock(false);
            }
            when 114 {
                // r
                writeCustom(config.getCustom().format12HourTime(config, ext, tm));
            }
            when 83 {
                // S
                writeInt(ext, '0', 2, required(tm.second(), REQUIRES_TIME));
            }
            when 115 {
                // s
                writeInt(ext, ' ', 0, instant().asSecond());
            }
            when 84 {
                // T
                formatClock(true);
            }
            when 116 {
                // t
                writeStr(ext, CASE_AS_IS, '\t');
            }
            when 85 {
                // U
                writeInt(ext, '0', 2, weekNumber(tm.sundayBasedWeek(), true));
            }
            when 117 {
                // u
                writeInt(ext, ' ', 0, JiffWeekdays.toMondayOneOffset(weekday()));
            }
            when 86 {
                // V
                writeInt(ext, '0', 2, isoWeek());
            }
            when 87 {
                // W
                writeInt(ext, '0', 2, weekNumber(tm.mondayBasedWeek(), false));
            }
            when 119 {
                // w
                writeInt(ext, ' ', 0, JiffWeekdays.toSundayZeroOffset(weekday()));
            }
            when 88 {
                // X
                writeCustom(config.getCustom().formatTime(config, ext, tm));
            }
            when 120 {
                // x
                writeCustom(config.getCustom().formatDate(config, ext, tm));
            }
            when 89 {
                // Y
                writeInt(ext, '0', 4, year());
            }
            when 121 {
                // y
                writeInt(ext, '0', 2, JiffMath.truncMod(year(), 100L));
            }
            when 90 {
                // Z
                formatAbbreviation(ext);
            }
            when else {
                // z
                formatOffset(ext.colons());
            }
        }
    }

    // ---- compound directives --------------------------------------------------

    private void formatAmericanDate() {
        out.add(JiffMath.pad(month(), 2));
        out.add('/');
        out.add(JiffMath.pad(day(), 2));
        out.add('/');
        Long year2 = JiffMath.truncMod(year(), 100L);
        if (year2 < 0) {
            out.add('-');
        }
        out.add(JiffMath.pad(Math.abs(year2), 2));
    }

    private void formatIsoDate() {
        Integer yearValue = year();
        if (yearValue < 0) {
            out.add('-');
        }
        out.add(JiffMath.pad(Math.abs(yearValue), 4));
        out.add('-');
        out.add(JiffMath.pad(month(), 2));
        out.add('-');
        out.add(JiffMath.pad(day(), 2));
    }

    private void formatClock(Boolean withSeconds) {
        out.add(JiffMath.pad(hour(), 2));
        out.add(':');
        out.add(JiffMath.pad(required(tm.minute(), REQUIRES_TIME), 2));
        if (withSeconds) {
            out.add(':');
            out.add(JiffMath.pad(required(tm.second(), REQUIRES_TIME), 2));
        }
    }

    private void formatFraction(JiffStrtimeExtension ext) {
        Integer subsec = required(tm.subsecNanosecond(), REQUIRES_TIME);
        Integer width = ext.width();
        if (width != null && width == 0) {
            throw new JiffException('zero precision with %f is not allowed');
        }
        if (subsec == 0 && width == null) {
            writeStr(ext, CASE_AS_IS, '0');
            return;
        }
        writeFraction(width, subsec);
    }

    private void formatNanoseconds(JiffStrtimeExtension ext) {
        Integer subsec = required(tm.subsecNanosecond(), REQUIRES_TIME);
        Integer width = ext.width();
        if (width != null && width == 0) {
            throw new JiffException('zero precision with %N is not allowed');
        }
        writeFraction(width == null ? 9 : width, subsec);
    }

    private void formatIana(Boolean colon) {
        String iana = tm.ianaTimeZone();
        if (iana != null) {
            out.add(iana);
            return;
        }
        JiffOffset offset = tm.offset();
        if (offset == null) {
            throw new JiffException(
                'requires IANA time zone identifier or time zone offset, ' +
                'but neither were present'
            );
        }
        writeOffset(offset, colon, true, false);
    }

    private void formatOffset(Integer colons) {
        JiffOffset offset = tm.offset();
        if (offset == null) {
            throw new JiffException(REQUIRES_OFFSET);
        }
        writeOffset(offset, colons > 0, colons < 3, colons == 2);
    }

    private void formatAbbreviation(JiffStrtimeExtension ext) {
        JiffTimeZone zone = tm.timeZoneForAbbreviation();
        if (zone == null) {
            throw new JiffException('requires IANA time zone identifier');
        }
        writeStr(ext, CASE_UPPER, zone.toOffsetInfo(instant()).abbreviation());
    }

    private void writeCustom(String text) {
        if (text != null) {
            out.add(text);
        }
    }

    // ---- values -----------------------------------------------------------------

    private static Integer required(Integer value, String message) {
        if (value == null) {
            throw new JiffException(message);
        }
        return value;
    }

    // The date assembled from the broken down time, or null when there is none.
    private JiffDate assembledDate() {
        try {
            return tm.toDate();
        } catch (JiffException e) {
            return null;
        }
    }

    private Integer year() {
        Integer value = tm.year();
        if (value != null) {
            return value;
        }
        return dateOrFail().year();
    }

    private Integer month() {
        Integer value = tm.month();
        if (value != null) {
            return value;
        }
        return dateOrFail().month();
    }

    private Integer day() {
        Integer value = tm.day();
        if (value != null) {
            return value;
        }
        return dateOrFail().day();
    }

    private Integer dayOfYear() {
        Integer value = tm.dayOfYear();
        if (value != null) {
            return value;
        }
        return dateOrFail().dayOfYear();
    }

    private Integer isoWeekYear() {
        Integer value = tm.isoWeekYear();
        if (value != null) {
            return value;
        }
        return dateOrFail().toIsoWeekDate().year();
    }

    private Integer isoWeek() {
        Integer value = tm.isoWeek();
        if (value != null) {
            return value;
        }
        return dateOrFail().toIsoWeekDate().week();
    }

    private JiffWeekday weekday() {
        JiffWeekday value = tm.weekday();
        if (value != null) {
            return value;
        }
        return dateOrFail().weekday();
    }

    private JiffDate dateOrFail() {
        JiffDate value = assembledDate();
        if (value == null) {
            throw new JiffException(REQUIRES_DATE);
        }
        return value;
    }

    private Integer hour() {
        return required(tm.hour(), REQUIRES_TIME);
    }

    private Integer hour12() {
        Integer value = hour();
        if (value == 0) {
            return 12;
        }
        return value > 12 ? value - 12 : value;
    }

    private JiffMeridiem meridiem() {
        JiffMeridiem value = tm.meridiem();
        if (value != null) {
            return value;
        }
        return hour() < 12 ? JiffMeridiem.AM : JiffMeridiem.PM;
    }

    private JiffTimestamp instant() {
        try {
            return tm.toTimestamp();
        } catch (JiffException e) {
            throw new JiffException(REQUIRES_INSTANT);
        }
    }

    // `%U` (Sunday based) or `%W` (Monday based): an explicitly set week number, or one
    // computed from the day of the year and the weekday.
    private Integer weekNumber(Integer explicit, Boolean sundayBased) {
        if (explicit != null) {
            return explicit;
        }
        Integer dayOfYearValue = dayOfYear();
        Integer sundayZero = JiffWeekdays.toSundayZeroOffset(weekday());
        if (sundayBased) {
            return (dayOfYearValue + 6 - sundayZero) / 7;
        }
        return (dayOfYearValue + 6 - Math.mod(sundayZero + 6, 7)) / 7;
    }

    // ---- writing ----------------------------------------------------------------

    // Writes a string in its default case, unless the `^` or `#` flag changes it.
    private void writeStr(JiffStrtimeExtension ext, Integer defaultCase, String text) {
        String flag = ext.flag();
        Integer textCase = defaultCase;
        if ('^'.equals(flag)) {
            textCase = CASE_UPPER;
        } else if ('#'.equals(flag)) {
            textCase = defaultCase == CASE_UPPER
                ? CASE_LOWER
                : defaultCase == CASE_LOWER ? CASE_UPPER : CASE_AS_IS;
        }
        if (textCase == CASE_UPPER) {
            out.add(JiffFmtUtil.toAsciiUpperCase(text));
        } else if (textCase == CASE_LOWER) {
            out.add(JiffFmtUtil.toAsciiLowerCase(text));
        } else {
            out.add(text);
        }
    }

    // Writes a number padded to the default width with the default padding character,
    // unless the flag or width of the extension say otherwise.
    private void writeInt(
        JiffStrtimeExtension ext,
        String defaultPad,
        Integer defaultWidth,
        Long numberValue
    ) {
        String flag = ext.flag();
        String pad = defaultPad;
        if ('0'.equals(flag)) {
            pad = '0';
        } else if ('_'.equals(flag)) {
            pad = ' ';
        }
        Integer width = defaultWidth;
        if ('-'.equals(flag)) {
            width = 0;
        } else if (ext.width() != null) {
            width = ext.width();
        }
        Long magnitude = numberValue;
        if (numberValue < 0) {
            magnitude = -numberValue;
            if (width > 0) {
                writeNegativeInt(pad, width, magnitude);
                return;
            }
            out.add('-');
        }
        out.add(padded(magnitude, pad, width));
    }

    // A negative number with a width: the sign counts towards the width. Spaces go before the
    // sign and zeros after it.
    private void writeNegativeInt(String pad, Integer width, Long magnitude) {
        Integer rest = width - 1;
        if (' '.equals(pad)) {
            Integer digits = String.valueOf(magnitude).length();
            if (rest > digits) {
                out.add(' '.repeat(rest - digits));
            }
            rest = 0;
        }
        out.add('-');
        out.add(padded(magnitude, pad, rest));
    }

    private static String padded(Long magnitude, String pad, Integer width) {
        return String.valueOf(magnitude).leftPad(Math.min(width, MAX_PAD), pad);
    }

    // The first `precision` digits of a nine digit fraction, or, without a precision, all of
    // them up to the last that is not zero.
    private void writeFraction(Integer precision, Integer subsec) {
        String digits = String.valueOf(subsec).leftPad(9, '0');
        Integer stop = 9;
        if (precision != null) {
            stop = Math.min(precision, 9);
        } else {
            while (stop > 0 && digits.charAt(stop - 1) == 48) {
                stop--;
            }
        }
        out.add(digits.substring(0, stop));
    }

    // `+HHMM`, `+HH:MM`, `+HH:MM:SS` or `+HH`: the minutes are written when `minute` is true
    // or they (or the seconds) are not zero, and the seconds when `second` is true or they
    // are not zero.
    private void writeOffset(JiffOffset offset, Boolean colon, Boolean minute, Boolean second) {
        Integer total = Math.abs(offset.seconds());
        Integer hours = total / 3600;
        Integer minutes = Math.mod(total / 60, 60);
        Integer seconds = Math.mod(total, 60);
        String separator = colon ? ':' : '';
        out.add(offset.isNegative() ? '-' : '+');
        out.add(JiffMath.pad(hours, 2));
        if (minute || minutes != 0 || seconds != 0) {
            out.add(separator + JiffMath.pad(minutes, 2));
            if (second || seconds != 0) {
                out.add(separator + JiffMath.pad(seconds, 2));
            }
        }
    }
}
