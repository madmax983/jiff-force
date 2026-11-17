/**
 * The dates `start`, `start + period`, `start + 2 * period` and so on, created by
 * `JiffDate.series`. A negative period walks backwards in time.
 *
 *     // Month ends, starting with January 31st.
 *     JiffDate january = JiffDate.newInstance(2024, 1, 31);
 *     JiffDateSeries monthEnds = january.series(new JiffSpan().months(1));
 *     monthEnds.next();   // 2024-01-31
 *     monthEnds.next();   // 2024-02-29
 *     monthEnds.next();   // 2024-03-31
 *
 * Each date is computed from the start, not from the date before it, which is why the series
 * above returns to the 31st after February.
 *
 * The series has no end of its own. It ends only before the first step that would leave the
 * supported range of `JiffDate` or overflow the limits of a `JiffSpan`, which in practice is
 * thousands of years away, so a loop over a series needs its own exit:
 *
 *     for (JiffDate day : start.series(new JiffSpan().weeks(1))) {
 *         if (day.isAfter(finish)) {
 *             break;
 *         }
 *         // ...
 *     }
 *
 * A zero period yields the start date over and over; for practical purposes such a series
 * never ends.
 *
 * A series is a one-shot cursor that can be read with `hasNext()` / `next()` or with a `for`
 * loop. It remembers its position: a second loop over the same series picks up where the first
 * one stopped, and once it has ended it stays ended. Call `JiffDate.series` again to start
 * over.
 *
 * Mirrors `jiff::civil::DateSeries`.
 */
public class JiffDateSeries implements Iterator<JiffDate>, Iterable<JiffDate> {
    private final JiffDate start;
    private final JiffSpan period;
    // How many periods to add to `start` for the next date that has not been computed yet.
    private Long step = 0;
    // The next date to hand out, when it has already been computed.
    private JiffDate upcoming = null;
    private Boolean done = false;

    /** Starts a series at `start` that advances by `period`. See `JiffDate.series`. */
    public JiffDateSeries(JiffDate start, JiffSpan period) {
        this(start, period, 0L);
    }

    @TestVisible
    private JiffDateSeries(JiffDate start, JiffSpan period, Long step) {
        if (start == null) {
            throw new JiffException('the start of a date series must not be null');
        }
        if (period == null) {
            throw new JiffException('the period of a date series must not be null');
        }
        this.start = start;
        this.period = period;
        this.step = step;
    }

    /** Whether the series has another date to give. */
    public Boolean hasNext() {
        advance();
        return upcoming != null;
    }

    /** The next date in the series. Throws if the series has ended; check `hasNext()` first. */
    public JiffDate next() {
        advance();
        if (upcoming == null) {
            throw new JiffException('the date series has no more elements');
        }
        JiffDate result = upcoming;
        upcoming = null;
        return result;
    }

    /** Returns this series, so that it can be used directly in a `for` loop. */
    public Iterator<JiffDate> iterator() {
        return this;
    }

    /** Computes the upcoming date, unless it is already known or the series has ended. */
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
            // Either the scaled period or the resulting date is out of range. Later steps lie
            // even further out, so the series is over.
            done = true;
        }
    }
}
