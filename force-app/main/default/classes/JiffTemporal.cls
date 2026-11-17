/**
 * Printing and parsing in the Temporal ISO 8601 / RFC 3339 / RFC 9557 family of formats.
 *
 * This is the format every jiff-force type uses for `toString()` and `parse(String)`. The
 * methods here are the shared implementation behind those; most code should call the methods
 * on the types themselves.
 *
 * Mirrors `jiff::fmt::temporal`.
 */
public class JiffTemporal {
    private static final JiffTemporalPrinter DEFAULT_PRINTER = new JiffTemporalPrinter();

    // ---- datetimes: printing ----------------------------------------------
    //
    // These print with the default options. For lowercase letters, another separator or a
    // fixed precision of fractional seconds, use a `JiffTemporalPrinter`.

    /** Formats a date as `YYYY-MM-DD`. Years before zero are written as `-00YYYY`. */
    public static String printDate(JiffDate value) {
        return DEFAULT_PRINTER.dateToString(value);
    }

    /** Formats a time as `HH:MM:SS`, followed by a fraction only when it is non-zero. */
    public static String printTime(JiffTime value) {
        return DEFAULT_PRINTER.timeToString(value);
    }

    /** Formats a datetime as a date and a time separated by `T`. */
    public static String printDateTime(JiffDateTime value) {
        return DEFAULT_PRINTER.dateTimeToString(value);
    }

    /**
     * Formats an ISO 8601 week date as `YYYY-Www-D`, for example `2024-W10-6`. The weekday is
     * written as a number from `1` (Monday) to `7` (Sunday), and years before zero as
     * `-00YYYY`.
     */
    public static String printIsoWeekDate(JiffIsoWeekDate value) {
        return DEFAULT_PRINTER.isoWeekDateToString(value);
    }

    /**
     * Formats a time zone in the form `parseTimeZone` reads: its IANA name, `Etc/Unknown`, or
     * the offset of a fixed zone as `+HH:MM` (`+HH:MM:SS` when it has seconds).
     */
    public static String printTimeZone(JiffTimeZone zone) {
        return DEFAULT_PRINTER.timeZoneToString(zone);
    }

    /**
     * Formats datetime pieces as a Temporal ISO 8601 string, for example
     * `2025-01-03T07:55:00+02:00[Africa/Cairo]`. See `JiffTemporalPrinter.piecesToString` for
     * how each piece is written.
     */
    public static String printPieces(JiffPieces pieces) {
        return DEFAULT_PRINTER.piecesToString(pieces);
    }

    /**
     * Formats a UTC offset the way RFC 3339 requires inside a timestamp: a sign, two digit
     * hours, a colon and two digit minutes, for example `-05:00` or `+05:30`.
     *
     * RFC 3339 has no room for seconds, so an offset with seconds is rounded to the nearest
     * minute (`-00:44:30` prints as `-00:45`). `JiffOffset.toString()` is the form that keeps
     * them.
     */
    public static String printOffset(JiffOffset offset) {
        Integer magnitude = Math.abs(offset.seconds());
        Integer hours = magnitude / 3600;
        Integer minutes = Math.mod(magnitude / 60, 60);
        if (Math.mod(magnitude, 60) >= 30) {
            minutes++;
            if (minutes == 60) {
                hours++;
                minutes = 0;
                // The largest offset is 25:59:59, which must not round up to 26:00.
                if (hours > 25) {
                    hours = 25;
                    minutes = 59;
                }
            }
        }
        return (offset.isNegative() ? '-' : '+') +
            JiffMath.pad(hours, 2) +
            ':' +
            JiffMath.pad(minutes, 2);
    }

    /** Formats an instant as an RFC 3339 timestamp in UTC, for example `2024-06-19T19:22:45Z`. */
    public static String printTimestamp(JiffTimestamp value) {
        return DEFAULT_PRINTER.timestampToString(value);
    }

    /**
     * Formats an instant as an RFC 3339 timestamp at the given offset, for example
     * `2024-06-19T15:22:45-04:00`. The civil part is what a clock at that offset shows.
     */
    public static String printTimestampWithOffset(JiffTimestamp value, JiffOffset offset) {
        return DEFAULT_PRINTER.timestampWithOffsetToString(value, offset);
    }

