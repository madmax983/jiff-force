/**
 * Options for writing a `JiffSpan` or `JiffSignedDuration` in the "friendly" duration format,
 * and the printer that applies them.
 *
 * The default printer is what `JiffSpan.toFriendly()` uses. It writes compact labels with a
 * space between units and a trailing ` ago` for negative durations:
 *
 *     JiffSpan span = new JiffSpan().years(1).months(2).hours(15).seconds(30).nanoseconds(1);
 *     new JiffFriendlyPrinter().spanToString(span);   // 1y 2mo 15h 30s 1ns
 *
 * Every setter returns a new printer, so a configured printer can be kept in a static and
 * shared:
 *
 *     JiffFriendlyPrinter verbose = new JiffFriendlyPrinter()
 *         .designator(JiffFriendlyDesignator.VERBOSE)
 *         .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS)
 *         .commaAfterDesignator(true);
 *     verbose.spanToString(span);
 *     // 1 year, 2 months, 15 hours, 30 seconds, 1 nanosecond
 *
 *     new JiffFriendlyPrinter().hoursMinutesSeconds(true).spanToString(span);
 *     // 1y 2mo 15:00:30.000000001
 *
 * ## Spans and durations print differently
 *
 * A span is written unit by unit, exactly as it is stored: a span of 120 minutes prints as
 * `120m`. A signed duration has no units of its own, so it is always broken down into hours,
 * minutes, seconds, milliseconds, microseconds and nanoseconds: 120 minutes prints as `2h`.
 *
 * ## Rounding
 *
 * The printer never rounds. Round the span or duration first, then print it. A fixed
 * `precision` truncates.
 *
 * Whatever this printer writes, `JiffFriendly.parseSpan` reads back.
 *
 * Mirrors `jiff::fmt::friendly::SpanPrinter`.
 */
public class JiffFriendlyPrinter {
    private static final Integer MAX_PADDING = 20;
    private static final Integer MAX_PRECISION = 9;
    private static final List<JiffUnit> UNITS = JiffUnit.values();
    private static final Integer DAY_ORDINAL = JiffUnit.DAY.ordinal();
    private static final Integer YEAR_ORDINAL = JiffUnit.YEAR.ordinal();
    // U+00B5 MICRO SIGN.
    private static final String MICRO = String.fromCharArray(new List<Integer>{ 181 });

    // Unit labels, indexed by JiffUnit ordinal (nanoseconds first). The verbose labels are
    // the unit names themselves and come from `JiffMath`.
    private static final List<String> SHORT_SINGULAR = new List<String>{
        'nsec',
        MICRO + 'sec',
        'msec',
        'sec',
        'min',
        'hr',
        'day',
        'wk',
        'mo',
        'yr'
    };
    private static final List<String> SHORT_PLURAL = new List<String>{
        'nsecs',
        MICRO + 'secs',
        'msecs',
        'secs',
        'mins',
        'hrs',
        'days',
        'wks',
        'mos',
        'yrs'
    };
    private static final List<String> COMPACT_LABELS = new List<String>{
        'ns',
        MICRO + 's',
        'ms',
        's',
        'm',
        'h',
        'd',
        'w',
        'mo',
        'y'
    };
    private static final List<String> HUMAN_TIME_SINGULAR = new List<String>{
        'ns',
        'us',
        'ms',
        's',
        'm',
        'h',
        'd',
        'w',
        'month',
        'y'
    };
    private static final List<String> HUMAN_TIME_PLURAL = new List<String>{
        'ns',
        'us',
        'ms',
        's',
        'm',
        'h',
        'd',
        'w',
        'months',
        'y'
    };

