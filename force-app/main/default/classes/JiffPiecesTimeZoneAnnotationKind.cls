/**
 * What an RFC 9557 time zone annotation holds: a time zone name, as in `[America/New_York]`,
 * or a UTC offset, as in `[-05:00]`.
 *
 * Mirrors the variants of `jiff::fmt::temporal::TimeZoneAnnotationKind`. The data each variant
 * carries in Jiff is read from the annotation itself, with
 * `JiffPiecesTimeZoneAnnotation.name()` and `JiffPiecesTimeZoneAnnotation.offset()`.
 */
public enum JiffPiecesTimeZoneAnnotationKind {
    NAMED,
    OFFSET
}
