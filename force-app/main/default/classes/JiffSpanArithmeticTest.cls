@IsTest
private class JiffSpanArithmeticTest {
    private static final String DAY_NEEDS_RELATIVE = 'using unit \'day\' in a span or configuration requires that either a relative reference time be given or `JiffSpanRelativeTo.daysAre24Hours()` is used to indicate invariant 24-hour days, but neither were provided';
    private static final String WEEK_NEEDS_RELATIVE = 'using unit \'week\' in a span or configuration requires that either a relative reference time be given or `JiffSpanRelativeTo.daysAre24Hours()` is used to indicate invariant 24-hour days, but neither were provided';
    private static final String MONTH_NEEDS_RELATIVE = 'using unit \'month\' in a span or configuration requires that a relative reference time be given, but none was provided';
    private static final String YEAR_NEEDS_RELATIVE = 'using unit \'year\' in a span or configuration requires that a relative reference time be given, but none was provided';
    private static final String YEAR_NOT_24_HOURS = 'using unit \'year\' in span or configuration requires that a relative reference time be given (`JiffSpanRelativeTo.daysAre24Hours()` was given but this only permits using days and weeks without a relative reference time)';
    private static final String SIGNED_DURATION_RANGE = 'parameter \'signed duration seconds\' is not in the required range of -9223372036854775808..=9223372036854775807';
    private static final String YEAR_RANGE = 'parameter \'year\' is not in the required range of -9999..=9999';

    private static JiffSpan span(String text) {
        return JiffOracleSupport.toSpan(text);
    }

    private static String text(JiffSpan value) {
        return JiffOracleSupport.spanText(value);
    }

    private static JiffSpanRelativeTo onDate(Integer year, Integer month, Integer day) {
        return JiffSpanRelativeTo.fromDate(JiffDate.newInstance(year, month, day));
    }

    private static JiffSpanRelativeTo day24() {
        return JiffSpanRelativeTo.daysAre24Hours();
    }

    private static void assertFails(String expectedMessage, Exception e) {
        Assert.isInstanceOfType(e, JiffException.class, String.valueOf(e));
        Assert.areEqual(expectedMessage, e.getMessage());
    }

    // ---- vectors from Jiff -------------------------------------------------

    private static String tryAdd(
        JiffSpan a,
        Object other,
        JiffSpanRelativeTo relative,
        Boolean subtracting
    ) {
        try {
            JiffSpan result;
            if (other instanceof JiffSpan) {
                JiffSpan b = (JiffSpan) other;
                if (relative == null) {
                    result = subtracting ? a.subtract(b) : a.add(b);
                } else {
                    result = subtracting ? a.subtract(b, relative) : a.add(b, relative);
                }
            } else {
                JiffSignedDuration d = (JiffSignedDuration) other;
                if (relative == null) {
                    result = subtracting ? a.subtract(d) : a.add(d);
                } else {
                    result = subtracting ? a.subtract(d, relative) : a.add(d, relative);
                }
            }
            return text(result);
        } catch (JiffException e) {
            return JiffSpanVectorSupport.failure(e);
        }
    }

    private static String tryCompare(JiffSpan a, JiffSpan b, JiffSpanRelativeTo relative) {
        try {
            return String.valueOf(relative == null ? a.compare(b) : a.compare(b, relative));
        } catch (JiffException e) {
            return JiffSpanVectorSupport.failure(e);
        }
    }

    private static String tryToDuration(JiffSpan a, JiffSpanRelativeTo relative) {
        try {
            JiffSignedDuration d = relative == null ? a.toDuration() : a.toDuration(relative);
            return JiffOracleSupport.durationText(d);
        } catch (JiffException e) {
            return JiffSpanVectorSupport.failure(e);
        }
    }

    @IsTest
    static void addingAndSubtractingSpansAndDurationsAgreesWithJiff() {
        JiffSpanVectorSupport vectors = new JiffSpanVectorSupport();
        for (String row : JiffSpanArithmeticVectors.rows()) {
            List<String> f = JiffOracleSupport.fields(row);
            JiffSpan a = span(f.get(0));
            JiffSpanRelativeTo relative = JiffSpanVectorSupport.relative(f.get(1));
            JiffSpan b = span(f.get(2));
            JiffSignedDuration d = JiffOracleSupport.toDuration(f.get(3));
            vectors.check(f.get(4), tryAdd(a, b, relative, false), 'add span', row);
            vectors.check(f.get(5), tryAdd(a, b, relative, true), 'subtract span', row);
            vectors.check(f.get(6), tryAdd(a, d, relative, false), 'add duration', row);
            vectors.check(f.get(7), tryAdd(a, d, relative, true), 'subtract duration', row);
        }
        vectors.verify(1800);
    }

