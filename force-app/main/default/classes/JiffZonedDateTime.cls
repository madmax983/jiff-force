/**
 * A time zone aware instant in time: a timestamp, the civil datetime it has in a time zone,
 * and that time zone, rolled into one.
 *
 *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 7, 4).at(8, 39, 0, 0)
 *         .inTz('America/New_York');
 *     zdt.toString();      // 2024-07-04T08:39:00-04:00[America/New_York]
 *     zdt.toTimestamp();   // 2024-07-04T12:39:00Z
 *     zdt.toDateTime();    // 2024-07-04T08:39:00
 *     zdt.offset();        // -04
 *     zdt.timeZone();      // America/New_York
 *
 * Use this type whenever both the instant and what the clock on the wall says matter. It
 * offers roughly everything `JiffDateTime` does, except that each operation takes the time
 * zone into account:
 *
 * - Arithmetic follows RFC 5545. Calendar units (years, months, weeks, days) move the civil
 *   datetime and keep the clock reading, so adding one day across a daylight saving change
 *   lands on the same time the next day, 23 or 25 hours later. Time units (hours and smaller)
 *   move the instant, so adding 24 hours always means 24 real hours.
 * - A civil datetime that the zone skips (a gap) or repeats (a fold) is resolved the way most
 *   people expect, with `JiffDisambiguation.COMPATIBLE`, wherever one is produced: by
 *   arithmetic, `tomorrow()`, `firstOfMonth()` and so on. `with()` lets you choose otherwise.
 * - `startOfDay()` is the first instant of the day, which is not midnight when the zone
 *   skips midnight, and rounding to a day knows that a day may be 23 or 25 hours long.
 *
 * ## Creating one
 *
 * - `JiffZonedDateTime.now()` for the current time in the running user's zone.
 * - `timestamp.toZonedDateTime(tz)` or `timestamp.inTz('Europe/London')` for an instant.
 * - `datetime.toZonedDateTime(tz)` or `datetime.inTz(...)`, and the same on `JiffDate`, for a
 *   civil datetime.
 * - `JiffZonedDateTime.fromSystemDatetime(dt)` for a platform `Datetime`.
 *
 * ## Comparison
 *
 * Zoned datetimes are ordered by their instant alone. The civil datetime and the time zone
 * play no part, so `12:00` in New York is before `11:00` in Los Angeles on the same day, and
 * `12:00` in New York `equals` `09:00` in Los Angeles. To also require the same zone, compare
 * `timeZone()` as well.
 *
 * ## Text
 *
 * `toString()` gives the RFC 9557 form, `2024-07-04T08:39:00-04:00[America/New_York]`, which
 * records the offset as well as the zone so that a repeated civil time stays unambiguous.
 *
 * The supported range is that of `JiffTimestamp`. Time zone behaviour comes from the
 * platform; see `JiffTimeZone`. Instances are immutable.
 *
 * Not ported yet: parsing, `strftime` and `strptime`, and the forms of `until` and `since`
 * that round their result.
 *
 * Mirrors `jiff::ZonedDateTime`.
 */
public class JiffZonedDateTime implements Comparable {
    /**
     * The Unix epoch, `1970-01-01T00:00:00Z`, in the `UTC` time zone. This is also what Jiff's
     * `ZonedDateTime::default()` returns.
     */
    public static final JiffZonedDateTime UNIX_EPOCH = newInstance(
        JiffTimestamp.UNIX_EPOCH,
        JiffTimeZone.UTC
    );

    private final JiffTimestamp ts;
    // The civil datetime and the offset are determined by the timestamp and the time zone.
    // They are kept so that the civil accessors do not have to ask the time zone each time.
    private final JiffDateTime dt;
    private final JiffOffset off;
    private final JiffTimeZone tz;

    private JiffZonedDateTime(JiffTimestamp ts, JiffDateTime dt, JiffOffset off, JiffTimeZone tz) {
        this.ts = ts;
        this.dt = dt;
        this.off = off;
        this.tz = tz;
    }

    // ---- construction ---------------------------------------------------

    /**
     * The current time in the running user's time zone (`JiffTimeZone.userTimeZone()`, the
     * port's counterpart to Jiff's system time zone). The platform clock has millisecond
     * precision.
     *
     * For the current time in another zone, `JiffTimestamp.now().toZonedDateTime(tz)` avoids
     * looking up the user's zone first.
     */
    public static JiffZonedDateTime now() {
        return newInstance(JiffTimestamp.now(), JiffTimeZone.userTimeZone());
    }

    /**
     * Creates the zoned datetime for an instant in a time zone. The time zone decides how the
     * instant reads as a civil datetime. This never fails for non-null arguments.
     *
     *     JiffZonedDateTime.newInstance(
     *         JiffTimestamp.UNIX_EPOCH,
     *         JiffTimeZone.get('Australia/Sydney')
     *     );   // 1970-01-01T10:00:00+10:00[Australia/Sydney]
     */
    public static JiffZonedDateTime newInstance(JiffTimestamp timestamp, JiffTimeZone zone) {
        if (timestamp == null || zone == null) {
            throw new JiffException('a zoned datetime needs both a timestamp and a time zone');
        }
        JiffOffset offset = zone.toOffset(timestamp);
        return new JiffZonedDateTime(timestamp, offset.toDateTime(timestamp), offset, zone);
    }

