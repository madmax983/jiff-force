/**
 * A `JiffStrtimeCustom` that follows POSIX's `C` locale, the output of `date` on many Unix
 * systems:
 *
 * | Specifier | Format                 | Example                    |
 * | --------- | ---------------------- | -------------------------- |
 * | `%c`      | `%a %b %e %H:%M:%S %Y` | `Tue Jul  1 17:30:00 2025` |
 * | `%x`      | `%m/%d/%y`             | `07/01/25`                 |
 * | `%X`      | `%H:%M:%S`             | `17:30:00`                 |
 * | `%r`      | `%I:%M:%S %p`          | `05:30:00 PM`              |
 *
 *     JiffStrtimeConfig config = new JiffStrtimeConfig().custom(new JiffStrtimePosixCustom());
 *     JiffBrokenDownTime.fromDateTime(JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0))
 *         .format('%c', config);   // Tue Jul  1 17:30:00 2025
 *
 * With the `^` flag, `%^c` upper cases the weekday and month names and `%^r` the AM/PM
 * marker.
 *
 * Mirrors `jiff::fmt::strtime::PosixCustom`.
 */
public class JiffStrtimePosixCustom implements JiffStrtimeCustom {
    /** `%c`: `Tue Jul  1 17:30:00 2025`. */
    public String formatDateTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        if (ext != null && ext.isUppercase()) {
            return tm.format('%^a %^b %e %H:%M:%S %Y', config);
        }
        return tm.format('%a %b %e %H:%M:%S %Y', config);
    }

    /** `%x`: `07/01/25`. */
    public String formatDate(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        return tm.format('%m/%d/%y', config);
    }

    /** `%X`: `17:30:00`. */
    public String formatTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        return tm.format('%H:%M:%S', config);
    }

    /** `%r`: `05:30:00 PM`. */
    public String format12HourTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        if (ext != null && ext.isUppercase()) {
            return tm.format('%I:%M:%S %^p', config);
        }
        return tm.format('%I:%M:%S %p', config);
    }
}
