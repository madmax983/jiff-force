@IsTest
private class JiffDateArithmeticTest {
    private static final String YEAR_RANGE = 'parameter \'year\' is not in the required range of -9999..=9999';
    private static final String EPOCH_DAY_RANGE = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';
    private static final String MONTHS_RANGE = 'parameter \'months\' is not in the required range of -239976..=239976';
    private static final String DURATION_DAYS =
        'number of days derived from duration exceed\'s Jiff\'s datetime limits: ' +
        EPOCH_DAY_RANGE;
    private static final String UNSIGNED_DURATION =
        'unsigned duration exceeds Jiff\'s limits: parameter \'signed duration seconds\' ' +
        'is not in the required range of -9223372036854775808..=9223372036854775807';

    private static JiffDate ymd(Integer year, Integer month, Integer day) {
        return JiffDate.newInstance(year, month, day);
    }

    /** Parses the `year,month,day` form used by the vector tables below. */
    private static JiffDate parseYmd(String text) {
        List<String> parts = text.split(',');
        return ymd(
            Integer.valueOf(parts.get(0)),
            Integer.valueOf(parts.get(1)),
            Integer.valueOf(parts.get(2))
        );
    }

    /** The full Jiff error message that a vector's `ERR:` code stands for. */
    private static String messageFor(String code) {
        if (code.equals('ERR:year')) {
            return YEAR_RANGE;
        }
        if (code.equals('ERR:epoch')) {
            return EPOCH_DAY_RANGE;
        }
        if (code.equals('ERR:months')) {
            return MONTHS_RANGE;
        }
        if (code.equals('ERR:duration')) {
            return DURATION_DAYS;
        }
        if (code.equals('ERR:unsigned')) {
            return UNSIGNED_DURATION;
        }
        Assert.fail('unknown error code in vector: ' + code);
        return null;
    }

    private static String describe(JiffDate start, String operation, Object operand) {
        return start + ' ' + operation + ' ' + operand;
    }

    private static void assertAdd(JiffDate start, JiffSpan span, String expected) {
        String what = describe(start, '+', span);
        try {
            JiffDate actual = start.add(span);
            Assert.isFalse(expected.startsWith('ERR:'), what + ' should fail but gave ' + actual);
            Assert.areEqual(parseYmd(expected), actual, what);
        } catch (JiffException e) {
            Assert.isTrue(expected.startsWith('ERR:'), what + ' failed: ' + e.getMessage());
            Assert.areEqual(messageFor(expected), e.getMessage(), what);
        }
    }

    private static void assertSubtract(JiffDate start, JiffSpan span, String expected) {
        String what = describe(start, '-', span);
        try {
            JiffDate actual = start.subtract(span);
            Assert.isFalse(expected.startsWith('ERR:'), what + ' should fail but gave ' + actual);
            Assert.areEqual(parseYmd(expected), actual, what);
        } catch (JiffException e) {
            Assert.isTrue(expected.startsWith('ERR:'), what + ' failed: ' + e.getMessage());
            Assert.areEqual(messageFor(expected), e.getMessage(), what);
        }
    }

    private static void assertAddFails(JiffDate start, JiffSpan span, String expected) {
        try {
            JiffDate actual = start.add(span);
            Assert.fail(describe(start, '+', span) + ' should fail but gave ' + actual);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertUntil(JiffDate d1, JiffDate d2, JiffUnit largest, String expected) {
        String what = d1 + ' until ' + d2 + ' in ' + largest;
        try {
            JiffSpan actual = d1.until(d2, largest);
            Assert.isFalse(expected.startsWith('ERR:'), what + ' should fail but gave ' + actual);
            Assert.areEqual(expected, actual.toString(), what);
            // `since` is the same span with the sign flipped.
            Assert.areEqual(actual.negate(), d1.since(d2, largest), what);
            // Adding the span to the start always arrives at the other date.
            Assert.areEqual(d2, d1.add(actual), what);
        } catch (JiffException e) {
            Assert.isTrue(expected.startsWith('ERR:'), what + ' failed: ' + e.getMessage());
            Assert.areEqual(messageFor(expected), e.getMessage(), what);
        }
    }

    // ---- add(JiffSpan) ---------------------------------------------------

    @IsTest
    static void addingMonthsClampsToTheEndOfTheMonth() {
        JiffDate d = ymd(2024, 3, 31);
        Assert.areEqual(ymd(2024, 4, 30), d.add(new JiffSpan().months(1)));
        // Adding two months gives May 31, not May 30.
        Assert.areEqual(ymd(2024, 5, 31), d.add(new JiffSpan().months(2)));
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 1, 31).add(new JiffSpan().months(1)));
        Assert.areEqual(ymd(2023, 2, 28), ymd(2023, 1, 31).add(new JiffSpan().months(1)));
    }

    @IsTest
    static void addingYearsClampsALeapDay() {
        JiffDate leapDay = ymd(2024, 2, 29);
        Assert.areEqual(ymd(2025, 2, 28), leapDay.add(new JiffSpan().years(1)));
        Assert.areEqual(ymd(2028, 2, 29), leapDay.add(new JiffSpan().years(4)));
        Assert.areEqual(ymd(2023, 2, 28), leapDay.subtract(new JiffSpan().years(1)));
    }

    @IsTest
    static void timeUnitsCountOnlyAsWholeDays() {
        JiffDate d = ymd(2024, 3, 31);
        // Any time in the span that does not exceed a day is ignored.
        Assert.areEqual(d, d.add(new JiffSpan().hours(23)));
        // But if the time exceeds a day, that is accounted for.
        Assert.areEqual(ymd(2024, 4, 1), d.add(new JiffSpan().hours(28)));
        Assert.areEqual(d, d.add(new JiffSpan().hours(23).minutes(59).seconds(59)));
        Assert.areEqual(ymd(2024, 4, 1), d.add(new JiffSpan().hours(23).minutes(60)));
        Assert.areEqual(ymd(2024, 4, 1), d.add(new JiffSpan().milliseconds(86400000L)));
        Assert.areEqual(
            ymd(2024, 4, 1),
            d.add(new JiffSpan().seconds(86399).nanoseconds(1000000000L))
        );
        Assert.areEqual(d, d.subtract(new JiffSpan().hours(23)));
        Assert.areEqual(ymd(2024, 3, 30), d.subtract(new JiffSpan().hours(24)));
        Assert.areEqual(ymd(2024, 3, 30), d.subtract(new JiffSpan().hours(47)));
    }

