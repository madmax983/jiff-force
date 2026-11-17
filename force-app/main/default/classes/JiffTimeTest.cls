@IsTest
private class JiffTimeTest {
    private static void assertRejected(
        Integer h,
        Integer m,
        Integer s,
        Integer ns,
        String expected
    ) {
        try {
            JiffTime.newInstance(h, m, s, ns);
            Assert.fail('expected the time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void exposesItsComponents() {
        JiffTime t = JiffTime.newInstance(15, 22, 45, 123456789);
        Assert.areEqual(15, t.hour());
        Assert.areEqual(22, t.minute());
        Assert.areEqual(45, t.second());
        Assert.areEqual(123, t.millisecond());
        Assert.areEqual(456, t.microsecond());
        Assert.areEqual(789, t.nanosecond());
        Assert.areEqual(123456789, t.subsecNanosecond());
        Assert.areEqual(55365, t.toSecondOfDay());
        Assert.areEqual(55365123456789L, t.toNanosecondOfDay());
    }

    @IsTest
    static void rejectsOutOfRangeComponentsWithJiffsWording() {
        assertRejected(24, 0, 0, 0, 'parameter \'hour\' is not in the required range of 0..=23');
        assertRejected(-1, 0, 0, 0, 'parameter \'hour\' is not in the required range of 0..=23');
        assertRejected(0, 60, 0, 0, 'parameter \'minute\' is not in the required range of 0..=59');
        assertRejected(0, -1, 0, 0, 'parameter \'minute\' is not in the required range of 0..=59');
        // There is no leap second: 23:59:60 is not a valid civil time.
        assertRejected(
            23,
            59,
            60,
            0,
            'parameter \'second\' is not in the required range of 0..=59'
        );
        assertRejected(0, 0, -1, 0, 'parameter \'second\' is not in the required range of 0..=59');
        assertRejected(
            0,
            0,
            0,
            1000000000,
            'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
        );
        assertRejected(
            0,
            0,
            0,
            -1,
            'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
        );
    }

    @IsTest
    static void hasNamedBoundaries() {
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 0), JiffTime.MIN);
        Assert.areEqual(JiffTime.MIN, JiffTime.midnight());
        Assert.areEqual(JiffTime.newInstance(23, 59, 59, 999999999), JiffTime.MAX);
        Assert.areEqual(0L, JiffTime.MIN.toNanosecondOfDay());
        Assert.areEqual(86399999999999L, JiffTime.MAX.toNanosecondOfDay());
    }