    // ---- datetimes: parsing -----------------------------------------------
    //
    // All of these read the same grammar, which `JiffTemporalParser` describes, and differ in
    // which parts of a string they require and which they ignore. They throw `JiffException`
    // with Jiff's wording when the text does not parse.

    /**
     * Parses the components of a datetime string without deciding what they should become: a
     * date, and optionally a time, a UTC offset and a time zone annotation. The other parsing
     * functions here are this followed by one of the conversions on the result.
     *
     * Mirrors `jiff::fmt::temporal::parser::DateTimeParser::parse_temporal_datetime`.
     */
    public static JiffTemporalParsed parseParts(String text) {
        return JiffTemporalParser.parseDateTime(text);
    }

    /**
     * Parses a civil date such as `2024-06-19`.
     *
     * - The basic format without separators is accepted too (`20240619`), but the two styles
     *   may not be mixed.
     * - A year outside `0000..9999` is written with a sign and six digits: `-000044-03-15`.
     * - A full datetime is accepted and everything but its date is ignored, including a
     *   numeric offset and a time zone annotation: `2024-06-19T15:22:45-04:00[America/New_York]`
     *   is `2024-06-19`.
     * - A `Z` offset is rejected. `Z` says the time is in UTC, so the date that was written
     *   may not be the date where the event happened; parse a `JiffTimestamp` and convert it
     *   with a time zone instead.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_date`.
     */
    public static JiffDate parseDate(String text) {
        return JiffTemporalParser.parseDateTime(text).toDate();
    }

    /**
     * Parses a civil datetime such as `2024-06-19T15:22:45` or `2024-06-19 15:22:45.123`.
     *
     * - The date and time are separated by `T`, `t` or a single space.
     * - The time may stop after the hour or the minute (`2024-06-19T15`), and may be written
     *   without colons (`20240619T152245`).
     * - The seconds may have up to nine fractional digits, after `.` or `,`.
     * - A second of `60` (a leap second) is accepted and read as `59`.
     * - A date alone gives midnight.
     * - A numeric offset and a time zone annotation are ignored. A `Z` offset is rejected, for
     *   the reason given under `parseDate`.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_datetime`.
     */
    public static JiffDateTime parseDateTime(String text) {
        return JiffTemporalParser.parseDateTime(text).toDateTime();
    }

    /**
     * Parses a civil time such as `15:22:45`, `15:22`, `15` or `15:22:45.123456789`.
     *
     * - A time may start with the designator `T` or `t`.
     * - A full datetime is accepted and its date is ignored, but a date without a time is
     *   rejected.
     * - A time without colons (`1522`) is accepted only when it could not also be a date. The
     *   string `1214` could mean 12:14 or December 14th and `202012` could mean 20:20:12 or
     *   December 2020, so both are rejected; `T1214` and `12:14` are not ambiguous.
     * - A numeric offset and annotations are ignored, and a `Z` offset is rejected.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_time`.
     */
    public static JiffTime parseTime(String text) {
        return JiffTemporalParser.parseTime(text);
    }

    /**
     * Parses an instant from an RFC 3339 timestamp such as `2024-06-19T19:22:45Z` or
     * `2024-06-19T15:22:45-04:00`.
     *
     * - A time and an offset are both required: without them the string does not identify an
     *   instant.
     * - The offset is `Z` (or `z`) or numeric: `-04`, `-04:00`, `-0400`, `+05:30:15`. An
     *   offset may have seconds and even a fraction of a second, which is rounded to the
     *   nearest second. `-00:00` is the same as `Z`.
     * - A time zone annotation may follow (`[America/New_York]`), and is ignored: the offset
     *   alone decides the instant, even when it is not an offset that zone ever uses. Parse a
     *   zoned datetime when the zone's rules should be applied.
     * - Other annotations, such as `[u-ca=gregory]`, are checked for syntax and ignored,
     *   unless they are marked critical (`[!u-ca=gregory]`), which is an error.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_timestamp`.
     */
    public static JiffTimestamp parseTimestamp(String text) {
        return JiffTemporalParser.parseDateTime(text).toTimestamp();
    }