    /**
     * Creates the zoned datetime for a civil datetime in a time zone, resolving a gap or a
     * fold with the `COMPATIBLE` strategy. This is the implementation behind
     * `JiffDateTime.toZonedDateTime`, which reads better at the call site.
     *
     * Throws if the instant is outside the range of `JiffTimestamp`.
     */
    public static JiffZonedDateTime fromDateTime(JiffDateTime civil, JiffTimeZone zone) {
        if (civil == null || zone == null) {
            throw new JiffException('a zoned datetime needs both a civil datetime and a time zone');
        }
        JiffAmbiguousOffset found = zone.toAmbiguousTimestamp(civil).offset();
        if (found.isUnambiguous()) {
            // The common case. The time zone has just said that this is the offset for this
            // civil datetime, so there is no need to ask it again for the instant.
            JiffOffset offset = found.offset();
            return new JiffZonedDateTime(offset.toTimestamp(civil), civil, offset, zone);
        }
        // For a gap, the offset from before the transition gives the instant after the gap;
        // for a fold, it gives the first of the two instants. The civil datetime and the
        // offset in effect at that instant then come from the time zone.
        return newInstance(found.before().toTimestamp(civil), zone);
    }

    /**
     * Converts a platform `Datetime` to the same instant viewed in the running user's time
     * zone, the zone the platform itself uses to show a `Datetime` to that user. A null
     * `Datetime`, such as an empty record field, gives null.
     *
     *     JiffZonedDateTime created = JiffZonedDateTime.fromSystemDatetime(acct.CreatedDate);
     *     created.hour();   // the hour the user saw on the clock
     *
     * Throws if the `Datetime` is outside the supported range.
     */
    public static JiffZonedDateTime fromSystemDatetime(Datetime value) {
        if (value == null) {
            return null;
        }
        return newInstance(JiffTimestamp.fromSystemDatetime(value), JiffTimeZone.userTimeZone());
    }

    /**
     * Converts a platform `Datetime` to the same instant viewed in the given time zone. A null
     * `Datetime` gives null. Throws if the `Datetime` is outside the supported range.
     */
    public static JiffZonedDateTime fromSystemDatetime(Datetime value, JiffTimeZone zone) {
        if (zone == null) {
            throw new JiffException('a zoned datetime needs both a timestamp and a time zone');
        }
        if (value == null) {
            return null;
        }
        return newInstance(JiffTimestamp.fromSystemDatetime(value), zone);
    }

    /**
     * Parses a zoned datetime in the RFC 9557 format that `toString()` prints, such as
     * `2024-07-04T08:39:00-04:00[America/New_York]`.
     *
     *     JiffZonedDateTime.parse('2024-07-04T08:39:00-04:00[America/New_York]');
     *     JiffZonedDateTime.parse('2024-07-04T08:39:00[America/New_York]');   // offset optional
     *     JiffZonedDateTime.parse('2024-07-04[America/New_York]');            // midnight
     *     JiffZonedDateTime.parse('2024-07-04T12:39:00Z[America/New_York]');  // an instant
     *
     * The time zone annotation in square brackets is required. Without an offset, a clock
     * reading in a gap or fold is resolved as `JiffDisambiguation.COMPATIBLE` does. With an
     * offset, the offset must be one the zone has for that clock reading (which also picks
     * between the two readings of a fold), or this throws; a `Z` instead names the instant
     * and the zone only says how to show it. An offset written to the minute matches a zone
     * offset that has seconds when it equals that offset rounded to the minute.
     *
     * Throws `JiffException` when the text is not valid or does not agree with the zone.
     *
     * Mirrors `impl FromStr for jiff::ZonedDateTime`. One detail differs: an offset written
     * with explicit zero seconds (`-00:45:00`) is matched to the minute like `-00:45`, where
     * Jiff then requires an exact match.
     */
    public static JiffZonedDateTime parse(String text) {
        JiffPieces pieces = JiffPieces.parse(text);
        JiffPiecesTimeZoneAnnotation annotation = pieces.timeZoneAnnotation();
        if (annotation == null) {
            throw new JiffException(
                'failed to find time zone annotation in square brackets, ' +
                'which is required for parsing a zoned datetime'
            );
        }
        JiffTimeZone tz = annotation.toTimeZone();
        JiffTime clock = pieces.toTime();
        JiffDateTime dt = JiffDateTime.fromParts(
            pieces.toDate(),
            clock == null ? JiffTime.midnight() : clock
        );
        JiffPiecesOffset written = pieces.offset();
        JiffAmbiguousZonedDateTime ambiguous;
        if (written == null) {
            ambiguous = tz.toAmbiguousZonedDateTime(dt);
        } else if (written.isZulu()) {
            ambiguous = JiffOffsetConflicts.resolve(
                JiffOffsetConflict.ALWAYS_OFFSET,
                dt,
                JiffOffset.UTC,
                tz
            );
        } else {
            ambiguous = JiffOffsetConflicts.resolveWith(
                JiffOffsetConflict.REJECT,
                dt,
                written.toNumericOffset(),
                tz,
                new MinuteEquality()
            );
        }
        return ambiguous.compatible();
    }

    /**
     * Text offsets usually stop at the minute. A written offset matches a zone offset with
     * seconds when it equals that offset rounded to the minute, unless the text itself had
     * seconds.
     */
    private class MinuteEquality implements JiffOffsetConflicts.Equality {
        public Boolean isEqual(JiffOffset given, JiffOffset candidate) {
            if (given.equals(candidate)) {
                return true;
            }
            if (Math.mod(candidate.seconds(), 60) == 0 || Math.mod(given.seconds(), 60) != 0) {
                return false;
            }
            try {
                return given.equals(candidate.round(JiffUnit.MINUTE));
            } catch (JiffException e) {
                // Rounding the largest offsets can leave the range; then only an exact match
                // counts, and that has already failed.
                return false;
            }
        }
    }

