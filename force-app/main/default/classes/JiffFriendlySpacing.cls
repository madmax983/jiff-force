/**
 * How much whitespace `JiffFriendlyPrinter` puts into a friendly duration.
 *
 * - `NONE` writes no spaces: `1y2mo`. (When the hours-minutes-seconds form follows calendar
 *   units, one space still separates the two: `1y2mo 15:00:00`.)
 * - `BETWEEN_UNITS` writes a space after each label: `1y 2mo`. This is the default.
 * - `BETWEEN_UNITS_AND_DESIGNATORS` also writes a space between each value and its label:
 *   `1 y 2 mo`. It reads best with verbose labels: `1 year 2 months`.
 *
 * Mirrors `jiff::fmt::friendly::Spacing`.
 */
public enum JiffFriendlySpacing {
    NONE,
    BETWEEN_UNITS,
    BETWEEN_UNITS_AND_DESIGNATORS
}
