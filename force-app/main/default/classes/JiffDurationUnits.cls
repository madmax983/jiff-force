/**
 * The unit values of a duration while it is being parsed. Internal: not part of the public API.
 *
 * Both duration formats (ISO 8601 in `JiffTemporal`, friendly in `JiffFriendlyParser`) parse
 * into this builder and then ask it for a `JiffSpan` or a `JiffSignedDuration`, so the rules
 * the formats share live here: units must appear from largest to smallest, a fraction belongs
 * to the smallest unit and is carried down into the units below it, and a time unit that is
 * too big for a span spills over into smaller units instead of failing.
 *
 * Each value is kept as an unsigned magnitude and the sign is applied at the end. That is what
 * lets `9223372036854775808 seconds ago` parse: the magnitude does not fit in a `Long`, but
 * its negation does.
 *
 * Unlike the value types this class is a mutable builder; it never leaves the parser that
 * created it.
 *
 * Mirrors `jiff::fmt::util::DurationUnits`.
 */
public class JiffDurationUnits {
    private static final List<JiffUnit> UNITS = JiffUnit.values();
    private static final Integer HOUR_ORDINAL = JiffUnit.HOUR.ordinal();
    private static final Integer DAY_ORDINAL = JiffUnit.DAY.ordinal();

    // Indexed by JiffUnit ordinal: the largest magnitude a span holds for nanoseconds through
    // hours. A parsed time unit beyond its limit is carried into the units below it.
    private static final List<Long> SPAN_MAX = new List<Long>{
        9223372036854775807L,
        631107417600000000L,
        631107417600000L,
        631107417600L,
        10518456960L,
        175307616L
    };

    private static final String INVALID_FRACTION_NANOS = 'failed to set nanosecond value from fractional component';

    // Indexed by JiffUnit ordinal: the unsigned value parsed for each unit.
    private final List<JiffI128> values = new List<JiffI128>{
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO,
        JiffI128.ZERO
    };
    // The fraction of the smallest unit in billionths, or -1 when there is none.
    private Integer fraction = -1;
    private Integer sign = 0;
    // The smallest and largest units set so far; null until the first one is.
    private JiffUnit minUnit;
    private JiffUnit maxUnit;
    private Boolean anyNonZero = false;

    /**
     * Records the unsigned value of one unit. Units must be set from largest to smallest and
     * at most once each; anything else throws.
     */
    public void setUnitValue(JiffUnit unit, JiffI128 value) {
        if (minUnit != null && minUnit.ordinal() <= unit.ordinal()) {
            throw new JiffException(
                'found value with unit ' +
                    JiffMath.singular(unit) +
                    ' after unit ' +
                    JiffMath.singular(minUnit) +
                    ', but units must be written from largest to smallest ' +
                    '(and they can\'t be repeated)'
            );
        }
        minUnit = unit;
        if (maxUnit == null) {
            maxUnit = unit;
        }
        values.set(unit.ordinal(), value);
        anyNonZero = anyNonZero || !value.isZero();
    }

    /**
     * Records hours, minutes and seconds parsed from the `HH:MM:SS` form, with the fraction of
     * a second in billionths or -1 for none. Throws when a unit of hours or smaller was
     * already set.
     */
    public void setHms(JiffI128 hours, JiffI128 minutes, JiffI128 seconds, Integer fraction) {
        if (minUnit != null && minUnit.ordinal() <= HOUR_ORDINAL) {
            throw new JiffException(
                'found `HH:MM:SS` after unit ' +
                    JiffMath.singular(minUnit) +
                    ', but `HH:MM:SS` can only appear after years, months, weeks or days'
            );
        }
        setUnitValue(JiffUnit.HOUR, hours);
        setUnitValue(JiffUnit.MINUTE, minutes);
        setUnitValue(JiffUnit.SECOND, seconds);
        if (fraction >= 0) {
            setFraction(fraction);
        }
    }

    /**
     * Records a fraction, in billionths (`0..999999999`), of the smallest unit set so far.
     * Call it after the last `setUnitValue`. Only hours through microseconds may have one.
     */
    public void setFraction(Integer fraction) {
        if (
            minUnit != null && (minUnit.ordinal() > HOUR_ORDINAL || minUnit == JiffUnit.NANOSECOND)
        ) {
            throw new JiffException(
                'fractional ' + JiffMath.plural(minUnit) + ' are not supported'
            );
        }
        this.fraction = fraction;
        anyNonZero = anyNonZero || fraction != 0;
    }