    /**
     * Starts building a new zoned datetime from this one with some fields replaced:
     *
     *     JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 10, 31).inTz('America/New_York');
     *     zdt1.with().month(11).day(30).build();
     *     // 2024-11-30T00:00:00-05:00[America/New_York]
     *
     * Nothing is validated until `build()`, so the fields can be set in any order. The time
     * zone cannot be changed this way; use `withTimeZone` or `inTz` to keep the instant, or
     * `toDateTime().toZonedDateTime(tz)` to keep the clock reading. See
     * `JiffZonedDateTimeWith` for the fields that can be set and how the result is resolved.
     */
    public JiffZonedDateTimeWith with() {
        return new JiffZonedDateTimeWith(this);
    }

    /**
     * The same instant in another time zone. The civil datetime changes; the instant does
     * not.
     *
     *     JiffZonedDateTime london = JiffDate.newInstance(2024, 7, 4).at(12, 0, 0, 0)
     *         .inTz('Europe/London');
     *     london.withTimeZone(JiffTimeZone.get('America/New_York'));
     *     // 2024-07-04T07:00:00-04:00[America/New_York]
     */
    public JiffZonedDateTime withTimeZone(JiffTimeZone zone) {
        return newInstance(ts, zone);
    }

    /**
     * The same instant in the time zone with the given IANA name. Shorthand for
     * `withTimeZone(JiffTimeZone.get(name))`; throws if the platform does not know the name.
     */
    public JiffZonedDateTime inTz(String name) {
        return withTimeZone(JiffTimeZone.get(name));
    }

    // ---- accessors ------------------------------------------------------

    /** The time zone of this zoned datetime. */
    public JiffTimeZone timeZone() {
        return tz;
    }

    /** The instant, without the time zone. */
    public JiffTimestamp toTimestamp() {
        return ts;
    }

    /** The civil datetime: what a calendar and a clock in the time zone show at this instant. */
    public JiffDateTime toDateTime() {
        return dt;
    }

    /** The civil date in the time zone. */
    public JiffDate toDate() {
        return dt.toDate();
    }

    /** The civil time of day in the time zone. */
    public JiffTime toTime() {
        return dt.toTime();
    }

    /**
     * The UTC offset in effect at this instant in the time zone: `-05` for New York in
     * February and `-04` in July.
     */
    public JiffOffset offset() {
        return off;
    }

    /**
     * Converts to a platform `Datetime` for the same instant. A `Datetime` has millisecond
     * precision and no time zone of its own, so anything finer than a millisecond is dropped
     * (truncating toward the epoch, as `JiffTimestamp.toSystemDatetime` does) and the time
     * zone is forgotten.
     */
    public Datetime toSystemDatetime() {
        return ts.toSystemDatetime();
    }

    /** The year of the civil date, in `-9999..9999`. */
    public Integer year() {
        return dt.year();
    }

    /**
     * The year within its era, in `1..10000`. Pair it with `era()`.
     *
     * Years from `1` onward are unchanged (`2024` is `2024 CE`). Year `0` is `1 BCE`, year
     * `-1` is `2 BCE`, and so on. Jiff returns the year and the era together as a tuple; here
     * they are two accessors.
     */
    public Integer eraYear() {
        return dt.eraYear();
    }

    /** The era of the civil year: `CE` for years from `1` onward, `BCE` for the rest. */
    public JiffEra era() {
        return dt.era();
    }

    /** The month of the civil date, in `1..12`. */
    public Integer month() {
        return dt.month();
    }

    /** The day of the month of the civil date, in `1..31`. */
    public Integer day() {
        return dt.day();
    }

    /** The hour of the civil time, in `0..23`. */
    public Integer hour() {
        return dt.hour();
    }

    /** The minute of the civil time, in `0..59`. */
    public Integer minute() {
        return dt.minute();
    }

    /** The second of the civil time, in `0..59`. */
    public Integer second() {
        return dt.second();
    }

    /** The millisecond component of the fractional second, in `0..999`. */
    public Integer millisecond() {
        return dt.millisecond();
    }

    /** The microsecond component of the fractional second, in `0..999`. */
    public Integer microsecond() {
        return dt.microsecond();
    }

    /** The nanosecond component of the fractional second, in `0..999`. */
    public Integer nanosecond() {
        return dt.nanosecond();
    }

    /**
     * The whole fractional second of the civil time in nanoseconds, in `0..999,999,999`.
     *
     * This is always positive, as it reads on a clock. The fraction of the timestamp carries
     * the timestamp's sign instead, so for an instant before 1970 the two differ: 1,234
     * nanoseconds before the epoch is `23:59:59.999998766` on the clock.
     */
    public Integer subsecNanosecond() {
        return dt.subsecNanosecond();
    }

    /** The day of the week the civil date falls on. */
    public JiffWeekday weekday() {
        return dt.weekday();
    }

    /**
     * The position of the civil date within its year, where January 1st is day `1`. December
     * 31st is day `365`, or day `366` in a leap year.
     */
    public Integer dayOfYear() {
        return dt.dayOfYear();
    }

    /**
     * The position of the civil date within its year as if leap days did not exist, in
     * `1..365`. December 31st is always day `365`, in leap years too.
     *
     * Returns null for February 29th, which has no position in this scheme.
     */
    public Integer dayOfYearNoLeap() {
        Integer position = dt.dayOfYearNoLeap();
        if (position == null) {
            return null;
        }
        return position;
    }

    /**
     * The number of days in the civil month: 28, 29, 30 or 31.
     *
     * This is the calendar's answer. A time zone can skip a whole day, as `Pacific/Apia` did
     * with December 30th 2011, and that month still reports 31.
     */
    public Integer daysInMonth() {
        return dt.daysInMonth();
    }

    /** The number of days in the civil year: 366 in a leap year, otherwise 365. */
    public Integer daysInYear() {
        return dt.daysInYear();
    }