    @IsTest
    static void addingANegativeSpanMovesBackward() {
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 3, 31).add(new JiffSpan().months(-1)));
        Assert.areEqual(ymd(2022, 12, 15), ymd(2024, 1, 15).add(new JiffSpan().months(-13)));
        Assert.areEqual(ymd(2024, 2, 18), ymd(2024, 2, 25).add(new JiffSpan().weeks(-1)));
    }

    @IsTest
    static void addingWeeksAndDaysCountsOffTheCalendar() {
        Assert.areEqual(ymd(2024, 3, 3), ymd(2024, 2, 25).add(new JiffSpan().weeks(1)));
        Assert.areEqual(ymd(2024, 3, 1), ymd(2024, 2, 28).add(new JiffSpan().days(2)));
        Assert.areEqual(ymd(2023, 3, 1), ymd(2023, 2, 27).add(new JiffSpan().days(2)));
        Assert.areEqual(ymd(2024, 1, 1), ymd(2023, 12, 30).add(new JiffSpan().days(2)));
        Assert.areEqual(ymd(2024, 7, 2), ymd(2024, 7, 3).add(new JiffSpan().days(-1)));
        Assert.areEqual(ymd(2024, 7, 4), ymd(2024, 7, 3).add(new JiffSpan().days(1)));
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 3, 1).add(new JiffSpan().days(-1)));
        Assert.areEqual(ymd(2022, 12, 31), ymd(2023, 1, 1).add(new JiffSpan().days(-1)));
        // The whole supported range, in one step each way.
        Assert.areEqual(JiffDate.MAX, JiffDate.MIN.add(new JiffSpan().days(7304483L)));
        Assert.areEqual(JiffDate.MIN, JiffDate.MAX.add(new JiffSpan().days(-7304483L)));
    }

    @IsTest
    static void unitsAreAppliedFromLargestToSmallest() {
        // The month is added first and clamped to April 30th, and only then the day.
        JiffDate d = ymd(2023, 3, 31);
        Assert.areEqual(ymd(2023, 5, 1), d.add(new JiffSpan().months(1).days(1)));
        JiffSpan everything = new JiffSpan().years(1).months(1).weeks(1).days(1).hours(25);
        Assert.areEqual(ymd(2025, 5, 9), ymd(2024, 3, 31).add(everything));
        Assert.areEqual(ymd(2023, 2, 19), ymd(2024, 3, 31).subtract(everything));
    }

    @IsTest
    static void addingAZeroSpanReturnsTheSameDate() {
        Assert.areEqual(JiffDate.MAX, JiffDate.MAX.add(new JiffSpan()));
        Assert.areEqual(JiffDate.MIN, JiffDate.MIN.subtract(new JiffSpan()));
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 2, 29).add(new JiffSpan().days(0)));
    }

    @IsTest
    static void addingMonthsCarriesIntoTheYear() {
        // Jiff's `test_month_add_overflowing`, observed through January 15th and December 15th.
        JiffDate january = ymd(2024, 1, 15);
        Assert.areEqual(ymd(2024, 1, 15), january.add(new JiffSpan().months(0)));
        Assert.areEqual(ymd(2024, 12, 15), january.add(new JiffSpan().months(11)));
        Assert.areEqual(ymd(2025, 1, 15), january.add(new JiffSpan().months(12)));
        Assert.areEqual(ymd(2025, 2, 15), january.add(new JiffSpan().months(13)));
        Assert.areEqual(ymd(2025, 9, 15), january.add(new JiffSpan().months(20)));
        Assert.areEqual(ymd(2023, 12, 15), january.add(new JiffSpan().months(-1)));
        Assert.areEqual(ymd(2023, 11, 15), january.add(new JiffSpan().months(-2)));
        Assert.areEqual(ymd(2023, 1, 15), january.add(new JiffSpan().months(-12)));
        Assert.areEqual(ymd(2022, 12, 15), january.add(new JiffSpan().months(-13)));
        // The largest month count a span can hold is 19,998 years' worth.
        Assert.areEqual(ymd(9999, 12, 15), ymd(-9999, 12, 15).add(new JiffSpan().months(239976L)));
    }

    @IsTest
    static void addingBeyondTheSupportedRangeFails() {
        JiffDate d = ymd(2024, 3, 31);
        assertAddFails(d, new JiffSpan().years(9000), YEAR_RANGE);
        assertAddFails(d, new JiffSpan().years(-19000), YEAR_RANGE);
        // One day past either end is reported against the year, like `tomorrow`.
        assertAddFails(JiffDate.MAX, new JiffSpan().days(1), YEAR_RANGE);
        assertAddFails(JiffDate.MIN, new JiffSpan().days(-1), YEAR_RANGE);
        assertAddFails(JiffDate.MAX, new JiffSpan().days(2), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MIN, new JiffSpan().days(-2), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MIN, new JiffSpan().days(7304484L), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MAX, new JiffSpan().weeks(1), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MAX, new JiffSpan().hours(24), EPOCH_DAY_RANGE);
    }

    @IsTest
    static void theDaysCarriedByTimeUnitsMustThemselvesBeAnEpochDay() {
        // A quirk inherited from Jiff: hours worth more days than the latest epoch day are
        // rejected even when the date they would lead to is within range.
        Assert.areEqual(ymd(-1970, 12, 31), JiffDate.MIN.add(new JiffSpan().hours(24 * 2932896L)));
        assertAddFails(JiffDate.MIN, new JiffSpan().hours(24 * 2932897L), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MIN, new JiffSpan().hours(24 * 3000000L), EPOCH_DAY_RANGE);
        assertAddFails(JiffDate.MIN, new JiffSpan().hours(175307616L), EPOCH_DAY_RANGE);
        Assert.areEqual(ymd(-1970, 12, 31), JiffDate.MAX.add(new JiffSpan().hours(-24 * 4371587L)));
        assertAddFails(JiffDate.MAX, new JiffSpan().hours(-24 * 4371588L), EPOCH_DAY_RANGE);
    }

    @IsTest
    static void addAndSubtractMatchJiffAcrossManyDatesAndSpans() {
        // Produced by Jiff 1.0.0. Each row is
        //   start | years,months,weeks,days,hours | start.checked_add(span) | start.checked_sub(span)
        // where a result is `year,month,day` or the code of the error Jiff reported.
        List<String> rows = new List<String>{
            '2024,3,31|0,1,0,0,0|2024,4,30|2024,2,29',
            '2024,3,31|0,-1,0,0,0|2024,2,29|2024,4,30',
            '2024,2,29|1,0,0,0,0|2025,2,28|2023,2,28',
            '2024,2,29|-1,0,0,0,0|2023,2,28|2025,2,28',
            '2024,2,29|4,0,0,0,0|2028,2,29|2020,2,29',
            '2023,3,31|0,1,0,1,0|2023,5,1|2023,2,27',
            '2024,3,31|1,1,1,1,25|2025,5,9|2023,2,19',
            '2024,3,31|-1,-1,-1,-1,-25|2023,2,19|2025,5,9',
            '2024,1,15|0,13,0,0,0|2025,2,15|2022,12,15',
            '2024,1,15|0,-13,0,0,0|2022,12,15|2025,2,15',
            '-9999,1,1|19998,11,0,30,0|9999,12,31|ERR:year',
            '-9999,1,1|19998,11,0,31,0|ERR:epoch|ERR:year',
            '-9999,1,1|19998,12,0,0,0|ERR:year|ERR:year',
            '-9999,1,1|0,239976,0,0,0|9999,1,1|ERR:year',
            '9999,12,31|0,-239976,0,0,0|-9999,12,31|ERR:year',
            '9999,12,31|-19998,-11,0,-30,0|-9999,1,1|ERR:year',
            '-9999,1,1|0,0,1043497,4,0|9999,12,31|ERR:epoch',
            '-9999,1,1|0,0,1043497,5,0|ERR:epoch|ERR:epoch',
            '9999,12,31|0,0,-1043497,-4,0|-9999,1,1|ERR:epoch',
            '9999,12,31|0,0,0,0,24|ERR:epoch|9999,12,30',
            '9999,12,31|0,0,0,0,23|9999,12,31|9999,12,31',
            '-9999,1,1|0,0,0,0,-24|ERR:epoch|-9999,1,2',
            '-9999,1,1|0,0,0,0,-23|-9999,1,1|-9999,1,1',
            '9999,12,31|0,0,1,0,0|ERR:epoch|9999,12,24',
            '-9999,1,1|0,0,0,0,70389504|-1970,12,31|ERR:epoch',
            '-9999,1,1|0,0,0,0,70389528|ERR:epoch|ERR:epoch',
            '9999,12,31|0,0,0,0,-104918088|-1970,12,31|ERR:epoch',
            '9999,12,31|0,0,0,0,-104918112|ERR:epoch|ERR:epoch',
            '2004,3,31|0,11,0,0,0|2005,2,28|2003,4,30',
            '4,1,30|0,30,0,0,0|6,7,30|1,7,30',
            '1990,1,30|2,6,0,0,0|1992,7,30|1987,7,30',
            '1997,3,31|2,24,0,0,0|2001,3,31|1993,3,31',
            '1997,12,30|2,0,27,0,0|2000,7,6|1995,6,24',
            '3399,9,30|0,0,0,0,0|3399,9,30|3399,9,30',
            '2028,6,30|0,-17,0,0,0|2027,1,30|2029,11,30',
            '2,8,31|0,-22,0,0,0|0,10,31|4,6,30',
            '2028,11,29|-1,-6,0,0,0|2027,5,29|2030,5,29',
            '1990,4,30|0,0,43,393,0|1992,3,24|1988,6,5',
            '2008,6,30|0,21,0,169,62|2010,9,17|2006,4,12',
            '2002,5,21|-1,0,0,0,0|2001,5,21|2003,5,21',
            '2001,11,30|0,-14,-36,0,0|2000,1,22|2003,10,9',
            '2021,9,30|0,0,0,0,0|2021,9,30|2021,9,30',
            '8388,7,31|0,2,0,0,0|8388,9,30|8388,5,31',
            '2022,8,31|0,0,0,0,0|2022,8,31|2022,8,31',
            '1990,10,28|0,-5,0,-105,0|1990,2,12|1991,7,11',
            '2008,6,24|0,0,0,0,0|2008,6,24|2008,6,24',
            '1992,4,29|0,0,0,0,0|1992,4,29|1992,4,29',
            '-2,1,28|0,24,0,0,70|0,1,30|-4,1,26',
            '2627,6,30|0,0,0,-359,0|2626,7,6|2628,6,23',
            '-9401,12,31|0,0,0,-168,0|-9401,7,16|-9400,6,17',
            '2014,7,29|0,29,0,0,0|2016,12,29|2012,2,29',
            '2019,3,31|0,-29,0,0,0|2016,10,31|2021,8,31',
            '2013,9,30|2,0,0,132,0|2016,2,9|2011,5,21',
            '2009,2,28|0,0,-21,0,0|2008,10,4|2009,7,25',
            '1993,12,31|2,0,0,0,54|1996,1,2|1991,12,29',
            '1993,12,31|0,-5,0,-100,0|1993,4,22|1994,9,8',
            '2000,9,29|0,0,32,0,0|2001,5,11|2000,2,18',
            '2026,11,23|0,0,-31,0,0|2026,4,20|2027,6,28',
            '1,7,31|-2,-21,-36,-255,0|-4,6,11|6,9,19',
            '2004,6,12|0,0,0,41,0|2004,7,23|2004,5,2',
            '2001,11,25|0,5,0,0,40|2002,4,26|2001,6,24',
            '1991,12,31|0,0,0,261,92|1992,9,20|1991,4,11',
            '1999,7,31|0,0,0,-314,0|1998,9,20|2000,6,9',
            '2010,10,30|3,17,0,0,0|2015,3,30|2006,5,30',
            '1996,8,29|0,0,0,0,0|1996,8,29|1996,8,29',
            '2017,9,10|-3,0,0,0,0|2014,9,10|2020,9,10',
            '2028,1,7|0,0,0,-121,0|2027,9,8|2028,5,7',
            '2009,4,30|0,0,0,0,-99|2009,4,26|2009,5,4',
            '2013,9,30|0,0,25,96,0|2014,6,28|2013,1,2',
            '2017,5,14|0,30,49,291,67|2021,8,11|2013,2,16',
            '1997,4,29|-2,-5,0,-301,0|1994,2,1|2000,7,26',
            '2030,3,31|0,10,0,0,0|2031,1,31|2029,5,31',
            '1996,2,29|0,19,0,0,0|1997,9,29|1994,7,29',
            '1991,10,30|0,-28,0,-123,0|1989,2,27|1994,7,1',
            '2016,9,18|0,0,42,0,20|2017,7,9|2015,11,29',
            '2017,3,28|0,0,0,-292,0|2016,6,9|2018,1,14',
            '2007,12,30|0,0,0,280,89|2008,10,8|2007,3,22',
            '2017,4,29|0,0,0,0,4|2017,4,29|2017,4,29',
            '2024,4,2|2,10,51,0,0|2028,1,25|2020,6,10',
            '-2,8,30|0,22,0,0,52|0,7,2|-4,10,28',
            '2007,4,2|0,0,-2,-275,0|2006,6,17|2008,1,16',
            '2007,3,31|0,0,0,-68,-50|2007,1,20|2007,6,9',
            '2030,10,4|0,0,0,381,0|2031,10,20|2029,9,18',
            '-8379,11,29|0,2,54,154,15|-8377,7,15|-8380,4,15',
            '2023,6,30|-2,-29,0,0,0|2019,1,30|2027,11,30',
            '2024,6,30|-2,0,0,0,-21|2022,6,30|2026,6,30',
            '1993,4,19|0,10,52,0,4|1995,2,18|1991,6,21',
            '2025,4,30|1,21,0,2,2|2028,2,1|2022,7,28'
        };
        for (String row : rows) {
            List<String> columns = row.split('\\|');
            JiffDate start = parseYmd(columns.get(0));
            List<String> units = columns.get(1).split(',');
            JiffSpan span = new JiffSpan()
                .years(Long.valueOf(units.get(0)))
                .months(Long.valueOf(units.get(1)))
                .weeks(Long.valueOf(units.get(2)))
                .days(Long.valueOf(units.get(3)))
                .hours(Long.valueOf(units.get(4)));
            assertAdd(start, span, columns.get(2));
            assertSubtract(start, span, columns.get(3));
        }
    }

    @IsTest
    static void addingThenSubtractingDaysAndWeeksIsReversible() {
        List<JiffSpan> spans = new List<JiffSpan>{
            new JiffSpan().days(1),
            new JiffSpan().days(-1),
            new JiffSpan().days(40),
            new JiffSpan().weeks(3).days(2),
            new JiffSpan().weeks(-60),
            new JiffSpan().days(365).hours(49),
            new JiffSpan().hours(-100)
        };
        for (Long epochDay = -4370000L; epochDay <= 2930000L; epochDay += 99991) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            for (JiffSpan span : spans) {
                Assert.areEqual(d, d.add(span).subtract(span), describe(d, '+-', span));
                Assert.areEqual(d, d.subtract(span).add(span), describe(d, '-+', span));
            }
        }
    }

    // ---- add(JiffSignedDuration) ------------------------------------------

    @IsTest
    static void addingADurationCountsWholeDays() {
        JiffDate d = ymd(2024, 2, 29);
        JiffSignedDuration oneDay = JiffSignedDuration.fromHours(24);
        Assert.areEqual(ymd(2024, 3, 1), d.add(oneDay));
        Assert.areEqual(ymd(2024, 2, 28), d.add(oneDay.negate()));
        // Any leftover time is truncated: only whole days from the duration are considered.
        Assert.areEqual(ymd(2024, 3, 1), d.add(JiffSignedDuration.fromHours(47)));
        Assert.areEqual(ymd(2024, 2, 28), d.add(JiffSignedDuration.fromHours(-47)));
        Assert.areEqual(d, d.add(JiffSignedDuration.fromHours(23)));
        Assert.areEqual(d, d.add(JiffSignedDuration.ZERO));
    }

    @IsTest
    static void subtractingADurationIsAddingItsNegation() {
        JiffDate d = ymd(2024, 2, 29);
        Assert.areEqual(ymd(2024, 2, 28), d.subtract(JiffSignedDuration.fromHours(24)));
        Assert.areEqual(ymd(2024, 2, 27), d.subtract(JiffSignedDuration.fromHours(48)));
        Assert.areEqual(ymd(2024, 3, 1), d.subtract(JiffSignedDuration.fromHours(-24)));
    }

    @IsTest
    static void durationArithmeticMatchesJiffIncludingItsErrors() {
        // Produced by Jiff 1.0.0. Each row is
        //   start | secs,nanos | checked_add | checked_sub | saturating_add | saturating_sub
        List<String> rows = new List<String>{
            '2024,2,29|86400,0|2024,3,1|2024,2,28|2024,3,1|2024,2,28',
            '2024,2,29|-86400,0|2024,2,28|2024,3,1|2024,2,28|2024,3,1',
            '2024,2,29|86399,999999999|2024,2,29|2024,2,29|2024,2,29|2024,2,29',
            '2024,2,29|-86399,-999999999|2024,2,29|2024,2,29|2024,2,29|2024,2,29',
            '2024,2,29|169200,0|2024,3,1|2024,2,28|2024,3,1|2024,2,28',
            '2024,2,29|-169200,0|2024,2,28|2024,3,1|2024,2,28|2024,3,1',
            '2024,2,29|0,0|2024,2,29|2024,2,29|2024,2,29|2024,2,29',
            '2024,2,29|31622400,0|2025,3,1|2023,2,28|2025,3,1|2023,2,28',
            '2024,2,29|-31622400,0|2023,2,28|2025,3,1|2023,2,28|2025,3,1',
            '9999,12,31|86400,0|ERR:year|9999,12,30|9999,12,31|9999,12,30',
            '9999,12,31|86399,0|9999,12,31|9999,12,31|9999,12,31|9999,12,31',
            '9999,12,31|172800,0|ERR:epoch|9999,12,29|9999,12,31|9999,12,29',
            '-9999,1,1|-86400,0|ERR:year|-9999,1,2|-9999,1,1|-9999,1,2',
            '-9999,1,1|-86399,0|-9999,1,1|-9999,1,1|-9999,1,1|-9999,1,1',
            '-9999,1,1|-172800,0|ERR:epoch|-9999,1,3|-9999,1,1|-9999,1,3',
            '-9999,1,1|253402214400,0|-1970,12,31|ERR:epoch|-1970,12,31|-9999,1,1',
            '-9999,1,1|253402300800,0|ERR:duration|ERR:epoch|9999,12,31|-9999,1,1',
            '9999,12,31|-377705116800,0|-1970,12,31|ERR:duration|-1970,12,31|9999,12,31',
            '9999,12,31|-377705203200,0|ERR:duration|ERR:duration|-9999,1,1|9999,12,31',
            '2024,2,29|9223372036854775807,999999999|ERR:duration|ERR:duration|9999,12,31|-9999,1,1',
            '2024,2,29|-9223372036854775808,-999999999|ERR:duration|ERR:unsigned|-9999,1,1|9999,12,31',
            '2024,2,29|-9223372036854775808,0|ERR:duration|ERR:unsigned|-9999,1,1|9999,12,31',
            '2024,2,29|-9223372036854775807,0|ERR:duration|ERR:duration|-9999,1,1|9999,12,31'
        };
        for (String row : rows) {
            List<String> columns = row.split('\\|');
            JiffDate start = parseYmd(columns.get(0));
            List<String> parts = columns.get(1).split(',');
            JiffSignedDuration duration = JiffSignedDuration.newInstance(
                Long.valueOf(parts.get(0)),
                Integer.valueOf(parts.get(1))
            );
            String what = start + ' with ' + columns.get(1);
            try {
                JiffDate sum = start.add(duration);
                Assert.areEqual(parseYmd(columns.get(2)), sum, what);
            } catch (JiffException e) {
                Assert.isTrue(columns.get(2).startsWith('ERR:'), what + ': ' + e.getMessage());
                Assert.areEqual(messageFor(columns.get(2)), e.getMessage(), what);
            }
            try {
                JiffDate difference = start.subtract(duration);
                Assert.areEqual(parseYmd(columns.get(3)), difference, what);
            } catch (JiffException e) {
                Assert.isTrue(columns.get(3).startsWith('ERR:'), what + ': ' + e.getMessage());
                Assert.areEqual(messageFor(columns.get(3)), e.getMessage(), what);
            }
            Assert.areEqual(parseYmd(columns.get(4)), start.saturatingAdd(duration), what);
            Assert.areEqual(parseYmd(columns.get(5)), start.saturatingSubtract(duration), what);
        }
    }

    // ---- saturating arithmetic ---------------------------------------------

    @IsTest
    static void saturatingAddStopsAtTheEndsOfTheRange() {
        JiffDate d = ymd(2024, 3, 31);
        Assert.areEqual(JiffDate.MAX, d.saturatingAdd(new JiffSpan().years(9000)));
        Assert.areEqual(JiffDate.MIN, d.saturatingAdd(new JiffSpan().years(-19000)));
        Assert.areEqual(JiffDate.MAX, d.saturatingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(JiffDate.MIN, d.saturatingAdd(JiffSignedDuration.MIN));
        // In range, it is ordinary addition.
        Assert.areEqual(ymd(2024, 4, 30), d.saturatingAdd(new JiffSpan().months(1)));
        Assert.areEqual(ymd(2024, 4, 1), d.saturatingAdd(JiffSignedDuration.fromHours(25)));
        Assert.areEqual(d, d.saturatingAdd(new JiffSpan()));
    }

    @IsTest
    static void saturatingSubtractStopsAtTheEndsOfTheRange() {
        JiffDate d = ymd(2024, 3, 31);
        Assert.areEqual(JiffDate.MIN, d.saturatingSubtract(new JiffSpan().years(19000)));
        Assert.areEqual(JiffDate.MAX, d.saturatingSubtract(new JiffSpan().years(-9000)));
        Assert.areEqual(JiffDate.MIN, d.saturatingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(JiffDate.MAX, d.saturatingSubtract(JiffSignedDuration.MIN));
        // In range, it is ordinary subtraction.
        Assert.areEqual(
            ymd(-6976, 2, 29),
            ymd(2024, 2, 29).saturatingSubtract(new JiffSpan().years(9000))
        );
        Assert.areEqual(ymd(2024, 3, 30), d.saturatingSubtract(new JiffSpan().days(1)));
        Assert.areEqual(ymd(2024, 3, 30), d.saturatingSubtract(JiffSignedDuration.fromHours(25)));
    }

    @IsTest
    static void saturationFollowsTheErrorNotTheTrueResult() {
        // Where Jiff's addition fails although the true result is in range (see the test of
        // days carried by time units), the saturating form saturates as well.
        JiffSpan manyHours = new JiffSpan().hours(24 * 3000000L);
        Assert.areEqual(JiffDate.MAX, JiffDate.MIN.saturatingAdd(manyHours));
        Assert.areEqual(
            JiffDate.MAX,
            ymd(2024, 3, 31).saturatingAdd(new JiffSpan().hours(175307616L))
        );
        Assert.areEqual(
            JiffDate.MIN,
            ymd(2024, 3, 31).saturatingSubtract(new JiffSpan().hours(175307616L))
        );
    }

    // ---- until and since ---------------------------------------------------

    @IsTest
    static void untilReportsDaysByDefault() {
        JiffDate earlier = ymd(2006, 8, 24);
        JiffDate later = ymd(2019, 1, 31);
        Assert.areEqual(new JiffSpan().days(4543), earlier.until(later));
        // Flipping the dates is fine, but the span is negative.
        Assert.areEqual(new JiffSpan().days(-4543), later.until(earlier));
        Assert.areEqual(new JiffSpan().days(4543), later.since(earlier));
        Assert.areEqual(new JiffSpan().days(-4543), earlier.since(later));
        Assert.areEqual(new JiffSpan().days(7), ymd(2024, 3, 3).since(ymd(2024, 2, 25)));
        Assert.areEqual(new JiffSpan(), earlier.until(earlier));
        Assert.areEqual(new JiffSpan(), earlier.since(earlier));
        // A null unit means the default too.
        Assert.areEqual(new JiffSpan().days(4543), earlier.until(later, null));
    }

    @IsTest
    static void untilCanUseLargerUnits() {
        JiffDate d1 = ymd(1995, 12, 7);
        JiffDate d2 = ymd(2019, 1, 31);
        Assert.areEqual('P8456D', d1.until(d2).toString());
        Assert.areEqual('P8456D', d1.until(d2, JiffUnit.DAY).toString());
        Assert.areEqual('P1208W', d1.until(d2, JiffUnit.WEEK).toString());
        Assert.areEqual('P277M24D', d1.until(d2, JiffUnit.MONTH).toString());
        Assert.areEqual('P23Y1M24D', d1.until(d2, JiffUnit.YEAR).toString());
        Assert.areEqual(
            new JiffSpan().years(1).months(3),
            ymd(2024, 1, 1).until(ymd(2025, 4, 1), JiffUnit.YEAR)
        );
        Assert.areEqual(
            new JiffSpan().months(2).days(7),
            ymd(2024, 5, 3).since(ymd(2024, 2, 25), JiffUnit.YEAR)
        );
    }

    @IsTest
    static void unitsLargerThanDaysAreNotReversible() {
        JiffDate d1 = ymd(2024, 3, 2);
        JiffDate d2 = ymd(2024, 5, 1);
        JiffSpan span = d1.until(d2, JiffUnit.MONTH);
        Assert.areEqual(new JiffSpan().months(1).days(29), span);
        // Not the same as the original date.
        Assert.areEqual(ymd(2024, 3, 3), d2.subtract(span));
        // But in the default configuration, days are always the biggest unit and
        // reversibility is guaranteed.
        span = d1.until(d2);
        Assert.areEqual(new JiffSpan().days(60), span);
        Assert.areEqual(d1, d2.subtract(span));
    }

    @IsTest
    static void sinceInYears() {
        JiffDate d1 = ymd(2023, 4, 15);
        JiffDate d2 = ymd(2019, 2, 22);
        Assert.areEqual(new JiffSpan().years(4).months(1).days(21), d1.since(d2, JiffUnit.YEAR));
        Assert.areEqual(new JiffSpan().years(-4).months(-1).days(-24), d2.since(d1, JiffUnit.YEAR));

        d1 = ymd(2023, 2, 22);
        d2 = ymd(2019, 4, 15);
        Assert.areEqual(new JiffSpan().years(3).months(10).days(7), d1.since(d2, JiffUnit.YEAR));
        Assert.areEqual(new JiffSpan().years(-3).months(-10).days(-7), d2.since(d1, JiffUnit.YEAR));

        d1 = ymd(9999, 12, 31);
        d2 = ymd(-9999, 1, 1);
        Assert.areEqual(
            new JiffSpan().years(19998).months(11).days(30),
            d1.since(d2, JiffUnit.YEAR)
        );
        Assert.areEqual(
            new JiffSpan().years(-19998).months(-11).days(-30),
            d2.since(d1, JiffUnit.YEAR)
        );
    }

    @IsTest
    static void sinceInMonths() {
        JiffDate d1 = ymd(2024, 7, 24);
        JiffDate d2 = ymd(2024, 2, 22);
        Assert.areEqual(new JiffSpan().months(5).days(2), d1.since(d2, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().months(-5).days(-2), d2.since(d1, JiffUnit.MONTH));
        Assert.areEqual(d2, d1.subtract(new JiffSpan().months(5).days(2)));
        Assert.areEqual(d1, d2.subtract(new JiffSpan().months(-5).days(-2)));

        d1 = ymd(2024, 7, 15);
        d2 = ymd(2024, 2, 22);
        Assert.areEqual(new JiffSpan().months(4).days(22), d1.since(d2, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().months(-4).days(-23), d2.since(d1, JiffUnit.MONTH));
        Assert.areEqual(d2, d1.subtract(new JiffSpan().months(4).days(22)));
        Assert.areEqual(d1, d2.subtract(new JiffSpan().months(-4).days(-23)));

        d1 = ymd(2023, 4, 15);
        d2 = ymd(2023, 2, 22);
        Assert.areEqual(new JiffSpan().months(1).days(21), d1.since(d2, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().months(-1).days(-24), d2.since(d1, JiffUnit.MONTH));
        Assert.areEqual(d2, d1.subtract(new JiffSpan().months(1).days(21)));
        Assert.areEqual(d1, d2.subtract(new JiffSpan().months(-1).days(-24)));

        d1 = ymd(2023, 4, 15);
        d2 = ymd(2019, 2, 22);
        Assert.areEqual(new JiffSpan().months(49).days(21), d1.since(d2, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().months(-49).days(-24), d2.since(d1, JiffUnit.MONTH));
    }

    @IsTest
    static void sinceInWeeksAndDays() {
        JiffDate d1 = ymd(2024, 7, 15);
        JiffDate d2 = ymd(2024, 6, 22);
        Assert.areEqual(new JiffSpan().weeks(3).days(2), d1.since(d2, JiffUnit.WEEK));
        Assert.areEqual(new JiffSpan().weeks(-3).days(-2), d2.since(d1, JiffUnit.WEEK));

        d2 = ymd(2024, 2, 22);
        Assert.areEqual(new JiffSpan().days(144), d1.since(d2, JiffUnit.DAY));
        Assert.areEqual(new JiffSpan().days(-144), d2.since(d1, JiffUnit.DAY));

        // Ref: https://github.com/tc39/proposal-temporal/issues/2893
        Assert.areEqual(
            new JiffSpan().weeks(139),
            ymd(2019, 1, 8).until(ymd(2021, 9, 7), JiffUnit.WEEK)
        );
    }

    @IsTest
    static void untilMeasuresMonthsOfDifferentLengths() {
        JiffDate jan1 = ymd(2020, 1, 1);
        JiffDate feb1 = ymd(2020, 2, 1);
        JiffDate mar1 = ymd(2020, 3, 1);
        Assert.areEqual(new JiffSpan().days(31), jan1.until(feb1));
        Assert.areEqual(new JiffSpan().months(1), jan1.until(feb1, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().days(29), feb1.until(mar1));
        Assert.areEqual(new JiffSpan().months(1), feb1.until(mar1, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().days(60), jan1.until(mar1));
        Assert.areEqual(new JiffSpan().months(2), jan1.until(mar1, JiffUnit.MONTH));
    }

    @IsTest
    static void sinceAndUntilAreNotMirrorImages() {
        // Temporal.PlainDate.from("2020-04-30").since("2020-02-29", {largestUnit: "months"})
        //   => P2M
        // Temporal.PlainDate.from("2020-02-29").until("2020-04-30", {largestUnit: "months"})
        //   => P2M1D
        JiffDate d1 = ymd(2020, 4, 30);
        JiffDate d2 = ymd(2020, 2, 29);
        Assert.areEqual(new JiffSpan().months(2), d1.since(d2, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().months(2).days(1), d2.until(d1, JiffUnit.MONTH));
    }

    @IsTest
    static void untilDoesNotBalanceDaysIntoAMonth() {
        // These match Temporal. See https://github.com/tc39/proposal-temporal/issues/2535
        Assert.areEqual(
            new JiffSpan().months(10).days(30),
            ymd(2023, 5, 31).until(ymd(2024, 4, 30), JiffUnit.MONTH)
        );
        Assert.areEqual(
            new JiffSpan().days(30),
            ymd(2023, 5, 31).until(ymd(2023, 6, 30), JiffUnit.MONTH)
        );
    }

    @IsTest
    static void untilWorksInTheFirstAndLastSupportedYears() {
        Assert.areEqual(
            new JiffSpan().months(-10).days(-30),
            ymd(-9999, 12, 1).until(ymd(-9999, 1, 2), JiffUnit.MONTH)
        );
        Assert.areEqual(
            new JiffSpan().months(10).days(29),
            ymd(9999, 1, 2).until(ymd(9999, 12, 1), JiffUnit.MONTH)
        );
        Assert.areEqual(new JiffSpan().days(7304483L), JiffDate.MIN.until(JiffDate.MAX));
        Assert.areEqual(new JiffSpan().days(-7304483L), JiffDate.MAX.until(JiffDate.MIN));
    }

    @IsTest
    static void theWholeRangeDoesNotFitInASpanOfMonths() {
        try {
            JiffSpan span = JiffDate.MIN.until(JiffDate.MAX, JiffUnit.MONTH);
            Assert.fail('expected the difference to overflow, but got ' + span);
        } catch (JiffException e) {
            Assert.areEqual(MONTHS_RANGE, e.getMessage());
        }
        try {
            JiffSpan span = JiffDate.MIN.since(JiffDate.MAX, JiffUnit.MONTH);
            Assert.fail('expected the difference to overflow, but got ' + span);
        } catch (JiffException e) {
            Assert.areEqual(MONTHS_RANGE, e.getMessage());
        }
    }

    @IsTest
    static void unitsSmallerThanADayAreRejected() {
        JiffDate d1 = ymd(2024, 2, 29);
        JiffDate d2 = ymd(2024, 3, 1);
        try {
            d1.until(d2, JiffUnit.HOUR);
            Assert.fail('expected hours to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                '\'hour\' not allowed as a date unit for rounding span',
                e.getMessage()
            );
        }
        try {
            d1.since(d2, JiffUnit.NANOSECOND);
            Assert.fail('expected nanoseconds to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                '\'nanosecond\' not allowed as a date unit for rounding span',
                e.getMessage()
            );
        }
        // The unit is checked even when the dates are equal.
        try {
            d1.until(d1, JiffUnit.SECOND);
            Assert.fail('expected seconds to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('\'second\' not allowed'), e.getMessage());
        }
    }

    @IsTest
    static void untilMatchesJiffAcrossManyPairsOfDates() {
        // Produced by Jiff 1.0.0. Each row is
        //   d1 | d2 | d1.until(d2) with the largest unit set to day | week | month | year
        // where a result is the span as Jiff prints it or the code of the error it reported.
        List<String> rows = new List<String>{
            '2024,1,31|2024,3,1|P30D|P4W2D|P1M1D|P1M1D',
            '2024,3,31|2024,2,29|-P31D|-P4W3D|-P1M|-P1M',
            '2020,2,29|2021,2,28|P365D|P52W1D|P11M30D|P11M30D',
            '2021,2,28|2020,2,29|-P365D|-P52W1D|-P11M28D|-P11M28D',
            '2019,12,31|2021,1,1|P367D|P52W3D|P12M1D|P1Y1D',
            '2021,1,31|2019,12,1|-P427D|-P61W|-P13M30D|-P1Y1M30D',
            '2022,11,30|2024,2,29|P456D|P65W1D|P14M30D|P1Y2M30D',
            '2024,2,29|2022,11,30|-P456D|-P65W1D|-P14M29D|-P1Y2M29D',
            '-9999,1,1|9999,12,31|P7304483D|P1043497W4D|ERR:months|P19998Y11M30D',
            '9999,12,31|-9999,1,1|-P7304483D|-P1043497W4D|ERR:months|-P19998Y11M30D',
            '-1,12,31|1,1,1|P367D|P52W3D|P12M1D|P1Y1D',
            '0,2,29|-4,2,29|-P1461D|-P208W5D|-P48M|-P4Y',
            '-4207,4,29|-3,8,28|P1535600D|P219371W3D|P50451M30D|P4204Y3M30D',
            '-1205,11,5|2010,5,11|P1174077D|P167725W2D|P38574M6D|P3214Y6M6D',
            '9266,7,30|2003,10,31|-P2652664D|-P378952W|-P87152M30D|-P7262Y8M30D',
            '2008,4,30|2752,9,10|P271873D|P38839W|P8932M11D|P744Y4M11D',
            '2020,8,30|2028,12,31|P3045D|P435W|P100M1D|P8Y4M1D',
            '2010,7,31|2019,9,30|P3348D|P478W2D|P109M30D|P9Y1M30D',
            '2029,10,30|2011,6,8|-P6719D|-P959W6D|-P220M22D|-P18Y4M22D',
            '2010,12,29|2004,12,10|-P2210D|-P315W5D|-P72M19D|-P6Y19D',
            '2013,2,28|2008,2,29|-P1826D|-P260W6D|-P59M28D|-P4Y11M28D',
            '1993,10,3|1998,4,29|P1669D|P238W3D|P54M26D|P4Y6M26D',
            '2004,10,30|1993,12,28|-P3959D|-P565W4D|-P130M2D|-P10Y10M2D',
            '-5032,8,16|2004,6,29|P2569798D|P367114W|P84430M13D|P7035Y10M13D',
            '2019,10,6|2,10,30|-P736670D|-P105238W4D|-P24203M7D|-P2016Y11M7D',
            '2006,1,31|2005,5,31|-P245D|-P35W|-P8M|-P8M',
            '7384,2,29|2011,2,27|-P1962450D|-P280350W|-P64476M1D|-P5373Y1D',
            '1994,10,31|-4898,6,30|-P2517375D|-P359625W|-P82708M|-P6892Y4M',
            '2002,5,30|-1541,7,29|-P1293994D|-P184856W2D|-P42514M1D|-P3542Y10M1D',
            '2014,3,30|2018,5,24|P1516D|P216W4D|P49M24D|P4Y1M24D',
            '2003,9,29|2027,5,30|P8644D|P1234W6D|P284M1D|P23Y8M1D',
            '5,5,30|2003,5,28|P729752D|P104250W2D|P23975M28D|P1997Y11M28D',
            '1999,6,3|2019,8,30|P7393D|P1056W1D|P242M27D|P20Y2M27D',
            '2026,1,31|2018,12,31|-P2588D|-P369W5D|-P85M|-P7Y1M',
            '1994,7,31|2017,6,29|P8369D|P1195W4D|P274M29D|P22Y10M29D',
            '-3553,11,17|2025,2,27|P2037060D|P291008W4D|P66927M10D|P5577Y3M10D',
            '1992,10,29|1991,2,27|-P610D|-P87W1D|-P20M1D|-P1Y8M1D',
            '1990,10,31|-2,3,29|-P727779D|-P103968W3D|-P23911M2D|-P1992Y7M2D',
            '1994,6,29|2019,7,30|P9162D|P1308W6D|P301M1D|P25Y1M1D',
            '2023,4,30|2012,5,31|-P3986D|-P569W3D|-P130M30D|-P10Y10M30D',
            '2002,11,30|-1836,4,30|-P1402014D|-P200287W5D|-P46063M|-P3838Y7M',
            '2007,4,29|-5,6,29|-P734807D|-P104972W3D|-P24142M|-P2011Y10M',
            '2015,1,30|2012,9,29|-P853D|-P121W6D|-P28M1D|-P2Y4M1D',
            '-5,6,29|2016,1,31|P738006D|P105429W3D|P24247M2D|P2020Y7M2D',
            '1991,4,30|2009,11,29|P6788D|P969W5D|P222M30D|P18Y6M30D',
            '2029,6,28|2017,12,31|-P4197D|-P599W4D|-P137M28D|-P11Y5M28D',
            '1993,10,28|1992,6,26|-P489D|-P69W6D|-P16M2D|-P1Y4M2D',
            '2021,3,19|2005,4,28|-P5804D|-P829W1D|-P190M21D|-P15Y10M21D',
            '2002,2,27|2030,2,28|P10228D|P1461W1D|P336M1D|P28Y1D',
            '4462,8,16|2002,1,30|-P898695D|-P128385W|-P29526M17D|-P2460Y6M17D',
            '2016,4,26|1997,10,31|-P6752D|-P964W4D|-P221M26D|-P18Y5M26D',
            '1995,8,31|-3473,7,31|-P1997177D|-P285311W|-P65617M|-P5468Y1M',
            '2024,12,30|2030,5,30|P1977D|P282W3D|P65M|P5Y5M',
            '2029,3,29|5389,11,24|P1227455D|P175350W5D|P40327M26D|P3360Y7M26D',
            '2014,2,27|2001,3,30|-P4717D|-P673W6D|-P154M28D|-P12Y10M28D',
            '2009,9,29|1999,4,30|-P3805D|-P543W4D|-P124M29D|-P10Y4M29D',
            '-3239,10,28|2002,1,31|P1913966D|P273423W5D|P62883M3D|P5240Y3M3D',
            '2012,7,28|2010,8,30|-P698D|-P99W5D|-P22M29D|-P1Y10M29D',
            '2021,8,29|2019,6,30|-P791D|-P113W|-P25M29D|-P2Y1M29D',
            '6529,2,28|2005,1,29|-P1652387D|-P236055W2D|-P54288M30D|-P4524Y30D'
        };
        for (String row : rows) {
            List<String> columns = row.split('\\|');
            JiffDate d1 = parseYmd(columns.get(0));
            JiffDate d2 = parseYmd(columns.get(1));
            assertUntil(d1, d2, JiffUnit.DAY, columns.get(2));
            assertUntil(d1, d2, JiffUnit.WEEK, columns.get(3));
            assertUntil(d1, d2, JiffUnit.MONTH, columns.get(4));
            assertUntil(d1, d2, JiffUnit.YEAR, columns.get(5));
            Assert.areEqual(columns.get(2), d1.until(d2).toString());
        }
    }

    @IsTest
    static void aDifferenceInDaysAlwaysLeadsBackToTheStart() {
        // Jiff's `prop_since_then_add` and `prop_until_then_sub`.
        List<JiffDate> dates = new List<JiffDate>{ JiffDate.MIN, JiffDate.MAX, JiffDate.ZERO };
        for (Long epochDay = -4371587L; epochDay <= 2932896L; epochDay += 333331) {
            dates.add(JiffDate.fromEpochDay(epochDay));
        }
        for (JiffDate d1 : dates) {
            for (JiffDate d2 : dates) {
                Assert.areEqual(d1, d2.add(d1.since(d2)));
                Assert.areEqual(d1, d2.subtract(d1.until(d2)));
            }
        }
    }

    // ---- durationUntil and durationSince -----------------------------------

    @IsTest
    static void measuresTheExactDurationBetweenDates() {
        JiffDate earlier = ymd(2006, 8, 24);
        JiffDate later = ymd(2019, 1, 31);
        Assert.areEqual(JiffSignedDuration.fromHours(4543 * 24), earlier.durationUntil(later));
        Assert.areEqual(JiffSignedDuration.fromHours(4543 * 24), later.durationSince(earlier));
        Assert.areEqual(JiffSignedDuration.fromHours(-4543 * 24), later.durationUntil(earlier));
        Assert.areEqual(JiffSignedDuration.fromHours(-4543 * 24), earlier.durationSince(later));
        Assert.areEqual(
            JiffSignedDuration.fromHours(456 * 24),
            ymd(2024, 1, 1).durationUntil(ymd(2025, 4, 1))
        );
        Assert.areEqual(
            JiffSignedDuration.fromSecs(31 * 24 * 60 * 60),
            ymd(2024, 7, 1).durationUntil(ymd(2024, 8, 1))
        );
        Assert.isTrue(ymd(2024, 8, 1).durationUntil(ymd(2024, 7, 1)).isNegative());
        Assert.areEqual(JiffSignedDuration.ZERO, earlier.durationUntil(earlier));
    }

    @IsTest
    static void theDurationOfTheWholeRangeFits() {
        Assert.areEqual(
            JiffSignedDuration.fromSecs(631107331200L),
            JiffDate.MIN.durationUntil(JiffDate.MAX)
        );
        Assert.areEqual(
            JiffSignedDuration.fromSecs(-631107331200L),
            JiffDate.MAX.durationUntil(JiffDate.MIN)
        );
        Assert.areEqual(
            JiffSignedDuration.fromHours(175307592L),
            JiffDate.MAX.durationSince(JiffDate.MIN)
        );
    }
}
