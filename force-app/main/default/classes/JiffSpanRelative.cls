/**
 * Internal: a resolved starting point for span arithmetic, comparison, totals and rounding.
 * Not part of the public API; `JiffSpanRelativeTo.toRelative` creates these.
 *
 * A starting point is either a civil datetime, whose days are all 24 hours long, or a zoned
 * datetime, whose days follow its time zone. Either way it also knows its instant: a zoned
 * datetime's own timestamp, or the civil datetime read as if it were UTC. Differences between
 * instants measure how long a stretch of calendar units really is from here.
 *
 * Mirrors Jiff's private `Relative`, `RelativeCivil`, `RelativeZonedDateTime` and
 * `RelativeSpan`, and the parts of `SpanTotal::total` and `Relative::round` that need a
 * starting point.
 */
public class JiffSpanRelative {
    private static final Long TWO_POW_61 = 2305843009213693952L;

    // Exactly one of the two is set.
    private final JiffDateTime civil;
    private final JiffZonedDateTime zoned;
    // The instant of this starting point, as a duration since the Unix epoch.
    private final JiffSignedDuration instant;

    private JiffSpanRelative(
        JiffDateTime civil,
        JiffZonedDateTime zoned,
        JiffSignedDuration instant
    ) {
        this.civil = civil;
        this.zoned = zoned;
        this.instant = instant;
    }

    /** A civil starting point. Throws when the datetime, read as UTC, is not a valid instant. */
    public static JiffSpanRelative ofCivil(JiffDateTime civilDateTime) {
        JiffSignedDuration utc;
        try {
            utc = civilDateTime.toZonedDateTime(JiffTimeZone.UTC).toTimestamp().asDuration();
        } catch (JiffException e) {
            throw inContext(
                'failed to interpret datetime in UTC in order to convert it to a timestamp',
                e
            );
        }
        return new JiffSpanRelative(civilDateTime, null, utc);
    }

    /** A zoned starting point. */
    public static JiffSpanRelative ofZoned(JiffZonedDateTime zonedDateTime) {
        return new JiffSpanRelative(null, zonedDateTime, zonedDateTime.toTimestamp().asDuration());
    }

    /** Whether days here follow a time zone rather than always being 24 hours. */
    public Boolean isZoned() {
        return zoned != null;
    }

    /** The instant of this starting point, as a duration since the Unix epoch. */
    public JiffSignedDuration toDuration() {
        return instant;
    }

    /** The starting point `span` later. */
    public JiffSpanRelative add(JiffSpan span) {
        if (zoned != null) {
            return ofZoned(zoned.add(span));
        }
        return ofCivil(civil.add(span));
    }

    /** The starting point `duration` later. */
    public JiffSpanRelative add(JiffSignedDuration duration) {
        if (zoned != null) {
            return ofZoned(zoned.add(duration));
        }
        return ofCivil(civil.add(duration));
    }

    /**
     * The span from this starting point to `other` (of the same kind), with `largest` as its
     * biggest unit.
     */
    public JiffSpan until(JiffUnit largest, JiffSpanRelative other) {
        if (zoned != null) {
            try {
                return zoned.until(other.zoned, largest);
            } catch (JiffException e) {
                throw inContext(
                    'failed to get span between zoned datetimes with largest unit set to \'' +
                        JiffMath.plural(largest) +
                        '\'',
                    e
                );
            }
        }
        try {
            return civil.until(other.civil, largest);
        } catch (JiffException e) {
            throw inContext(
                'failed to get span between datetimes with largest unit set to \'' +
                    JiffMath.plural(largest) +
                    '\'',
                e
            );
        }
    }

    // ---- span operations that need a starting point ----------------------

    /**
     * The total of `span` in `unit`, measured from here, as a fraction. This is where a month,
     * a year, or a day in a time zone, gets its length.
     */
    public Double total(JiffSpan span, JiffUnit unit) {
        JiffSpanRelative endPoint = add(span);
        JiffSpan balanced = until(unit, endPoint);
        if (!JiffMath.isCalendar(unit)) {
            return totalInvariant(balanced, unit);
        }
        Integer sign = balanced.signum();
        if (sign == 0) {
            // A zero span has no direction to measure the unit in, and its total is zero.
            Double zero = 0;
            return zero;
        }
        List<JiffSignedDuration> bounds = JiffSpanNudge.unitStartAndEnd(
            this,
            balanced.withoutLower(unit),
            unit,
            sign
        );
        Double denominator = toDouble(bounds.get(1).subtract(bounds.get(0)));
        Double numerator = toDouble(endPoint.toDuration().subtract(bounds.get(0)));
        Double whole = balanced.get(unit);
        Double direction = sign;
        return whole + (numerator / denominator) * direction;
    }

    /**
     * The total of `span` in `unit` (weeks or smaller), treating every week as seven days and
     * every day as 24 hours.
     */
    public static Double totalInvariant(JiffSpan span, JiffUnit unit) {
        // As in Jiff, the ratio is taken between nanosecond counts rather than seconds, which
        // loses less precision.
        Double nanos = toDouble(span.toInvariantDuration());
        Double perUnit = JiffMath.nanosPerUnit(unit);
        return nanos / perUnit;
    }

