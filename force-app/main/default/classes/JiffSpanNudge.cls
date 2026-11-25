/**
 * Internal: the core of span rounding. Not part of the public API.
 *
 * Rounding a span first balances it from its starting point (see `JiffSpanRelative.round`),
 * then "nudges" its smallest unit to the rounded value. A nudge records the rounded span, the
 * instant the rounded span ends at, and whether rounding pushed it past a whole unit, in which
 * case `bubble` carries that into the bigger units.
 *
 * There are three ways to nudge:
 *
 * - `relativeInvariant` for units of a fixed length: round the exact duration.
 * - `relativeCalendar` for calendar units: measure how long one increment of the unit is from
 *   where the span has reached, and round the progress made through it.
 * - `relativeZonedTime` for time units in a span with days in a time zone: round the time of
 *   day, then let it spill into the next day only if it passes that day's real length.
 *
 * Mirrors Jiff's private `Nudge`, `round_span_invariant` and `unit_start_and_end`.
 */
public class JiffSpanNudge {
    private final JiffSpan span;
    private final JiffSignedDuration roundedRelativeEnd;
    private final Boolean grewBigUnit;

    private JiffSpanNudge(
        JiffSpan span,
        JiffSignedDuration roundedRelativeEnd,
        Boolean grewBigUnit
    ) {
        this.span = span;
        this.roundedRelativeEnd = roundedRelativeEnd;
        this.grewBigUnit = grewBigUnit;
    }

    /**
     * Rounds a balanced span whose smallest unit (days at most) has a fixed length.
     *
     * @param balanced    the span, balanced from its starting point
     * @param relativeEnd the instant the span ends at
     */
    public static JiffSpanNudge relativeInvariant(
        JiffSpan balanced,
        JiffSignedDuration relativeEnd,
        JiffUnit largest,
        JiffUnit smallest,
        Long increment,
        JiffRoundMode mode
    ) {
        Integer sign = balanced.signum();
        JiffSignedDuration balancedNanos = balanced.toInvariantDuration();
        JiffSignedDuration roundedNanos = JiffRounding.roundDuration(
            mode,
            balancedNanos,
            smallest,
            increment
        );
        JiffSpan rounded = fromRoundedNanos(largest, roundedNanos)
            .years(balanced.getYears())
            .months(balanced.getMonths())
            .weeks(balanced.getWeeks());
        JiffSignedDuration diffNanos = roundedNanos.subtract(balancedNanos);
        Long diffDays = civilDays(roundedNanos) - civilDays(balancedNanos);
        Boolean grew = JiffMath.signum(diffDays) == sign;
        return new JiffSpanNudge(rounded, relativeEnd.add(diffNanos), grew);
    }

    /**
     * Rounds a balanced span to a calendar unit (or, from a zoned starting point, to days),
     * whose length depends on where the span has got to.
     */
    public static JiffSpanNudge relativeCalendar(
        JiffSpan balanced,
        JiffSpanRelative relativeStart,
        JiffSpanRelative relativeEnd,
        JiffUnit smallest,
        Long increment,
        JiffRoundMode mode
    ) {
        Integer sign = balanced.signum();
        // Start from the whole increments the span already has, dropping everything smaller.
        Long truncated = increment * (balanced.get(smallest) / increment);
        JiffSpan start = balanced.withoutLower(smallest).withUnit(smallest, truncated);
        // Measure one increment from there, in the direction of the span.
        List<JiffSignedDuration> bounds = unitStartAndEnd(
            relativeStart,
            start,
            smallest,
            sign * increment
        );
        JiffSignedDuration relative0 = bounds.get(0);
        JiffSignedDuration relative1 = bounds.get(1);
        JiffSignedDuration progressNanos = relativeEnd.toDuration().subtract(relative0);
        JiffSignedDuration incrementNanos = relative1.subtract(relative0).abs();
        JiffSignedDuration roundedNanos = roundByDuration(mode, progressNanos, incrementNanos);
        Boolean grew = sign == roundedNanos.subtract(progressNanos).signum();
        // Both lengths are whole seconds: offsets never change at a finer precision.
        Long increments = roundedNanos.asSecs() / incrementNanos.asSecs();
        String what = JiffMath.plural(smallest);
        Long units = JiffMath.checkedAdd(
            truncated,
            JiffMath.checkedMul(increment, increments, what),
            what
        );
        return new JiffSpanNudge(
            start.withUnit(smallest, units),
            grew ? relative1 : relative0,
            grew
        );
    }

