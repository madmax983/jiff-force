/**
 * The UTC offset written in a datetime string, for use with `JiffPieces`.
 *
 * It is almost a `JiffOffset`, and every value converts to one with `toNumericOffset`. But
 * some offsets in a string mean more than their number of seconds:
 *
 * - `Z` ("Zulu") says the time is in UTC and that the offset to local time is unknown.
 * - `-00:00` says the same thing in the older notation of RFC 3339.
 * - `+00:00` says the offset to local time is known, and is zero.
 *
 * All three become `JiffOffset.UTC`. This type keeps what was actually written, so a string
 * can be inspected and printed back unchanged.
 *
 *     JiffPiecesOffset off = JiffPieces.parse('1970-01-01T00:00:00Z').offset();
 *     off.isZulu();            // true
 *     off.toNumericOffset();   // +00
 *
 * An offset is either `JiffPiecesOffset.ZULU` or a numeric offset made with `fromNumeric` or
 * `fromOffset`. Instances are immutable.
 *
 * Mirrors `jiff::fmt::temporal::PiecesOffset`.
 */
public class JiffPiecesOffset {
    /** The `Z` offset: UTC, with the offset to local time unknown. */
    public static final JiffPiecesOffset ZULU = new JiffPiecesOffset(null);

    // Null for Zulu.
    private final JiffPiecesNumericOffset numericValue;

    private JiffPiecesOffset(JiffPiecesNumericOffset numericValue) {
        this.numericValue = numericValue;
    }

    /** A specific numeric offset, which may be `-00:00`. */
    public static JiffPiecesOffset fromNumeric(JiffPiecesNumericOffset numericOffset) {
        if (numericOffset == null) {
            throw new JiffException('a numeric pieces offset needs an offset');
        }
        return new JiffPiecesOffset(numericOffset);
    }

    /** A specific numeric offset with the offset's own sign. This never gives `-00:00`. */
    public static JiffPiecesOffset fromOffset(JiffOffset offset) {
        return new JiffPiecesOffset(JiffPiecesNumericOffset.fromOffset(offset));
    }

    /** Whether this is the `Z` offset. */
    public Boolean isZulu() {
        return numericValue == null;
    }

    /** The numeric offset with its written sign, or null when this is the `Z` offset. */
    public JiffPiecesNumericOffset asNumeric() {
        return numericValue;
    }

    /**
     * This offset as a plain `JiffOffset`. `Z`, `-00:00` and `+00:00` all give
     * `JiffOffset.UTC`; any other offset is returned as it is.
     */
    public JiffOffset toNumericOffset() {
        return numericValue == null ? JiffOffset.UTC : numericValue.offset();
    }

    /** Whether both are `Z`, or both are the same numeric offset with the same written sign. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffPiecesOffset)) {
            return false;
        }
        JiffPiecesOffset that = (JiffPiecesOffset) other;
        if (numericValue == null || that.numericValue == null) {
            return numericValue == null && that.numericValue == null;
        }
        return numericValue.equals(that.numericValue);
    }

    /** A hash consistent with `equals`. */
    public Integer hashCode() {
        return numericValue == null ? 1 : numericValue.hashCode() * 31 + 7;
    }

    /** The offset as it is printed in a datetime string: `Z`, `-00:00`, `+05:30`. */
    public override String toString() {
        return numericValue == null ? 'Z' : numericValue.toString();
    }
}
