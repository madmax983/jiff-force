/**
 * The datetimes `start`, `start + period`, `start + 2 * period` and so on, created by
 * `JiffDateTime.series`. A negative period walks backwards in time.
 *
 *     // Every five hours, starting on the afternoon of July 15th.
 *     JiffDateTime start = JiffDateTime.newInstance(2023, 7, 15, 16, 30, 0, 0);
 *     JiffDateTimeSeries scans = start.series(new JiffSpan().hours(5));
 *     scans.next();   // 2023-07-15T16:30:00
 *     scans.next();   // 2023-07-15T21:30:00
 *     scans.next();   // 2023-07-16T02:30:00
 *
 * Each datetime is computed from the start, not from the datetime before it, so a monthly
 * series started on the 31st returns to the 31st after passing through a shorter month.
 *
 * The series has no end of its own. It ends only before the first step that would leave the
 * supported range of `JiffDateTime` or overflow the limits of a `JiffSpan`, which in practice
 * is thousands of years away, so a loop over a series needs its own exit:
 *
 *     for (JiffDateTime dt : start.series(new JiffSpan().hours(5))) {
 *         if (dt.isAfter(finish)) {
 *             break;
 *         }
 *         // ...
 *     }
 *
 * A zero period yields the start datetime over and over; for practical purposes such a
 * series never ends.
 *
 * A series is a one-shot cursor that can be read with `hasNext()` / `next()` or with a `for`
 * loop. It remembers its position: a second loop over the same series picks up where the first
 * one stopped, and once it has ended it stays ended. Call `JiffDateTime.series` again to start
 * over.
 *
 * Mirrors `jiff::civil::DateTimeSeries`.
 */
public class JiffDateTimeSeries implements Iterator<JiffDateTime>, Iterable<JiffDateTime> {
    private final JiffDateTime start;
    private final JiffSpan period;
    // How many periods to add to `start` for the next datetime that has not been computed yet.
    private Long step = 0;
    // The next datetime to hand out, when it has already been computed.
    private JiffDateTime upcoming = null;
    private Boolean done = false;

    /** Starts a series at `start` that advances by `period`. See `JiffDateTime.series`. */
    public JiffDateTimeSeries(JiffDateTime start, JiffSpan period) {
        this(start, period, 0L);
    }

    @TestVisible
    private JiffDateTimeSeries(JiffDateTime start, JiffSpan period, Long step) {
        if (start == null) {
            throw new JiffException('the start of a datetime series must not be null');
        }
        if (period == null) {
            throw new JiffException('the period of a datetime series must not be null');
        }
        this.start = start;
        this.period = period;
        this.step = step;
    }

    /** Whether the series has another datetime to give. */
    public Boolean hasNext() {
        advance();
        return upcoming != null;
    }

    /**
     * The next datetime in the series. Throws if the series has ended; check `hasNext()`
     * first.
     */
    public JiffDateTime next() {
        advance();
        if (upcoming == null) {
            throw new JiffException('the datetime series has no more elements');
        }
        JiffDateTime result = upcoming;
        upcoming = null;
        return result;
    }

    /** Returns this series, so that it can be used directly in a `for` loop. */
    public Iterator<JiffDateTime> iterator() {
        return this;
    }

    /** Computes the upcoming datetime, unless it is already known or the series has ended. */
    private void advance() {
        if (upcoming != null || done) {
            return;
        }
        // The order of these steps is Jiff's: scale the period, count the step, add.
        try {
            JiffSpan offset = period.multiply(step);
            if (step == JiffMath.LONG_MAX) {
                done = true;
                return;
            }
            step += 1;
            upcoming = start.add(offset);
        } catch (JiffException e) {
            // Either the scaled period or the resulting datetime is out of range. Later steps
            // lie even further out, so the series is over.
            done = true;
        }
    }
}
