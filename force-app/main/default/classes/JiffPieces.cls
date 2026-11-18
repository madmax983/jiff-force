/**
 * A low level view of a datetime string in the Temporal ISO 8601 / RFC 9557 format: its date,
 * and the time, UTC offset and time zone annotation it may also have.
 *
 * Most code should parse into the type it wants (`JiffTimestamp.parse`, `JiffDateTime.parse`
 * and so on). Those apply rules: a timestamp needs an offset, a civil datetime rejects `Z`.
 * `JiffPieces` applies none. It hands back what was written and lets the caller decide, which
 * is the way to handle the cases the higher level types reject or gloss over:
 *
 *     JiffPieces pieces = JiffPieces.parse('2025-01-03T17:28-05');
 *     pieces.toDate();             // 2025-01-03
 *     pieces.toTime();             // 17:28:00
 *     pieces.toNumericOffset();    // -05
 *     pieces.timeZoneAnnotation(); // null: there is no [..] part
 *
 * It also tells apart the three ways of writing an offset of zero, which a `JiffOffset`
 * cannot:
 *
 *     JiffPieces.parse('1970-01-01T00:00:00Z').offset().isZulu();                    // true
 *     JiffPieces.parse('1970-01-01T00:00:00-00:00').offset().asNumeric().isNegative(); // true
 *     JiffPieces.parse('1970-01-01T00:00:00+00:00').offset().asNumeric().isNegative(); // false
 *
 * Going the other way, pieces can be assembled with the `with...` methods and printed with
 * `toString()`:
 *
 *     JiffPieces.fromDate(JiffDate.newInstance(2025, 1, 3))
 *         .withOffset(JiffOffset.fromHours(2))
 *         .withTimeZoneName('Africa/Cairo')
 *         .toString();              // 2025-01-03T00:00:00+02:00[Africa/Cairo]
 *
 * This is a "dumb" type: it stores and prints what it is given, even when the parts
 * contradict each other. An offset that does not match the time zone, or a zone name that
 * does not exist, is kept as it is. Setting one part never changes another.
 *
 * Only the date is required. Instances are immutable; the `with...` methods return a new
 * value. The `without...` methods take a part away again, which Jiff's `Pieces` cannot do.
 *
 * Mirrors `jiff::fmt::temporal::Pieces`.
 */
public class JiffPieces {
    private static final Long PRIME = 1000000007L;

    private final JiffDate dateValue;
    private final JiffTime timeValue;
    private final JiffPiecesOffset offsetValue;
    private final JiffPiecesTimeZoneAnnotation annotation;

    private JiffPieces(
        JiffDate dateValue,
        JiffTime timeValue,
        JiffPiecesOffset offsetValue,
        JiffPiecesTimeZoneAnnotation annotation
    ) {
        this.dateValue = dateValue;
        this.timeValue = timeValue;
        this.offsetValue = offsetValue;
        this.annotation = annotation;
    }

    // ---- construction ---------------------------------------------------

    /**
     * Parses a Temporal ISO 8601 datetime string into its pieces.
     *
     * Everything `JiffTemporal.parseDateTime` and `JiffTemporal.parseTimestamp` accept is
     * accepted here, and no part other than the date is required. Throws `JiffException` when
     * the text is not a datetime string at all.
     *
     *     JiffPieces pieces = JiffPieces.parse('2025-01-03T16:42[America/Whitehorse]');
     *     pieces.toDate();          // 2025-01-03
     *     pieces.toTime();          // 16:42:00
     *     pieces.toNumericOffset(); // null
     *     pieces.toTimeZone();      // America/Whitehorse
     *
     * Mirrors `Pieces::parse`.
     */
    public static JiffPieces parse(String text) {
        return JiffTemporal.parsePieces(text);
    }

    /** Pieces with only a date. Prints as `2025-01-03`. Mirrors `From<Date>`. */
    public static JiffPieces fromDate(JiffDate value) {
        if (value == null) {
            throw new JiffException('datetime pieces need a date');
        }
        return new JiffPieces(value, null, null, null);
    }

    /** Pieces with the date and time of a civil datetime. Mirrors `From<DateTime>`. */
    public static JiffPieces fromDateTime(JiffDateTime value) {
        if (value == null) {
            throw new JiffException('datetime pieces need a date');
        }
        return new JiffPieces(value.toDate(), value.toTime(), null, null);
    }

    /**
     * Pieces for an instant: its date and time in UTC, and the `Z` offset. Prints the same as
     * the timestamp does, for example `2025-01-03T18:50:08Z`. Mirrors `From<Timestamp>`.
     */
    public static JiffPieces fromTimestamp(JiffTimestamp value) {
        if (value == null) {
            throw new JiffException('datetime pieces need a date');
        }
        return fromDateTime(JiffOffset.UTC.toDateTime(value)).withOffset(JiffPiecesOffset.ZULU);
    }