    // Assigned only by the setters below, on a copy that has not been handed out yet.
    private JiffFriendlyDesignator designatorStyle = JiffFriendlyDesignator.COMPACT;
    private JiffFriendlySpacing spacingStyle = JiffFriendlySpacing.BETWEEN_UNITS;
    private JiffFriendlyDirection directionStyle = JiffFriendlyDirection.AUTO;
    private JiffFriendlyFractionalUnit fractionalUnit;
    private Boolean comma = false;
    private Boolean clock = false;
    // Null when not set: no padding (two digits in the clock form), automatic precision.
    private Integer paddingDigits;
    private Integer precisionDigits;
    private JiffUnit zeroUnitValue = JiffUnit.SECOND;

    /**
     * Creates a printer with the default settings: compact labels, a space between units, an
     * automatic sign, no fractions, no commas, no padding, and `0s` for a zero duration.
     */
    public JiffFriendlyPrinter() {
    }

    private JiffFriendlyPrinter copy() {
        JiffFriendlyPrinter next = new JiffFriendlyPrinter();
        next.designatorStyle = designatorStyle;
        next.spacingStyle = spacingStyle;
        next.directionStyle = directionStyle;
        next.fractionalUnit = fractionalUnit;
        next.comma = comma;
        next.clock = clock;
        next.paddingDigits = paddingDigits;
        next.precisionDigits = precisionDigits;
        next.zeroUnitValue = zeroUnitValue;
        return next;
    }

    // ---- settings -------------------------------------------------------

    /**
     * Sets which unit labels are written. The default is `JiffFriendlyDesignator.COMPACT`
     * (`1y 2mo`); the choice is a matter of taste, except that `HUMAN_TIME` exists for
     * interoperating with Rust's `humantime` crate.
     */
    public JiffFriendlyPrinter designator(JiffFriendlyDesignator designator) {
        if (designator == null) {
            throw new JiffException('designator must not be null');
        }
        JiffFriendlyPrinter next = copy();
        next.designatorStyle = designator;
        return next;
    }

    /**
     * Sets how much whitespace is written. The default is `JiffFriendlySpacing.BETWEEN_UNITS`
     * (`1y 2mo`).
     */
    public JiffFriendlyPrinter spacing(JiffFriendlySpacing spacing) {
        if (spacing == null) {
            throw new JiffException('spacing must not be null');
        }
        JiffFriendlyPrinter next = copy();
        next.spacingStyle = spacing;
        return next;
    }

    /**
     * Sets how the sign is written. The default is `JiffFriendlyDirection.AUTO`, which in most
     * configurations writes a trailing ` ago` for a negative duration.
     */
    public JiffFriendlyPrinter direction(JiffFriendlyDirection direction) {
        if (direction == null) {
            throw new JiffException('direction must not be null');
        }
        JiffFriendlyPrinter next = copy();
        next.directionStyle = direction;
        return next;
    }

    /**
     * Turns on fractional formatting: units smaller than `unit` are written as a decimal
     * fraction of it, so `1h 30m` with `JiffFriendlyFractionalUnit.HOUR` is `1.5h`. Pass null
     * (the default) to write every unit as a whole number.
     *
     * In the hours-minutes-seconds form the seconds always carry the fraction and this
     * setting is ignored.
     */
    public JiffFriendlyPrinter fractional(JiffFriendlyFractionalUnit unit) {
        JiffFriendlyPrinter next = copy();
        next.fractionalUnit = unit;
        return next;
    }

    /** When true, a comma is written after each unit label but the last: `1y, 2mo`. */
    public JiffFriendlyPrinter commaAfterDesignator(Boolean yes) {
        JiffFriendlyPrinter next = copy();
        next.comma = yes;
        return next;
    }

    /**
     * When true, hours, minutes and seconds are written as `HH:MM:SS[.fffffffff]` instead of
     * with labels. Calendar units of a span keep their labels and come first: `1d 02:00:00`.
     *
     * In this form the hours, minutes and seconds are padded to two digits unless `padding`
     * says otherwise, and anything below a second is a fraction of the seconds, so
     * `1000 milliseconds` and `1 second` print the same. A span's values are written as they
     * are (`120 minutes` is `00:120:00`); a signed duration is balanced (`02:00:00`).
     */
    public JiffFriendlyPrinter hoursMinutesSeconds(Boolean yes) {
        JiffFriendlyPrinter next = copy();
        next.clock = yes;
        return next;
    }

