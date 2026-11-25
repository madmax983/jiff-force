/**
 * Arithmetic on `JiffZonedDateTime`: adding and subtracting spans and durations, and the
 * differences `until`, `since`, `durationUntil` and `durationSince`.
 *
 * Expected values are from the examples in Jiff's documentation of `ZonedDateTime`, from the
 * tests in `jiff/src/zoned.rs`, or were printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffZonedDateTimeArithmeticTest {
    private static final String NEW_YORK = 'America/New_York';
    private static final String TIMESTAMP_RANGE =
        'parameter \'Unix timestamp seconds\' is not in the required range of ' +
        '-377705023201..=253402207200';
    private static final String YEAR_RANGE =
        'failed to add span to datetime from zoned datetime: failed to add span to date: ' +
        'parameter \'year\' is not in the required range of -9999..=9999';
    private static final List<JiffUnit> CALENDAR_UNITS = new List<JiffUnit>{
        JiffUnit.YEAR,
        JiffUnit.MONTH,
        JiffUnit.WEEK,
        JiffUnit.DAY
    };
    private static final String MAX_UTC = '9999-12-30T22:00:00.999999999+00:00[UTC]';
    private static final String MIN_UTC = '-009999-01-02T01:59:59+00:00[UTC]';

    private static JiffZonedDateTime zoned(String text) {
        return JiffZonedTestSupport.zoned(text);
    }

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

    private static JiffSpan span(String text) {
        return JiffSpan.parse(text);
    }

    // ---- adding spans ---------------------------------------------------

    @IsTest
    static void addsCalendarAndClockUnits() {
        JiffZonedDateTime zdt = newYork(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(
            newYork(2016, 4, 7, 3, 24, 30, 4000),
            zdt.add(new JiffSpan().years(20).months(4).nanoseconds(500))
        );
        Assert.areEqual(
            '2016-04-07T03:24:30.000004-04:00[America/New_York]',
            zdt.add(new JiffSpan().years(20).months(4).nanoseconds(500)).toString()
        );
    }

    @IsTest
    static void addingAMonthClampsToTheLastDay() {
        Assert.areEqual(
            newYork(2019, 2, 28, 15, 30, 0, 0),
            newYork(2019, 1, 31, 15, 30, 0, 0).add(new JiffSpan().months(1))
        );
    }

    @IsTest
    static void aDayIsNotAlwaysTwentyFourHours() {
        // New York springs forward on 2024-03-10.
        JiffZonedDateTime zdt = newYork(2024, 3, 10, 0, 0, 0, 0);
        Assert.areEqual(
            '2024-03-11T00:00:00-04:00[America/New_York]',
            zdt.add(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2024-03-11T01:00:00-04:00[America/New_York]',
            zdt.add(new JiffSpan().hours(24)).toString()
        );
    }

    @IsTest
    static void addingADayIntoAGapMovesForward() {
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            newYork(2024, 3, 9, 2, 30, 0, 0).add(new JiffSpan().days(1)).toString()
        );
    }

    @IsTest
    static void addingADayIntoAFoldPicksTheEarlierTime() {
        Assert.areEqual(
            // This corresponds to the first iteration of the 1 o'clock hour, i.e., when DST is
            // still in effect. It's the earlier time.
            '2024-11-03T01:30:00-04:00[America/New_York]',
            newYork(2024, 11, 2, 1, 30, 0, 0).add(new JiffSpan().days(1)).toString()
        );
    }

    @IsTest
    static void addsNegativeSpans() {
        Assert.areEqual(
            newYork(2024, 2, 29, 19, 5, 59, 999999999),
            newYork(2024, 3, 31, 19, 5, 59, 999999999).add(new JiffSpan().months(-1))
        );
    }

    @IsTest
    static void clockUnitsAreAddedAfterTheCivilDatetimeIsResolved() {
        // From `zoned_add_calendar_units_dst` in Jiff's tests.
        JiffZonedDateTime zdt = newYork(2024, 1, 31, 2, 30, 0, 0);
        Assert.areEqual(
            '2024-02-29T02:30:00-05:00[America/New_York]',
            zdt.add(new JiffSpan().months(1)).toString()
        );
        // Lands in a gap, so it's moved forward by the length of the gap.
        zdt = newYork(2024, 3, 9, 2, 30, 0, 0);
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            zdt.add(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2024-03-10T03:31:00-04:00[America/New_York]',
            zdt.add(new JiffSpan().days(1).minutes(1)).toString()
        );
        // Lands in a fold, so the earlier offset is picked.
        zdt = newYork(2024, 11, 2, 1, 30, 0, 0);
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            zdt.add(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-05:00[America/New_York]',
            zdt.add(new JiffSpan().days(1).hours(1)).toString()
        );
    }

    @IsTest
    static void addingClockUnitsKeepsFullPrecision() {
        // From `zoned_precision_loss` in Jiff's tests.
        JiffZonedDateTime zdt1 = zoned('2025-01-25T19:32:21.783444592+01:00[Europe/Paris]');
        JiffSpan oneSecond = new JiffSpan().seconds(1);
        JiffZonedDateTime zdt2 = zdt1.add(oneSecond);
        Assert.areEqual('2025-01-25T19:32:22.783444592+01:00[Europe/Paris]', zdt2.toString());
        Assert.areEqual(zdt1, zdt2.subtract(oneSecond), 'should be reversible');
    }

    @IsTest
    static void addsSpansAcrossTransitionsInManyZones() {
        // Each row is: start | span | what Jiff gives for start + span.
        List<String> cases = new List<String>{
            '2024-03-30T01:30:00+00:00[Europe/London] | P1D | 2024-03-31T02:30:00+01:00[Europe/London]',
            '2024-03-30T01:30:00+00:00[Europe/London] | PT24H | 2024-03-31T02:30:00+01:00[Europe/London]',
            '2024-03-30T01:30:00+00:00[Europe/London] | P1DT1H | 2024-03-31T03:30:00+01:00[Europe/London]',
            '2024-10-26T01:30:00+01:00[Europe/London] | P1D | 2024-10-27T01:30:00+01:00[Europe/London]',
            '2024-10-26T01:30:00+01:00[Europe/London] | PT24H | 2024-10-27T01:30:00+01:00[Europe/London]',
            '2024-10-26T01:30:00+01:00[Europe/London] | PT25H | 2024-10-27T01:30:00+00:00[Europe/London]',
            '2024-10-05T02:30:00+10:00[Australia/Sydney] | P1D | 2024-10-06T03:30:00+11:00[Australia/Sydney]',
            '2024-10-05T02:30:00+10:00[Australia/Sydney] | PT24H | 2024-10-06T03:30:00+11:00[Australia/Sydney]',
            '2024-04-06T02:30:00+11:00[Australia/Sydney] | P1D | 2024-04-07T02:30:00+11:00[Australia/Sydney]',
            '2024-04-06T02:30:00+11:00[Australia/Sydney] | PT24H | 2024-04-07T02:30:00+11:00[Australia/Sydney]',
            '2024-01-31T12:00:00+05:30[Asia/Kolkata] | P1M | 2024-02-29T12:00:00+05:30[Asia/Kolkata]',
            '2024-01-31T12:00:00+05:30[Asia/Kolkata] | P1MT13H45M | 2024-03-01T01:45:00+05:30[Asia/Kolkata]',
            '2015-10-17T00:30:00-03:00[America/Sao_Paulo] | P1D | 2015-10-18T01:30:00-02:00[America/Sao_Paulo]',
            '2015-10-17T00:30:00-03:00[America/Sao_Paulo] | P1W | 2015-10-24T00:30:00-02:00[America/Sao_Paulo]',
            '2024-03-10T01:30:00-05:00[America/New_York] | PT1H | 2024-03-10T03:30:00-04:00[America/New_York]',
            '2024-11-03T01:30:00-04:00[America/New_York] | PT1H | 2024-11-03T01:30:00-05:00[America/New_York]',
            '2024-11-03T01:30:00-05:00[America/New_York] | -PT1H | 2024-11-03T01:30:00-04:00[America/New_York]',
            '2024-03-10T03:30:00-04:00[America/New_York] | -PT1H | 2024-03-10T01:30:00-05:00[America/New_York]',
            '2024-03-11T02:30:00-04:00[America/New_York] | -P1D | 2024-03-10T03:30:00-04:00[America/New_York]',
            '2024-11-04T01:30:00-05:00[America/New_York] | -P1D | 2024-11-03T01:30:00-04:00[America/New_York]',
            '2024-11-04T01:30:00-05:00[America/New_York] | P1DT30M | 2024-11-05T02:00:00-05:00[America/New_York]',
            '2024-02-29T12:00:00-05:00[America/New_York] | P1Y | 2025-02-28T12:00:00-05:00[America/New_York]',
            '2024-02-29T12:00:00-05:00[America/New_York] | P4Y1M1DT0.000000001S | 2028-03-30T12:00:00.000000001-04:00[America/New_York]',
            '2011-12-29T12:00:00-10:00[Pacific/Apia] | P1D | 2011-12-31T12:00:00+14:00[Pacific/Apia]',
            '2011-12-29T12:00:00-10:00[Pacific/Apia] | PT24H | 2011-12-31T12:00:00+14:00[Pacific/Apia]',
            '2011-12-31T12:00:00+14:00[Pacific/Apia] | -P1D | 2011-12-31T12:00:00+14:00[Pacific/Apia]',
            '2024-07-04T12:00:00+00:00[UTC] | P1M1DT1H | 2024-08-05T13:00:00+00:00[UTC]',
            '2024-07-04T12:00:00-05:30[-05:30] | P1M1DT1H | 2024-08-05T13:00:00-05:30[-05:30]',
            '2024-07-04T12:00:00.123456789+01:00[Europe/London] | -P2WT0.877001S | 2024-06-20T11:59:59.246455789+01:00[Europe/London]'
        };
        for (String row : cases) {
            List<String> f = row.split(' \\| ');
            JiffZonedDateTime start = zoned(f.get(0));
            JiffSpan toAdd = span(f.get(1));
            Assert.areEqual(f.get(2), start.add(toAdd).toString(), row);
            Assert.areEqual(f.get(2), start.subtract(toAdd.negate()).toString(), row);
            Assert.areEqual(f.get(2), start.saturatingAdd(toAdd).toString(), row);
            Assert.areEqual(f.get(2), start.saturatingSubtract(toAdd.negate()).toString(), row);
        }
    }

    @IsTest
    static void addingNothingChangesNothing() {
        JiffZonedDateTime zdt = zoned('2024-11-03T01:30:00-05:00[America/New_York]');
        Assert.areEqual(zdt.toString(), zdt.add(new JiffSpan()).toString());
        Assert.areEqual(zdt.toString(), zdt.subtract(new JiffSpan()).toString());
        Assert.areEqual(zdt.toString(), zdt.add(JiffSignedDuration.ZERO).toString());
    }

    @IsTest
    static void addingCalendarUnitsFailsOutsideTheSupportedYears() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        List<JiffSpan> tooFar = new List<JiffSpan>{
            new JiffSpan().years(9000),
            new JiffSpan().years(-19000),
            new JiffSpan().years(9000).hours(1)
        };
        for (JiffSpan toAdd : tooFar) {
            try {
                zdt.add(toAdd);
                Assert.fail('expected ' + toAdd + ' to overflow');
            } catch (JiffException e) {
                Assert.areEqual(YEAR_RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void addingClockUnitsFailsOutsideTheSupportedInstants() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        List<JiffSpan> tooFar = new List<JiffSpan>{
            new JiffSpan().seconds(631107417600L),
            new JiffSpan().seconds(-631107417600L),
            new JiffSpan().hours(175307616L).nanoseconds(1)
        };
        for (JiffSpan toAdd : tooFar) {
            try {
                zdt.add(toAdd);
                Assert.fail('expected ' + toAdd + ' to overflow');
            } catch (JiffException e) {
                Assert.areEqual(
                    'failed to add span to timestamp from zoned datetime: ' + TIMESTAMP_RANGE,
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void eachStepOfAnAdditionReportsItsOwnFailure() {
        JiffZonedDateTime near = JiffDate.newInstance(9999, 12, 29).at(22, 0, 0, 0).inTz('UTC');
        Assert.areEqual(
            '9999-12-30T22:00:00+00:00[UTC]',
            near.add(new JiffSpan().days(1)).toString()
        );
        String conversion =
            'failed to convert civil datetime to timestamp: converting datetime with time zone ' +
            'offset `+00` to timestamp overflowed: ' +
            TIMESTAMP_RANGE;
        Map<String, String> expected = new Map<String, String>{
            // The civil datetime exists but has no instant.
            'P2D' => conversion,
            'P2DT1H' => conversion,
            // The civil datetime resolves, and the hours then run past the end.
            'P1DT1H' => 'failed to add span to timestamp from zoned datetime: ' +
            'adding span overflowed timestamp: ' +
            TIMESTAMP_RANGE,
            'P1DT1.000000001S' => 'failed to add span to timestamp from zoned datetime: ' +
            TIMESTAMP_RANGE
        };
        for (String text : expected.keySet()) {
            try {
                near.add(span(text));
                Assert.fail('expected adding ' + text + ' to overflow');
            } catch (JiffException e) {
                Assert.areEqual(expected.get(text), e.getMessage(), text);
            }
        }
    }

    // ---- subtracting ----------------------------------------------------

    @IsTest
    static void subtractsSpansAndDurations() {
        JiffZonedDateTime zdt = newYork(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(
            newYork(1975, 8, 7, 3, 24, 30, 3000),
            zdt.subtract(new JiffSpan().years(20).months(4).nanoseconds(500))
        );
        Assert.areEqual(
            '1975-08-07T03:24:30.000003-04:00[America/New_York]',
            zdt.subtract(new JiffSpan().years(20).months(4).nanoseconds(500)).toString()
        );
        JiffSignedDuration oneDay = JiffSignedDuration.newInstance(24 * 60 * 60L, 500);
        Assert.areEqual(newYork(1995, 12, 6, 3, 24, 30, 3000), zdt.subtract(oneDay));
    }

    // ---- adding durations -----------------------------------------------

    @IsTest
    static void addsExactDurations() {
        JiffZonedDateTime zdt = newYork(2024, 2, 29, 0, 0, 0, 0);
        JiffSignedDuration dur = JiffSignedDuration.fromHours(25);
        Assert.areEqual(newYork(2024, 3, 1, 1, 0, 0, 0), zdt.add(dur));
        Assert.areEqual(newYork(2024, 2, 27, 23, 0, 0, 0), zdt.add(dur.negate()));
        Assert.areEqual(newYork(2024, 2, 27, 23, 0, 0, 0), zdt.subtract(dur));
    }

    @IsTest
    static void aDurationIsElapsedTimeNotClockTime() {
        JiffZonedDateTime zdt = zoned('2024-03-09T12:00:00-05:00[America/New_York]');
        Assert.areEqual(
            '2024-03-10T13:00:00-04:00[America/New_York]',
            zdt.add(JiffSignedDuration.fromHours(24)).toString()
        );
    }

    @IsTest
    static void addingADurationFailsOutsideTheSupportedInstants() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        try {
            zdt.add(JiffSignedDuration.MAX);
            Assert.fail('expected the largest duration to overflow');
        } catch (JiffException e) {
            Assert.areEqual('adding duration overflowed timestamp', e.getMessage());
        }
        try {
            zdt.add(JiffSignedDuration.MIN);
            Assert.fail('expected the smallest duration to overflow');
        } catch (JiffException e) {
            Assert.areEqual(TIMESTAMP_RANGE, e.getMessage());
        }
        try {
            zdt.subtract(JiffSignedDuration.MAX);
            Assert.fail('expected subtracting the largest duration to overflow');
        } catch (JiffException e) {
            Assert.areEqual(TIMESTAMP_RANGE, e.getMessage());
        }
        try {
            zdt.subtract(JiffSignedDuration.MIN);
            Assert.fail('expected the smallest duration to have no negation');
        } catch (JiffException e) {
            Assert.areEqual(
                'unsigned duration exceeds Jiff\'s limits: parameter \'signed duration ' +
                    'seconds\' is not in the required range of ' +
                    '-9223372036854775808..=9223372036854775807',
                e.getMessage()
            );
        }
    }

    // ---- saturating arithmetic ------------------------------------------

    @IsTest
    static void saturatingAddStopsAtTheLimits() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(
            JiffTimestamp.MAX,
            zdt.saturatingAdd(new JiffSpan().years(9000)).toTimestamp()
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            zdt.saturatingAdd(new JiffSpan().years(-19000)).toTimestamp()
        );
        Assert.areEqual(JiffTimestamp.MAX, zdt.saturatingAdd(JiffSignedDuration.MAX).toTimestamp());
        Assert.areEqual(JiffTimestamp.MIN, zdt.saturatingAdd(JiffSignedDuration.MIN).toTimestamp());
        // The result stays in the same time zone.
        Assert.areEqual(
            JiffTimeZone.get(NEW_YORK),
            zdt.saturatingAdd(new JiffSpan().years(9000)).timeZone()
        );
    }

    @IsTest
    static void saturatingSubtractStopsAtTheLimits() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(
            JiffTimestamp.MIN,
            zdt.saturatingSubtract(new JiffSpan().years(19000)).toTimestamp()
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            zdt.saturatingSubtract(new JiffSpan().years(-9000)).toTimestamp()
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            zdt.saturatingSubtract(JiffSignedDuration.MAX).toTimestamp()
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            zdt.saturatingSubtract(JiffSignedDuration.MIN).toTimestamp()
        );
    }

    @IsTest
    static void saturatedResultsReadInTheSameZone() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2024, 3, 31).at(13, 13, 13, 13).inTz('UTC');
        Assert.areEqual(MAX_UTC, zdt.saturatingAdd(new JiffSpan().years(9000)).toString());
        Assert.areEqual(MIN_UTC, zdt.saturatingAdd(new JiffSpan().years(-19000)).toString());
        Assert.areEqual(MIN_UTC, zdt.saturatingSubtract(new JiffSpan().years(19000)).toString());
        Assert.areEqual(MAX_UTC, zdt.saturatingSubtract(new JiffSpan().years(-9000)).toString());
        Assert.areEqual(MAX_UTC, zdt.saturatingAdd(JiffSignedDuration.MAX).toString());
        Assert.areEqual(MIN_UTC, zdt.saturatingAdd(JiffSignedDuration.MIN).toString());
        Assert.areEqual(MIN_UTC, zdt.saturatingSubtract(JiffSignedDuration.MAX).toString());
        Assert.areEqual(MAX_UTC, zdt.saturatingSubtract(JiffSignedDuration.MIN).toString());
    }

    @IsTest
    static void saturatingArithmeticIsOrdinaryArithmeticWithinRange() {
        JiffZonedDateTime zdt = newYork(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(
            '2024-04-01T13:13:13.000000013-04:00[America/New_York]',
            zdt.saturatingAdd(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2024-03-30T13:13:13.000000013-04:00[America/New_York]',
            zdt.saturatingSubtract(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2024-03-31T14:13:13.000000013-04:00[America/New_York]',
            zdt.saturatingAdd(JiffSignedDuration.fromHours(1)).toString()
        );
        Assert.areEqual(
            '2024-03-31T12:13:13.000000013-04:00[America/New_York]',
            zdt.saturatingSubtract(JiffSignedDuration.fromHours(1)).toString()
        );
    }

    // ---- until and since ------------------------------------------------

    @IsTest
    static void untilUsesHoursByDefault() {
        JiffZonedDateTime earlier = newYork(2006, 8, 24, 22, 30, 0, 0);
        JiffZonedDateTime later = newYork(2019, 1, 31, 21, 0, 0, 0);
        Assert.areEqual(new JiffSpan().hours(109031).minutes(30), earlier.until(later));
        // Flipping the dates is fine, but you'll get a negative span.
        Assert.areEqual(new JiffSpan().hours(-109031).minutes(-30), later.until(earlier));
        Assert.areEqual(new JiffSpan().hours(109031).minutes(30), later.since(earlier));
        Assert.areEqual(new JiffSpan().hours(-109031).minutes(-30), earlier.since(later));
        // A null largest unit means the default.
        Assert.areEqual(
            new JiffSpan().hours(109031).minutes(30),
            earlier.until(later, (JiffUnit) null)
        );
        Assert.areEqual(
            new JiffSpan().hours(109031).minutes(30),
            later.since(earlier, (JiffUnit) null)
        );
    }

    @IsTest
    static void untilCanUseBiggerUnits() {
        JiffZonedDateTime zdt1 = newYork(1995, 12, 7, 3, 24, 30, 3500);
        JiffZonedDateTime zdt2 = newYork(2019, 1, 31, 15, 30, 0, 0);
        // The default limits durations to using "hours" as the biggest unit.
        Assert.areEqual('PT202956H5M29.9999965S', zdt1.until(zdt2).toString());
        // But we can ask for units all the way up to years.
        Assert.areEqual(
            new JiffSpan()
                .years(23)
                .months(1)
                .days(24)
                .hours(12)
                .minutes(5)
                .seconds(29)
                .milliseconds(999)
                .microseconds(996)
                .nanoseconds(500),
            zdt1.until(zdt2, JiffUnit.YEAR)
        );
        Assert.areEqual('PT730641929.9999965S', zdt1.until(zdt2, JiffUnit.SECOND).toString());
        Assert.areEqual(
            new JiffSpan().nanoseconds(730641929999996500L),
            zdt1.until(zdt2, JiffUnit.NANOSECOND)
        );
    }

    @IsTest
    static void sinceIsUntilWithTheSignFlipped() {
        JiffZonedDateTime zdt1 = newYork(2024, 5, 3, 23, 30, 0, 0);
        JiffZonedDateTime zdt2 = newYork(2024, 2, 25, 7, 0, 0, 0);
        Assert.areEqual(new JiffSpan().hours(1647).minutes(30), zdt1.since(zdt2));
        Assert.areEqual(
            new JiffSpan().months(2).days(7).hours(16).minutes(30),
            zdt1.since(zdt2, JiffUnit.YEAR)
        );
    }

    @IsTest
    static void unitsBiggerThanDaysInhibitReversibility() {
        JiffZonedDateTime zdt1 = newYork(2024, 3, 2, 0, 0, 0, 0);
        JiffZonedDateTime zdt2 = newYork(2024, 5, 1, 0, 0, 0, 0);
        JiffSpan difference = zdt1.until(zdt2, JiffUnit.MONTH);
        Assert.areEqual(new JiffSpan().months(1).days(29), difference);
        // Not the same as the original datetime!
        Assert.areEqual(newYork(2024, 3, 3, 0, 0, 0, 0), zdt2.subtract(difference));
        // But in the default configuration, hours are always the biggest unit and
        // reversibility is guaranteed.
        difference = zdt1.until(zdt2);
        Assert.areEqual('PT1439H', difference.toString());
        Assert.areEqual(zdt1, zdt2.subtract(difference));
    }

    @IsTest
    static void calendarUnitsNeedTheSameTimeZone() {
        JiffZonedDateTime zdt1 = newYork(2024, 3, 2, 0, 0, 0, 0);
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 5, 1).inTz('America/Los_Angeles');
        for (JiffUnit largest : CALENDAR_UNITS) {
            try {
                zdt1.until(zdt2, largest);
                Assert.fail('expected ' + largest + ' to need matching time zones');
            } catch (JiffException e) {
                Assert.areEqual(
                    'computing the span between zoned datetimes, with ' +
                        largest.name().toLowerCase() +
                        ' units, requires that the time zones are equivalent, ' +
                        'but the zoned datetimes have distinct time zones',
                    e.getMessage()
                );
            }
        }
        // Exact units do not care.
        Assert.areEqual('PT1442H', zdt1.until(zdt2).toString());
        Assert.areEqual('PT1442H', zdt1.until(zdt2, JiffUnit.HOUR).toString());
        Assert.areEqual('PT1442H', zdt2.since(zdt1).toString());
    }

    @IsTest
    static void aliasesCountAsDistinctTimeZonesUnlikeInJiff() {
        JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 3, 2).inTz('Asia/Calcutta');
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2024, 5, 1).inTz('Asia/Kolkata');
        // Jiff compares the zone data and gives one month and 29 days here. The platform
        // cannot say that two names are the same zone, so this port refuses...
        try {
            zdt1.until(zdt2, JiffUnit.MONTH);
            Assert.fail('expected two aliases to count as distinct time zones');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('distinct time zones'), e.getMessage());
        }
        // ...until both sides are given the same name.
        Assert.areEqual(
            new JiffSpan().months(1).days(29),
            zdt1.inTz('Asia/Kolkata').until(zdt2, JiffUnit.MONTH)
        );
    }

    @IsTest
    static void untilWithLargestUnit() {
        // From `until_with_largest_unit` in Jiff's tests.
        JiffZonedDateTime zdt1 = JiffDate.newInstance(1995, 12, 7)
            .at(3, 24, 30, 3500)
            .inTz('Asia/Kolkata');
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2019, 1, 31)
            .at(15, 30, 0, 0)
            .inTz('Asia/Kolkata');
        JiffSpan clock = new JiffSpan()
            .hours(202956)
            .minutes(5)
            .seconds(29)
            .milliseconds(999)
            .microseconds(996)
            .nanoseconds(500);
        Assert.areEqual(clock, zdt1.until(zdt2));
        JiffSpan calendar = new JiffSpan()
            .years(23)
            .months(1)
            .days(24)
            .hours(12)
            .minutes(5)
            .seconds(29)
            .milliseconds(999)
            .microseconds(996)
            .nanoseconds(500);
        Assert.areEqual(calendar, zdt1.until(zdt2, JiffUnit.YEAR));
        Assert.areEqual(calendar.negate(), zdt2.until(zdt1, JiffUnit.YEAR));
        Assert.areEqual(
            new JiffSpan().nanoseconds(730641929999996500L),
            zdt1.until(zdt2, JiffUnit.NANOSECOND)
        );

        zdt1 = newYork(2020, 1, 1, 0, 0, 0, 0);
        zdt2 = newYork(2020, 4, 24, 21, 0, 0, 0);
        Assert.areEqual(new JiffSpan().hours(2756), zdt1.until(zdt2));
        Assert.areEqual(
            new JiffSpan().months(3).days(23).hours(21),
            zdt1.until(zdt2, JiffUnit.YEAR)
        );

        // A 25 hour day: the dates are equal, so there are no whole days to count.
        zdt1 = JiffDate.newInstance(2000, 10, 29).at(0, 0, 0, 0).inTz('America/Vancouver');
        zdt2 = JiffDate.newInstance(2000, 10, 29).at(23, 0, 0, 5).inTz('America/Vancouver');
        Assert.areEqual(new JiffSpan().hours(24).nanoseconds(5), zdt1.until(zdt2, JiffUnit.DAY));
    }

    @IsTest
    static void untilCrossesDstDay() {
        // From `until_crosses_dst_day` in Jiff's tests: the clock goes backwards while the
        // instants go forwards.
        JiffZonedDateTime start = newYork(2024, 11, 3, 1, 50, 0, 0);
        Assert.areEqual('2024-11-03T01:50:00-04:00[America/New_York]', start.toString());
        JiffZonedDateTime finish = zoned('2024-11-03T01:00:00-05:00[America/New_York]');
        for (JiffUnit largest : CALENDAR_UNITS) {
            Assert.areEqual(new JiffSpan().minutes(10), start.until(finish, largest));
            Assert.areEqual(new JiffSpan().minutes(-10), finish.until(start, largest));
        }
    }

    @IsTest
    static void untilCrossesDstDayDifferentDate() {
        // From `until_crosses_dst_day_different_date` in Jiff's tests: the later instant is on
        // the earlier civil date.
        JiffZonedDateTime start = zoned('2009-11-01T00:00:00-02:30[America/St_Johns]');
        JiffZonedDateTime finish = zoned('2009-10-31T23:01:00-03:30[America/St_Johns]');
        for (JiffUnit largest : CALENDAR_UNITS) {
            Assert.areEqual(new JiffSpan().minutes(1), start.until(finish, largest));
            Assert.areEqual(new JiffSpan().minutes(-1), finish.until(start, largest));
        }
    }

    @IsTest
    static void untilCrossesDstMultipleDays() {
        // From `until_crosses_dst_multiple_days` in Jiff's tests. Each row is: start, end, the
        // span from start to end, and the span from end to start.
        List<List<String>> cases = new List<List<String>>{
            new List<String>{
                '2024-11-01T01:50:00-04:00[America/New_York]',
                '2024-11-03T01:00:00-05:00[America/New_York]',
                'P2DT10M',
                '-P1DT23H10M'
            },
            new List<String>{
                '2024-11-03T01:50:00-04:00[America/New_York]',
                '2024-11-04T01:00:00-05:00[America/New_York]',
                'PT24H10M',
                '-PT24H10M'
            },
            new List<String>{
                '2024-11-03T01:50:00-05:00[America/New_York]',
                '2024-11-04T01:00:00-05:00[America/New_York]',
                'PT23H10M',
                '-PT23H10M'
            },
            new List<String>{
                '2024-03-09T02:30:00-05:00[America/New_York]',
                '2024-03-10T03:00:00-04:00[America/New_York]',
                'PT23H30M',
                '-P1DT30M'
            },
            // The first day correction lands on a skipped date.
            new List<String>{
                '2011-12-28T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T11:00:00+14:00[Pacific/Apia]',
                'P1DT23H',
                '-P2DT23H'
            }
        };
        for (List<String> row : cases) {
            JiffZonedDateTime start = zoned(row.get(0));
            JiffZonedDateTime finish = zoned(row.get(1));
            for (JiffUnit largest : CALENDAR_UNITS) {
                String label = row.get(0) + ' and ' + row.get(1) + ', ' + largest;
                JiffSpan forward = start.until(finish, largest);
                Assert.areEqual(span(row.get(2)), forward, label);
                Assert.areEqual(finish, start.add(forward), label);

                JiffSpan backward = finish.until(start, largest);
                Assert.areEqual(span(row.get(3)), backward, label);
                Assert.areEqual(start, finish.add(backward), label);
            }
        }
    }

    @IsTest
    static void differencesAgreeWithJiffInManyZones() {
        // Each row is: start, end, the span from start to end with years, months, weeks, days
        // and hours as the largest unit, and then the same five from end to start.
        List<List<String>> cases = new List<List<String>>{
            new List<String>{
                '2024-03-09T12:00:00-05:00[America/New_York]',
                '2024-03-10T12:00:00-04:00[America/New_York]',
                'P1D',
                'P1D',
                'P1D',
                'P1D',
                'PT23H',
                '-P1D',
                '-P1D',
                '-P1D',
                '-P1D',
                '-PT23H'
            },
            new List<String>{
                '2024-11-02T12:00:00-04:00[America/New_York]',
                '2024-11-03T12:00:00-05:00[America/New_York]',
                'P1D',
                'P1D',
                'P1D',
                'P1D',
                'PT25H',
                '-P1D',
                '-P1D',
                '-P1D',
                '-P1D',
                '-PT25H'
            },
            new List<String>{
                '2024-03-30T12:00:00+00:00[Europe/London]',
                '2024-10-27T11:00:00+00:00[Europe/London]',
                'P6M26DT24H',
                'P6M26DT24H',
                'P30WT24H',
                'P210DT24H',
                'PT5063H',
                '-P6M27DT22H',
                '-P6M27DT22H',
                '-P30WT22H',
                '-P210DT22H',
                '-PT5063H'
            },
            new List<String>{
                '2024-04-06T12:00:00+11:00[Australia/Sydney]',
                '2025-10-05T13:00:00+11:00[Australia/Sydney]',
                'P1Y5M29DT1H',
                'P17M29DT1H',
                'P78W1DT1H',
                'P547DT1H',
                'PT13129H',
                '-P1Y5M29DT1H',
                '-P17M29DT1H',
                '-P78W1DT1H',
                '-P547DT1H',
                '-PT13129H'
            },
            new List<String>{
                '2020-02-29T23:59:59.999999999+05:30[Asia/Kolkata]',
                '2024-03-01T00:00:00+05:30[Asia/Kolkata]',
                'P4YT0.000000001S',
                'P48MT0.000000001S',
                'P208W5DT0.000000001S',
                'P1461DT0.000000001S',
                'PT35064H0.000000001S',
                '-P4YT0.000000001S',
                '-P48MT0.000000001S',
                '-P208W5DT0.000000001S',
                '-P1461DT0.000000001S',
                '-PT35064H0.000000001S'
            },
            new List<String>{
                '2015-10-17T12:00:00-03:00[America/Sao_Paulo]',
                '2015-10-18T01:00:00-02:00[America/Sao_Paulo]',
                'PT12H',
                'PT12H',
                'PT12H',
                'PT12H',
                'PT12H',
                '-PT12H',
                '-PT12H',
                '-PT12H',
                '-PT12H',
                '-PT12H'
            },
            new List<String>{
                '2011-12-29T00:00:00-10:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                'P2D',
                'P2D',
                'P2D',
                'P2D',
                'PT24H',
                '-P2D',
                '-P2D',
                '-P2D',
                '-P2D',
                '-PT24H'
            },
            new List<String>{
                '2011-12-28T00:00:00-10:00[Pacific/Apia]',
                '2012-01-02T06:00:00+14:00[Pacific/Apia]',
                'P5DT6H',
                'P5DT6H',
                'P5DT6H',
                'P5DT6H',
                'PT102H',
                '-P5DT6H',
                '-P5DT6H',
                '-P5DT6H',
                '-P5DT6H',
                '-PT102H'
            },
            new List<String>{
                '2024-01-31T10:00:00+00:00[UTC]',
                '2024-03-01T09:00:00+00:00[UTC]',
                'P29DT23H',
                'P29DT23H',
                'P4W1DT23H',
                'P29DT23H',
                'PT719H',
                '-P1MT23H',
                '-P1MT23H',
                '-P4W1DT23H',
                '-P29DT23H',
                '-PT719H'
            },
            new List<String>{
                '2024-01-31T10:00:00-05:30[-05:30]',
                '2025-03-01T09:00:00-05:30[-05:30]',
                'P1Y28DT23H',
                'P12M28DT23H',
                'P56W2DT23H',
                'P394DT23H',
                'PT9479H',
                '-P1Y1MT23H',
                '-P13MT23H',
                '-P56W2DT23H',
                '-P394DT23H',
                '-PT9479H'
            }
        };
        List<JiffUnit> units = new List<JiffUnit>{
            JiffUnit.YEAR,
            JiffUnit.MONTH,
            JiffUnit.WEEK,
            JiffUnit.DAY,
            JiffUnit.HOUR
        };
        for (List<String> row : cases) {
            JiffZonedDateTime start = zoned(row.get(0));
            JiffZonedDateTime finish = zoned(row.get(1));
            for (Integer i = 0; i < units.size(); i++) {
                JiffUnit largest = units.get(i);
                String label = row.get(0) + ' and ' + row.get(1) + ', ' + largest;
                JiffSpan forward = start.until(finish, largest);
                Assert.areEqual(row.get(2 + i), forward.toString(), label);
                Assert.areEqual(finish, start.add(forward), label);
                Assert.areEqual(forward.negate(), start.since(finish, largest), label);

                JiffSpan backward = finish.until(start, largest);
                Assert.areEqual(row.get(7 + i), backward.toString(), label);
                Assert.areEqual(start, finish.add(backward), label);
                Assert.areEqual(backward.negate(), finish.since(start, largest), label);
            }
        }
    }

    @IsTest
    static void theSpanBetweenAnInstantAndItselfIsZero() {
        JiffZonedDateTime zdt = newYork(2024, 7, 4, 12, 0, 0, 0);
        JiffZonedDateTime elsewhere = zdt.inTz('Asia/Kolkata');
        for (JiffUnit largest : JiffUnit.values()) {
            Assert.areEqual('PT0S', zdt.until(zdt, largest).toString());
            Assert.areEqual('PT0S', zdt.since(zdt, largest).toString());
            // Not even a mismatch of time zones matters when there is nothing to count.
            Assert.areEqual('PT0S', zdt.until(elsewhere, largest).toString());
        }
        Assert.isTrue(zdt.until(zdt).isZero());
    }

    @IsTest
    static void differencesSpanTheWholeSupportedRange() {
        JiffZonedDateTime min = JiffTimestamp.MIN.inTz('UTC');
        JiffZonedDateTime max = JiffTimestamp.MAX.inTz('UTC');
        Assert.areEqual('P19998Y11M28DT20H1.999999999S', min.until(max, JiffUnit.YEAR).toString());
        Assert.areEqual('-P19998Y11M28DT20H1.999999999S', max.until(min, JiffUnit.YEAR).toString());
        Assert.areEqual('PT175307564H1.999999999S', min.until(max).toString());
    }

    @IsTest
    static void nanosecondsOverflowBeyondAbout292Years() {
        JiffZonedDateTime zdt1 = JiffDate.newInstance(1700, 1, 1).inTz('UTC');
        JiffZonedDateTime zdt2 = JiffDate.newInstance(2300, 1, 1).inTz('UTC');
        Assert.areEqual('P600Y', zdt1.until(zdt2, JiffUnit.YEAR).toString());
        try {
            zdt1.until(zdt2, JiffUnit.NANOSECOND);
            Assert.fail('expected 600 years of nanoseconds to overflow a span');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'nanoseconds\' is not in the required range of ' +
                '-9223372036854775807..=9223372036854775807',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void calendarDifferencesNeedTheTimeOfDayOnTheLastDay() {
        // The last supported day ends at 22:00 UTC and the first begins at 01:59:59, so a
        // time of day outside those hours cannot be placed on them to count whole days.
        JiffZonedDateTime max = JiffTimestamp.MAX.inTz('UTC');
        JiffZonedDateTime min = JiffTimestamp.MIN.inTz('UTC');
        JiffZonedDateTime late = JiffDate.newInstance(2024, 1, 1).at(23, 0, 0, 0).inTz('UTC');
        JiffZonedDateTime early = JiffDate.newInstance(2024, 1, 1).at(0, 30, 0, 0).inTz('UTC');
        String expected =
            'failed to convert intermediate datetime to zoned timestamp: converting datetime ' +
            'with time zone offset `+00` to timestamp overflowed: ' +
            TIMESTAMP_RANGE;
        for (JiffUnit largest : CALENDAR_UNITS) {
            try {
                late.until(max, largest);
                Assert.fail('expected 23:00 not to exist on the last day, with ' + largest);
            } catch (JiffException e) {
                Assert.areEqual(expected, e.getMessage());
            }
            try {
                early.until(min, largest);
                Assert.fail('expected 00:30 not to exist on the first day, with ' + largest);
            } catch (JiffException e) {
                Assert.areEqual(expected, e.getMessage());
            }
        }
        // The other way round there is nothing in the way, and exact units never mind.
        Assert.areEqual(
            'P7975Y11M29DT21H30M0.999999999S',
            early.until(max, JiffUnit.YEAR).toString()
        );
        Assert.areEqual('-P12022Y11M30DT21H1S', late.until(min, JiffUnit.YEAR).toString());
        Assert.areEqual('P7975Y11M28DT23H0.999999999S', max.since(late, JiffUnit.YEAR).toString());
        Assert.areEqual('PT69916127H0.999999999S', late.until(max).toString());
        Assert.areEqual('-PT105391414H30M1S', early.until(min).toString());
    }

    // ---- exact durations ------------------------------------------------

    @IsTest
    static void durationUntilIsTheElapsedTime() {
        JiffZonedDateTime earlier = newYork(2006, 8, 24, 22, 30, 0, 0);
        JiffZonedDateTime later = newYork(2019, 1, 31, 21, 0, 0, 0);
        JiffSignedDuration expected = JiffSignedDuration.fromHours(109031)
            .add(JiffSignedDuration.fromMins(30));
        Assert.areEqual(expected, earlier.durationUntil(later));
        // Flipping the dates is fine, but you'll get a negative duration.
        Assert.areEqual(expected.negate(), later.durationUntil(earlier));
        Assert.areEqual(expected, later.durationSince(earlier));
        Assert.areEqual(expected.negate(), earlier.durationSince(later));
    }

    @IsTest
    static void aDurationSeesTheRealLengthOfADay() {
        JiffZonedDateTime zdt1 = newYork(2024, 3, 10, 0, 0, 0, 0);
        JiffZonedDateTime zdt2 = newYork(2024, 3, 11, 0, 0, 0, 0);
        Assert.areEqual(new JiffSpan().days(1), zdt1.until(zdt2, JiffUnit.DAY));
        // This day was only 23 hours long!
        Assert.areEqual(JiffSignedDuration.fromHours(23), zdt1.durationUntil(zdt2));

        zdt1 = newYork(2024, 7, 1, 0, 0, 0, 0);
        zdt2 = newYork(2024, 8, 1, 0, 0, 0, 0);
        Assert.areEqual(JiffSignedDuration.fromSecs(31 * 24 * 60 * 60L), zdt1.durationUntil(zdt2));
    }

    @IsTest
    static void durationsIgnoreTheTimeZones() {
        JiffZonedDateTime zdt1 = zoned('2024-07-04T12:00:00-04:00[America/New_York]');
        JiffZonedDateTime zdt2 = zoned('2024-07-05T00:00:00+05:30[Asia/Kolkata]');
        Assert.areEqual(JiffSignedDuration.fromMins(150), zdt1.durationUntil(zdt2));
        Assert.areEqual(JiffSignedDuration.fromMins(-150), zdt1.durationSince(zdt2));
        Assert.areEqual(JiffSignedDuration.ZERO, zdt1.durationUntil(zdt1.inTz('Asia/Kolkata')));
    }
}
