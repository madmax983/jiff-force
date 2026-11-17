/**
 * The UTC offset or offsets a time zone could apply to one civil datetime.
 *
 * Most civil datetimes happen exactly once in a time zone, and then there is one offset. Around
 * a time zone transition there are two other possibilities:
 *
 * - A **gap**: the civil time never appears on the clock. When New York springs forward at
 *   `2024-03-10T02:00`, clocks jump to `03:00`, so `02:30` does not exist.
 * - A **fold**: the civil time appears twice. When New York falls back at `2024-11-03T02:00`,
 *   clocks return to `01:00`, so `01:30` happens once at `-04` and again at `-05`.
 *
 * For a gap and a fold, `before()` is the offset in effect before the transition and `after()`
 * the offset in effect after it:
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     tz.toAmbiguousTimestamp(JiffDateTime.newInstance(2024, 7, 15, 17, 30, 0, 0)).offset();
 *     // Unambiguous(-04)
 *     tz.toAmbiguousTimestamp(JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0)).offset();
 *     // Gap(-05, -04)
 *     tz.toAmbiguousTimestamp(JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0)).offset();
 *     // Fold(-04, -05)
 *
 * Counter-intuitively, applying the `before()` offset to a time in a gap gives the *later*
 * instant, the one whose civil time is after the gap. `JiffAmbiguousTimestamp` does this
 * bookkeeping; most code should use its `compatible()`, `earlier()` and `later()` methods.
 *
 * Jiff models this as an enum with three variants. Here it is one immutable class with a
 * factory method and a predicate per variant.
 *
 * Mirrors `jiff::tz::AmbiguousOffset`.
 */
public class JiffAmbiguousOffset {
    private static final Integer UNAMBIGUOUS = 0;
    private static final Integer GAP = 1;
    private static final Integer FOLD = 2;

    private final Integer kind;
    // The single offset when unambiguous; otherwise the offset before the transition.
    private final JiffOffset first;
    // Null when unambiguous; otherwise the offset after the transition.
    private final JiffOffset second;

    private JiffAmbiguousOffset(Integer kind, JiffOffset first, JiffOffset second) {
        this.kind = kind;
        this.first = first;
        this.second = second;
    }

    /** The civil datetime happens exactly once, at `offset`. */
    public static JiffAmbiguousOffset unambiguous(JiffOffset offset) {
        requireOffset(offset);
        return new JiffAmbiguousOffset(UNAMBIGUOUS, offset, null);
    }

    /**
     * The civil datetime falls in a gap between `before`, the offset in effect before the
     * transition, and `after`, the offset in effect after it.
     */
    public static JiffAmbiguousOffset gap(JiffOffset before, JiffOffset after) {
        requireOffset(before);
        requireOffset(after);
        return new JiffAmbiguousOffset(GAP, before, after);
    }

    /**
     * The civil datetime falls in a fold and happens twice: first at `before`, the offset in
     * effect before the transition, and again at `after`, the offset in effect after it.
     */
    public static JiffAmbiguousOffset fold(JiffOffset before, JiffOffset after) {
        requireOffset(before);
        requireOffset(after);
        return new JiffAmbiguousOffset(FOLD, before, after);
    }

    private static void requireOffset(JiffOffset offset) {
        if (offset == null) {
            throw new JiffException('an ambiguous offset cannot hold a null offset');
        }
    }

    /** Whether the civil datetime happens exactly once. */
    public Boolean isUnambiguous() {
        return kind == UNAMBIGUOUS;
    }

    /** Whether the civil datetime is skipped by the clock. */
    public Boolean isGap() {
        return kind == GAP;
    }

    /** Whether the civil datetime happens twice. */
    public Boolean isFold() {
        return kind == FOLD;
    }

    /** The one offset that applies, or null for a gap or a fold. */
    public JiffOffset offset() {
        return kind == UNAMBIGUOUS ? first : null;
    }

    /** The offset in effect before the transition, or null when unambiguous. */
    public JiffOffset before() {
        return kind == UNAMBIGUOUS ? null : first;
    }

    /** The offset in effect after the transition, or null when unambiguous. */
    public JiffOffset after() {
        return second;
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffAmbiguousOffset)) {
            return false;
        }
        JiffAmbiguousOffset that = (JiffAmbiguousOffset) other;
        if (kind != that.kind || !first.equals(that.first)) {
            return false;
        }
        return second == null ? that.second == null : second.equals(that.second);
    }

    public Integer hashCode() {
        return (kind * 31 + first.hashCode()) * 31 + (second == null ? 0 : second.hashCode());
    }

    /** For example `Unambiguous(-04)`, `Gap(-05, -04)` or `Fold(-04, -05)`. */
    public override String toString() {
        if (kind == UNAMBIGUOUS) {
            return 'Unambiguous(' + first + ')';
        }
        return (kind == GAP ? 'Gap(' : 'Fold(') + first + ', ' + second + ')';
    }
}
