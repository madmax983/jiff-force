/**
 * Runs on AER and on a real org only: the JVM harness does not model SObjects, so this class
 * and JiffRecords are listed in tools/apexjvm/aer-only.txt.
 *
 * Platform values are built from epoch milliseconds so the tests hold under any user locale.
 */
@IsTest
private class JiffRecordsTest {
    private static final Long MILLIS_PER_DAY = 86400000L;
    // 2024-07-04T11:39:00Z, which is 07:39 in New York (EDT, -04:00).
    private static final Long JULY_FOURTH = 1720093140000L;

    private static Date platformDay(Long epochDay) {
        return Datetime.newInstance(epochDay * MILLIS_PER_DAY).dateGmt();
    }

    private static void assertRejected(String expected, String actual) {
        Assert.areEqual(expected, actual);
    }

    // ---- Date fields ----------------------------------------------------

    @IsTest
    static void readsADateFieldByTokenAndByName() {
        Opportunity opp = new Opportunity(CloseDate = platformDay(19782L));
        Assert.areEqual(
            JiffDate.newInstance(2024, 2, 29),
            JiffRecords.getDate(opp, Opportunity.CloseDate)
        );
        Assert.areEqual(JiffDate.newInstance(2024, 2, 29), JiffRecords.getDate(opp, 'CloseDate'));
        // Field names ignore case, as they do everywhere in Apex.
        Assert.areEqual(JiffDate.newInstance(2024, 2, 29), JiffRecords.getDate(opp, 'closedate'));
    }

    @IsTest
    static void anEmptyDateFieldReadsAsNull() {
        Opportunity opp = new Opportunity();
        Assert.isNull(JiffRecords.getDate(opp, Opportunity.CloseDate));
        Assert.isNull(JiffRecords.getDate(opp, 'CloseDate'));
    }

    @IsTest
    static void writesADateFieldAndNullEmptiesIt() {
        Opportunity opp = new Opportunity();
        JiffRecords.putDate(opp, Opportunity.CloseDate, JiffDate.newInstance(2024, 2, 29));
        Assert.areEqual(platformDay(19782L), opp.CloseDate);
        JiffRecords.putDate(opp, 'CloseDate', JiffDate.newInstance(1969, 12, 31));
        Assert.areEqual(platformDay(-1L), opp.CloseDate);
        JiffRecords.putDate(opp, Opportunity.CloseDate, null);
        Assert.isNull(opp.CloseDate);
    }

    @IsTest
    static void aDateRoundTripsThroughAField() {
        Opportunity opp = new Opportunity();
        JiffDate closeDate = JiffDate.newInstance(2024, 1, 31);
        JiffRecords.putDate(opp, Opportunity.CloseDate, closeDate.add(new JiffSpan().months(1)));
        Assert.areEqual(
            JiffDate.newInstance(2024, 2, 29),
            JiffRecords.getDate(opp, Opportunity.CloseDate)
        );
    }

    // ---- Time fields ----------------------------------------------------

    @IsTest
    static void readsAndWritesATimeField() {
        BusinessHours hours = new BusinessHours(MondayStartTime = Time.newInstance(9, 30, 0, 250));
        Assert.areEqual(
            JiffTime.newInstance(9, 30, 0, 250000000),
            JiffRecords.getTime(hours, BusinessHours.MondayStartTime)
        );
        Assert.isNull(JiffRecords.getTime(hours, 'MondayEndTime'));
        // Anything finer than a millisecond is truncated on the way in.
        JiffRecords.putTime(hours, 'MondayEndTime', JiffTime.newInstance(17, 0, 0, 999999999));
        Assert.areEqual(Time.newInstance(17, 0, 0, 999), hours.MondayEndTime);
        JiffRecords.putTime(hours, BusinessHours.MondayEndTime, null);
        Assert.isNull(hours.MondayEndTime);
    }

    // ---- Datetime fields ------------------------------------------------

    @IsTest
    static void readsADatetimeFieldAsAnInstant() {
        Event meeting = new Event(ActivityDateTime = Datetime.newInstance(JULY_FOURTH));
        Assert.areEqual(
            JiffTimestamp.fromMillisecond(JULY_FOURTH),
            JiffRecords.getTimestamp(meeting, Event.ActivityDateTime)
        );
        Assert.areEqual(
            '2024-07-04T11:39:00Z',
            JiffRecords.getTimestamp(meeting, 'ActivityDateTime').toString()
        );
        Assert.isNull(JiffRecords.getTimestamp(new Event(), Event.ActivityDateTime));
    }

    @IsTest
    static void readsADatetimeFieldInAZone() {
        Event meeting = new Event(ActivityDateTime = Datetime.newInstance(JULY_FOURTH));
        JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
        Assert.areEqual(
            '2024-07-04T07:39:00-04:00[America/New_York]',
            JiffRecords.getZonedDateTime(meeting, Event.ActivityDateTime, newYork).toString()
        );
        Assert.areEqual(
            JiffDateTime.newInstance(2024, 7, 4, 7, 39, 0, 0),
            JiffRecords.getDateTime(meeting, 'ActivityDateTime', newYork)
        );
        Assert.areEqual(
            JiffDateTime.newInstance(2024, 7, 4, 17, 9, 0, 0),
            JiffRecords.getDateTime(
                meeting,
                Event.ActivityDateTime,
                JiffTimeZone.get('Asia/Kolkata')
            )
        );
        Assert.isNull(JiffRecords.getZonedDateTime(new Event(), 'ActivityDateTime', newYork));
        Assert.isNull(JiffRecords.getDateTime(new Event(), Event.ActivityDateTime, newYork));
    }

