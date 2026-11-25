@IsTest
private class JiffOffsetTest {
    private static final String RANGE =
        'parameter \'time zone offset total seconds\' is not in the required range of ' +
        '-93599..=93599';
    private static final String CALENDAR_UNITS = 'operation can only be performed with units of hours or smaller, but found non-zero \'';

    private static JiffOffset hours(Integer value) {
        return JiffOffset.fromHours(value);
    }

    private static JiffOffset secs(Integer value) {
        return JiffOffset.fromSeconds(value);
    }

    private static JiffDateTime dt(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer nanosecond
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, second, nanosecond);
    }

    private static JiffTimestamp stamp(Long second, Integer nanosecond) {
        return JiffTimestamp.newInstance(second, nanosecond);
    }

    private static void assertContains(String expectedFragment, String message) {
        Assert.isTrue(
            message.contains(expectedFragment),
            'expected "' + expectedFragment + '" in: ' + message
        );
    }

    @IsTest
    static void constantsCoverJiffsRange() {
        Assert.areEqual(0, JiffOffset.UTC.seconds());
        Assert.areEqual(JiffOffset.UTC, JiffOffset.ZERO);
        Assert.areEqual(-93599, JiffOffset.MIN.seconds());
        Assert.areEqual(93599, JiffOffset.MAX.seconds());
    }

    @IsTest
    static void fromHoursConvertsToSeconds() {
        Assert.areEqual(-18000, hours(-5).seconds());
        Assert.areEqual(18000, hours(5).seconds());
        Assert.areEqual(90000, hours(25).seconds());
        Assert.areEqual(-90000, hours(-25).seconds());
        for (Integer tooMany : new List<Integer>{ 26, -26, 2147483647, -2147483647 }) {
            try {
                hours(tooMany);
                Assert.fail('expected ' + tooMany + ' hours to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void fromSecondsAcceptsOnlyTheSupportedRange() {
        Assert.areEqual(-18000, secs(-18000).seconds());
        Assert.areEqual(18000, secs(18000).seconds());
        Assert.areEqual(JiffOffset.MAX, secs(93599));
        Assert.areEqual(JiffOffset.MIN, secs(-93599));
        for (Integer tooMany : new List<Integer>{ 93600, -93600 }) {
            try {
                secs(tooMany);
                Assert.fail('expected ' + tooMany + ' seconds to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void fromDurationRoundsToTheNearestSecond() {
        Assert.areEqual(hours(-5), JiffOffset.fromDuration(JiffSignedDuration.fromHours(-5L)));
        Assert.areEqual(
            secs(-18001),
            JiffOffset.fromDuration(JiffSignedDuration.newInstance(-18000L, -500000000))
        );
        Assert.areEqual(
            secs(18001),
            JiffOffset.fromDuration(JiffSignedDuration.newInstance(18000L, 500000000))
        );
        Assert.areEqual(
            secs(18000),
            JiffOffset.fromDuration(JiffSignedDuration.newInstance(18000L, 499999999))
        );
        for (
            JiffSignedDuration tooLong : new List<JiffSignedDuration>{
                JiffSignedDuration.fromHours(30L),
                JiffSignedDuration.fromHours(-30L),
                JiffSignedDuration.newInstance(93599L, 500000000),
                JiffSignedDuration.MAX,
                JiffSignedDuration.MIN
            }
        ) {
            try {
                JiffOffset.fromDuration(tooLong);
                Assert.fail('expected ' + tooLong + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual('signed duration overflows time zone offset', e.getMessage());
            }
        }
    }

    @IsTest
    static void negateFlipsTheSideOfUtc() {
        Assert.areEqual(hours(5), hours(-5).negate());
        Assert.areEqual(JiffOffset.MIN, JiffOffset.MAX.negate());
        Assert.areEqual(JiffOffset.UTC, JiffOffset.UTC.negate());
    }

    @IsTest
    static void reportsItsSign() {
        Assert.areEqual(1, hours(5).signum());
        Assert.areEqual(0, hours(0).signum());
        Assert.areEqual(-1, hours(-5).signum());
        Assert.isTrue(hours(5).isPositive());
        Assert.isFalse(hours(0).isPositive());
        Assert.isFalse(hours(-5).isPositive());
        Assert.isFalse(hours(5).isNegative());
        Assert.isFalse(hours(0).isNegative());
        Assert.isTrue(hours(-5).isNegative());
        Assert.isFalse(hours(5).isZero());
        Assert.isTrue(hours(0).isZero());
        Assert.isFalse(hours(-5).isZero());
    }

    @IsTest
    static void toStringIsAsCompactAsTheOffsetAllows() {
        Assert.areEqual('-05', hours(-5).toString());
        Assert.areEqual('-05', secs(-18000).toString());
        Assert.areEqual('-05:01', secs(-18060).toString());
        Assert.areEqual('-05:01:02', secs(-18062).toString());
        Assert.areEqual('-25:59:59', secs(-93599).toString());
        Assert.areEqual('+25:59:59', secs(93599).toString());
        Assert.areEqual('+00', hours(0).toString());
        Assert.areEqual('+01', secs(3600).toString());
        Assert.areEqual('+00:30', secs(1800).toString());
        Assert.areEqual('-00:30', secs(-1800).toString());
        Assert.areEqual('+00:01', secs(60).toString());
        Assert.areEqual('+00:00:30', secs(30).toString());
        Assert.areEqual('-00:00:30', secs(-30).toString());
        Assert.areEqual('+05:00:30', secs(18030).toString());
        Assert.areEqual('-05:00:30', secs(-18030).toString());
    }

    @IsTest
    static void printOffsetRoundsToTheNearestMinute() {
        Assert.areEqual('-04:00', JiffTemporal.printOffset(hours(-4)));
        Assert.areEqual('+00:00', JiffTemporal.printOffset(JiffOffset.UTC));
        Assert.areEqual('+05:30', JiffTemporal.printOffset(secs(19800)));
        // Africa/Monrovia was at -00:44:30 until 1972, which RFC 3339 cannot express.
        Assert.areEqual('-00:45', JiffTemporal.printOffset(secs(-2670)));
        Assert.areEqual('+00:01', JiffTemporal.printOffset(secs(30)));
        Assert.areEqual('-00:01', JiffTemporal.printOffset(secs(-30)));
        Assert.areEqual('+00:01', JiffTemporal.printOffset(secs(59)));
        Assert.areEqual('+05:01', JiffTemporal.printOffset(secs(18030)));
        Assert.areEqual('+00:00', JiffTemporal.printOffset(secs(29)));
        Assert.areEqual('+02:00', JiffTemporal.printOffset(secs(7170)));
        // The limits cannot round up to 26 hours.
        Assert.areEqual('+25:59', JiffTemporal.printOffset(JiffOffset.MAX));
        Assert.areEqual('-25:59', JiffTemporal.printOffset(JiffOffset.MIN));
    }

    @IsTest
    static void toTimeZoneMakesAFixedZone() {
        JiffTimeZone tz = hours(-4).toTimeZone();
        Assert.areEqual(JiffTimeZone.fixed(hours(-4)), tz);
        Assert.areEqual('1969-12-31T20:00:00', tz.toDateTime(JiffTimestamp.UNIX_EPOCH).toString());
    }

    @IsTest
    static void toDateTimeShiftsTheInstantByTheOffset() {
        Assert.areEqual(
            dt(1969, 12, 31, 16, 0, 0, 0),
            hours(-8).toDateTime(JiffTimestamp.UNIX_EPOCH)
        );
        JiffDateTime epoch = dt(1970, 1, 1, 0, 0, 0, 0);
        Assert.areEqual(epoch, secs(0).toDateTime(stamp(0L, 0)));
        Assert.areEqual(epoch, secs(3600).toDateTime(stamp(-3600L, 0)));
        Assert.areEqual(epoch, secs(-3600).toDateTime(stamp(3600L, 0)));
        JiffDateTime halfPastEleven = dt(1969, 12, 31, 23, 30, 0, 0);
        Assert.areEqual(halfPastEleven, secs(0).toDateTime(stamp(-1800L, 0)));
        Assert.areEqual(halfPastEleven, secs(3600).toDateTime(stamp(-5400L, 0)));
        Assert.areEqual(halfPastEleven, secs(-3600).toDateTime(stamp(1800L, 0)));
        JiffDateTime halfPastMidnight = dt(1970, 1, 1, 0, 30, 0, 0);
        Assert.areEqual(halfPastMidnight, secs(0).toDateTime(stamp(1800L, 0)));
        Assert.areEqual(halfPastMidnight, secs(3600).toDateTime(stamp(-1800L, 0)));
        Assert.areEqual(halfPastMidnight, secs(-3600).toDateTime(stamp(5400L, 0)));
    }

    @IsTest
    static void toDateTimeCountsTheFractionForwardBeforeTheEpoch() {
        JiffDateTime epoch = dt(1970, 1, 1, 0, 0, 0, 123);
        Assert.areEqual(epoch, secs(0).toDateTime(stamp(0L, 123)));
        Assert.areEqual(epoch, secs(3600).toDateTime(stamp(-3599L, -999999877)));
        Assert.areEqual(epoch, secs(-3600).toDateTime(stamp(3600L, 123)));
        JiffDateTime halfPastEleven = dt(1969, 12, 31, 23, 30, 0, 123);
        Assert.areEqual(halfPastEleven, secs(0).toDateTime(stamp(-1799L, -999999877)));
        Assert.areEqual(halfPastEleven, secs(3600).toDateTime(stamp(-5399L, -999999877)));
        Assert.areEqual(halfPastEleven, secs(-3600).toDateTime(stamp(1800L, 123)));
        JiffDateTime halfPastMidnight = dt(1970, 1, 1, 0, 30, 0, 123);
        Assert.areEqual(halfPastMidnight, secs(0).toDateTime(stamp(1800L, 123)));
        Assert.areEqual(halfPastMidnight, secs(3600).toDateTime(stamp(-1799L, -999999877)));
        Assert.areEqual(halfPastMidnight, secs(-3600).toDateTime(stamp(5400L, 123)));
    }

    @IsTest
    static void everyTimestampHasADateTimeAtEveryOffset() {
        Assert.areEqual(JiffDateTime.MIN, JiffOffset.MIN.toDateTime(JiffTimestamp.MIN));
        Assert.areEqual(JiffDateTime.MAX, JiffOffset.MAX.toDateTime(JiffTimestamp.MAX));
        // One nanosecond after the minimum, at the minimum offset.
        Assert.areEqual(
            '-009999-01-01T00:00:00.000000001',
            JiffOffset.MIN.toDateTime(stamp(-377705023201L, 1)).toString()
        );
        Assert.areEqual(
            dt(-9999, 1, 3, 3, 59, 58, 0),
            JiffOffset.MAX.toDateTime(JiffTimestamp.MIN)
        );
        Assert.areEqual(
            dt(9999, 12, 29, 20, 0, 1, 999999999),
            JiffOffset.MIN.toDateTime(JiffTimestamp.MAX)
        );
    }

    @IsTest
    static void utcDateTimesMatchJiffsSpecificExamples() {
        Long minSecond = -377705023201L;
        Long maxSecond = 253402207200L;
        assertUtc(minSecond, 0, dt(-9999, 1, 2, 1, 59, 59, 0));
        assertUtc(minSecond + 1, -999999999, dt(-9999, 1, 2, 1, 59, 59, 1));
        assertUtc(-1L, 1, dt(1969, 12, 31, 23, 59, 59, 1));
        assertUtc(maxSecond, 0, dt(9999, 12, 30, 22, 0, 0, 0));
        assertUtc(maxSecond - 1, 0, dt(9999, 12, 30, 21, 59, 59, 0));
        assertUtc(maxSecond - 1, 999999999, dt(9999, 12, 30, 21, 59, 59, 999999999));
        assertUtc(maxSecond, 999999999, dt(9999, 12, 30, 22, 0, 0, 999999999));
        assertUtc(-2L, -1, dt(1969, 12, 31, 23, 59, 57, 999999999));
        assertUtc(-86398L, -1, dt(1969, 12, 31, 0, 0, 1, 999999999));
        assertUtc(-86399L, -1, dt(1969, 12, 31, 0, 0, 0, 999999999));
        assertUtc(-86400L, -1, dt(1969, 12, 30, 23, 59, 59, 999999999));
    }

    private static void assertUtc(Long second, Integer nanosecond, JiffDateTime expected) {
        JiffTimestamp timestamp = stamp(second, nanosecond);
        Assert.areEqual(expected, JiffOffset.UTC.toDateTime(timestamp), 'timestamp ' + timestamp);
        Assert.areEqual(timestamp, JiffOffset.UTC.toTimestamp(expected), 'datetime ' + expected);
    }

    @IsTest
    static void datetimesRoundTripThroughUtcNearDayBoundaries() {
        List<Long> days = new List<Long>{ -4371586L, -1000L, -5L, 23L, 2000L, 2932895L };
        List<Long> seconds = new List<Long>{ -86400L, -10L, -1L, 0L, 1L, 10L, 86400L };
        List<Integer> nanos = new List<Integer>{ 0, 1, 5, 999999999 };
        for (Long day : days) {
            for (Long second : seconds) {
                Long total = day * 86400L + second;
                if (total < -377705023201L || total > 253402207200L) {
                    continue;
                }
                for (Integer nano : nanos) {
                    JiffTimestamp timestamp = stamp(total, nano);
                    Assert.areEqual(
                        timestamp,
                        JiffOffset.UTC.toTimestamp(JiffOffset.UTC.toDateTime(timestamp))
                    );
                }
            }
        }
    }

    @IsTest
    static void toTimestampUndoesTheOffset() {
        Assert.areEqual(
            JiffTimestamp.UNIX_EPOCH,
            hours(-8).toTimestamp(dt(1969, 12, 31, 16, 0, 0, 0))
        );
        Assert.areEqual(
            stamp(-1L, -500000000),
            hours(1).toTimestamp(dt(1970, 1, 1, 0, 59, 58, 500000000))
        );
        Assert.areEqual(
            stamp(0L, 500000000),
            hours(1).toTimestamp(dt(1970, 1, 1, 1, 0, 0, 500000000))
        );
    }

    @IsTest
    static void toTimestampRejectsInstantsBeyondTheMaximum() {
        String expected =
            'converting datetime with time zone offset `-08` to timestamp overflowed: ' +
            'parameter \'Unix timestamp seconds\' is not in the required range of ' +
            '-377705023201..=253402207200';
        try {
            hours(-8).toTimestamp(dt(9999, 12, 31, 23, 0, 0, 0));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
        // With a big enough offset even the last civil datetime fits.
        Assert.areEqual(JiffTimestamp.MAX, JiffOffset.MAX.toTimestamp(JiffDateTime.MAX));
        // One second less of offset is enough to go out of bounds.
        try {
            secs(93598).toTimestamp(JiffDateTime.MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertContains('time zone offset `+25:59:58` to timestamp overflowed', e.getMessage());
        }
    }

    @IsTest
    static void toTimestampRejectsInstantsBeforeTheMinimum() {
        try {
            hours(8).toTimestamp(dt(-9999, 1, 1, 1, 0, 0, 0));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertContains('time zone offset `+08` to timestamp overflowed', e.getMessage());
        }
        Assert.areEqual(JiffTimestamp.MIN, JiffOffset.MIN.toTimestamp(JiffDateTime.MIN));
        try {
            secs(-93598).toTimestamp(JiffDateTime.MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertContains('time zone offset `-25:59:58` to timestamp overflowed', e.getMessage());
        }
        // Half a second into that out-of-range second is still before the minimum timestamp.
        // (Jiff only catches this with debug assertions enabled; the port always does.)
        try {
            secs(-93598).toTimestamp(dt(-9999, 1, 1, 0, 0, 0, 500000000));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertContains('to timestamp overflowed', e.getMessage());
        }
    }

    @IsTest
    static void addsSpansOfWholeSeconds() {
        Assert.areEqual(hours(-4), hours(-5).add(new JiffSpan().hours(1L)));
        Assert.areEqual(hours(1), hours(-10).add(new JiffSpan().hours(11L)));
        Assert.areEqual(secs(-1), JiffOffset.UTC.add(new JiffSpan().seconds(-1L)));
        Assert.areEqual(
            secs(5430),
            JiffOffset.UTC.add(new JiffSpan().hours(1L).minutes(30L).seconds(30L))
        );
        // 900ms + 50,000us + 50,000,000ns is exactly one second.
        JiffSpan oneSecond = new JiffSpan()
            .milliseconds(900L)
            .microseconds(50000L)
            .nanoseconds(50000000L);
        Assert.areEqual(secs(18001), hours(5).add(oneSecond));
        // Any leftover fraction of a second is ignored.
        JiffSpan aLittleMore = new JiffSpan()
            .milliseconds(901L)
            .microseconds(50001L)
            .nanoseconds(50000001L);
        Assert.areEqual(secs(18001), hours(5).add(aLittleMore));
        Assert.areEqual(hours(5), hours(5).add(new JiffSpan()));
    }

    @IsTest
    static void addingASpanRejectsCalendarUnits() {
        Map<String, JiffSpan> spans = new Map<String, JiffSpan>{
            'day' => new JiffSpan().days(1L),
            'week' => new JiffSpan().weeks(1L),
            'month' => new JiffSpan().months(1L),
            'year' => new JiffSpan().years(1L)
        };
        for (String unit : spans.keySet()) {
            try {
                JiffOffset.UTC.add(spans.get(unit));
                Assert.fail('expected a span of one ' + unit + ' to be rejected');
            } catch (JiffException e) {
                assertContains(CALENDAR_UNITS + unit + '\' units', e.getMessage());
            }
            try {
                JiffOffset.UTC.subtract(spans.get(unit));
                Assert.fail('expected a span of one ' + unit + ' to be rejected');
            } catch (JiffException e) {
                assertContains(CALENDAR_UNITS + unit + '\' units', e.getMessage());
            }
        }
    }

    @IsTest
    static void addingASpanRejectsResultsOutOfRange() {
        List<JiffSpan> spans = new List<JiffSpan>{
            new JiffSpan().seconds(-1L),
            new JiffSpan().seconds(1L),
            new JiffSpan().hours(30L)
        };
        List<JiffOffset> offsets = new List<JiffOffset>{
            JiffOffset.MIN,
            JiffOffset.MAX,
            JiffOffset.UTC
        };
        for (Integer i = 0; i < spans.size(); i++) {
            try {
                offsets.get(i).add(spans.get(i));
                Assert.fail('expected an overflow adding ' + spans.get(i));
            } catch (JiffException e) {
                Assert.areEqual(RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void addsDurationsIgnoringFractions() {
        JiffSignedDuration elevenHours = JiffSignedDuration.fromHours(11L);
        Assert.areEqual(hours(1), hours(-10).add(elevenHours));
        Assert.areEqual(hours(-21), hours(-10).add(elevenHours.negate()));
        // Only whole seconds of the duration are considered.
        Assert.areEqual(
            hours(-7),
            hours(-10).add(JiffSignedDuration.newInstance(10800L, 999999999))
        );
        try {
            JiffOffset.UTC.add(JiffSignedDuration.fromHours(30L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'adding signed duration to time zone offset overflowed: ' + RANGE,
                e.getMessage()
            );
        }
        try {
            JiffOffset.MAX.add(JiffSignedDuration.fromSecs(1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(RANGE, e.getMessage());
        }
    }

    @IsTest
    static void subtractsSpansAndDurations() {
        Assert.areEqual(hours(-5), hours(-4).subtract(new JiffSpan().hours(1L)));
        Assert.areEqual(hours(-5), hours(-4).subtract(JiffSignedDuration.fromHours(1L)));
        Assert.areEqual(secs(-1), JiffOffset.UTC.subtract(new JiffSpan().seconds(1L)));
        Assert.areEqual(secs(1), JiffOffset.UTC.subtract(new JiffSpan().seconds(-1L)));
        try {
            JiffOffset.MIN.subtract(new JiffSpan().seconds(1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(RANGE, e.getMessage());
        }
        try {
            JiffOffset.MAX.subtract(JiffSignedDuration.fromSecs(-1L));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(RANGE, e.getMessage());
        }
        try {
            JiffOffset.UTC.subtract(JiffSignedDuration.MIN);
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
    static void saturatingAddClampsToTheLimits() {
        Assert.areEqual(JiffOffset.MIN, JiffOffset.MIN.saturatingAdd(new JiffSpan().seconds(-1L)));
        Assert.areEqual(JiffOffset.MAX, JiffOffset.MAX.saturatingAdd(new JiffSpan().seconds(1L)));
        Assert.areEqual(hours(-4), hours(-5).saturatingAdd(new JiffSpan().hours(1L)));
        Assert.areEqual(JiffOffset.MAX, JiffOffset.UTC.saturatingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(JiffOffset.MIN, JiffOffset.UTC.saturatingAdd(JiffSignedDuration.MIN));
        Assert.areEqual(hours(1), hours(-10).saturatingAdd(JiffSignedDuration.fromHours(11L)));
    }

    @IsTest
    static void saturatingSubtractClampsToTheLimits() {
        Assert.areEqual(
            JiffOffset.MIN,
            JiffOffset.MIN.saturatingSubtract(new JiffSpan().seconds(1L))
        );
        Assert.areEqual(
            JiffOffset.MAX,
            JiffOffset.MAX.saturatingSubtract(new JiffSpan().seconds(-1L))
        );
        Assert.areEqual(hours(-5), hours(-4).saturatingSubtract(new JiffSpan().hours(1L)));
        Assert.areEqual(JiffOffset.MIN, JiffOffset.UTC.saturatingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(JiffOffset.MAX, JiffOffset.UTC.saturatingSubtract(JiffSignedDuration.MIN));
        Assert.areEqual(hours(-5), hours(-4).saturatingSubtract(JiffSignedDuration.fromHours(1L)));
    }

    @IsTest
    static void saturatingArithmeticStillRejectsCalendarUnits() {
        for (
            JiffSpan span : new List<JiffSpan>{
                new JiffSpan().weeks(1L),
                new JiffSpan().months(1L),
                new JiffSpan().years(1L)
            }
        ) {
            try {
                JiffOffset.UTC.saturatingAdd(span);
                Assert.fail('expected ' + span + ' to be rejected');
            } catch (JiffException e) {
                assertContains(CALENDAR_UNITS, e.getMessage());
            }
            try {
                JiffOffset.UTC.saturatingSubtract(span);
                Assert.fail('expected ' + span + ' to be rejected');
            } catch (JiffException e) {
                assertContains(CALENDAR_UNITS, e.getMessage());
            }
        }
    }

    @IsTest
    static void untilAndSinceGiveSpansOfSeconds() {
        Assert.areEqual(new JiffSpan().seconds(18000L), hours(-5).until(JiffOffset.UTC));
        Assert.areEqual(new JiffSpan().seconds(-18000L), JiffOffset.UTC.until(hours(-5)));
        // The largest span there can be.
        Assert.areEqual(new JiffSpan().seconds(187198L), JiffOffset.MIN.until(JiffOffset.MAX));
        Assert.areEqual(new JiffSpan().seconds(18000L), JiffOffset.UTC.since(hours(-5)));
        Assert.areEqual(new JiffSpan().seconds(-18000L), hours(-5).since(JiffOffset.UTC));
        Assert.areEqual(new JiffSpan(), hours(3).until(hours(3)));
    }

    @IsTest
    static void durationUntilAndSinceGiveExactDurations() {
        Assert.areEqual(JiffSignedDuration.fromHours(5L), hours(-5).durationUntil(JiffOffset.UTC));
        Assert.areEqual(JiffSignedDuration.fromHours(-5L), JiffOffset.UTC.durationUntil(hours(-5)));
        Assert.areEqual(JiffSignedDuration.fromHours(5L), JiffOffset.UTC.durationSince(hours(-5)));
        Assert.areEqual(JiffSignedDuration.fromHours(-5L), hours(-5).durationSince(JiffOffset.UTC));
        Assert.areEqual(
            JiffSignedDuration.fromSecs(187198L),
            JiffOffset.MIN.durationUntil(JiffOffset.MAX)
        );
    }

    @IsTest
    static void roundsToHoursMinutesOrSeconds() {
        Assert.areEqual(
            secs(-2700),
            secs(-2670).round(JiffRound.to(JiffUnit.MINUTE).increment(15L))
        );
        Assert.areEqual(hours(-5), secs(-18030).round(JiffUnit.HOUR));
        Assert.areEqual(
            secs(16200),
            secs(15300).round(JiffRound.to(JiffUnit.MINUTE).increment(30L))
        );
        Assert.areEqual(
            secs(16200),
            secs(15420)
                .round(JiffRound.to(JiffUnit.MINUTE).increment(30L).mode(JiffRoundMode.EXPAND))
        );
        // -05:30 rounds to -06 by default, and to -05 when truncating.
        Assert.areEqual(hours(-6), secs(-19800).round(JiffUnit.HOUR));
        Assert.areEqual(
            hours(-5),
            secs(-19800).round(JiffRound.to(JiffUnit.HOUR).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(secs(-2670), secs(-2670).round(JiffUnit.SECOND));
    }

    @IsTest
    static void roundingCanOverflow() {
        List<JiffOffset> extremes = new List<JiffOffset>{ JiffOffset.MAX, JiffOffset.MIN };
        List<JiffUnit> units = new List<JiffUnit>{ JiffUnit.MINUTE, JiffUnit.HOUR };
        for (JiffOffset offset : extremes) {
            for (JiffUnit unit : units) {
                try {
                    offset.round(unit);
                    Assert.fail('expected rounding ' + offset + ' to the ' + unit + ' to overflow');
                } catch (JiffException e) {
                    Assert.areEqual(
                        'rounding time zone offset resulted in a duration that overflows: ' + RANGE,
                        e.getMessage()
                    );
                }
            }
        }
    }

    @IsTest
    static void roundingRejectsUnitsAnOffsetCannotHave() {
        Map<String, JiffRound> options = new Map<String, JiffRound>{
            'day' => JiffRound.to(JiffUnit.DAY),
            // The default smallest unit of JiffRound.
            'nanosecond' => new JiffRound(),
            'millisecond' => JiffRound.to(JiffUnit.MILLISECOND)
        };
        for (String unit : options.keySet()) {
            try {
                JiffOffset.UTC.round(options.get(unit));
                Assert.fail('expected rounding to ' + unit + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    '\'' +
                        unit +
                        '\' not allowed when rounding time zone offset ' +
                        '(must use hours, minutes or seconds)',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void ordersFromWestToEast() {
        Assert.isTrue(hours(-5).compareTo(hours(-4)) < 0);
        Assert.isTrue(hours(5).compareTo(hours(-4)) > 0);
        Assert.areEqual(0, hours(5).compareTo(secs(18000)));
        Assert.isTrue(JiffOffset.MIN.compareTo(JiffOffset.MAX) < 0);
        List<JiffOffset> offsets = new List<JiffOffset>{ hours(3), JiffOffset.MIN, hours(-3) };
        offsets.sort();
        Assert.areEqual(JiffOffset.MIN, offsets.get(0));
        Assert.areEqual(hours(3), offsets.get(2));
    }

    @IsTest
    static void equalOffsetsAreInterchangeable() {
        Assert.areEqual(hours(5), secs(18000));
        Assert.areEqual(hours(5).hashCode(), secs(18000).hashCode());
        Assert.areNotEqual(hours(5), hours(-5));
        Assert.isFalse(hours(5).equals('+05'));
        Map<JiffOffset, String> names = new Map<JiffOffset, String>{ hours(-5) => 'EST' };
        Assert.areEqual('EST', names.get(secs(-18000)));
    }

    @IsTest
    static void offsetConflictNamesJiffsFourStrategies() {
        List<JiffOffsetConflict> strategies = JiffOffsetConflict.values();
        Assert.areEqual(4, strategies.size());
        Assert.areEqual(JiffOffsetConflict.ALWAYS_OFFSET, strategies.get(0));
        Assert.areEqual(JiffOffsetConflict.ALWAYS_TIME_ZONE, strategies.get(1));
        Assert.areEqual(JiffOffsetConflict.PREFER_OFFSET, strategies.get(2));
        Assert.areEqual(JiffOffsetConflict.REJECT, strategies.get(3));
    }
}
