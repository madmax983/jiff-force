/**
 * `JiffZonedDateTime.series` and `JiffZonedDateTimeSeries`.
 *
 * Expected values are from the examples in Jiff's documentation of `ZonedDateTime::series`,
 * or were printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffZonedDateTimeSeriesTest {
    private static final String NEW_YORK = 'America/New_York';

    private static JiffZonedDateTime newYork(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute
    ) {
        return JiffDate.newInstance(year, month, day).at(hour, minute, 0, 0).inTz(NEW_YORK);
    }

    /** The next `count` elements of `series`, printed. */
    private static List<String> take(JiffZonedDateTimeSeries series, Integer count) {
        List<String> out = new List<String>();
        while (out.size() < count && series.hasNext()) {
            out.add(series.next().toString());
        }
        return out;
    }

    /** Every remaining element of a series that is known to end, printed. */
    private static List<String> drain(JiffZonedDateTimeSeries series) {
        List<String> out = new List<String>();
        for (JiffZonedDateTime zdt : series) {
            out.add(zdt.toString());
            Assert.isTrue(out.size() < 100, 'the series should have ended');
        }
        return out;
    }

    @IsTest
    static void whenToCheckAGlucoseMonitor() {
        JiffZonedDateTime start = newYork(2023, 7, 15, 16, 30);
        JiffZonedDateTime finish = start.add(new JiffSpan().days(2));
        List<JiffDateTime> scanTimes = new List<JiffDateTime>();
        for (JiffZonedDateTime zdt : start.series(new JiffSpan().hours(5))) {
            if (zdt.isAfter(finish)) {
                break;
            }
            scanTimes.add(zdt.toDateTime());
        }
        Assert.areEqual(
            new List<JiffDateTime>{
                JiffDateTime.newInstance(2023, 7, 15, 16, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 15, 21, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 16, 2, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 16, 7, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 16, 12, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 16, 17, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 16, 22, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 17, 3, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 17, 8, 30, 0, 0),
                JiffDateTime.newInstance(2023, 7, 17, 13, 30, 0, 0)
            },
            scanTimes
        );
    }

    @IsTest
    static void clockUnitsStepOverAGap() {
        JiffZonedDateTime zdt = newYork(2025, 3, 9, 1, 0);
        Assert.areEqual(
            new List<String>{
                '2025-03-09T01:00:00-05:00[America/New_York]',
                '2025-03-09T01:30:00-05:00[America/New_York]',
                '2025-03-09T03:00:00-04:00[America/New_York]',
                '2025-03-09T03:30:00-04:00[America/New_York]'
            },
            take(zdt.series(new JiffSpan().minutes(30)), 4)
        );
    }

    @IsTest
    static void clockUnitsStepThroughBothHalvesOfAFold() {
        JiffZonedDateTime zdt = newYork(2025, 11, 2, 0, 30);
        Assert.areEqual(
            new List<String>{
                '2025-11-02T00:30:00-04:00[America/New_York]',
                '2025-11-02T01:00:00-04:00[America/New_York]',
                '2025-11-02T01:30:00-04:00[America/New_York]',
                '2025-11-02T01:00:00-05:00[America/New_York]',
                '2025-11-02T01:30:00-05:00[America/New_York]',
                '2025-11-02T02:00:00-05:00[America/New_York]'
            },
            take(zdt.series(new JiffSpan().minutes(30)), 6)
        );

        JiffZonedDateTime london = JiffDate.newInstance(2024, 10, 27)
            .at(0, 30, 0, 0)
            .inTz('Europe/London');
        Assert.areEqual(
            new List<String>{
                '2024-10-27T00:30:00+01:00[Europe/London]',
                '2024-10-27T01:15:00+01:00[Europe/London]',
                '2024-10-27T01:00:00+00:00[Europe/London]',
                '2024-10-27T01:45:00+00:00[Europe/London]',
                '2024-10-27T02:30:00+00:00[Europe/London]'
            },
            take(london.series(new JiffSpan().minutes(45)), 5)
        );
    }

    @IsTest
    static void calendarUnitsKeepTheTimeOfDay() {
        Assert.areEqual(
            new List<String>{
                '2024-03-08T02:30:00-05:00[America/New_York]',
                '2024-03-09T02:30:00-05:00[America/New_York]',
                // 02:30 does not exist on the 10th.
                '2024-03-10T03:30:00-04:00[America/New_York]',
                '2024-03-11T02:30:00-04:00[America/New_York]'
            },
            take(newYork(2024, 3, 8, 2, 30).series(new JiffSpan().days(1)), 4)
        );
    }

    @IsTest
    static void eachElementIsComputedFromTheStart() {
        Assert.areEqual(
            new List<String>{
                '2024-01-31T02:30:00-05:00[America/New_York]',
                '2024-02-29T02:30:00-05:00[America/New_York]',
                // Back on the 31st, which a running total would have lost.
                '2024-03-31T02:30:00-04:00[America/New_York]',
                '2024-04-30T02:30:00-04:00[America/New_York]'
            },
            take(newYork(2024, 1, 31, 2, 30).series(new JiffSpan().months(1)), 4)
        );
    }

    @IsTest
    static void aSkippedDayIsNotRepeated() {
        // Apia never had 2011-12-30, so one day and two days after the 29th are the same
        // instant.
        JiffZonedDateTime zdt = JiffDate.newInstance(2011, 12, 29).inTz('Pacific/Apia');
        Assert.areEqual(
            '2011-12-31T00:00:00+14:00[Pacific/Apia]',
            zdt.add(new JiffSpan().days(1)).toString()
        );
        Assert.areEqual(
            '2011-12-31T00:00:00+14:00[Pacific/Apia]',
            zdt.add(new JiffSpan().days(2)).toString()
        );
        Assert.areEqual(
            '2012-01-01T00:00:00+14:00[Pacific/Apia]',
            zdt.add(new JiffSpan().days(3)).toString()
        );
        // The series yields it once.
        zdt = JiffDate.newInstance(2011, 12, 28).inTz('Pacific/Apia');
        Assert.areEqual(
            new List<String>{
                '2011-12-28T00:00:00-10:00[Pacific/Apia]',
                '2011-12-29T00:00:00-10:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                '2012-01-01T00:00:00+14:00[Pacific/Apia]'
            },
            take(zdt.series(new JiffSpan().days(1)), 4)
        );
    }

    @IsTest
    static void aNegativePeriodWalksBackwardsWithoutRepeating() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2012, 1, 1).inTz('Pacific/Apia');
        Assert.areEqual(
            new List<String>{
                '2012-01-01T00:00:00+14:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                '2011-12-29T00:00:00-10:00[Pacific/Apia]',
                '2011-12-28T00:00:00-10:00[Pacific/Apia]'
            },
            take(zdt.series(new JiffSpan().days(-1)), 4)
        );
    }

    @IsTest
    static void aZeroPeriodRepeatsTheStart() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2011, 12, 28).inTz('Pacific/Apia');
        Assert.areEqual(
            new List<String>{
                '2011-12-28T00:00:00-10:00[Pacific/Apia]',
                '2011-12-28T00:00:00-10:00[Pacific/Apia]',
                '2011-12-28T00:00:00-10:00[Pacific/Apia]'
            },
            take(zdt.series(new JiffSpan()), 3)
        );
    }

    @IsTest
    static void endsBeforeLeavingTheSupportedRange() {
        JiffZonedDateTime nearMax = JiffDate.newInstance(9999, 12, 28).inTz('UTC');
        Assert.areEqual(
            new List<String>{
                '9999-12-28T00:00:00+00:00[UTC]',
                '9999-12-29T00:00:00+00:00[UTC]',
                '9999-12-30T00:00:00+00:00[UTC]'
            },
            drain(nearMax.series(new JiffSpan().days(1)))
        );
        JiffZonedDateTime nearMin = JiffTimestamp.MIN.inTz('UTC').add(new JiffSpan().hours(49));
        Assert.areEqual(
            new List<String>{
                '-009999-01-04T02:59:59+00:00[UTC]',
                '-009999-01-03T02:59:59+00:00[UTC]',
                '-009999-01-02T02:59:59+00:00[UTC]'
            },
            drain(nearMin.series(new JiffSpan().days(-1)))
        );
    }

    @IsTest
    static void endsWhenThePeriodCanNoLongerBeScaled() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2024, 1, 1).inTz('UTC');
        // Twice 19,998 years is more than a span can hold.
        Assert.areEqual(1, drain(zdt.series(new JiffSpan().years(19998))).size());
        // The largest count of nanoseconds can be added once, but not doubled.
        Assert.areEqual(2, drain(zdt.series(new JiffSpan().nanoseconds(JiffMath.LONG_MAX))).size());
    }

    @IsTest
    static void endsWhenTheStepCounterIsExhausted() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2024, 1, 1).inTz('UTC');
        // A zero period never overflows, so only the counter can stop it.
        JiffZonedDateTimeSeries series = new JiffZonedDateTimeSeries(
            zdt,
            new JiffSpan(),
            JiffMath.LONG_MAX - 1
        );
        Assert.isTrue(series.hasNext());
        Assert.areEqual(zdt, series.next());
        Assert.isFalse(series.hasNext());
    }

    @IsTest
    static void anEndedSeriesStaysEnded() {
        JiffZonedDateTimeSeries series = JiffDate.newInstance(9999, 12, 30)
            .inTz('UTC')
            .series(new JiffSpan().days(1));
        Assert.isTrue(series.hasNext());
        Assert.areEqual('9999-12-30T00:00:00+00:00[UTC]', series.next().toString());
        Assert.isFalse(series.hasNext());
        Assert.isFalse(series.hasNext());
        try {
            series.next();
            Assert.fail('expected an ended series to refuse to give another element');
        } catch (JiffException e) {
            Assert.areEqual('the zoned datetime series has no more elements', e.getMessage());
        }
    }

    @IsTest
    static void aSecondLoopContinuesWhereTheFirstStopped() {
        JiffZonedDateTimeSeries series = newYork(2024, 7, 1, 9, 0).series(new JiffSpan().days(1));
        // The series is its own iterator.
        Iterator<JiffZonedDateTime> cursor = series.iterator();
        Assert.areEqual(1, cursor.next().day());
        Integer seen = 1;
        for (JiffZonedDateTime zdt : series) {
            seen++;
            if (zdt.day() == 3) {
                break;
            }
        }
        Assert.areEqual(3, seen);
        // hasNext() does not consume anything, however often it is asked.
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual('2024-07-04T09:00:00-04:00[America/New_York]', series.next().toString());
        Assert.areEqual('2024-07-05T09:00:00-04:00[America/New_York]', series.next().toString());
    }

    @IsTest
    static void needsAStartAndAPeriod() {
        try {
            new JiffZonedDateTimeSeries(null, new JiffSpan());
            Assert.fail('expected a missing start to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'the start of a zoned datetime series must not be null',
                e.getMessage()
            );
        }
        try {
            new JiffZonedDateTimeSeries(JiffZonedDateTime.UNIX_EPOCH, null);
            Assert.fail('expected a missing period to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'the period of a zoned datetime series must not be null',
                e.getMessage()
            );
        }
    }
}