    @IsTest
    static void convertsToAndFromNanosecondsSinceMidnight() {
        Assert.areEqual(JiffTime.MIN, JiffTime.fromNanosecondOfDay(0L));
        Assert.areEqual(JiffTime.MAX, JiffTime.fromNanosecondOfDay(86399999999999L));
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 1), JiffTime.fromNanosecondOfDay(1L));
        Assert.areEqual(
            JiffTime.newInstance(0, 0, 1, 0),
            JiffTime.fromNanosecondOfDay(1000000000L)
        );
        Assert.areEqual(
            JiffTime.newInstance(1, 0, 0, 0),
            JiffTime.fromNanosecondOfDay(3600000000000L)
        );
        Assert.areEqual(
            JiffTime.newInstance(15, 22, 45, 123456789),
            JiffTime.fromNanosecondOfDay(55365123456789L)
        );
        // A prime step visits every hour, minute and second boundary pattern over the day.
        for (Long nanos = 0L; nanos < 86400000000000L; nanos += 86028121000037L / 1000) {
            Assert.areEqual(nanos, JiffTime.fromNanosecondOfDay(nanos).toNanosecondOfDay());
        }
        for (Long bad : new List<Long>{ -1L, 86400000000000L }) {
            try {
                JiffTime.fromNanosecondOfDay(bad);
                Assert.fail('expected an out of range nanosecond to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'nanoseconds (in one civil day)\' is not in the required range of 0..=86399999999999',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void ordersFromMidnightOnward() {
        JiffTime noon = JiffTime.newInstance(12, 0, 0, 0);
        Assert.areEqual(0, noon.compareTo(JiffTime.newInstance(12, 0, 0, 0)));
        Assert.areEqual(-1, noon.compareTo(JiffTime.newInstance(12, 0, 0, 1)));
        Assert.areEqual(1, noon.compareTo(JiffTime.newInstance(11, 59, 59, 999999999)));
        Assert.isTrue(JiffTime.MIN.isBefore(JiffTime.MAX));
        Assert.isTrue(JiffTime.MAX.isAfter(noon));
        Assert.isFalse(noon.isBefore(noon));
        List<JiffTime> times = new List<JiffTime>{ JiffTime.MAX, noon, JiffTime.MIN };
        times.sort();
        Assert.areEqual(JiffTime.MIN, times.get(0));
        Assert.areEqual(noon, times.get(1));
        Assert.areEqual(JiffTime.MAX, times.get(2));
    }

    @IsTest
    static void equalsAndHashesByValue() {
        JiffTime t = JiffTime.newInstance(15, 22, 45, 5);
        Assert.isTrue(t.equals(JiffTime.newInstance(15, 22, 45, 5)));
        Assert.areEqual(t.hashCode(), JiffTime.newInstance(15, 22, 45, 5).hashCode());
        Assert.isFalse(t.equals(JiffTime.newInstance(15, 22, 45, 6)));
        Assert.isFalse(t.equals('15:22:45.000000005'));
        Map<JiffTime, String> names = new Map<JiffTime, String>{
            JiffTime.midnight() => 'midnight'
        };
        Assert.areEqual('midnight', names.get(JiffTime.newInstance(0, 0, 0, 0)));
    }

    @IsTest
    static void printsIso8601WithOnlyTheFractionItNeeds() {
        Assert.areEqual('00:00:00', JiffTime.MIN.toString());
        Assert.areEqual('15:22:45', JiffTime.newInstance(15, 22, 45, 0).toString());
        Assert.areEqual('15:22:45.5', JiffTime.newInstance(15, 22, 45, 500000000).toString());
        Assert.areEqual('15:22:45.123', JiffTime.newInstance(15, 22, 45, 123000000).toString());
        Assert.areEqual('15:22:45.000001', JiffTime.newInstance(15, 22, 45, 1000).toString());
        Assert.areEqual('05:02:01.000000001', JiffTime.newInstance(5, 2, 1, 1).toString());
        Assert.areEqual('23:59:59.999999999', JiffTime.MAX.toString());
    }

    // Everything below takes its expected values from the examples in the doc comments of
    // `jiff::civil::Time`, from the test module of `jiff/src/civil/time.rs`, and, for the
    // remaining edge cases and all error messages, from the output of Jiff 1.0.0 itself.

    private static JiffTime t(Integer h, Integer m, Integer s, Integer ns) {
        return JiffTime.newInstance(h, m, s, ns);
    }

    // ---- platform interop -------------------------------------------------

    @IsTest
    static void convertsFromAPlatformTime() {
        Assert.areEqual(
            t(15, 22, 45, 123000000),
            JiffTime.fromSystemTime(Time.newInstance(15, 22, 45, 123))
        );
        Assert.areEqual(JiffTime.MIN, JiffTime.fromSystemTime(Time.newInstance(0, 0, 0, 0)));
        Assert.areEqual(
            t(23, 59, 59, 999000000),
            JiffTime.fromSystemTime(Time.newInstance(23, 59, 59, 999))
        );
    }

    @IsTest
    static void rejectsANullPlatformTime() {
        try {
            JiffTime.fromSystemTime(null);
            Assert.fail('expected a null platform time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('cannot convert a null system time to a `JiffTime`', e.getMessage());
        }
    }

    @IsTest
    static void convertsToAPlatformTimeDroppingAnythingBelowAMillisecond() {
        Assert.areEqual(Time.newInstance(15, 22, 45, 123), t(15, 22, 45, 123456789).toSystemTime());
        Assert.areEqual(Time.newInstance(0, 0, 0, 0), JiffTime.MIN.toSystemTime());
        // Truncated, not rounded: the last nanosecond of the day stays within the day.
        Time last = JiffTime.MAX.toSystemTime();
        Assert.areEqual(23, last.hour());
        Assert.areEqual(59, last.minute());
        Assert.areEqual(59, last.second());
        Assert.areEqual(999, last.millisecond());
        Assert.areEqual(Time.newInstance(1, 2, 3, 0), t(1, 2, 3, 999999).toSystemTime());
    }

    @IsTest
    static void platformTimesRoundTripAtMillisecondPrecision() {
        List<Time> platformTimes = new List<Time>{
            Time.newInstance(0, 0, 0, 0),
            Time.newInstance(0, 0, 0, 1),
            Time.newInstance(12, 34, 56, 789),
            Time.newInstance(23, 59, 59, 999)
        };
        for (Time platformTime : platformTimes) {
            Assert.areEqual(platformTime, JiffTime.fromSystemTime(platformTime).toSystemTime());
        }
    }

    // ---- until and since ----------------------------------------------------

    @IsTest
    static void untilGivesTheSpanBetweenTwoTimes() {
        JiffTime t1 = t(22, 35, 1, 0);
        JiffTime t2 = t(22, 35, 3, 500000000);
        Assert.areEqual(new JiffSpan().seconds(2).milliseconds(500), t1.until(t2));
        // Flipping the times gives a negative span.
        Assert.areEqual(new JiffSpan().seconds(-2).milliseconds(-500), t2.until(t1));
        Assert.areEqual('PT2.5S', t1.until(t2).toString());
        Assert.areEqual('-PT2.5S', t2.until(t1).toString());
    }

    @IsTest
    static void untilUsesHoursAsTheLargestUnitByDefault() {
        Assert.areEqual('PT12H5M29.9999965S', t(3, 24, 30, 3500).until(t(15, 30, 0, 0)).toString());
        Assert.areEqual(
            new JiffSpan()
                .hours(23)
                .minutes(59)
                .seconds(59)
                .milliseconds(999)
                .microseconds(999)
                .nanoseconds(999),
            JiffTime.MIN.until(JiffTime.MAX)
        );
        Assert.areEqual(
            new JiffSpan().hours(-1).minutes(-49).seconds(-59),
            t(22, 0, 0, 0).until(t(20, 10, 1, 0))
        );
    }

    @IsTest
    static void untilATimeEqualToItselfIsAZeroSpan() {
        JiffTime noon = t(12, 0, 0, 0);
        Assert.areEqual(new JiffSpan(), noon.until(t(12, 0, 0, 0)));
        Assert.areEqual(new JiffSpan(), noon.until(noon, JiffUnit.SECOND));
        Assert.areEqual(new JiffSpan(), noon.since(noon));
    }

    @IsTest
    static void untilBalancesDownToTheRequestedLargestUnit() {
        JiffTime t1 = t(3, 24, 30, 3500);
        JiffTime t2 = t(15, 30, 0, 0);
        Assert.areEqual('PT725M29.9999965S', t1.until(t2, JiffUnit.MINUTE).toString());
        Assert.areEqual(
            new JiffSpan()
                .hours(12)
                .minutes(5)
                .seconds(29)
                .milliseconds(999)
                .microseconds(996)
                .nanoseconds(500),
            t1.until(t2, JiffUnit.HOUR)
        );
        Assert.areEqual(
            new JiffSpan()
                .minutes(725)
                .seconds(29)
                .milliseconds(999)
                .microseconds(996)
                .nanoseconds(500),
            t1.until(t2, JiffUnit.MINUTE)
        );
        Assert.areEqual(
            new JiffSpan().seconds(43529).milliseconds(999).microseconds(996).nanoseconds(500),
            t1.until(t2, JiffUnit.SECOND)
        );
        Assert.areEqual(
            new JiffSpan().milliseconds(43529999).microseconds(996).nanoseconds(500),
            t1.until(t2, JiffUnit.MILLISECOND)
        );
        Assert.areEqual(
            new JiffSpan().microseconds(43529999996L).nanoseconds(500),
            t1.until(t2, JiffUnit.MICROSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(43529999996500L),
            t1.until(t2, JiffUnit.NANOSECOND)
        );
        Assert.areEqual(
            new JiffSpan().seconds(960),
            t(8, 14, 0, 0).until(t(8, 30, 0, 0), JiffUnit.SECOND)
        );
    }

    @IsTest
    static void untilCoversTheWholeDayInEveryUnit() {
        Assert.areEqual(
            new JiffSpan()
                .minutes(1439)
                .seconds(59)
                .milliseconds(999)
                .microseconds(999)
                .nanoseconds(999),
            JiffTime.MIN.until(JiffTime.MAX, JiffUnit.MINUTE)
        );
        Assert.areEqual(
            new JiffSpan().seconds(86399).milliseconds(999).microseconds(999).nanoseconds(999),
            JiffTime.MIN.until(JiffTime.MAX, JiffUnit.SECOND)
        );
        Assert.areEqual(
            new JiffSpan().milliseconds(86399999).microseconds(999).nanoseconds(999),
            JiffTime.MIN.until(JiffTime.MAX, JiffUnit.MILLISECOND)
        );
        Assert.areEqual(
            new JiffSpan().microseconds(86399999999L).nanoseconds(999),
            JiffTime.MIN.until(JiffTime.MAX, JiffUnit.MICROSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(86399999999999L),
            JiffTime.MIN.until(JiffTime.MAX, JiffUnit.NANOSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(-86399999999999L),
            JiffTime.MAX.until(JiffTime.MIN, JiffUnit.NANOSECOND)
        );
    }

    @IsTest
    static void sinceIsUntilWithTheOperandsSwapped() {
        Assert.areEqual(new JiffSpan().hours(21).minutes(30), t(22, 30, 0, 0).since(t(1, 0, 0, 0)));
        Assert.areEqual(
            new JiffSpan().hours(1).minutes(49).seconds(59),
            t(22, 0, 0, 0).since(t(20, 10, 1, 0))
        );
        JiffTime t1 = t(22, 35, 1, 0);
        JiffTime t2 = t(22, 35, 3, 500000000);
        Assert.areEqual(new JiffSpan().seconds(-2).milliseconds(-500), t1.since(t2));
        Assert.areEqual(new JiffSpan().seconds(2).milliseconds(500), t2.since(t1));
    }

    @IsTest
    static void sinceBalancesDownToTheRequestedLargestUnit() {
        Assert.areEqual(
            new JiffSpan().minutes(990),
            t(23, 30, 0, 0).since(t(7, 0, 0, 0), JiffUnit.MINUTE)
        );
        Assert.areEqual(
            new JiffSpan().minutes(-990),
            t(7, 0, 0, 0).since(t(23, 30, 0, 0), JiffUnit.MINUTE)
        );
        Assert.areEqual(
            new JiffSpan().milliseconds(-43529999).microseconds(-996).nanoseconds(-500),
            t(3, 24, 30, 3500).since(t(15, 30, 0, 0), JiffUnit.MILLISECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(-86399999999999L),
            JiffTime.MIN.since(JiffTime.MAX, JiffUnit.NANOSECOND)
        );
    }

    @IsTest
    static void untilAndSinceRejectALargestUnitBiggerThanHours() {
        Map<JiffUnit, String> names = new Map<JiffUnit, String>{
            JiffUnit.DAY => 'day',
            JiffUnit.WEEK => 'week',
            JiffUnit.MONTH => 'month',
            JiffUnit.YEAR => 'year'
        };
        for (JiffUnit unit : names.keySet()) {
            String expected =
                '\'' +
                names.get(unit) +
                '\' not allowed as a time unit for rounding span';
            try {
                t(1, 0, 0, 0).until(t(2, 0, 0, 0), unit);
                Assert.fail('expected until to reject ' + unit);
            } catch (JiffException e) {
                Assert.areEqual(expected, e.getMessage());
            }
            try {
                // Even when the two times are equal.
                t(1, 0, 0, 0).since(t(1, 0, 0, 0), unit);
                Assert.fail('expected since to reject ' + unit);
            } catch (JiffException e) {
                Assert.areEqual(expected, e.getMessage());
            }
        }
    }

    @IsTest
    static void addingTheSpanFromUntilGivesTheOtherTimeBack() {
        // Jiff states these as properties of `until` and `since` for all pairs of times.
        List<JiffTime> times = new List<JiffTime>{
            JiffTime.MIN,
            t(0, 0, 0, 1),
            t(3, 24, 30, 3500),
            t(12, 0, 0, 0),
            t(15, 22, 45, 123456789),
            t(23, 59, 59, 0),
            JiffTime.MAX
        };
        for (JiffTime t1 : times) {
            for (JiffTime t2 : times) {
                JiffSpan forwards = t1.until(t2);
                Assert.areEqual(t2, t1.add(forwards));
                Assert.areEqual(t1, t2.subtract(forwards));
                JiffSpan backwards = t1.since(t2);
                Assert.areEqual(t1, t2.add(backwards));
                Assert.areEqual(t2, t1.subtract(backwards));
                Assert.areEqual(forwards, backwards.negate());
                Assert.areEqual(
                    t1.until(t2, JiffUnit.NANOSECOND).getNanoseconds(),
                    t1.since(t2, JiffUnit.NANOSECOND).negate().getNanoseconds()
                );
                Assert.areEqual(t2, t1.add(t1.durationUntil(t2)));
            }
        }
    }

    // ---- durations between times --------------------------------------------

    @IsTest
    static void durationUntilGivesTheElapsedTimeBetweenTwoTimes() {
        JiffTime t1 = t(22, 35, 1, 0);
        JiffTime t2 = t(22, 35, 3, 500000000);
        Assert.areEqual(JiffSignedDuration.newInstance(2L, 500000000), t1.durationUntil(t2));
        Assert.areEqual(JiffSignedDuration.newInstance(-2L, -500000000), t2.durationUntil(t1));
        Assert.areEqual(JiffSignedDuration.ZERO, t1.durationUntil(t1));
        Assert.areEqual(
            JiffSignedDuration.newInstance(86399L, 999999999),
            JiffTime.MIN.durationUntil(JiffTime.MAX)
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(-86399L, -999999999),
            JiffTime.MAX.durationUntil(JiffTime.MIN)
        );
    }

    @IsTest
    static void durationSinceIsDurationUntilWithTheOperandsSwapped() {
        Assert.areEqual(
            JiffSignedDuration.fromSecs(21L * 60L * 60L + 30L * 60L),
            t(22, 30, 0, 0).durationSince(t(1, 0, 0, 0))
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(-86399L, -999999999),
            JiffTime.MIN.durationSince(JiffTime.MAX)
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(86399L, 999999999),
            JiffTime.MAX.durationSince(JiffTime.MIN)
        );
    }

    // ---- rounding -------------------------------------------------------------

    private static void assertRoundFails(JiffRound options, String expected) {
        try {
            JiffTime.MIN.round(options);
            Assert.fail('expected the rounding options to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('failed rounding time: ' + expected, e.getMessage());
        }
    }

    @IsTest
    static void roundsToTheNearestUnitWithTiesGoingUp() {
        Assert.areEqual(t(15, 45, 10, 0), t(15, 45, 10, 123456789).round(JiffUnit.SECOND));
        Assert.areEqual(t(15, 45, 11, 0), t(15, 45, 10, 500000001).round(JiffUnit.SECOND));
        Assert.areEqual(t(15, 45, 11, 0), t(15, 45, 10, 999999999).round(JiffUnit.SECOND));
        Assert.areEqual(t(16, 25, 0, 0), t(16, 24, 59, 500000000).round(JiffUnit.SECOND));
        Assert.areEqual(t(3, 26, 0, 0), t(3, 25, 30, 0).round(JiffUnit.MINUTE));
        Assert.areEqual(
            t(3, 26, 0, 0),
            t(3, 25, 30, 0).round(new JiffRound().smallest(JiffUnit.MINUTE))
        );
    }

    @IsTest
    static void roundingWithTheDefaultOptionsChangesNothing() {
        JiffTime original = t(15, 45, 10, 123456789);
        Assert.areEqual(original, original.round(new JiffRound()));
        Assert.areEqual(original, original.round(JiffUnit.NANOSECOND));
        Assert.areEqual(JiffTime.MAX, JiffTime.MAX.round(JiffUnit.NANOSECOND));
    }

    @IsTest
    static void roundsWithTheRequestedMode() {
        Assert.areEqual(
            t(15, 45, 10, 0),
            t(15, 45, 10, 999999999).round(JiffRound.to(JiffUnit.SECOND).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(
            t(16, 24, 59, 0),
            t(16, 24, 59, 500000000).round(JiffRound.to(JiffUnit.SECOND).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(
            t(3, 26, 0, 0),
            t(3, 25, 1, 0).round(JiffRound.to(JiffUnit.MINUTE).mode(JiffRoundMode.CEIL))
        );
    }

    @IsTest
    static void everyRoundingModeMatchesJiff() {
        // Columns: 10:30, 11:30, 10:29:59.999999999 and 23:30 rounded to the hour (as that
        // hour), then the last nanosecond of the day rounded to the half hour (as HHMM).
        Map<JiffRoundMode, List<Integer>> expected = new Map<JiffRoundMode, List<Integer>>{
            JiffRoundMode.CEIL => new List<Integer>{ 11, 12, 11, 0, 0 },
            JiffRoundMode.FLOOR => new List<Integer>{ 10, 11, 10, 23, 2330 },
            JiffRoundMode.EXPAND => new List<Integer>{ 11, 12, 11, 0, 0 },
            JiffRoundMode.TRUNC => new List<Integer>{ 10, 11, 10, 23, 2330 },
            JiffRoundMode.HALF_CEIL => new List<Integer>{ 11, 12, 10, 0, 0 },
            JiffRoundMode.HALF_FLOOR => new List<Integer>{ 10, 11, 10, 23, 0 },
            JiffRoundMode.HALF_EXPAND => new List<Integer>{ 11, 12, 10, 0, 0 },
            JiffRoundMode.HALF_TRUNC => new List<Integer>{ 10, 11, 10, 23, 0 },
            JiffRoundMode.HALF_EVEN => new List<Integer>{ 10, 12, 10, 0, 0 }
        };
        Assert.areEqual(JiffRoundMode.values().size(), expected.size());
        for (JiffRoundMode mode : expected.keySet()) {
            List<Integer> row = expected.get(mode);
            JiffRound toHour = JiffRound.to(JiffUnit.HOUR).mode(mode);
            String message = 'mode ' + mode;
            Assert.areEqual(t(row.get(0), 0, 0, 0), t(10, 30, 0, 0).round(toHour), message);
            Assert.areEqual(t(row.get(1), 0, 0, 0), t(11, 30, 0, 0).round(toHour), message);
            Assert.areEqual(
                t(row.get(2), 0, 0, 0),
                t(10, 29, 59, 999999999).round(toHour),
                message
            );
            Assert.areEqual(t(row.get(3), 0, 0, 0), t(23, 30, 0, 0).round(toHour), message);
            Assert.areEqual(
                t(row.get(4) / 100, Math.mod(row.get(4), 100), 0, 0),
                JiffTime.MAX.round(JiffRound.to(JiffUnit.MINUTE).increment(30).mode(mode)),
                message
            );
        }
    }

    @IsTest
    static void roundsToAnIncrementOfTheSmallestUnit() {
        Assert.areEqual(
            t(15, 0, 0, 0),
            t(16, 27, 29, 999999999).round(JiffRound.to(JiffUnit.HOUR).increment(3))
        );
        JiffRound fiveMinutes = JiffRound.to(JiffUnit.MINUTE).increment(5);
        Assert.areEqual(t(15, 25, 0, 0), t(15, 27, 29, 999999999).round(fiveMinutes));
        Assert.areEqual(t(15, 30, 0, 0), t(15, 27, 30, 0).round(fiveMinutes));
        Assert.areEqual(
            t(3, 20, 0, 0),
            t(3, 24, 59, 0).round(JiffRound.to(JiffUnit.MINUTE).increment(10))
        );
        Assert.areEqual(
            t(22, 30, 0, 0),
            t(22, 15, 0, 0).round(JiffRound.to(JiffUnit.MINUTE).increment(30))
        );
        Assert.areEqual(
            t(1, 2, 45, 0),
            t(1, 2, 37, 500000000).round(JiffRound.to(JiffUnit.SECOND).increment(15))
        );
        Assert.areEqual(
            t(1, 2, 3, 500000000),
            t(1, 2, 3, 250000000).round(JiffRound.to(JiffUnit.MILLISECOND).increment(500))
        );
        Assert.areEqual(
            t(1, 2, 3, 123500000),
            t(1, 2, 3, 123456789).round(JiffRound.to(JiffUnit.MICROSECOND).increment(250))
        );
        Assert.areEqual(
            t(1, 2, 3, 123456800),
            t(1, 2, 3, 123456789).round(JiffRound.to(JiffUnit.NANOSECOND).increment(100))
        );
        JiffRound halfDays = JiffRound.to(JiffUnit.HOUR).increment(12);
        Assert.areEqual(t(12, 0, 0, 0), t(17, 59, 59, 999999999).round(halfDays));
        Assert.areEqual(t(0, 0, 0, 0), t(18, 0, 0, 0).round(halfDays));
    }

    @IsTest
    static void roundingUpPastTheEndOfTheDayWrapsToMidnight() {
        JiffTime last = t(23, 59, 59, 999999999);
        Assert.areEqual(last, last.round(JiffUnit.NANOSECOND));
        Assert.areEqual(t(0, 0, 0, 0), last.round(JiffUnit.MICROSECOND));
        Assert.areEqual(t(0, 0, 0, 0), last.round(JiffUnit.MILLISECOND));
        Assert.areEqual(t(0, 0, 0, 0), last.round(JiffUnit.SECOND));
        Assert.areEqual(t(0, 0, 0, 0), last.round(JiffUnit.MINUTE));
        Assert.areEqual(t(0, 0, 0, 0), last.round(JiffUnit.HOUR));
        Assert.areEqual(JiffTime.MIN, JiffTime.MAX.round(JiffUnit.HOUR));
    }

    @IsTest
    static void roundingRejectsUnitsBiggerThanHours() {
        assertRoundFails(JiffRound.to(JiffUnit.DAY), 'rounding to \'days\' is not supported');
        assertRoundFails(JiffRound.to(JiffUnit.YEAR), 'rounding to \'years\' is not supported');
        try {
            JiffTime.MIN.round(JiffUnit.WEEK);
            Assert.fail('expected rounding to weeks to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed rounding time: rounding to \'weeks\' is not supported',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void roundingRejectsIncrementsThatDoNotDivideTheNextUnit() {
        assertRoundFails(
            JiffRound.to(JiffUnit.MINUTE).increment(7),
            'increment for rounding to \'minutes\' must divide into `60` evenly'
        );
        assertRoundFails(
            JiffRound.to(JiffUnit.MINUTE).increment(60),
            'increment for rounding to \'minutes\' must divide into `60` evenly'
        );
        assertRoundFails(
            JiffRound.to(JiffUnit.HOUR).increment(24),
            'increment for rounding to \'hours\' must divide into `24` evenly'
        );
        assertRoundFails(
            JiffRound.to(JiffUnit.NANOSECOND).increment(1000),
            'increment for rounding to \'nanoseconds\' must divide into `1000` evenly'
        );
    }

    @IsTest
    static void roundingRejectsIncrementsOutOfRange() {
        String expected = 'parameter \'rounding increment\' is not in the required range of 1..=1000000000';
        assertRoundFails(JiffRound.to(JiffUnit.NANOSECOND).increment(0), expected);
        assertRoundFails(JiffRound.to(JiffUnit.NANOSECOND).increment(-1), expected);
        assertRoundFails(JiffRound.to(JiffUnit.NANOSECOND).increment(1000000001), expected);
    }

    // ---- combining with a date ------------------------------------------

    @IsTest
    static void combinesWithADateIntoADatetime() {
        JiffDate day = JiffDate.newInstance(2010, 3, 14);
        JiffTime halfPastTwo = t(2, 30, 0, 0);
        Assert.areEqual(JiffDateTime.fromParts(day, halfPastTwo), halfPastTwo.toDateTime(day));
        Assert.areEqual('2010-03-14T02:30:00', halfPastTwo.toDateTime(day).toString());
        try {
            JiffDateTime unexpected = halfPastTwo.toDateTime(null);
            Assert.fail('expected a missing date to be rejected but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual('a datetime needs both a date and a time', e.getMessage());
        }
    }

    @IsTest
    static void buildsADatetimeOnTheGivenDate() {
        Assert.areEqual('2010-03-14T02:30:00', t(2, 30, 0, 0).onDate(2010, 3, 14).toString());
        Assert.areEqual(
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 123456789),
            t(15, 22, 45, 123456789).onDate(2024, 2, 29)
        );
        // It is the same datetime that `JiffDate.at` builds from the other side.
        Assert.areEqual(
            JiffDate.newInstance(2010, 3, 14).at(2, 30, 0, 0),
            t(2, 30, 0, 0).onDate(2010, 3, 14)
        );
        try {
            JiffDateTime unexpected = t(2, 30, 0, 0).onDate(2023, 2, 29);
            Assert.fail('expected an invalid date to be rejected but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`',
                e.getMessage()
            );
        }
    }
}