    /**
     * Rounds the time units of a balanced span that has days measured in a time zone. The
     * rounded time of day only carries into a day when it reaches that day's real length.
     */
    public static JiffSpanNudge relativeZonedTime(
        JiffSpan balanced,
        JiffSpanRelative relativeStart,
        JiffUnit smallest,
        Long increment,
        JiffRoundMode mode
    ) {
        Integer sign = balanced.signum();
        JiffSignedDuration timeNanos = balanced.onlyLower(JiffUnit.DAY).toInvariantDuration();
        JiffSignedDuration roundedTimeNanos = JiffRounding.roundDuration(
            mode,
            timeNanos,
            smallest,
            increment
        );
        List<JiffSignedDuration> bounds = unitStartAndEnd(
            relativeStart,
            balanced.withoutLower(JiffUnit.DAY),
            JiffUnit.DAY,
            sign
        );
        JiffSignedDuration relative0 = bounds.get(0);
        JiffSignedDuration relative1 = bounds.get(1);
        JiffSignedDuration dayNanos = relative1.subtract(relative0);
        JiffSignedDuration beyondDayNanos = roundedTimeNanos.subtract(dayNanos);
        Long dayDelta = 0;
        JiffSignedDuration roundedRelativeEnd;
        if (beyondDayNanos.isZero() || beyondDayNanos.signum() == sign) {
            dayDelta += 1;
            roundedTimeNanos = JiffRounding.roundDuration(
                mode,
                beyondDayNanos,
                smallest,
                increment
            );
            roundedRelativeEnd = relative1.add(roundedTimeNanos);
        } else {
            roundedRelativeEnd = relative0.add(roundedTimeNanos);
        }
        // As in Jiff, the extra day is added as +1 whatever the span's sign.
        JiffSpan rounded = fromRoundedNanos(JiffUnit.HOUR, roundedTimeNanos)
            .years(balanced.getYears())
            .months(balanced.getMonths())
            .weeks(balanced.getWeeks())
            .days(balanced.getDays() + dayDelta);
        return new JiffSpanNudge(rounded, roundedRelativeEnd, dayDelta != 0);
    }

    /**
     * Carries a rounded span into bigger units, from `smallest` (days at least) up to
     * `largest`, for as long as the next whole unit does not end past the rounded end.
     */
    public JiffSpan bubble(JiffSpanRelative relativeStart, JiffUnit smallest, JiffUnit largest) {
        if (!grewBigUnit || smallest == JiffUnit.WEEK) {
            return span;
        }
        List<JiffUnit> units = JiffUnit.values();
        JiffSpan balanced = span;
        Integer sign = balanced.signum();
        Integer index = JiffMath.largerOf(smallest, JiffUnit.DAY).ordinal();
        while (index + 1 < units.size()) {
            index++;
            JiffUnit unit = units.get(index);
            if (JiffMath.isLarger(unit, largest)) {
                break;
            }
            // Smaller units only bubble into weeks when weeks were asked for.
            if (unit == JiffUnit.WEEK && largest != JiffUnit.WEEK) {
                continue;
            }
            JiffSpan spanStart = balanced.withoutLower(unit);
            JiffSpan spanEnd = spanStart.withUnit(unit, spanStart.get(unit) + sign);
            JiffSignedDuration threshold = relativeStart.add(spanEnd).toDuration();
            JiffSignedDuration beyond = roundedRelativeEnd.subtract(threshold);
            if (beyond.isZero() || beyond.signum() == sign) {
                balanced = spanEnd;
            } else {
                break;
            }
        }
        return balanced;
    }

    /**
     * Rounds a span whose units all have a fixed length (weeks at most), as one exact
     * duration, and spreads the result over the units from `largest` down.
     */
    public static JiffSpan roundInvariant(
        JiffSpan span,
        JiffUnit largest,
        JiffUnit smallest,
        Long increment,
        JiffRoundMode mode
    ) {
        JiffSignedDuration rounded = JiffRounding.roundDuration(
            mode,
            span.toInvariantDuration(),
            smallest,
            increment
        );
        return fromRoundedNanos(largest, rounded);
    }

    /**
     * The instants `span` and `span` plus `amount` more `unit`s end at, measured from
     * `relative`: the start and end of the stretch of `unit` being measured.
     */
    public static List<JiffSignedDuration> unitStartAndEnd(
        JiffSpanRelative relative,
        JiffSpan span,
        JiffUnit unit,
        Long amount
    ) {
        JiffSpan spanAmount = span.withUnit(unit, span.get(unit) + amount);
        JiffSignedDuration relative0 = relative.add(span).toDuration();
        JiffSignedDuration relative1 = relative.add(spanAmount).toDuration();
        return new List<JiffSignedDuration>{ relative0, relative1 };
    }

    /** Rounds `quantity` to a multiple of `increment`, a positive duration of any length. */
    private static JiffSignedDuration roundByDuration(
        JiffRoundMode mode,
        JiffSignedDuration quantity,
        JiffSignedDuration increment
    ) {
        return JiffSignedDuration.fromNanosI128(
            JiffRounding.round(mode, quantity.asNanosI128(), increment.asNanosI128())
        );
    }

    /** `JiffSpan.fromInvariantDuration`, with Jiff's description of the step on failure. */
    private static JiffSpan fromRoundedNanos(JiffUnit largest, JiffSignedDuration rounded) {
        try {
            return JiffSpan.fromInvariantDuration(largest, rounded);
        } catch (JiffException e) {
            throw JiffSpanRelative.inContext(
                'failed to convert rounded nanoseconds to span for largest unit set to \'' +
                    JiffMath.plural(largest) +
                    '\'',
                e
            );
        }
    }

    /** The whole civil days in a duration, truncated toward zero. */
    private static Long civilDays(JiffSignedDuration duration) {
        return duration.asSecs() / JiffMath.SECS_PER_CIVIL_DAY;
    }
}