    /**
     * Sets the minimum number of digits each unit value is written with, padding with zeros
     * on the left: a padding of 3 writes one hour as `001h`. Values above 20 are treated as
     * 20. By default there is no padding, except for the two digits of the
     * hours-minutes-seconds form.
     */
    public JiffFriendlyPrinter padding(Integer digits) {
        if (digits < 0) {
            throw new JiffException('padding must not be negative');
        }
        JiffFriendlyPrinter next = copy();
        next.paddingDigits = Math.min(digits, MAX_PADDING);
        return next;
    }

    /**
     * Sets how many digits are written after the decimal point when fractions are on (through
     * `fractional` or `hoursMinutesSeconds`). A precision of 0 drops the fraction, and values
     * above 9 are treated as 9. Digits beyond the precision are truncated, not rounded.
     *
     * Pass null (the default) for an automatic precision: as many digits as the value needs,
     * and none, not even the decimal point, when the fraction is zero.
     */
    public JiffFriendlyPrinter precision(Integer digits) {
        if (digits != null && digits < 0) {
            throw new JiffException('precision must not be negative');
        }
        JiffFriendlyPrinter next = copy();
        if (digits == null) {
            next.precisionDigits = null;
        } else {
            next.precisionDigits = Math.min(digits, MAX_PRECISION);
        }
        return next;
    }

    /**
     * Sets the unit used to write a duration of zero. The default is seconds (`0s`). When
     * `fractional` is set, the fractional unit is used instead.
     */
    public JiffFriendlyPrinter zeroUnit(JiffUnit unit) {
        if (unit == null) {
            throw new JiffException('zero unit must not be null');
        }
        JiffFriendlyPrinter next = copy();
        next.zeroUnitValue = unit;
        return next;
    }

    /** The unit labels this printer writes. */
    public JiffFriendlyDesignator getDesignator() {
        return designatorStyle;
    }

    /** How much whitespace this printer writes. */
    public JiffFriendlySpacing getSpacing() {
        return spacingStyle;
    }

    /** How this printer writes the sign. */
    public JiffFriendlyDirection getDirection() {
        return directionStyle;
    }

    /** The fractional unit, or null when every unit is written as a whole number. */
    public JiffFriendlyFractionalUnit getFractional() {
        return fractionalUnit;
    }

    /** Whether a comma is written after each unit label. */
    public Boolean getCommaAfterDesignator() {
        return comma;
    }

    /** Whether hours, minutes and seconds are written as `HH:MM:SS`. */
    public Boolean getHoursMinutesSeconds() {
        return clock;
    }

    /** The minimum digits per unit value, or null when `padding` was never set. */
    public Integer getPadding() {
        if (paddingDigits == null) {
            return null;
        }
        return paddingDigits;
    }

    /** The fixed number of fractional digits, or null when the precision is automatic. */
    public Integer getPrecision() {
        if (precisionDigits == null) {
            return null;
        }
        return precisionDigits;
    }

    /** The unit used to write a duration of zero when no fractional unit is set. */
    public JiffUnit getZeroUnit() {
        return zeroUnitValue;
    }

    // ---- printing -------------------------------------------------------

    /**
     * Formats a span in the friendly format. Each non-zero unit is written as stored; a zero
     * span is written as a zero of the zero unit, for example `0s`.
     */
    public String spanToString(JiffSpan span) {
        JiffFriendlyWriter writer = new JiffFriendlyWriter(
            this,
            span.hasCalendarUnits(),
            span.signum()
        );
        writer.writePrefixSign();
        if (clock) {
            writeSpanClock(span, writer);
        } else {
            writeSpanDesignators(span, writer);
        }
        writer.writeSuffixSign();
        return writer.toString();
    }