    /** Whether the civil year is a leap year. */
    public Boolean inLeapYear() {
        return dt.inLeapYear();
    }

    /**
     * Converts the civil date to its ISO 8601 week date: a week year, a week number and a
     * weekday. The time of day plays no part. See `JiffIsoWeekDate`.
     */
    public JiffIsoWeekDate toIsoWeekDate() {
        return dt.toIsoWeekDate();
    }

    // ---- neighbouring datetimes -----------------------------------------

    /**
     * The first instant of this zoned datetime's civil day.
     *
     * That is usually midnight, but not always: when clocks go forward at midnight the day
     * starts later.
     *
     *     JiffDate.newInstance(2015, 10, 18).at(12, 0, 0, 0).inTz('America/Sao_Paulo')
     *         .startOfDay();   // 2015-10-18T01:00:00-02:00[America/Sao_Paulo]
     *
     * Throws if the start of the day is outside the supported range, which can only happen
     * on the first day of the range.
     */
    public JiffZonedDateTime startOfDay() {
        return fromDateTime(dt.startOfDay(), tz);
    }

    /**
     * The last representable instant of this zoned datetime's civil day, usually
     * `23:59:59.999999999`.
     *
     * If that civil time is skipped by the zone the earlier instant is used, because the
     * later one belongs to the next day; if it is repeated, the later one is used. That is
     * the opposite of the `COMPATIBLE` strategy used elsewhere.
     *
     * Throws if the end of the day is outside the supported range, which can only happen on
     * the last day of the range.
     */
    public JiffZonedDateTime endOfDay() {
        JiffDateTime endOfCivilDay = dt.endOfDay();
        JiffAmbiguousOffset found = tz.toAmbiguousTimestamp(endOfCivilDay).offset();
        JiffOffset chosen = found.isUnambiguous() ? found.offset() : found.after();
        return newInstance(chosen.toTimestamp(endOfCivilDay), tz);
    }

    /**
     * The first day of this zoned datetime's month, at the same time of day. If the zone
     * skips or repeats that time on that day, it is resolved with the `COMPATIBLE` strategy.
     */
    public JiffZonedDateTime firstOfMonth() {
        return fromDateTime(dt.firstOfMonth(), tz);
    }

    /**
     * The last day of this zoned datetime's month, at the same time of day. If the zone
     * skips or repeats that time on that day, it is resolved with the `COMPATIBLE` strategy.
     */
    public JiffZonedDateTime lastOfMonth() {
        return fromDateTime(dt.lastOfMonth(), tz);
    }

    /**
     * January 1st of this zoned datetime's year, at the same time of day. If the zone skips
     * or repeats that time on that day, it is resolved with the `COMPATIBLE` strategy.
     */
    public JiffZonedDateTime firstOfYear() {
        return fromDateTime(dt.firstOfYear(), tz);
    }

    /**
     * December 31st of this zoned datetime's year, at the same time of day. If the zone
     * skips or repeats that time on that day, it is resolved with the `COMPATIBLE` strategy.
     */
    public JiffZonedDateTime lastOfYear() {
        return fromDateTime(dt.lastOfYear(), tz);
    }

    /**
     * The same time of day on the following civil day. This is not always 24 hours later.
     *
     * If the zone skips or repeats that time tomorrow, it is resolved with the `COMPATIBLE`
     * strategy: `02:30` on the day before New York springs forward gives `03:30`.
     *
     * Throws if the result is outside the supported range.
     */
    public JiffZonedDateTime tomorrow() {
        return fromDateTime(dt.tomorrow(), tz);
    }

    /**
     * The same time of day on the preceding civil day. This is not always 24 hours earlier.
     *
     * If the zone skips or repeats that time yesterday, it is resolved with the `COMPATIBLE`
     * strategy: `01:30` on the day after New York falls back gives the first `01:30`.
     *
     * Throws if the result is outside the supported range.
     */
    public JiffZonedDateTime yesterday() {
        return fromDateTime(dt.yesterday(), tz);
    }

    /**
     * The `nth` occurrence of `weekday` in this zoned datetime's month, at the same time of
     * day.
     *
     * A positive `nth` counts from the start of the month and a negative one from the end, so
     * `2` with `FRIDAY` is the second Friday and `-1` with `THURSDAY` is the last Thursday.
     * The day of this datetime does not matter, only its year and month.
     *
     * Throws if `nth` is zero or outside `-5..5`, or if it is `5` or `-5` and the month has
     * only four of that weekday.
     */
    public JiffZonedDateTime nthWeekdayOfMonth(Integer nth, JiffWeekday weekday) {
        return fromDateTime(dt.nthWeekdayOfMonth(nth, weekday), tz);
    }

    /**
     * The `nth` occurrence of `weekday` after this zoned datetime's date, or before it when
     * `nth` is negative, at the same time of day.
     *
     * The date itself is never counted. If today is a Sunday, the first Sunday (`nth` of `1`)
     * is a week from today and the first Monday is tomorrow; the first Saturday backwards
     * (`nth` of `-1`) is yesterday.
     *
     *     // The start of the week containing `zdt`, for weeks that begin on Sunday.
     *     zdt.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY).startOfDay();
     *
     * Throws if `nth` is zero, or if the result would fall outside the supported range.
     */
    public JiffZonedDateTime nthWeekday(Integer nth, JiffWeekday weekday) {
        return fromDateTime(dt.nthWeekday(nth, weekday), tz);
    }

    // ---- arithmetic -----------------------------------------------------

