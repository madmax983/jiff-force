/**
 * A span of time expressed in calendar and clock units: years, months, weeks, days, hours,
 * minutes, seconds, milliseconds, microseconds and nanoseconds.
 *
 * A span keeps each unit separately. `1 month` stays `1 month`; it is not converted to a
 * number of days until it is applied to a date, because only then is its length known. This
 * is what makes `2024-01-31 + 1 month = 2024-02-29` work.
 *
 *     JiffSpan span = new JiffSpan().months(1).days(15).hours(4);
 *     span.getMonths();   // 1
 *     span.toString();    // P1M15DT4H
 *
 * ## Sign
 *
 * A span has a single sign shared by all of its units: it is positive, negative or zero as a
 * whole, never a mix. Setting any unit to a negative value makes the whole span negative, so
 * `new JiffSpan().years(1).months(-1)` is `-P1Y1M`, exactly as in Jiff. Getters report each
 * unit with the span's sign applied.
 *
 * ## Equality
 *
 * `equals` compares spans field by field, so `PT60M` and `PT1H` are *not* equal even though
 * they describe the same amount of time. Use `compare` to ask whether two spans are the same
 * length. (This is the comparison Jiff calls `Span::fieldwise`.)
 *
 * Instances are immutable; every setter returns a new span. Values outside a unit's limit
 * throw `JiffException`.
 *
 * Mirrors `jiff::Span`.
 */
public class JiffSpan {
    private static final Integer UNIT_COUNT = 10;

    // Indexed by JiffUnit ordinal: the largest magnitude each unit may hold. The limits are
    // sized so that any two datetimes Jiff supports are a representable span apart.
    private static final List<Long> LIMITS = new List<Long>{
        9223372036854775807L,
        631107417600000000L,
        631107417600000L,
        631107417600L,
        10518456960L,
        175307616L,
        7304484L,
        1043497L,
        239976L,
        19998L
    };

    private static final List<JiffUnit> UNITS = JiffUnit.values();

    // -1, 0 or 1. Zero exactly when every magnitude is zero.
    private final Integer sign;
    // Indexed by JiffUnit ordinal: the magnitude (never negative) of each unit.
    private final List<Long> magnitudes;

    /** Creates a span of zero length. */
    public JiffSpan() {
        this(0, new List<Long>{ 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L });
    }

    private JiffSpan(Integer sign, List<Long> magnitudes) {
        this.sign = sign;
        this.magnitudes = magnitudes;
    }

    // ---- setters --------------------------------------------------------

    public JiffSpan years(Long value) {
        return withUnit(JiffUnit.YEAR, value);
    }

    public JiffSpan months(Long value) {
        return withUnit(JiffUnit.MONTH, value);
    }

    public JiffSpan weeks(Long value) {
        return withUnit(JiffUnit.WEEK, value);
    }

    public JiffSpan days(Long value) {
        return withUnit(JiffUnit.DAY, value);
    }

    public JiffSpan hours(Long value) {
        return withUnit(JiffUnit.HOUR, value);
    }

    public JiffSpan minutes(Long value) {
        return withUnit(JiffUnit.MINUTE, value);
    }

    public JiffSpan seconds(Long value) {
        return withUnit(JiffUnit.SECOND, value);
    }

    public JiffSpan milliseconds(Long value) {
        return withUnit(JiffUnit.MILLISECOND, value);
    }

    public JiffSpan microseconds(Long value) {
        return withUnit(JiffUnit.MICROSECOND, value);
    }

    public JiffSpan nanoseconds(Long value) {
        return withUnit(JiffUnit.NANOSECOND, value);
    }

    /**
     * Returns a copy of this span with `unit` set to `value`.
     *
     * A negative value makes the whole span negative. Setting a unit to zero leaves the sign
     * alone unless that empties the span, in which case it becomes zero.
     */
    public JiffSpan withUnit(JiffUnit unit, Long value) {
        Integer index = unit.ordinal();
        Long max = LIMITS.get(index);
        JiffMath.check(value, -max, max, JiffMath.plural(unit));
        List<Long> next = magnitudes.clone();
        next.set(index, value < 0 ? -value : value);
        return new JiffSpan(resign(value, next), next);
    }