    /**
     * Formats a signed duration in the friendly format, broken down into hours and smaller
     * units. Hours are the largest unit used, however long the duration is.
     */
    public String durationToString(JiffSignedDuration duration) {
        JiffFriendlyWriter writer = new JiffFriendlyWriter(this, false, duration.signum());
        // Take the duration apart before removing the sign from each piece: the most negative
        // duration has no positive counterpart, but every one of its pieces does.
        Long secs = duration.asSecs();
        Long nanos = JiffMath.abs(duration.subsecNanos());
        Long hours = JiffMath.abs(secs / JiffMath.SECS_PER_HOUR);
        Long belowHour = JiffMath.abs(JiffMath.truncMod(secs, JiffMath.SECS_PER_HOUR));
        writer.writePrefixSign();
        if (clock) {
            writer.writeClock(hours, belowHour / 60L, JiffMath.truncMod(belowHour, 60L), nanos);
        } else {
            writeDurationDesignators(hours, belowHour, nanos, writer);
        }
        writer.writeSuffixSign();
        return writer.toString();
    }

    /**
     * The label this printer writes for `unit`, in its singular or plural form. Compact labels
     * do not distinguish the two.
     */
    public String label(JiffUnit unit, Boolean plural) {
        Integer index = unit.ordinal();
        switch on designatorStyle {
            when VERBOSE {
                return plural ? JiffMath.plural(unit) : JiffMath.singular(unit);
            }
            when SHORT_FORM {
                return plural ? SHORT_PLURAL.get(index) : SHORT_SINGULAR.get(index);
            }
            when HUMAN_TIME {
                return plural ? HUMAN_TIME_PLURAL.get(index) : HUMAN_TIME_SINGULAR.get(index);
            }
            when else {
                return COMPACT_LABELS.get(index);
            }
        }
    }

    /** The `JiffUnit` a fractional unit stands for. */
    public static JiffUnit toUnit(JiffFriendlyFractionalUnit unit) {
        switch on unit {
            when HOUR {
                return JiffUnit.HOUR;
            }
            when MINUTE {
                return JiffUnit.MINUTE;
            }
            when SECOND {
                return JiffUnit.SECOND;
            }
            when MILLISECOND {
                return JiffUnit.MILLISECOND;
            }
            when else {
                return JiffUnit.MICROSECOND;
            }
        }
    }

    private void writeSpanDesignators(JiffSpan span, JiffFriendlyWriter writer) {
        // Units from here up are written whole; the ones below fold into the fraction.
        Integer lowestWhole = fractionalUnit == null ? 0 : toUnit(fractionalUnit).ordinal() + 1;
        for (Integer i = YEAR_ORDINAL; i >= lowestWhole; i--) {
            writer.write(UNITS.get(i), span.getAbs(UNITS.get(i)));
        }
        if (fractionalUnit != null) {
            JiffSignedDuration rest = span.onlyLower(UNITS.get(lowestWhole))
                .toInvariantDuration()
                .abs();
            writeFractional(rest.asSecs(), rest.subsecNanos(), 0L, writer);
        }
        writer.writeZero();
    }

    private void writeSpanClock(JiffSpan span, JiffFriendlyWriter writer) {
        if (span.hasCalendarUnits()) {
            for (Integer i = YEAR_ORDINAL; i >= DAY_ORDINAL; i--) {
                writer.write(UNITS.get(i), span.getAbs(UNITS.get(i)));
            }
            writer.finishPreceding();
            if (spacingStyle == JiffFriendlySpacing.NONE) {
                // Without this the clock would run straight on from the last label.
                writer.append(' ');
            }
        }
        JiffSignedDuration seconds = span.onlyLower(JiffUnit.MINUTE).toInvariantDuration().abs();
        writer.writeClock(
            span.getAbs(JiffUnit.HOUR),
            span.getAbs(JiffUnit.MINUTE),
            seconds.asSecs(),
            seconds.subsecNanos()
        );
    }

