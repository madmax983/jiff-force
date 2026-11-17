/**
 * A printer for dates, times, datetimes, timestamps and time zones in the Temporal ISO 8601 /
 * RFC 3339 / RFC 9557 format, with options.
 *
 * `toString()` on each type prints with the default options. Use this class when the output
 * needs to differ:
 *
 *     JiffTemporalPrinter printer = new JiffTemporalPrinter().precision(3).separator(' ');
 *     printer.timestampToString(JiffTimestamp.fromMillisecond(1720493204500L));
 *     // 2024-07-09 02:46:44.500Z
 *
 * The options:
 *
 * - `lowercase(true)` writes the letters of the format in lowercase: the separator between a
 *   date and a time (`t`), the Zulu designator (`z`) and the week prefix of an ISO week date
 *   (`w`). Time zone names are not changed. Off by default.
 * - `separator(' ')` sets the character between a date and a time. The default is `T`. RFC
 *   3339 also permits a space; anything else may not parse again.
 * - `precision(n)` writes exactly `n` digits of fractional seconds, `0` to `9`, truncating
 *   (never rounding) or padding with zeros as needed. `precision(null)`, the default, writes
 *   as many digits as the value needs and none when the fraction is zero.
 *
 * A printer is an immutable value: each option method returns a new printer, so one can be
 * built once, kept in a static field and shared.
 *
 * Printing a zoned datetime is out of this class's hands until `JiffZonedDateTime` exists.
 *
 * Mirrors `jiff::fmt::temporal::DateTimePrinter`. Jiff's `print_*` methods write to a buffer;
 * here only the `*_to_string` forms exist.
 */
public class JiffTemporalPrinter {
    private static final Integer MAX_PRECISION = 9;
    // Stands for "as many digits as the value needs".
    private static final Integer AUTO_PRECISION = -1;

    private final Boolean lowercaseLetters;
    // The separator as a character code.
    private final Integer separatorChar;
    private final Integer precisionDigits;

    /** A printer with the default options: uppercase, `T` separator, automatic precision. */
    public JiffTemporalPrinter() {
        this(false, 84, AUTO_PRECISION);
    }

    private JiffTemporalPrinter(
        Boolean lowercaseLetters,
        Integer separatorChar,
        Integer precisionDigits
    ) {
        this.lowercaseLetters = lowercaseLetters;
        this.separatorChar = separatorChar;
        this.precisionDigits = precisionDigits;
    }

    // ---- options --------------------------------------------------------

    /**
     * Whether to write the format's letters in lowercase: `2024-06-15t07:00:00z` rather than
     * `2024-06-15T07:00:00Z`. Mirrors `DateTimePrinter::lowercase`.
     */
    public JiffTemporalPrinter lowercase(Boolean yes) {
        return new JiffTemporalPrinter(yes, separatorChar, precisionDigits);
    }

    /**
     * Sets the character written between a date and a time. It must be a single ASCII
     * character; anything else throws `JiffException`. With `lowercase(true)` an uppercase
     * letter given here is written in lowercase.
     *
     * Mirrors `DateTimePrinter::separator`.
     */
    public JiffTemporalPrinter separator(String asciiChar) {
        if (asciiChar == null || asciiChar.length() != 1 || asciiChar.charAt(0) > 127) {
            throw new JiffException('RFC 3339 separator must be a single ASCII character');
        }
        return new JiffTemporalPrinter(lowercaseLetters, asciiChar.charAt(0), precisionDigits);
    }

    /**
     * Sets how many digits of fractional seconds to write, or null to write only as many as
     * the value needs. Zero writes no fraction at all. A value above nine is treated as nine.
     * A negative value throws `JiffException`.
     *
     * Digits beyond the precision are cut off, not rounded: `23:59:59.999` at precision zero
     * is `23:59:59`.
     *
     * Mirrors `DateTimePrinter::precision`.
     */
    public JiffTemporalPrinter precision(Integer digits) {
        if (digits == null) {
            return new JiffTemporalPrinter(lowercaseLetters, separatorChar, AUTO_PRECISION);
        }
        if (digits < 0) {
            throw new JiffException('the precision of fractional seconds must not be negative');
        }
        return new JiffTemporalPrinter(
            lowercaseLetters,
            separatorChar,
            Math.min(digits, MAX_PRECISION)
        );
    }

    // ---- printing -------------------------------------------------------

    /**
     * Formats a date as `YYYY-MM-DD`. Years before zero are written with a sign and six
     * digits, `-00YYYY`. None of the options affect a date.
     *
     * Mirrors `DateTimePrinter::date_to_string`.
     */
    public String dateToString(JiffDate value) {
        return year(value.year()) +
            '-' +
            JiffMath.pad(value.month(), 2) +
            '-' +
            JiffMath.pad(value.day(), 2);
    }

    /**
     * Formats a time as `HH:MM:SS`, followed by a fraction as the precision option directs.
     *
     * Mirrors `DateTimePrinter::time_to_string`.
     */
    public String timeToString(JiffTime value) {
        String out =
            JiffMath.pad(value.hour(), 2) +
            ':' +
            JiffMath.pad(value.minute(), 2) +
            ':' +
            JiffMath.pad(value.second(), 2);
        Integer nanos = value.subsecNanosecond();
        Boolean hasFraction = precisionDigits == AUTO_PRECISION ? nanos != 0 : precisionDigits > 0;
        return hasFraction ? out + '.' + fraction(nanos) : out;
    }