    @IsTest
    static void comparingAndConvertingToDurationsAgreesWithJiff() {
        JiffSpanVectorSupport vectors = new JiffSpanVectorSupport();
        for (String row : JiffSpanArithmeticVectors.rows()) {
            List<String> f = JiffOracleSupport.fields(row);
            JiffSpan a = span(f.get(0));
            JiffSpanRelativeTo relative = JiffSpanVectorSupport.relative(f.get(1));
            vectors.check(f.get(8), tryCompare(a, span(f.get(2)), relative), 'compare', row);
            vectors.check(f.get(9), tryToDuration(a, relative), 'toDuration', row);
        }
        vectors.verify(900);
    }

    // ---- add and subtract ------------------------------------------------

    @IsTest
    static void addingTimeSpansBalancesIntoTheBiggerUnit() {
        // From Jiff's documentation of `Span::checked_add` and its `test_checked_add`.
        Assert.areEqual(span('1h 30m'), span('1h').add(span('30m')));
        Assert.areEqual(span('4h 15m'), span('1h 30m').add(span('2h 45m')));
        Assert.areEqual(span('3h 1m'), span('2h 59m').add(span('2m')));
    }

    @IsTest
    static void addingDaysNeedsAReferenceOrTwentyFourHourDays() {
        Assert.areEqual(span('3d 1h'), span('2d 23h').add(span('2h'), day24()));
        try {
            span('2d 23h').add(span('2h'));
            Assert.fail('days without a reference must be rejected');
        } catch (Exception e) {
            assertFails(DAY_NEEDS_RELATIVE, e);
        }
    }

    @IsTest
    static void addingCalendarUnitsDependsOnWhereTheSpanStarts() {
        JiffSpan span1 = span('1mo 15d');
        JiffSpan span2 = span('15d');
        try {
            span1.add(span2);
            Assert.fail('months without a reference must be rejected');
        } catch (Exception e) {
            assertFails(MONTH_NEEDS_RELATIVE, e);
        }
        // March 1 plus 1 month is April 1, and a month from April 1 is 30 days...
        Assert.areEqual(span('2mo'), span1.add(span2, onDate(2008, 3, 1)));
        // ...but a month from May 1 is 31 days.
        Assert.areEqual(span('1mo 30d'), span1.add(span2, onDate(2008, 4, 1)));
    }

    @IsTest
    static void addingSpansRelativeToADateTimeBalancesEveryUnit() {
        // Jiff's `test_checked_add`.
        JiffSpan fifties = span('50y 50mo 50d 50h 50m 50s 500ms 500us 500ns');
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.fromDateTime(
            JiffDateTime.newInstance(1900, 1, 1, 0, 0, 0, 0)
        );
        Assert.areEqual(span('108y 7mo 12d 5h 41m 41s 1ms 1us'), fifties.add(fifties, relative));
        JiffSpan monthAndAHalf = span('1mo 15d');
        Assert.areEqual(
            span('3mo'),
            monthAndAHalf.add(
                monthAndAHalf,
                JiffSpanRelativeTo.fromDateTime(JiffDateTime.newInstance(2000, 2, 1, 0, 0, 0, 0))
            )
        );
        Assert.areEqual(
            span('2mo 30d'),
            monthAndAHalf.add(
                monthAndAHalf,
                JiffSpanRelativeTo.fromDateTime(JiffDateTime.newInstance(2000, 3, 1, 0, 0, 0, 0))
            )
        );
    }

    @IsTest
    static void addingSpansThatOverflowAUnitIsRejected() {
        try {
            span('19998y').add(span('1y'), onDate(2000, 1, 1));
            Assert.fail('19999 years must be rejected');
        } catch (Exception e) {
            assertFails('failed to add span to date: ' + YEAR_RANGE, e);
        }
        try {
            span('19998y').add(span('1y'));
            Assert.fail('years without a reference must be rejected');
        } catch (Exception e) {
            assertFails(YEAR_NEEDS_RELATIVE, e);
        }
    }

