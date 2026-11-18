/**
 * A UTC offset exactly as it was written in a string: either the `Z` designator, or a sign and
 * hours with whichever of the minutes, seconds and fractional seconds were present. Internal:
 * the parsers produce it and `JiffPieces`, `JiffTimestamp.parse` and the zoned datetime parser
 * consume it.
 *
 * It is kept separate from `JiffOffset` because the written form carries more than the number
 * of seconds. `Z` and `-00:00` mean "UTC, local offset unknown"; an offset written with
 * seconds must be matched exactly rather than to the minute; and a fraction of a second is
 * only rounded away when the offset is finally needed.
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::fmt::offset::ParsedOffset`.
 */
public class JiffTemporalParsedOffset {
    private static final Integer MAX_SECONDS = 93599;

    // Marks a component that was not written.
    private static final Integer ABSENT = -1;

    private final Boolean zuluOffset;
    private final Boolean negative;
    private final Integer hourPart;
    private final Integer minutePart;
    private final Integer secondPart;
    private final Integer nanosecondPart;

    private JiffTemporalParsedOffset(
        Boolean zuluOffset,
        Boolean negative,
        Integer hourPart,
        Integer minutePart,
        Integer secondPart,
        Integer nanosecondPart
    ) {
        this.zuluOffset = zuluOffset;
        this.negative = negative;
        this.hourPart = hourPart;
        this.minutePart = minutePart;
        this.secondPart = secondPart;
        this.nanosecondPart = nanosecondPart;
    }

    /** The `Z` (or `z`) designator. */
    public static JiffTemporalParsedOffset zulu() {
        return new JiffTemporalParsedOffset(true, false, 0, ABSENT, ABSENT, ABSENT);
    }

    /**
     * A numeric offset written with only a sign and hours, such as `-05`. `negative` is the
     * sign that was written, so that `-00` is not lost; `hours` is the magnitude. Add the
     * other components with `withMinutes`, `withSeconds` and `withNanoseconds`.
     */
    public static JiffTemporalParsedOffset numeric(Boolean negative, Integer hours) {
        return new JiffTemporalParsedOffset(false, negative, hours, ABSENT, ABSENT, ABSENT);
    }

    /** This offset with a minutes component (`0..59`). */
    public JiffTemporalParsedOffset withMinutes(Integer minutes) {
        return new JiffTemporalParsedOffset(
            zuluOffset,
            negative,
            hourPart,
            minutes,
            secondPart,
            nanosecondPart
        );
    }

    /** This offset with a seconds component (`0..59`). */
    public JiffTemporalParsedOffset withSeconds(Integer seconds) {
        return new JiffTemporalParsedOffset(
            zuluOffset,
            negative,
            hourPart,
            minutePart,
            seconds,
            nanosecondPart
        );
    }

    /** This offset with a fraction of a second, in nanoseconds (`0..999,999,999`). */
    public JiffTemporalParsedOffset withNanoseconds(Integer nanoseconds) {
        return new JiffTemporalParsedOffset(
            zuluOffset,
            negative,
            hourPart,
            minutePart,
            secondPart,
            nanoseconds
        );
    }

    /** Whether the offset was written as `Z`. */
    public Boolean isZulu() {
        return zuluOffset;
    }

    /**
     * Whether a numeric offset was written with a negative sign. True for `-00:00`. Always
     * false for `Z`.
     */
    public Boolean isNegative() {
        return negative;
    }

    /**
     * Whether the offset was written with a seconds component, even a zero one (`+05:30:00`).
     * Such an offset is compared with a time zone's offset exactly; one written to the minute
     * is compared after rounding. Always false for `Z`.
     */
    public Boolean hasSubminute() {
        return secondPart != ABSENT;
    }

    /**
     * Converts to a `JiffOffset`. `Z` gives `JiffOffset.UTC`.
     *
     * An offset has whole seconds, so a fraction of half a second or more rounds the offset
     * away from zero. Throws `JiffException` when that pushes it past `25:59:59`.
     */
    public JiffOffset toOffset() {
        if (zuluOffset) {
            return JiffOffset.UTC;
        }
        Integer seconds = hourPart * 3600;
        if (minutePart != ABSENT) {
            seconds += minutePart * 60;
        }
        if (secondPart != ABSENT) {
            seconds += secondPart;
        }
        if (nanosecondPart >= 500000000) {
            seconds += 1;
        }
        if (seconds > MAX_SECONDS) {
            throw new JiffException(
                'due to precision loss from fractional seconds, ' +
                'time zone offset is rounded to a value that is out of bounds'
            );
        }
        return JiffOffset.fromSeconds(negative ? -seconds : seconds);
    }

    /**
     * Converts to the offset of a `JiffPieces`, which keeps `Z` and `-00:00` distinct from
     * `+00:00`. Throws when `toOffset` does.
     */
    public JiffPiecesOffset toPiecesOffset() {
        if (zuluOffset) {
            return JiffPiecesOffset.ZULU;
        }
        JiffPiecesNumericOffset numericOffset = JiffPiecesNumericOffset.fromOffset(toOffset());
        return JiffPiecesOffset.fromNumeric(
            negative ? numericOffset.withNegativeZero() : numericOffset
        );
    }

    /**
     * The offset with the components that were written, in the extended format: `Z`, `-05`,
     * `+05:30`, `+05:30:15`, `-00:44:30.5`. This is how an offset appears in the "unparsed
     * input remains" error.
     */
    public override String toString() {
        if (zuluOffset) {
            return 'Z';
        }
        String out = (negative ? '-' : '+') + JiffMath.pad(hourPart, 2);
        if (minutePart != ABSENT) {
            out += ':' + JiffMath.pad(minutePart, 2);
        }
        if (secondPart != ABSENT) {
            out += (minutePart == ABSENT ? ':00:' : ':') + JiffMath.pad(secondPart, 2);
        }
        if (nanosecondPart > 0) {
            if (minutePart == ABSENT) {
                out += ':00';
            }
            if (secondPart == ABSENT) {
                out += ':00';
            }
            out += '.' + JiffTemporal.fraction(nanosecondPart);
        }
        return out;
    }
}
