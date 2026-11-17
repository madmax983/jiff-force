@IsTest
private class JiffDateTimeSeriesTest {
    private static JiffDateTime civil(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, second, subsecNanosecond);
    }

    /** A datetime on the given day and hour, with the rest of the time zero. */
    private static JiffDateTime atHour(Integer year, Integer month, Integer day, Integer hour) {
        return JiffDateTime.newInstance(year, month, day, hour, 0, 0, 0);
    }

    /** Collects at most `count` datetimes from `series`. */
    private static List<JiffDateTime> take(JiffDateTimeSeries series, Integer count) {
        List<JiffDateTime> datetimes = new List<JiffDateTime>();
        while (datetimes.size() < count && series.hasNext()) {
            datetimes.add(series.next());
        }
        return datetimes;
    }

    @IsTest
    static void listsWhenToScanAGlucoseMonitor() {
        // "My veterinarian installed a glucose monitor and instructed me to scan it about
        // every 5 hours": all the scans for the 2 days following its installation.
        JiffDateTime start = civil(2023, 7, 15, 16, 30, 0, 0);
        JiffDateTime finish = start.add(new JiffSpan().days(2));
        List<JiffDateTime> scanTimes = new List<JiffDateTime>();
        for (JiffDateTime scan : start.series(new JiffSpan().hours(5))) {
            if (scan.isAfter(finish)) {
                break;
            }
            scanTimes.add(scan);
        }
        Assert.areEqual(
            new List<JiffDateTime>{
                civil(2023, 7, 15, 16, 30, 0, 0),
                civil(2023, 7, 15, 21, 30, 0, 0),
                civil(2023, 7, 16, 2, 30, 0, 0),
                civil(2023, 7, 16, 7, 30, 0, 0),
                civil(2023, 7, 16, 12, 30, 0, 0),
                civil(2023, 7, 16, 17, 30, 0, 0),
                civil(2023, 7, 16, 22, 30, 0, 0),
                civil(2023, 7, 17, 3, 30, 0, 0),
                civil(2023, 7, 17, 8, 30, 0, 0),
                civil(2023, 7, 17, 13, 30, 0, 0)
            },
            scanTimes
        );
    }

    @IsTest
    static void aPeriodLongerThanADayMovesTheDateAndTheTime() {
        Assert.areEqual(
            new List<JiffDateTime>{
                civil(2024, 3, 10, 7, 30, 0, 0),
                civil(2024, 3, 11, 19, 30, 0, 0),
                civil(2024, 3, 13, 7, 30, 0, 0),
                civil(2024, 3, 14, 19, 30, 0, 0),
                civil(2024, 3, 16, 7, 30, 0, 0)
            },
            take(civil(2024, 3, 10, 7, 30, 0, 0).series(new JiffSpan().hours(36)), 5)
        );
    }

    @IsTest
    static void aNegativePeriodWalksBackward() {
        Assert.areEqual(
            new List<JiffDateTime>{
                civil(2024, 3, 10, 7, 30, 0, 0),
                civil(2024, 3, 2, 19, 30, 0, 0),
                civil(2024, 2, 24, 7, 30, 0, 0),
                civil(2024, 2, 16, 19, 30, 0, 0)
            },
            take(civil(2024, 3, 10, 7, 30, 0, 0).series(new JiffSpan().weeks(-1).hours(-12)), 4)
        );
    }

    @IsTest
    static void eachDatetimeIsComputedFromTheStart() {
        // Stepping a month at a time from the previous result would stick at the 29th.
        Assert.areEqual(
            new List<JiffDateTime>{
                atHour(2024, 1, 31, 12),
                atHour(2024, 2, 29, 12),
                atHour(2024, 3, 31, 12),
                atHour(2024, 4, 30, 12),
                atHour(2024, 5, 31, 12),
                atHour(2024, 6, 30, 12)
            },
            take(atHour(2024, 1, 31, 12).series(new JiffSpan().months(1)), 6)
        );
    }

    @IsTest
    static void calendarAndClockUnitsCombineInOnePeriod() {
        Assert.areEqual(
            new List<JiffDateTime>{
                civil(2024, 1, 31, 23, 30, 0, 0),
                civil(2024, 3, 1, 0, 30, 0, 0),
                civil(2024, 4, 1, 1, 30, 0, 0),
                civil(2024, 5, 1, 2, 30, 0, 0),
                civil(2024, 6, 1, 3, 30, 0, 0)
            },
            take(civil(2024, 1, 31, 23, 30, 0, 0).series(new JiffSpan().months(1).hours(1)), 5)
        );
    }

    @IsTest
    static void endsWhenTheNextDatetimeWouldLeaveTheSupportedRange() {
        Assert.areEqual(
            new List<JiffDateTime>{
                atHour(9999, 12, 31, 20),
                atHour(9999, 12, 31, 21),
                atHour(9999, 12, 31, 22),
                atHour(9999, 12, 31, 23)
            },
            take(atHour(9999, 12, 31, 20).series(new JiffSpan().hours(1)), 100)
        );
        Assert.areEqual(
            new List<JiffDateTime>{
                atHour(-9999, 1, 1, 3),
                atHour(-9999, 1, 1, 2),
                atHour(-9999, 1, 1, 1),
                atHour(-9999, 1, 1, 0)
            },
            take(atHour(-9999, 1, 1, 3).series(new JiffSpan().hours(-1)), 100)
        );
        Assert.areEqual(
            new List<JiffDateTime>{
                civil(9999, 12, 31, 23, 59, 59, 999999997),
                civil(9999, 12, 31, 23, 59, 59, 999999998),
                civil(9999, 12, 31, 23, 59, 59, 999999999)
            },
            take(
                civil(9999, 12, 31, 23, 59, 59, 999999997).series(new JiffSpan().nanoseconds(1)),
                100
            )
        );
        Assert.areEqual(
            new List<JiffDateTime>{ JiffDateTime.MIN },
            take(JiffDateTime.MIN.series(new JiffSpan().nanoseconds(-1)), 100)
        );
        Assert.areEqual(
            new List<JiffDateTime>{
                atHour(-9999, 1, 1, 0),
                atHour(-4999, 1, 1, 0),
                atHour(1, 1, 1, 0),
                atHour(5001, 1, 1, 0)
            },
            take(JiffDateTime.MIN.series(new JiffSpan().years(5000)), 100)
        );
    }

    @IsTest
    static void endsWhenTheMultipliedPeriodNoLongerFitsInASpan() {
        // Twice 10,000 years is more than a span can hold, so only the start is produced.
        Assert.areEqual(
            new List<JiffDateTime>{ atHour(2024, 1, 1, 0) },
            take(atHour(2024, 1, 1, 0).series(new JiffSpan().years(10000)), 100)
        );
    }

    @IsTest
    static void staysEndedOnceItHasEnded() {
        JiffDateTimeSeries series = atHour(9999, 12, 31, 22).series(new JiffSpan().hours(1));
        Assert.isTrue(series.hasNext());
        Assert.areEqual(atHour(9999, 12, 31, 22), series.next());
        Assert.areEqual(atHour(9999, 12, 31, 23), series.next());
        Assert.isFalse(series.hasNext());
        Assert.isFalse(series.hasNext());
        for (Integer attempt = 0; attempt < 2; attempt++) {
            try {
                JiffDateTime unexpected = series.next();
                Assert.fail('expected the ended series to refuse, but it gave ' + unexpected);
            } catch (JiffException e) {
                Assert.areEqual('the datetime series has no more elements', e.getMessage());
            }
        }
        Assert.isFalse(series.hasNext());
    }

    @IsTest
    static void hasNextDoesNotAdvanceTheSeries() {
        JiffDateTimeSeries series = atHour(2023, 7, 15, 16).series(new JiffSpan().hours(5));
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(atHour(2023, 7, 15, 16), series.next());
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(atHour(2023, 7, 15, 21), series.next());
        // And next() works without asking first.
        Assert.areEqual(atHour(2023, 7, 16, 2), series.next());
        Assert.areEqual(atHour(2023, 7, 16, 7), series.next());
    }

    @IsTest
    static void aZeroPeriodRepeatsTheStartForever() {
        JiffDateTime start = civil(2024, 6, 19, 15, 22, 45, 5);
        JiffDateTimeSeries series = start.series(new JiffSpan());
        for (Integer i = 0; i < 50; i++) {
            Assert.isTrue(series.hasNext());
            Assert.areEqual(start, series.next());
        }
    }

    @IsTest
    static void aLoopContinuesFromWhereTheSeriesIs() {
        JiffDateTimeSeries series = atHour(2023, 7, 15, 16).series(new JiffSpan().hours(5));
        Assert.areEqual(atHour(2023, 7, 15, 16), series.next());
        // The series is its own iterator.
        Iterator<JiffDateTime> cursor = series.iterator();
        Assert.areEqual(atHour(2023, 7, 15, 21), cursor.next());
        List<JiffDateTime> seen = new List<JiffDateTime>();
        for (JiffDateTime scan : series) {
            seen.add(scan);
            if (seen.size() == 2) {
                break;
            }
        }
        Assert.areEqual(
            new List<JiffDateTime>{ atHour(2023, 7, 16, 2), atHour(2023, 7, 16, 7) },
            seen
        );
        Assert.areEqual(atHour(2023, 7, 16, 12), series.next());
    }

    @IsTest
    static void endsWhenTheStepCounterItselfWouldOverflow() {
        // Only a zero period can get this far: Jiff counts steps in a 64 bit integer and ends
        // the series when that count can go no higher.
        JiffDateTime start = atHour(2024, 6, 19, 12);
        JiffDateTimeSeries lastStep = new JiffDateTimeSeries(
            start,
            new JiffSpan(),
            9223372036854775806L
        );
        Assert.areEqual(new List<JiffDateTime>{ start }, take(lastStep, 5));
        JiffDateTimeSeries exhausted = new JiffDateTimeSeries(
            start,
            new JiffSpan(),
            9223372036854775807L
        );
        Assert.isFalse(exhausted.hasNext());
    }

    @IsTest
    static void needsAStartAndAPeriod() {
        try {
            JiffDateTimeSeries series = new JiffDateTimeSeries(null, new JiffSpan().days(1));
            Assert.fail('expected a missing start to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the start of a datetime series must not be null', e.getMessage());
        }
        try {
            JiffDateTimeSeries series = JiffDateTime.MIN.series(null);
            Assert.fail('expected a missing period to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the period of a datetime series must not be null', e.getMessage());
        }
    }
}
