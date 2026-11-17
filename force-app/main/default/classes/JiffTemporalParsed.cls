/**
 * The components of a datetime string, as parsed by `JiffTemporal.parseParts` and before any
 * decision about what they should become: a date, and optionally a time, a UTC offset and an
 * RFC 9557 time zone annotation.
 *
 * Each of the conversions applies the rules of its target type:
 *
 * - `toDate()` and `toDateTime()` reject a `Z` offset, and otherwise ignore the offset and
 *   the annotation. A missing time is midnight.
 * - `toTimestamp()` requires a time and an offset, and ignores the annotation.
 * - `toPieces()` keeps everything and rejects nothing.
 *
 * A zoned datetime needs more than `JiffPieces` keeps, so the raw parts are available too:
 * `civilDate()`, `civilTime()`, `offset()` (which knows whether seconds were written, see
 * `JiffTemporalParsedOffset.hasSubminute`) and `timeZoneAnnotation()`.
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::fmt::temporal::parser::ParsedDateTime`.
 */
public class JiffTemporalParsed {
    private static final String ZULU_IN_CIVIL =
        'cannot parse civil date/time from string with a Zulu offset, ' +
        'parse as a `jiff::Timestamp` first and convert to a civil date/time instead';

    private final JiffDate dateValue;
    private final JiffTime timeValue;
    private final JiffTemporalParsedOffset offsetValue;
    private final JiffPiecesTimeZoneAnnotation annotation;
    private final String annotationText;

    /**
     * Assembles the parsed components. `timePart`, `offsetPart` and `annotationPart` are null
     * when the string did not have them. `annotationText` is the annotation as it should
     * appear in error messages, brackets included, or the empty string.
     */
    public JiffTemporalParsed(
        JiffDate datePart,
        JiffTime timePart,
        JiffTemporalParsedOffset offsetPart,
        JiffPiecesTimeZoneAnnotation annotationPart,
        String annotationText
    ) {
        this.dateValue = datePart;
        this.timeValue = timePart;
        this.offsetValue = offsetPart;
        this.annotation = annotationPart;
        this.annotationText = annotationText;
    }

    // ---- raw parts ------------------------------------------------------

    /** The date that was written, whatever the offset. */
    public JiffDate civilDate() {
        return dateValue;
    }

    /** The time that was written, or null when the string had only a date. */
    public JiffTime civilTime() {
        return timeValue;
    }

    /** The time that was written, or midnight when the string had only a date. */
    public JiffTime civilTimeOrMidnight() {
        return timeValue == null ? JiffTime.midnight() : timeValue;
    }

    /** The UTC offset as it was written, or null when the string had none. */
    public JiffTemporalParsedOffset offset() {
        return offsetValue;
    }

    /** The time zone annotation, or null when the string had none. */
    public JiffPiecesTimeZoneAnnotation timeZoneAnnotation() {
        return annotation;
    }

    // ---- conversions ----------------------------------------------------

    /**
     * Everything that was parsed, as a `JiffPieces`. Throws only when the offset was written
     * with a fraction of a second that rounds it out of range.
     */
    public JiffPieces toPieces() {
        JiffPieces pieces = JiffPieces.fromDate(dateValue);
        if (timeValue != null) {
            pieces = pieces.withTime(timeValue);
        }
        if (offsetValue != null) {
            pieces = pieces.withOffset(offsetValue.toPiecesOffset());
        }
        if (annotation != null) {
            pieces = pieces.withTimeZoneAnnotation(annotation);
        }
        return pieces;
    }

    /**
     * The instant the string identifies: its civil datetime read at its offset. Throws when
     * the time or the offset is missing, or when the instant is out of range. A time zone
     * annotation is ignored, even when it disagrees with the offset.
     */
    public JiffTimestamp toTimestamp() {
        if (timeValue == null) {
            throw new JiffException(
                'failed to find time component, which is required for parsing a timestamp'
            );
        }
        if (offsetValue == null) {
            throw new JiffException(
                'failed to find offset component, which is required for parsing a timestamp'
            );
        }
        JiffOffset numericOffset = offsetValue.toOffset();
        try {
            return numericOffset.toTimestamp(JiffDateTime.fromParts(dateValue, timeValue));
        } catch (JiffException e) {
            throw new JiffException(
                'failed to convert civil datetime to timestamp with offset ' +
                    numericOffset.toString() +
                    ': ' +
                    e.getMessage(),
                e
            );
        }
    }

    /**
     * The civil datetime that was written, with midnight for a missing time. A numeric offset
     * and an annotation are ignored. Throws when the offset is `Z`: such a string names an
     * instant, and reading its digits as a local time is almost always a mistake.
     */
    public JiffDateTime toDateTime() {
        rejectZulu(offsetValue);
        return JiffDateTime.fromParts(dateValue, civilTimeOrMidnight());
    }

    /** The civil date that was written. Throws when the offset is `Z`, as `toDateTime` does. */
    public JiffDate toDate() {
        rejectZulu(offsetValue);
        return dateValue;
    }

    /**
     * Throws when `parsedOffset` is `Z`, with the error for a `Z` offset where a civil date or
     * time was asked for. A null or numeric offset passes.
     */
    public static void rejectZulu(JiffTemporalParsedOffset parsedOffset) {
        if (parsedOffset != null && parsedOffset.isZulu()) {
            throw new JiffException(ZULU_IN_CIVIL);
        }
    }

    /**
     * What was parsed, written back out: the date, `T` and the time if there was one, the
     * offset with the components it was written with, and the time zone annotation. This is
     * the value quoted by the "unparsed input remains" error.
     */
    public override String toString() {
        String out = JiffTemporal.printDate(dateValue);
        if (timeValue != null) {
            out += 'T' + JiffTemporal.printTime(timeValue);
        }
        if (offsetValue != null) {
            out += offsetValue.toString();
        }
        return out + annotationText;
    }
}
