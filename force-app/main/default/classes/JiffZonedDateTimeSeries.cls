/**
 * The zoned datetimes `start`, `start + period`, `start + 2 * period` and so on, created by
 * `JiffZonedDateTime.series`. A negative period walks backwards in time.
 *
 *     // Every 30 minutes across the hour New York repeats on 2025-11-02.
 *     JiffZonedDateTime start = JiffDate.newInstance(2025, 11, 2).at(0, 30, 0, 0)
 *         .inTz('America/New_York');
 *     JiffZonedDateTimeSeries series = start.series(new JiffSpan().minutes(30));
 *     series.next();   // 2025-11-02T00:30:00-04:00[America/New_York]
 *     series.next();   // 2025-11-02T01:00:00-04:00[America/New_York]
 *     series.next();   // 2025-11-02T01:30:00-04:00[America/New_York]
 *     series.next();   // 2025-11-02T01:00:00-05:00[America/New_York]
 *
 * Each zoned datetime is computed from the start with `JiffZonedDateTime.add`, not from the
 * one before it, so a monthly series started on the 31st returns to the 31st after passing
 * through a shorter month, and a daily series keeps its time of day across daylight saving
 * changes.
 *
 * The instants always move strictly in one direction. Zone aware arithmetic can give the
 * same instant for two different steps: `Pacific/Apia` never had December 30th 2011 on its
 * calendars, so one day and two days after the 29th are both the 31st. Such a repeat is left
 * out, and the series goes `2011-12-28`, `2011-12-29`, `2011-12-31`, `2012-01-01`.
 *
 * The series has no end of its own. It ends only before the first step that would leave the
 * supported range or overflow the limits of a `JiffSpan`, so a loop over a series needs its
 * own exit:
 *
 *     for (JiffZonedDateTime zdt : start.series(new JiffSpan().hours(5))) {
 *         if (zdt.isAfter(finish)) {
 *             break;
 *         }
 *         // ...
 *     }
 *
 * A zero period yields the start over and over; for practical purposes such a series never
 * ends.
 *
 * A series is a one-shot cursor that can be read with `hasNext()` / `next()` or with a `for`
 * loop. It remembers its position: a second loop over the same series picks up where the
 * first one stopped, and once it has ended it stays ended. Call `JiffZonedDateTime.series`
 * again to start over.
 *
 * Mirrors `jiff::ZonedDateTimeSeries`.
 */
public class JiffZonedDateTimeSeries implements Iterator<JiffZonedDateTime>, Iterable<JiffZonedDateTime> {
    private final JiffZonedDateTime start;
    private final JiffSpan period;
    // How many periods to add to `start` for the next element that has not been computed yet.
    private Long step = 0;
    // The instant of the element handed out most recently, or null before the first.
    private JiffTimestamp previous = null;
    // The next element to hand out, when it has already been computed.
    private JiffZonedDateTime upcoming = null;
    private Boolean done = false;

    /** Starts a series at `start` that advances by `period`. See `JiffZonedDateTime.series`. */
    public JiffZonedDateTimeSeries(JiffZonedDateTime start, JiffSpan period) {
        this(start, period, 0L);
    }

    @TestVisible
    private JiffZonedDateTimeSeries(JiffZonedDateTime start, JiffSpan period, Long step) {
        if (start == null) {
            throw new JiffException('the start of a zoned datetime series must not be null');
        }
        if (period == null) {
            throw new JiffException('the period of a zoned datetime series must not be null');
        }
        this.start = start;
        this.period = period;
        this.step = step;
    }

    /** Whether the series has another zoned datetime to give. */
    public Boolean hasNext() {
        advance();
        return upcoming != null;
    }

    /**
     * The next zoned datetime in the series. Throws if the series has ended; check
     * `hasNext()` first.
     */
    public JiffZonedDateTime next() {
        advance();
        if (upcoming == null) {
            throw new JiffException('the zoned datetime series has no more elements');
        }
        JiffZonedDateTime result = upcoming;
        upcoming = null;
        return result;
    }

    /** Returns this series, so that it can be used directly in a `for` loop. */
    public Iterator<JiffZonedDateTime> iterator() {
        return this;
    }

    /** Computes the upcoming element, unless it is already known or the series has ended. */
    private void advance() {
        // The loop skips steps that do not move the instant; see the class notes.
        while (upcoming == null && !done) {
            JiffZonedDateTime candidate;
            // The order of these steps is Jiff's: scale the period, count the step, add.
            try {
                JiffSpan offset = period.multiply(step);
                if (step == JiffMath.LONG_MAX) {
                    done = true;
                    return;
                }
                step += 1;
                candidate = start.add(offset);
            } catch (JiffException e) {
                // Either the scaled period or the resulting datetime is out of range. Later
                // steps lie even further out, so the series is over.
                done = true;
                return;
            }
            if (movesOn(candidate.toTimestamp())) {
                previous = candidate.toTimestamp();
                upcoming = candidate;
            }
        }
    }

    /** Whether `instant` lies beyond the previous element, in the direction of the period. */
    private Boolean movesOn(JiffTimestamp instant) {
        if (previous == null) {
            return true;
        }
        if (period.isPositive()) {
            return previous.isBefore(instant);
        }
        if (period.isNegative()) {
            return previous.isAfter(instant);
        }
        // A zero period is a request for the same instant again and again.
        return true;
    }
}
