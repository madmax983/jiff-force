/**
 * Arithmetic and numbering schemes for `JiffWeekday`.
 *
 * Apex enums cannot declare methods, so everything Jiff offers as a method on a weekday is a
 * static method here that takes the weekday as its first argument:
 *
 *     JiffWeekdays.next(JiffWeekday.SUNDAY);                             // MONDAY
 *     JiffWeekdays.wrappingAdd(JiffWeekday.SATURDAY, 2L);                // MONDAY
 *     JiffWeekdays.since(JiffWeekday.FRIDAY, JiffWeekday.TUESDAY);       // 3
 *     JiffWeekdays.toSundayZeroOffset(JiffWeekday.THURSDAY);             // 4
 *
 * ## Numbering
 *
 * A weekday has no single agreed number. ISO 8601 starts the week on Monday and counts from
 * `1`; many systems start on Sunday, and some count from `0`. The four `from...Offset` and
 * `to...Offset` pairs convert between a weekday and each of those schemes. For the same reason
 * weekdays are deliberately not ordered: to compare two of them, convert both to the scheme you
 * mean and compare the numbers.
 *
 * Mirrors the methods of `jiff::civil::Weekday`.
 */
public class JiffWeekdays {
    private static final List<JiffWeekday> WEEKDAYS = JiffWeekday.values();

    // ---- offsets --------------------------------------------------------

    /**
     * The weekday at `offset` in a week that starts on Monday and is numbered from `0`
     * (Monday is `0`, Sunday is `6`). Throws unless the offset is in `0..6`.
     */
    public static JiffWeekday fromMondayZeroOffset(Integer offset) {
        JiffMath.check(offset, 0L, 6L, 'weekday (Monday 0-indexed)');
        return WEEKDAYS.get(offset);
    }

    /**
     * The weekday at `offset` in a week that starts on Monday and is numbered from `1`
     * (Monday is `1`, Sunday is `7`), as in ISO 8601. Throws unless the offset is in `1..7`.
     */
    public static JiffWeekday fromMondayOneOffset(Integer offset) {
        JiffMath.check(offset, 1L, 7L, 'weekday (Monday 1-indexed)');
        return WEEKDAYS.get(offset - 1);
    }

    /**
     * The weekday at `offset` in a week that starts on Sunday and is numbered from `0`
     * (Sunday is `0`, Saturday is `6`). Throws unless the offset is in `0..6`.
     */
    public static JiffWeekday fromSundayZeroOffset(Integer offset) {
        JiffMath.check(offset, 0L, 6L, 'weekday (Sunday 0-indexed)');
        return WEEKDAYS.get(offset == 0 ? 6 : offset - 1);
    }

    /**
     * The weekday at `offset` in a week that starts on Sunday and is numbered from `1`
     * (Sunday is `1`, Saturday is `7`). Throws unless the offset is in `1..7`.
     */
    public static JiffWeekday fromSundayOneOffset(Integer offset) {
        JiffMath.check(offset, 1L, 7L, 'weekday (Sunday 1-indexed)');
        return WEEKDAYS.get(offset == 1 ? 6 : offset - 2);
    }

    /** The weekday's offset in a week starting on Monday, numbered from `0`: `0..6`. */
    public static Integer toMondayZeroOffset(JiffWeekday weekday) {
        return weekday.ordinal();
    }

    /** The weekday's offset in a week starting on Monday, numbered from `1`: `1..7`. */
    public static Integer toMondayOneOffset(JiffWeekday weekday) {
        return weekday.ordinal() + 1;
    }

    /** The weekday's offset in a week starting on Sunday, numbered from `0`: `0..6`. */
    public static Integer toSundayZeroOffset(JiffWeekday weekday) {
        return weekday == JiffWeekday.SUNDAY ? 0 : weekday.ordinal() + 1;
    }

    /** The weekday's offset in a week starting on Sunday, numbered from `1`: `1..7`. */
    public static Integer toSundayOneOffset(JiffWeekday weekday) {
        return toSundayZeroOffset(weekday) + 1;
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * The weekday `days` days after `weekday`, wrapping around the end of the week. A negative
     * count moves backwards. Adding any multiple of seven returns the same weekday. Every
     * `Long` is accepted; nothing overflows.
     */
    public static JiffWeekday wrappingAdd(JiffWeekday weekday, Long days) {
        // Reduce the count before adding so that even the largest Long cannot overflow.
        Long shift = JiffMath.truncMod(days, 7L);
        if (shift < 0) {
            shift += 7;
        }
        return WEEKDAYS.get(JiffMath.truncMod(weekday.ordinal() + shift, 7L).intValue());
    }

    /**
     * The weekday `days` days before `weekday`, wrapping around the start of the week. A
     * negative count moves forwards. Every `Long` is accepted; nothing overflows.
     */
    public static JiffWeekday wrappingSubtract(JiffWeekday weekday, Long days) {
        if (days == JiffMath.LONG_MIN) {
            // The most negative Long cannot be negated. Subtracting it adds 2^63 days, and
            // 2^63 leaves a remainder of one when divided by seven.
            return wrappingAdd(weekday, 1L);
        }
        return wrappingAdd(weekday, -days);
    }

    /** The day after `weekday`; Monday follows Sunday. */
    public static JiffWeekday next(JiffWeekday weekday) {
        return wrappingAdd(weekday, 1L);
    }

    /** The day before `weekday`; Sunday precedes Monday. */
    public static JiffWeekday previous(JiffWeekday weekday) {
        return wrappingAdd(weekday, -1L);
    }

    /**
     * The number of days from `other` forward to `weekday`, in `0..6`. Adding the result to
     * `other` gives `weekday`: Friday since Tuesday is `3`, Sunday since Monday is `6`.
     */
    public static Integer since(JiffWeekday weekday, JiffWeekday other) {
        Integer days = weekday.ordinal() - other.ordinal();
        return days < 0 ? days + 7 : days;
    }

    /**
     * The number of days from `weekday` forward to `other`, in `0..6`. Adding the result to
     * `weekday` gives `other`: Friday until Tuesday is `4`, Sunday until Monday is `1`.
     */
    public static Integer until(JiffWeekday weekday, JiffWeekday other) {
        return since(other, weekday);
    }

    // ---- cycles ---------------------------------------------------------

    /**
     * The seven days of the week in order, starting with `weekday`.
     *
     * Jiff returns an unending iterator here. Apex has no lazy iterator adaptors, so the port
     * returns one full turn of the cycle, which is what the iterator is used for in practice.
     */
    public static List<JiffWeekday> cycleForward(JiffWeekday weekday) {
        return cycle(weekday, 1L);
    }

    /**
     * The seven days of the week in reverse order, starting with `weekday`. See `cycleForward`
     * for how this differs from Jiff's unending iterator.
     */
    public static List<JiffWeekday> cycleReverse(JiffWeekday weekday) {
        return cycle(weekday, -1L);
    }

    private static List<JiffWeekday> cycle(JiffWeekday weekday, Long step) {
        List<JiffWeekday> days = new List<JiffWeekday>();
        JiffWeekday current = weekday;
        for (Integer i = 0; i < 7; i++) {
            days.add(current);
            current = wrappingAdd(current, step);
        }
        return days;
    }
}