    /** The sign of a span after one of its units was set to `value`. */
    private Integer resign(Long value, List<Long> next) {
        if (value < 0) {
            return -1;
        }
        if (value == 0 && allZero(next)) {
            return 0;
        }
        return sign == 0 ? JiffMath.signum(value) : sign;
    }

    private static Boolean allZero(List<Long> values) {
        for (Long v : values) {
            if (v != 0) {
                return false;
            }
        }
        return true;
    }

    // ---- getters --------------------------------------------------------

    public Long getYears() {
        return get(JiffUnit.YEAR);
    }

    public Long getMonths() {
        return get(JiffUnit.MONTH);
    }

    public Long getWeeks() {
        return get(JiffUnit.WEEK);
    }

    public Long getDays() {
        return get(JiffUnit.DAY);
    }

    public Long getHours() {
        return get(JiffUnit.HOUR);
    }

    public Long getMinutes() {
        return get(JiffUnit.MINUTE);
    }

    public Long getSeconds() {
        return get(JiffUnit.SECOND);
    }

    public Long getMilliseconds() {
        return get(JiffUnit.MILLISECOND);
    }

    public Long getMicroseconds() {
        return get(JiffUnit.MICROSECOND);
    }

    public Long getNanoseconds() {
        return get(JiffUnit.NANOSECOND);
    }

    /**
     * The value of one unit of this span, with the span's sign applied. This is the value of
     * that field alone, not the span's total length in that unit; see `total` for that.
     */
    public Long get(JiffUnit unit) {
        return sign * magnitudes.get(unit.ordinal());
    }

    /** The magnitude of one unit, ignoring the span's sign. */
    public Long getAbs(JiffUnit unit) {
        return magnitudes.get(unit.ordinal());
    }

    // ---- sign -----------------------------------------------------------

    /** -1, 0 or 1 according to whether this span is negative, zero or positive. */
    public Integer signum() {
        return sign;
    }

    public Boolean isPositive() {
        return sign > 0;
    }

    public Boolean isNegative() {
        return sign < 0;
    }

    public Boolean isZero() {
        return sign == 0;
    }

    public JiffSpan abs() {
        return sign < 0 ? new JiffSpan(1, magnitudes) : this;
    }

    public JiffSpan negate() {
        return sign == 0 ? this : new JiffSpan(-sign, magnitudes);
    }

    // ---- arithmetic that needs no reference date -------------------------

    /**
     * Multiplies every unit by `factor`. Throws if any unit would exceed its limit.
     *
     * The units are scaled independently and never rebalanced: `PT40M * 2` is `PT80M`.
     */
    public JiffSpan multiply(Long factor) {
        if (factor == 0 || sign == 0) {
            return new JiffSpan();
        }
        if (factor == 1) {
            return this;
        }
        // Only `Long.MIN` has no absolute value. Jiff reports it as a multiple outside the
        // range of every unit (`rhs.checked_abs().ok_or_else(b::SpanMultiple::error)`).
        if (factor == JiffMath.LONG_MIN) {
            throw JiffMath.rangeError('span multiple', -JiffMath.LONG_MAX, JiffMath.LONG_MAX);
        }
        Long absFactor = factor < 0 ? -factor : factor;
        List<Long> next = magnitudes.clone();
        // From years down to nanoseconds, as Jiff does, so that when several units overflow
        // the error names the largest of them.
        for (Integer i = UNIT_COUNT - 1; i >= 0; i--) {
            Long magnitude = magnitudes.get(i);
            if (magnitude == 0) {
                continue;
            }
            Long max = LIMITS.get(i);
            if (
                JiffMath.greaterThan(absFactor, max) ||
                JiffMath.greaterThan(magnitude, max / absFactor)
            ) {
                throw JiffMath.rangeError(JiffMath.plural(UNITS.get(i)), -max, max);
            }
            next.set(i, magnitude * absFactor);
        }
        return new JiffSpan(factor < 0 ? -sign : sign, next);
    }

    // ---- arithmetic, comparison, totals and rounding ---------------------
    //
    // Days and bigger units have no fixed length, so the operations below need to know where
    // the span starts as soon as one is involved: pass a `JiffSpanRelativeTo`. Without one,
    // only spans of hours and smaller units are accepted. Passing null for the reference is
    // the same as not passing one.

