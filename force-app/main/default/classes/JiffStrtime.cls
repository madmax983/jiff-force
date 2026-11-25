/**
 * `printf`-style formatting (`strftime`) and parsing (`strptime`) of datetimes.
 *
 *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 7, 15).at(16, 24, 59, 0)
 *         .inTz('America/New_York');
 *     JiffStrtime.format('%a, %-d %b %Y %T %z', zdt);   // Mon, 15 Jul 2024 16:24:59 -0400
 *
 *     JiffStrtime.parse('%Y-%m-%d is a %A', '2024-07-15 is a Monday').toDate();   // 2024-07-15
 *
 * The `strftime` and `strptime` methods of `JiffDate`, `JiffTime`, `JiffDateTime`,
 * `JiffTimestamp` and `JiffZonedDateTime` are the usual way in. `format` here throws when the
 * format cannot be applied (where `strftime` writes the specifier literally), and `parse`
 * returns the `JiffBrokenDownTime` with every field that was parsed.
 *
 * ## Conversion specifiers
 *
 * When parsing, names (of weekdays, months, AM/PM) are matched without regard to ASCII case.
 *
 * | Specifier | Example | Description |
 * | --------- | ------- | ----------- |
 * | `%%` | `%%` | A literal `%`. |
 * | `%A`, `%a` | `Sunday`, `Sun` | The full and abbreviated weekday. |
 * | `%B`, `%b`, `%h` | `June`, `Jun`, `Jun` | The full and abbreviated month name. |
 * | `%C` | `20` | The century of the year. No padding. |
 * | `%c` | `2024 M07 14, Sun 17:31:59` | Date and time via `JiffStrtimeCustom`. Formatting only. |
 * | `%D` | `7/14/24` | Equivalent to `%m/%d/%y`. |
 * | `%d`, `%e` | `25`, ` 5` | The day of the month. `%d` is zero padded, `%e` space padded. |
 * | `%F` | `2024-07-14` | Equivalent to `%Y-%m-%d`. |
 * | `%f` | `000456` | Fractional seconds, up to nanosecond precision. |
 * | `%.f` | `.000456` | Optional fractional seconds, with dot, up to nanosecond precision. |
 * | `%G` | `2024` | An ISO 8601 week-based year. Zero padded to 4 digits. |
 * | `%g` | `24` | A two digit ISO 8601 week-based year (1969 to 2068). Zero padded. |
 * | `%H` | `23` | The hour on a 24 hour clock. Zero padded. |
 * | `%I` | `11` | The hour on a 12 hour clock. Zero padded. |
 * | `%j` | `060` | The day of the year, `1..366`. Zero padded to 3 digits. |
 * | `%k` | `15` | The hour on a 24 hour clock. Space padded. |
 * | `%l` | ` 3` | The hour on a 12 hour clock. Space padded. |
 * | `%M` | `04` | The minute. Zero padded. |
 * | `%m` | `01` | The month. Zero padded. |
 * | `%N` | `123456000` | Fractional seconds, up to nanosecond precision. Alias for `%9f`. |
 * | `%n` | `\n` | A newline when formatting; any whitespace when parsing. |
 * | `%P` | `am` | AM or PM, lower case. |
 * | `%p` | `PM` | AM or PM, upper case. |
 * | `%Q` | `America/New_York`, `+0530` | An IANA time zone identifier, or else `%z`. |
 * | `%:Q` | `America/New_York`, `+05:30` | An IANA time zone identifier, or else `%:z`. |
 * | `%q` | `4` | The quarter of the year. Formatting only. |
 * | `%R` | `23:30` | Equivalent to `%H:%M`. |
 * | `%r` | `8:30:00 AM` | The 12-hour clock time via `JiffStrtimeCustom`. Formatting only. |
 * | `%S` | `59` | The second. Zero padded. |
 * | `%s` | `1737396540` | A Unix timestamp in seconds. |
 * | `%T` | `23:30:59` | Equivalent to `%H:%M:%S`. |
 * | `%t` | `\t` | A tab when formatting; any whitespace when parsing. |
 * | `%U` | `03` | Week number; week 1 starts on the first Sunday. Zero padded. |
 * | `%u` | `7` | The weekday, Monday `1` to Sunday `7`. |
 * | `%V` | `05` | The ISO 8601 week number. Zero padded. |
 * | `%W` | `03` | Week number; week 1 starts on the first Monday. Zero padded. |
 * | `%w` | `0` | The weekday, Sunday `0` to Saturday `6`. |
 * | `%X` | `17:31:59` | The clock time via `JiffStrtimeCustom`. Formatting only. |
 * | `%x` | `2024 M07 14` | The date via `JiffStrtimeCustom`. Formatting only. |
 * | `%Y` | `2024` | The full year. Zero padded to 4 digits. |
 * | `%y` | `24` | A two digit year (1969 to 2068). Zero padded. |
 * | `%Z` | `EDT` | The time zone abbreviation. Formatting only. |
 * | `%z` | `+0530` | The UTC offset as `[+-]HHMM[SS]`. |
 * | `%:z` | `+05:30` | The UTC offset as `[+-]HH:MM[:SS]`. |
 * | `%::z` | `+05:30:00` | The UTC offset as `[+-]HH:MM:SS`. |
 * | `%:::z` | `-04`, `+05:30` | The UTC offset as `[+-]HH[:MM[:SS]]`. |
 *
 * A flag may follow the `%`: `_` pads a number with spaces, `-` does not pad it, `0` pads it
 * with zeros, `^` upper cases letters and `#` swaps their case (useful with `%p` and `%Z`).
 * Then a width of up to 255 may set the minimum padding (clamped to 20 when formatting), so
 * `%_3d` pads the day to three spaces. For `%f`, `%N` and `%.f` the width is the precision:
 * `%3f` and `%.3f` always write three digits, truncating. When parsing, the width raises how
 * many digits are read (`%03d` reads `005`) and everything else is ignored.
 *
 * `%Z` writes the abbreviation the platform's time zone database gives; it cannot be parsed.
 * `%Q` parses an IANA name and `JiffBrokenDownTime.toZonedDateTime` looks it up with
 * `JiffTimeZone.get`. Names of months and weekdays are English. `%c`, `%r`, `%X` and `%x`
 * use `JiffStrtimeDefaultCustom` unless a `JiffStrtimeConfig` says otherwise. The `E` and `O`
 * modifiers and `%+` are not supported.
 *
 * Mirrors `jiff::fmt::strtime`.
 */
