/**
 * The text of one friendly duration while `JiffFriendlyPrinter` is writing it. Internal: not
 * part of the public API.
 *
 * It works out once, up front, how the sign is shown, and it remembers whether a unit has been
 * written yet, which decides whether the next one needs a separator in front of it and whether
 * a zero has to be written at the end.
 *
 * Unlike the value types this class is mutable; a new one is made for every duration printed.
 *
 * Mirrors `DesignatorWriter` and `FractionalPrinter` in `jiff::fmt::friendly`.
 */
public class JiffFriendlyWriter {
    private static final Integer MAX_PRECISION = 9;

    private final JiffFriendlyPrinter printer;
    // What is written before and after the units to show the sign; either may be empty.
    private final String prefixSign;
    private final String suffixSign;
    private final Integer padding;
    private String out = '';
    private Boolean writtenNonZeroUnit = false;

    /**
     * Starts an empty duration. `hasCalendar` says whether the value has non-zero units of
     * days or larger, and `signum` is -1, 0 or 1 for its sign; with the printer's settings
     * they decide how the sign is written.
     */
    public JiffFriendlyWriter(JiffFriendlyPrinter printer, Boolean hasCalendar, Integer signum) {
        this.printer = printer;
        Integer configuredPadding = printer.getPadding();
        this.padding = configuredPadding == null ? 0 : configuredPadding;
        JiffFriendlyDirection direction = printer.getDirection();
        // `AUTO` prefers the suffix, but a suffix needs a space in front of it, so it is not
        // used when spacing is off, and the clock form on its own reads better with a
        // leading sign.
        Boolean autoSuffix =
            direction == JiffFriendlyDirection.AUTO &&
            printer.getSpacing() != JiffFriendlySpacing.NONE &&
            (hasCalendar || !printer.getHoursMinutesSeconds());
        Boolean asSuffix = autoSuffix || direction == JiffFriendlyDirection.SUFFIX;
        Boolean negative = signum < 0;
        String positivePrefix = direction == JiffFriendlyDirection.FORCE_SIGN ? '+' : '';
        String prefix = negative ? '-' : positivePrefix;
        this.prefixSign = asSuffix ? '' : prefix;
        this.suffixSign = asSuffix && negative ? ' ago' : '';
    }

    /** Writes the leading sign, if the sign is shown as a prefix. */
    public void writePrefixSign() {
        out += prefixSign;
    }

    /** Writes the trailing ` ago`, if the sign is shown as a suffix. */
    public void writeSuffixSign() {
        out += suffixSign;
    }

    /** Appends text as it is. */
    public void append(String text) {
        out += text;
    }

    /** Writes one unit and its label. A value of zero writes nothing. */
    public void write(JiffUnit unit, Long value) {
        if (value == 0) {
            return;
        }
        finishPreceding();
        writtenNonZeroUnit = true;
        out += JiffMath.pad(value, padding);
        writeLabel(unit, value != 1);
    }

    /**
     * Writes a unit as a decimal number: `whole` plus `fraction` billionths. Nothing is
     * written when both are zero, unless a fixed precision above zero asks for `0.00`.
     */
    public void writeFractional(JiffUnit unit, Long whole, Long fraction) {
        Integer precision = printer.getPrecision();
        Boolean automatic = precision == null;
        Boolean isZero = whole == 0 && fraction == 0;
        if (isZero && (automatic || precision == 0)) {
            return;
        }
        finishPreceding();
        writtenNonZeroUnit = true;
        out += formatDecimal(whole, fraction, padding);
        // A fraction that a precision of zero is about to drop does not make a plural.
        Boolean shownFraction = fraction != 0 && (automatic || precision != 0);
        writeLabel(unit, whole != 1 || shownFraction);
    }

    /**
     * Writes a zero with the label of the printer's zero unit, or of its fractional unit when
     * it has one, but only when no unit has been written.
     */
    public void writeZero() {
        if (writtenNonZeroUnit) {
            return;
        }
        out += JiffMath.pad(0L, padding);
        JiffUnit unit = printer.getFractional() == null
            ? printer.getZeroUnit()
            : JiffFriendlyPrinter.toUnit(printer.getFractional());
        writeLabel(unit, true);
    }

    /**
     * Writes `HH:MM:SS`, with `nanos` as a fraction of the seconds. Each of the three numbers
     * is padded to the printer's padding, which defaults to two digits here.
     */
    public void writeClock(Long hours, Long minutes, Long seconds, Long nanos) {
        Integer configuredPadding = printer.getPadding();
        Integer clockPadding = configuredPadding == null ? 2 : configuredPadding;
        out +=
            JiffMath.pad(hours, clockPadding) +
            ':' +
            JiffMath.pad(minutes, clockPadding) +
            ':' +
            formatDecimal(seconds, nanos, clockPadding);
    }

    /** Writes the separator that follows a unit, if a unit has been written. */
    public void finishPreceding() {
        if (!writtenNonZeroUnit) {
            return;
        }
        if (printer.getCommaAfterDesignator()) {
            out += ',';
        }
        if (printer.getSpacing() != JiffFriendlySpacing.NONE) {
            out += ' ';
        }
    }

    /** The text written so far. */
    public override String toString() {
        return out;
    }

    private void writeLabel(JiffUnit unit, Boolean plural) {
        if (printer.getSpacing() == JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS) {
            out += ' ';
        }
        out += printer.label(unit, plural);
    }

    /**
     * `whole`, zero padded to `width`, followed by `fraction` billionths as decimal digits.
     * With no precision set the fraction is written only when it is not zero, and without
     * trailing zeros. A fixed precision writes exactly that many digits, truncating.
     */
    private String formatDecimal(Long whole, Long fraction, Integer width) {
        String text = JiffMath.pad(whole, width);
        Integer precision = printer.getPrecision();
        if (precision == null) {
            return fraction == 0 ? text : text + '.' + JiffTemporal.fraction(fraction.intValue());
        }
        if (precision == 0) {
            return text;
        }
        return text + '.' + JiffMath.pad(fraction, MAX_PRECISION).substring(0, precision);
    }
}
