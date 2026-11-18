/**
 * A series of timestamps a fixed period apart, produced by `JiffTimestamp.series(period)`.
 *
 *     // Every five hours for the next two days.
 *     JiffTimestamp finish = start.add(new JiffSpan().hours(48));
 *     for (JiffTimestamp ts : start.series(new JiffSpan().hours(5))) {
 *         if (ts.isAfter(finish)) {
 *             break;
 *         }
 *         // ...
 *     }
 *
 * The series has no end of its own: it runs until stepping again would leave the range of
 * `JiffTimestamp`, so a loop over it needs its own stopping condition, or use `take`. As in
 * Jiff, the last timestamp before the limit is not produced, because the series stops as soon
 * as it cannot compute the one after it. A negative period walks backward in time, and a
 * period of zero repeats the starting timestamp forever. A period with a non-zero unit larger
 * than hours has no fixed length, and yields an empty series.
 *
 * Unlike the value types in this library, a series is a cursor: `next()` advances it, and
 * looping over it consumes it.
 *
 * Mirrors `jiff::TimestampSeries`.
 */
public class JiffTimestampSeries implements Iterator<JiffTimestamp>, Iterable<JiffTimestamp> {
    // Null when the period cannot be converted to an exact duration.
    private final JiffSignedDuration step;
    // The timestamp `next()` will return, and the one after it. `following` is null once the
    // series has run into the limits of JiffTimestamp.
    private JiffTimestamp current;
    private JiffTimestamp following;

    /** Creates the series that starts at `start` and steps by `period`. */
    public JiffTimestampSeries(JiffTimestamp start, JiffSpan period) {
        this.step = period.largestCalendarUnit() == null ? period.toInvariantDuration() : null;
        this.current = start;
        this.following = advance(start);
    }

    /** `origin` plus one step, or null when there is no step or the sum is out of range. */
    private JiffTimestamp advance(JiffTimestamp origin) {
        if (step == null) {
            return null;
        }
        try {
            return origin.add(step);
        } catch (JiffException e) {
            return null;
        }
    }

    /** Whether `next()` has another timestamp to return. */
    public Boolean hasNext() {
        return following != null;
    }

    /** Returns the next timestamp and advances the series. Throws when the series is done. */
    public JiffTimestamp next() {
        if (following == null) {
            throw new JiffException('timestamp series has no more elements');
        }
        JiffTimestamp result = current;
        current = following;
        following = advance(current);
        return result;
    }

    /**
     * Returns up to `count` timestamps, advancing the series past them. Fewer are returned
     * only if the series ends first.
     */
    public List<JiffTimestamp> take(Integer count) {
        List<JiffTimestamp> out = new List<JiffTimestamp>();
        while (out.size() < count && hasNext()) {
            out.add(next());
        }
        return out;
    }

    /**
     * Returns this series, so that it can be used directly in a `for` loop. The loop advances
     * this same cursor rather than a copy.
     */
    public Iterator<JiffTimestamp> iterator() {
        return this;
    }
}