public class JiffStrtime {
    private static final JiffStrtimeConfig LENIENT = new JiffStrtimeConfig().lenient(true);

    /**
     * Parses `input` according to `format`. The same as `JiffBrokenDownTime.parse`.
     *
     *     JiffStrtime.parse('%a, %d %b %Y %T %z', 'Mon, 15 Jul 2024 16:24:59 -0400')
     *         .toZonedDateTime();   // 2024-07-15T16:24:59-04:00[-04:00]
     */
    public static JiffBrokenDownTime parse(String format, String input) {
        return JiffBrokenDownTime.parse(format, input);
    }

    /** Formats a date. Throws when the format cannot be applied, for example `%H`. */
    public static String format(String format, JiffDate value) {
        return JiffBrokenDownTime.fromDate(value).format(format);
    }

    /** Formats a time. Throws when the format cannot be applied, for example `%Y`. */
    public static String format(String format, JiffTime value) {
        return JiffBrokenDownTime.fromTime(value).format(format);
    }

    /** Formats a civil datetime. Throws when the format cannot be applied, for example `%z`. */
    public static String format(String format, JiffDateTime value) {
        return JiffBrokenDownTime.fromDateTime(value).format(format);
    }

    /**
     * Formats an ISO 8601 week date. Throws when the format cannot be applied, for example
     * `%H`.
     *
     *     JiffIsoWeekDate weekDate = JiffIsoWeekDate.newInstance(2020, 53, JiffWeekday.SUNDAY);
     *     JiffStrtime.format('%G-W%V-%u', weekDate);
     *     // 2020-W53-7
     */
    public static String format(String format, JiffIsoWeekDate value) {
        return JiffBrokenDownTime.fromIsoWeekDate(value).format(format);
    }

    /**
     * Formats a timestamp, in UTC. Throws when the format cannot be applied, for example `%Z`
     * (a timestamp has no time zone).
     */
    public static String format(String format, JiffTimestamp value) {
        return JiffBrokenDownTime.fromTimestamp(value).format(format);
    }

    /**
     * Formats a zoned datetime. Throws when the format is invalid.
     *
     *     JiffStrtime.format('%Y-%m-%dT%H:%M:%S%.f%:z', zdt);
     *     // 2024-07-15T16:24:59.123456789-04:00
     */
    public static String format(String format, JiffZonedDateTime value) {
        return JiffBrokenDownTime.fromZonedDateTime(value).format(format);
    }

    /**
     * Formats leniently, as the `strftime` methods of the datetime types do: a specifier that
     * cannot be applied is written out literally. Internal.
     */
    public static String formatLenient(String format, JiffBrokenDownTime tm) {
        return tm.format(format, LENIENT);
    }
}
