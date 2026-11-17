/**
 * A builder that makes a new `JiffZonedDateTime` by replacing some of the fields of an
 * existing one, in the same time zone.
 *
 * Start it with `JiffZonedDateTime.with()`, name the fields to change, and finish with
 * `build()`. Any field you do not set keeps the value it has in the original.
 *
 *     JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 10, 31).inTz('America/New_York');
 *     JiffZonedDateTime zdt2 = zdt1.with().month(11).day(30).build();
 *     // 2024-11-30T00:00:00-05:00[America/New_York]
 *
 * Nothing is validated until `build()`, so fields can be set in any order. The one exception
 * is a null value, which every setter rejects at once.
 *
 * ## The civil fields
 *
 * The date and time fields follow the rules of `JiffDateTimeWith`:
 *
 * - `year` and `eraYear` both set the year, and the last one set wins.
 * - `day`, `dayOfYear` and `dayOfYearNoLeap` all set the day, and the last one set wins. The
 *   two day-of-year forms also determine the month.
 * - `millisecond`, `microsecond` and `nanosecond` each replace three digits of the fractional
 *   second, while `subsecNanosecond` replaces all of it. Setting `subsecNanosecond` together
 *   with any of the other three makes `build()` throw.
 * - `withDate` replaces the whole date and forgets every date field set before it; `withTime`
 *   does the same for the time of day.
 *
 * ## How the new civil datetime becomes an instant
 *
 * The new civil datetime may be skipped or repeated by the time zone, so `build()` has to
 * choose an instant. Three settings control the choice:
 *
 * - `offset` is the UTC offset to aim for. It defaults to the offset of the original zoned
 *   datetime.
 * - `offsetConflict` says what to do when that offset is not one the time zone has for the
 *   new civil datetime. It defaults to `PREFER_OFFSET`: use the offset when it is valid, and
 *   otherwise fall back to the time zone.
 * - `disambiguation` says which instant to pick when the time zone is consulted and the
 *   civil datetime falls in a gap or a fold. It defaults to `COMPATIBLE`.
 *
 * With the defaults, a small change to a datetime inside a repeated hour stays in the same
 * repetition, and anything else behaves the way arithmetic does:
 *
 *     // The second 01:30 on the day New York falls back, at offset -05.
 *     zdt.with().minute(34).build();   // 2024-11-03T01:34:00-05:00[America/New_York]
 *     zdt.with().hour(0).build();      // 2024-11-03T00:30:00-04:00[America/New_York]
 *
 * Builders are immutable; each setter returns a new builder.
 *
 * Mirrors `jiff::ZonedDateTimeWith`.
 */
public class JiffZonedDateTimeWith {
    private final JiffZonedDateTime original;
    private final JiffDateTimeWith fields;
    // Null until `offset` is called, which means "the offset of the original".
    private final JiffOffset wantedOffset;
    private final JiffDisambiguation ambiguity;
    private final JiffOffsetConflict conflict;

    /**
     * Creates a builder whose fields all come from `original`. `JiffZonedDateTime.with()` is
     * the usual way to get one.
     */
    public JiffZonedDateTimeWith(JiffZonedDateTime original) {
        this(
            original,
            new JiffDateTimeWith(civilOf(original)),
            null,
            JiffDisambiguation.COMPATIBLE,
            JiffOffsetConflict.PREFER_OFFSET
        );
    }

    private JiffZonedDateTimeWith(
        JiffZonedDateTime original,
        JiffDateTimeWith fields,
        JiffOffset wantedOffset,
        JiffDisambiguation ambiguity,
        JiffOffsetConflict conflict
    ) {
        this.original = original;
        this.fields = fields;
        this.wantedOffset = wantedOffset;
        this.ambiguity = ambiguity;
        this.conflict = conflict;
    }

    private static JiffDateTime civilOf(JiffZonedDateTime original) {
        if (original == null) {
            throw new JiffException('the zoned datetime to build from must not be null');
        }
        return original.toDateTime();
    }

    private static JiffException missing(String field) {
        return new JiffException(field + ' must not be null');
    }

    private JiffZonedDateTimeWith withFields(JiffDateTimeWith changed) {
        return new JiffZonedDateTimeWith(original, changed, wantedOffset, ambiguity, conflict);
    }

