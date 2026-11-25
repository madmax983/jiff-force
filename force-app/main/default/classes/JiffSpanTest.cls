@IsTest
private class JiffSpanTest {
    private static void assertRangeError(String unit, Long max, String message) {
        Assert.areEqual(
            'parameter \'' + unit + '\' is not in the required range of -' + max + '..=' + max,
            message
        );
    }

    @IsTest
    static void startsAtZero() {
        JiffSpan span = new JiffSpan();
        Assert.isTrue(span.isZero());
        Assert.isFalse(span.isPositive());
        Assert.isFalse(span.isNegative());
        Assert.areEqual(0, span.signum());
        Assert.areEqual('PT0S', span.toString());
        Assert.areEqual(JiffUnit.NANOSECOND, span.largestUnit());
        Assert.areEqual(JiffUnit.NANOSECOND, span.smallestUnit());
        Assert.isNull(span.largestCalendarUnit());
        for (JiffUnit unit : JiffUnit.values()) {
            Assert.areEqual(0L, span.get(unit));
            Assert.isFalse(span.hasUnit(unit));
        }
    }

    @IsTest
    static void settersAndGettersRoundTripEveryUnit() {
        JiffSpan span = new JiffSpan()
            .years(1)
            .months(2)
            .weeks(3)
            .days(4)
            .hours(5)
            .minutes(6)
            .seconds(7)
            .milliseconds(8)
            .microseconds(9)
            .nanoseconds(10);
        Assert.areEqual(1L, span.getYears());
        Assert.areEqual(2L, span.getMonths());
        Assert.areEqual(3L, span.getWeeks());
        Assert.areEqual(4L, span.getDays());
        Assert.areEqual(5L, span.getHours());
        Assert.areEqual(6L, span.getMinutes());
        Assert.areEqual(7L, span.getSeconds());
        Assert.areEqual(8L, span.getMilliseconds());
        Assert.areEqual(9L, span.getMicroseconds());
        Assert.areEqual(10L, span.getNanoseconds());
        Assert.areEqual(1, span.signum());
        Assert.areEqual(JiffUnit.YEAR, span.largestUnit());
        Assert.areEqual(JiffUnit.NANOSECOND, span.smallestUnit());
        Assert.areEqual(JiffUnit.YEAR, span.largestCalendarUnit());
        Assert.areEqual('P1Y2M3W4DT5H6M7.00800901S', span.toString());
    }

    @IsTest
    static void oneNegativeUnitMakesTheWholeSpanNegative() {
        JiffSpan span = new JiffSpan().years(1).months(-1);
        Assert.isTrue(span.isNegative());
        Assert.areEqual(-1L, span.getYears());
        Assert.areEqual(-1L, span.getMonths());
        Assert.areEqual(1L, span.getAbs(JiffUnit.YEAR));
        Assert.areEqual('-P1Y1M', span.toString());
        // Setting a later unit to a positive value does not flip the sign back.
        Assert.areEqual('-P1Y1M5D', span.days(5).toString());
        Assert.areEqual(-5L, span.days(5).getDays());
    }

    @IsTest
    static void zeroingTheLastUnitClearsTheSign() {
        JiffSpan negative = new JiffSpan().hours(-3);
        Assert.areEqual(-1, negative.signum());
        Assert.areEqual(0, negative.hours(0).signum());
        Assert.areEqual(1, negative.hours(0).minutes(5).signum());
        // Zeroing one of several units keeps the sign.
        JiffSpan two = new JiffSpan().hours(-3).minutes(4);
        Assert.areEqual(-1, two.hours(0).signum());
        Assert.areEqual(-4L, two.hours(0).getMinutes());
        Assert.areEqual(0, new JiffSpan().days(0).signum());
    }

    @IsTest
    static void negateAndAbsFlipOnlyTheSign() {
        JiffSpan span = new JiffSpan().days(2).hours(3);
        Assert.areEqual('-P2DT3H', span.negate().toString());
        Assert.areEqual(span, span.negate().negate());
        Assert.areEqual(span, span.negate().abs());
        Assert.areEqual(span, span.abs());
        Assert.isTrue(new JiffSpan().negate().isZero());
        Assert.isTrue(new JiffSpan().abs().isZero());
    }

