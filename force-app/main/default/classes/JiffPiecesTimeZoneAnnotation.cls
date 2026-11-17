/**
 * The time zone annotation of an RFC 9557 datetime string: the part in square brackets, as in
 * `2025-01-02T16:47-05[America/New_York]`. For use with `JiffPieces`.
 *
 * An annotation holds either a time zone name or a UTC offset; `kind()` says which. It may
 * also carry the critical flag, written `!` (`[!America/New_York]`), which asks the reader to
 * reject the string rather than ignore an annotation it cannot honour.
 *
 *     JiffPiecesTimeZoneAnnotation ann =
 *         JiffPieces.parse('2025-01-02T16:47-05[America/New_York]').timeZoneAnnotation();
 *     ann.kind();          // NAMED
 *     ann.name();          // America/New_York
 *     ann.isCritical();    // false
 *     ann.toTimeZone();    // the America/New_York time zone
 *
 * The name is whatever was written. It is only looked up when `toTimeZone` is called, so an
 * annotation can name a zone that does not exist. Instances are immutable.
 *
 * Mirrors `jiff::fmt::temporal::TimeZoneAnnotation`. Jiff wraps the name in a
 * `TimeZoneAnnotationName`; here it is a plain `String`.
 */
public class JiffPiecesTimeZoneAnnotation {
    // Exactly one of these is set.
    private final String nameValue;
    private final JiffOffset offsetValue;
    private final Boolean critical;

    private JiffPiecesTimeZoneAnnotation(
        String nameValue,
        JiffOffset offsetValue,
        Boolean critical
    ) {
        this.nameValue = nameValue;
        this.offsetValue = offsetValue;
        this.critical = critical;
    }

    /**
     * An annotation holding a time zone name, without the critical flag. The name is not
     * checked in any way.
     */
    public static JiffPiecesTimeZoneAnnotation fromName(String name) {
        if (name == null) {
            throw new JiffException('a time zone annotation needs a name or an offset');
        }
        return new JiffPiecesTimeZoneAnnotation(name, null, false);
    }

    /** An annotation holding a UTC offset, without the critical flag. */
    public static JiffPiecesTimeZoneAnnotation fromOffset(JiffOffset offset) {
        if (offset == null) {
            throw new JiffException('a time zone annotation needs a name or an offset');
        }
        return new JiffPiecesTimeZoneAnnotation(null, offset, false);
    }

    /** Whether this annotation holds a name or an offset. */
    public JiffPiecesTimeZoneAnnotationKind kind() {
        return nameValue != null
            ? JiffPiecesTimeZoneAnnotationKind.NAMED
            : JiffPiecesTimeZoneAnnotationKind.OFFSET;
    }

    /** The time zone name, or null when this annotation holds an offset. */
    public String name() {
        return nameValue;
    }

    /** The UTC offset, or null when this annotation holds a name. */
    public JiffOffset offset() {
        return offsetValue;
    }

    /**
     * Whether the annotation carries the critical flag `!`. Parsing records the flag and
     * otherwise ignores it for time zone annotations, as Jiff and Temporal do.
     */
    public Boolean isCritical() {
        return critical;
    }

    /**
     * This annotation with the critical flag set or cleared.
     *
     * Jiff has no public way to do this: there, a critical annotation only comes from parsing
     * one. The port offers it so that such a string can also be built.
     */
    public JiffPiecesTimeZoneAnnotation withCritical(Boolean yes) {
        if (yes == null) {
            throw new JiffException('the critical flag must be true or false, not null');
        }
        return new JiffPiecesTimeZoneAnnotation(nameValue, offsetValue, yes);
    }

    /**
     * The time zone this annotation refers to: the named zone from the platform's time zone
     * database, or a fixed offset zone. Throws `JiffException` when the name is not a known
     * time zone.
     */
    public JiffTimeZone toTimeZone() {
        return nameValue != null ? JiffTimeZone.get(nameValue) : JiffTimeZone.fixed(offsetValue);
    }

    /** Whether both hold the same name or the same offset, and agree on the critical flag. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffPiecesTimeZoneAnnotation)) {
            return false;
        }
        JiffPiecesTimeZoneAnnotation that = (JiffPiecesTimeZoneAnnotation) other;
        if (critical != that.critical || kind() != that.kind()) {
            return false;
        }
        return nameValue != null
            ? nameValue.equals(that.nameValue)
            : offsetValue.equals(that.offsetValue);
    }

    /** A hash consistent with `equals`. */
    public Integer hashCode() {
        Long detail = nameValue != null ? nameValue.hashCode() : offsetValue.hashCode();
        return JiffMath.floorMod(detail * 2 + (critical ? 1 : 0), 1000000007L).intValue();
    }

    /**
     * The annotation as it is printed in a datetime string, brackets included:
     * `[America/New_York]`, `[!Europe/London]`, `[-05:00]`. An offset is rounded to the
     * nearest minute, since RFC 9557 has no room for seconds.
     */
    public override String toString() {
        return '[' +
            (critical ? '!' : '') +
            (nameValue != null ? nameValue : JiffTemporal.printOffset(offsetValue)) +
            ']';
    }
}