    /**
     * Rounds `span`, measured from here, so that its units lie between `smallest` and
     * `largest`, to a multiple of `increment` smallest units.
     */
    public JiffSpan round(
        JiffSpan span,
        JiffUnit largest,
        JiffUnit smallest,
        Long increment,
        JiffRoundMode mode
    ) {
        JiffSpanRelative endPoint = add(span);
        JiffSpan balanced = until(largest, endPoint);
        if (balanced.isZero()) {
            return balanced;
        }
        JiffSpanNudge nudge;
        if (zoned == null) {
            if (JiffMath.isLarger(smallest, JiffUnit.DAY)) {
                nudge = JiffSpanNudge.relativeCalendar(
                    balanced,
                    this,
                    endPoint,
                    smallest,
                    increment,
                    mode
                );
            } else {
                nudge = JiffSpanNudge.relativeInvariant(
                    balanced,
                    endPoint.toDuration(),
                    largest,
                    smallest,
                    increment,
                    mode
                );
            }
        } else if (JiffMath.isCalendar(smallest)) {
            nudge = JiffSpanNudge.relativeCalendar(
                balanced,
                this,
                endPoint,
                smallest,
                increment,
                mode
            );
        } else if (JiffMath.isCalendar(largest)) {
            // Rounding the time of day can spill into a day, whose length varies here.
            nudge = JiffSpanNudge.relativeZonedTime(balanced, this, smallest, increment, mode);
        } else {
            nudge = JiffSpanNudge.relativeInvariant(
                balanced,
                endPoint.toDuration(),
                largest,
                smallest,
                increment,
                mode
            );
        }
        return nudge.bubble(this, smallest, largest);
    }

    /**
     * Rounds the unrounded difference `span` between two datetimes the way Jiff's
     * `*Difference` options do, when they ask for any rounding at all.
     *
     * @param smallest     the smallest unit, with the datetime type's default already applied
     * @param relative     the receiver of `until` or `since`, or null for types without days
     * @param calendarOnly true for dates, whose differences are already in whole days: then
     *                     only a smallest unit bigger than a day, or an increment, rounds
     */
    public static JiffSpan roundDifference(
        JiffSpan span,
        JiffDifference options,
        JiffUnit smallest,
        JiffSpanRelativeTo relative,
        Boolean calendarOnly
    ) {
        JiffUnit unchanged = calendarOnly ? JiffUnit.DAY : JiffUnit.NANOSECOND;
        Long increment = options.getIncrement();
        if (!JiffMath.isLarger(smallest, unchanged) && increment != null && increment == 1) {
            return span;
        }
        // The largest unit is passed on as given, so an unset one takes span rounding's own
        // default, which can differ from the one used for the unrounded difference.
        JiffSpanRound round = new JiffSpanRound()
            .smallest(smallest)
            .largest(options.getLargest())
            .mode(options.getMode())
            .increment(increment)
            .relative(relative);
        return span.round(round);
    }

    // ---- floating point --------------------------------------------------

    /**
     * The nanoseconds of `duration` as the nearest Double, ties to even: what Rust's
     * `i128 as f64` gives. Converting the seconds and nanoseconds separately and adding them
     * would round twice, and could be one unit in the last place away.
     */
    public static Double toDouble(JiffSignedDuration duration) {
        if (duration.fitsNanos()) {
            // A Long converts to the nearest Double.
            Double exact = duration.asNanos();
            return exact;
        }
        JiffI128 value = duration.asNanosI128();
        JiffI128 magnitude = value.abs();
        // Scale the magnitude down by a power of two into [2^61, 2^62), which a Long holds.
        // Any bits shifted out only matter as a "sticky" bit: whether the value is a little
        // above the truncated one. Recording that in the lowest bit, far below the 53 bits a
        // Double keeps, makes the single rounding of the Long to a Double come out exactly as
        // rounding the whole value would.
        //
        // The bit length is judged from an approximation, which can be one too high or one
        // too low near a power of two. Starting one bit further down than needed keeps the
        // first quotient below 2^62 either way, and the loop then steps up to [2^61, 2^62).
        Integer shift = bitLength(magnitude.toDouble()) - 61;
        JiffI128 scaled = magnitude.divide(JiffI128.valueOf(powerOfTwo(shift)));
        while (scaled.compareTo(JiffI128.valueOf(TWO_POW_61)) < 0) {
            shift--;
            scaled = magnitude.divide(JiffI128.valueOf(powerOfTwo(shift)));
        }
        Long top = scaled.toLong();
        Boolean inexact = !magnitude.subtract(scaled.multiply(powerOfTwo(shift))).isZero();
        if (inexact && JiffMath.truncMod(top, 2L) == 0) {
            top += 1;
        }
        Double result = top;
        Double scale = powerOfTwo(shift);
        result = result * scale;
        return value.isNegative() ? -result : result;
    }

    /** The number of binary digits of a value at least 1, judged from its approximation. */
    private static Integer bitLength(Double approximate) {
        Double one = 1;
        Double two = 2;
        Double rest = approximate;
        Integer bits = 0;
        while (rest >= one) {
            rest = rest / two;
            bits++;
        }
        return bits;
    }

    /** `2^exponent`, for an exponent from 0 to 62. */
    private static Long powerOfTwo(Integer exponent) {
        Long result = 1;
        for (Integer i = 0; i < exponent; i++) {
            result *= 2;
        }
        return result;
    }

    /** Wraps `cause` in the description of the step that failed, the way Jiff chains errors. */
    public static JiffException inContext(String step, JiffException cause) {
        return new JiffException(step + ': ' + cause.getMessage(), cause);
    }
}
