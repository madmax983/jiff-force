/**
 * Construction, accessors, neighbouring datetimes, comparison and text of `JiffZonedDateTime`.
 * Arithmetic, rounding, `with()` and series have their own test classes.
 *
 * Expected values are from the examples in Jiff's documentation of `ZonedDateTime`, or were
 * printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffZonedDateTimeTest {
    private static final String NEW_YORK = 'America/New_York';
    private static final String TIMESTAMP_RANGE =
        'parameter \'Unix timestamp seconds\' is not in the required range of ' +
        '-377705023201..=253402207200';

    private static JiffZonedDateTime zoned(String text) {
        return JiffZonedTestSupport.zoned(text);
    }

    /** A civil datetime in New York, the zone most of Jiff's examples use. */
    private static JiffZonedDateTime newYork(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDate.newInstance(year, month, day)
            .at(hour, minute, second, subsecNanosecond)
            .inTz(NEW_YORK);
    }

    private static String overflowAt(String offsetText) {
        return 'converting datetime with time zone offset `' +
            offsetText +
            '` to timestamp overflowed: ' +
            TIMESTAMP_RANGE;
    }

    // ---- construction ---------------------------------------------------

    @IsTest
    static void anInstantReadsDifferentlyInEachZone() {
        // 2024-07-04T11:39:00Z, as Jiff prints it in each zone.
        JiffTimestamp ts = JiffTimestamp.fromSecond(1720093140L);
        Map<String, String> expected = new Map<String, String>{
            'Australia/Sydney' => '2024-07-04T21:39:00+10:00[Australia/Sydney]',
            'America/New_York' => '2024-07-04T07:39:00-04:00[America/New_York]',
            'Europe/London' => '2024-07-04T12:39:00+01:00[Europe/London]',
            'Asia/Kolkata' => '2024-07-04T17:09:00+05:30[Asia/Kolkata]',
            'America/Sao_Paulo' => '2024-07-04T08:39:00-03:00[America/Sao_Paulo]',
            'Pacific/Apia' => '2024-07-05T00:39:00+13:00[Pacific/Apia]',
            'UTC' => '2024-07-04T11:39:00+00:00[UTC]'
        };
        for (String name : expected.keySet()) {
            JiffZonedDateTime zdt = JiffZonedDateTime.newInstance(ts, JiffTimeZone.get(name));
            Assert.areEqual(expected.get(name), zdt.toString());
            Assert.areEqual(ts, zdt.toTimestamp(), name);
            Assert.areEqual(JiffTimeZone.get(name), zdt.timeZone());
        }
    }

    @IsTest
    static void theEpochInSydneyIsTenInTheMorning() {
        JiffZonedDateTime zdt = JiffZonedDateTime.newInstance(
            JiffTimestamp.UNIX_EPOCH,
            JiffTimeZone.get('Australia/Sydney')
        );
        Assert.areEqual('1970-01-01T10:00:00+10:00[Australia/Sydney]', zdt.toString());
    }

    @IsTest
    static void needsATimestampAndATimeZone() {
        try {
            JiffZonedDateTime.newInstance(null, JiffTimeZone.UTC);
            Assert.fail('expected a missing timestamp to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a zoned datetime needs both a timestamp and a time zone',
                e.getMessage()
            );
        }
        try {
            JiffZonedDateTime.newInstance(JiffTimestamp.UNIX_EPOCH, null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a zoned datetime needs both a timestamp and a time zone',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void unixEpochIsTheEpochInUtc() {
        // `ZonedDateTime::UNIX_EPOCH`, which is also `ZonedDateTime::default()`.
        JiffZonedDateTime epoch = JiffZonedDateTime.UNIX_EPOCH;
        Assert.areEqual('1970-01-01T00:00:00+00:00[UTC]', epoch.toString());
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, epoch.toTimestamp());
        Assert.areEqual(JiffTimeZone.UTC, epoch.timeZone());
        Assert.areEqual(JiffOffset.UTC, epoch.offset());
    }

    @IsTest
    static void nowIsTheCurrentInstantInTheUsersZone() {
        JiffTimestamp before = JiffTimestamp.now();
        JiffZonedDateTime zdt = JiffZonedDateTime.now();
        JiffTimestamp after = JiffTimestamp.now();
        // Jiff's own example: assert!(ZonedDateTime::now().timestamp() > Timestamp::UNIX_EPOCH)
        Assert.isTrue(zdt.toTimestamp().isAfter(JiffTimestamp.UNIX_EPOCH));
        Assert.isFalse(zdt.toTimestamp().isBefore(before));
        Assert.isFalse(zdt.toTimestamp().isAfter(after));
        Assert.areEqual(JiffTimeZone.userTimeZone(), zdt.timeZone());
        Assert.areEqual(UserInfo.getTimeZone().getID(), zdt.timeZone().ianaName());
    }

    @IsTest
    static void fromDateTimeResolvesGapsAndFoldsCompatibly() {
        JiffTimeZone tz = JiffTimeZone.get(NEW_YORK);
        Assert.areEqual(
            '2024-07-15T17:30:00-04:00[America/New_York]',
            JiffZonedDateTime.fromDateTime(JiffDateTime.newInstance(2024, 7, 15, 17, 30, 0, 0), tz)
                .toString()
        );
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            JiffZonedDateTime.fromDateTime(JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0), tz)
                .toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            JiffZonedDateTime.fromDateTime(JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0), tz)
                .toString()
        );
        try {
            JiffZonedDateTime.fromDateTime(null, tz);
            Assert.fail('expected a missing datetime to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a zoned datetime needs both a civil datetime and a time zone',
                e.getMessage()
            );
        }
        try {
            JiffZonedDateTime.fromDateTime(JiffDateTime.ZERO, null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a zoned datetime needs both a civil datetime and a time zone',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void withTimeZoneKeepsTheInstantAndChangesTheClock() {
        JiffZonedDateTime london = JiffDate.newInstance(2024, 7, 4)
            .at(12, 0, 0, 0)
            .inTz('Europe/London');
        Assert.areEqual('2024-07-04T12:00:00+01:00[Europe/London]', london.toString());
        JiffZonedDateTime inNewYork = london.withTimeZone(JiffTimeZone.get(NEW_YORK));
        Assert.areEqual('2024-07-04T07:00:00-04:00[America/New_York]', inNewYork.toString());
        Assert.areEqual(london.toTimestamp(), inNewYork.toTimestamp());
        Assert.areEqual(
            '2024-07-04T16:30:00+05:30[Asia/Kolkata]',
            london.inTz('Asia/Kolkata').toString()
        );
        Assert.areEqual(london.toTimestamp(), london.inTz('Asia/Kolkata').toTimestamp());
    }

    @IsTest
    static void inTzRejectsAnUnknownZone() {
        try {
            JiffZonedDateTime.UNIX_EPOCH.inTz('Not/AZone');
            Assert.fail('expected an unknown zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time zone `Not/AZone` in time zone database',
                e.getMessage()
            );
        }
    }

    // ---- accessors ------------------------------------------------------

    @IsTest
    static void exposesItsCivilFields() {
        JiffZonedDateTime zdt = newYork(2000, 1, 2, 3, 4, 5, 123456789);
        Assert.areEqual(2000, zdt.year());
        Assert.areEqual(1, zdt.month());
        Assert.areEqual(2, zdt.day());
        Assert.areEqual(3, zdt.hour());
        Assert.areEqual(4, zdt.minute());
        Assert.areEqual(5, zdt.second());
        Assert.areEqual(123, zdt.millisecond());
        Assert.areEqual(456, zdt.microsecond());
        Assert.areEqual(789, zdt.nanosecond());
        Assert.areEqual(123456789, zdt.subsecNanosecond());
        Assert.areEqual(333456789, zdt.with().millisecond(333).build().subsecNanosecond());
    }

    @IsTest
    static void exposesItsParts() {
        JiffZonedDateTime zdt = newYork(2024, 3, 14, 18, 45, 0, 0);
        Assert.areEqual(1710456300L, zdt.toTimestamp().asSecond());
        Assert.areEqual(JiffDateTime.newInstance(2024, 3, 14, 18, 45, 0, 0), zdt.toDateTime());
        Assert.areEqual(JiffDate.newInstance(2024, 3, 14), zdt.toDate());
        Assert.areEqual(JiffTime.newInstance(18, 45, 0, 0), zdt.toTime());
        Assert.areEqual(NEW_YORK, zdt.timeZone().ianaName());
    }

    @IsTest
    static void theOffsetFollowsDaylightSavingTime() {
        // -05 because New York is in "standard" time at this point.
        Assert.areEqual(JiffOffset.fromHours(-5), newYork(2024, 2, 14, 18, 45, 0, 0).offset());
        // But we get -04 once "summer" or "daylight saving time" starts.
        Assert.areEqual(JiffOffset.fromHours(-4), newYork(2024, 7, 14, 18, 45, 0, 0).offset());
    }

    @IsTest
    static void theYearHasAnEra() {
        // The era is a property of the civil year, whatever the zone.
        JiffTimeZone tz = JiffTimeZone.fixed(JiffOffset.fromHours(-5));
        List<List<Integer>> cases = new List<List<Integer>>{
            // year, era year, 1 for CE or 0 for BCE
            new List<Integer>{ 2024, 2024, 1 },
            new List<Integer>{ 1, 1, 1 },
            new List<Integer>{ 0, 1, 0 },
            new List<Integer>{ -1, 2, 0 },
            new List<Integer>{ -10, 11, 0 },
            new List<Integer>{ -9999, 10000, 0 }
        };
        for (List<Integer> row : cases) {
            JiffZonedDateTime zdt = JiffDate.newInstance(row.get(0), 10, 3)
                .at(7, 30, 0, 0)
                .toZonedDateTime(tz);
            Assert.areEqual(row.get(0), zdt.year());
            Assert.areEqual(row.get(1), zdt.eraYear(), 'era year of ' + row.get(0));
            Assert.areEqual(row.get(2) == 1 ? JiffEra.CE : JiffEra.BCE, zdt.era());
        }
    }

    @IsTest
    static void theCivilFractionIsPositiveEvenBeforeTheEpoch() {
        // 1,234 nanoseconds after the Unix epoch.
        JiffZonedDateTime zdt = JiffTimestamp.newInstance(0L, 1234).inTz('UTC');
        Assert.areEqual(1234, zdt.subsecNanosecond());
        Assert.areEqual(1234, zdt.toTimestamp().subsecNanosecond());
        // 1,234 nanoseconds before the Unix epoch.
        zdt = JiffTimestamp.newInstance(0L, -1234).inTz('UTC');
        Assert.areEqual(-1234, zdt.toTimestamp().subsecNanosecond());
        Assert.areEqual(999998766, zdt.subsecNanosecond());
        Assert.areEqual(23, zdt.hour());
        Assert.areEqual(59, zdt.minute());
        Assert.areEqual(59, zdt.second());
    }

    @IsTest
    static void knowsItsWeekday() {
        // The Unix epoch was on a Thursday.
        Assert.areEqual(JiffWeekday.THURSDAY, newYork(1970, 1, 1, 7, 30, 0, 0).weekday());
        Assert.areEqual(JiffWeekday.SUNDAY, newYork(2024, 3, 10, 7, 30, 0, 0).weekday());
    }

    @IsTest
    static void countsDaysWithinTheYear() {
        Assert.areEqual(236, newYork(2006, 8, 24, 7, 30, 0, 0).dayOfYear());
        Assert.areEqual(365, newYork(2023, 12, 31, 7, 30, 0, 0).dayOfYear());
        Assert.areEqual(366, newYork(2024, 12, 31, 7, 30, 0, 0).dayOfYear());

        Assert.areEqual(236, newYork(2006, 8, 24, 7, 30, 0, 0).dayOfYearNoLeap());
        Assert.areEqual(365, newYork(2023, 12, 31, 7, 30, 0, 0).dayOfYearNoLeap());
        Assert.areEqual(365, newYork(2024, 12, 31, 7, 30, 0, 0).dayOfYearNoLeap());
        Integer leapDay = newYork(2024, 2, 29, 7, 30, 0, 0).dayOfYearNoLeap();
        Assert.isTrue(leapDay == null, 'February 29th has no position');
    }

    @IsTest
    static void knowsTheLengthOfItsMonthAndYear() {
        Assert.areEqual(29, newYork(2024, 2, 10, 7, 30, 0, 0).daysInMonth());
        Assert.areEqual(28, newYork(2023, 2, 10, 7, 30, 0, 0).daysInMonth());
        Assert.areEqual(31, newYork(2024, 8, 15, 7, 30, 0, 0).daysInMonth());
        // Apia skipped December 30th 2011, but the calendar month still has 31 days.
        Assert.areEqual(31, JiffDate.newInstance(2011, 12, 1).inTz('Pacific/Apia').daysInMonth());

        Assert.areEqual(366, newYork(2024, 7, 10, 7, 30, 0, 0).daysInYear());
        Assert.areEqual(365, newYork(2023, 7, 10, 7, 30, 0, 0).daysInYear());
        Assert.isTrue(newYork(2024, 1, 1, 7, 30, 0, 0).inLeapYear());
        Assert.isFalse(newYork(2023, 12, 31, 7, 30, 0, 0).inLeapYear());
    }

    @IsTest
    static void convertsToAnIsoWeekDate() {
        List<List<Integer>> cases = new List<List<Integer>>{
            // year, month, day, week year, week
            new List<Integer>{ 1995, 1, 1, 1994, 52 },
            new List<Integer>{ 1996, 12, 31, 1997, 1 },
            new List<Integer>{ 2019, 12, 30, 2020, 1 },
            new List<Integer>{ 2024, 3, 9, 2024, 10 }
        };
        List<JiffWeekday> weekdays = new List<JiffWeekday>{
            JiffWeekday.SUNDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.SATURDAY
        };
        for (Integer i = 0; i < cases.size(); i++) {
            List<Integer> row = cases.get(i);
            JiffIsoWeekDate weekDate = newYork(row.get(0), row.get(1), row.get(2), 18, 45, 0, 0)
                .toIsoWeekDate();
            Assert.areEqual(row.get(3), weekDate.year());
            Assert.areEqual(row.get(4), weekDate.week());
            Assert.areEqual(weekdays.get(i), weekDate.weekday());
        }
    }

    // ---- neighbouring datetimes -----------------------------------------

    @IsTest
    static void theStartOfDayIsUsuallyMidnight() {
        Assert.areEqual(
            '2015-10-18T00:00:00-04:00[America/New_York]',
            newYork(2015, 10, 18, 12, 0, 0, 0).startOfDay().toString()
        );
    }

    @IsTest
    static void theStartOfDayIsNotMidnightWhenTheZoneSkipsIt() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2015, 10, 18)
            .at(12, 0, 0, 0)
            .inTz('America/Sao_Paulo');
        Assert.areEqual(
            // not midnight!
            '2015-10-18T01:00:00-02:00[America/Sao_Paulo]',
            zdt.startOfDay().toString()
        );
    }

    @IsTest
    static void theStartOfDayCanBeOutOfRange() {
        // While -9999-01-03T04:00:00+25:59:59 is representable as a zoned datetime, the start
        // of the corresponding day is not!
        JiffTimeZone tz = JiffTimeZone.fixed(JiffOffset.MAX);
        JiffZonedDateTime zdt = JiffDate.newInstance(-9999, 1, 3)
            .at(4, 0, 0, 0)
            .toZonedDateTime(tz);
        try {
            zdt.startOfDay();
            Assert.fail('expected the start of the first day to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('+25:59:59'), e.getMessage());
        }
        // The next day works fine since -9999-01-04T00:00:00+25:59:59 is representable.
        zdt = JiffDate.newInstance(-9999, 1, 4).at(15, 0, 0, 0).toZonedDateTime(tz);
        Assert.areEqual(
            JiffDateTime.newInstance(-9999, 1, 4, 0, 0, 0, 0),
            zdt.startOfDay().toDateTime()
        );
    }

    @IsTest
    static void theEndOfDayIsItsLastNanosecond() {
        JiffZonedDateTime zdt = newYork(2024, 7, 3, 7, 30, 10, 123456789);
        Assert.areEqual(newYork(2024, 7, 3, 23, 59, 59, 999999999), zdt.endOfDay());
        Assert.areEqual(
            '2024-07-03T23:59:59.999999999-04:00[America/New_York]',
            zdt.endOfDay().toString()
        );
    }

    @IsTest
    static void theEndOfDayIsTheLaterInstantWhenItIsRepeated() {
        // Sao Paulo fell back at midnight: 23:00 to 24:00 on February 20th happened twice.
        JiffZonedDateTime zdt = zoned('2016-02-20T12:00:00-02:00[America/Sao_Paulo]');
        Assert.areEqual(
            '2016-02-20T23:59:59.999999999-03:00[America/Sao_Paulo]',
            zdt.endOfDay().toString()
        );
        Assert.areEqual(
            '2016-02-20T00:00:00-02:00[America/Sao_Paulo]',
            zdt.startOfDay().toString()
        );
    }

    @IsTest
    static void theEndOfDayCanBeOutOfRange() {
        // While 9999-12-30T01:30-04 is representable as a zoned datetime, the end of the
        // corresponding day is not!
        JiffTimeZone tz = JiffTimeZone.fixed(JiffOffset.fromHours(-4));
        JiffZonedDateTime zdt = JiffDate.newInstance(9999, 12, 30)
            .at(1, 30, 0, 0)
            .toZonedDateTime(tz);
        try {
            zdt.endOfDay();
            Assert.fail('expected the end of the last day to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('-04'), e.getMessage());
        }
        // The previous day works fine.
        zdt = JiffDate.newInstance(9999, 12, 29).at(1, 30, 0, 0).toZonedDateTime(tz);
        Assert.areEqual('9999-12-29T23:59:59.999999999-04:00[-04:00]', zdt.endOfDay().toString());
    }

    @IsTest
    static void findsTheFirstAndLastOfTheMonthAndYear() {
        Assert.areEqual(
            newYork(2024, 2, 1, 7, 30, 0, 0),
            newYork(2024, 2, 29, 7, 30, 0, 0).firstOfMonth()
        );
        Assert.areEqual(
            newYork(2024, 2, 29, 7, 30, 0, 0),
            newYork(2024, 2, 5, 7, 30, 0, 0).lastOfMonth()
        );
        Assert.areEqual(
            newYork(2024, 1, 1, 7, 30, 0, 0),
            newYork(2024, 2, 29, 7, 30, 0, 0).firstOfYear()
        );
        Assert.areEqual(
            newYork(2024, 12, 31, 7, 30, 0, 0),
            newYork(2024, 2, 5, 7, 30, 0, 0).lastOfYear()
        );
    }

    @IsTest
    static void neighboursAreResolvedInTheZone() {
        // Each row is a zoned datetime followed by what Jiff gives for its start of day, end of
        // day, tomorrow, yesterday, first and last of month, and first and last of year.
        List<List<String>> cases = new List<List<String>>{
            new List<String>{
                '2015-10-18T12:00:00-02:00[America/Sao_Paulo]',
                '2015-10-18T01:00:00-02:00[America/Sao_Paulo]',
                '2015-10-18T23:59:59.999999999-02:00[America/Sao_Paulo]',
                '2015-10-19T12:00:00-02:00[America/Sao_Paulo]',
                '2015-10-17T12:00:00-03:00[America/Sao_Paulo]',
                '2015-10-01T12:00:00-03:00[America/Sao_Paulo]',
                '2015-10-31T12:00:00-02:00[America/Sao_Paulo]',
                '2015-01-01T12:00:00-02:00[America/Sao_Paulo]',
                '2015-12-31T12:00:00-02:00[America/Sao_Paulo]'
            },
            new List<String>{
                '2024-03-10T12:00:00-04:00[America/New_York]',
                '2024-03-10T00:00:00-05:00[America/New_York]',
                '2024-03-10T23:59:59.999999999-04:00[America/New_York]',
                '2024-03-11T12:00:00-04:00[America/New_York]',
                '2024-03-09T12:00:00-05:00[America/New_York]',
                '2024-03-01T12:00:00-05:00[America/New_York]',
                '2024-03-31T12:00:00-04:00[America/New_York]',
                '2024-01-01T12:00:00-05:00[America/New_York]',
                '2024-12-31T12:00:00-05:00[America/New_York]'
            },
            new List<String>{
                '2024-11-03T12:00:00-05:00[America/New_York]',
                '2024-11-03T00:00:00-04:00[America/New_York]',
                '2024-11-03T23:59:59.999999999-05:00[America/New_York]',
                '2024-11-04T12:00:00-05:00[America/New_York]',
                '2024-11-02T12:00:00-04:00[America/New_York]',
                '2024-11-01T12:00:00-04:00[America/New_York]',
                '2024-11-30T12:00:00-05:00[America/New_York]',
                '2024-01-01T12:00:00-05:00[America/New_York]',
                '2024-12-31T12:00:00-05:00[America/New_York]'
            },
            new List<String>{
                '2024-03-31T12:00:00+01:00[Europe/London]',
                '2024-03-31T00:00:00+00:00[Europe/London]',
                '2024-03-31T23:59:59.999999999+01:00[Europe/London]',
                '2024-04-01T12:00:00+01:00[Europe/London]',
                '2024-03-30T12:00:00+00:00[Europe/London]',
                '2024-03-01T12:00:00+00:00[Europe/London]',
                '2024-03-31T12:00:00+01:00[Europe/London]',
                '2024-01-01T12:00:00+00:00[Europe/London]',
                '2024-12-31T12:00:00+00:00[Europe/London]'
            },
            new List<String>{
                '2024-10-27T12:00:00+00:00[Europe/London]',
                '2024-10-27T00:00:00+01:00[Europe/London]',
                '2024-10-27T23:59:59.999999999+00:00[Europe/London]',
                '2024-10-28T12:00:00+00:00[Europe/London]',
                '2024-10-26T12:00:00+01:00[Europe/London]',
                '2024-10-01T12:00:00+01:00[Europe/London]',
                '2024-10-31T12:00:00+00:00[Europe/London]',
                '2024-01-01T12:00:00+00:00[Europe/London]',
                '2024-12-31T12:00:00+00:00[Europe/London]'
            },
            new List<String>{
                '2024-10-06T12:00:00+11:00[Australia/Sydney]',
                '2024-10-06T00:00:00+10:00[Australia/Sydney]',
                '2024-10-06T23:59:59.999999999+11:00[Australia/Sydney]',
                '2024-10-07T12:00:00+11:00[Australia/Sydney]',
                '2024-10-05T12:00:00+10:00[Australia/Sydney]',
                '2024-10-01T12:00:00+10:00[Australia/Sydney]',
                '2024-10-31T12:00:00+11:00[Australia/Sydney]',
                '2024-01-01T12:00:00+11:00[Australia/Sydney]',
                '2024-12-31T12:00:00+11:00[Australia/Sydney]'
            },
            new List<String>{
                '2024-04-07T12:00:00+10:00[Australia/Sydney]',
                '2024-04-07T00:00:00+11:00[Australia/Sydney]',
                '2024-04-07T23:59:59.999999999+10:00[Australia/Sydney]',
                '2024-04-08T12:00:00+10:00[Australia/Sydney]',
                '2024-04-06T12:00:00+11:00[Australia/Sydney]',
                '2024-04-01T12:00:00+11:00[Australia/Sydney]',
                '2024-04-30T12:00:00+10:00[Australia/Sydney]',
                '2024-01-01T12:00:00+11:00[Australia/Sydney]',
                '2024-12-31T12:00:00+11:00[Australia/Sydney]'
            },
            new List<String>{
                '2024-04-07T12:00:00+05:30[Asia/Kolkata]',
                '2024-04-07T00:00:00+05:30[Asia/Kolkata]',
                '2024-04-07T23:59:59.999999999+05:30[Asia/Kolkata]',
                '2024-04-08T12:00:00+05:30[Asia/Kolkata]',
                '2024-04-06T12:00:00+05:30[Asia/Kolkata]',
                '2024-04-01T12:00:00+05:30[Asia/Kolkata]',
                '2024-04-30T12:00:00+05:30[Asia/Kolkata]',
                '2024-01-01T12:00:00+05:30[Asia/Kolkata]',
                '2024-12-31T12:00:00+05:30[Asia/Kolkata]'
            },
            // Apia skipped December 30th 2011 altogether.
            new List<String>{
                '2011-12-29T12:00:00-10:00[Pacific/Apia]',
                '2011-12-29T00:00:00-10:00[Pacific/Apia]',
                '2011-12-29T23:59:59.999999999-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-12-28T12:00:00-10:00[Pacific/Apia]',
                '2011-12-01T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-01-01T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]'
            },
            new List<String>{
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                '2011-12-31T23:59:59.999999999+14:00[Pacific/Apia]',
                '2012-01-01T12:00:00+14:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-12-01T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-01-01T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]'
            }
        };
        for (List<String> row : cases) {
            JiffZonedDateTime zdt = zoned(row.get(0));
            String label = ' of ' + row.get(0);
            Assert.areEqual(row.get(1), zdt.startOfDay().toString(), 'start of day' + label);
            Assert.areEqual(row.get(2), zdt.endOfDay().toString(), 'end of day' + label);
            Assert.areEqual(row.get(3), zdt.tomorrow().toString(), 'tomorrow' + label);
            Assert.areEqual(row.get(4), zdt.yesterday().toString(), 'yesterday' + label);
            Assert.areEqual(row.get(5), zdt.firstOfMonth().toString(), 'first of month' + label);
            Assert.areEqual(row.get(6), zdt.lastOfMonth().toString(), 'last of month' + label);
            Assert.areEqual(row.get(7), zdt.firstOfYear().toString(), 'first of year' + label);
            Assert.areEqual(row.get(8), zdt.lastOfYear().toString(), 'last of year' + label);
        }
    }

    @IsTest
    static void tomorrowIsTheSameTimeOnTheNextDay() {
        Assert.areEqual(
            newYork(2024, 2, 29, 7, 30, 0, 0),
            newYork(2024, 2, 28, 7, 30, 0, 0).tomorrow()
        );
        // Ambiguous datetimes are automatically resolved.
        Assert.areEqual(
            newYork(2024, 3, 10, 3, 30, 0, 0),
            newYork(2024, 3, 9, 2, 30, 0, 0).tomorrow()
        );
    }

    @IsTest
    static void yesterdayIsTheSameTimeOnThePreviousDay() {
        Assert.areEqual(
            newYork(2024, 2, 29, 7, 30, 0, 0),
            newYork(2024, 3, 1, 7, 30, 0, 0).yesterday()
        );
        Assert.areEqual(
            // Consistent with the "compatible" disambiguation strategy, the "first" 1 o'clock
            // hour is selected. The second 1 o'clock hour would have offset -05.
            '2024-11-03T01:30:00-04:00[America/New_York]',
            newYork(2024, 11, 4, 1, 30, 0, 0).yesterday().toString()
        );
    }

    @IsTest
    static void theLimitsHaveNoTomorrowOrYesterday() {
        JiffZonedDateTime max = JiffTimestamp.MAX.inTz('UTC');
        Assert.areEqual('9999-12-30T22:00:00.999999999+00:00[UTC]', max.toString());
        try {
            max.tomorrow();
            Assert.fail('expected the maximum to have no tomorrow');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('+00'), e.getMessage());
        }
        try {
            max.endOfDay();
            Assert.fail('expected the end of the last day to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('+00'), e.getMessage());
        }
        Assert.areEqual('9999-12-30T00:00:00+00:00[UTC]', max.startOfDay().toString());

        JiffZonedDateTime min = JiffTimestamp.MIN.inTz('UTC');
        Assert.areEqual('-009999-01-02T01:59:59+00:00[UTC]', min.toString());
        try {
            min.yesterday();
            Assert.fail('expected the minimum to have no yesterday');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('+00'), e.getMessage());
        }
        try {
            min.startOfDay();
            Assert.fail('expected the start of the first day to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(overflowAt('+00'), e.getMessage());
        }
        Assert.areEqual('-009999-01-02T23:59:59.999999999+00:00[UTC]', min.endOfDay().toString());
    }

    @IsTest
    static void findsTheNthWeekdayOfTheMonth() {
        // The second Friday of March 2017.
        Assert.areEqual(
            newYork(2017, 3, 10, 7, 30, 0, 0),
            newYork(2017, 3, 1, 7, 30, 0, 0).nthWeekdayOfMonth(2, JiffWeekday.FRIDAY)
        );
        JiffZonedDateTime zdt = newYork(2024, 3, 1, 7, 30, 0, 0);
        Assert.areEqual(
            newYork(2024, 3, 28, 7, 30, 0, 0),
            zdt.nthWeekdayOfMonth(-1, JiffWeekday.THURSDAY)
        );
        Assert.areEqual(
            newYork(2024, 3, 21, 7, 30, 0, 0),
            zdt.nthWeekdayOfMonth(-2, JiffWeekday.THURSDAY)
        );
        zdt = newYork(2024, 3, 25, 7, 30, 0, 0);
        Assert.areEqual(
            newYork(2024, 3, 25, 7, 30, 0, 0),
            zdt.nthWeekdayOfMonth(4, JiffWeekday.MONDAY)
        );
        // There is no 5th Monday. Same goes for counting backwards.
        for (Integer nth : new List<Integer>{ 5, -5 }) {
            try {
                zdt.nthWeekdayOfMonth(nth, JiffWeekday.MONDAY);
                Assert.fail('expected March 2024 to have only four Mondays');
            } catch (JiffException e) {
                Assert.isTrue(e.getMessage().contains('day'), e.getMessage());
            }
        }
    }

    @IsTest
    static void findsTheNthWeekdayFromHere() {
        // Use a Sunday in March as our start date.
        JiffZonedDateTime zdt = newYork(2024, 3, 10, 7, 30, 0, 0);
        Assert.areEqual(JiffWeekday.SUNDAY, zdt.weekday());
        // The first next Monday is tomorrow!
        Assert.areEqual(newYork(2024, 3, 11, 7, 30, 0, 0), zdt.nthWeekday(1, JiffWeekday.MONDAY));
        // But the next Sunday is a week away, because this doesn't include the current weekday.
        Assert.areEqual(newYork(2024, 3, 17, 7, 30, 0, 0), zdt.nthWeekday(1, JiffWeekday.SUNDAY));
        // "not this Thursday, but next Thursday"
        Assert.areEqual(newYork(2024, 3, 21, 7, 30, 0, 0), zdt.nthWeekday(2, JiffWeekday.THURSDAY));
        // "last Saturday" was yesterday!
        Assert.areEqual(newYork(2024, 3, 9, 7, 30, 0, 0), zdt.nthWeekday(-1, JiffWeekday.SATURDAY));
        // "last Sunday" was a week ago.
        Assert.areEqual(newYork(2024, 3, 3, 7, 30, 0, 0), zdt.nthWeekday(-1, JiffWeekday.SUNDAY));
        // "not last Thursday, but the one before"
        Assert.areEqual(
            newYork(2024, 2, 29, 7, 30, 0, 0),
            zdt.nthWeekday(-2, JiffWeekday.THURSDAY)
        );
    }

    @IsTest
    static void weekdaySearchesAreResolvedInTheZone() {
        // 02:30 does not exist on Sunday 2024-03-10 in New York, and 01:30 happens twice on
        // Sunday 2024-11-03.
        JiffZonedDateTime march = newYork(2024, 3, 20, 2, 30, 0, 0);
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            march.nthWeekdayOfMonth(2, JiffWeekday.SUNDAY).toString()
        );
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            march.nthWeekday(-2, JiffWeekday.SUNDAY).toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            newYork(2024, 11, 20, 1, 30, 0, 0).nthWeekdayOfMonth(1, JiffWeekday.SUNDAY).toString()
        );
    }

    @IsTest
    static void weekdaySearchesStopAtTheLimits() {
        JiffZonedDateTime max = JiffTimestamp.MAX.inTz('UTC');
        Assert.areEqual(JiffWeekday.THURSDAY, max.weekday());
        try {
            max.nthWeekday(1, JiffWeekday.SATURDAY);
            Assert.fail('expected the Saturday after the maximum to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'Unix epoch days\' is not in the required range of ' +
                '-4371587..=2932896',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void findsTheStartOfTheWeek() {
        JiffZonedDateTime zdt = newYork(2024, 3, 15, 7, 30, 0, 0);
        // For weeks starting with Sunday.
        Assert.areEqual(
            newYork(2024, 3, 10, 7, 30, 0, 0),
            zdt.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY)
        );
        // For weeks starting with Monday.
        Assert.areEqual(
            newYork(2024, 3, 11, 7, 30, 0, 0),
            zdt.tomorrow().nthWeekday(-1, JiffWeekday.MONDAY)
        );
        // The start of the week is its own start, and so is its end.
        zdt = newYork(2024, 3, 10, 0, 0, 0, 0);
        Assert.areEqual(
            newYork(2024, 3, 10, 0, 0, 0, 0),
            zdt.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY)
        );
        zdt = newYork(2024, 3, 16, 23, 59, 59, 999999999);
        Assert.areEqual(
            newYork(2024, 3, 10, 0, 0, 0, 0),
            zdt.tomorrow()
                .nthWeekday(-1, JiffWeekday.SUNDAY)
                .with()
                .withTime(JiffTime.midnight())
                .build()
        );
    }

    // ---- comparison -----------------------------------------------------

    @IsTest
    static void ordersByInstant() {
        JiffZonedDateTime zdt1 = newYork(2024, 3, 11, 1, 25, 15, 0);
        JiffZonedDateTime zdt2 = newYork(2025, 1, 31, 0, 30, 0, 0);
        Assert.isTrue(zdt1.compareTo(zdt2) < 0);
        Assert.isTrue(zdt2.compareTo(zdt1) > 0);
        Assert.areEqual(0, zdt1.compareTo(newYork(2024, 3, 11, 1, 25, 15, 0)));
        Assert.isTrue(zdt1.isBefore(zdt2));
        Assert.isFalse(zdt1.isAfter(zdt2));
        Assert.isTrue(zdt2.isAfter(zdt1));
        Assert.isFalse(zdt2.isBefore(zdt1));
        Assert.isFalse(zdt1.isBefore(zdt1));
        Assert.isFalse(zdt1.isAfter(zdt1));
    }

    @IsTest
    static void comparisonIgnoresTheCivilDatetime() {
        JiffZonedDateTime zdt1 = newYork(2024, 7, 4, 12, 0, 0, 0);
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 7, 4)
            .at(11, 0, 0, 0)
            .inTz('America/Los_Angeles');
        Assert.isTrue(zdt1.isBefore(zdt2));
        // But if we only compare civil datetime, the result is flipped.
        Assert.isTrue(zdt1.toDateTime().isAfter(zdt2.toDateTime()));
    }

    @IsTest
    static void sortsChronologically() {
        JiffZonedDateTime first = zoned('2024-07-04T12:00:00-04:00[America/New_York]');
        JiffZonedDateTime second = zoned('2024-07-04T11:00:00-07:00[America/Los_Angeles]');
        JiffZonedDateTime third = zoned('2024-07-05T00:00:00+05:30[Asia/Kolkata]');
        List<JiffZonedDateTime> all = new List<JiffZonedDateTime>{ third, first, second };
        all.sort();
        Assert.areEqual(new List<JiffZonedDateTime>{ first, second, third }, all);
    }

    @IsTest
    static void equalityIsOfTheInstantOnly() {
        JiffZonedDateTime zdt1 = newYork(2024, 7, 4, 12, 0, 0, 0);
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 7, 4)
            .at(9, 0, 0, 0)
            .inTz('America/Los_Angeles');
        Assert.isTrue(zdt1.equals(zdt2));
        Assert.areEqual(zdt1.hashCode(), zdt2.hashCode());
        Assert.isFalse(zdt1.timeZone().equals(zdt2.timeZone()));

        Assert.isFalse(zdt1.equals(newYork(2024, 7, 4, 12, 0, 0, 1)));
        Assert.isFalse(zdt1.equals(zdt1.toTimestamp()));
        Assert.isFalse(zdt1.equals(null));

        Set<JiffZonedDateTime> unique = new Set<JiffZonedDateTime>{ zdt1, zdt2 };
        Assert.areEqual(1, unique.size());
    }

    // ---- text -----------------------------------------------------------

    @IsTest
    static void printsAsRfc9557() {
        // No fractional seconds:
        Assert.areEqual(
            '2024-06-15T07:00:00-04:00[America/New_York]',
            newYork(2024, 6, 15, 7, 0, 0, 0).toString()
        );
        // With fractional seconds:
        Assert.areEqual(
            '2024-06-15T07:00:00.123-04:00[America/New_York]',
            newYork(2024, 6, 15, 7, 0, 0, 123000000).toString()
        );
        Assert.areEqual(
            '2024-07-04T07:39:00.123456789-04:00[America/New_York]',
            JiffTimestamp.newInstance(1720093140L, 123456789).inTz(NEW_YORK).toString()
        );
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            newYork(2024, 3, 10, 3, 30, 0, 0).toString()
        );
    }

    @IsTest
    static void printsUtcFixedAndUnknownZones() {
        JiffTimestamp ts = JiffTimestamp.fromSecond(1720093140L);
        Assert.areEqual(
            '2024-07-04T11:39:00.123+00:00[UTC]',
            JiffTimestamp.newInstance(1720093140L, 123000000)
                .toZonedDateTime(JiffTimeZone.UTC)
                .toString()
        );
        // A fixed offset zone has no name, so the offset is written twice.
        Assert.areEqual(
            '2024-07-04T06:39:00-05:00[-05:00]',
            ts.toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(-5))).toString()
        );
        Assert.areEqual(
            '2024-07-04T17:09:00+05:30[+05:30]',
            ts.toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromSeconds(19800))).toString()
        );
        // RFC 9557 offsets have no seconds: -05:30:31 is rounded to the minute, both times.
        Assert.areEqual(
            '2024-07-04T06:08:29-05:31[-05:31]',
            ts.toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromSeconds(-19831))).toString()
        );
        Assert.areEqual(
            '2024-07-04T11:39:00Z[Etc/Unknown]',
            ts.toZonedDateTime(JiffTimeZone.unknown()).toString()
        );
    }

    @IsTest
    static void printsYearsBeforeZeroWithSixDigits() {
        JiffZonedDateTime zdt = JiffDate.newInstance(-1, 1, 1)
            .at(0, 0, 0, 0)
            .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(2)));
        Assert.areEqual('-000001-01-01T00:00:00+02:00[+02:00]', zdt.toString());
    }

    @IsTest
    static void printsAnOffsetWithSecondsRoundedToTheMinute() {
        // Monrovia was 44 minutes and 30 seconds behind UTC until 1972.
        JiffZonedDateTime zdt = JiffDate.newInstance(1970, 6, 1).inTz('Africa/Monrovia');
        Assert.areEqual(JiffOffset.fromSeconds(-2670), zdt.offset());
        Assert.areEqual('1970-06-01T00:00:00-00:45[Africa/Monrovia]', zdt.toString());
    }

    // ---- platform interop -----------------------------------------------

    @IsTest
    static void convertsAPlatformDatetimeInAGivenZone() {
        Datetime value = Datetime.newInstanceGmt(2024, 7, 4, 11, 39, 0);
        JiffZonedDateTime zdt = JiffZonedDateTime.fromSystemDatetime(
            value,
            JiffTimeZone.get(NEW_YORK)
        );
        Assert.areEqual('2024-07-04T07:39:00-04:00[America/New_York]', zdt.toString());
        Assert.areEqual(1720093140L, zdt.toTimestamp().asSecond());
        Assert.areEqual(
            '2024-07-04T17:09:00+05:30[Asia/Kolkata]',
            JiffZonedDateTime.fromSystemDatetime(value, JiffTimeZone.get('Asia/Kolkata')).toString()
        );
    }

    @IsTest
    static void convertsAPlatformDatetimeInTheUsersZone() {
        Datetime value = Datetime.newInstanceGmt(2024, 7, 4, 11, 39, 0);
        JiffZonedDateTime zdt = JiffZonedDateTime.fromSystemDatetime(value);
        Assert.areEqual(1720093140L, zdt.toTimestamp().asSecond());
        Assert.areEqual(JiffTimeZone.userTimeZone(), zdt.timeZone());
        // The civil fields are the ones the platform shows that user.
        Assert.areEqual(Integer.valueOf(value.format('H', zdt.timeZone().ianaName())), zdt.hour());
        Assert.areEqual(39, zdt.minute());
    }

    @IsTest
    static void aNullPlatformDatetimeGivesNull() {
        Datetime nothing = null;
        Assert.isNull(JiffZonedDateTime.fromSystemDatetime(nothing));
        Assert.isNull(JiffZonedDateTime.fromSystemDatetime(nothing, JiffTimeZone.UTC));
    }

    @IsTest
    static void convertingAPlatformDatetimeNeedsAZone() {
        try {
            JiffZonedDateTime.fromSystemDatetime(Datetime.newInstance(0L), null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a zoned datetime needs both a timestamp and a time zone',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void convertsToAPlatformDatetime() {
        JiffZonedDateTime zdt = newYork(2024, 7, 4, 7, 39, 0, 0);
        Assert.areEqual(Datetime.newInstanceGmt(2024, 7, 4, 11, 39, 0), zdt.toSystemDatetime());
        Assert.areEqual(zdt, JiffZonedDateTime.fromSystemDatetime(zdt.toSystemDatetime()));
    }

    @IsTest
    static void aPlatformDatetimeKeepsOnlyMilliseconds() {
        // Anything below a millisecond is dropped, truncating toward the epoch.
        JiffZonedDateTime zdt = JiffTimestamp.newInstance(1720093140L, 123999999).inTz(NEW_YORK);
        Assert.areEqual(1720093140123L, zdt.toSystemDatetime().getTime());
        zdt = JiffTimestamp.newInstance(-1L, -123999999).inTz(NEW_YORK);
        Assert.areEqual(-1123L, zdt.toSystemDatetime().getTime());
    }
}
