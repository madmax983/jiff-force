@IsTest
private class JiffDateSeriesTest {
    private static JiffDate ymd(Integer year, Integer month, Integer day) {
        return JiffDate.newInstance(year, month, day);
    }

    /** Collects at most `count` dates from `series`. */
    private static List<JiffDate> take(JiffDateSeries series, Integer count) {
        List<JiffDate> dates = new List<JiffDate>();
        while (dates.size() < count && series.hasNext()) {
            dates.add(series.next());
        }
        return dates;
    }

    @IsTest
    static void halloweenFallsOnTheseWeekdaysInThe2020s() {
        List<JiffWeekday> expected = new List<JiffWeekday>{
            JiffWeekday.SATURDAY,
            JiffWeekday.SUNDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.THURSDAY,
            JiffWeekday.FRIDAY,
            JiffWeekday.SATURDAY,
            JiffWeekday.SUNDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.WEDNESDAY
        };
        List<JiffDate> halloweens = take(ymd(2020, 10, 31).series(new JiffSpan().years(1)), 10);
        Assert.areEqual(10, halloweens.size());
        for (Integer i = 0; i < 10; i++) {
            Assert.areEqual(ymd(2020 + i, 10, 31), halloweens.get(i));
            Assert.areEqual(expected.get(i), halloweens.get(i).weekday());
        }
    }

    @IsTest
    static void worksInAForLoopWithItsOwnExit() {
        // "I mow the lawn about every week and a half from the beginning of May to the end of
        // October. About how many times will I mow the lawn in 2024?"
        JiffDate finish = ymd(2024, 10, 31);
        Integer mows = 0;
        for (JiffDate day : ymd(2024, 5, 1).series(new JiffSpan().weeks(1).days(3).hours(12))) {
            if (day.isAfter(finish)) {
                break;
            }
            mows++;
        }
        Assert.areEqual(18, mows);
    }

    @IsTest
    static void aPeriodShorterThanADayRepeatsDates() {
        Assert.areEqual(
            new List<JiffDate>{
                ymd(2024, 3, 11),
                ymd(2024, 3, 11),
                ymd(2024, 3, 12),
                ymd(2024, 3, 12),
                ymd(2024, 3, 13),
                ymd(2024, 3, 14),
                ymd(2024, 3, 14)
            },
            take(ymd(2024, 3, 11).series(new JiffSpan().hours(15)), 7)
        );
    }

    @IsTest
    static void aNegativePeriodWalksBackward() {
        // "When did the most recent Friday the 13th occur?"
        JiffDate found = null;
        for (JiffDate day : ymd(2024, 3, 13).series(new JiffSpan().months(-1))) {
            if (day.weekday() == JiffWeekday.FRIDAY) {
                found = day;
                break;
            }
        }
        Assert.areEqual(ymd(2023, 10, 13), found);
        Assert.areEqual(
            new List<JiffDate>{
                ymd(2024, 3, 13),
                ymd(2024, 2, 13),
                ymd(2024, 1, 13),
                ymd(2023, 12, 13)
            },
            take(ymd(2024, 3, 13).series(new JiffSpan().months(-1)), 4)
        );
    }

    @IsTest
    static void eachDateIsComputedFromTheStart() {
        // Stepping a month at a time from the previous result would stick at the 29th.
        Assert.areEqual(
            new List<JiffDate>{
                ymd(2024, 1, 31),
                ymd(2024, 2, 29),
                ymd(2024, 3, 31),
                ymd(2024, 4, 30),
                ymd(2024, 5, 31),
                ymd(2024, 6, 30)
            },
            take(ymd(2024, 1, 31).series(new JiffSpan().months(1)), 6)
        );
    }

    @IsTest
    static void endsWhenTheNextDateWouldLeaveTheSupportedRange() {
        Assert.areEqual(
            new List<JiffDate>{ ymd(9999, 12, 29), ymd(9999, 12, 30), ymd(9999, 12, 31) },
            take(ymd(9999, 12, 29).series(new JiffSpan().days(1)), 100)
        );
        Assert.areEqual(
            new List<JiffDate>{ ymd(9999, 10, 31), ymd(9999, 11, 30), ymd(9999, 12, 31) },
            take(ymd(9999, 10, 31).series(new JiffSpan().months(1)), 100)
        );
        Assert.areEqual(
            new List<JiffDate>{ JiffDate.MIN },
            take(JiffDate.MIN.series(new JiffSpan().days(-1)), 100)
        );
        Assert.areEqual(
            new List<JiffDate>{ ymd(-9999, 1, 1), ymd(-4999, 1, 1), ymd(1, 1, 1), ymd(5001, 1, 1) },
            take(JiffDate.MIN.series(new JiffSpan().years(5000)), 100)
        );
    }