    @IsTest
    static void addingADurationKeepsTheSpansBiggestUnit() {
        Assert.areEqual(span('1h 30m'), span('1h').add(JiffSignedDuration.fromMins(30)));
        Assert.areEqual(span('5400s'), span('1s').add(JiffSignedDuration.fromSecs(5399L)));
        JiffSignedDuration thirtyDays = JiffSignedDuration.fromHours(30 * 24);
        try {
            span('1mo').add(thirtyDays);
            Assert.fail('a month without a reference must be rejected');
        } catch (Exception e) {
            assertFails(MONTH_NEEDS_RELATIVE, e);
        }
        // 30 days is one month from March 1 (April has 30 days)...
        Assert.areEqual(span('2mo'), span('1mo').add(thirtyDays, onDate(2024, 3, 1)));
        // ...but less than a month from April 1.
        Assert.areEqual(span('1mo 30d'), span('1mo').add(thirtyDays, onDate(2024, 4, 1)));
    }

    @IsTest
    static void subtractingIsAddingTheNegation() {
        Assert.areEqual(span('30m'), span('1h').subtract(span('30m')));
        Assert.areEqual(span('30m'), span('1h').subtract(JiffSignedDuration.fromMins(30)));
        Assert.areEqual(span('-1d -1h'), span('2h').subtract(span('1d 3h'), day24()));
        Assert.areEqual(
            span('-12h'),
            span('12h').subtract(JiffSignedDuration.fromHours(24), day24())
        );
        // 2024-01-31 plus 2 months is 2024-03-31; a month back is 2024-02-29, 29 days on.
        Assert.areEqual(span('29d'), span('2mo').subtract(span('1mo'), onDate(2024, 1, 31)));
    }

    @IsTest
    static void addingTheExtremeDurationsOverflows() {
        // Jiff's `overflow_i64_signed_duration`.
        List<JiffSpan> timeSpans = new List<JiffSpan>{
            span('1ns'),
            span('1us'),
            span('1ms'),
            span('1s'),
            span('1m'),
            span('1h')
        };
        for (JiffSpan one : timeSpans) {
            for (
                JiffSignedDuration extreme : new List<JiffSignedDuration>{
                    JiffSignedDuration.MAX,
                    JiffSignedDuration.MIN
                }
            ) {
                assertOverflows(one, extreme, null);
            }
        }
        for (JiffSpan one : new List<JiffSpan>{ span('1d'), span('1w') }) {
            assertOverflows(one, JiffSignedDuration.MAX, day24());
            assertOverflows(one, JiffSignedDuration.MIN, day24());
        }
    }