    /**
     * Adds a span to this zoned datetime. A negative span moves backwards.
     *
     * The years, months, weeks and days are added to the civil datetime, exactly as
     * `JiffDateTime.add` does, and the result is turned back into an instant in the time zone
     * (with the `COMPATIBLE` strategy if it lands in a gap or a fold). The hours and smaller
     * units are then added to that instant. So a day is "the same time tomorrow", however
     * long that is, while 24 hours is always 24 hours:
     *
     *     // New York springs forward on 2024-03-10.
     *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 3, 10).inTz('America/New_York');
     *     zdt.add(new JiffSpan().days(1));     // 2024-03-11T00:00:00-04:00[America/New_York]
     *     zdt.add(new JiffSpan().hours(24));   // 2024-03-11T01:00:00-04:00[America/New_York]
     *
     * As with a civil datetime, adding months or years pulls the day back to the end of a
     * shorter month, so adding such a span and subtracting it again does not always return
     * to the same datetime.
     *
     * Throws if the result is outside the supported range.
     */
    public JiffZonedDateTime add(JiffSpan span) {
        JiffSpan calendar = span.onlyCalendar();
        if (calendar.isZero()) {
            // Only hours and smaller: plain arithmetic on the instant, with no time zone
            // transitions to think about.
            return newInstance(addToTimestamp(ts, span), tz);
        }
        JiffSpan clock = span.onlyTime();
        JiffDateTime moved;
        try {
            moved = dt.add(calendar);
        } catch (JiffException e) {
            throw inContext('failed to add span to datetime from zoned datetime', e);
        }
        if (clock.isZero()) {
            try {
                return fromDateTime(moved, tz);
            } catch (JiffException e) {
                throw inContext('failed to convert civil datetime to timestamp', e);
            }
        }
        JiffTimestamp resolved;
        try {
            resolved = tz.toAmbiguousTimestamp(moved).compatible();
        } catch (JiffException e) {
            throw inContext('failed to convert civil datetime to timestamp', e);
        }
        return newInstance(addToTimestamp(resolved, clock), tz);
    }

    /** Adds a span of time units to an instant, describing the step if it fails. */
    private static JiffTimestamp addToTimestamp(JiffTimestamp origin, JiffSpan clock) {
        try {
            return origin.add(clock);
        } catch (JiffException e) {
            throw inContext('failed to add span to timestamp from zoned datetime', e);
        }
    }

    /**
     * Adds an exact duration to this zoned datetime. A negative duration moves backwards.
     *
     * The duration is added to the instant, so it always means that much elapsed time, and
     * subtracting the same duration gives this zoned datetime back.
     *
     *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 2, 29).inTz('America/New_York');
     *     zdt.add(JiffSignedDuration.fromHours(25));
     *     // 2024-03-01T01:00:00-05:00[America/New_York]
     *
     * Throws if the result is outside the supported range.
     */
    public JiffZonedDateTime add(JiffSignedDuration duration) {
        return newInstance(ts.add(duration), tz);
    }

    /**
     * Subtracts a span from this zoned datetime. The same as adding the span negated; see
     * `add(JiffSpan)` for how each unit is applied.
     */
    public JiffZonedDateTime subtract(JiffSpan span) {
        return add(span.negate());
    }

    /**
     * Subtracts an exact duration from this zoned datetime. The same as adding the duration
     * negated; see `add(JiffSignedDuration)`.
     */
    public JiffZonedDateTime subtract(JiffSignedDuration duration) {
        return add(JiffTimestamp.negated(duration));
    }

    /**
     * Like `add(JiffSpan)`, except that instead of throwing when the result is out of range
     * it returns `JiffTimestamp.MAX` (for a positive span) or `JiffTimestamp.MIN` (for a
     * negative one) in this time zone.
     */
    public JiffZonedDateTime saturatingAdd(JiffSpan span) {
        try {
            return add(span);
        } catch (JiffException e) {
            return newInstance(span.isNegative() ? JiffTimestamp.MIN : JiffTimestamp.MAX, tz);
        }
    }

    /**
     * Like `add(JiffSignedDuration)`, except that instead of throwing when the result is out
     * of range it returns `JiffTimestamp.MAX` (for a positive duration) or `JiffTimestamp.MIN`
     * (for a negative one) in this time zone.
     */
    public JiffZonedDateTime saturatingAdd(JiffSignedDuration duration) {
        try {
            return add(duration);
        } catch (JiffException e) {
            return newInstance(duration.isNegative() ? JiffTimestamp.MIN : JiffTimestamp.MAX, tz);
        }
    }

    /**
     * Like `subtract(JiffSpan)`, except that instead of throwing when the result is out of
     * range it returns `JiffTimestamp.MIN` (for a positive span) or `JiffTimestamp.MAX` (for a
     * negative one) in this time zone.
     */
    public JiffZonedDateTime saturatingSubtract(JiffSpan span) {
        return saturatingAdd(span.negate());
    }

    /**
     * Like `subtract(JiffSignedDuration)`, except that instead of throwing when the result is
     * out of range it returns `JiffTimestamp.MIN` (for a positive duration) or
     * `JiffTimestamp.MAX` (for a negative one) in this time zone.
     */
    public JiffZonedDateTime saturatingSubtract(JiffSignedDuration duration) {
        if (duration.asSecs() == JiffMath.LONG_MIN) {
            // Too negative to negate, so subtracting it certainly overflows forwards.
            return newInstance(JiffTimestamp.MAX, tz);
        }
        return saturatingAdd(duration.negate());
    }

    /** Wraps `cause` in the description of the step that failed, the way Jiff chains errors. */
    private static JiffException inContext(String step, JiffException cause) {
        return new JiffException(step + ': ' + cause.getMessage(), cause);
    }

    // ---- differences ----------------------------------------------------