    /**
     * Parses an ISO 8601 week date such as `2024-W10-6`: a week year, `W` and a two digit
     * week number, and the day of the week as a digit from `1` (Monday) to `7` (Sunday).
     *
     * The `W` may be lowercase and the hyphens may be left out (`2024W106`). The year follows
     * the same rules as in `parseDate`.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_iso_week_date`.
     */
    public static JiffIsoWeekDate parseIsoWeekDate(String text) {
        return JiffTemporalParser.parseIsoWeekDate(text);
    }

    /**
     * Parses a time zone: an IANA name such as `America/New_York` or `UTC`, or a UTC offset
     * such as `-05:00`, `+0530` or `+05:30:15`, which gives a fixed offset zone. This reads
     * what `printTimeZone` writes.
     *
     * Jiff also accepts POSIX TZ strings here (`EST5EDT,M3.2.0,M11.1.0`). This port has no
     * POSIX time zones, so such a string is looked up as a name and fails. Names are matched
     * as `JiffTimeZone.get` matches them, which is case sensitive.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_time_zone`.
     */
    public static JiffTimeZone parseTimeZone(String text) {
        return JiffTemporalParser.parseTimeZone(text);
    }

    /**
     * Parses a datetime string into its pieces, with nothing required but the date and
     * nothing ignored. See `JiffPieces`.
     *
     * Mirrors `jiff::fmt::temporal::DateTimeParser::parse_pieces`.
     */
    public static JiffPieces parsePieces(String text) {
        return JiffTemporalParser.parseDateTime(text).toPieces();
    }

    // ---- durations: printing ----------------------------------------------

    /**
     * Formats a duration as an ISO 8601 duration with hours as the largest unit, for example
     * `PT2H30M`, `-PT1.5S` or `PT0S`.
     */
    public static String printDuration(JiffSignedDuration duration) {
        // Work on the components separately and negate each one, so that the most negative
        // duration (whose seconds have no positive counterpart) still prints.
        Long secs = duration.asSecs();
        Integer nanos = duration.subsecNanos();
        String out = duration.isNegative() ? '-PT' : 'PT';
        Boolean atLeastAMinute = secs >= 60 || secs <= -60;
        Long seconds = JiffMath.abs(JiffMath.truncMod(secs, 60L));
        if (atLeastAMinute) {
            Long hours = secs / 3600L;
            Long minutes = JiffMath.abs(JiffMath.truncMod(secs, 3600L) / 60L);
            if (hours != 0) {
                // Negate after dividing: the quotient always has a positive counterpart.
                out += (hours < 0 ? -hours : hours) + 'H';
            }
            if (minutes != 0) {
                out += minutes + 'M';
            }
        }
        if (!atLeastAMinute || seconds != 0 || nanos != 0) {
            out += String.valueOf(seconds);
            if (nanos != 0) {
                out += '.' + fraction(nanos < 0 ? -nanos : nanos);
            }
            out += 'S';
        }
        return out;
    }

    /**
     * Formats a span as an ISO 8601 duration, for example `P1Y2M3DT4H5M6.5S`, `-P1W` or `PT0S`.
     *
     * Units that are zero are omitted. Milliseconds, microseconds and nanoseconds have no
     * designator in ISO 8601, so they are folded into a fractional number of seconds.
     */
    public static String printSpan(JiffSpan span) {
        String out = span.isNegative() ? '-P' : 'P';
        if (span.hasUnit(JiffUnit.YEAR)) {
            out += span.getAbs(JiffUnit.YEAR) + 'Y';
        }
        if (span.hasUnit(JiffUnit.MONTH)) {
            out += span.getAbs(JiffUnit.MONTH) + 'M';
        }
        if (span.hasUnit(JiffUnit.WEEK)) {
            out += span.getAbs(JiffUnit.WEEK) + 'W';
        }
        if (span.hasUnit(JiffUnit.DAY)) {
            out += span.getAbs(JiffUnit.DAY) + 'D';
        }
        if (!span.hasTimeUnits()) {
            return span.hasCalendarUnits() ? out : out + 'T0S';
        }
        out += 'T';
        if (span.hasUnit(JiffUnit.HOUR)) {
            out += span.getAbs(JiffUnit.HOUR) + 'H';
        }
        if (span.hasUnit(JiffUnit.MINUTE)) {
            out += span.getAbs(JiffUnit.MINUTE) + 'M';
        }
        if (span.hasFractionalSeconds()) {
            Long millis = span.getAbs(JiffUnit.MILLISECOND);
            Long micros = span.getAbs(JiffUnit.MICROSECOND);
            Long nanos = span.getAbs(JiffUnit.NANOSECOND);
            Long subsec =
                JiffMath.truncMod(millis, 1000L) * 1000000L +
                JiffMath.truncMod(micros, 1000000L) * 1000L +
                JiffMath.truncMod(nanos, 1000000000L);
            Long secs =
                span.getAbs(JiffUnit.SECOND) +
                millis / 1000L +
                micros / 1000000L +
                nanos / 1000000000L +
                subsec / 1000000000L;
            subsec = JiffMath.truncMod(subsec, 1000000000L);
            out += String.valueOf(secs);
            if (subsec != 0) {
                out += '.' + fraction(subsec.intValue());
            }
            out += 'S';
        } else if (span.hasUnit(JiffUnit.SECOND)) {
            out += span.getAbs(JiffUnit.SECOND) + 'S';
        }
        return out;
    }