    /**
     * Pieces for an instant as a clock at the given offset shows it, with that offset. For the
     * Unix epoch at `-05` this prints `1969-12-31T19:00:00-05:00`.
     *
     * This is usually what is wanted instead of `fromTimestamp(ts).withOffset(offset)`, which
     * keeps the UTC date and time and so describes a different instant.
     *
     * Mirrors `From<(Timestamp, Offset)>`.
     */
    public static JiffPieces fromTimestampWithOffset(JiffTimestamp value, JiffOffset offset) {
        if (value == null || offset == null) {
            throw new JiffException('datetime pieces need a timestamp and an offset');
        }
        return fromDateTime(offset.toDateTime(value)).withOffset(offset);
    }

    // ---- accessors ------------------------------------------------------

    /** The civil date. Every `JiffPieces` has one. Mirrors `Pieces::date`. */
    public JiffDate toDate() {
        return dateValue;
    }

    /**
     * The civil time, or null when the string had none (`2025-01-03`,
     * `2015-10-18[America/Sao_Paulo]`).
     *
     * The types that need a time and parse a string without one use the first moment of the
     * day. Pieces do not fill it in. Mirrors `Pieces::time`.
     */
    public JiffTime toTime() {
        return timeValue;
    }

    /**
     * The UTC offset as it was written, or null when the string had none. The result says
     * whether a `Z`, a `-00:00` or another numeric offset was used. Mirrors `Pieces::offset`.
     */
    public JiffPiecesOffset offset() {
        return offsetValue;
    }

    /**
     * The time zone annotation (the part in square brackets), or null when the string had
     * none. Mirrors `Pieces::time_zone_annotation`.
     */
    public JiffPiecesTimeZoneAnnotation timeZoneAnnotation() {
        return annotation;
    }

    /**
     * The UTC offset as a plain `JiffOffset`, or null when the string had none. `Z`, `-00:00`
     * and `+00:00` all give `JiffOffset.UTC`; use `offset()` to tell them apart.
     *
     * Mirrors `Pieces::to_numeric_offset`.
     */
    public JiffOffset toNumericOffset() {
        return offsetValue == null ? null : offsetValue.toNumericOffset();
    }

    /**
     * The time zone named by the annotation, or null when there is no annotation. An offset
     * annotation gives a fixed offset zone. Throws `JiffException` when the annotation names a
     * zone the platform does not know.
     *
     *     JiffPieces.parse('2025-01-03T17:13-05').toTimeZone();        // null
     *     JiffPieces.parse('2025-01-03T17:13-05[-05]').toTimeZone();   // fixed at -05
     *     JiffPieces.parse('2025-01-03T17:13-05[America/New_York]').toTimeZone();
     *
     * Mirrors `Pieces::to_time_zone`.
     */
    public JiffTimeZone toTimeZone() {
        return annotation == null ? null : annotation.toTimeZone();
    }

    // ---- setters --------------------------------------------------------

    /** These pieces with a different date. Mirrors `Pieces::with_date`. */
    public JiffPieces withDate(JiffDate value) {
        if (value == null) {
            throw new JiffException('datetime pieces need a date');
        }
        return new JiffPieces(value, timeValue, offsetValue, annotation);
    }

    /**
     * These pieces with the given time. A null time removes it, as `withoutTime()` does.
     * Mirrors `Pieces::with_time`.
     */
    public JiffPieces withTime(JiffTime value) {
        return new JiffPieces(dateValue, value, offsetValue, annotation);
    }

    /**
     * These pieces without a time: `2025-01-03T07:55[Africa/Cairo]` becomes
     * `2025-01-03[Africa/Cairo]`. If there is an offset, it stays, and the pieces print with
     * a time of midnight.
     *
     * Jiff has no counterpart: its `Pieces` can gain a part but never lose one.
     */
    public JiffPieces withoutTime() {
        return new JiffPieces(dateValue, null, offsetValue, annotation);
    }

    /**
     * These pieces with the given UTC offset, which may be `JiffPiecesOffset.ZULU` or a
     * `-00:00`.
     *
     * This is the offset of the RFC 3339 part of the string, not the one inside a time zone
     * annotation; see `withTimeZoneOffset` for that. The two are not kept in step.
     *
     * A string such as `2025-01-03+11` is not valid, so pieces that have an offset but no
     * time are printed with a time of midnight.
     *
     * To remove the offset, call `withoutOffset()`. A variable that holds null removes it
     * too, but `withOffset(null)` does not compile: with two methods of this name, Apex
     * cannot tell which one a bare `null` is meant for.
     *
     * Mirrors `Pieces::with_offset`.
     */
    public JiffPieces withOffset(JiffPiecesOffset value) {
        return new JiffPieces(dateValue, timeValue, value, annotation);
    }

