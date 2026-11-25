/**
 * The default `JiffStrtimeCustom`, used whenever no other is configured. Its output follows
 * Unicode's `und` ("undetermined") locale:
 *
 * | Specifier | Format                   | Example                    |
 * | --------- | ------------------------ | -------------------------- |
 * | `%c`      | `%Y M%m %-d, %a %H:%M:%S` | `2025 M07 1, Tue 17:30:00` |
 * | `%x`      | `%Y M%m %-d`             | `2025 M07 1`               |
 * | `%X`      | `%H:%M:%S`               | `17:30:00`                 |
 * | `%r`      | `%-I:%M:%S %p`           | `5:30:00 PM`               |
 *
 * With the `^` flag, `%^c` upper cases the weekday and `%^r` the AM/PM marker.
 *
 * Mirrors `jiff::fmt::strtime::DefaultCustom`.
 */
public class JiffStrtimeDefaultCustom implements JiffStrtimeCustom {
    /** `%c`: `2025 M07 1, Tue 17:30:00`. */
    public String formatDateTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        if (ext != null && ext.isUppercase()) {
            return tm.format('%Y M%m %-d, %^a %H:%M:%S', config);
        }
        return tm.format('%Y M%m %-d, %a %H:%M:%S', config);
    }

    /** `%x`: `2025 M04 27`. */
    public String formatDate(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        return tm.format('%Y M%m %-d', config);
    }

    /** `%X`: `17:30:00`. */
    public String formatTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        return tm.format('%H:%M:%S', config);
    }

    /** `%r`: `5:30:00 PM`. */
    public String format12HourTime(
        JiffStrtimeConfig config,
        JiffStrtimeExtension ext,
        JiffBrokenDownTime tm
    ) {
        if (ext != null && ext.isUppercase()) {
            return tm.format('%-I:%M:%S %^p', config);
        }
        return tm.format('%-I:%M:%S %p', config);
    }
}