    /** Sets the sign of the whole duration: -1 or 1. A duration of all zeros stays zero. */
    public void setSign(Integer sign) {
        this.sign = sign;
    }

    /** The smallest unit set so far, or null when none has been. */
    public JiffUnit getMin() {
        return minUnit;
    }

    /**
     * Builds a span from the units collected. Throws when no unit was set, when a calendar
     * unit exceeds its limit, or when the time units are together too long for a span.
     */
    public JiffSpan toSpan() {
        requireUnits();
        JiffSpan span = new JiffSpan();
        for (Integer i = JiffUnit.YEAR.ordinal(); i >= 0; i--) {
            if (values.get(i).isZero()) {
                continue;
            }
            JiffUnit unit = UNITS.get(i);
            Long value = signedValue(unit);
            try {
                span = i >= DAY_ORDINAL
                    ? span.withUnit(unit, value)
                    : withTimeUnit(span, unit, value);
            } catch (JiffException e) {
                throw new JiffException(
                    'failed to set value for ' +
                        JiffMath.singular(unit) +
                        ' unit on span: ' +
                        e.getMessage(),
                    e
                );
            }
        }
        if (fraction >= 0) {
            // The whole part of the smallest unit was set above.
            span = fractionalTimeToSpan(minUnit, 0L, signedFraction(), span);
        }
        return span;
    }

    /**
     * Builds a signed duration from the units collected. Throws when no unit was set, when a
     * calendar unit (days or larger) was set, or when the total overflows.
     */
    public JiffSignedDuration toSignedDuration() {
        requireUnits();
        if (maxUnit.ordinal() > HOUR_ORDINAL) {
            throw new JiffException(
                'parsing calendar units (' +
                    JiffMath.plural(maxUnit) +
                    ' in this case) in this context is not supported ' +
                    '(perhaps try parsing into a `JiffSpan` instead)'
            );
        }
        JiffSignedDuration total = JiffSignedDuration.ZERO;
        for (Integer i = HOUR_ORDINAL; i >= 0; i--) {
            if (values.get(i).isZero()) {
                continue;
            }
            JiffUnit unit = UNITS.get(i);
            Long value = signedValue(unit);
            try {
                total = total.add(unitDuration(unit, value));
            } catch (JiffException e) {
                throw new JiffException(
                    'accumulated duration overflowed when adding value to unit ' +
                    JiffMath.singular(unit),
                    e
                );
            }
        }
        if (fraction >= 0) {
            try {
                total = total.add(
                    JiffSignedDuration.fromNanos(fractionNanos(minUnit, signedFraction()))
                );
            } catch (JiffException e) {
                throw new JiffException(
                    'accumulated duration overflowed when adding fractional value to unit ' +
                    JiffMath.singular(minUnit),
                    e
                );
            }
        }
        return total;
    }

    private void requireUnits() {
        if (minUnit == null) {
            throw new JiffException('no parsed duration components');
        }
    }

    /** The sign applied to each unit: zero unless something non-zero was parsed. */
    private Integer effectiveSign() {
        return anyNonZero ? sign : 0;
    }

    /** The value of `unit` with the sign applied. Throws when it does not fit in a `Long`. */
    private Long signedValue(JiffUnit unit) {
        JiffI128 value = values.get(unit.ordinal());
        if (effectiveSign() < 0) {
            value = value.negate();
        }
        if (!value.fitsLong()) {
            throw new JiffException(
                'value for ' +
                    JiffMath.plural(unit) +
                    ' is too big (or small) to fit into a signed 64-bit integer'
            );
        }
        return value.toLong();
    }

    private Integer signedFraction() {
        return effectiveSign() < 0 ? -fraction : fraction;
    }

    /**
     * Adds `value` to a time unit of `span`. A unit below hours may already hold what a bigger
     * unit could not, so the value is added to it rather than replacing it. When the sum is
     * beyond the unit's limit, the excess is carried into the units below.
     */
    private static JiffSpan withTimeUnit(JiffSpan span, JiffUnit unit, Long value) {
        Long max = SPAN_MAX.get(unit.ordinal());
        Long existing = span.get(unit);
        // Every unit of a parsed duration has the same sign, so the magnitudes add.
        Boolean fits =
            value != JiffMath.LONG_MIN &&
            !JiffMath.greaterThan(JiffMath.abs(value), max - JiffMath.abs(existing));
        if (fits) {
            return span.withUnit(unit, value + existing);
        }
        if (unit == JiffUnit.NANOSECOND) {
            // There is nothing smaller to carry into.
            throw JiffMath.rangeError(JiffMath.plural(unit), -max, max);
        }
        return fractionalTimeToSpan(unit, value, 0, span);
    }

