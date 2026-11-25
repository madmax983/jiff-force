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

    // What Jiff 1.0.0 reports for a float that is not a number, and for one that is a number
    // but too large. The second prints its bounds as floats, hence the rounded digits.
    private static final String NON_FINITE = 'could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)';
    private static final String FLOAT_RANGE = 'parameter \'floating point seconds\' is not in the required range of -9223372036854776000..=9223372036854776000';

    private static Double dbl(String text) {
        return Double.valueOf(text);
    }

    /** An infinity made by arithmetic rather than parsed, as a caller's own overflow would. */
    private static Double overflowedToInfinity() {
        Double big = 1;
        for (Integer i = 0; i < 200; i++) {
            big = big * 10;
        }
        return big * big;
    }

    @IsTest
    static void fractionalSecondsThatAreNotFiniteAreRejected() {
        // SignedDuration::try_from_secs_f64(f64::NAN / INFINITY / NEG_INFINITY) all return
        // the same error in Jiff.
        List<Double> notFinite = new List<Double>{
            dbl('NaN'),
            dbl('Infinity'),
            dbl('-Infinity'),
            overflowedToInfinity(),
            -overflowedToInfinity()
        };
        for (Double bad : notFinite) {
            try {
                JiffSignedDuration.fromSecsDouble(bad);
                Assert.fail('expected ' + bad + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(NON_FINITE, e.getMessage());
            }
        }
    }

    @IsTest
    static void multiplyingOrDividingByANonFiniteNumberIsRejected() {
        // from_secs(1).mul_f64(NAN), .div_f64(NAN), .mul_f64(INFINITY), .mul_f64(NEG_INFINITY)
        // and ZERO.mul_f64(INFINITY) (zero times infinity is NaN) all panic in Jiff with the
        // non-finite error.
        Double nan = dbl('NaN');
        Double inf = dbl('Infinity');
        JiffSignedDuration one = d(1L, 0);
        List<String> messages = new List<String>();
        try {
            one.multiplyDouble(nan);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.divideDouble(nan);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.multiplyDouble(inf);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            one.multiplyDouble(-inf);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            JiffSignedDuration.ZERO.multiplyDouble(inf);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            JiffSignedDuration.ZERO.multiplyDouble(overflowedToInfinity());
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                NON_FINITE,
                NON_FINITE,
                NON_FINITE,
                NON_FINITE,
                NON_FINITE,
                NON_FINITE
            },
            messages
        );
        // Dividing by an infinity is fine: from_secs(1).div_f64(INFINITY) is zero in Jiff.
        assertParts(0L, 0, one.divideDouble(inf));
        assertParts(0L, 0, one.divideDouble(-inf));
    }

    @IsTest
    static void fractionalSecondsSaturateAtExactlyTwoToTheSixtyThird() {
        // 2^63 is `i64::MAX as f64`, so Jiff accepts it and its cast saturates:
        // try_from_secs_f64(9223372036854775808.0) is (i64::MAX, 0) and the negation is
        // (i64::MIN, 0).
        Double twoTo63 = dbl('9223372036854775808');
        assertParts(JiffMath.LONG_MAX, 0, JiffSignedDuration.fromSecsDouble(twoTo63));
        assertParts(JiffMath.LONG_MIN, 0, JiffSignedDuration.fromSecsDouble(-twoTo63));
        Assert.isTrue(JiffSignedDuration.fromSecsDouble(twoTo63).isPositive());
        Assert.isTrue(JiffSignedDuration.fromSecsDouble(-twoTo63).isNegative());
        // The floats next to 2^63 on the inside are whole seconds a Long holds exactly.
        Double justInside = dbl('9223372036854774784');
        assertParts(9223372036854774784L, 0, JiffSignedDuration.fromSecsDouble(justInside));
        assertParts(-9223372036854774784L, 0, JiffSignedDuration.fromSecsDouble(-justInside));
        // The floats next to it on the outside are out of range, like everything beyond.
        List<Double> outside = new List<Double>{
            dbl('9223372036854777856'),
            dbl('-9223372036854777856'),
            dbl('9.3e18'),
            dbl('-9.3e18'),
            dbl('1e30'),
            dbl('-1e30')
        };
        for (Double bad : outside) {
            try {
                JiffSignedDuration.fromSecsDouble(bad);
                Assert.fail('expected ' + bad + ' to be out of range');
            } catch (JiffException e) {
                Assert.areEqual(FLOAT_RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void floatArithmeticOnTheLargestDurationsSaturatesAsInJiff() {
        Double one = 1;
        Double two = 2;
        Double billion = 1000000000;
        // MAX and MIN as float seconds are exactly 2^63 and -2^63.
        Assert.areEqual(dbl('9223372036854775808'), JiffSignedDuration.MAX.asSecsDouble());
        Assert.areEqual(dbl('-9223372036854775808'), JiffSignedDuration.MIN.asSecsDouble());
        // Jiff: MAX.mul_f64(1.0), MAX.div_f64(1.0), MIN.mul_f64(-1.0), MIN.div_f64(-1.0),
        // from_secs(4611686018427387904).mul_f64(2.0) and
        // new(9223372036, 854775807).mul_f64(1e9) are all (i64::MAX, 0).
        assertParts(JiffMath.LONG_MAX, 0, JiffSignedDuration.MAX.multiplyDouble(one));
        assertParts(JiffMath.LONG_MAX, 0, JiffSignedDuration.MAX.divideDouble(one));
        assertParts(JiffMath.LONG_MAX, 0, JiffSignedDuration.MIN.multiplyDouble(-one));
        assertParts(JiffMath.LONG_MAX, 0, JiffSignedDuration.MIN.divideDouble(-one));
        assertParts(
            JiffMath.LONG_MAX,
            0,
            JiffSignedDuration.fromSecs(4611686018427387904L).multiplyDouble(two)
        );
        assertParts(JiffMath.LONG_MAX, 0, d(9223372036L, 854775807).multiplyDouble(billion));
        // Jiff: MIN.mul_f64(1.0) and from_secs(-4611686018427387904).mul_f64(2.0) are
        // (i64::MIN, 0).
        assertParts(JiffMath.LONG_MIN, 0, JiffSignedDuration.MIN.multiplyDouble(one));
        assertParts(
            JiffMath.LONG_MIN,
            0,
            JiffSignedDuration.fromSecs(-4611686018427387904L).multiplyDouble(two)
        );
        // Jiff: MAX.mul_f64(2.0) and MAX.mul_f64(1.0000000000000002) panic with the range
        // error.
        for (Double factor : new List<Double>{ two, dbl('1.0000000000000002'), -two }) {
            try {
                JiffSignedDuration.MAX.multiplyDouble(factor);
                Assert.fail('expected MAX * ' + factor + ' to be out of range');
            } catch (JiffException e) {
                Assert.areEqual(FLOAT_RANGE, e.getMessage());
            }
        }
    }

    @IsTest
    static void fractionalSecondsRoundToTheNearestNanosecondWithTiesAwayFromZero() {
        // Every expected value is what SignedDuration::try_from_secs_f64 returns in Jiff 1.0.0.
        // The largest float below half a nanosecond rounds down; adding 0.5 and truncating
        // would round it up.
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('4.999999999999999e-10')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('-4.999999999999999e-10')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('4.9999999999999994e-10')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('-4.9999999999999994e-10')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('1e-10')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('-1e-10')));
        // Exact halves go away from zero.
        assertParts(0L, 1, JiffSignedDuration.fromSecsDouble(dbl('5e-10')));
        assertParts(0L, -1, JiffSignedDuration.fromSecsDouble(dbl('-5e-10')));
        assertParts(0L, 2, JiffSignedDuration.fromSecsDouble(dbl('1.5e-9')));
        assertParts(0L, 3, JiffSignedDuration.fromSecsDouble(dbl('2.5e-9')));
        assertParts(0L, -3, JiffSignedDuration.fromSecsDouble(dbl('-2.5e-9')));
        // Rounding up to a whole second carries into the seconds.
        assertParts(1L, 0, JiffSignedDuration.fromSecsDouble(dbl('0.9999999995')));
        assertParts(-1L, 0, JiffSignedDuration.fromSecsDouble(dbl('-0.9999999995')));
        assertParts(2L, 0, JiffSignedDuration.fromSecsDouble(dbl('1.9999999996')));
        assertParts(0L, 999999999, JiffSignedDuration.fromSecsDouble(dbl('0.99999999949')));
        // Ordinary values, including Jiff's own doc examples.
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('0')));
        assertParts(0L, 0, JiffSignedDuration.fromSecsDouble(dbl('-0.0')));
        assertParts(0L, 500000000, JiffSignedDuration.fromSecsDouble(dbl('0.5')));
        assertParts(0L, -500000000, JiffSignedDuration.fromSecsDouble(dbl('-0.5')));
        assertParts(12L, 123456789, JiffSignedDuration.fromSecsDouble(dbl('12.123456789')));
        assertParts(-12L, -123456789, JiffSignedDuration.fromSecsDouble(dbl('-12.123456789')));
        // A float cannot hold this many digits; Jiff gives ...328, not ...321.
        assertParts(
            123456789L,
            987654328,
            JiffSignedDuration.fromSecsDouble(dbl('123456789.987654321'))
        );
        // The largest values that still have a fractional part.
        assertParts(
            4503599627370495L,
            500000000,
            JiffSignedDuration.fromSecsDouble(dbl('4503599627370495.5'))
        );
        assertParts(
            -4503599627370495L,
            -500000000,
            JiffSignedDuration.fromSecsDouble(dbl('-4503599627370495.5'))
        );
        assertParts(
            9007199254740992L,
            0,
            JiffSignedDuration.fromSecsDouble(dbl('9007199254740993'))
        );
    }

    @IsTest
    static void floatMultiplicationAndDivisionRoundLikeJiff() {
        Double half = 0.5;
        Double two = 2;
        JiffSignedDuration oneNano = d(0L, 1);
        // Jiff: new(0, 1).mul_f64(0.49999999999999994) and new(0, 1).div_f64(2.0000000000000004)
        // are zero; with 0.5 and 2.0 they are one nanosecond.
        assertParts(0L, 0, oneNano.multiplyDouble(dbl('0.49999999999999994')));
        assertParts(0L, 0, oneNano.negate().multiplyDouble(dbl('0.49999999999999994')));
        assertParts(0L, 0, oneNano.divideDouble(dbl('2.0000000000000004')));
        assertParts(0L, 1, oneNano.multiplyDouble(half));
        assertParts(0L, -1, oneNano.negate().multiplyDouble(half));
        assertParts(0L, 1, oneNano.divideDouble(two));
        // Jiff's doc examples for mul_f64 and div_f64.
        JiffSignedDuration duration = d(12L, 123456789);
        assertParts(24L, 246913578, duration.multiplyDouble(two));
        assertParts(-24L, -246913578, duration.multiplyDouble(-two));
        assertParts(6L, 61728395, duration.divideDouble(two));
        assertParts(-6L, -61728395, duration.divideDouble(-two));
    }

    @IsTest
    static void dividingByAFloatingPointZeroIsRejectedAsInJiff() {
        // from_secs(5).div_f64(0.0), from_secs(-5).div_f64(0.0), ZERO.div_f64(0.0) and
        // from_secs(5).div_f64(-0.0) all panic in Jiff with the non-finite error, because the
        // quotient is an infinity or NaN.
        Double zero = 0;
        Double negativeZero = dbl('-0.0');
        List<JiffSignedDuration> dividends = new List<JiffSignedDuration>{
            d(5L, 0),
            d(-5L, 0),
            JiffSignedDuration.ZERO,
            JiffSignedDuration.MAX
        };
        for (JiffSignedDuration dividend : dividends) {
            for (Double divisor : new List<Double>{ zero, negativeZero, -zero }) {
                try {
                    dividend.divideDouble(divisor);
                    Assert.fail('expected ' + dividend + ' / ' + divisor + ' to be rejected');
                } catch (JiffException e) {
                    Assert.areEqual(NON_FINITE, e.getMessage());
                }
            }
        }
    }

    @IsTest
    static void dividingByAZeroDurationThrowsInsteadOfReturningInfinity() {
        // A deliberate difference: Jiff's div_duration_f64 returns inf, -inf and NaN here.
        List<JiffSignedDuration> dividends = new List<JiffSignedDuration>{
            d(5L, 0),
            d(-5L, 0),
            d(0L, 1),
            JiffSignedDuration.ZERO
        };
        for (JiffSignedDuration dividend : dividends) {
            try {
                dividend.divDuration(JiffSignedDuration.ZERO);
                Assert.fail('expected ' + dividend + ' / zero to be rejected');
            } catch (JiffException e) {
                Assert.areEqual('division of a signed duration by a zero duration', e.getMessage());
            }
        }
        // Everything else matches Jiff: ZERO / 5s is 0, MIN / MAX is -1, and Jiff's doc
        // example gives 2 and -2.
        Double zero = 0;
        Double two = 2;
        Double one = 1;
        Assert.areEqual(zero, JiffSignedDuration.ZERO.divDuration(d(5L, 0)));
        Assert.areEqual(-one, JiffSignedDuration.MIN.divDuration(JiffSignedDuration.MAX));
        Assert.areEqual(two, d(12L, 600000000).divDuration(d(6L, 300000000)));
        Assert.areEqual(-two, d(-12L, -600000000).divDuration(d(6L, 300000000)));
        Assert.areEqual(two, d(-12L, -600000000).divDuration(d(-6L, -300000000)));
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