    /** Nine fractional digits with trailing zeros removed. `nanos` must be in `1..999999999`. */
    public static String fraction(Integer nanos) {
        String digits = String.valueOf(nanos).leftPad(9, '0');
        Integer endIndex = digits.length();
        while (endIndex > 1 && digits.charAt(endIndex - 1) == 48) {
            endIndex--;
        }
        return digits.substring(0, endIndex);
    }

    // ---- ISO 8601 durations: parsing and lowercase printing ----------------

    /**
     * Parses an ISO 8601 duration such as `P1Y2M3DT4H5M6.5S` into a span.
     *
     * - The duration starts with `P`, optionally after a `+` or `-` sign. Years, months,
     *   weeks and days come first, then `T` and the hours, minutes and seconds. Units must be
     *   in that order and each may appear once.
     * - Designators may be lowercase (`p1y2m3dt4h5m6.5s`), an extension to ISO 8601.
     * - The last time unit may have a fraction of up to nine digits, after `.` or `,`. A
     *   fraction of an hour or minute is carried into the smaller units, so `PT1.5H` is one
     *   hour and thirty minutes; a fraction of a second becomes milliseconds, microseconds and
     *   nanoseconds.
     * - Each unit is kept as written, so `PT90M` is ninety minutes. A time unit that is too
     *   large for a span spills over into the smaller units rather than failing.
     *
     * Throws `JiffException` when the text is not an ISO 8601 duration or does not fit in a
     * span.
     *
     * Mirrors `jiff::fmt::temporal::SpanParser::parse_span`.
     */
    public static JiffSpan parseSpan(String text) {
        JiffDurationScanner scanner = new JiffDurationScanner(text);
        JiffDurationUnits units = new JiffDurationUnits();
        Integer sign = isoDurationSign(scanner);
        isoDurationDesignator(scanner);
        isoDateUnits(scanner, units);
        if (scanner.eatEither(84, 116)) {
            isoTimeUnits(scanner, units);
        }
        units.setSign(sign);
        JiffSpan span = units.toSpan();
        scanner.finish(printSpan(span));
        return span;
    }

    /**
     * Parses an ISO 8601 duration such as `PT2H30M` or `-PT1.5S` into a signed duration.
     *
     * The syntax is that of `parseSpan`, except that only the time part is allowed: the text
     * must contain `T`, and must not contain years, months, weeks or days, because those have
     * no fixed length. Throws `JiffException` otherwise, or when the total overflows.
     *
     * Mirrors `jiff::fmt::temporal::SpanParser::parse_duration`.
     */
    public static JiffSignedDuration parseDuration(String text) {
        JiffDurationScanner scanner = new JiffDurationScanner(text);
        JiffDurationUnits units = new JiffDurationUnits();
        Integer sign = isoDurationSign(scanner);
        isoDurationDesignator(scanner);
        if (!scanner.eatEither(84, 116)) {
            throw new JiffException(
                'parsing ISO 8601 duration in this context requires that the duration ' +
                'contain a time component and no components of days or greater'
            );
        }
        isoTimeUnits(scanner, units);
        units.setSign(sign);
        JiffSignedDuration duration = units.toSignedDuration();
        scanner.finish(printDuration(duration));
        return duration;
    }

