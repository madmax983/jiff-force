/**
 * Reads and writes the date, time and datetime fields of records as jiff-force values.
 *
 *     Opportunity opp = [SELECT CloseDate FROM Opportunity WHERE Id = :oppId];
 *     JiffDate closeDate = JiffRecords.getDate(opp, Opportunity.CloseDate);
 *     JiffRecords.putDate(opp, Opportunity.CloseDate, closeDate.add(new JiffSpan().months(1)));
 *
 *     Event meeting = [SELECT ActivityDateTime FROM Event WHERE Id = :eventId];
 *     JiffZonedDateTime starts = JiffRecords.getZonedDateTime(meeting, Event.ActivityDateTime);
 *
 * Every method takes the field either as a token (`Opportunity.CloseDate`) or by name
 * (`'CloseDate'`, ignoring case), which suits code that does not know the object in advance.
 *
 * How each kind of field maps:
 *
 * - A **Date** field holds a calendar day with no time zone: `JiffDate`.
 * - A **Time** field holds a wall clock time with no date or zone: `JiffTime`.
 * - A **Datetime** field holds an instant. Read it as a `JiffTimestamp` (the instant itself),
 *   a `JiffZonedDateTime` (the instant seen in a time zone, by default the running user's), or
 *   a `JiffDateTime` (only the wall clock reading in a zone you name).
 *
 * An empty field reads as null, and writing null empties the field. Writing truncates anything
 * finer than a millisecond, the precision of the platform types. All conversions are
 * independent of the running user's locale, including locales with a non-Gregorian calendar.
 *
 * The field's declared type is checked against the method used, and a mismatch throws
 * `JiffException`. This catches mistakes the platform would let through: a Date value counts
 * as a Datetime in Apex, and putting a Datetime into a Date field silently converts it.
 *
 * Reading a field that the query did not select throws the platform's `SObjectException`, as
 * reading it directly would.
 *
 * There is no Jiff counterpart; this is jiff-force's bridge to Salesforce data.
 */
public class JiffRecords {
    private JiffRecords() {
    }

    // ---- Date fields ----------------------------------------------------

    /** Reads a Date field as a `JiffDate`, or null when the field is empty. */
    public static JiffDate getDate(SObject record, Schema.SObjectField field) {
        return JiffDate.fromSystemDate((Date) read(record, field, Schema.DisplayType.DATE));
    }

    /** Reads the Date field with the given name as a `JiffDate`, or null when it is empty. */
    public static JiffDate getDate(SObject record, String fieldName) {
        return getDate(record, resolve(record, fieldName));
    }

    /** Writes a `JiffDate` to a Date field. A null value empties the field. */
    public static void putDate(SObject record, Schema.SObjectField field, JiffDate value) {
        write(record, field, Schema.DisplayType.DATE, value == null ? null : value.toSystemDate());
    }

    /** Writes a `JiffDate` to the Date field with the given name. Null empties the field. */
    public static void putDate(SObject record, String fieldName, JiffDate value) {
        putDate(record, resolve(record, fieldName), value);
    }

    // ---- Time fields ----------------------------------------------------

    /** Reads a Time field as a `JiffTime`, or null when the field is empty. */
    public static JiffTime getTime(SObject record, Schema.SObjectField field) {
        return JiffTime.fromSystemTime((Time) read(record, field, Schema.DisplayType.TIME));
    }

    /** Reads the Time field with the given name as a `JiffTime`, or null when it is empty. */
    public static JiffTime getTime(SObject record, String fieldName) {
        return getTime(record, resolve(record, fieldName));
    }

    /**
     * Writes a `JiffTime` to a Time field, dropping anything finer than a millisecond. A null
     * value empties the field.
     */
    public static void putTime(SObject record, Schema.SObjectField field, JiffTime value) {
        write(record, field, Schema.DisplayType.TIME, value == null ? null : value.toSystemTime());
    }

    /** Writes a `JiffTime` to the Time field with the given name. Null empties the field. */
    public static void putTime(SObject record, String fieldName, JiffTime value) {
        putTime(record, resolve(record, fieldName), value);
    }

    // ---- Datetime fields ------------------------------------------------

    /** Reads a Datetime field as the instant it holds, or null when the field is empty. */
    public static JiffTimestamp getTimestamp(SObject record, Schema.SObjectField field) {
        return JiffTimestamp.fromSystemDatetime(
            (Datetime) read(record, field, Schema.DisplayType.DATETIME)
        );
    }

    /** Reads the Datetime field with the given name as an instant, or null when it is empty. */
    public static JiffTimestamp getTimestamp(SObject record, String fieldName) {
        return getTimestamp(record, resolve(record, fieldName));
    }

    /**
     * Writes an instant to a Datetime field, dropping anything finer than a millisecond. A
     * null value empties the field.
     */
    public static void putTimestamp(
        SObject record,
        Schema.SObjectField field,
        JiffTimestamp value
    ) {
        write(
            record,
            field,
            Schema.DisplayType.DATETIME,
            value == null ? null : value.toSystemDatetime()
        );
    }

    /** Writes an instant to the Datetime field with the given name. Null empties the field. */
    public static void putTimestamp(SObject record, String fieldName, JiffTimestamp value) {
        putTimestamp(record, resolve(record, fieldName), value);
    }

