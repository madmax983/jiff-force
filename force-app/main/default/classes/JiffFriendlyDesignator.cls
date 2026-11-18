/**
 * Which unit labels `JiffFriendlyPrinter` writes after each value.
 *
 * For a span of one year and two months:
 *
 * - `VERBOSE` spells each unit out: `1year 2months`.
 * - `SHORT_FORM` uses a short but not minimal label, with a plural form: `1yr 2mos`.
 * - `COMPACT` uses the shortest recognizable label, the same for singular and plural:
 *   `1y 2mo`. This is the default.
 * - `HUMAN_TIME` uses only labels that Rust's `humantime` crate can also parse:
 *   `1y 2months`. Use it when the text is read by a system built on that crate.
 *
 * `SHORT_FORM` is Jiff's `Designator::Short`; `short` on its own is a reserved word in Apex.
 *
 * Mirrors `jiff::fmt::friendly::Designator`.
 */
public enum JiffFriendlyDesignator {
    VERBOSE,
    SHORT_FORM,
    COMPACT,
    HUMAN_TIME
}