    /**
     * The sum of this span and `other`, balanced so that its biggest unit is the bigger of the
     * two spans' biggest units. Throws when either span has days or bigger units; use
     * `add(other, relative)` for those.
     *
     *     new JiffSpan().hours(2).minutes(59).add(new JiffSpan().minutes(2));   // PT3H1M
     */
    public JiffSpan add(JiffSpan other) {
        return add(other, null);
    }

    /**
     * The sum of this span and `other`, measured from `relative`: this span is added to it,
     * then `other`, and the result is the span from `relative` to where that lands, using
     * units up to the bigger of the two spans' biggest units.
     *
     *     JiffSpan span = new JiffSpan().months(1).days(15);
     *     JiffSpan more = new JiffSpan().days(15);
     *     span.add(more, JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2008, 3, 1)));   // P2M
     *     span.add(more, JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2008, 4, 1)));   // P1M30D
     *
     * Throws when a span has days or bigger units and `relative` is null, when it has months
     * or years and `relative` is `JiffSpanRelativeTo.daysAre24Hours()`, or when a unit of the
     * result, or a datetime along the way, is out of range.
     */
    public JiffSpan add(JiffSpan other, JiffSpanRelativeTo relative) {
        requireArgument(other, 'span to add');
        return addSpan(other, relative);
    }

    /**
     * This span plus an exact duration, balanced so that its biggest unit is this span's.
     * Throws when this span has days or bigger units; use `add(duration, relative)` for those.
     *
     *     new JiffSpan().hours(1).add(JiffSignedDuration.fromMins(30));   // PT1H30M
     */
    public JiffSpan add(JiffSignedDuration duration) {
        return add(duration, null);
    }

    /**
     * This span plus an exact duration, measured from `relative`: the span is added to it,
     * then the duration, and the result is the span from `relative` to where that lands,
     * using units up to this span's biggest unit.
     *
     *     JiffSignedDuration thirtyDays = JiffSignedDuration.fromHours(30 * 24);
     *     new JiffSpan().months(1).add(thirtyDays, JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2024, 3, 1)));
     *     // P2M (April has 30 days)
     *
     * Throws in the same cases as `add(JiffSpan, JiffSpanRelativeTo)`.
     */
    public JiffSpan add(JiffSignedDuration duration, JiffSpanRelativeTo relative) {
        requireArgument(duration, 'duration to add');
        return addDuration(duration, relative);
    }

    /**
     * This span minus `other`: `add(other.negate())`.
     *
     *     new JiffSpan().hours(1).subtract(new JiffSpan().minutes(30));   // PT30M
     */
    public JiffSpan subtract(JiffSpan other) {
        return subtract(other, null);
    }

    /** This span minus `other`, measured from `relative`: `add(other.negate(), relative)`. */
    public JiffSpan subtract(JiffSpan other, JiffSpanRelativeTo relative) {
        requireArgument(other, 'span to subtract');
        return addSpan(other.negate(), relative);
    }

    /**
     * This span minus an exact duration: `add(duration.negate())`. Throws when the duration
     * is `JiffSignedDuration.MIN`, whose negation is out of range.
     */
    public JiffSpan subtract(JiffSignedDuration duration) {
        return subtract(duration, null);
    }