    private static void assertOverflows(
        JiffSpan one,
        JiffSignedDuration extreme,
        JiffSpanRelativeTo relative
    ) {
        try {
            one.add(extreme, relative);
            Assert.fail('adding ' + extreme + ' to ' + one + ' must overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().startsWith('parameter '), e.getMessage());
        }
        try {
            one.subtract(extreme, relative);
            Assert.fail('subtracting ' + extreme + ' from ' + one + ' must overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('parameter '), e.getMessage());
        }
    }

    @IsTest
    static void overflowingTheDurationIsReportedAsJiffDoes() {
        try {
            span('1s').add(JiffSignedDuration.MAX);
            Assert.fail('the sum overflows a signed duration');
        } catch (Exception e) {
            assertFails(SIGNED_DURATION_RANGE, e);
        }
        try {
            span('1s').subtract(JiffSignedDuration.MIN);
            Assert.fail('the minimum duration cannot be negated');
        } catch (Exception e) {
            assertFails('unsigned duration exceeds Jiff\'s limits: ' + SIGNED_DURATION_RANGE, e);
        }
        try {
            span('1s').subtract(JiffSignedDuration.MAX);
            Assert.fail('the difference overflows a span of seconds');
        } catch (Exception e) {
            assertFails(
                'parameter \'seconds\' is not in the required range of -631107417600..=631107417600',
                e
            );
        }
    }

    @IsTest
    static void maximalInvariantSpansDoNotOverflowWhenAdded() {
        // Jiff's `maximum_invariant_duration` and `minimum_invariant_duration`.
        JiffSpan biggest = new JiffSpan()
            .weeks(1043497L)
            .days(7304484L)
            .hours(175307616L)
            .minutes(10518456960L)
            .seconds(631107417600L)
            .milliseconds(631107417600000L)
            .microseconds(631107417600000000L)
            .nanoseconds(JiffMath.LONG_MAX);
        JiffSignedDuration expected = JiffSignedDuration.newInstance(
            1229715239L * 3600 + 47 * 60 + 16,
            854775807
        );
        Assert.areEqual(expected, biggest.toDuration(day24()));
        Assert.areEqual(expected.negate(), biggest.negate().toDuration(day24()));
        Assert.areEqual(
            JiffSignedDuration.newInstance(2459430479L * 3600 + 34 * 60 + 33, 709551614),
            biggest.toDuration(day24()).add(biggest.toDuration(day24()))
        );
    }

    @IsTest
    static void nullArgumentsAreRejected() {
        JiffSpan one = span('1h');
        List<String> messages = new List<String>();
        try {
            one.add((JiffSpan) null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.add((JiffSignedDuration) null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.subtract((JiffSpan) null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.subtract((JiffSignedDuration) null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.compare(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'the span to add must not be null',
                'the duration to add must not be null',
                'the span to subtract must not be null',
                'the duration to subtract must not be null',
                'the span to compare with must not be null'
            },
            messages
        );
    }

    // ---- compare ---------------------------------------------------------

    @IsTest
    static void comparingLooksAtLengthNotFields() {
        // From Jiff's documentation of `Span::compare`.
        Assert.areEqual(0, span('3h').compare(span('180m')));
        Assert.areNotEqual(span('3h'), span('180m'));
        Assert.areEqual(-1, span('-1s').compare(span('0')));
        Assert.areEqual(1, span('0').compare(span('-1s')));
    }

    @IsTest
    static void sortingByLengthOrdersSpansAsJiffDoes() {
        // Jiff's `test_compare`.
        JiffSpan span1 = span('79h 10m');
        JiffSpan span2 = span('79h 630s');
        JiffSpan span3 = span('78h 50m');
        Assert.areEqual(-1, span3.compare(span1));
        Assert.areEqual(-1, span1.compare(span2));
        Assert.areEqual(1, span2.compare(span3));

        JiffSpan days1 = span('79h 10m');
        JiffSpan days2 = span('3d 7h 630s');
        JiffSpan days3 = span('3d 6h 50m');
        // With 24 hour days: span3 < span1 < span2.
        Assert.areEqual(-1, days3.compare(days1, day24()));
        Assert.areEqual(-1, days1.compare(days2, day24()));
        // From 2020-11-01 in Los Angeles, whose first day is 25 hours long: span1 < span3 < span2.
        JiffSpanRelativeTo losAngeles = JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(2020, 11, 1).inTz('America/Los_Angeles')
        );
        Assert.areEqual(-1, days1.compare(days3, losAngeles));
        Assert.areEqual(-1, days3.compare(days2, losAngeles));
        Assert.areEqual(1, days2.compare(days1, losAngeles));
        // A civil reference date ignores the long day: span3 < span1 < span2.
        Assert.areEqual(-1, days3.compare(days1, onDate(2020, 11, 1)));
        Assert.areEqual(-1, days1.compare(days2, onDate(2020, 11, 1)));
    }

    @IsTest
    static void comparingCalendarUnitsNeedsAReference() {
        try {
            span('1d').compare(span('1h'));
            Assert.fail('days without a reference must be rejected');
        } catch (Exception e) {
            assertFails(DAY_NEEDS_RELATIVE, e);
        }
        try {
            span('1y').compare(span('1h'), day24());
            Assert.fail('years with 24 hour days must be rejected');
        } catch (Exception e) {
            assertFails(YEAR_NOT_24_HOURS, e);
        }
        Assert.areEqual(0, span('1mo').compare(span('29d'), onDate(2024, 2, 1)));
        Assert.areEqual(1, span('1mo').compare(span('29d'), onDate(2023, 1, 1)));
        try {
            span('1y').compare(span('1d'), onDate(9999, 6, 1));
            Assert.fail('a year past 9999 must be rejected');
        } catch (Exception e) {
            assertFails('failed to add span to date: ' + YEAR_RANGE, e);
        }
    }

    // ---- toDuration ------------------------------------------------------

    @IsTest
    static void aYearIsAsLongAsTheYearItStartsIn() {
        // From Jiff's documentation of `Span::to_duration`.
        Assert.areEqual(
            JiffSignedDuration.fromSecs(31622400L),
            span('1y').toDuration(onDate(2024, 1, 1))
        );
        Assert.areEqual(
            JiffSignedDuration.fromSecs(31536000L),
            span('1y').toDuration(onDate(2023, 1, 1))
        );
        Assert.areEqual(JiffSignedDuration.fromHours(192), span('1w 1d').toDuration(day24()));
        Assert.areEqual(
            JiffSignedDuration.fromHours(696),
            span('1mo').toDuration(onDate(2024, 2, 1))
        );
    }

    @IsTest
    static void aDayInATimeZoneIsAsLongAsThatDay() {
        JiffSpanRelativeTo springForward = JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(2024, 3, 10).inTz('America/New_York')
        );
        JiffSpanRelativeTo fallBack = JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(2024, 11, 3).inTz('America/New_York')
        );
        Assert.areEqual(JiffSignedDuration.fromHours(23), span('1d').toDuration(springForward));
        Assert.areEqual(JiffSignedDuration.fromHours(25), span('1d').toDuration(fallBack));
        Assert.areEqual(
            JiffSignedDuration.fromHours(24),
            span('1d').toDuration(onDate(2024, 3, 10))
        );
        // A null reference is the same as none.
        Assert.areEqual(JiffSignedDuration.fromMins(90), span('1h 30m').toDuration(null));
    }

    @IsTest
    static void aSpanOfHoursConvertsToADurationWithoutAReference() {
        // From Jiff's documentation of `TryFrom<Span> for SignedDuration`.
        JiffSpan maximal = new JiffSpan()
            .hours(175307616L)
            .minutes(10518456960L)
            .seconds(631107417600L)
            .milliseconds(631107417600000L)
            .microseconds(631107417600000000L)
            .nanoseconds(JiffMath.LONG_MAX);
        Assert.areEqual(
            JiffSignedDuration.newInstance(3164760460036L, 854775807),
            maximal.toDuration()
        );
        Assert.areEqual(JiffSignedDuration.fromMins(-90), span('-1h -30m').toDuration());
    }

    @IsTest
    static void daysAndWeeksDoNotConvertWithoutAReference() {
        Map<String, String> causes = new Map<String, String>{
            '1d' => DAY_NEEDS_RELATIVE,
            '1w' => WEEK_NEEDS_RELATIVE,
            '1mo' => MONTH_NEEDS_RELATIVE,
            '1y 1h' => YEAR_NEEDS_RELATIVE
        };
        for (String text : causes.keySet()) {
            try {
                span(text).toDuration();
                Assert.fail(text + ' must be rejected');
            } catch (Exception e) {
                assertFails(
                    'failed to convert span to duration without relative datetime (must use `JiffSpan.toDuration(JiffSpanRelativeTo)` instead): ' +
                    causes.get(text),
                    e
                );
            }
        }
    }

    @IsTest
    static void toDurationNamesTheReferenceThatFailed() {
        try {
            span('1y').toDuration(day24());
            Assert.fail('years with 24 hour days must be rejected');
        } catch (Exception e) {
            assertFails(
                'could not compute normalized relative span when all days are assumed to be 24 hours: ' +
                YEAR_NOT_24_HOURS,
                e
            );
        }
        try {
            span('1y').toDuration(onDate(9999, 6, 1));
            Assert.fail('a year past 9999 must be rejected');
        } catch (Exception e) {
            assertFails(
                'could not compute normalized relative span from civil datetime: failed to add span to date: ' +
                YEAR_RANGE,
                e
            );
        }
        try {
            span('1y')
                .toDuration(
                    JiffSpanRelativeTo.fromZonedDateTime(
                        JiffDate.newInstance(9999, 6, 1).inTz('UTC')
                    )
                );
            Assert.fail('a year past 9999 must be rejected');
        } catch (Exception e) {
            assertFails(
                'could not compute normalized relative span from zoned datetime: failed to add span to datetime from zoned datetime: failed to add span to date: ' +
                YEAR_RANGE,
                e
            );
        }
    }
}