    /**
     * The span from this zoned datetime until `other`, using hours as the largest unit. It is
     * negative when `other` is earlier.
     *
     *     JiffZonedDateTime earlier = JiffDate.newInstance(2006, 8, 24).at(22, 30, 0, 0)
     *         .inTz('America/New_York');
     *     JiffZonedDateTime later = JiffDate.newInstance(2019, 1, 31).at(21, 0, 0, 0)
     *         .inTz('America/New_York');
     *     earlier.until(later);   // PT109031H30M
     *     later.until(earlier);   // -PT109031H30M
     *
     * The result is an exact length of time, so the two zoned datetimes may be in different
     * time zones, and subtracting the result from `other` always gives this instant back.
     * This never fails.
     */
    public JiffSpan until(JiffZonedDateTime other) {
        return until(other, JiffUnit.HOUR);
    }

    /**
     * The span from this zoned datetime until `other`, using units up to `largest` (null
     * means `HOUR`). It is negative when `other` is earlier.
     *
     *     JiffZonedDateTime zdt1 = JiffDate.newInstance(1995, 12, 7).at(3, 24, 30, 3500)
     *         .inTz('America/New_York');
     *     JiffZonedDateTime zdt2 = JiffDate.newInstance(2019, 1, 31).at(15, 30, 0, 0)
     *         .inTz('America/New_York');
     *     zdt1.until(zdt2, JiffUnit.YEAR);   // P23Y1M24DT12H5M29.9999965S
     *
     * With `HOUR` or a smaller unit the difference is the exact time between the two
     * instants, spread over the units from `largest` down.
     *
     * With `DAY` or a larger unit the difference is counted the way arithmetic applies it:
     * whole calendar units between the civil dates first, keeping this datetime's time of
     * day, and then the exact time left over. A day that is 23 or 25 hours long still counts
     * as one day, so adding the result to this zoned datetime gives `other`. For that to make
     * sense both must be in the same time zone, and this throws when they are not. Months
     * differ in length, so such a span is tied to its starting point: subtracting it from
     * `other` may not give this datetime back.
     *
     * Time zones are compared with `JiffTimeZone.equals`, which cannot tell that two names are
     * aliases of one zone. Where Jiff accepts `Asia/Calcutta` and `Asia/Kolkata` together,
     * this throws; convert one side with `inTz` first.
     *
     * Nothing is rounded here. Throws if the difference does not fit in the requested units,
     * which can only happen with `NANOSECOND`, for instants more than about 292 years apart.
     * With `DAY` or a larger unit it also throws in one corner of the supported range: when
     * `other` is on the very first or last supported day and this datetime's time of day has
     * no instant on that day.
     */
    public JiffSpan until(JiffZonedDateTime other, JiffUnit largest) {
        JiffUnit unit = largest == null ? JiffUnit.HOUR : largest;
        Integer sign = JiffMath.signum(other.ts.compareTo(ts));
        if (sign == 0) {
            return new JiffSpan();
        }
        if (JiffMath.isLarger(JiffUnit.DAY, unit)) {
            return ts.until(other.ts, unit);
        }
        if (!tz.equals(other.tz)) {
            throw new JiffException(
                'computing the span between zoned datetimes, with ' +
                    JiffMath.singular(unit) +
                    ' units, requires that the time zones are equivalent, ' +
                    'but the zoned datetimes have distinct time zones'
            );
        }
        JiffDate endDate = other.toDate();
        if (JiffMath.signum(endDate.compareTo(dt.toDate())) != sign) {
            // The instants are in order but the civil dates are not, or they are the same
            // date. There are no whole days to count.
            return ts.until(other.ts, JiffUnit.HOUR);
        }
        // Take this datetime's time of day on the end date. If that overshoots `other`, the
        // last day was not a whole one: count one day fewer and try again. The instants are
        // compared rather than the clock times, which can be out of order during a fold.
        JiffZonedDateTime intermediate = atTimeOfDayOn(endDate);
        if (JiffMath.signum(other.ts.compareTo(intermediate.ts)) == -sign) {
            endDate = stepBack(endDate, sign);
            intermediate = atTimeOfDayOn(endDate);
            // A date the zone skips entirely can need a second correction.
            if (JiffMath.signum(other.ts.compareTo(intermediate.ts)) == -sign) {
                endDate = stepBack(endDate, sign);
                intermediate = atTimeOfDayOn(endDate);
            }
        }
        JiffSignedDuration remainder = intermediate.ts.durationUntil(other.ts);
        JiffSpan dateSpan = dt.toDate().until(endDate, unit);
        // What is left over is less than two days and has the sign of the date span (or one
        // of them is zero), so the units can be combined into one span.
        return JiffSpan.fromInvariantDuration(JiffUnit.HOUR, remainder)
            .years(dateSpan.getYears())
            .months(dateSpan.getMonths())
            .weeks(dateSpan.getWeeks())
            .days(dateSpan.getDays());
    }

    /**
     * This zoned datetime's time of day on another civil date in the same zone. On its own
     * date that is this zoned datetime itself, which keeps its offset when it is in a fold.
     */
    private JiffZonedDateTime atTimeOfDayOn(JiffDate day) {
        if (day.equals(dt.toDate())) {
            return this;
        }
        try {
            return fromDateTime(day.toDateTime(dt.toTime()), tz);
        } catch (JiffException e) {
            throw inContext('failed to convert intermediate datetime to zoned timestamp', e);
        }
    }

    /** The civil date one day closer to the start of a difference going in direction `sign`. */
    private static JiffDate stepBack(JiffDate day, Integer sign) {
        try {
            return day.add(new JiffSpan().days(-sign));
        } catch (JiffException e) {
            throw inContext('failed to add days to date in zoned datetime', e);
        }
    }