    /** This span minus an exact duration, measured from `relative`. */
    public JiffSpan subtract(JiffSignedDuration duration, JiffSpanRelativeTo relative) {
        requireArgument(duration, 'duration to subtract');
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Jiff negates the duration into an unsigned one, which then does not fit back.
            throw new JiffException(
                'unsigned duration exceeds Jiff\'s limits: ' + signedDurationRange().getMessage()
            );
        }
        return addDuration(duration.negate(), relative);
    }

    private JiffSpan addSpan(JiffSpan other, JiffSpanRelativeTo relative) {
        JiffUnit unit = JiffMath.largerOf(largestUnit(), other.largestUnit());
        JiffSpanRelative start = resolve(relative, unit);
        if (start == null) {
            return addInvariant(unit, other.toInvariantDuration());
        }
        JiffSpanRelative mid = start.add(this);
        return start.until(unit, mid.add(other));
    }

    private JiffSpan addDuration(JiffSignedDuration duration, JiffSpanRelativeTo relative) {
        JiffUnit unit = largestUnit();
        JiffSpanRelative start = resolve(relative, unit);
        if (start == null) {
            return addInvariant(unit, duration);
        }
        JiffSpanRelative mid = start.add(this);
        return start.until(unit, mid.add(duration));
    }

    /** Adds a duration to this span's own exact length, for spans of weeks at most. */
    private JiffSpan addInvariant(JiffUnit unit, JiffSignedDuration duration) {
        JiffSignedDuration sum;
        try {
            sum = toInvariantDuration().add(duration);
        } catch (JiffException e) {
            throw signedDurationRange();
        }
        return fromInvariantDuration(unit, sum);
    }

    private static JiffException signedDurationRange() {
        return JiffMath.rangeError('signed duration seconds', JiffMath.LONG_MIN, JiffMath.LONG_MAX);
    }

    /**
     * The starting point to measure spans up to `unit` from, or null when they can be handled
     * as exact durations. Throws when `unit` needs a reference that `relative` does not give.
     */
    private static JiffSpanRelative resolve(JiffSpanRelativeTo relative, JiffUnit unit) {
        if (relative == null) {
            JiffSpanRelativeTo.requireRelative(unit);
            return null;
        }
        return relative.toRelative(unit);
    }

    /**
     * Compares the lengths of this span and `other`: -1, 0 or 1 as this span is shorter, the
     * same length or longer. Negative spans are shorter than the zero span. Throws when either
     * span has days or bigger units; use `compare(other, relative)` for those.
     *
     * Unlike `equals`, this looks at length only: `PT3H` and `PT180M` compare as 0.
     */
    public Integer compare(JiffSpan other) {
        return compare(other, null);
    }

    /**
     * Compares the lengths of this span and `other`, each measured from `relative`: -1, 0 or
     * 1 as this span ends earlier, at the same instant or later.
     *
     *     JiffZonedDateTime zdt = JiffDate.newInstance(2020, 11, 1).inTz('America/Los_Angeles');
     *     // That day is 25 hours long, so 3 days and 6 hours 50 minutes is longer than 79 hours 10 minutes.
     *     new JiffSpan().days(3).hours(6).minutes(50)
     *         .compare(new JiffSpan().hours(79).minutes(10), JiffSpanRelativeTo.fromZonedDateTime(zdt));   // 1
     *
     * Throws when a span has days or bigger units and `relative` is null, when it has months
     * or years and `relative` is `JiffSpanRelativeTo.daysAre24Hours()`, or when adding a span
     * to `relative` goes out of range.
     */
    public Integer compare(JiffSpan other, JiffSpanRelativeTo relative) {
        requireArgument(other, 'span to compare with');
        JiffUnit unit = JiffMath.largerOf(largestUnit(), other.largestUnit());
        JiffSpanRelative start = resolve(relative, unit);
        if (start == null) {
            return toInvariantDuration().compareTo(other.toInvariantDuration());
        }
        JiffSignedDuration end1 = start.add(this).toDuration();
        JiffSignedDuration end2 = start.add(other).toDuration();
        return end1.compareTo(end2);
    }

    /**
     * The length of this span in `unit`, as a fraction. Throws when the span or `unit` is a
     * day or bigger; use `total(unit, relative)` for those.
     *
     *     new JiffSpan().hours(3).minutes(10).total(JiffUnit.SECOND);   // 11400.0
     */
    public Double total(JiffUnit unit) {
        return total(unit, null);
    }

    /**
     * The length of this span in `unit`, measured from `relative`, as a fraction. A month or
     * a year counts the calendar's months or years from `relative`; from a zoned datetime a
     * day is as long as that day really is.
     *
     *     JiffZonedDateTime march = JiffDate.newInstance(2024, 3, 1).inTz('America/New_York');
     *     // March 2024 there had a 23 hour day, so 744 hours is a little more than its 31 days.
     *     new JiffSpan().hours(744).total(JiffUnit.MONTH, JiffSpanRelativeTo.fromZonedDateTime(march));
     *     // 1.0013888888888889
     *
     * The division is done in 64 bit floating point at the end, exactly as Jiff does it, so
     * the result matches Jiff's to the last bit. Throws when the span or `unit` is a day or
     * bigger and `relative` is null, when either is a month or year and `relative` is
     * `JiffSpanRelativeTo.daysAre24Hours()`, or when a datetime along the way is out of range.
     */
    public Double total(JiffUnit unit, JiffSpanRelativeTo relative) {
        requireArgument(unit, 'unit to total');
        JiffSpanRelative start = resolve(relative, JiffMath.largerOf(unit, largestUnit()));
        if (start == null) {
            return JiffSpanRelative.totalInvariant(this, unit);
        }
        return start.total(this, unit);
    }

    /**
     * This span rounded to a multiple of `smallest` with `JiffRoundMode.HALF_EXPAND`:
     * `round(JiffSpanRound.to(smallest))`.
     *
     *     new JiffSpan().hours(1).minutes(59).round(JiffUnit.HOUR);   // PT2H
     */
    public JiffSpan round(JiffUnit smallest) {
        return round(JiffSpanRound.to(smallest));
    }

    /**
     * This span balanced and rounded as `options` say: units smaller than its smallest unit
     * are rounded away, units bigger than its largest unit are folded into it, and units in
     * between carry over into the next one up as they fill. See `JiffSpanRound`.
     *
     *     new JiffSpan().nanoseconds(123456789123456789L).round(new JiffSpanRound().largest(JiffUnit.HOUR));
     *     // PT34293H33M9.123456789S
     *
     * Throws when the increment is not valid for the smallest unit, when the largest unit is
     * smaller than the smallest unit, when days or bigger units are involved (in the span or
     * in the options) without a reference point in `options`, and when the result does not fit.
     */
    public JiffSpan round(JiffSpanRound options) {
        requireArgument(options, 'rounding options');
        JiffUnit smallest = options.getSmallest();
        JiffUnit existingLargest = largestUnit();
        JiffUnit largest = options.getLargest() != null
            ? options.getLargest()
            : JiffMath.largerOf(smallest, existingLargest);
        JiffUnit max = JiffMath.largerOf(existingLargest, largest);
        Long increment;
        try {
            increment = JiffRounding.incrementForSpan(smallest, options.getIncrement());
        } catch (JiffException e) {
            throw JiffSpanRelative.inContext('failed rounding span', e);
        }
        if (JiffMath.isLarger(smallest, largest)) {
            throw new JiffException(
                'largest unit (\'' +
                    JiffMath.singular(largest) +
                    '\') cannot be smaller than smallest unit (\'' +
                    JiffMath.singular(smallest) +
                    '\')'
            );
        }
        JiffRoundMode mode = options.getMode();
        JiffSpanRelativeTo relative = options.getRelative();
        if (relative == null) {
            // Without a reference point, only units of a fixed length can be involved.
            requireRelativeFor(smallest, 'error with `smallest` rounding option');
            if (options.getLargest() != null) {
                requireRelativeFor(options.getLargest(), 'error with `largest` rounding option');
            }
            requireRelativeFor(existingLargest, 'error with largest unit in span to be rounded');
            return JiffSpanNudge.roundInvariant(this, largest, smallest, increment, mode);
        }
        JiffSpanRelative start = relative.toRelative(max);
        if (start == null) {
            // Every unit involved has a fixed length from this reference, so the span can be
            // rounded as one exact duration.
            return JiffSpanNudge.roundInvariant(this, largest, smallest, increment, mode);
        }
        return start.round(this, largest, smallest, increment, mode);
    }

    private static void requireRelativeFor(JiffUnit unit, String option) {
        try {
            JiffSpanRelativeTo.requireRelative(unit);
        } catch (JiffException e) {
            throw JiffSpanRelative.inContext(option, e);
        }
    }

    /**
     * The exact length of this span. Days and bigger units have no fixed length on their own,
     * so this throws when the span has any; use `toDuration(relative)` for those.
     *
     *     new JiffSpan().hours(1).minutes(30).toDuration();   // PT1H30M
     *
     * Mirrors `TryFrom<Span> for SignedDuration`. A signed duration can hold any span of
     * hours and smaller units, so nothing else can fail.
     */
    public JiffSignedDuration toDuration() {
        try {
            JiffSpanRelativeTo.requireRelative(largestUnit());
        } catch (JiffException e) {
            throw JiffSpanRelative.inContext(
                'failed to convert span to duration without relative datetime ' +
                '(must use `JiffSpan.toDuration(JiffSpanRelativeTo)` instead)',
                e
            );
        }
        return toInvariantDuration();
    }

    /**
     * The exact length of this span, measured from `relative`.
     *
     *     JiffSpan year = new JiffSpan().years(1);
     *     year.toDuration(JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2024, 1, 1)));   // PT8784H
     *     year.toDuration(JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2023, 1, 1)));   // PT8760H
     *     new JiffSpan().weeks(1).days(1).toDuration(JiffSpanRelativeTo.daysAre24Hours());   // PT192H
     *
     * A null `relative` is the same as `toDuration()`. Throws when the span has months or
     * years and `relative` is `JiffSpanRelativeTo.daysAre24Hours()`, or when adding the span
     * to `relative` goes out of range.
     */
    public JiffSignedDuration toDuration(JiffSpanRelativeTo relative) {
        if (relative == null) {
            return toDuration();
        }
        try {
            JiffSpanRelative start = relative.toRelative(largestUnit());
            if (start == null) {
                return toInvariantDuration();
            }
            return start.until(JiffUnit.SECOND, start.add(this)).toInvariantDuration();
        } catch (JiffException e) {
            String origin = relative.isDaysAre24Hours()
                ? 'when all days are assumed to be 24 hours'
                : relative.getDateTime() != null ? 'from civil datetime' : 'from zoned datetime';
            throw JiffSpanRelative.inContext(
                'could not compute normalized relative span ' + origin,
                e
            );
        }
    }

    private static void requireArgument(Object value, String what) {
        if (value == null) {
            throw new JiffException('the ' + what + ' must not be null');
        }
    }

    // ---- structure (internal helpers shared with the other jiff-force types) ----

    /** Whether `unit` is non-zero in this span. */
    public Boolean hasUnit(JiffUnit unit) {
        return magnitudes.get(unit.ordinal()) != 0;
    }

    /** The largest non-zero unit, or nanoseconds for a zero span. */
    public JiffUnit largestUnit() {
        for (Integer i = UNIT_COUNT - 1; i >= 0; i--) {
            if (magnitudes.get(i) != 0) {
                return UNITS.get(i);
            }
        }
        return JiffUnit.NANOSECOND;
    }

    /** The smallest non-zero unit, or nanoseconds for a zero span. */
    public JiffUnit smallestUnit() {
        for (Integer i = 0; i < UNIT_COUNT; i++) {
            if (magnitudes.get(i) != 0) {
                return UNITS.get(i);
            }
        }
        return JiffUnit.NANOSECOND;
    }

    /** The largest non-zero calendar unit (days and above), or null when there is none. */
    public JiffUnit largestCalendarUnit() {
        for (Integer i = UNIT_COUNT - 1; i >= JiffUnit.DAY.ordinal(); i--) {
            if (magnitudes.get(i) != 0) {
                return UNITS.get(i);
            }
        }
        return null;
    }

    /** Whether any of hours through nanoseconds is non-zero. */
    public Boolean hasTimeUnits() {
        for (Integer i = 0; i < JiffUnit.DAY.ordinal(); i++) {
            if (magnitudes.get(i) != 0) {
                return true;
            }
        }
        return false;
    }

    /** Whether any of days through years is non-zero. */
    public Boolean hasCalendarUnits() {
        return largestCalendarUnit() != null;
    }

    /** Whether milliseconds, microseconds or nanoseconds is non-zero. */
    public Boolean hasFractionalSeconds() {
        return magnitudes.get(0) != 0 || magnitudes.get(1) != 0 || magnitudes.get(2) != 0;
    }

    /** This span with hours through nanoseconds cleared. */
    public JiffSpan onlyCalendar() {
        return keep(JiffUnit.DAY.ordinal(), UNIT_COUNT - 1);
    }

    /** This span with days through years cleared. */
    public JiffSpan onlyTime() {
        return keep(0, JiffUnit.HOUR.ordinal());
    }

    /** This span with `unit` and everything larger cleared. */
    public JiffSpan onlyLower(JiffUnit unit) {
        return keep(0, unit.ordinal() - 1);
    }

    /** This span with everything smaller than `unit` cleared. */
    public JiffSpan withoutLower(JiffUnit unit) {
        return keep(unit.ordinal(), UNIT_COUNT - 1);
    }

    /** Keeps the units whose ordinals lie in `first..last` and zeroes the rest. */
    private JiffSpan keep(Integer first, Integer last) {
        List<Long> next = new List<Long>();
        Boolean anyLeft = false;
        for (Integer i = 0; i < UNIT_COUNT; i++) {
            Long magnitude = i >= first && i <= last ? magnitudes.get(i) : 0L;
            anyLeft = anyLeft || magnitude != 0;
            next.add(magnitude);
        }
        return new JiffSpan(anyLeft ? sign : 0, next);
    }

    /** Hours, minutes and seconds expressed as a signed number of seconds. */
    public Long toHmsSeconds() {
        return sign *
            (getAbs(JiffUnit.SECOND) +
            getAbs(JiffUnit.MINUTE) * 60L +
            getAbs(JiffUnit.HOUR) * 3600L);
    }

    /**
     * The length of this span assuming weeks are seven days and days are twenty four hours.
     * Years and months are ignored; callers must already have dealt with them.
     */
    public JiffSignedDuration toInvariantDuration() {
        return JiffSignedDuration.fromSecs(
                get(JiffUnit.WEEK) * JiffMath.SECS_PER_CIVIL_WEEK +
                    get(JiffUnit.DAY) * JiffMath.SECS_PER_CIVIL_DAY
            )
            .add(toInvariantDurationTimeOnly());
    }

    /** The length of the hours through nanoseconds of this span. */
    public JiffSignedDuration toInvariantDurationTimeOnly() {
        return JiffSignedDuration.fromSecs(
                get(JiffUnit.HOUR) * 3600L + get(JiffUnit.MINUTE) * 60L + get(JiffUnit.SECOND)
            )
            .add(JiffSignedDuration.fromMillis(get(JiffUnit.MILLISECOND)))
            .add(JiffSignedDuration.fromMicros(get(JiffUnit.MICROSECOND)))
            .add(JiffSignedDuration.fromNanos(get(JiffUnit.NANOSECOND)));
    }

    /**
     * Spreads a duration across the units from `largest` (weeks at most) down to nanoseconds,
     * assuming seven day weeks and twenty four hour days. Throws if a unit overflows its limit.
     */
    public static JiffSpan fromInvariantDuration(JiffUnit largest, JiffSignedDuration duration) {
        JiffSpan span = new JiffSpan();
        Long secs = duration.asSecs();
        Long nanos = duration.subsecNanos();
        Integer top = largest.ordinal();
        if (largest == JiffUnit.WEEK) {
            span = span.weeks(secs / JiffMath.SECS_PER_CIVIL_WEEK);
            secs = JiffMath.truncMod(secs, JiffMath.SECS_PER_CIVIL_WEEK);
        }
        if (top >= JiffUnit.DAY.ordinal()) {
            span = span.days(secs / JiffMath.SECS_PER_CIVIL_DAY);
            secs = JiffMath.truncMod(secs, JiffMath.SECS_PER_CIVIL_DAY);
        }
        if (top >= JiffUnit.HOUR.ordinal()) {
            span = span.hours(secs / 3600L);
            secs = JiffMath.truncMod(secs, 3600L);
        }
        if (top >= JiffUnit.MINUTE.ordinal()) {
            span = span.minutes(secs / 60L);
            secs = JiffMath.truncMod(secs, 60L);
        }
        if (top >= JiffUnit.SECOND.ordinal()) {
            span = span.seconds(secs);
            secs = 0L;
        }
        // What remains is `secs` whole seconds plus `nanos`, to be expressed in sub-second
        // units. Each conversion checks the unit's limit before multiplying.
        if (top >= JiffUnit.MILLISECOND.ordinal()) {
            span = span.milliseconds(scaled(secs, 1000L, nanos / 1000000L, JiffUnit.MILLISECOND));
            secs = 0L;
            nanos = JiffMath.truncMod(nanos, 1000000L);
        }
        if (top >= JiffUnit.MICROSECOND.ordinal()) {
            span = span.microseconds(scaled(secs, 1000000L, nanos / 1000L, JiffUnit.MICROSECOND));
            secs = 0L;
            nanos = JiffMath.truncMod(nanos, 1000L);
        }
        return span.nanoseconds(scaled(secs, 1000000000L, nanos, JiffUnit.NANOSECOND));
    }

    /** `secs * perSecond + extra`, or a range error for `unit` if that overflows its limit. */
    private static Long scaled(Long secs, Long perSecond, Long extra, JiffUnit unit) {
        Long max = LIMITS.get(unit.ordinal());
        // `extra` is less than a second in magnitude, so its absolute value is safe to take.
        // `secs` may be `Long.MIN`, which has none, so it is compared against both ends of
        // the range instead. The two never differ in sign, so the sum is within `max`
        // exactly when `secs` is within `bound`.
        Long bound = (max - JiffMath.abs(extra)) / perSecond;
        if (JiffMath.greaterThan(secs, bound) || JiffMath.lessThan(secs, -bound)) {
            throw JiffMath.rangeError(JiffMath.plural(unit), -max, max);
        }
        return secs * perSecond + extra;
    }

    /**
     * Converts an absolute duration to a span of seconds, milliseconds, microseconds and
     * nanoseconds. Throws if the seconds exceed what a span can hold.
     */
    public static JiffSpan fromDuration(JiffSignedDuration duration) {
        Long nanos = duration.subsecNanos();
        return new JiffSpan()
            .seconds(duration.asSecs())
            .milliseconds(nanos / 1000000L)
            .microseconds(JiffMath.truncMod(nanos, 1000000L) / 1000L)
            .nanoseconds(JiffMath.truncMod(nanos, 1000L));
    }

    // ---- equality and text ----------------------------------------------

    /** Field by field equality. `PT60M` does not equal `PT1H`; see the class notes. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffSpan)) {
            return false;
        }
        JiffSpan that = (JiffSpan) other;
        if (sign != that.sign) {
            return false;
        }
        for (Integer i = 0; i < UNIT_COUNT; i++) {
            if (magnitudes.get(i) != that.magnitudes.get(i)) {
                return false;
            }
        }
        return true;
    }

    public Integer hashCode() {
        Long hash = sign + 2;
        for (Integer i = 0; i < UNIT_COUNT; i++) {
            hash = JiffMath.floorMod(
                hash * 31 + JiffMath.floorMod(magnitudes.get(i), 1000000007L),
                1000000007L
            );
        }
        return hash.intValue();
    }

    /** Formats this span as an ISO 8601 duration, for example `P1Y2M3DT4H5M6.5S`. */
    public override String toString() {
        return JiffTemporal.printSpan(this);
    }

    /**
     * Parses a span from either an ISO 8601 duration (`P1Y2M3DT4H5M6S`) or a friendly duration
     * (`1 year, 2 months, 3 days, 4h 5m 6s`).
     *
     * Text that starts with `P` or `p`, optionally after a sign, is read as ISO 8601;
     * anything else is read as the friendly format. Each unit is kept as written. Throws
     * `JiffException` when the text is neither, or a unit is beyond what a span holds.
     *
     *     JiffSpan.parse('P2M35DT2H30M');                  // 2 months 35 days 2 hours 30 minutes
     *     JiffSpan.parse('2 months, 35 days, 02:30:00');   // the same span
     *     JiffSpan.parse('3d ago');                        // -P3D
     *
     * See `JiffTemporal.parseSpan` and `JiffFriendly` for the two formats.
     */
    public static JiffSpan parse(String text) {
        return JiffFriendly.parseIsoOrFriendlySpan(text);
    }

    /**
     * Formats this span in the friendly format, for example `1y 2mo 15h 30s` or `3d ago`.
     *
     * Unlike `toString()`, the result names every unit separately, so `parse` reads it back
     * as exactly this span. Use `JiffFriendlyPrinter` for other styles, such as
     * `1 year, 2 months`.
     */
    public String toFriendly() {
        return JiffFriendly.printSpan(this);
    }
}