    @IsTest
    static void enforcesTheLimitOfEachUnit() {
        Map<JiffUnit, Long> limits = new Map<JiffUnit, Long>{
            JiffUnit.YEAR => 19998L,
            JiffUnit.MONTH => 239976L,
            JiffUnit.WEEK => 1043497L,
            JiffUnit.DAY => 7304484L,
            JiffUnit.HOUR => 175307616L,
            JiffUnit.MINUTE => 10518456960L,
            JiffUnit.SECOND => 631107417600L,
            JiffUnit.MILLISECOND => 631107417600000L,
            JiffUnit.MICROSECOND => 631107417600000000L
        };
        for (JiffUnit unit : limits.keySet()) {
            Long max = limits.get(unit);
            Assert.areEqual(max, new JiffSpan().withUnit(unit, max).get(unit));
            Assert.areEqual(-max, new JiffSpan().withUnit(unit, -max).get(unit));
            for (Long bad : new List<Long>{ max + 1, -max - 1 }) {
                try {
                    new JiffSpan().withUnit(unit, bad);
                    Assert.fail('expected ' + bad + ' ' + unit + ' to be rejected');
                } catch (JiffException e) {
                    assertRangeError(unit.name().toLowerCase() + 's', max, e.getMessage());
                }
            }
        }
        Assert.areEqual(
            JiffMath.LONG_MAX,
            new JiffSpan().nanoseconds(JiffMath.LONG_MAX).getNanoseconds()
        );
        Assert.areEqual(
            -JiffMath.LONG_MAX,
            new JiffSpan().nanoseconds(-JiffMath.LONG_MAX).getNanoseconds()
        );
        try {
            new JiffSpan().nanoseconds(JiffMath.LONG_MIN);
            Assert.fail('expected the minimum Long to be rejected');
        } catch (JiffException e) {
            assertRangeError('nanoseconds', JiffMath.LONG_MAX, e.getMessage());
        }
    }

