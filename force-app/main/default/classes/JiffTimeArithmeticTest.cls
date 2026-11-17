/**
 * Adding to and subtracting from a `JiffTime`: wrapping, checked, saturating, and the internal
 * variant that carries into days.
 *
 * Expected values are the examples in the doc comments of `jiff::civil::Time`, the assertions
 * in the test modules of `jiff/src/civil/time.rs` and `jiff-core/src/civil/time.rs`, and, for
 * the remaining edge cases and all error messages, the output of Jiff 1.0.0 itself.
 */
@IsTest
private class JiffTimeArithmeticTest {
    private static final String OVERFLOWED = 'adding duration to time overflowed';
    private static final String OUTSIDE_THE_DAY = 'parameter \'nanoseconds (in one civil day)\' is not in the required range of 0..=86399999999999';
    private static final String TOO_MANY_DAYS = 'parameter \'days\' is not in the required range of -7304484..=7304484';
    private static final Long LONG_MAX = 9223372036854775807L;
    private static final Long LONG_MIN = -9223372036854775807L - 1L;

    private static JiffTime t(Integer h, Integer m, Integer s, Integer ns) {
        return JiffTime.newInstance(h, m, s, ns);
    }

    private static JiffSpan ns(Long value) {
        return new JiffSpan().nanoseconds(value);
    }

    /** A span with every unit from hours down at its maximum. */
    private static JiffSpan largestTimeSpan() {
        return new JiffSpan()
            .hours(175307616L)
            .minutes(10518456960L)
            .seconds(631107417600L)
            .milliseconds(631107417600000L)
            .microseconds(631107417600000000L)
            .nanoseconds(LONG_MAX);
    }

    private static String calendarUnits(String unit) {
        return 'operation can only be performed with units of hours or smaller, but found non-zero \'' +
            unit +
            '\' units (operations on `JiffTimestamp`, `JiffOffset` and `JiffTime` don\'t support calendar units in a `JiffSpan`)';
    }

