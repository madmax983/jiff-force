/**
 * A numeric UTC offset as it was written in a datetime string, for use with `JiffPieces`.
 *
 * This is a `JiffOffset` plus one extra fact: whether the offset was written with a negative
 * sign. For every offset but zero the two agree. For zero they need not, and that is the point
 * of this type: `+00:00` says that UTC is the preferred offset, while `-00:00` says that the
 * time is in UTC only because the offset to local time is not known. A `JiffOffset` cannot
 * tell them apart.
 *
 *     JiffPiecesNumericOffset plus = JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC);
 *     plus.isNegative();                       // false, prints as +00:00
 *     plus.withNegativeZero().isNegative();    // true, prints as -00:00
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::fmt::temporal::PiecesNumericOffset`.
 */
public class JiffPiecesNumericOffset {
    private final JiffOffset offsetValue;
    private final Boolean negative;

    private JiffPiecesNumericOffset(JiffOffset offsetValue, Boolean negative) {
        this.offsetValue = offsetValue;
        this.negative = negative;
    }

    /**
     * Wraps an offset. The sign is the offset's own, so this never produces `-00:00`; use
     * `withNegativeZero` for that.
     */
    public static JiffPiecesNumericOffset fromOffset(JiffOffset offset) {
        if (offset == null) {
            throw new JiffException('a numeric offset needs an offset');
        }
        return new JiffPiecesNumericOffset(offset, offset.isNegative());
    }

    /** The offset itself. `-00:00` and `+00:00` both give `JiffOffset.UTC`. */
    public JiffOffset offset() {
        return offsetValue;
    }

    /**
     * Whether the offset was written with a negative sign. This is true for `-00:00`, which is
     * the only case where it differs from `offset().isNegative()`.
     */
    public Boolean isNegative() {
        return negative;
    }

    /**
     * Marks this offset as written with a negative sign. Only meaningful for an offset of
     * zero, where it turns `+00:00` into `-00:00`; a positive offset is still printed with its
     * own sign.
     */
    public JiffPiecesNumericOffset withNegativeZero() {
        return new JiffPiecesNumericOffset(offsetValue, true);
    }

    /** Whether both the offset and the written sign are the same. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffPiecesNumericOffset)) {
            return false;
        }
        JiffPiecesNumericOffset that = (JiffPiecesNumericOffset) other;
        return offsetValue.equals(that.offsetValue) && negative == that.negative;
    }

    /** A hash consistent with `equals`. */
    public Integer hashCode() {
        return offsetValue.hashCode() * 2 + (negative ? 1 : 0);
    }

    /** The offset as it is printed in a datetime string: `-00:00`, `+05:30`, `-04:00`. */
    public override String toString() {
        return offsetValue.isZero() && negative ? '-00:00' : JiffTemporal.printOffset(offsetValue);
    }
}