    /**
     * Formats a span as an ISO 8601 duration, with lowercase unit designators when `lowercase`
     * is true: `P5y10dT1h` rather than `P5Y10DT1H`. The `P` and `T` stay uppercase.
     *
     * Lowercase designators are easier to read, but they are an extension to ISO 8601 that
     * not every parser accepts. `parseSpan` does.
     *
     * Mirrors `jiff::fmt::temporal::SpanPrinter::lowercase`.
     */
    public static String printSpan(JiffSpan span, Boolean lowercase) {
        return lowercase ? isoLowercaseDesignators(printSpan(span)) : printSpan(span);
    }

    /**
     * Formats a signed duration as an ISO 8601 duration, with lowercase unit designators when
     * `lowercase` is true: `PT2h30m` rather than `PT2H30M`.
     *
     * Mirrors `jiff::fmt::temporal::SpanPrinter::lowercase`.
     */
    public static String printDuration(JiffSignedDuration duration, Boolean lowercase) {
        String printed = printDuration(duration);
        return lowercase ? isoLowercaseDesignators(printed) : printed;
    }

    /** Lowercases every letter of a printed duration except the `P` and `T` markers. */
    private static String isoLowercaseDesignators(String printed) {
        return printed.toLowerCase().replace('p', 'P').replace('t', 'T');
    }

    /** Consumes an optional `+` or `-` and returns the sign it stands for. */
    private static Integer isoDurationSign(JiffDurationScanner scanner) {
        if (scanner.eat(45)) {
            return -1;
        }
        scanner.eat(43);
        return 1;
    }

    /** Consumes the `P` (or `p`) every ISO 8601 duration starts with. */
    private static void isoDurationDesignator(JiffDurationScanner scanner) {
        if (scanner.eatEither(80, 112)) {
            return;
        }
        throw new JiffException(
            'expected to find duration beginning with `P` or `p`, ' + isoFound(scanner)
        );
    }

    /** Parses the years, months, weeks and days of a duration. */
    private static void isoDateUnits(JiffDurationScanner scanner, JiffDurationUnits units) {
        JiffI128 value = scanner.unitValue();
        while (value != null) {
            Integer designator = scanner.peek();
            JiffUnit unit;
            if (designator == 89 || designator == 121) {
                unit = JiffUnit.YEAR;
            } else if (designator == 77 || designator == 109) {
                unit = JiffUnit.MONTH;
            } else if (designator == 87 || designator == 119) {
                unit = JiffUnit.WEEK;
            } else if (designator == 68 || designator == 100) {
                unit = JiffUnit.DAY;
            } else {
                throw new JiffException(
                    'expected to find date unit designator suffix (`Y`, `M`, `W` or `D`), ' +
                    isoFound(scanner)
                );
            }
            scanner.advance(1);
            units.setUnitValue(unit, value);
            value = scanner.unitValue();
        }
    }

    /**
     * Parses the hours, minutes and seconds of a duration, which follow the `T`. At least one
     * of them must be present.
     */
    private static void isoTimeUnits(JiffDurationScanner scanner, JiffDurationUnits units) {
        JiffI128 value = scanner.unitValue();
        while (value != null) {
            Integer fraction = scanner.fraction();
            Integer designator = scanner.peek();
            JiffUnit unit;
            if (designator == 72 || designator == 104) {
                unit = JiffUnit.HOUR;
            } else if (designator == 77 || designator == 109) {
                unit = JiffUnit.MINUTE;
            } else if (designator == 83 || designator == 115) {
                unit = JiffUnit.SECOND;
            } else {
                throw new JiffException(
                    'expected to find time unit designator suffix (`H`, `M` or `S`), ' +
                    isoFound(scanner)
                );
            }
            scanner.advance(1);
            units.setUnitValue(unit, value);
            if (fraction >= 0) {
                // A fraction is only allowed on the last unit.
                units.setFraction(fraction);
                break;
            }
            value = scanner.unitValue();
        }
        if (units.getMin() == null || units.getMin().ordinal() > JiffUnit.HOUR.ordinal()) {
            throw new JiffException(
                'found a time designator (`T` or `t`) in an ISO 8601 duration string, ' +
                'but did not find any time units'
            );
        }
    }

    /** The end of an error about an unexpected character, or about the input ending. */
    private static String isoFound(JiffDurationScanner scanner) {
        return scanner.isDone()
            ? 'but found end of input'
            : 'but found `' + scanner.describeNext() + '` instead';
    }
}