    /**
     * Adds `value` plus `fraction` billionths of `unit` to `span`, spread over `unit` and the
     * units below it. For example an hour value of 1 with a fraction of 500,000,000 adds one
     * hour and thirty minutes.
     *
     * The result is balanced when it can be. When a unit would exceed its limit it is pinned
     * to the limit and the excess moves down, which is how a span whose seconds, milliseconds
     * and microseconds are all at their maximum survives being written as fractional seconds
     * and read back. Throws when even the nanoseconds cannot absorb what is left.
     */
    private static JiffSpan fractionalTimeToSpan(
        JiffUnit unit,
        Long value,
        Integer fraction,
        JiffSpan span
    ) {
        Long perUnitNanos = JiffMath.nanosPerUnit(unit);
        if (
            unit.ordinal() > JiffUnit.SECOND.ordinal() &&
            !JiffMath.mulFits(value, perUnitNanos / JiffMath.NANOS_PER_SEC)
        ) {
            // Jiff converts the value to a signed duration first, whose seconds are 64 bit.
            // Only a count of hours or minutes can be too large for that.
            throw new JiffException(
                'converting ' +
                    JiffMath.plural(unit) +
                    ' to seconds overflows a signed 64-bit integer'
            );
        }
        // Everything is switched over to nanoseconds and then dealt out again.
        JiffI128 rest = JiffI128.product(value, perUnitNanos).add(fractionNanos(unit, fraction));
        JiffSpan out = span;
        for (Integer i = unit.ordinal(); i > 0 && !rest.isZero(); i--) {
            JiffUnit stage = UNITS.get(i);
            Long perUnit = JiffMath.nanosPerUnit(stage);
            List<JiffI128> parts = rest.divRem(JiffI128.valueOf(perUnit));
            JiffI128 count = parts.get(0).add(out.get(stage));
            rest = parts.get(1);
            JiffI128 max = JiffI128.valueOf(SPAN_MAX.get(i));
            if (count.compareTo(max) > 0) {
                rest = rest.add(count.subtract(max).multiply(perUnit));
                count = max;
            } else if (count.compareTo(max.negate()) < 0) {
                rest = rest.add(count.add(max).multiply(perUnit));
                count = max.negate();
            }
            out = out.withUnit(stage, count.toLong());
        }
        if (rest.isZero()) {
            return out;
        }
        JiffI128 nanos = rest.add(out.get(JiffUnit.NANOSECOND));
        if (!nanos.fitsLong()) {
            throw new JiffException(INVALID_FRACTION_NANOS);
        }
        try {
            return out.withUnit(JiffUnit.NANOSECOND, nanos.toLong());
        } catch (JiffException e) {
            throw new JiffException(INVALID_FRACTION_NANOS + ': ' + e.getMessage(), e);
        }
    }

    /**
     * The nanoseconds in `fraction` billionths of `unit`, which is one of hours through
     * microseconds (`setFraction` allows nothing else). Fractions of a millisecond or
     * microsecond finer than a nanosecond are truncated.
     */
    private static Long fractionNanos(JiffUnit unit, Integer fraction) {
        Long billionths = fraction;
        if (unit == JiffUnit.HOUR) {
            return billionths * 3600L;
        }
        if (unit == JiffUnit.MINUTE) {
            return billionths * 60L;
        }
        if (unit == JiffUnit.SECOND) {
            return billionths;
        }
        if (unit == JiffUnit.MILLISECOND) {
            return billionths / 1000L;
        }
        return billionths / 1000000L;
    }

    /** `value` of a time unit as a duration. Throws when hours or minutes overflow. */
    private static JiffSignedDuration unitDuration(JiffUnit unit, Long value) {
        switch on unit {
            when HOUR {
                return JiffSignedDuration.fromHours(value);
            }
            when MINUTE {
                return JiffSignedDuration.fromMins(value);
            }
            when SECOND {
                return JiffSignedDuration.fromSecs(value);
            }
            when MILLISECOND {
                return JiffSignedDuration.fromMillis(value);
            }
            when MICROSECOND {
                return JiffSignedDuration.fromMicros(value);
            }
            when else {
                return JiffSignedDuration.fromNanos(value);
            }
        }
    }
}
