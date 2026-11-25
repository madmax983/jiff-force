/**
 * A hook for the locale dependent conversion specifiers of `strftime`: `%c` (date and time),
 * `%r` (12-hour clock time), `%X` (clock time) and `%x` (date).
 *
 * Attach an implementation with `JiffStrtimeConfig.custom` and format with
 * `JiffBrokenDownTime.format(String, JiffStrtimeConfig)`. `JiffStrtimeDefaultCustom` (the
 * default, Unicode's `und` locale) and `JiffStrtimePosixCustom` (POSIX's `C` locale) come with
 * the library.
 *
 * Each method returns the formatted text, or throws `JiffException`. An implementation usually
 * formats the broken down time with another format string, passing `config` on so that
 * lenient mode carries through:
 *
 *     public String formatDate(
 *         JiffStrtimeConfig config, JiffStrtimeExtension ext, JiffBrokenDownTime tm
 *     ) {
 *         return tm.format('%d.%m.%Y', config);
 *     }
 *
 * Jiff's trait gives every method a default implementation. Apex interfaces cannot, so an
 * implementation must provide all four; it can delegate to `JiffStrtimeDefaultCustom` for the
 * ones it does not change. Parsing is not customizable.
 *
 * Mirrors `jiff::fmt::strtime::Custom`.
 */
public interface JiffStrtimeCustom {
    /** Formats `%c`: the date and the clock time. */
    String formatDateTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    );

    /** Formats `%x`: the date. */
    String formatDate(JiffStrtimeConfig config, JiffStrtimeExtension ext, JiffBrokenDownTime tm);

    /** Formats `%X`: the clock time. */
    String formatTime(JiffStrtimeConfig config, JiffStrtimeExtension ext, JiffBrokenDownTime tm);

    /** Formats `%r`: the clock time on a 12-hour clock. */
    String format12HourTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    );
}
