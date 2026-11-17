/**
 * The era a year belongs to.
 *
 * jiff-force numbers years the way ISO 8601 does: there is a year `0`, and years before it are
 * negative. The common way of writing Gregorian years has no year zero and no negative years;
 * it labels each year with an era instead. Year `0` here is `1 BCE`, year `-1` is `2 BCE`, and
 * every year from `1` onward is the same number in the `CE` era.
 *
 * Use `JiffDate.eraYear()` and `JiffDate.era()` to read a date's year in era form, and
 * `JiffDateWith.eraYear(year, era)` to set it.
 *
 * Mirrors `jiff::civil::Era`.
 */
public enum JiffEra {
    /** "Before common era": every year less than or equal to `0`. The same as "BC". */
    BCE,
    /** "Common era": every year greater than `0`. The same as "AD". */
    CE
}
