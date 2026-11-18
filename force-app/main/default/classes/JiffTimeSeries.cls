/**
 * The times `start`, `start + period`, `start + 2 * period` and so on, created by
 * `JiffTime.series`. A negative period steps backwards through the day.
 *
 *     for (JiffTime t : JiffTime.MIN.series(new JiffSpan().hours(3))) {
 *         // 00:00:00, 03:00:00, 06:00:00, 09:00:00, 12:00:00, 15:00:00, 18:00:00, 21:00:00
 *     }
 *
 * The series ends before the first step that would leave the day (the arithmetic is that of
 * `JiffTime.add`, which never wraps around midnight) or that would overflow the limits of a
 * `JiffSpan`. A period with a non-zero unit larger than hours therefore yields the start time
 * and nothing else. A zero period yields the start time over and over; for practical purposes
 * such a series never ends, so do not loop over it without a `break`.
 *
 * A series is a one-shot cursor that can be read with `hasNext()` / `next()` or with a `for`
 * loop. It remembers its position: a second loop over the same series picks up where the first
 * one stopped, and once it has ended it stays ended. Call `JiffTime.series` again to start
 * over.
 *
 * Mirrors `jiff::civil::TimeSeries`.
 */
public class JiffTimeSeries implements Iterator<JiffTime>, Iterable<JiffTime> {
    private final JiffTime start;
    private final JiffSpan period;
    // How many periods to add to `start` for the next time that has not been computed yet.
    private Long step = 0;
    // The next time to hand out, when it has already been computed.
    private JiffTime upcoming = null;
    private Boolean done = false;

    /** Starts a series at `start` that advances by `period`. See `JiffTime.series`. */
    public JiffTimeSeries(JiffTime start, JiffSpan period) {
        this(start, period, 0L);
    }

    @TestVisible
    private JiffTimeSeries(JiffTime start, JiffSpan period, Long step) {
        this.start = start;
        this.period = period;
        this.step = step;
    }

    /** Whether the series has another time to give. */
    public Boolean hasNext() {
        advance();
        return upcoming != null;
    }

    /** The next time in the series. Throws if the series has ended; check `hasNext()` first. */
    public JiffTime next() {
        advance();
        if (upcoming == null) {
            throw new JiffException('the time series has no more elements');
        }
        JiffTime result = upcoming;
        upcoming = null;
        return result;
    }

    /** Returns this series, so that it can be used directly in a `for` loop. */
    public Iterator<JiffTime> iterator() {
        return this;
    }

    /** Computes the upcoming time, unless it is already known or the series has ended. */
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
            done = true;
        }
    }
}