    @IsTest
    static void readsADatetimeFieldInTheUsersZoneByDefault() {
        Event meeting = new Event(ActivityDateTime = Datetime.newInstance(JULY_FOURTH));
        JiffZonedDateTime seen = JiffRecords.getZonedDateTime(meeting, Event.ActivityDateTime);
        Assert.areEqual(JiffTimeZone.userTimeZone(), seen.timeZone());
        Assert.areEqual(JiffTimestamp.fromMillisecond(JULY_FOURTH), seen.toTimestamp());
        Assert.areEqual(seen, JiffRecords.getZonedDateTime(meeting, 'ActivityDateTime'));
        Assert.isNull(JiffRecords.getZonedDateTime(new Event(), Event.ActivityDateTime));
    }

    @IsTest
    static void writesInstantsToADatetimeField() {
        Event meeting = new Event();
        JiffRecords.putTimestamp(
            meeting,
            Event.ActivityDateTime,
            JiffTimestamp.newInstance(JULY_FOURTH / 1000, 999999999)
        );
        // Truncated to the millisecond.
        Assert.areEqual(JULY_FOURTH + 999, meeting.ActivityDateTime.getTime());
        JiffRecords.putZonedDateTime(
            meeting,
            'ActivityDateTime',
            JiffTimestamp.fromMillisecond(JULY_FOURTH).inTz('Asia/Tokyo')
        );
        Assert.areEqual(JULY_FOURTH, meeting.ActivityDateTime.getTime());
        JiffRecords.putTimestamp(meeting, 'ActivityDateTime', null);
        Assert.isNull(meeting.ActivityDateTime);
        JiffRecords.putZonedDateTime(meeting, Event.ActivityDateTime, null);
        Assert.isNull(meeting.ActivityDateTime);
    }

    @IsTest
    static void writesAWallClockReadingInAZone() {
        Event meeting = new Event();
        JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
        JiffRecords.putDateTime(
            meeting,
            Event.ActivityDateTime,
            JiffDateTime.newInstance(2024, 7, 4, 7, 39, 0, 0),
            newYork
        );
        Assert.areEqual(JULY_FOURTH, meeting.ActivityDateTime.getTime());
        // 02:30 on 2024-03-10 does not exist in New York; compatible resolution moves it to 03:30 EDT.
        JiffRecords.putDateTime(
            meeting,
            'ActivityDateTime',
            JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0),
            newYork
        );
        Assert.areEqual(1710055800000L, meeting.ActivityDateTime.getTime());
        // 01:30 on 2024-11-03 happens twice; compatible resolution takes the earlier, EDT one.
        JiffRecords.putDateTime(
            meeting,
            Event.ActivityDateTime,
            JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0),
            newYork
        );
        Assert.areEqual(1730611800000L, meeting.ActivityDateTime.getTime());
        JiffRecords.putDateTime(meeting, Event.ActivityDateTime, null, newYork);
        Assert.isNull(meeting.ActivityDateTime);
    }

    // ---- mistakes -------------------------------------------------------

    @IsTest
    static void rejectsAFieldOfTheWrongType() {
        Opportunity opp = new Opportunity(Name = 'x', CloseDate = platformDay(0L));
        Event meeting = new Event(ActivityDateTime = Datetime.newInstance(0L));
        try {
            // A Date value counts as a Datetime in Apex, so only the field type can catch this.
            JiffRecords.getTimestamp(opp, Opportunity.CloseDate);
            Assert.fail('expected a Date field to be rejected as a Datetime');
        } catch (JiffException e) {
            assertRejected('field CloseDate is a DATE field, not a DATETIME field', e.getMessage());
        }
        try {
            JiffRecords.putDate(meeting, Event.ActivityDateTime, JiffDate.ZERO);
            Assert.fail('expected a Datetime field to be rejected as a Date');
        } catch (JiffException e) {
            assertRejected(
                'field ActivityDateTime is a DATETIME field, not a DATE field',
                e.getMessage()
            );
        }
        try {
            JiffRecords.getTime(opp, 'Name');
            Assert.fail('expected a text field to be rejected');
        } catch (JiffException e) {
            assertRejected('field Name is a STRING field, not a TIME field', e.getMessage());
        }
        // Nothing was written by the rejected put.
        Assert.areEqual(0L, meeting.ActivityDateTime.getTime());
    }

    @IsTest
    static void rejectsMissingArguments() {
        Opportunity opp = new Opportunity();
        Map<String, String> expected = new Map<String, String>{
            'record' => 'the record must not be null',
            'field' => 'the field must not be null',
            'name' => 'the field name must not be null',
            'unknown' => 'there is no field named \'Closing\' on Opportunity',
            'zone' => 'the time zone must not be null'
        };
        for (String which : expected.keySet()) {
            try {
                if (which.equals('record')) {
                    JiffRecords.getDate(null, Opportunity.CloseDate);
                } else if (which.equals('field')) {
                    Schema.SObjectField missing = null;
                    JiffRecords.getDate(opp, missing);
                } else if (which.equals('name')) {
                    String missing = null;
                    JiffRecords.getDate(opp, missing);
                } else if (which.equals('unknown')) {
                    JiffRecords.getDate(opp, 'Closing');
                } else {
                    JiffRecords.getZonedDateTime(new Event(), Event.ActivityDateTime, null);
                }
                Assert.fail('expected ' + which + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(expected.get(which), e.getMessage());
            }
        }
        try {
            JiffRecords.putDateTime(new Event(), 'ActivityDateTime', JiffDateTime.MIN, null);
            Assert.fail('expected a missing zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the time zone must not be null', e.getMessage());
        }
        try {
            String fieldName = 'CloseDate';
            JiffRecords.putDate(null, fieldName, JiffDate.ZERO);
            Assert.fail('expected a missing record to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the record must not be null', e.getMessage());
        }
    }
}