    /**
     * Writes a duration of `hours` whole hours, `belowHour` further seconds (fewer than 3600)
     * and `nanos` nanoseconds, all non-negative.
     */
    private void writeDurationDesignators(
        Long hours,
        Long belowHour,
        Long nanos,
        JiffFriendlyWriter writer
    ) {
        Long minutes = belowHour / 60L;
        Long seconds = JiffMath.truncMod(belowHour, 60L);
        Long millis = nanos / JiffMath.NANOS_PER_MILLI;
        Long belowMilli = JiffMath.truncMod(nanos, JiffMath.NANOS_PER_MILLI);
        if (fractionalUnit == null) {
            writer.write(JiffUnit.HOUR, hours);
            writer.write(JiffUnit.MINUTE, minutes);
            writer.write(JiffUnit.SECOND, seconds);
            writer.write(JiffUnit.MILLISECOND, millis);
            writer.write(JiffUnit.MICROSECOND, belowMilli / JiffMath.NANOS_PER_MICRO);
            writer.write(
                JiffUnit.NANOSECOND,
                JiffMath.truncMod(belowMilli, JiffMath.NANOS_PER_MICRO)
            );
            writer.writeZero();
            return;
        }
        switch on fractionalUnit {
            when HOUR {
                writeFractional(belowHour, nanos, hours, writer);
            }
            when MINUTE {
                writer.write(JiffUnit.HOUR, hours);
                writeFractional(belowHour, nanos, 0L, writer);
            }
            when SECOND {
                writer.write(JiffUnit.HOUR, hours);
                writer.write(JiffUnit.MINUTE, minutes);
                writeFractional(seconds, nanos, 0L, writer);
            }
            when MILLISECOND {
                writer.write(JiffUnit.HOUR, hours);
                writer.write(JiffUnit.MINUTE, minutes);
                writer.write(JiffUnit.SECOND, seconds);
                writeFractional(0L, nanos, 0L, writer);
            }
            when else {
                writer.write(JiffUnit.HOUR, hours);
                writer.write(JiffUnit.MINUTE, minutes);
                writer.write(JiffUnit.SECOND, seconds);
                writer.write(JiffUnit.MILLISECOND, millis);
                writeFractional(0L, belowMilli, 0L, writer);
            }
        }
        writer.writeZero();
    }

    /**
     * Writes the non-negative duration `secs` seconds and `nanos` nanoseconds as a decimal
     * number of the fractional unit, to nine places, truncating. `extraWhole` is added to the
     * whole part; it carries hours that were split off beforehand.
     */
    private void writeFractional(
        Long secs,
        Long nanos,
        Long extraWhole,
        JiffFriendlyWriter writer
    ) {
        // Seconds and billionths of a second are what the duration is already in; the other
        // units rescale it.
        Long whole = secs;
        Long fraction = nanos;
        switch on fractionalUnit {
            when HOUR {
                whole = secs / 3600L;
                fraction =
                    (JiffMath.truncMod(secs, 3600L) * JiffMath.NANOS_PER_SEC + nanos) / 3600L;
            }
            when MINUTE {
                whole = secs / 60L;
                fraction = (JiffMath.truncMod(secs, 60L) * JiffMath.NANOS_PER_SEC + nanos) / 60L;
            }
            when MILLISECOND {
                whole = secs * 1000L + nanos / JiffMath.NANOS_PER_MILLI;
                fraction = JiffMath.truncMod(nanos, JiffMath.NANOS_PER_MILLI) * 1000L;
            }
            when MICROSECOND {
                whole = secs * 1000000L + nanos / JiffMath.NANOS_PER_MICRO;
                fraction = JiffMath.truncMod(nanos, JiffMath.NANOS_PER_MICRO) * 1000000L;
            }
        }
        writer.writeFractional(toUnit(fractionalUnit), whole + extraWhole, fraction);
    }
}