    /**
     * The span from `other` until this zoned datetime, using hours as the largest unit. It is
     * negative when `other` is later. This is `until(other)` with the sign flipped.
     */
    public JiffSpan since(JiffZonedDateTime other) {
        return until(other).negate();
    }

    /**
     * The span from `other` until this zoned datetime, using units up to `largest` (null
     * means `HOUR`). It is negative when `other` is later.
     *
     * This is `until(other, largest)` with the sign flipped: days, months and years are still
     * counted starting from this datetime, going back to `other`. That is not always the same
     * as `other.until(this, largest)`, which counts forward from `other`.
     */
    public JiffSpan since(JiffZonedDateTime other, JiffUnit largest) {
        return until(other, largest).negate();
    }

    /**
     * The span from this zoned datetime until `other`, with the units and rounding `options`
     * ask for.
     *
     * The smallest unit defaults to `NANOSECOND`, and the largest to the bigger of `HOUR` and
     * the smallest unit. When the smallest unit is bigger than a nanosecond, or the increment
     * is not 1, the difference is rounded as `JiffSpan.round` does, measured from this zoned
     * datetime, so a day containing a change of offset has its real length.
     *
     *     // 2024-03-10 is 23 hours long in New York.
     *     JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 3, 10).inTz('America/New_York');
     *     JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 3, 10).at(23, 30, 0, 0).inTz('America/New_York');
     *     zdt1.until(zdt2);   // PT22H30M
     *     zdt1.until(zdt2, new JiffDifference().smallest(JiffUnit.DAY).mode(JiffRoundMode.HALF_EXPAND));
     *     // P1D
     *
     * Throws when the time zones differ and the largest unit is a day or bigger, the
     * increment is not valid for the smallest unit, the largest unit is smaller than the
     * smallest, or the result does not fit.
     *
     * Mirrors `ZonedDateTime::until` with a `ZonedDateTimeDifference`.
     */
    public JiffSpan until(JiffZonedDateTime other, JiffDifference options) {
        return difference(other, options, false);
    }

    /**
     * The span from `other` until this zoned datetime, with the units and rounding `options`
     * ask for. This is `until(other, options)` before rounding, negated; the rounding is then
     * measured from this zoned datetime. See `until(JiffZonedDateTime, JiffDifference)`.
     *
     * Mirrors `ZonedDateTime::since` with a `ZonedDateTimeDifference`.
     */
    public JiffSpan since(JiffZonedDateTime other, JiffDifference options) {
        return difference(other, options, true);
    }

    private JiffSpan difference(JiffZonedDateTime other, JiffDifference options, Boolean negate) {
        JiffDifference config = options == null ? new JiffDifference() : options;
        JiffUnit smallest = config.getSmallest() == null
            ? JiffUnit.NANOSECOND
            : config.getSmallest();
        JiffUnit largest = config.getLargest() == null
            ? JiffMath.largerOf(smallest, JiffUnit.HOUR)
            : config.getLargest();
        JiffSpan span = until(other, largest);
        return JiffSpanRelative.roundDifference(
            negate ? span.negate() : span,
            config,
            smallest,
            JiffSpanRelativeTo.fromZonedDateTime(this),
            false
        );
    }

    /**
     * The exact length of time from this zoned datetime until `other`. It is negative when
     * `other` is earlier. This never fails, and the time zones play no part.
     *
     *     // The day New York springs forward is 23 hours long.
     *     JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 3, 10).inTz('America/New_York');
     *     JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 3, 11).inTz('America/New_York');
     *     zdt1.durationUntil(zdt2);          // PT23H
     *     zdt1.until(zdt2, JiffUnit.DAY);    // P1D
     */
    public JiffSignedDuration durationUntil(JiffZonedDateTime other) {
        return ts.durationUntil(other.ts);
    }

    /**
     * The exact length of time from `other` until this zoned datetime. It is negative when
     * `other` is later. This never fails.
     */
    public JiffSignedDuration durationSince(JiffZonedDateTime other) {
        return other.ts.durationUntil(ts);
    }

    // ---- rounding -------------------------------------------------------

    /**
     * Rounds this zoned datetime to the nearest multiple of `unit`, with ties rounding up.
     *
     *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 6, 19).at(15, 0, 0, 0)
     *         .inTz('America/New_York');
     *     zdt.round(JiffUnit.DAY);   // 2024-06-20T00:00:00-04:00[America/New_York]
     *
     * See `round(JiffRound)` for the units allowed and the ways this can fail.
     */
    public JiffZonedDateTime round(JiffUnit unit) {
        return round(JiffRound.to(unit));
    }

    /**
     * Rounds this zoned datetime according to `options`: a smallest unit, a rounding mode and
     * a rounding increment.
     *
     *     // The nearest five minutes.
     *     JiffZonedDateTime zdt = JiffDate.newInstance(2024, 6, 19).at(15, 27, 30, 0)
     *         .inTz('America/New_York');
     *     zdt.round(JiffRound.to(JiffUnit.MINUTE).increment(5));
     *     // 2024-06-19T15:30:00-04:00[America/New_York]
     *
     * The smallest unit must be days or smaller. With days the increment must be `1`; with a
     * smaller unit it must divide evenly into the next unit up without being equal to it.
     *
     * For hours and smaller units the civil time is rounded, as `JiffDateTime.round` does, and
     * the result is turned back into an instant while keeping the current offset whenever it
     * is still valid, so rounding inside a repeated hour stays in the same repetition. If the
     * rounded civil time does not exist, it is resolved with the `COMPATIBLE` strategy:
     * `01:59` just before New York springs forward rounds to `03:00`.
     *
     * For days, the progress through the actual civil day is rounded, from its first instant
     * to the first instant of the next day. On a 23 hour day the tipping point is therefore
     * `12:30` on the clock, and on a 25 hour day `11:30`. The result is the start of this day
     * or of the next.
     *
     * Throws for an unsupported unit or increment, or if the result is outside the supported
     * range.
     */
    public JiffZonedDateTime round(JiffRound options) {
        if (options.getSmallest() == JiffUnit.DAY) {
            return roundToDay(options);
        }
        JiffDateTime rounded = dt.round(options);
        // Prefer the offset this datetime already has, so that a small change of clock time
        // does not jump to the other side of a fold.
        return JiffOffsetConflicts.resolve(JiffOffsetConflict.PREFER_OFFSET, rounded, off, tz)
            .compatible();
    }