    /**
     * These pieces with the given numeric UTC offset. An offset of zero is written `+00:00`.
     * A null offset removes it, as `withoutOffset()` does; see the other `withOffset` for why
     * that is the better way to ask.
     *
     * Mirrors `Pieces::with_offset` for an `Offset`.
     */
    public JiffPieces withOffset(JiffOffset value) {
        if (value == null) {
            return withoutOffset();
        }
        return withOffset(JiffPiecesOffset.fromOffset(value));
    }

    /**
     * These pieces without a UTC offset: `2025-01-03T07:55+02:00[Africa/Cairo]` becomes
     * `2025-01-03T07:55:00[Africa/Cairo]`. An offset inside a time zone annotation is not
     * touched.
     *
     * Jiff has no counterpart: its `Pieces` can gain a part but never lose one.
     */
    public JiffPieces withoutOffset() {
        return new JiffPieces(dateValue, timeValue, null, annotation);
    }

    /**
     * These pieces with a time zone annotation holding the given name, which is not checked.
     * Mirrors `Pieces::with_time_zone_name`.
     */
    public JiffPieces withTimeZoneName(String name) {
        return withTimeZoneAnnotation(JiffPiecesTimeZoneAnnotation.fromName(name));
    }

    /**
     * These pieces with a time zone annotation holding the given offset. This is the offset
     * inside the square brackets, not the one set by `withOffset`.
     * Mirrors `Pieces::with_time_zone_offset`.
     */
    public JiffPieces withTimeZoneOffset(JiffOffset offset) {
        return withTimeZoneAnnotation(JiffPiecesTimeZoneAnnotation.fromOffset(offset));
    }

    /**
     * These pieces with the given time zone annotation. A null annotation removes it, as
     * `withoutTimeZoneAnnotation()` does. Mirrors `Pieces::with_time_zone_annotation`.
     */
    public JiffPieces withTimeZoneAnnotation(JiffPiecesTimeZoneAnnotation value) {
        return new JiffPieces(dateValue, timeValue, offsetValue, value);
    }

    /**
     * These pieces without a time zone annotation: `2025-01-03T07:55+02:00[Africa/Cairo]`
     * becomes `2025-01-03T07:55:00+02:00`.
     *
     * Jiff has no counterpart: its `Pieces` can gain a part but never lose one.
     */
    public JiffPieces withoutTimeZoneAnnotation() {
        return new JiffPieces(dateValue, timeValue, offsetValue, null);
    }

    // ---- equality and text ----------------------------------------------

    /** Whether every piece is the same, including which pieces are absent. */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffPieces)) {
            return false;
        }
        JiffPieces that = (JiffPieces) other;
        if (!dateValue.equals(that.dateValue)) {
            return false;
        }
        if (timeValue == null ? that.timeValue != null : !timeValue.equals(that.timeValue)) {
            return false;
        }
        if (
            offsetValue == null ? that.offsetValue != null : !offsetValue.equals(that.offsetValue)
        ) {
            return false;
        }
        return annotation == null ? that.annotation == null : annotation.equals(that.annotation);
    }

    /** A hash consistent with `equals`. */
    public Integer hashCode() {
        Long hash = dateValue.hashCode();
        hash = JiffMath.floorMod(hash * 31 + (timeValue == null ? 0 : timeValue.hashCode()), PRIME);
        hash = JiffMath.floorMod(
            hash * 31 + (offsetValue == null ? 0 : offsetValue.hashCode()),
            PRIME
        );
        hash = JiffMath.floorMod(
            hash * 31 + (annotation == null ? 0 : annotation.hashCode()),
            PRIME
        );
        return hash.intValue();
    }

    /**
     * Formats these pieces as a Temporal ISO 8601 datetime string.
     *
     * - The time is written when there is one, or when there is an offset (as midnight).
     * - The offset is written as `Z`, `-00:00` or `+HH:MM`, rounded to the nearest minute.
     * - The annotation is written in square brackets, with `!` when it is critical.
     *
     * For control over the precision of the fractional seconds, the separator or letter case,
     * use `JiffTemporalPrinter.piecesToString`.
     *
     * Mirrors the `Display` implementation of `Pieces`.
     */
    public override String toString() {
        return JiffTemporal.printPieces(this);
    }
}