    /**
     * Formats a civil datetime as a date, the separator and a time:
     * `2024-06-15T07:00:00`.
     *
     * Mirrors `DateTimePrinter::datetime_to_string`.
     */
    public String dateTimeToString(JiffDateTime value) {
        return dateToString(value.toDate()) + separatorText() + timeToString(value.toTime());
    }

    /**
     * Formats an instant as an RFC 3339 timestamp in UTC, ending in `Z`:
     * `2024-06-19T19:22:45Z`.
     *
     * Mirrors `DateTimePrinter::timestamp_to_string`.
     */
    public String timestampToString(JiffTimestamp value) {
        return dateTimeToString(JiffOffset.UTC.toDateTime(value)) + zulu();
    }

    /**
     * Formats an instant as an RFC 3339 timestamp at the given offset:
     * `2024-06-19T15:22:45-04:00`. The date and time are what a clock at that offset shows.
     *
     * RFC 3339 offsets have no seconds, so an offset with seconds is rounded to the nearest
     * minute. A timestamp at such an offset may therefore not parse back to the same instant.
     *
     * Mirrors `DateTimePrinter::timestamp_with_offset_to_string`.
     */
    public String timestampWithOffsetToString(JiffTimestamp value, JiffOffset offset) {
        return dateTimeToString(offset.toDateTime(value)) + JiffTemporal.printOffset(offset);
    }

    /**
     * Formats an ISO 8601 week date as `YYYY-Www-D`, for example `2024-W10-6`. The weekday is
     * a number from `1` (Monday) to `7` (Sunday).
     *
     * Mirrors `DateTimePrinter::print_iso_week_date`.
     */
    public String isoWeekDateToString(JiffIsoWeekDate value) {
        return year(value.year()) +
            (lowercaseLetters ? '-w' : '-W') +
            JiffMath.pad(value.week(), 2) +
            '-' +
            JiffWeekdays.toMondayOneOffset(value.weekday());
    }

    /**
     * Formats a time zone so that `JiffTemporal.parseTimeZone` reads it back: an IANA name
     * (`America/New_York`, `UTC`), `Etc/Unknown` for the unknown zone, or the offset of a
     * fixed zone as `+HH:MM` or, when it has seconds, `+HH:MM:SS`.
     *
     * Mirrors `DateTimePrinter::time_zone_to_string`. That can fail in Jiff, for a system
     * time zone that has no name; every time zone of this port can be printed.
     */
    public String timeZoneToString(JiffTimeZone zone) {
        if (zone.ianaName() != null) {
            return zone.ianaName();
        }
        if (zone.isUnknown()) {
            return 'Etc/Unknown';
        }
        JiffOffset offset = zone.toFixedOffset();
        Integer magnitude = Math.abs(offset.seconds());
        Integer seconds = Math.mod(magnitude, 60);
        return (offset.isNegative() ? '-' : '+') +
            JiffMath.pad(magnitude / 3600, 2) +
            ':' +
            JiffMath.pad(Math.mod(magnitude / 60, 60), 2) +
            (seconds == 0 ? '' : ':' + JiffMath.pad(seconds, 2));
    }

    /**
     * Formats datetime pieces as a Temporal ISO 8601 string, passing each piece through as it
     * is:
     *
     * - A date alone is `2025-01-03`, and with an annotation `2025-01-03[Africa/Cairo]`.
     * - A time, when present, follows the separator.
     * - An offset is `Z`, `-00:00` or `+HH:MM` (rounded to the minute). Since
     *   `2025-01-03-05:00` is not valid, pieces with an offset and no time are written with a
     *   time of midnight.
     * - An annotation is written in square brackets, with `!` when it is critical.
     *
     * Mirrors `DateTimePrinter::pieces_to_string`.
     */
    public String piecesToString(JiffPieces pieces) {
        JiffPiecesOffset offset = pieces.offset();
        String out;
        if (pieces.toTime() != null || offset != null) {
            JiffTime timePart = pieces.toTime() == null ? JiffTime.midnight() : pieces.toTime();
            out = dateToString(pieces.toDate()) + separatorText() + timeToString(timePart);
            if (offset != null) {
                out += offset.isZulu() ? zulu() : offset.toString();
            }
        } else {
            out = dateToString(pieces.toDate());
        }
        JiffPiecesTimeZoneAnnotation annotation = pieces.timeZoneAnnotation();
        return annotation == null ? out : out + annotation.toString();
    }

    // ---- helpers --------------------------------------------------------

    /** A year as four digits, or as `-00` and four digits when it is negative. */
    private static String year(Integer value) {
        return value < 0 ? '-00' + JiffMath.pad(-value, 4) : JiffMath.pad(value, 4);
    }

    /** The separator between a date and a time, in the letter case the options ask for. */
    private String separatorText() {
        String text = String.fromCharArray(new List<Integer>{ separatorChar });
        return lowercaseLetters ? text.toLowerCase() : text;
    }

    private String zulu() {
        return lowercaseLetters ? 'z' : 'Z';
    }

    /**
     * The digits of a fraction of a second: cut or padded to the precision when there is one,
     * and otherwise with trailing zeros removed.
     */
    private String fraction(Integer nanos) {
        String digits = String.valueOf(nanos).leftPad(MAX_PRECISION, '0');
        if (precisionDigits != AUTO_PRECISION) {
            return digits.substring(0, precisionDigits);
        }
        Integer endIndex = MAX_PRECISION;
        while (endIndex > 0 && digits.charAt(endIndex - 1) == 48) {
            endIndex--;
        }
        return digits.substring(0, endIndex);
    }
}