    private JiffZonedDateTime roundToDay(JiffRound options) {
        try {
            JiffRounding.incrementForDateTime(JiffUnit.DAY, options.getIncrement());
        } catch (JiffException e) {
            throw inContext('failed rounding datetime', e);
        }
        JiffZonedDateTime dayStart;
        try {
            dayStart = startOfDay();
        } catch (JiffException e) {
            throw inContext('failed to find start of day for zoned datetime', e);
        }
        JiffZonedDateTime dayEnd;
        try {
            dayEnd = dayStart.tomorrow();
        } catch (JiffException e) {
            throw inContext('failed to add 1 day to zoned datetime to find length of day', e);
        }
        if (dayStart.ts.equals(dayEnd.ts)) {
            // Rounding to a multiple of nothing is meaningless. Adding a day should always
            // move the instant, but time zone data is strange enough to check.
            throw new JiffException('failed to add 1 day to zoned datetime to find length of day');
        }
        // Both lengths are at most a few days, so their nanoseconds fit a Long comfortably.
        Long dayLength = dayStart.ts.durationUntil(dayEnd.ts).asNanos();
        Long progress = dayStart.ts.durationUntil(ts).asNanos();
        Long rounded = JiffRounding.roundLong(options.getMode(), progress, dayLength);
        return newInstance(dayStart.ts.add(JiffSignedDuration.fromNanos(rounded)), tz);
    }

    // ---- series ---------------------------------------------------------

    /**
     * The zoned datetimes a fixed span apart, starting with this one: this datetime, this
     * datetime plus `period`, this datetime plus twice `period`, and so on. A negative period
     * walks backwards.
     *
     *     // Every 30 minutes across the hour New York skips on 2025-03-09.
     *     JiffZonedDateTime start = JiffDate.newInstance(2025, 3, 9).at(1, 0, 0, 0)
     *         .inTz('America/New_York');
     *     JiffZonedDateTimeSeries series = start.series(new JiffSpan().minutes(30));
     *     series.next();   // 2025-03-09T01:00:00-05:00[America/New_York]
     *     series.next();   // 2025-03-09T01:30:00-05:00[America/New_York]
     *     series.next();   // 2025-03-09T03:00:00-04:00[America/New_York]
     *
     * Each element is computed from the start with zone aware arithmetic, and an element that
     * would not be strictly later (or earlier, for a negative period) than the one before it
     * is left out, so the series never repeats an instant. The series has no end of its own;
     * a loop over it needs its own exit. See `JiffZonedDateTimeSeries`.
     */
    public JiffZonedDateTimeSeries series(JiffSpan period) {
        return new JiffZonedDateTimeSeries(this, period);
    }

    // ---- comparison -----------------------------------------------------

    /**
     * Orders zoned datetimes by their instant: negative when this one is earlier than
     * `other`, zero when they are the same instant and positive when it is later. The civil
     * datetimes and the time zones are not compared.
     */
    public Integer compareTo(Object other) {
        return ts.compareTo(((JiffZonedDateTime) other).ts);
    }

    /** Whether this instant is strictly earlier than `other`. */
    public Boolean isBefore(JiffZonedDateTime other) {
        return compareTo(other) < 0;
    }

    /** Whether this instant is strictly later than `other`. */
    public Boolean isAfter(JiffZonedDateTime other) {
        return compareTo(other) > 0;
    }

    /**
     * Whether `other` is a zoned datetime for the same instant. As in Jiff, the time zone is
     * not compared: noon in New York equals 9am in Los Angeles on the same day. To require
     * the same zone as well, also compare `timeZone()`.
     */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffZonedDateTime)) {
            return false;
        }
        return ts.equals(((JiffZonedDateTime) other).ts);
    }

    /** A hash of the instant, consistent with `equals`. */
    public Integer hashCode() {
        return ts.hashCode();
    }

    /**
     * Formats this zoned datetime in the RFC 9557 form: the civil datetime, the offset, and
     * the time zone in brackets.
     *
     * - An IANA zone: `2024-03-10T03:30:00-04:00[America/New_York]`.
     * - `UTC`: `2024-03-10T07:30:00+00:00[UTC]`.
     * - A fixed offset zone repeats the offset: `2024-03-10T02:00:00-05:30[-05:30]`.
     * - The unknown zone: `2024-03-10T07:30:00Z[Etc/Unknown]`.
     *
     * A fractional second is written only when it is non-zero. RFC 9557 has no room for
     * seconds in an offset, so an offset with seconds is rounded to the nearest minute.
     */
    public override String toString() {
        String civil = JiffTemporal.printDateTime(dt);
        if (tz.isUnknown()) {
            return civil + 'Z[Etc/Unknown]';
        }
        String printedOffset = JiffTemporal.printOffset(off);
        String zoneName = tz.ianaName();
        return civil + printedOffset + '[' + (zoneName == null ? printedOffset : zoneName) + ']';
    }
}