    /**
     * Creates the zoned datetime described by this builder: the original with every field
     * that was set replaced, resolved to an instant in the original's time zone as described
     * in the class notes. With nothing set, this returns a zoned datetime equal to the
     * original.
     *
     * Throws if a field is out of range, if the fields do not combine into a real civil
     * datetime, if the offset is rejected by `JiffOffsetConflict.REJECT`, if the civil
     * datetime is ambiguous and `JiffDisambiguation.REJECT` was chosen, or if the instant is
     * outside the supported range.
     */
    public JiffZonedDateTime build() {
        JiffDateTime civil = fields.build();
        JiffOffset aim = wantedOffset == null ? original.offset() : wantedOffset;
        return JiffOffsetConflicts.resolve(conflict, civil, aim, original.timeZone())
            .disambiguate(ambiguity);
    }

    /**
     * Sets the year, month and day from `datePart`. Overrides every date field set earlier;
     * date fields set afterwards replace fields of `datePart`. (`ZonedDateTimeWith::date` in
     * Jiff; `date` is a reserved word in Apex.)
     *
     *     // 2005-11-05T15:30:00-05:00[America/New_York]
     *     zdt.with().withDate(JiffDate.newInstance(2017, 10, 31)).build();
     *     // 2017-10-31T15:30:00-04:00[America/New_York]: the time remains the same
     */
    public JiffZonedDateTimeWith withDate(JiffDate datePart) {
        return withFields(fields.withDate(datePart));
    }

    /**
     * Sets the hour, minute, second and fractional second from `timePart`. Overrides every
     * time field set earlier; time fields set afterwards replace fields of `timePart`.
     * (`ZonedDateTimeWith::time` in Jiff; `time` is a reserved word in Apex.)
     *
     * Note that `with().withTime(JiffTime.midnight())` is midnight on the clock, which the
     * zone may skip; `JiffZonedDateTime.startOfDay()` is the first instant of the day.
     */
    public JiffZonedDateTimeWith withTime(JiffTime timePart) {
        return withFields(fields.withTime(timePart));
    }

    /**
     * Sets the year, in `-9999..9999`. Overrides any earlier `year` or `eraYear`.
     *
     * `build()` throws if the year is out of range, or if the date does not exist in that
     * year: February 29th cannot simply move to 2023.
     */
    public JiffZonedDateTimeWith year(Integer year) {
        if (year == null) {
            throw missing('year');
        }
        return withFields(fields.year(year));
    }

    /**
     * Sets the year by its era and its number within that era. Overrides any earlier `year`
     * or `eraYear`.
     *
     * `CE` years are the same as plain years and must be in `1..9999`. `BCE` years count
     * backwards from year zero and must be in `1..10000`: `1 BCE` is year `0` and `509 BCE` is
     * year `-508`. `build()` throws if the year is outside the range for its era.
     */
    public JiffZonedDateTimeWith eraYear(Integer year, JiffEra era) {
        if (year == null) {
            throw missing('eraYear');
        }
        return withFields(fields.eraYear(year, era));
    }

    /**
     * Sets the month, in `1..12`. Overrides any earlier `month`.
     *
     * `build()` throws if the month is out of range, or if the day does not exist in that
     * month: October 31st cannot simply move to November.
     */
    public JiffZonedDateTimeWith month(Integer month) {
        if (month == null) {
            throw missing('month');
        }
        return withFields(fields.month(month));
    }

    /**
     * Sets the day of the month. Overrides any earlier `day`, `dayOfYear` or
     * `dayOfYearNoLeap`.
     *
     * `build()` throws if the resulting year and month have no such day.
     */
    public JiffZonedDateTimeWith day(Integer day) {
        if (day == null) {
            throw missing('day');
        }
        return withFields(fields.day(day));
    }

    /**
     * Sets the day by its position in the year, where `1` is January 1st. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..366`. In a leap year day `60` is February 29th; in any other year
     * it is March 1st. `build()` throws if the value is out of range, or if it is `366` and
     * the year is not a leap year.
     */
    public JiffZonedDateTimeWith dayOfYear(Integer day) {
        if (day == null) {
            throw missing('dayOfYear');
        }
        return withFields(fields.dayOfYear(day));
    }

    /**
     * Sets the day by its position in the year as if leap days did not exist. Overrides any
     * earlier `day`, `dayOfYear` or `dayOfYearNoLeap`, and determines the month as well.
     *
     * Valid values are `1..365`. Day `60` is always March 1st and day `365` is always
     * December 31st, in leap years too; February 29th can never be produced. `build()` throws
     * if the value is out of range.
     */
    public JiffZonedDateTimeWith dayOfYearNoLeap(Integer day) {
        if (day == null) {
            throw missing('dayOfYearNoLeap');
        }
        return withFields(fields.dayOfYearNoLeap(day));
    }