    /**
     * Reads a Datetime field as a zoned datetime in the running user's time zone, which is how
     * the user sees the value in Salesforce. Null when the field is empty.
     */
    public static JiffZonedDateTime getZonedDateTime(SObject record, Schema.SObjectField field) {
        return getZonedDateTime(record, field, JiffTimeZone.userTimeZone());
    }

    /** Reads the named Datetime field in the running user's time zone. Null when empty. */
    public static JiffZonedDateTime getZonedDateTime(SObject record, String fieldName) {
        return getZonedDateTime(record, resolve(record, fieldName));
    }

    /** Reads a Datetime field as a zoned datetime in the given time zone. Null when empty. */
    public static JiffZonedDateTime getZonedDateTime(
        SObject record,
        Schema.SObjectField field,
        JiffTimeZone tz
    ) {
        requireZone(tz);
        JiffTimestamp instant = getTimestamp(record, field);
        return instant == null ? null : instant.toZonedDateTime(tz);
    }

    /** Reads the named Datetime field as a zoned datetime in the given zone. Null when empty. */
    public static JiffZonedDateTime getZonedDateTime(
        SObject record,
        String fieldName,
        JiffTimeZone tz
    ) {
        return getZonedDateTime(record, resolve(record, fieldName), tz);
    }

    /**
     * Writes the instant of a zoned datetime to a Datetime field. A Datetime field stores only
     * the instant, so the time zone is not kept. A null value empties the field.
     */
    public static void putZonedDateTime(
        SObject record,
        Schema.SObjectField field,
        JiffZonedDateTime value
    ) {
        putTimestamp(record, field, value == null ? null : value.toTimestamp());
    }

    /** Writes the instant of a zoned datetime to the named Datetime field. Null empties it. */
    public static void putZonedDateTime(SObject record, String fieldName, JiffZonedDateTime value) {
        putZonedDateTime(record, resolve(record, fieldName), value);
    }

    /**
     * Reads a Datetime field as the wall clock reading of its instant in the given time zone.
     * Null when the field is empty.
     *
     *     // The local time a meeting starts at its venue.
     *     JiffDateTime local = JiffRecords.getDateTime(
     *         meeting, Event.ActivityDateTime, JiffTimeZone.get('Europe/London'));
     */
    public static JiffDateTime getDateTime(
        SObject record,
        Schema.SObjectField field,
        JiffTimeZone tz
    ) {
        JiffZonedDateTime zoned = getZonedDateTime(record, field, tz);
        return zoned == null ? null : zoned.toDateTime();
    }

    /** Reads the named Datetime field as a wall clock reading in the given zone. */
    public static JiffDateTime getDateTime(SObject record, String fieldName, JiffTimeZone tz) {
        return getDateTime(record, resolve(record, fieldName), tz);
    }

    /**
     * Writes a wall clock reading in the given time zone to a Datetime field, as the instant
     * at which that zone's clocks show it. When the reading falls in a gap or a fold of a
     * daylight saving change, the instant is chosen the way `JiffDisambiguation.COMPATIBLE`
     * does. A null value empties the field.
     */
    public static void putDateTime(
        SObject record,
        Schema.SObjectField field,
        JiffDateTime value,
        JiffTimeZone tz
    ) {
        requireZone(tz);
        putTimestamp(record, field, value == null ? null : tz.toTimestamp(value));
    }

    /** Writes a wall clock reading in the given zone to the named Datetime field. */
    public static void putDateTime(
        SObject record,
        String fieldName,
        JiffDateTime value,
        JiffTimeZone tz
    ) {
        putDateTime(record, resolve(record, fieldName), value, tz);
    }

    // ---- internals ------------------------------------------------------

    private static Object read(
        SObject record,
        Schema.SObjectField field,
        Schema.DisplayType expected
    ) {
        check(record, field, expected);
        return record.get(field);
    }

    private static void write(
        SObject record,
        Schema.SObjectField field,
        Schema.DisplayType expected,
        Object value
    ) {
        check(record, field, expected);
        record.put(field, value);
    }

    private static void check(
        SObject record,
        Schema.SObjectField field,
        Schema.DisplayType expected
    ) {
        if (record == null) {
            throw new JiffException('the record must not be null');
        }
        if (field == null) {
            throw new JiffException('the field must not be null');
        }
        Schema.DescribeFieldResult describe = field.getDescribe();
        Schema.DisplayType actual = describe.getType();
        if (actual != expected) {
            throw new JiffException(
                'field ' +
                    describe.getName() +
                    ' is a ' +
                    actual.name() +
                    ' field, not a ' +
                    expected.name() +
                    ' field'
            );
        }
    }

    private static Schema.SObjectField resolve(SObject record, String fieldName) {
        if (record == null) {
            throw new JiffException('the record must not be null');
        }
        if (fieldName == null) {
            throw new JiffException('the field name must not be null');
        }
        Schema.DescribeSObjectResult objectDescribe = record.getSObjectType().getDescribe();
        Schema.SObjectField field = objectDescribe.fields.getMap().get(fieldName);
        if (field == null) {
            throw new JiffException(
                'there is no field named \'' + fieldName + '\' on ' + objectDescribe.getName()
            );
        }
        return field;
    }

    private static void requireZone(JiffTimeZone tz) {
        if (tz == null) {
            throw new JiffException('the time zone must not be null');
        }
    }
}
