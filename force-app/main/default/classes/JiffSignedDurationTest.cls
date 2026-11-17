@IsTest
private class JiffSignedDurationTest {
    private static JiffSignedDuration d(Long secs, Integer nanos) {
        return JiffSignedDuration.newInstance(secs, nanos);
    }

    private static void assertParts(Long secs, Integer nanos, JiffSignedDuration actual) {
        Assert.areEqual(secs, actual.asSecs(), 'seconds of ' + actual);
        Assert.areEqual(nanos, actual.subsecNanos(), 'nanoseconds of ' + actual);
    }

    private static void assertFails(String expectedFragment, String message) {
        Assert.isTrue(
            message.contains(expectedFragment),
            'expected "' + expectedFragment + '" in: ' + message
        );
    }

    @IsTest
    static void constructionCarriesAndBalancesSigns() {
        assertParts(12L, 0, d(12L, 0));
        assertParts(12L, 500000000, d(12L, 500000000));
        // Nanoseconds beyond a second carry into the seconds.
        assertParts(13L, 500000000, d(12L, 1500000000));
        assertParts(-13L, -500000000, d(-12L, -1500000000));
        // Mixed signs are rebalanced so both components agree.
        assertParts(11L, 500000000, d(12L, -500000000));
        assertParts(-11L, -500000000, d(-12L, 500000000));
        assertParts(0L, -1, d(0L, -1));
        assertParts(0L, 999999999, d(1L, -1));
        assertParts(0L, -999999999, d(-1L, 1));
        assertParts(0L, 0, d(1L, -1000000000));
        try {
            d(JiffMath.LONG_MAX, 1000000000);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
    }

    @IsTest
    static void convertsFromSmallerUnits() {
        assertParts(1L, 500000000, JiffSignedDuration.fromMillis(1500L));
        assertParts(-1L, -500000000, JiffSignedDuration.fromMillis(-1500L));
        assertParts(1L, 500000, JiffSignedDuration.fromMicros(1000500L));
        assertParts(-1L, -500000, JiffSignedDuration.fromMicros(-1000500L));
        assertParts(1L, 5, JiffSignedDuration.fromNanos(1000000005L));
        assertParts(-9223372036L, -854775808, JiffSignedDuration.fromNanos(JiffMath.LONG_MIN));
        assertParts(9223372036L, 854775807, JiffSignedDuration.fromNanos(JiffMath.LONG_MAX));
        assertParts(7200L, 0, JiffSignedDuration.fromHours(2L));
        assertParts(-120L, 0, JiffSignedDuration.fromMins(-2L));
        assertParts(42L, 0, JiffSignedDuration.fromSecs(42L));
        for (
            Long tooBig : new List<Long>{
                JiffMath.LONG_MAX / 3600 + 1,
                JiffMath.LONG_MIN / 3600 - 1
            }
        ) {
            try {
                JiffSignedDuration.fromHours(tooBig);
                Assert.fail('expected an overflow');
            } catch (JiffException e) {
                assertFails('overflowed', e.getMessage());
            }
        }
        try {
            JiffSignedDuration.fromMins(JiffMath.LONG_MAX / 60 + 1);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
    }

    @IsTest
    static void exposesItsComponents() {
        JiffSignedDuration duration = d(-7384L, -123456789);
        Assert.areEqual(-7384L, duration.asSecs());
        Assert.areEqual(-123, duration.subsecMillis());
        Assert.areEqual(-123456, duration.subsecMicros());
        Assert.areEqual(-123456789, duration.subsecNanos());
        Assert.areEqual(-2L, duration.asHours());
        Assert.areEqual(-123L, duration.asMins());
        Assert.areEqual(-7384123L, duration.asMillis());
        Assert.areEqual(-7384123456L, duration.asMicros());
        Assert.areEqual(-7384123456789L, duration.asNanos());
        Assert.areEqual('-7384123456789', duration.asNanosI128().toString());
        Assert.isTrue(duration.fitsNanos());
        Assert.isTrue(duration.isNegative());
        Assert.isFalse(duration.isPositive());
        Assert.isFalse(duration.isZero());
        Assert.areEqual(-1, duration.signum());
        Assert.areEqual(1, d(0L, 1).signum());
        Assert.areEqual(0, JiffSignedDuration.ZERO.signum());
        Assert.isTrue(JiffSignedDuration.ZERO.isZero());
        Assert.isTrue(d(0L, 1).isPositive());
    }

    @IsTest
    static void wideTotalsOverflowALongOnlyWhenTheyMust() {
        Assert.isFalse(JiffSignedDuration.MAX.fitsNanos());
        Assert.areEqual(
            '9223372036854775807999999999',
            JiffSignedDuration.MAX.asNanosI128().toString()
        );
        Assert.areEqual(
            '-9223372036854775808999999999',
            JiffSignedDuration.MIN.asNanosI128().toString()
        );
        for (String unit : new List<String>{ 'millis', 'micros', 'nanos' }) {
            try {
                if (unit == 'millis') {
                    JiffSignedDuration.MAX.asMillis();
                } else if (unit == 'micros') {
                    JiffSignedDuration.MAX.asMicros();
                } else {
                    JiffSignedDuration.MAX.asNanos();
                }
                Assert.fail('expected an overflow');
            } catch (JiffException e) {
                assertFails('overflowed', e.getMessage());
            }
        }
        Assert.areEqual(
            JiffMath.LONG_MAX,
            JiffSignedDuration.fromNanos(JiffMath.LONG_MAX).asNanos()
        );
        Assert.areEqual(
            JiffMath.LONG_MIN,
            JiffSignedDuration.fromNanos(JiffMath.LONG_MIN).asNanos()
        );
        Assert.areEqual(
            JiffSignedDuration.MAX,
            JiffSignedDuration.fromNanosI128(JiffSignedDuration.MAX.asNanosI128())
        );
        Assert.areEqual(
            JiffSignedDuration.MIN,
            JiffSignedDuration.fromNanosI128(JiffSignedDuration.MIN.asNanosI128())
        );
        try {
            JiffSignedDuration.fromNanosI128(JiffSignedDuration.MAX.asNanosI128().add(1L));
            Assert.fail('expected a range error');
        } catch (JiffException e) {
            assertFails('signed duration seconds', e.getMessage());
        }
    }

    @IsTest
    static void addsAndSubtracts() {
        assertParts(13L, 0, d(12L, 500000000).add(d(0L, 500000000)));
        assertParts(-13L, 0, d(-12L, -500000000).add(d(0L, -500000000)));
        assertParts(0L, 500000000, d(1L, 0).add(d(0L, -500000000)));
        assertParts(0L, -500000000, d(-1L, 0).add(d(0L, 500000000)));
        assertParts(0L, 1, d(1L, 0).subtract(d(0L, 999999999)));
        assertParts(-1L, -1, d(0L, -1).subtract(d(1L, 0)));
        assertParts(2L, 999999998, d(1L, 999999999).add(d(0L, 999999999)));
        Assert.areEqual(
            JiffSignedDuration.ZERO,
            JiffSignedDuration.MAX.subtract(JiffSignedDuration.MAX)
        );
        try {
            JiffSignedDuration.MAX.add(d(0L, 1));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
        try {
            JiffSignedDuration.MIN.subtract(d(0L, 1));
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
        try {
            JiffSignedDuration.ZERO.subtract(JiffSignedDuration.MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
    }

    @IsTest
    static void saturatingArithmeticClampsInsteadOfThrowing() {
        Assert.areEqual(JiffSignedDuration.MAX, JiffSignedDuration.MAX.saturatingAdd(d(0L, 1)));
        Assert.areEqual(JiffSignedDuration.MIN, JiffSignedDuration.MIN.saturatingAdd(d(0L, -1)));
        Assert.areEqual(
            JiffSignedDuration.MIN,
            JiffSignedDuration.MIN.saturatingSubtract(d(0L, 1))
        );
        Assert.areEqual(
            JiffSignedDuration.MAX,
            JiffSignedDuration.MAX.saturatingSubtract(d(0L, -1))
        );
        Assert.areEqual(d(3L, 0), d(1L, 0).saturatingAdd(d(2L, 0)));
        Assert.areEqual(d(-1L, 0), d(1L, 0).saturatingSubtract(d(2L, 0)));
        Assert.areEqual(JiffSignedDuration.MAX, JiffSignedDuration.MAX.saturatingMultiply(2));
        Assert.areEqual(JiffSignedDuration.MIN, JiffSignedDuration.MAX.saturatingMultiply(-2));
        Assert.areEqual(JiffSignedDuration.MAX, JiffSignedDuration.MIN.saturatingMultiply(-2));
        Assert.areEqual(d(6L, 0), d(3L, 0).saturatingMultiply(2));
    }

    @IsTest
    static void multipliesAndDividesByIntegers() {
        assertParts(3L, 0, d(1L, 500000000).multiply(2));
        assertParts(-3L, 0, d(1L, 500000000).multiply(-2));
        assertParts(0L, 0, d(1L, 500000000).multiply(0));
        assertParts(2147483647L, 0, d(0L, 1).multiply(2147483647).multiply(1000000000));
        assertParts(0L, 750000000, d(1L, 500000000).divide(2));
        assertParts(0L, -750000000, d(1L, 500000000).divide(-2));
        assertParts(0L, 333333333, d(1L, 0).divide(3));
        assertParts(3L, 333333333, d(10L, 0).divide(3));
        assertParts(-3L, -333333333, d(-10L, 0).divide(3));
        try {
            JiffSignedDuration.MAX.multiply(2);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
        try {
            d(1L, 0).divide(0);
            Assert.fail('expected division by zero to fail');
        } catch (JiffException e) {
            assertFails('by zero', e.getMessage());
        }
        try {
            JiffSignedDuration.MIN.divide(-1);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
    }

    @IsTest
    static void negatesAndTakesAbsoluteValues() {
        Assert.areEqual(d(-1L, -5), d(1L, 5).negate());
        Assert.areEqual(d(1L, 5), d(-1L, -5).abs());
        Assert.areEqual(d(1L, 5), d(1L, 5).abs());
        Assert.areEqual(JiffSignedDuration.ZERO, JiffSignedDuration.ZERO.negate());
        try {
            JiffSignedDuration.MIN.negate();
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
        try {
            JiffSignedDuration.MIN.abs();
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            assertFails('overflowed', e.getMessage());
        }
    }

    @IsTest
    static void convertsToAndFromFractionalSeconds() {
        Double oneAndAHalf = 1.5;
        Assert.areEqual(oneAndAHalf, d(1L, 500000000).asSecsDouble());
        Assert.areEqual(-oneAndAHalf, d(-1L, -500000000).asSecsDouble());
        Double millis = 1500.25;
        Assert.areEqual(millis, d(1L, 500250000).asMillisDouble());
        assertParts(1L, 500000000, JiffSignedDuration.fromSecsDouble(oneAndAHalf));
        assertParts(-1L, -500000000, JiffSignedDuration.fromSecsDouble(-oneAndAHalf));
        Double tiny = 0.000000001;
        assertParts(0L, 1, JiffSignedDuration.fromSecsDouble(tiny));
        Double almostTwo = 1.9999999999;
        assertParts(2L, 0, JiffSignedDuration.fromSecsDouble(almostTwo));
        assertParts(-2L, 0, JiffSignedDuration.fromSecsDouble(-almostTwo));
        Double two = 2;
        assertParts(3L, 0, d(1L, 500000000).multiplyDouble(two));
        assertParts(0L, 750000000, d(1L, 500000000).divideDouble(two));
        Double ratio = 4;
        Assert.areEqual(ratio, d(6L, 0).divDuration(d(1L, 500000000)));
        Double huge = 1;
        for (Integer i = 0; i < 30; i++) {
            huge = huge * 10;
        }
        for (Double bad : new List<Double>{ huge, -huge }) {
            try {
                JiffSignedDuration.fromSecsDouble(bad);
                Assert.fail('expected a range error');
            } catch (JiffException e) {
                assertFails('floating point seconds', e.getMessage());
            }
        }
    }

    @IsTest
    static void roundsToTimeUnits() {
        JiffSignedDuration duration = d(5L * 3600 + 30 * 60 + 30, 500000000);
        Assert.areEqual(d(6L * 3600, 0), duration.round(JiffUnit.HOUR));
        Assert.areEqual(d(5L * 3600 + 31 * 60, 0), duration.round(JiffUnit.MINUTE));
        Assert.areEqual(d(5L * 3600 + 30 * 60 + 31, 0), duration.round(JiffUnit.SECOND));
        Assert.areEqual(duration, duration.round(JiffUnit.MILLISECOND));
        Assert.areEqual(duration, duration.round(new JiffRound()));
        Assert.areEqual(
            d(5L * 3600 + 30 * 60, 0),
            duration.round(JiffRound.to(JiffUnit.MINUTE).increment(15).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(
            d(5L * 3600 + 45 * 60, 0),
            duration.round(JiffRound.to(JiffUnit.MINUTE).increment(15).mode(JiffRoundMode.CEIL))
        );
        // Negative durations round symmetrically under the default mode.
        Assert.areEqual(d(-6L * 3600, 0), duration.negate().round(JiffUnit.HOUR));
        Assert.areEqual(
            d(-5L * 3600, 0),
            duration.negate().round(JiffRound.to(JiffUnit.HOUR).mode(JiffRoundMode.CEIL))
        );
        // Unlike other types, a signed duration accepts increments that do not divide evenly.
        Assert.areEqual(d(7L * 3600, 0), duration.round(JiffRound.to(JiffUnit.HOUR).increment(7)));
    }

    @IsTest
    static void roundingRejectsCalendarUnitsAndOverflow() {
        try {
            d(1L, 0).round(JiffUnit.DAY);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            assertFails('is a calendar unit', e.getMessage());
        }
        try {
            JiffSignedDuration.MAX.round(JiffUnit.HOUR);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            assertFails('outside the supported range', e.getMessage());
            Assert.isNotNull(e.getCause());
        }
        Assert.areEqual(
            d(JiffMath.LONG_MAX - 30 * 60 - 7, 0),
            JiffSignedDuration.MAX.round(JiffRound.to(JiffUnit.HOUR).mode(JiffRoundMode.TRUNC))
        );
    }

    @IsTest
    static void comparesAndHashesByValue() {
        Assert.areEqual(0, d(1L, 5).compareTo(d(1L, 5)));
        Assert.areEqual(-1, d(1L, 5).compareTo(d(1L, 6)));
        Assert.areEqual(1, d(2L, 0).compareTo(d(1L, 999999999)));
        Assert.areEqual(-1, d(-2L, 0).compareTo(d(-1L, -999999999)));
        Assert.areEqual(-1, JiffSignedDuration.MIN.compareTo(JiffSignedDuration.MAX));
        Assert.areEqual(d(1L, 5).hashCode(), d(0L, 1000000005).hashCode());
        Assert.isTrue(d(1L, 5).equals(d(0L, 1000000005)));
        Assert.isFalse(d(1L, 5).equals(d(1L, 6)));
        Assert.isFalse(d(1L, 5).equals('PT1.000000005S'));
        List<JiffSignedDuration> sorted = new List<JiffSignedDuration>{
            d(3L, 0),
            d(-1L, 0),
            d(0L, 1)
        };
        sorted.sort();
        Assert.areEqual(d(-1L, 0), sorted.get(0));
        Assert.areEqual(d(3L, 0), sorted.get(2));
        Map<JiffSignedDuration, String> names = new Map<JiffSignedDuration, String>{
            d(60L, 0) => 'minute'
        };
        Assert.areEqual('minute', names.get(JiffSignedDuration.fromMins(1L)));
    }

    @IsTest
    static void printsAsAnIsoDuration() {
        Assert.areEqual('PT0S', d(0L, 0).toString());
        Assert.areEqual('PT0.000000001S', d(0L, 1).toString());
        Assert.areEqual('PT1S', d(1L, 0).toString());
        Assert.areEqual('PT59S', d(59L, 0).toString());
        Assert.areEqual('PT1M', d(60L, 0).toString());
        Assert.areEqual('PT1M0.000000001S', d(60L, 1).toString());
        Assert.areEqual('PT1M1.000000001S', d(61L, 1).toString());
        Assert.areEqual('PT1H', d(3600L, 0).toString());
        Assert.areEqual('PT1H0.000000001S', d(3600L, 1).toString());
        Assert.areEqual('PT1H1M', d(3660L, 0).toString());
        Assert.areEqual('PT1H1M0.000000001S', d(3660L, 1).toString());
        Assert.areEqual('PT1H1M1S', d(3661L, 0).toString());
        Assert.areEqual('PT1H1M1.000000001S', d(3661L, 1).toString());
        Assert.areEqual('-PT0.000000001S', d(0L, -1).toString());
        Assert.areEqual('-PT1S', d(-1L, 0).toString());
        Assert.areEqual('-PT59S', d(-59L, 0).toString());
        Assert.areEqual('-PT1M', d(-60L, 0).toString());
        Assert.areEqual('-PT1H1M1.000000001S', d(-3661L, -1).toString());
        Assert.areEqual('PT1.5S', d(1L, 500000000).toString());
        Assert.areEqual('PT2562047788015215H30M7.999999999S', JiffSignedDuration.MAX.toString());
        Assert.areEqual('-PT2562047788015215H30M8.999999999S', JiffSignedDuration.MIN.toString());
    }
}
