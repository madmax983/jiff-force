/**
 * A civil datetime in a time zone that has not yet been pinned to one zoned datetime.
 *
 * `JiffTimeZone.toAmbiguousZonedDateTime(dt)` returns this, because a civil datetime may
 * happen once, never (a gap) or twice (a fold) in a time zone; see `JiffAmbiguousOffset`. What
 * is ambiguous is the offset, and the methods here choose one:
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     // 01:30 happens twice on the day clocks fall back.
 *     JiffAmbiguousZonedDateTime fold =
 *         tz.toAmbiguousZonedDateTime(JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0));
 *     fold.isAmbiguous();   // true
 *     fold.earlier();       // 2024-11-03T01:30:00-04:00[America/New_York]
 *     fold.later();         // 2024-11-03T01:30:00-05:00[America/New_York]
 *     fold.compatible();    // 2024-11-03T01:30:00-04:00[America/New_York]
 *     fold.unambiguous();   // throws JiffException
 *
 * | Method          | Unambiguous  | Gap                              | Fold    |
 * | --------------- | ------------ | -------------------------------- | ------- |
 * | `compatible()`  | the datetime | later (civil time after the gap) | earlier |
 * | `earlier()`     | the datetime | earlier (civil time before it)   | earlier |
 * | `later()`       | the datetime | later                            | later   |
 * | `unambiguous()` | the datetime | throws                           | throws  |
 *
 * In a gap no instant has the requested civil time, so the result is shifted by the length of
 * the gap: `02:30` on a spring-forward day becomes `03:30` (later) or `01:30` (earlier).
 *
 * Every method can also throw when the chosen instant is outside the range of
 * `JiffTimestamp`, which can only happen within about a day of the limits of `JiffDateTime`.
 *
 * This is `JiffAmbiguousTimestamp` with the time zone carried along, so that the answer is a
 * `JiffZonedDateTime` instead of a bare instant. Instances are immutable.
 *
 * Mirrors `jiff::tz::AmbiguousZonedDateTime`.
 */
public class JiffAmbiguousZonedDateTime {
    private final JiffAmbiguousTimestamp ambiguous;
    private final JiffTimeZone tz;

    private JiffAmbiguousZonedDateTime(JiffAmbiguousTimestamp ambiguous, JiffTimeZone tz) {
        this.ambiguous = ambiguous;
        this.tz = tz;
    }

    /**
     * Pairs a possibly ambiguous timestamp with the time zone it was computed for. Most code
     * gets one of these from `JiffTimeZone.toAmbiguousZonedDateTime` or
     * `JiffOffsetConflicts.resolve` instead.
     */
    public static JiffAmbiguousZonedDateTime newInstance(
        JiffAmbiguousTimestamp ambiguous,
        JiffTimeZone tz
    ) {
        if (ambiguous == null || tz == null) {
            throw new JiffException(
                'an ambiguous zoned datetime needs both an ambiguous timestamp and a time zone'
            );
        }
        return new JiffAmbiguousZonedDateTime(ambiguous, tz);
    }

    /**
     * The time zone the civil datetime is to be resolved in. (Jiff's `into_time_zone` is this
     * same accessor; Apex has no ownership to hand over.)
     */
    public JiffTimeZone timeZone() {
        return tz;
    }

    /** The civil datetime that was asked about. */
    public JiffDateTime toDateTime() {
        return ambiguous.toDateTime();
    }

    /**
     * The offset or offsets that could apply to the civil datetime: one when it is
     * unambiguous, and the offsets before and after the transition for a gap or a fold.
     */
    public JiffAmbiguousOffset offset() {
        return ambiguous.offset();
    }

    /** Whether the civil datetime falls in a gap or a fold. */
    public Boolean isAmbiguous() {
        return ambiguous.isAmbiguous();
    }

    /**
     * Picks the later datetime in a gap and the earlier one in a fold. This is the choice
     * RFC 5545 makes and the one most people expect.
     */
    public JiffZonedDateTime compatible() {
        return disambiguate(JiffDisambiguation.COMPATIBLE);
    }

    /** Picks the earlier of the candidate datetimes. */
    public JiffZonedDateTime earlier() {
        return disambiguate(JiffDisambiguation.EARLIER);
    }

    /** Picks the later of the candidate datetimes. */
    public JiffZonedDateTime later() {
        return disambiguate(JiffDisambiguation.LATER);
    }

    /** Returns the datetime when there is exactly one, and throws for a gap or a fold. */
    public JiffZonedDateTime unambiguous() {
        return disambiguate(JiffDisambiguation.REJECT);
    }

    /** Chooses a datetime using the given strategy. */
    public JiffZonedDateTime disambiguate(JiffDisambiguation option) {
        if (option == null) {
            throw new JiffException('disambiguation strategy must not be null');
        }
        JiffTimestamp chosen;
        try {
            chosen = ambiguous.disambiguate(option);
        } catch (JiffException e) {
            throw new JiffException(
                'error converting datetime to instant in time zone ' + tz + ': ' + e.getMessage(),
                e
            );
        }
        return JiffZonedDateTime.newInstance(chosen, tz);
    }

    /** Whether `other` has the same civil datetime, the same offsets and the same time zone. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffAmbiguousZonedDateTime)) {
            return false;
        }
        JiffAmbiguousZonedDateTime that = (JiffAmbiguousZonedDateTime) other;
        return ambiguous.equals(that.ambiguous) && tz.equals(that.tz);
    }

    /** A hash consistent with `equals`. */
    public Integer hashCode() {
        Long hash = ambiguous.hashCode() * 31L + tz.hashCode();
        return JiffMath.floorMod(hash, 1000000007L).intValue();
    }

    /** For example `2024-11-03T01:30:00 Fold(-04, -05) [America/New_York]`. */
    public override String toString() {
        return ambiguous.toString() + ' [' + tz.toString() + ']';
    }
}