    /** Sets the hour. `build()` throws unless it is in `0..23`. */
    public JiffZonedDateTimeWith hour(Integer hour) {
        if (hour == null) {
            throw missing('hour');
        }
        return withFields(fields.hour(hour));
    }

    /** Sets the minute. `build()` throws unless it is in `0..59`. */
    public JiffZonedDateTimeWith minute(Integer minute) {
        if (minute == null) {
            throw missing('minute');
        }
        return withFields(fields.minute(minute));
    }

    /** Sets the second. `build()` throws unless it is in `0..59`. */
    public JiffZonedDateTimeWith second(Integer second) {
        if (second == null) {
            throw missing('second');
        }
        return withFields(fields.second(second));
    }

    /**
     * Sets the millisecond component of the fractional second, leaving the microsecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffZonedDateTimeWith millisecond(Integer millisecond) {
        if (millisecond == null) {
            throw missing('millisecond');
        }
        return withFields(fields.millisecond(millisecond));
    }

    /**
     * Sets the microsecond component of the fractional second, leaving the millisecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffZonedDateTimeWith microsecond(Integer microsecond) {
        if (microsecond == null) {
            throw missing('microsecond');
        }
        return withFields(fields.microsecond(microsecond));
    }

    /**
     * Sets the nanosecond component of the fractional second, leaving the millisecond and
     * microsecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     */
    public JiffZonedDateTimeWith nanosecond(Integer nanosecond) {
        if (nanosecond == null) {
            throw missing('nanosecond');
        }
        return withFields(fields.nanosecond(nanosecond));
    }

    /**
     * Sets the whole fractional second, in nanoseconds. `build()` throws unless it is in
     * `0..999,999,999`, or if any of `millisecond`, `microsecond` or `nanosecond` is also set.
     */
    public JiffZonedDateTimeWith subsecNanosecond(Integer subsecNanosecond) {
        if (subsecNanosecond == null) {
            throw missing('subsecNanosecond');
        }
        return withFields(fields.subsecNanosecond(subsecNanosecond));
    }

    /**
     * Sets the UTC offset to aim for, in place of the original's. What happens when the time
     * zone does not have this offset for the new civil datetime is up to `offsetConflict`.
     *
     *     // The first 01:30 on the day New York falls back, at offset -04.
     *     zdt.with().offset(JiffOffset.fromHours(-5)).build();
     *     // 2024-11-03T01:30:00-05:00[America/New_York]: only the offset changes
     *     zdt.with().offset(JiffOffset.fromHours(-12)).build();
     *     // 2024-11-03T01:30:00-04:00[America/New_York]: not a New York offset, so by default
     *     // it is ignored and the datetime is disambiguated instead
     */
    public JiffZonedDateTimeWith offset(JiffOffset offset) {
        if (offset == null) {
            throw missing('offset');
        }
        return new JiffZonedDateTimeWith(original, fields, offset, ambiguity, conflict);
    }

    /**
     * Sets what to do when the offset (the original's, or the one given to `offset`) is not
     * one the time zone has for the new civil datetime. The default is `PREFER_OFFSET`.
     *
     * - `PREFER_OFFSET` keeps the offset when it is valid and otherwise lets the time zone
     *   and the disambiguation strategy decide.
     * - `ALWAYS_TIME_ZONE` ignores the offset.
     * - `ALWAYS_OFFSET` takes the civil datetime at exactly that offset as the instant, so
     *   the civil datetime of the result may differ from the fields that were set.
     * - `REJECT` makes `build()` throw unless the offset is valid.
     */
    public JiffZonedDateTimeWith offsetConflict(JiffOffsetConflict strategy) {
        if (strategy == null) {
            throw new JiffException('offset conflict strategy must not be null');
        }
        return new JiffZonedDateTimeWith(original, fields, wantedOffset, ambiguity, strategy);
    }

    /**
     * Sets how a civil datetime that the time zone skips or repeats is resolved, whenever the
     * offset does not settle it. The default is `COMPATIBLE`.
     *
     *     // 2024-03-11T02:05:00-04:00[America/New_York]; 02:05 does not exist the day before.
     *     zdt.with().day(10).build();
     *     // 2024-03-10T03:05:00-04:00[America/New_York]
     *     zdt.with().day(10).disambiguation(JiffDisambiguation.EARLIER).build();
     *     // 2024-03-10T01:05:00-05:00[America/New_York]
     */
    public JiffZonedDateTimeWith disambiguation(JiffDisambiguation strategy) {
        if (strategy == null) {
            throw new JiffException('disambiguation strategy must not be null');
        }
        return new JiffZonedDateTimeWith(original, fields, wantedOffset, strategy, conflict);
    }
}
