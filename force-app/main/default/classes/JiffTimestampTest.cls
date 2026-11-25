@IsTest
private class JiffTimestampTest {
    private static final Long MIN_SECOND = -377705023201L;
    private static final Long MAX_SECOND = 253402207200L;
    private static final String SECONDS_RANGE =
        'parameter \'Unix timestamp seconds\' is not in the required range of ' +
        '-377705023201..=253402207200';
    private static final String CALENDAR_UNITS =
        'operation can only be performed with units of hours or smaller, but found non-zero ' +
        '\'day\' units (operations on `JiffTimestamp`, `JiffOffset` and `JiffTime` don\'t ' +
        'support calendar units in a `JiffSpan`)';

    private static JiffTimestamp stamp(Long second, Integer nanosecond) {
        return JiffTimestamp.newInstance(second, nanosecond);
    }

    /** The instant at which a clock `offsetHours` from UTC shows the given civil datetime. */
    private static JiffTimestamp at(
        Integer offsetHours,
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer nanosecond
    ) {
        return JiffOffset.fromHours(offsetHours)
            .toTimestamp(
                JiffDateTime.newInstance(year, month, day, hour, minute, second, nanosecond)
            );
    }

    private static JiffTimestamp utc(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer nanosecond
    ) {
        return at(0, year, month, day, hour, minute, second, nanosecond);
    }

    private static void assertParts(Long second, Integer nanosecond, JiffTimestamp actual) {
        Assert.areEqual(second, actual.asSecond(), 'seconds of ' + actual);
        Assert.areEqual(nanosecond, actual.subsecNanosecond(), 'nanoseconds of ' + actual);
    }

    private static void assertContains(String expectedFragment, String message) {
        Assert.isTrue(
            message.contains(expectedFragment),
            'expected "' + expectedFragment + '" in: ' + message
        );
    }

    // ---- construction ---------------------------------------------------

    @IsTest
    static void constantsSpanJiffsRange() {
        Assert.areEqual('-009999-01-02T01:59:59Z', JiffTimestamp.MIN.toString());
        Assert.areEqual('9999-12-30T22:00:00.999999999Z', JiffTimestamp.MAX.toString());
        Assert.areEqual('1970-01-01T00:00:00Z', JiffTimestamp.UNIX_EPOCH.toString());
        assertParts(MIN_SECOND, 0, JiffTimestamp.MIN);
        assertParts(MAX_SECOND, 999999999, JiffTimestamp.MAX);
        assertParts(0L, 0, JiffTimestamp.UNIX_EPOCH);
        Assert.areEqual(JiffTimestamp.MIN, stamp(MIN_SECOND, 0));
        Assert.areEqual(JiffTimestamp.MAX, stamp(MAX_SECOND, 999999999));
    }