    @IsTest
    static void multipliesEachUnitIndependently() {
        JiffSpan span = new JiffSpan().hours(1).minutes(40);
        Assert.areEqual('PT2H80M', span.multiply(2).toString());
        Assert.areEqual('-PT2H80M', span.multiply(-2).toString());
        Assert.areEqual('PT2H80M', span.negate().multiply(-2).toString());
        Assert.areEqual(span, span.multiply(1));
        Assert.isTrue(span.multiply(0).isZero());
        Assert.isTrue(new JiffSpan().multiply(5).isZero());
        try {
            new JiffSpan().years(10000).multiply(2);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('years', 19998L, e.getMessage());
        }
        try {
            new JiffSpan().days(1).multiply(7304485L);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('days', 7304484L, e.getMessage());
        }
        try {
            new JiffSpan().days(1).multiply(JiffMath.LONG_MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            // Jiff: 1.day().checked_mul(i64::MIN).
            assertRangeError('span multiple', JiffMath.LONG_MAX, e.getMessage());
        }
        // Jiff: Span::new().checked_mul(i64::MIN) is the zero span, because a zero span is
        // answered before the multiple is looked at.
        Assert.isTrue(new JiffSpan().multiply(JiffMath.LONG_MIN).isZero());
        // Jiff: 1.day().checked_mul(i64::MIN + 1) is past the limit for days.
        try {
            new JiffSpan().days(1).multiply(-JiffMath.LONG_MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('days', 7304484L, e.getMessage());
        }
        Assert.areEqual(
            JiffMath.LONG_MAX,
            new JiffSpan().nanoseconds(1).multiply(JiffMath.LONG_MAX).getNanoseconds()
        );
    }

    private static String tryMultiply(JiffSpan span, Long factor) {
        try {
            return span.multiply(factor).toString();
        } catch (JiffException e) {
            return e.getMessage();
        }
    }

    private static String rangeText(String unit, Long max) {
        return 'parameter \'' + unit + '\' is not in the required range of -' + max + '..=' + max;
    }

    @IsTest
    static void multiplyingPastSeveralLimitsReportsTheLargestUnit() {
        // Jiff checks years first and nanoseconds last, so when more than one unit of a span
        // overflows, the error names the largest. Each expected message is what
        // Span::checked_mul returns in Jiff 1.0.0 for the same span and multiple.
        Assert.areEqual(
            rangeText('days', 7304484L),
            tryMultiply(new JiffSpan().hours(-175307616).days(-4213602), 2L)
        );
        Assert.areEqual(
            rangeText('years', 19998L),
            tryMultiply(new JiffSpan().years(19998).hours(-32543), 97652L)
        );
        Assert.areEqual(
            rangeText('years', 19998L),
            tryMultiply(new JiffSpan().years(12).days(15), 7304484L)
        );
        Assert.areEqual(
            rangeText('hours', 175307616L),
            tryMultiply(new JiffSpan().hours(2).minutes(3), 200000000000L)
        );
        Assert.areEqual(
            rangeText('years', 19998L),
            tryMultiply(new JiffSpan().years(1).nanoseconds(5), JiffMath.LONG_MAX)
        );
        Assert.areEqual(
            rangeText('years', 19998L),
            tryMultiply(new JiffSpan().years(1).months(1), -19999L)
        );
        Assert.areEqual(
            rangeText('months', 239976L),
            tryMultiply(new JiffSpan().months(1).weeks(1), 1043498L)
        );
        Assert.areEqual(
            rangeText('seconds', 631107417600L),
            tryMultiply(new JiffSpan().seconds(2).milliseconds(3), 631107417600L)
        );
        Assert.areEqual(
            rangeText('microseconds', 631107417600000000L),
            tryMultiply(new JiffSpan().microseconds(2).nanoseconds(3), 4611686018427387904L)
        );
        Assert.areEqual(
            rangeText('nanoseconds', JiffMath.LONG_MAX),
            tryMultiply(new JiffSpan().nanoseconds(5), JiffMath.LONG_MAX)
        );
        // Within every limit the units keep their places.
        Assert.areEqual('-P19998Y29997M', tryMultiply(new JiffSpan().years(2).months(3), -9999L));
    }

    @IsTest
    static void splitsIntoCalendarAndTimeParts() {
        JiffSpan span = new JiffSpan().years(1).days(2).hours(3).nanoseconds(4);
        Assert.areEqual('P1Y2D', span.onlyCalendar().toString());
        Assert.areEqual('PT3H0.000000004S', span.onlyTime().toString());
        Assert.isTrue(span.hasCalendarUnits());
        Assert.isTrue(span.hasTimeUnits());
        Assert.isTrue(span.hasFractionalSeconds());
        Assert.isFalse(span.onlyCalendar().hasTimeUnits());
        Assert.isFalse(span.onlyTime().hasCalendarUnits());
        Assert.isFalse(new JiffSpan().seconds(1).hasFractionalSeconds());
        // The sign follows whatever is left.
        Assert.areEqual(-1, span.negate().onlyTime().signum());
        Assert.areEqual(0, new JiffSpan().hours(-1).onlyCalendar().signum());
        Assert.areEqual(0, new JiffSpan().days(-1).onlyTime().signum());
        Assert.areEqual('PT3H0.000000004S', span.onlyLower(JiffUnit.DAY).toString());
        Assert.areEqual('PT0.000000004S', span.onlyLower(JiffUnit.HOUR).toString());
        Assert.areEqual('PT0S', span.onlyLower(JiffUnit.NANOSECOND).toString());
        Assert.areEqual('P1Y2DT3H', span.withoutLower(JiffUnit.HOUR).toString());
        Assert.areEqual('P1Y2D', span.withoutLower(JiffUnit.DAY).toString());
        Assert.areEqual('P1Y', span.withoutLower(JiffUnit.MONTH).toString());
        Assert.areEqual(span, span.withoutLower(JiffUnit.NANOSECOND));
        Assert.areEqual(JiffUnit.DAY, new JiffSpan().days(1).hours(2).largestCalendarUnit());
        Assert.areEqual(JiffUnit.HOUR, new JiffSpan().hours(2).seconds(1).largestUnit());
        Assert.areEqual(JiffUnit.SECOND, new JiffSpan().hours(2).seconds(1).smallestUnit());
    }

    @IsTest
    static void convertsToAnInvariantDuration() {
        JiffSpan span = new JiffSpan()
            .weeks(1)
            .days(2)
            .hours(3)
            .minutes(4)
            .seconds(5)
            .milliseconds(6)
            .microseconds(7)
            .nanoseconds(8);
        Long secs = 604800L + 2 * 86400L + 3 * 3600L + 4 * 60L + 5;
        Assert.areEqual(JiffSignedDuration.newInstance(secs, 6007008), span.toInvariantDuration());
        Assert.areEqual(
            JiffSignedDuration.newInstance(-secs, -6007008),
            span.negate().toInvariantDuration()
        );
        Assert.areEqual(
            JiffSignedDuration.newInstance(3 * 3600L + 4 * 60L + 5, 6007008),
            span.toInvariantDurationTimeOnly()
        );
        Assert.areEqual(11045L, span.toHmsSeconds());
        Assert.areEqual(-11045L, span.negate().toHmsSeconds());
        // Sub-second units larger than a second carry.
        Assert.areEqual(
            JiffSignedDuration.newInstance(3L, 500000000),
            new JiffSpan().milliseconds(2500).microseconds(1000000).toInvariantDuration()
        );
    }

    @IsTest
    static void buildsFromAnInvariantDuration() {
        JiffSignedDuration duration = JiffSignedDuration.newInstance(
            604800L + 2 * 86400L + 3 * 3600L + 4 * 60L + 5,
            6007008
        );
        Assert.areEqual(
            'P1W2DT3H4M5.006007008S',
            JiffSpan.fromInvariantDuration(JiffUnit.WEEK, duration).toString()
        );
        JiffSpan days = JiffSpan.fromInvariantDuration(JiffUnit.DAY, duration);
        Assert.areEqual(9L, days.getDays());
        Assert.areEqual(0L, days.getWeeks());
        Assert.areEqual(6L, days.getMilliseconds());
        Assert.areEqual(7L, days.getMicroseconds());
        Assert.areEqual(8L, days.getNanoseconds());
        // Months and years behave like days: the largest fixed unit is the day.
        Assert.areEqual(days, JiffSpan.fromInvariantDuration(JiffUnit.YEAR, duration));
        Assert.areEqual(219L, JiffSpan.fromInvariantDuration(JiffUnit.HOUR, duration).getHours());
        Assert.areEqual(
            13144L,
            JiffSpan.fromInvariantDuration(JiffUnit.MINUTE, duration).getMinutes()
        );
        Assert.areEqual(
            788645L,
            JiffSpan.fromInvariantDuration(JiffUnit.SECOND, duration).getSeconds()
        );
        JiffSpan millis = JiffSpan.fromInvariantDuration(JiffUnit.MILLISECOND, duration);
        Assert.areEqual(788645006L, millis.getMilliseconds());
        Assert.areEqual(0L, millis.getSeconds());
        Assert.areEqual(7L, millis.getMicroseconds());
        JiffSpan micros = JiffSpan.fromInvariantDuration(JiffUnit.MICROSECOND, duration);
        Assert.areEqual(788645006007L, micros.getMicroseconds());
        Assert.areEqual(8L, micros.getNanoseconds());
        JiffSpan nanos = JiffSpan.fromInvariantDuration(JiffUnit.NANOSECOND, duration);
        Assert.areEqual(788645006007008L, nanos.getNanoseconds());
        Assert.areEqual(JiffUnit.NANOSECOND, nanos.largestUnit());
        JiffSpan negative = JiffSpan.fromInvariantDuration(JiffUnit.HOUR, duration.negate());
        Assert.areEqual(-219L, negative.getHours());
        Assert.areEqual(-8L, negative.getNanoseconds());
        Assert.areEqual(
            duration,
            JiffSpan.fromInvariantDuration(JiffUnit.WEEK, duration).toInvariantDuration()
        );
    }

    @IsTest
    static void rejectsDurationsTooLongForTheRequestedUnit() {
        JiffSignedDuration big = JiffSignedDuration.fromSecs(10000000000L);
        try {
            JiffSpan.fromInvariantDuration(JiffUnit.NANOSECOND, big);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('nanoseconds', JiffMath.LONG_MAX, e.getMessage());
        }
        Assert.areEqual(
            10000000000000L,
            JiffSpan.fromInvariantDuration(JiffUnit.MILLISECOND, big).getMilliseconds()
        );
        try {
            JiffSpan.fromInvariantDuration(
                JiffUnit.SECOND,
                JiffSignedDuration.fromSecs(631107417601L)
            );
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('seconds', 631107417600L, e.getMessage());
        }
        try {
            JiffSpan.fromInvariantDuration(
                JiffUnit.MILLISECOND,
                JiffSignedDuration.fromSecs(631107417601L)
            );
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('milliseconds', 631107417600000L, e.getMessage());
        }
    }

    private static String tryFromInvariant(JiffUnit largest, JiffSignedDuration duration) {
        try {
            return JiffSpan.fromInvariantDuration(largest, duration).toString();
        } catch (JiffException e) {
            return e.getMessage();
        }
    }

    @IsTest
    static void theMostExtremeDurationsAreRejectedForSubSecondUnits() {
        // Jiff's Span::from_invariant_duration converts the duration to a 128 bit count of
        // the unit and fails with that unit's range error when it does not fit. The seconds
        // of these durations have no absolute value in 64 bits, which must not be mistaken
        // for a small number.
        List<JiffSignedDuration> extremes = new List<JiffSignedDuration>{
            JiffSignedDuration.MIN,
            JiffSignedDuration.newInstance(JiffMath.LONG_MIN, 0),
            JiffSignedDuration.newInstance(-JiffMath.LONG_MAX, 0),
            JiffSignedDuration.MAX,
            JiffSignedDuration.newInstance(JiffMath.LONG_MAX, 0)
        };
        for (JiffSignedDuration extreme : extremes) {
            Assert.areEqual(
                rangeText('milliseconds', 631107417600000L),
                tryFromInvariant(JiffUnit.MILLISECOND, extreme),
                'milliseconds of ' + extreme
            );
            Assert.areEqual(
                rangeText('microseconds', 631107417600000000L),
                tryFromInvariant(JiffUnit.MICROSECOND, extreme),
                'microseconds of ' + extreme
            );
            Assert.areEqual(
                rangeText('nanoseconds', JiffMath.LONG_MAX),
                tryFromInvariant(JiffUnit.NANOSECOND, extreme),
                'nanoseconds of ' + extreme
            );
        }
    }

    @IsTest
    static void nanosecondsStopExactlyAtTheLargestLong() {
        // i64::MAX nanoseconds is 9223372036.854775807 seconds, and it is the limit in both
        // directions.
        Assert.areEqual(
            JiffMath.LONG_MAX,
            JiffSpan.fromInvariantDuration(
                    JiffUnit.NANOSECOND,
                    JiffSignedDuration.newInstance(9223372036L, 854775807)
                )
                .getNanoseconds()
        );
        Assert.areEqual(
            -JiffMath.LONG_MAX,
            JiffSpan.fromInvariantDuration(
                    JiffUnit.NANOSECOND,
                    JiffSignedDuration.newInstance(-9223372036L, -854775807)
                )
                .getNanoseconds()
        );
        // Anything past it is out of range. One past the limit is the least interesting
        // probe: a sum that wrapped around would land on Long.MIN there and be rejected for
        // the wrong reason, so the probes go further.
        List<Integer> subseconds = new List<Integer>{ 854775808, 854775809, 999999999 };
        for (Integer subsecond : subseconds) {
            Assert.areEqual(
                rangeText('nanoseconds', JiffMath.LONG_MAX),
                tryFromInvariant(
                    JiffUnit.NANOSECOND,
                    JiffSignedDuration.newInstance(9223372036L, subsecond)
                ),
                'subsecond ' + subsecond
            );
            Assert.areEqual(
                rangeText('nanoseconds', JiffMath.LONG_MAX),
                tryFromInvariant(
                    JiffUnit.NANOSECOND,
                    JiffSignedDuration.newInstance(-9223372036L, -subsecond)
                ),
                'subsecond -' + subsecond
            );
        }
        Assert.areEqual(
            rangeText('nanoseconds', JiffMath.LONG_MAX),
            tryFromInvariant(JiffUnit.NANOSECOND, JiffSignedDuration.fromSecs(9223372037L))
        );
        Assert.areEqual(
            rangeText('nanoseconds', JiffMath.LONG_MAX),
            tryFromInvariant(JiffUnit.NANOSECOND, JiffSignedDuration.fromSecs(-9223372037L))
        );
    }

    @IsTest
    static void convertsFromASignedDuration() {
        JiffSpan span = JiffSpan.fromDuration(JiffSignedDuration.newInstance(90L, 123456789));
        Assert.areEqual(90L, span.getSeconds());
        Assert.areEqual(123L, span.getMilliseconds());
        Assert.areEqual(456L, span.getMicroseconds());
        Assert.areEqual(789L, span.getNanoseconds());
        Assert.areEqual('PT90.123456789S', span.toString());
        Assert.areEqual(
            '-PT90.123456789S',
            JiffSpan.fromDuration(JiffSignedDuration.newInstance(-90L, -123456789)).toString()
        );
        Assert.isTrue(JiffSpan.fromDuration(JiffSignedDuration.ZERO).isZero());
        try {
            JiffSpan.fromDuration(JiffSignedDuration.MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertRangeError('seconds', 631107417600L, e.getMessage());
        }
    }

    @IsTest
    static void equalityIsFieldByField() {
        JiffSpan hour = new JiffSpan().hours(1);
        Assert.areEqual(hour, new JiffSpan().hours(1));
        Assert.areEqual(hour.hashCode(), new JiffSpan().hours(1).hashCode());
        Assert.areNotEqual(hour, new JiffSpan().minutes(60));
        Assert.areNotEqual(hour, hour.negate());
        Assert.isFalse(hour.equals('PT1H'));
        Assert.areEqual(new JiffSpan(), new JiffSpan().days(5).days(0));
    }

    @IsTest
    static void printsIsoDurations() {
        Assert.areEqual('P1Y', new JiffSpan().years(1).toString());
        Assert.areEqual('P1M', new JiffSpan().months(1).toString());
        Assert.areEqual('P1W', new JiffSpan().weeks(1).toString());
        Assert.areEqual('P1D', new JiffSpan().days(1).toString());
        Assert.areEqual('PT1H', new JiffSpan().hours(1).toString());
        Assert.areEqual('PT1M', new JiffSpan().minutes(1).toString());
        Assert.areEqual('PT1S', new JiffSpan().seconds(1).toString());
        Assert.areEqual('PT0.001S', new JiffSpan().milliseconds(1).toString());
        Assert.areEqual('PT0.000001S', new JiffSpan().microseconds(1).toString());
        Assert.areEqual('PT0.000000001S', new JiffSpan().nanoseconds(1).toString());
        Assert.areEqual('-P5D', new JiffSpan().days(-5).toString());
        Assert.areEqual('PT1.5S', new JiffSpan().seconds(1).milliseconds(500).toString());
        Assert.areEqual('PT2.5S', new JiffSpan().milliseconds(2500).toString());
        Assert.areEqual(
            'PT1M2.000000003S',
            new JiffSpan().minutes(1).seconds(2).nanoseconds(3).toString()
        );
        Assert.areEqual(
            'PT4S',
            new JiffSpan()
                .seconds(1)
                .milliseconds(1000)
                .microseconds(1000000)
                .nanoseconds(1000000000)
                .toString()
        );
        Assert.areEqual(
            'PT631107417600.999999999S',
            new JiffSpan().seconds(631107417600L).nanoseconds(999999999).toString()
        );
    }
}
