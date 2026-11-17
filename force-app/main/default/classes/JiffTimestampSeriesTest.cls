@IsTest
private class JiffTimestampSeriesTest {
    private static JiffTimestamp at(
        Integer offsetHours,
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute
    ) {
        return JiffOffset.fromHours(offsetHours)
            .toTimestamp(JiffDateTime.newInstance(year, month, day, hour, minute, 0, 0));
    }

    private static List<String> strings(List<JiffTimestamp> timestamps) {
        List<String> out = new List<String>();
        for (JiffTimestamp timestamp : timestamps) {
            out.add(timestamp.toString());
        }
        return out;
    }

    @IsTest
    static void stepsThroughEveryFiveHoursForTwoDays() {
        // Jiff's example: when to scan a glucose monitor in the 48 hours after it is fitted.
        JiffTimestamp start = at(-4, 2023, 7, 15, 16, 30);
        JiffTimestamp finish = start.add(new JiffSpan().hours(48L));
        List<JiffTimestamp> scanTimes = new List<JiffTimestamp>();
        for (JiffTimestamp scan : start.series(new JiffSpan().hours(5L))) {
            if (scan.isAfter(finish)) {
                break;
            }
            scanTimes.add(scan);
        }
        List<JiffTimestamp> expected = new List<JiffTimestamp>{
            at(-4, 2023, 7, 15, 16, 30),
            at(-4, 2023, 7, 15, 21, 30),
            at(-4, 2023, 7, 16, 2, 30),
            at(-4, 2023, 7, 16, 7, 30),
            at(-4, 2023, 7, 16, 12, 30),
            at(-4, 2023, 7, 16, 17, 30),
            at(-4, 2023, 7, 16, 22, 30),
            at(-4, 2023, 7, 17, 3, 30),
            at(-4, 2023, 7, 17, 8, 30),
            at(-4, 2023, 7, 17, 13, 30)
        };
        Assert.areEqual(strings(expected), strings(scanTimes));
    }

    @IsTest
    static void takeCollectsTheNextTimestamps() {
        JiffTimestampSeries series = JiffTimestamp.UNIX_EPOCH.series(new JiffSpan().minutes(90L));
        Assert.areEqual(
            new List<String>{ '1970-01-01T00:00:00Z', '1970-01-01T01:30:00Z' },
            strings(series.take(2))
        );
        // The series carries on from where it stopped.
        Assert.areEqual(new List<String>{ '1970-01-01T03:00:00Z' }, strings(series.take(1)));
        Assert.areEqual(0, series.take(0).size());
        Assert.isTrue(series.hasNext());
        Assert.areEqual('1970-01-01T04:30:00Z', series.next().toString());
    }

    @IsTest
    static void aNegativePeriodWalksBackward() {
        Assert.areEqual(
            new List<String>{
                '1970-01-01T00:00:00Z',
                '1969-12-31T22:30:00Z',
                '1969-12-31T21:00:00Z'
            },
            strings(JiffTimestamp.UNIX_EPOCH.series(new JiffSpan().minutes(-90L)).take(3))
        );
    }

    @IsTest
    static void aZeroPeriodRepeatsTheStart() {
        List<JiffTimestamp> repeated = JiffTimestamp.UNIX_EPOCH.series(new JiffSpan()).take(3);
        Assert.areEqual(3, repeated.size());
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, repeated.get(2));
    }

    @IsTest
    static void stopsBeforeTheLimitOfTheRange() {
        JiffTimestamp nearMax = JiffTimestamp.MAX.subtract(new JiffSpan().hours(3L));
        JiffTimestampSeries series = nearMax.series(new JiffSpan().hours(1L));
        // As in Jiff, a timestamp is produced only while the one after it also exists, so the
        // series ends one step short of the maximum.
        Assert.areEqual(
            new List<String>{
                '9999-12-30T19:00:00.999999999Z',
                '9999-12-30T20:00:00.999999999Z',
                '9999-12-30T21:00:00.999999999Z'
            },
            strings(series.take(10))
        );
        Assert.isFalse(series.hasNext());
        try {
            series.next();
            Assert.fail('expected an exhausted series to throw');
        } catch (JiffException e) {
            Assert.areEqual('timestamp series has no more elements', e.getMessage());
        }
        Assert.isFalse(JiffTimestamp.MAX.series(new JiffSpan().nanoseconds(1L)).hasNext());
        Assert.isFalse(JiffTimestamp.MIN.series(new JiffSpan().nanoseconds(-1L)).hasNext());
        Assert.isTrue(JiffTimestamp.MIN.series(new JiffSpan().nanoseconds(1L)).hasNext());
    }

    @IsTest
    static void aPeriodWithCalendarUnitsYieldsNothing() {
        for (
            JiffSpan period : new List<JiffSpan>{
                new JiffSpan().days(1L),
                new JiffSpan().weeks(1L),
                new JiffSpan().months(1L).hours(2L),
                new JiffSpan().years(-1L)
            }
        ) {
            JiffTimestampSeries series = JiffTimestamp.UNIX_EPOCH.series(period);
            Assert.isFalse(series.hasNext(), 'series by ' + period);
            Assert.areEqual(0, series.take(3).size());
        }
    }

    @IsTest
    static void iteratingConsumesTheSeriesItself() {
        JiffTimestampSeries series = new JiffTimestampSeries(
            JiffTimestamp.UNIX_EPOCH,
            new JiffSpan().seconds(1L)
        );
        Integer seen = 0;
        for (JiffTimestamp timestamp : series) {
            seen++;
            if (seen == 3) {
                break;
            }
        }
        Assert.areEqual(JiffTimestamp.fromSecond(3L), series.next());
        Iterator<JiffTimestamp> cursor = series.iterator();
        Assert.areEqual(JiffTimestamp.fromSecond(4L), cursor.next());
        Assert.areEqual(JiffTimestamp.fromSecond(5L), series.next());
    }
}
