/**
 * A day of the week.
 *
 * The ordinal of each value is its zero-based offset from Monday, the first day of the week
 * under ISO 8601. `JiffWeekdays` holds the arithmetic and offset conversions that Jiff exposes
 * as methods on `jiff::civil::Weekday` (Apex enums cannot declare methods).
 */
public enum JiffWeekday {
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY,
    SUNDAY
}