    @IsTest
    static void endsWhenTheMultipliedPeriodNoLongerFitsInASpan() {
        // Twice 10,000 years is more than a span can hold, so only the start is produced.
        Assert.areEqual(
            new List<JiffDate>{ ymd(2024, 1, 1) },
            take(ymd(2024, 1, 1).series(new JiffSpan().years(10000)), 100)
        );
    }

    @IsTest
    static void staysEndedOnceItHasEnded() {
        JiffDateSeries series = ymd(9999, 12, 30).series(new JiffSpan().days(1));
        Assert.isTrue(series.hasNext());
        Assert.areEqual(ymd(9999, 12, 30), series.next());
        Assert.areEqual(ymd(9999, 12, 31), series.next());
        Assert.isFalse(series.hasNext());
        Assert.isFalse(series.hasNext());
        for (Integer attempt = 0; attempt < 2; attempt++) {
            try {
                JiffDate unexpected = series.next();
                Assert.fail('expected the ended series to refuse, but it gave ' + unexpected);
            } catch (JiffException e) {
                Assert.areEqual('the date series has no more elements', e.getMessage());
            }
        }
        Assert.isFalse(series.hasNext());
    }

    @IsTest
    static void hasNextDoesNotAdvanceTheSeries() {
        JiffDateSeries series = ymd(2024, 2, 25).series(new JiffSpan().weeks(1));
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(ymd(2024, 2, 25), series.next());
        Assert.isTrue(series.hasNext());
        Assert.isTrue(series.hasNext());
        Assert.areEqual(ymd(2024, 3, 3), series.next());
        // And next() works without asking first.
        Assert.areEqual(ymd(2024, 3, 10), series.next());
        Assert.areEqual(ymd(2024, 3, 17), series.next());
    }

    @IsTest
    static void aZeroPeriodRepeatsTheStartForever() {
        JiffDateSeries series = ymd(2024, 6, 19).series(new JiffSpan());
        for (Integer i = 0; i < 50; i++) {
            Assert.isTrue(series.hasNext());
            Assert.areEqual(ymd(2024, 6, 19), series.next());
        }
    }

    @IsTest
    static void aLoopContinuesFromWhereTheSeriesIs() {
        JiffDateSeries series = ymd(2024, 2, 25).series(new JiffSpan().weeks(1));
        Assert.areEqual(ymd(2024, 2, 25), series.next());
        // The series is its own iterator.
        Iterator<JiffDate> cursor = series.iterator();
        Assert.areEqual(ymd(2024, 3, 3), cursor.next());
        List<JiffDate> seen = new List<JiffDate>();
        for (JiffDate day : series) {
            seen.add(day);
            if (seen.size() == 2) {
                break;
            }
        }
        Assert.areEqual(new List<JiffDate>{ ymd(2024, 3, 10), ymd(2024, 3, 17) }, seen);
        Assert.areEqual(ymd(2024, 3, 24), series.next());
    }

    @IsTest
    static void endsWhenTheStepCounterItselfWouldOverflow() {
        // Only a zero period can get this far: Jiff counts steps in a 64 bit integer and ends
        // the series when that count can go no higher.
        JiffDate start = ymd(2024, 6, 19);
        JiffDateSeries lastStep = new JiffDateSeries(start, new JiffSpan(), 9223372036854775806L);
        Assert.areEqual(new List<JiffDate>{ start }, take(lastStep, 5));
        JiffDateSeries exhausted = new JiffDateSeries(start, new JiffSpan(), 9223372036854775807L);
        Assert.isFalse(exhausted.hasNext());
    }

    @IsTest
    static void listsTheWeeksOfAnIsoWeekYear() {
        // The example from Jiff's documentation of `ISOWeekDate`: a weekly series started on
        // the first day of an ISO week year visits the Monday of each of its weeks.
        JiffIsoWeekDate first = JiffIsoWeekDate.newInstance(2024, 1, JiffWeekday.MONDAY);
        Integer weeks = 0;
        for (JiffDate monday : first.toDate().series(new JiffSpan().weeks(1))) {
            JiffIsoWeekDate start = monday.toIsoWeekDate();
            if (start.year() != 2024) {
                break;
            }
            weeks++;
            Assert.areEqual(weeks, start.week());
            Assert.areEqual(JiffWeekday.MONDAY, start.weekday());
            Assert.areEqual(monday.add(new JiffSpan().days(6)), start.lastOfWeek().toDate());
        }
        Assert.areEqual(52, weeks);
    }

    @IsTest
    static void needsAStartAndAPeriod() {
        try {
            JiffDateSeries series = new JiffDateSeries(null, new JiffSpan().days(1));
            Assert.fail('expected a missing start to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the start of a date series must not be null', e.getMessage());
        }
        try {
            JiffDateSeries series = JiffDate.ZERO.series(null);
            Assert.fail('expected a missing period to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the period of a date series must not be null', e.getMessage());
        }
    }
}