    private static void assertAddFails(JiffTime start, JiffSpan span, String expected) {
        try {
            start.add(span);
            Assert.fail('expected adding ' + span + ' to ' + start + ' to fail');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertAddFails(
        JiffTime start,
        JiffSignedDuration duration,
        String expected
    ) {
        try {
            start.add(duration);
            Assert.fail('expected adding ' + duration + ' to ' + start + ' to fail');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertSubtractFails(JiffTime start, JiffSpan span, String expected) {
        try {
            start.subtract(span);
            Assert.fail('expected subtracting ' + span + ' from ' + start + ' to fail');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertSubtractFails(
        JiffTime start,
        JiffSignedDuration duration,
        String expected
    ) {
        try {
            start.subtract(duration);
            Assert.fail('expected subtracting ' + duration + ' from ' + start + ' to fail');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertCarries(
        JiffTime expectedTime,
        Long expectedDays,
        JiffTime.Overflow actual
    ) {
        Assert.areEqual(expectedTime, actual.toTime());
        Assert.areEqual(expectedDays, actual.days());
    }

    // ---- wrapping -------------------------------------------------------

    @IsTest
    static void wrappingAddOfASpanAddsEveryTimeUnit() {
        Assert.areEqual(
            t(22, 0, 0, 0),
            t(20, 10, 1, 0).wrappingAdd(new JiffSpan().hours(1).minutes(49).seconds(59))
        );
        Assert.areEqual(t(22, 35, 3, 500000000), t(22, 35, 1, 0).wrappingAdd(ns(2500000000L)));
        Assert.areEqual(
            t(1, 2, 3, 4005006),
            JiffTime.MIN.wrappingAdd(
                new JiffSpan()
                    .hours(1)
                    .minutes(2)
                    .seconds(3)
                    .milliseconds(4)
                    .microseconds(5)
                    .nanoseconds(6)
            )
        );
    }

    @IsTest
    static void wrappingAddOfAnEmptySpanChangesNothing() {
        JiffTime start = t(20, 10, 1, 0);
        Assert.areEqual(start, start.wrappingAdd(new JiffSpan()));
    }

    @IsTest
    static void wrappingAddOfASpanWrapsAroundMidnight() {
        Assert.areEqual(t(0, 0, 0, 0), JiffTime.MAX.wrappingAdd(ns(1)));
        JiffTime start = t(12, 34, 56, 789000000);
        Assert.areEqual(t(13, 34, 56, 789000000), start.wrappingAdd(new JiffSpan().hours(25)));
        Assert.areEqual(t(11, 34, 56, 789000000), start.wrappingAdd(new JiffSpan().hours(-25)));
    }

    @IsTest
    static void wrappingAddIgnoresUnitsLargerThanHours() {
        Assert.areEqual(JiffTime.MIN, JiffTime.MIN.wrappingAdd(new JiffSpan().days(1)));
        Assert.areEqual(
            t(6, 0, 0, 0),
            t(1, 0, 0, 0).wrappingAdd(new JiffSpan().years(1).months(2).weeks(3).days(4).hours(5))
        );
    }

    @IsTest
    static void wrappingSubtractOfASpanWrapsAroundMidnight() {
        Assert.areEqual(t(23, 59, 59, 999999999), JiffTime.MIN.wrappingSubtract(ns(1)));
        JiffTime start = t(12, 34, 56, 789000000);
        Assert.areEqual(t(11, 34, 56, 789000000), start.wrappingSubtract(new JiffSpan().hours(25)));
        Assert.areEqual(
            t(20, 10, 1, 0),
            t(22, 0, 0, 0).wrappingSubtract(new JiffSpan().hours(1).minutes(49).seconds(59))
        );
    }

    @IsTest
    static void wrappingAddOfTheLargestSpansGivesJiffsAnswer() {
        // Jiff sums these in a 64 bit integer that wraps, so the answers are not the exact
        // sums reduced to a day. They are what Jiff's own tests assert.
        Assert.areEqual(t(0, 42, 38, 811897855), JiffTime.MIN.wrappingAdd(largestTimeSpan()));
        Assert.areEqual(
            t(23, 17, 21, 188102145),
            JiffTime.MIN.wrappingAdd(largestTimeSpan().negate())
        );
        JiffTime start = t(23, 30, 0, 0);
        Assert.areEqual(t(0, 12, 38, 811897855), start.wrappingAdd(largestTimeSpan()));
        Assert.areEqual(t(22, 47, 21, 188102145), start.wrappingAdd(largestTimeSpan().negate()));
        Assert.areEqual(t(22, 47, 21, 188102145), start.wrappingSubtract(largestTimeSpan()));
        Assert.areEqual(
            t(0, 12, 38, 811897855),
            start.wrappingSubtract(largestTimeSpan().negate())
        );
    }

    @IsTest
    static void wrappingAddOfASpanIsExactAtTheEdgeOfA64BitSum() {
        // The largest count of nanoseconds on its own still fits.
        Assert.areEqual(t(23, 47, 16, 854775807), JiffTime.MIN.wrappingAdd(ns(LONG_MAX)));
        Assert.areEqual(t(0, 12, 43, 145224193), JiffTime.MIN.wrappingAdd(ns(-LONG_MAX)));
        Assert.areEqual(t(0, 12, 43, 145224192), JiffTime.MAX.wrappingSubtract(ns(LONG_MAX)));
        // One step further and the sum wraps before it is reduced to a time of day.
        Assert.areEqual(t(0, 12, 43, 145224190), JiffTime.MAX.wrappingAdd(ns(LONG_MAX)));
        Assert.areEqual(
            t(0, 12, 43, 145225191),
            JiffTime.MIN.wrappingAdd(ns(LONG_MAX).microseconds(1))
        );
        Assert.areEqual(
            t(23, 47, 16, 854774809),
            JiffTime.MIN.wrappingAdd(ns(LONG_MAX).microseconds(1).negate())
        );
    }

    @IsTest
    static void wrappingAddOfADurationWrapsAroundMidnight() {
        Assert.areEqual(t(0, 0, 0, 0), JiffTime.MAX.wrappingAdd(JiffSignedDuration.fromNanos(1)));
        JiffTime start = t(12, 34, 56, 789000000);
        Assert.areEqual(
            t(13, 34, 56, 789000000),
            start.wrappingAdd(JiffSignedDuration.fromHours(25))
        );
        Assert.areEqual(
            t(23, 59, 58, 500000005),
            t(0, 0, 0, 5).wrappingAdd(JiffSignedDuration.newInstance(-1L, -500000000))
        );
        Assert.areEqual(start, start.wrappingAdd(JiffSignedDuration.ZERO));
    }

    @IsTest
    static void wrappingAddAcceptsTheExtremeDurations() {
        Assert.areEqual(t(15, 30, 7, 999999999), JiffTime.MIN.wrappingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(t(8, 29, 51, 1), JiffTime.MIN.wrappingAdd(JiffSignedDuration.MIN));
        Assert.areEqual(t(15, 30, 7, 999999998), JiffTime.MAX.wrappingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(t(8, 29, 51, 0), JiffTime.MAX.wrappingAdd(JiffSignedDuration.MIN));
    }

    @IsTest
    static void wrappingSubtractOfADurationWrapsAroundMidnight() {
        Assert.areEqual(
            t(23, 59, 59, 999999999),
            JiffTime.MIN.wrappingSubtract(JiffSignedDuration.fromNanos(1))
        );
        Assert.areEqual(
            t(11, 34, 55, 989000000),
            t(12, 34, 56, 789000000)
                .wrappingSubtract(JiffSignedDuration.newInstance(25L * 3600L, 800000000))
        );
        Assert.areEqual(
            t(0, 0, 1, 500000005),
            t(0, 0, 0, 5).wrappingSubtract(JiffSignedDuration.newInstance(-1L, -500000000))
        );
    }

    @IsTest
    static void wrappingSubtractAcceptsTheExtremeDurations() {
        Assert.areEqual(
            t(15, 30, 8, 999999999),
            JiffTime.MIN.wrappingSubtract(JiffSignedDuration.MIN)
        );
        Assert.areEqual(t(8, 29, 52, 1), JiffTime.MIN.wrappingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(t(8, 29, 52, 0), JiffTime.MAX.wrappingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(
            t(15, 30, 8, 999999998),
            JiffTime.MAX.wrappingSubtract(JiffSignedDuration.MIN)
        );
    }

    // ---- checked: spans ---------------------------------------------------

    @IsTest
    static void addOfASpanAddsEveryTimeUnit() {
        Assert.areEqual(t(22, 35, 3, 500000000), t(22, 35, 1, 0).add(ns(2500000000L)));
        Assert.areEqual(
            t(22, 0, 0, 0),
            t(20, 10, 1, 0).add(new JiffSpan().hours(1).minutes(49).seconds(59))
        );
        Assert.areEqual(t(2, 0, 0, 0), JiffTime.MIN.add(new JiffSpan().hours(2)));
        JiffTime start = t(20, 10, 1, 0);
        Assert.areEqual(start, start.add(new JiffSpan()));
    }

    @IsTest
    static void addOfASpanFailsWhenTheResultLeavesTheDay() {
        Assert.areEqual(t(23, 59, 59, 999999999), t(23, 59, 59, 999999998).add(ns(1)));
        assertAddFails(JiffTime.MAX, ns(1), OVERFLOWED);
        assertAddFails(JiffTime.MIN, ns(-1), OVERFLOWED);
        assertAddFails(JiffTime.MIN, new JiffSpan().hours(24), OVERFLOWED);
    }

    @IsTest
    static void addOfASpanRejectsUnitsLargerThanHours() {
        // The time does not matter, and neither does the sign. The largest such unit is named.
        assertAddFails(JiffTime.MIN, new JiffSpan().days(1), calendarUnits('day'));
        assertAddFails(JiffTime.MIN, new JiffSpan().weeks(2), calendarUnits('week'));
        assertAddFails(JiffTime.MIN, new JiffSpan().months(-1), calendarUnits('month'));
        assertAddFails(JiffTime.MIN, new JiffSpan().years(1).days(2), calendarUnits('year'));
    }

    @IsTest
    static void addOfAHugeSpanReportsTheDayCarryWhenItIsOutOfRange() {
        // 175,307,616 hours is exactly the largest number of days a span can hold.
        JiffSpan mostHours = new JiffSpan().hours(175307616L);
        assertAddFails(JiffTime.MIN, mostHours, OVERFLOWED);
        assertAddFails(t(1, 0, 0, 0), mostHours, OVERFLOWED);
        assertAddFails(JiffTime.MIN, mostHours.minutes(1439), OVERFLOWED);
        assertAddFails(JiffTime.MIN, mostHours.minutes(1440), TOO_MANY_DAYS);
        assertAddFails(JiffTime.MIN, mostHours.negate(), OVERFLOWED);
        assertAddFails(JiffTime.MIN, mostHours.nanoseconds(1).negate(), TOO_MANY_DAYS);
        assertAddFails(t(23, 30, 0, 0), largestTimeSpan(), TOO_MANY_DAYS);
        assertAddFails(t(23, 30, 0, 0), largestTimeSpan().negate(), TOO_MANY_DAYS);
    }

    @IsTest
    static void subtractOfASpanIsAddOfItsNegation() {
        Assert.areEqual(
            t(20, 10, 1, 0),
            t(22, 0, 0, 0).subtract(new JiffSpan().hours(1).minutes(49).seconds(59))
        );
        Assert.areEqual(t(0, 0, 0, 0), t(0, 0, 0, 1).subtract(ns(1)));
        assertSubtractFails(JiffTime.MIN, ns(1), OVERFLOWED);
        assertSubtractFails(JiffTime.MIN, new JiffSpan().months(1), calendarUnits('month'));
    }

    // ---- checked: durations -----------------------------------------------

    @IsTest
    static void addOfADurationMovesForwardsOrBackwards() {
        JiffTime start = t(23, 0, 0, 0);
        JiffSignedDuration halfHour = JiffSignedDuration.fromMins(30);
        Assert.areEqual(t(23, 30, 0, 0), start.add(halfHour));
        Assert.areEqual(t(22, 30, 0, 0), start.add(halfHour.negate()));
        Assert.areEqual(t(23, 0, 0, 1), start.add(JiffSignedDuration.newInstance(0L, 1)));
        Assert.areEqual(t(2, 0, 0, 0), JiffTime.MIN.add(JiffSignedDuration.fromHours(2)));
        Assert.areEqual(start, start.add(JiffSignedDuration.ZERO));
    }

    @IsTest
    static void addOfADurationFailsWhenTheResultLeavesTheDay() {
        assertAddFails(JiffTime.MAX, JiffSignedDuration.fromNanos(1), OUTSIDE_THE_DAY);
        assertAddFails(JiffTime.MIN, JiffSignedDuration.fromNanos(-1), OUTSIDE_THE_DAY);
        assertAddFails(JiffTime.MIN, JiffSignedDuration.fromHours(24), OUTSIDE_THE_DAY);
    }

    @IsTest
    static void addOfADurationBeyond64BitNanosecondsReportsOverflow() {
        assertAddFails(JiffTime.MIN, JiffSignedDuration.MAX, OVERFLOWED);
        assertAddFails(JiffTime.MIN, JiffSignedDuration.MIN, OVERFLOWED);
        // The duration fits in 64 bits of nanoseconds here. At midnight so does the sum, which
        // is then merely outside the day; one nanosecond later the sum itself overflows.
        assertAddFails(JiffTime.MIN, JiffSignedDuration.fromNanos(LONG_MAX), OUTSIDE_THE_DAY);
        assertAddFails(t(0, 0, 0, 1), JiffSignedDuration.fromNanos(LONG_MAX), OVERFLOWED);
        assertAddFails(JiffTime.MIN, JiffSignedDuration.fromNanos(LONG_MIN), OUTSIDE_THE_DAY);
    }

    @IsTest
    static void subtractOfADurationIsAddOfItsNegation() {
        JiffTime start = t(22, 0, 0, 0);
        Assert.areEqual(t(21, 0, 0, 0), start.subtract(JiffSignedDuration.fromHours(1)));
        Assert.areEqual(t(23, 0, 0, 0), start.subtract(JiffSignedDuration.fromHours(-1)));
        assertSubtractFails(JiffTime.MIN, JiffSignedDuration.fromNanos(1), OUTSIDE_THE_DAY);
        assertSubtractFails(JiffTime.MIN, JiffSignedDuration.MAX, OVERFLOWED);
    }

    @IsTest
    static void subtractOfTheMostNegativeDurationFailsTheWayJiffDoes() {
        assertSubtractFails(
            JiffTime.MIN,
            JiffSignedDuration.MIN,
            'unsigned duration exceeds Jiff\'s limits: parameter \'signed duration seconds\' is not in the required range of -9223372036854775808..=9223372036854775807'
        );
    }

    // ---- saturating -------------------------------------------------------

    @IsTest
    static void saturatingAddOfASpanStopsAtTheEndsOfTheDay() {
        Assert.areEqual(t(23, 59, 59, 999999999), t(23, 59, 59, 999999998).saturatingAdd(ns(1)));
        Assert.areEqual(JiffTime.MAX, JiffTime.MAX.saturatingAdd(ns(1)));
        JiffTime noon = t(12, 0, 0, 0);
        Assert.areEqual(t(12, 30, 0, 0), noon.saturatingAdd(new JiffSpan().minutes(30)));
        Assert.areEqual(JiffTime.MAX, noon.saturatingAdd(new JiffSpan().hours(13)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingAdd(new JiffSpan().hours(-13)));
        Assert.areEqual(JiffTime.MAX, noon.saturatingAdd(largestTimeSpan()));
        Assert.areEqual(JiffTime.MIN, noon.saturatingAdd(largestTimeSpan().negate()));
    }

    @IsTest
    static void saturatingAddTreatsUnitsLargerThanHoursAsOverflow() {
        Assert.areEqual(JiffTime.MAX, JiffTime.MIN.saturatingAdd(new JiffSpan().days(1)));
        Assert.areEqual(JiffTime.MIN, t(12, 0, 0, 0).saturatingAdd(new JiffSpan().days(-1)));
    }

    @IsTest
    static void saturatingSubtractOfASpanStopsAtTheEndsOfTheDay() {
        Assert.areEqual(t(0, 0, 0, 0), t(0, 0, 0, 1).saturatingSubtract(ns(1)));
        Assert.areEqual(JiffTime.MIN, JiffTime.MIN.saturatingSubtract(ns(1)));
        JiffTime noon = t(12, 0, 0, 0);
        Assert.areEqual(t(11, 30, 0, 0), noon.saturatingSubtract(new JiffSpan().minutes(30)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingSubtract(new JiffSpan().hours(13)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingSubtract(new JiffSpan().days(1)));
        Assert.areEqual(JiffTime.MAX, noon.saturatingSubtract(new JiffSpan().days(-1)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingSubtract(largestTimeSpan()));
        Assert.areEqual(JiffTime.MAX, noon.saturatingSubtract(largestTimeSpan().negate()));
    }

    @IsTest
    static void saturatingAddOfADurationStopsAtTheEndsOfTheDay() {
        Assert.areEqual(JiffTime.MAX, JiffTime.MAX.saturatingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(JiffTime.MIN, JiffTime.MAX.saturatingAdd(JiffSignedDuration.MIN));
        JiffTime noon = t(12, 0, 0, 0);
        Assert.areEqual(t(12, 30, 0, 0), noon.saturatingAdd(JiffSignedDuration.fromMins(30)));
        Assert.areEqual(JiffTime.MAX, noon.saturatingAdd(JiffSignedDuration.fromHours(13)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingAdd(JiffSignedDuration.fromHours(-13)));
    }

    @IsTest
    static void saturatingSubtractOfADurationStopsAtTheEndsOfTheDay() {
        Assert.areEqual(JiffTime.MIN, JiffTime.MIN.saturatingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(JiffTime.MAX, JiffTime.MIN.saturatingSubtract(JiffSignedDuration.MIN));
        JiffTime noon = t(12, 0, 0, 0);
        Assert.areEqual(t(11, 30, 0, 0), noon.saturatingSubtract(JiffSignedDuration.fromMins(30)));
        Assert.areEqual(JiffTime.MIN, noon.saturatingSubtract(JiffSignedDuration.fromHours(13)));
        Assert.areEqual(JiffTime.MAX, noon.saturatingSubtract(JiffSignedDuration.fromHours(-13)));
    }

    // ---- carrying into days -------------------------------------------------

    @IsTest
    static void anOverflowHoldsATimeAndADayCarry() {
        JiffTime.Overflow carry = new JiffTime.Overflow(t(4, 30, 0, 0), -2L);
        Assert.areEqual(t(4, 30, 0, 0), carry.toTime());
        Assert.areEqual(-2L, carry.days());
    }

    @IsTest
    static void overflowingAddOfASpanCarriesWholeDays() {
        assertCarries(t(4, 30, 0, 0), 1L, t(23, 30, 0, 0).overflowingAdd(new JiffSpan().hours(5)));
        assertCarries(
            t(22, 30, 0, 0),
            0L,
            t(20, 10, 1, 0).overflowingAdd(new JiffSpan().hours(2).minutes(19).seconds(59))
        );
    }

    @IsTest
    static void overflowingAddOfANegativeSpanCarriesBackwards() {
        JiffTime midnight = JiffTime.MIN;
        assertCarries(t(0, 0, 1, 0), 0L, midnight.overflowingAdd(new JiffSpan().seconds(1)));
        assertCarries(t(23, 59, 59, 0), -1L, midnight.overflowingAdd(new JiffSpan().seconds(-1)));
        assertCarries(t(0, 0, 0, 1), 0L, midnight.overflowingAdd(ns(1)));
        assertCarries(t(23, 59, 59, 999999999), -1L, midnight.overflowingAdd(ns(-1)));
        assertCarries(
            t(0, 0, 1, 2),
            0L,
            midnight.overflowingAdd(new JiffSpan().seconds(1).nanoseconds(2))
        );
        assertCarries(
            t(23, 59, 58, 999999998),
            -1L,
            midnight.overflowingAdd(new JiffSpan().seconds(1).nanoseconds(2).negate())
        );
    }

    @IsTest
    static void overflowingAddOfASpanRejectsACarryNoSpanCanHold() {
        try {
            t(23, 30, 0, 0).overflowingAdd(largestTimeSpan());
            Assert.fail('expected the day carry to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(TOO_MANY_DAYS, e.getMessage());
        }
        // Exactly the largest carry is fine.
        assertCarries(
            t(23, 30, 0, 0),
            7304484L,
            t(23, 30, 0, 0).overflowingAdd(new JiffSpan().hours(175307616L))
        );
    }

    @IsTest
    static void overflowingAddOfASpanRejectsUnitsLargerThanHours() {
        try {
            JiffTime.MIN.overflowingAdd(new JiffSpan().weeks(1).hours(1));
            Assert.fail('expected a span with weeks to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(calendarUnits('week'), e.getMessage());
        }
    }

    @IsTest
    static void overflowingAddOfADurationCarriesWholeDays() {
        JiffTime midnight = JiffTime.MIN;
        assertCarries(t(0, 0, 1, 0), 0L, midnight.overflowingAdd(JiffSignedDuration.fromSecs(1)));
        assertCarries(
            t(23, 59, 59, 0),
            -1L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(-1))
        );
        assertCarries(t(0, 0, 0, 1), 0L, midnight.overflowingAdd(JiffSignedDuration.fromNanos(1)));
        assertCarries(
            t(23, 59, 59, 999999999),
            -1L,
            midnight.overflowingAdd(JiffSignedDuration.fromNanos(-1))
        );
        assertCarries(
            t(0, 0, 1, 2),
            0L,
            midnight.overflowingAdd(JiffSignedDuration.newInstance(1L, 2))
        );
        assertCarries(
            t(23, 59, 58, 999999998),
            -1L,
            midnight.overflowingAdd(JiffSignedDuration.newInstance(-1L, -2))
        );
    }

    @IsTest
    static void overflowingAddOfSecondsMatchesJiffCore() {
        JiffTime midnight = JiffTime.MIN;
        assertCarries(
            JiffTime.fromNanosecondOfDay(86399000000000L),
            0L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(86399))
        );
        assertCarries(midnight, 1L, midnight.overflowingAdd(JiffSignedDuration.fromSecs(86400)));
        assertCarries(
            t(0, 0, 1, 0),
            1L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(86401))
        );
        // 2^31 - 1 seconds: 11,647 seconds into the day, 24,855 days on.
        assertCarries(
            t(3, 14, 7, 0),
            24855L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(2147483647L))
        );
        assertCarries(
            t(0, 0, 1, 0),
            -1L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(-86399))
        );
        assertCarries(midnight, -1L, midnight.overflowingAdd(JiffSignedDuration.fromSecs(-86400)));
        assertCarries(
            t(23, 59, 59, 0),
            -2L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(-86401))
        );
        // -2^31 seconds: 74,752 seconds into the day, 24,856 days back.
        assertCarries(
            t(20, 45, 52, 0),
            -24856L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(-2147483648L))
        );
        assertCarries(
            t(20, 45, 51, 0),
            -24855L,
            t(23, 59, 59, 0).overflowingAdd(JiffSignedDuration.fromSecs(-2147483648L))
        );
    }

    @IsTest
    static void overflowingAddOfNanosecondsMatchesJiffCore() {
        JiffTime midnight = JiffTime.MIN;
        assertCarries(
            JiffTime.fromNanosecondOfDay(85636854775807L),
            106751L,
            midnight.overflowingAdd(JiffSignedDuration.fromNanos(LONG_MAX))
        );
        assertCarries(
            JiffTime.fromNanosecondOfDay(763145224192L),
            -106752L,
            midnight.overflowingAdd(JiffSignedDuration.fromNanos(LONG_MIN))
        );
        assertCarries(
            JiffTime.fromNanosecondOfDay(762145224192L),
            -106751L,
            t(23, 59, 59, 0).overflowingAdd(JiffSignedDuration.fromNanos(LONG_MIN))
        );
    }

    @IsTest
    static void overflowingAddOfADurationRejectsACarryNoSpanCanHold() {
        JiffTime midnight = JiffTime.MIN;
        List<JiffSignedDuration> tooLong = new List<JiffSignedDuration>{
            JiffSignedDuration.MAX,
            JiffSignedDuration.MIN,
            JiffSignedDuration.fromSecs(7304485L * 86400L),
            JiffSignedDuration.newInstance(-7304484L * 86400L, -1)
        };
        for (JiffSignedDuration duration : tooLong) {
            try {
                midnight.overflowingAdd(duration);
                Assert.fail('expected the day carry of ' + duration + ' to be out of range');
            } catch (JiffException e) {
                Assert.areEqual(TOO_MANY_DAYS, e.getMessage());
            }
        }
        // Exactly the largest carry in either direction is fine.
        assertCarries(
            midnight,
            7304484L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(7304484L * 86400L))
        );
        assertCarries(
            t(23, 59, 59, 999999999),
            7304484L,
            midnight.overflowingAdd(
                JiffSignedDuration.newInstance(7304485L * 86400L - 1L, 999999999)
            )
        );
        assertCarries(
            midnight,
            -7304484L,
            midnight.overflowingAdd(JiffSignedDuration.fromSecs(-7304484L * 86400L))
        );
    }

    // ---- properties ---------------------------------------------------------

    /** A spread of times and nanosecond offsets that covers both ends of the day. */
    private static List<Long> sampleNanoseconds() {
        return new List<Long>{
            0L,
            1L,
            999999999L,
            1000000000L,
            3599999999999L,
            3600000000000L,
            43200000000000L,
            55365123456789L,
            86399000000000L,
            86399999999998L,
            86399999999999L
        };
    }

    @IsTest
    static void checkedAndWrappingArithmeticAgreeWhileTheResultStaysInTheDay() {
        // Jiff states these as properties: whenever checked addition succeeds, it gives the
        // same answer as wrapping addition, and subtracting the span again gives the start.
        Integer inRange = 0;
        for (Long startNanos : sampleNanoseconds()) {
            JiffTime start = JiffTime.fromNanosecondOfDay(startNanos);
            for (Long offset : sampleNanoseconds()) {
                JiffSpan span = ns(offset);
                JiffTime wrappedSum = start.wrappingAdd(span);
                Assert.areEqual(start, wrappedSum.wrappingSubtract(span));
                JiffTime wrappedDifference = start.wrappingSubtract(span);
                Assert.areEqual(start, wrappedDifference.wrappingAdd(span));
                if (startNanos + offset < 86400000000000L) {
                    inRange++;
                    Assert.areEqual(wrappedSum, start.add(span));
                    Assert.areEqual(start, start.add(span).subtract(span));
                    Assert.areEqual(wrappedSum, start.saturatingAdd(span));
                    Assert.areEqual(wrappedSum, start.add(JiffSignedDuration.fromNanos(offset)));
                    Assert.areEqual(0L, start.overflowingAdd(span).days());
                } else {
                    Assert.areEqual(JiffTime.MAX, start.saturatingAdd(span));
                    Assert.areEqual(1L, start.overflowingAdd(span).days());
                    Assert.areEqual(wrappedSum, start.overflowingAdd(span).toTime());
                }
                if (startNanos - offset >= 0) {
                    Assert.areEqual(wrappedDifference, start.subtract(span));
                    Assert.areEqual(
                        wrappedDifference,
                        start.subtract(JiffSignedDuration.fromNanos(offset))
                    );
                } else {
                    Assert.areEqual(JiffTime.MIN, start.saturatingSubtract(span));
                }
            }
        }
        Assert.isTrue(inRange > 50, 'expected most pairs to stay within the day');
    }
}
