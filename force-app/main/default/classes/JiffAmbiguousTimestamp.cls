/**
 * A civil datetime in a time zone that has not yet been pinned to one instant.
 *
 * `JiffTimeZone.toAmbiguousTimestamp(dt)` returns this, because a civil datetime may happen
 * once, never (a gap) or twice (a fold) in a time zone; see `JiffAmbiguousOffset`. The methods
 * here choose an instant:
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     // 01:30 happens twice on the day clocks fall back.
 *     JiffAmbiguousTimestamp fold =
 *         tz.toAmbiguousTimestamp(JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0));
 *     fold.isAmbiguous();   // true
 *     fold.earlier();       // 2024-11-03T05:30:00Z
 *     fold.later();         // 2024-11-03T06:30:00Z
 *     fold.compatible();    // 2024-11-03T05:30:00Z
 *     fold.unambiguous();   // throws JiffException
 *
 * | Method          | Unambiguous | Gap                              | Fold    |
 * | --------------- | ----------- | -------------------------------- | ------- |
 * | `compatible()`  | the instant | later (civil time after the gap) | earlier |
 * | `earlier()`     | the instant | earlier (civil time before it)   | earlier |
 * | `later()`       | the instant | later                            | later   |
 * | `unambiguous()` | the instant | throws                           | throws  |
 *
 * In a gap no instant has the requested civil time, so the instant returned is shifted by the
 * length of the gap: `02:30` on a spring-forward day becomes `03:30` (later) or `01:30`
 * (earlier).
 *
 * Every method can also throw when the chosen instant is outside the range of
 * `JiffTimestamp`, which can only happen within about a day of the limits of `JiffDateTime`.
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::tz::AmbiguousTimestamp`.
 */
public class JiffAmbiguousTimestamp {
    private final JiffDateTime dt;
    private final JiffAmbiguousOffset ambiguousOffset;

    private JiffAmbiguousTimestamp(JiffDateTime dt, JiffAmbiguousOffset ambiguousOffset) {
        this.dt = dt;
        this.ambiguousOffset = ambiguousOffset;
    }

    /**
     * Pairs a civil datetime with the offsets that could apply to it. Most code gets one of
     * these from `JiffTimeZone.toAmbiguousTimestamp` instead.
     */
    public static JiffAmbiguousTimestamp newInstance(JiffDateTime dt, JiffAmbiguousOffset offset) {
        if (dt == null || offset == null) {
            throw new JiffException('an ambiguous timestamp needs both a datetime and an offset');
        }
        return new JiffAmbiguousTimestamp(dt, offset);
    }

    /** The civil datetime that was asked about. */
    public JiffDateTime toDateTime() {
        return dt;
    }

    /** The offset or offsets that could apply to the civil datetime. */
    public JiffAmbiguousOffset offset() {
        return ambiguousOffset;
    }

    /** Whether the civil datetime falls in a gap or a fold. */
    public Boolean isAmbiguous() {
        return !ambiguousOffset.isUnambiguous();
    }

    /**
     * Picks the later instant in a gap and the earlier instant in a fold. This is the choice
     * RFC 5545 makes and the one most people expect.
     */
    public JiffTimestamp compatible() {
        // In a gap, the offset from before the transition lands on the far side of the gap.
        return ambiguousOffset.isUnambiguous()
            ? ambiguousOffset.offset().toTimestamp(dt)
            : ambiguousOffset.before().toTimestamp(dt);
    }

    /** Picks the earlier of the candidate instants. */
    public JiffTimestamp earlier() {
        if (ambiguousOffset.isUnambiguous()) {
            return ambiguousOffset.offset().toTimestamp(dt);
        }
        return ambiguousOffset.isGap()
            ? ambiguousOffset.after().toTimestamp(dt)
            : ambiguousOffset.before().toTimestamp(dt);
    }

    /** Picks the later of the candidate instants. */
    public JiffTimestamp later() {
        if (ambiguousOffset.isUnambiguous()) {
            return ambiguousOffset.offset().toTimestamp(dt);
        }
        return ambiguousOffset.isGap()
            ? ambiguousOffset.before().toTimestamp(dt)
            : ambiguousOffset.after().toTimestamp(dt);
    }

    /** Returns the instant when there is exactly one, and throws for a gap or a fold. */
    public JiffTimestamp unambiguous() {
        if (ambiguousOffset.isUnambiguous()) {
            return ambiguousOffset.offset().toTimestamp(dt);
        }
        throw new JiffException(
            'datetime is ambiguous since it falls into a ' +
                (ambiguousOffset.isGap() ? 'gap' : 'fold') +
                ' between offsets ' +
                ambiguousOffset.before() +
                ' and ' +
                ambiguousOffset.after()
        );
    }

    /** Chooses an instant using the given strategy. */
    public JiffTimestamp disambiguate(JiffDisambiguation option) {
        if (option == null) {
            throw new JiffException('disambiguation strategy must not be null');
        }
        switch on option {
            when COMPATIBLE {
                return compatible();
            }
            when EARLIER {
                return earlier();
            }
            when LATER {
                return later();
            }
            when else {
                // REJECT
                return unambiguous();
            }
        }
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffAmbiguousTimestamp)) {
            return false;
        }
        JiffAmbiguousTimestamp that = (JiffAmbiguousTimestamp) other;
        return dt.equals(that.dt) && ambiguousOffset.equals(that.ambiguousOffset);
    }

    public Integer hashCode() {
        Long hash = dt.hashCode() * 31L + ambiguousOffset.hashCode();
        return JiffMath.floorMod(hash, 1000000007L).intValue();
    }

    /** For example `2024-11-03T01:30:00 Fold(-04, -05)`. */
    public override String toString() {
        return dt.toString() + ' ' + ambiguousOffset.toString();
    }
}
