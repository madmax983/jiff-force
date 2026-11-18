/**
 * How `JiffTemporalOffsetParser` treats the colons of a UTC offset.
 *
 * - `OPTIONAL`: `-05:30` and `-0530` are both accepted, but the two styles may not be mixed
 *   within one offset.
 * - `REQUIRED`: only `-05:30`.
 * - `ABSENT`: only `-0530`.
 *
 * Mirrors `jiff::fmt::offset::Colon`.
 */
public enum JiffTemporalOffsetColon {
    OPTIONAL,
    REQUIRED,
    ABSENT
}
