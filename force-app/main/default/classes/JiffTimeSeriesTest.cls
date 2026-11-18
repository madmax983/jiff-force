/**
 * Expected values are the examples in the doc comment of `jiff::civil::Time::series` and, for
 * the remaining cases, the output of Jiff 1.0.0 itself.
 */
@IsTest
private class JiffTimeSeriesTest {
    private static JiffTime t(Integer h, Integer m, Integer s, Integer ns) {
        return JiffTime.newInstance(h, m, s, ns);
    }

    private static List<JiffTime> drain(JiffTimeSeries series) {
        List<JiffTime> times = new List<JiffTime>();
        while (series.hasNext()) {
            times.add(series.next());
        }
        return times;
    }

    @IsTest
    static void visitsEveryThirdHourOfTheDay() {
        List<JiffTime> everyThirdHour = new List<JiffTime>();
        for (JiffTime each : JiffTime.MIN.series(new JiffSpan().hours(3))) {
            everyThirdHour.add(each);
        }
        Assert.areEqual(
            new List<JiffTime>{
                t(0, 0, 0, 0),
                t(3, 0, 0, 0),
                t(6, 0, 0, 0),
                t(9, 0, 0, 0),
                t(12, 0, 0, 0),
                t(15, 0, 0, 0),
                t(18, 0, 0, 0),
                t(21, 0, 0, 0)
            },
            everyThirdHour
        );
    }

    @IsTest
    static void aNegativePeriodStepsBackwards() {
        Assert.areEqual(
            new List<JiffTime>{ t(23, 0, 0, 0), t(16, 30, 0, 0), t(10, 0, 0, 0), t(3, 30, 0, 0) },
            drain(t(23, 0, 0, 0).series(new JiffSpan().hours(6).minutes(30).negate()))
        );
        Assert.areEqual(
            new List<JiffTime>{ t(5, 0, 0, 0), t(2, 59, 59, 0), t(0, 59, 58, 0) },
            drain(t(5, 0, 0, 0).series(new JiffSpan().hours(2).seconds(1).negate()))
        );
    }

    @IsTest
    static void stopsBeforeTheStepThatWouldLeaveTheDay() {
        Assert.areEqual(
            new List<JiffTime>{ t(5, 0, 0, 0), t(12, 30, 0, 0), t(20, 0, 0, 0) },
            drain(t(5, 0, 0, 0).series(new JiffSpan().hours(7).minutes(30)))
        );
        Assert.areEqual(
            new List<JiffTime>{ JiffTime.MAX },
            drain(JiffTime.MAX.series(new JiffSpan().nanoseconds(1)))
        );
        Assert.areEqual(
            new List<JiffTime>{ JiffTime.MIN },
            drain(JiffTime.MIN.series(new JiffSpan().nanoseconds(-1)))
        );
        Assert.areEqual(
            new List<JiffTime>{ JiffTime.MIN },
            drain(JiffTime.MIN.series(new JiffSpan().hours(24)))
        );
    }

    @IsTest
    static void aPeriodLargerThanHoursYieldsOnlyTheStart() {
        Assert.areEqual(
            new List<JiffTime>{ JiffTime.MIN },
            drain(JiffTime.MIN.series(new JiffSpan().days(1)))
        );
    }

    @IsTest
    static void stopsWhenThePeriodCanNoLongerBeMultiplied() {
        // Twice this period is more hours than a span can hold.
        Assert.areEqual(
            new List<JiffTime>{ JiffTime.MIN },
            drain(JiffTime.MIN.series(new JiffSpan().hours(100000000L)))
        );
    }

    @IsTest
    static void aZeroPeriodRepeatsTheStartForever() {
        JiffTimeSeries series = t(5, 0, 0, 0).series(new JiffSpan());
        for (Integer i = 0; i < 100; i++) {
            Assert.isTrue(series.hasNext());
            Assert.areEqual(t(5, 0, 0, 0), series.next());
        }
    }

    @IsTest
    static void endsWhenTheStepCounterItselfWouldOverflow() {
        // Only reachable with a zero period, after 2^63 - 1 elements: Jiff counts its steps in
        // a 64 bit integer and ends the series rather than let the counter overflow.
        JiffTime start = t(5, 0, 0, 0);
        JiffTimeSeries lastStep = new JiffTimeSeries(start, new JiffSpan(), 9223372036854775806L);
        Assert.areEqual(start, lastStep.next());
        Assert.isFalse(lastStep.hasNext());
        JiffTimeSeries exhausted = new JiffTimeSeries(start, new JiffSpan(), 9223372036854775807L);
        Assert.isFalse(exhausted.hasNext());
    }

    @IsTest
    static void staysEndedOnceItHasEnded() {
        JiffTimeSeries series = t(22, 0, 0, 0).series(new JiffSpan().hours(1));
        Assert.areEqual(t(22, 0, 0, 0), series.next());
        Assert.areEqual(t(23, 0, 0, 0), series.next());
        Assert.isFalse(series.hasNext());
        Assert.isFalse(series.hasNext());
        try {
            series.next();
            Assert.fail('expected an ended series to refuse to give another time');
        } catch (JiffException e) {
            Assert.areEqual('the time series has no more elements', e.getMessage());
        }
        Assert.isFalse(series.hasNext());
    }

    @IsTest
    static void hasNextDoesNotConsumeAnything() {
        JiffTimeSeries series = t(22, 0, 0, 0).series(new JiffSpan().hours(1));
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(t(22, 0, 0, 0), series.next());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(t(23, 0, 0, 0), series.next());
    }

    @IsTest
    static void aLoopContinuesFromWhereTheSeriesIs() {
        JiffTimeSeries series = JiffTime.MIN.series(new JiffSpan().hours(8));
        Assert.areEqual(t(0, 0, 0, 0), series.next());
        List<JiffTime> rest = new List<JiffTime>();
        for (JiffTime each : series) {
            rest.add(each);
        }
        Assert.areEqual(new List<JiffTime>{ t(8, 0, 0, 0), t(16, 0, 0, 0) }, rest);
        // The series is a cursor, so there is nothing left for a second loop.
        for (JiffTime each : series) {
            Assert.fail('expected the series to have ended, but it gave ' + each);
        }
        Assert.isFalse(series.iterator().hasNext());
    }

    @IsTest
    static void canBeConstructedDirectly() {
        Assert.areEqual(
            new List<JiffTime>{ t(11, 0, 0, 0), t(23, 0, 0, 0) },
            drain(new JiffTimeSeries(t(11, 0, 0, 0), new JiffSpan().hours(12)))
        );
    }
}