    @IsTest
    static void newInstanceTakesSecondsAndNanoseconds() {
        Assert.areEqual('1973-11-29T21:33:09Z', stamp(123456789L, 0).toString());
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, stamp(0L, 0));
        assertParts(0L, 123000000, stamp(0L, 123000000));
        assertParts(0L, -123000000, stamp(0L, -123000000));
        assertParts(1L, 0, stamp(1L, 0));
        assertParts(-1L, 0, stamp(-1L, 0));
        assertParts(1L, 123000000, stamp(1L, 123000000));
        assertParts(-1L, -123000000, stamp(-1L, -123000000));
    }

    @IsTest
    static void newInstanceMakesBothComponentsShareASign() {
        assertParts(1L, 1, stamp(2L, -999999999));
        assertParts(-1L, -1, stamp(-2L, 999999999));
        assertParts(0L, 877000000, stamp(1L, -123000000));
        assertParts(0L, -877000000, stamp(-1L, 123000000));
        JiffTimestamp positive = stamp(5L, -999999999);
        Assert.areEqual(1, positive.signum());
        assertParts(4L, 1, positive);
        JiffTimestamp negative = stamp(-5L, 999999999);
        Assert.areEqual(-1, negative.signum());
        assertParts(-4L, -1, negative);
    }

    @IsTest
    static void newInstanceRejectsNanosecondsBeyondOneSecond() {
        List<Long> seconds = new List<Long>{ 0L, 1L, -1L };
        List<Integer> nanos = new List<Integer>{
            1000000000,
            -1000000000,
            JiffMath.INT_MAX,
            JiffMath.INT_MIN
        };
        for (Long second : seconds) {
            for (Integer nano : nanos) {
                try {
                    stamp(second, nano);
                    Assert.fail('expected ' + nano + ' nanoseconds to be rejected');
                } catch (JiffException e) {
                    Assert.areEqual(
                        'parameter \'subsecond nanosecond\' is not in the required range of ' +
                        '-999999999..=999999999',
                        e.getMessage()
                    );
                }
            }
        }
    }

    @IsTest
    static void newInstanceRejectsInstantsOutsideTheRange() {
        List<Long> seconds = new List<Long>{
            MIN_SECOND,
            MIN_SECOND,
            MAX_SECOND + 1,
            MIN_SECOND - 1
        };
        List<Integer> nanos = new List<Integer>{ -1, -999999999, 0, 0 };
        for (Integer i = 0; i < seconds.size(); i++) {
            try {
                stamp(seconds.get(i), nanos.get(i));
                Assert.fail('expected an instant out of range to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(SECONDS_RANGE, e.getMessage());
            }
        }
        // The minimum second may still carry a positive fraction.
        Assert.areEqual('-009999-01-02T01:59:59.000000001Z', stamp(MIN_SECOND, 1).toString());
        assertParts(MIN_SECOND + 1, -1, stamp(MIN_SECOND, 999999999));
    }

    @IsTest
    static void fromSecondCountsWholeSeconds() {
        Assert.areEqual('1970-01-01T00:00:01Z', JiffTimestamp.fromSecond(1L).toString());
        Assert.areEqual('1969-12-31T23:59:59Z', JiffTimestamp.fromSecond(-1L).toString());
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, JiffTimestamp.fromSecond(0L));
        Assert.areEqual(JiffTimestamp.MIN, JiffTimestamp.fromSecond(MIN_SECOND));
        for (Long tooFar : new List<Long>{ -999999999999999999L, 999999999999999999L }) {
            try {
                JiffTimestamp.fromSecond(tooFar);
                Assert.fail('expected ' + tooFar + ' seconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(SECONDS_RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void fromMillisecondCountsMilliseconds() {
        Assert.areEqual('1970-01-01T00:00:00.001Z', JiffTimestamp.fromMillisecond(1L).toString());
        Assert.areEqual('1969-12-31T23:59:59.999Z', JiffTimestamp.fromMillisecond(-1L).toString());
        assertParts(-5L, -123000000, JiffTimestamp.fromMillisecond(-5123L));
        Assert.areEqual(JiffTimestamp.MIN, JiffTimestamp.fromMillisecond(MIN_SECOND * 1000L));
        for (
            Long tooFar : new List<Long>{
                -999999999999999999L,
                999999999999999999L,
                // Within the last second, but beyond the limit Jiff sets for milliseconds.
                253402207200999L
            }
        ) {
            try {
                JiffTimestamp.fromMillisecond(tooFar);
                Assert.fail('expected ' + tooFar + ' milliseconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'Unix timestamp milliseconds\' is not in the required range of ' +
                    '-377705023201000..=253402207200000',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void fromMicrosecondCountsMicroseconds() {
        Assert.areEqual(
            '1970-01-01T00:00:00.000001Z',
            JiffTimestamp.fromMicrosecond(1L).toString()
        );
        Assert.areEqual(
            '1969-12-31T23:59:59.999999Z',
            JiffTimestamp.fromMicrosecond(-1L).toString()
        );
        assertParts(5L, 123456000, JiffTimestamp.fromMicrosecond(5123456L));
        for (
            Long tooFar : new List<Long>{
                -999999999999999999L,
                999999999999999999L,
                JiffMath.LONG_MAX
            }
        ) {
            try {
                JiffTimestamp.fromMicrosecond(tooFar);
                Assert.fail('expected ' + tooFar + ' microseconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'Unix timestamp microseconds\' is not in the required range of ' +
                    '-377705023201000000..=253402207200000000',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void fromNanosecondCountsNanoseconds() {
        Assert.areEqual(
            '1970-01-01T00:00:00.000000001Z',
            JiffTimestamp.fromNanosecond(1L).toString()
        );
        Assert.areEqual(
            '1969-12-31T23:59:59.999999999Z',
            JiffTimestamp.fromNanosecond(-1L).toString()
        );
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, JiffTimestamp.fromNanosecond(0L));
        // Every Long is in range.
        assertParts(9223372036L, 854775807, JiffTimestamp.fromNanosecond(JiffMath.LONG_MAX));
        assertParts(-9223372036L, -854775808, JiffTimestamp.fromNanosecond(JiffMath.LONG_MIN));
    }

    @IsTest
    static void wideNanosecondsRoundTripAtTheBoundaries() {
        JiffI128 minimum = JiffTimestamp.MIN.asNanosecondI128();
        JiffI128 maximum = JiffTimestamp.MAX.asNanosecondI128();
        Assert.areEqual('-377705023201000000000', minimum.toString());
        Assert.areEqual('253402207200999999999', maximum.toString());
        Assert.areEqual(JiffTimestamp.MIN, JiffTimestamp.fromNanosecondI128(minimum));
        Assert.areEqual(JiffTimestamp.MAX, JiffTimestamp.fromNanosecondI128(maximum));
        Assert.areEqual(
            stamp(5L, 123456789),
            JiffTimestamp.fromNanosecondI128(JiffI128.valueOf(5123456789L))
        );
        for (JiffI128 outside : new List<JiffI128>{ minimum.subtract(1L), maximum.add(1L) }) {
            try {
                JiffTimestamp.fromNanosecondI128(outside);
                Assert.fail('expected ' + outside + ' nanoseconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(SECONDS_RANGE, e.getMessage());
            }
        }
        for (
            String huge : new List<String>{
                '9999999999999999999999999999999999',
                '-9999999999999999999999999999999999'
            }
        ) {
            try {
                JiffTimestamp.fromNanosecondI128(JiffI128.parse(huge));
                Assert.fail('expected ' + huge + ' nanoseconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'Unix timestamp nanoseconds\' is not in the required range of ' +
                    '-377705023201000000000..=253402207200000000000',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void fromDurationMeasuresFromTheEpoch() {
        Assert.areEqual(
            JiffTimestamp.UNIX_EPOCH,
            JiffTimestamp.fromDuration(JiffSignedDuration.ZERO)
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffTimestamp.fromDuration(JiffSignedDuration.newInstance(MIN_SECOND, 0))
        );
        Assert.areEqual(
            stamp(5L, 123456789),
            JiffTimestamp.fromDuration(JiffSignedDuration.newInstance(5L, 123456789))
        );
        for (
            JiffSignedDuration outside : new List<JiffSignedDuration>{
                // One nanosecond before the minimum.
                JiffSignedDuration.newInstance(MIN_SECOND, -1),
                JiffSignedDuration.fromSecs(-999999999999L),
                JiffSignedDuration.fromSecs(999999999999L)
            }
        ) {
            try {
                JiffTimestamp.fromDuration(outside);
                Assert.fail('expected ' + outside + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(SECONDS_RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void nowIsTheCurrentInstant() {
        Long before = System.currentTimeMillis();
        JiffTimestamp now = JiffTimestamp.now();
        Long after = System.currentTimeMillis();
        Assert.isTrue(now.isAfter(JiffTimestamp.UNIX_EPOCH));
        Assert.isTrue(now.asMillisecond() >= before && now.asMillisecond() <= after);
    }

    // ---- accessors ------------------------------------------------------

    @IsTest
    static void wholeUnitsTruncateTowardZero() {
        Assert.areEqual(5L, stamp(5L, 123456789).asSecond());
        Assert.areEqual(5L, stamp(5L, 999999999).asSecond());
        Assert.areEqual(-5L, stamp(-5L, -123456789).asSecond());
        Assert.areEqual(-5L, stamp(-5L, -999999999).asSecond());
        Assert.areEqual(5123L, stamp(5L, 123456789).asMillisecond());
        Assert.areEqual(5999L, stamp(5L, 999999999).asMillisecond());
        Assert.areEqual(-5123L, stamp(-5L, -123456789).asMillisecond());
        Assert.areEqual(-5999L, stamp(-5L, -999999999).asMillisecond());
        Assert.areEqual(5123456L, stamp(5L, 123456789).asMicrosecond());
        Assert.areEqual(5999999L, stamp(5L, 999999999).asMicrosecond());
        Assert.areEqual(-5123456L, stamp(-5L, -123456789).asMicrosecond());
        Assert.areEqual(-5999999L, stamp(-5L, -999999999).asMicrosecond());
        Assert.areEqual(5123456789L, stamp(5L, 123456789).asNanosecond());
        Assert.areEqual(5999999999L, stamp(5L, 999999999).asNanosecond());
        Assert.areEqual(-5123456789L, stamp(-5L, -123456789).asNanosecond());
        Assert.areEqual(-5999999999L, stamp(-5L, -999999999).asNanosecond());
    }

    @IsTest
    static void subsecondUnitsKeepTheSignOfTheTimestamp() {
        Assert.areEqual(123, stamp(5L, 123456789).subsecMillisecond());
        Assert.areEqual(999, stamp(5L, 999999999).subsecMillisecond());
        Assert.areEqual(-123, stamp(-5L, -123456789).subsecMillisecond());
        Assert.areEqual(-999, stamp(-5L, -999999999).subsecMillisecond());
        Assert.areEqual(123456, stamp(5L, 123456789).subsecMicrosecond());
        Assert.areEqual(999999, stamp(5L, 999999999).subsecMicrosecond());
        Assert.areEqual(-123456, stamp(-5L, -123456789).subsecMicrosecond());
        Assert.areEqual(-999999, stamp(-5L, -999999999).subsecMicrosecond());
        Assert.areEqual(123456789, stamp(5L, 123456789).subsecNanosecond());
        Assert.areEqual(999999999, stamp(5L, 999999999).subsecNanosecond());
        Assert.areEqual(-123456789, stamp(-5L, -123456789).subsecNanosecond());
        Assert.areEqual(-999999999, stamp(-5L, -999999999).subsecNanosecond());
    }

    @IsTest
    static void asNanosecondThrowsWhereALongCannotHoldTheCount() {
        Assert.areEqual(
            JiffMath.LONG_MAX,
            JiffTimestamp.fromNanosecond(JiffMath.LONG_MAX).asNanosecond()
        );
        Assert.areEqual(
            JiffMath.LONG_MIN,
            JiffTimestamp.fromNanosecond(JiffMath.LONG_MIN).asNanosecond()
        );
        for (
            JiffTimestamp distant : new List<JiffTimestamp>{
                JiffTimestamp.MAX,
                JiffTimestamp.MIN,
                stamp(9223372036L, 854775808)
            }
        ) {
            try {
                distant.asNanosecond();
                Assert.fail('expected an overflow for ' + distant);
            } catch (JiffException e) {
                Assert.areEqual('timestamp nanoseconds overflowed', e.getMessage());
            }
        }
        Assert.areEqual('5123456789', stamp(5L, 123456789).asNanosecondI128().toString());
        Assert.areEqual('-5123456789', stamp(-5L, -123456789).asNanosecondI128().toString());
    }

    @IsTest
    static void asDurationIsTheTimeSinceTheEpoch() {
        Assert.areEqual(JiffSignedDuration.ZERO, JiffTimestamp.UNIX_EPOCH.asDuration());
        Assert.areEqual(
            JiffSignedDuration.newInstance(5L, 123456789),
            stamp(5L, 123456789).asDuration()
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(-5L, -123456789),
            stamp(-5L, -123456789).asDuration()
        );
    }

    @IsTest
    static void signumAndIsZeroDescribeThePositionRelativeToTheEpoch() {
        Assert.isTrue(JiffTimestamp.UNIX_EPOCH.isZero());
        Assert.areEqual(0, JiffTimestamp.UNIX_EPOCH.signum());
        Assert.isFalse(stamp(0L, 1).isZero());
        Assert.isFalse(stamp(1L, 0).isZero());
        Assert.areEqual(1, stamp(0L, 1).signum());
        Assert.areEqual(-1, stamp(0L, -1).signum());
        Assert.areEqual(1, JiffTimestamp.MAX.signum());
        Assert.areEqual(-1, JiffTimestamp.MIN.signum());
    }

    // ---- arithmetic -----------------------------------------------------

    @IsTest
    static void addsSpansOfHoursAndSmaller() {
        Assert.areEqual(
            '1970-01-01T05:00:00Z',
            JiffTimestamp.UNIX_EPOCH.add(new JiffSpan().hours(5L)).toString()
        );
        Assert.areEqual(
            '1969-12-31T19:00:00Z',
            JiffTimestamp.UNIX_EPOCH.add(new JiffSpan().hours(-5L)).toString()
        );
        JiffTimestamp start = stamp(2999999999L, 0);
        Assert.areEqual('2065-01-24T05:19:59Z', start.toString());
        Assert.areEqual(
            '2065-01-24T06:49:59.000000123Z',
            start.add(new JiffSpan().hours(1L).minutes(30L).nanoseconds(123L)).toString()
        );
        Assert.areEqual(
            utc(2024, 3, 1, 0, 0, 0, 0),
            utc(2024, 2, 28, 0, 0, 0, 0).add(new JiffSpan().hours(48L))
        );
        Assert.areEqual(start, start.add(new JiffSpan()));
    }

    @IsTest
    static void addingASpanKeepsNanosecondPrecision() {
        JiffTimestamp start = at(1, 2025, 1, 25, 19, 32, 21, 783444592);
        JiffSpan oneSecond = new JiffSpan().seconds(1L);
        JiffTimestamp later = start.add(oneSecond);
        Assert.areEqual('2025-01-25T18:32:22.783444592Z', later.toString());
        Assert.areEqual(start, later.subtract(oneSecond), 'should be reversible');
    }

    @IsTest
    static void addingSecondsCrossesTheEpochCorrectly() {
        List<JiffTimestamp> starts = new List<JiffTimestamp>{
            stamp(-1L, -500000000),
            stamp(1L, 500000000),
            stamp(-1L, -1),
            stamp(1L, 1),
            stamp(0L, -1),
            stamp(0L, 1)
        };
        List<Long> seconds = new List<Long>{ 2L, -2L, 3L, -3L, 1L, -1L };
        List<JiffTimestamp> expected = new List<JiffTimestamp>{
            stamp(0L, 500000000),
            stamp(0L, -500000000),
            stamp(1L, 999999999),
            stamp(-1L, -999999999),
            stamp(0L, 999999999),
            stamp(0L, -999999999)
        };
        for (Integer i = 0; i < starts.size(); i++) {
            JiffTimestamp start = starts.get(i);
            Long amount = seconds.get(i);
            Assert.areEqual(expected.get(i), start.add(new JiffSpan().seconds(amount)));
            Assert.areEqual(expected.get(i), start.subtract(new JiffSpan().seconds(-amount)));
            Assert.areEqual(expected.get(i), start.add(JiffSignedDuration.fromSecs(amount)));
            Assert.areEqual(expected.get(i), start.subtract(JiffSignedDuration.fromSecs(-amount)));
        }
    }

    @IsTest
    static void addingASpanFailsBeyondTheLimits() {
        JiffSpan huge = new JiffSpan()
            .hours(175307616L)
            .minutes(10518456960L)
            .seconds(631107417600L);
        Map<JiffSpan, JiffTimestamp> cases = new Map<JiffSpan, JiffTimestamp>{
            new JiffSpan().seconds(1L) => JiffTimestamp.MAX,
            new JiffSpan().nanoseconds(1L) => JiffTimestamp.MAX,
            huge => JiffTimestamp.MAX,
            new JiffSpan().nanoseconds(-1L) => JiffTimestamp.MIN
        };
        for (JiffSpan span : cases.keySet()) {
            try {
                cases.get(span).add(span);
                Assert.fail('expected an overflow adding ' + span);
            } catch (JiffException e) {
                Assert.areEqual(SECONDS_RANGE, e.getMessage());
            }
        }
        // Whole seconds on both sides take a shorter path, which says what overflowed.
        try {
            JiffTimestamp.fromSecond(MAX_SECOND).add(new JiffSpan().seconds(1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual('adding span overflowed timestamp: ' + SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.MIN.add(new JiffSpan().seconds(-1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual('adding span overflowed timestamp: ' + SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.MIN.subtract(new JiffSpan().hours(1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual('adding span overflowed timestamp: ' + SECONDS_RANGE, e.getMessage());
        }
    }

    @IsTest
    static void spansWithCalendarUnitsAreRejected() {
        JiffSpan oneDay = new JiffSpan().days(1L);
        try {
            JiffTimestamp.UNIX_EPOCH.add(oneDay);
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CALENDAR_UNITS, e.getMessage());
        }
        try {
            JiffTimestamp.UNIX_EPOCH.subtract(oneDay);
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CALENDAR_UNITS, e.getMessage());
        }
        try {
            JiffTimestamp.MIN.saturatingAdd(oneDay);
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CALENDAR_UNITS, e.getMessage());
        }
        try {
            JiffTimestamp.MAX.saturatingSubtract(oneDay);
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CALENDAR_UNITS, e.getMessage());
        }
        try {
            JiffTimestamp.UNIX_EPOCH.add(new JiffSpan().years(1L).hours(2L));
            Assert.fail('expected years to be rejected');
        } catch (JiffException e) {
            assertContains('non-zero \'year\' units', e.getMessage());
        }
        // Hours and smaller are fine.
        JiffTimestamp.requireNoCalendarUnits(new JiffSpan().hours(1L).nanoseconds(1L));
    }

    @IsTest
    static void addsExactDurations() {
        JiffTimestamp start = stamp(2999999999L, 0);
        Assert.areEqual(
            '2065-01-24T06:49:59.000000123Z',
            start.add(JiffSignedDuration.newInstance(5400L, 123)).toString()
        );
        Assert.areEqual(
            utc(2024, 3, 1, 0, 0, 0, 0),
            utc(2024, 2, 28, 0, 0, 0, 0).add(JiffSignedDuration.fromHours(48L))
        );
        // One second after the epoch plus one nanosecond less than the maximum is the maximum.
        Assert.areEqual(
            JiffTimestamp.MAX,
            stamp(1L, 0).add(JiffSignedDuration.newInstance(MAX_SECOND, -1))
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            stamp(1L, 0).subtract(JiffSignedDuration.newInstance(-MAX_SECOND, 1))
        );
    }

    @IsTest
    static void addingADurationFailsBeyondTheLimits() {
        try {
            JiffTimestamp.MAX.add(JiffSignedDuration.fromSecs(1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.MIN.add(JiffSignedDuration.newInstance(0L, -1));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.MIN.subtract(JiffSignedDuration.newInstance(0L, 1));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.MAX.add(JiffSignedDuration.MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual('adding duration overflowed timestamp', e.getMessage());
        }
        try {
            JiffTimestamp.UNIX_EPOCH.subtract(JiffSignedDuration.MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'unsigned duration exceeds Jiff\'s limits: parameter \'signed duration ' +
                    'seconds\' is not in the required range of ' +
                    '-9223372036854775808..=9223372036854775807',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void subtractsSpansAndDurations() {
        JiffTimestamp start = stamp(2999999999L, 0);
        Assert.areEqual(
            '2065-01-24T03:49:58.999999877Z',
            start.subtract(new JiffSpan().hours(1L).minutes(30L).nanoseconds(123L)).toString()
        );
        Assert.areEqual(
            '2065-01-24T03:49:58.999999877Z',
            start.subtract(JiffSignedDuration.newInstance(5400L, 123)).toString()
        );
        Assert.areEqual(
            '2024-02-24T15:45:00Z',
            utc(2024, 2, 25, 15, 45, 0, 0).subtract(new JiffSpan().hours(24L)).toString()
        );
        JiffTimestamp thousand = stamp(1000L, 0);
        Assert.areEqual(stamp(600L, 0), thousand.subtract(JiffSignedDuration.fromSecs(400L)));
        Assert.areEqual(stamp(1400L, 0), thousand.subtract(JiffSignedDuration.fromSecs(-400L)));
        Assert.areEqual(thousand, thousand.subtract(JiffSignedDuration.ZERO));
        Assert.areEqual(
            stamp(599L, 999999999),
            thousand.subtract(JiffSignedDuration.newInstance(400L, 1))
        );
        Assert.areEqual(
            stamp(1400L, 1),
            thousand.subtract(JiffSignedDuration.newInstance(-400L, -1))
        );
    }

    @IsTest
    static void saturatingAddClampsToTheLimits() {
        Assert.areEqual(
            JiffTimestamp.MAX,
            JiffTimestamp.MAX.saturatingAdd(new JiffSpan().nanoseconds(1L))
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffTimestamp.MIN.saturatingAdd(new JiffSpan().nanoseconds(-1L))
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            JiffTimestamp.UNIX_EPOCH.saturatingAdd(JiffSignedDuration.MAX)
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffTimestamp.UNIX_EPOCH.saturatingAdd(JiffSignedDuration.MIN)
        );
        // In range, it is ordinary addition.
        Assert.areEqual(
            stamp(18000L, 0),
            JiffTimestamp.UNIX_EPOCH.saturatingAdd(new JiffSpan().hours(5L))
        );
        Assert.areEqual(
            stamp(18000L, 0),
            JiffTimestamp.UNIX_EPOCH.saturatingAdd(JiffSignedDuration.fromHours(5L))
        );
    }

    @IsTest
    static void saturatingSubtractClampsToTheLimits() {
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffTimestamp.MIN.saturatingSubtract(new JiffSpan().nanoseconds(1L))
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            JiffTimestamp.MAX.saturatingSubtract(new JiffSpan().nanoseconds(-1L))
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffTimestamp.UNIX_EPOCH.saturatingSubtract(JiffSignedDuration.MAX)
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            JiffTimestamp.UNIX_EPOCH.saturatingSubtract(JiffSignedDuration.MIN)
        );
        Assert.areEqual(
            stamp(-18000L, 0),
            JiffTimestamp.UNIX_EPOCH.saturatingSubtract(new JiffSpan().hours(5L))
        );
        Assert.areEqual(
            stamp(-18000L, 0),
            JiffTimestamp.UNIX_EPOCH.saturatingSubtract(JiffSignedDuration.fromHours(5L))
        );
    }

    // ---- differences ----------------------------------------------------

    @IsTest
    static void untilMeasuresInSecondsByDefault() {
        JiffTimestamp earlier = utc(2006, 8, 24, 22, 30, 0, 0);
        JiffTimestamp later = utc(2019, 1, 31, 21, 0, 0, 0);
        Assert.areEqual(new JiffSpan().seconds(392509800L), earlier.until(later));
        // Flipping the timestamps gives a negative span.
        Assert.areEqual(new JiffSpan().seconds(-392509800L), later.until(earlier));
        Assert.areEqual(new JiffSpan().seconds(392509800L), later.since(earlier));
        Assert.areEqual(new JiffSpan().seconds(-392509800L), earlier.since(later));
        Assert.areEqual(new JiffSpan(), earlier.until(earlier));
    }

    @IsTest
    static void untilCanBalanceUpToHours() {
        JiffTimestamp first = utc(1995, 12, 7, 3, 24, 30, 3500);
        JiffTimestamp second = utc(2019, 1, 31, 15, 30, 0, 0);
        Assert.areEqual('PT730641929.9999965S', first.until(second).toString());
        Assert.areEqual('PT202956H5M29.9999965S', first.until(second, JiffUnit.HOUR).toString());
        Assert.areEqual(
            new JiffSpan().hours(1648L).minutes(30L).milliseconds(123L),
            utc(2024, 5, 3, 23, 30, 0, 123000000).since(utc(2024, 2, 25, 7, 0, 0, 0), JiffUnit.HOUR)
        );
        Assert.areEqual(
            new JiffSpan().seconds(211076160L),
            utc(2024, 3, 15, 8, 14, 0, 0).until(utc(2030, 11, 22, 8, 30, 0, 0), JiffUnit.SECOND)
        );
        Assert.areEqual(
            new JiffSpan().minutes(-2L).milliseconds(-500L),
            stamp(120L, 500000000).until(JiffTimestamp.UNIX_EPOCH, JiffUnit.MINUTE)
        );
    }

    @IsTest
    static void untilCoversTheWholeRange() {
        Assert.areEqual(
            'PT631107230401.999999999S',
            JiffTimestamp.MIN.until(JiffTimestamp.MAX).toString()
        );
        Assert.areEqual(
            'PT175307564H1.999999999S',
            JiffTimestamp.MIN.until(JiffTimestamp.MAX, JiffUnit.HOUR).toString()
        );
        Assert.areEqual(
            '-PT631107230401.999999999S',
            JiffTimestamp.MIN.since(JiffTimestamp.MAX).toString()
        );
        // A span cannot hold that many nanoseconds.
        try {
            JiffTimestamp.MIN.until(JiffTimestamp.MAX, JiffUnit.NANOSECOND);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'nanoseconds\' is not in the required range of ' +
                '-9223372036854775807..=9223372036854775807',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void untilRejectsUnitsLargerThanHours() {
        JiffTimestamp nextDay = JiffTimestamp.fromSecond(86400L);
        for (JiffUnit unit : new List<JiffUnit>{ JiffUnit.DAY, JiffUnit.WEEK, JiffUnit.YEAR }) {
            try {
                JiffTimestamp.UNIX_EPOCH.until(nextDay, unit);
                Assert.fail('expected ' + unit + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'rounding to \'' + unit.name().toLowerCase() + 's\' is not supported',
                    e.getMessage()
                );
            }
        }
        try {
            JiffTimestamp.UNIX_EPOCH.since(nextDay, (JiffUnit) null);
            Assert.fail('expected a null unit to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('largest unit must not be null', e.getMessage());
        }
    }

    @IsTest
    static void durationUntilAndSinceAreExact() {
        JiffTimestamp earlier = utc(2006, 8, 24, 22, 30, 0, 0);
        JiffTimestamp later = utc(2019, 1, 31, 21, 0, 0, 0);
        Assert.areEqual(JiffSignedDuration.fromSecs(392509800L), earlier.durationUntil(later));
        Assert.areEqual(JiffSignedDuration.fromSecs(-392509800L), later.durationUntil(earlier));
        Assert.areEqual(JiffSignedDuration.fromSecs(392509800L), later.durationSince(earlier));
        Assert.areEqual(
            JiffSignedDuration.newInstance(5934600L, 123000000),
            utc(2024, 5, 3, 23, 30, 0, 123000000).durationSince(utc(2024, 2, 25, 7, 0, 0, 0))
        );
        Assert.areEqual(
            JiffSignedDuration.fromSecs(172800L),
            utc(2024, 2, 28, 0, 0, 0, 0).durationUntil(utc(2024, 3, 1, 0, 0, 0, 0))
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(631107230401L, 999999999),
            JiffTimestamp.MIN.durationUntil(JiffTimestamp.MAX)
        );
    }

    // ---- rounding -------------------------------------------------------

    @IsTest
    static void roundsToTheNearestUnit() {
        Assert.areEqual(
            '2024-06-19T16:00:00Z',
            utc(2024, 6, 19, 15, 30, 0, 0).round(JiffUnit.HOUR).toString()
        );
        Assert.areEqual(
            '2024-06-19T15:00:00Z',
            utc(2024, 6, 19, 15, 29, 59, 0).round(JiffUnit.HOUR).toString()
        );
        Assert.areEqual(
            '2024-06-20T16:25:00Z',
            utc(2024, 6, 20, 16, 24, 59, 500000000).round(JiffUnit.SECOND).toString()
        );
        Assert.areEqual(
            '2024-06-20T03:26:00Z',
            utc(2024, 6, 20, 3, 25, 30, 0).round(JiffUnit.MINUTE).toString()
        );
        JiffTimestamp unchanged = stamp(1718810565L, 123456789);
        Assert.areEqual(unchanged, unchanged.round(new JiffRound()));
        Assert.areEqual(unchanged, unchanged.round(JiffUnit.NANOSECOND));
    }

    @IsTest
    static void roundsWithAnIncrement() {
        JiffTimestamp start = utc(2024, 6, 19, 16, 27, 29, 999999999);
        Assert.areEqual(
            '2024-06-19T15:00:00Z',
            start.round(JiffRound.to(JiffUnit.HOUR).increment(3L)).toString()
        );
        JiffRound fiveMinutes = JiffRound.to(JiffUnit.MINUTE).increment(5L);
        Assert.areEqual(
            '2024-06-19T15:25:00Z',
            utc(2024, 6, 19, 15, 27, 29, 999999999).round(fiveMinutes).toString()
        );
        Assert.areEqual(
            '2024-06-19T15:30:00Z',
            utc(2024, 6, 19, 15, 27, 30, 0).round(fiveMinutes).toString()
        );
        Assert.areEqual(
            '2024-06-20T03:20:00Z',
            utc(2024, 6, 20, 3, 24, 59, 0)
                .round(JiffRound.to(JiffUnit.MINUTE).increment(10L))
                .toString()
        );
    }

    @IsTest
    static void roundsWithAMode() {
        Assert.areEqual(
            '2024-06-19T15:00:00Z',
            utc(2024, 6, 19, 15, 30, 0, 0)
                .round(JiffRound.to(JiffUnit.HOUR).mode(JiffRoundMode.TRUNC))
                .toString()
        );
        Assert.areEqual(
            '2024-06-20T16:24:59Z',
            utc(2024, 6, 20, 16, 24, 59, 500000000)
                .round(JiffRound.to(JiffUnit.SECOND).mode(JiffRoundMode.TRUNC))
                .toString()
        );
        Assert.areEqual(
            '2024-06-20T03:26:00Z',
            utc(2024, 6, 20, 3, 25, 1, 0)
                .round(JiffRound.to(JiffUnit.MINUTE).mode(JiffRoundMode.CEIL))
                .toString()
        );
    }

    @IsTest
    static void roundingBeforeTheEpochGoesAwayFromIt() {
        JiffTimestamp before = stamp(-1L, -500000000);
        Assert.areEqual('1969-12-31T23:59:58.5Z', before.toString());
        Assert.areEqual('1969-12-31T23:59:58Z', before.round(JiffUnit.SECOND).toString());
        Assert.areEqual(
            '1969-12-31T23:59:59Z',
            before.round(JiffRound.to(JiffUnit.SECOND).mode(JiffRoundMode.TRUNC)).toString()
        );
    }

    @IsTest
    static void roundingRejectsBadConfigurationAndOverflow() {
        try {
            JiffTimestamp.MAX.round(JiffUnit.SECOND);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(SECONDS_RANGE, e.getMessage());
        }
        try {
            JiffTimestamp.UNIX_EPOCH.round(JiffUnit.DAY);
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            assertContains('rounding to \'days\' is not supported', e.getMessage());
        }
        try {
            JiffTimestamp.UNIX_EPOCH.round(JiffRound.to(JiffUnit.SECOND).increment(7L));
            Assert.fail('expected an increment of 7 seconds to be rejected');
        } catch (JiffException e) {
            assertContains(
                'increment for rounding to \'seconds\' must divide into `86400` evenly',
                e.getMessage()
            );
        }
        // 45 seconds and 24 hours both divide a day.
        Assert.areEqual(
            stamp(90L, 0),
            stamp(100L, 0).round(JiffRound.to(JiffUnit.SECOND).increment(45L))
        );
        Assert.areEqual(
            stamp(86400L, 0),
            stamp(50000L, 0).round(JiffRound.to(JiffUnit.HOUR).increment(24L))
        );
    }

    // ---- text -----------------------------------------------------------

    @IsTest
    static void toStringIsRfc3339InUtc() {
        Assert.areEqual('2005-08-07T23:19:49Z', JiffTimestamp.fromSecond(1123456789L).toString());
        Assert.areEqual('2005-08-07T23:19:49.123Z', stamp(1123456789L, 123000000).toString());
        Assert.areEqual('2024-06-19T19:22:45Z', at(-4, 2024, 6, 19, 15, 22, 45, 0).toString());
        Assert.areEqual('2024-03-10T09:34:45Z', at(-4, 2024, 3, 10, 5, 34, 45, 0).toString());
        Assert.areEqual('-002024-03-10T09:34:45Z', at(-4, -2024, 3, 10, 5, 34, 45, 0).toString());
        Assert.areEqual(
            '2024-03-10T09:34:45.123456789Z',
            at(-4, 2024, 3, 10, 5, 34, 45, 123456789).toString()
        );
        // The same instant written with two different offsets.
        Assert.areEqual('2024-03-10T06:30:00Z', at(-4, 2024, 3, 10, 2, 30, 0, 0).toString());
        Assert.areEqual('2024-03-10T07:30:00Z', at(-5, 2024, 3, 10, 2, 30, 0, 0).toString());
        Assert.areEqual(
            '2024-03-10T09:34:45Z',
            JiffTemporal.printTimestamp(at(-4, 2024, 3, 10, 5, 34, 45, 0))
        );
    }

    @IsTest
    static void toStringWithOffsetShowsTheLocalTime() {
        Assert.areEqual(
            '1969-12-31T19:00:01-05:00',
            JiffTimestamp.fromSecond(1L).toStringWithOffset(JiffOffset.fromHours(-5))
        );
        JiffTimestamp fractional = stamp(1123456789L, 123000000);
        Assert.areEqual(
            '2005-08-07T18:19:49.123-05:00',
            fractional.toStringWithOffset(JiffOffset.fromHours(-5))
        );
        Assert.areEqual(
            '2005-08-07T23:19:49.123+00:00',
            fractional.toStringWithOffset(JiffOffset.UTC)
        );
        JiffOffset minusFour = JiffOffset.fromHours(-4);
        Assert.areEqual(
            '2024-03-10T05:34:45-04:00',
            at(-4, 2024, 3, 10, 5, 34, 45, 0).toStringWithOffset(minusFour)
        );
        Assert.areEqual(
            '-002024-03-10T05:34:45-04:00',
            at(-4, -2024, 3, 10, 5, 34, 45, 0).toStringWithOffset(minusFour)
        );
        Assert.areEqual(
            '2024-03-10T05:34:45.123456789-04:00',
            JiffTemporal.printTimestampWithOffset(
                at(-4, 2024, 3, 10, 5, 34, 45, 123456789),
                minusFour
            )
        );
    }

    @IsTest
    static void toStringWithOffsetRoundsTheOffsetToMinutes() {
        Assert.areEqual(
            '-009999-01-01T00:00:00-25:59',
            JiffTimestamp.MIN.toStringWithOffset(JiffOffset.MIN)
        );
        Assert.areEqual(
            '1970-01-02T01:59:59+25:59',
            JiffTimestamp.UNIX_EPOCH.toStringWithOffset(JiffOffset.MAX)
        );
        Assert.areEqual(
            '1970-01-01T00:00:30+00:01',
            JiffTimestamp.UNIX_EPOCH.toStringWithOffset(JiffOffset.fromSeconds(30))
        );
        Assert.areEqual(
            '1969-12-31T18:59:30-05:01',
            JiffTimestamp.UNIX_EPOCH.toStringWithOffset(JiffOffset.fromSeconds(-18030))
        );
        Assert.areEqual(
            '1969-12-31T23:30:00-00:30',
            JiffTimestamp.UNIX_EPOCH.toStringWithOffset(JiffOffset.fromSeconds(-1800))
        );
    }

    // ---- comparison -----------------------------------------------------

    @IsTest
    static void ordersChronologically() {
        JiffTimestamp first = JiffTimestamp.fromSecond(123456789L);
        JiffTimestamp second = JiffTimestamp.fromSecond(123456790L);
        Assert.isTrue(first.compareTo(second) < 0);
        Assert.isTrue(second.compareTo(first) > 0);
        Assert.areEqual(0, first.compareTo(JiffTimestamp.fromSecond(123456789L)));
        Assert.isTrue(first.isBefore(second));
        Assert.isFalse(second.isBefore(first));
        Assert.isTrue(second.isAfter(first));
        Assert.isFalse(first.isAfter(first));
        // The fraction breaks ties, on both sides of the epoch.
        Assert.isTrue(stamp(5L, 1).isBefore(stamp(5L, 2)));
        Assert.isTrue(stamp(-5L, -2).isBefore(stamp(-5L, -1)));
        Assert.isTrue(stamp(0L, -1).isBefore(JiffTimestamp.UNIX_EPOCH));
        Assert.isTrue(JiffTimestamp.MIN.isBefore(JiffTimestamp.MAX));
        List<JiffTimestamp> stamps = new List<JiffTimestamp>{
            second,
            JiffTimestamp.MAX,
            JiffTimestamp.MIN,
            first
        };
        stamps.sort();
        Assert.areEqual(JiffTimestamp.MIN, stamps.get(0));
        Assert.areEqual(first, stamps.get(1));
        Assert.areEqual(JiffTimestamp.MAX, stamps.get(3));
    }

    @IsTest
    static void equalTimestampsAreInterchangeable() {
        Assert.areEqual(stamp(1L, 500000000), JiffTimestamp.fromMillisecond(1500L));
        Assert.areEqual(
            stamp(1L, 500000000).hashCode(),
            JiffTimestamp.fromMillisecond(1500L).hashCode()
        );
        Assert.areNotEqual(stamp(1L, 500000000), stamp(1L, 500000001));
        Assert.areNotEqual(stamp(1L, 0), stamp(2L, 0));
        Assert.isFalse(stamp(1L, 0).equals('1970-01-01T00:00:01Z'));
        Map<JiffTimestamp, String> names = new Map<JiffTimestamp, String>{
            JiffTimestamp.fromSecond(0L) => 'epoch',
            JiffTimestamp.MIN => 'min'
        };
        Assert.areEqual('epoch', names.get(JiffTimestamp.UNIX_EPOCH));
        Assert.areEqual('min', names.get(stamp(MIN_SECOND, 0)));
    }

    // ---- platform interop -----------------------------------------------

    @IsTest
    static void convertsFromAPlatformDatetime() {
        JiffTimestamp converted = JiffTimestamp.fromSystemDatetime(
            Datetime.newInstance(1709209845000L)
        );
        Assert.areEqual('2024-02-29T12:30:45Z', converted.toString());
        Assert.areEqual(
            stamp(1709209845L, 123000000),
            JiffTimestamp.fromSystemDatetime(Datetime.newInstance(1709209845123L))
        );
        Assert.areEqual(
            stamp(0L, -1000000),
            JiffTimestamp.fromSystemDatetime(Datetime.newInstance(-1L))
        );
        Datetime missing = null;
        Assert.isNull(JiffTimestamp.fromSystemDatetime(missing));
        try {
            JiffTimestamp.fromSystemDatetime(Datetime.newInstance(253402207200001L));
            Assert.fail('expected a Datetime in the year 9999 to be out of range');
        } catch (JiffException e) {
            assertContains('Unix timestamp milliseconds', e.getMessage());
        }
    }

    @IsTest
    static void convertsToAPlatformDatetimeDroppingSubMilliseconds() {
        Assert.areEqual(
            Datetime.newInstance(1709209845000L),
            utc(2024, 2, 29, 12, 30, 45, 0).toSystemDatetime()
        );
        Assert.areEqual(5123L, stamp(5L, 123456789).toSystemDatetime().getTime());
        Assert.areEqual(5999L, stamp(5L, 999999999).toSystemDatetime().getTime());
        // Before the epoch the truncation is toward the epoch, as in `asMillisecond`.
        Assert.areEqual(-5123L, stamp(-5L, -123456789).toSystemDatetime().getTime());
        Assert.areEqual(0L, stamp(0L, -999999).toSystemDatetime().getTime());
        Datetime original = Datetime.newInstance(1709209845123L);
        Assert.areEqual(original, JiffTimestamp.fromSystemDatetime(original).toSystemDatetime());
    }

    // ---- zoned datetimes --------------------------------------------------

    @IsTest
    static void readsInATimeZoneByName() {
        JiffZonedDateTime zdt = stamp(123456789L, 0).inTz('America/New_York');
        Assert.areEqual('1973-11-29T16:33:09-05:00[America/New_York]', zdt.toString());
        Assert.areEqual(stamp(123456789L, 0), zdt.toTimestamp());
        // What time was it at the Unix epoch in Sydney?
        Assert.areEqual(
            '1970-01-01T10:00:00+10:00[Australia/Sydney]',
            JiffTimestamp.UNIX_EPOCH.inTz('Australia/Sydney').toString()
        );
        try {
            JiffTimestamp.UNIX_EPOCH.inTz('does not exist');
            Assert.fail('expected an unknown time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time zone `does not exist` in time zone database',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void readsInAGivenTimeZone() {
        JiffTimestamp ts = stamp(123456789L, 0);
        JiffZonedDateTime zdt = ts.toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(-4)));
        // A time zone annotation is still included in the printable version of the zoned
        // datetime, but it is fixed to a particular offset.
        Assert.areEqual('1973-11-29T17:33:09-04:00[-04:00]', zdt.toString());
        Assert.areEqual(
            '1973-11-29T21:33:09+00:00[UTC]',
            ts.toZonedDateTime(JiffTimeZone.UTC).toString()
        );
        // The limits can be read in any zone.
        Assert.areEqual(
            '9999-12-30T22:00:00.999999999+00:00[UTC]',
            JiffTimestamp.MAX.toZonedDateTime(JiffTimeZone.UTC).toString()
        );
        Assert.areEqual(
            '-009999-01-02T01:59:59+00:00[UTC]',
            JiffTimestamp.MIN.inTz('UTC').toString()
        );
    }
}
