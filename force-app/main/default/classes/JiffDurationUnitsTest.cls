/**
 * The builder both duration parsers feed. The expected values are the ones Jiff's parser tests
 * give for the same units (`fmt/friendly/parser.rs`, `fmt/temporal/parser.rs`); here the units
 * are set directly rather than parsed from text.
 */
@IsTest
private class JiffDurationUnitsTest {
    private static JiffI128 n(Long value) {
        return JiffI128.valueOf(value);
    }

    /** A builder with the given units set from largest to smallest and a positive sign. */
    private static JiffDurationUnits units(List<JiffUnit> order, List<Long> values) {
        JiffDurationUnits out = new JiffDurationUnits();
        for (Integer i = 0; i < order.size(); i++) {
            out.setUnitValue(order.get(i), n(values.get(i)));
        }
        out.setSign(1);
        return out;
    }

    private static JiffDurationUnits one(JiffUnit unit, Long value) {
        return units(new List<JiffUnit>{ unit }, new List<Long>{ value });
    }

    @IsTest
    static void unitsBecomeASpanAsWritten() {
        JiffDurationUnits built = units(
            new List<JiffUnit>{ JiffUnit.YEAR, JiffUnit.MONTH, JiffUnit.HOUR },
            new List<Long>{ 5L, 4L, 3L }
        );
        Assert.areEqual(JiffUnit.HOUR, built.getMin());
        Assert.areEqual(new JiffSpan().years(5).months(4).hours(3), built.toSpan());
        built.setSign(-1);
        Assert.areEqual('-P5Y4MT3H', built.toSpan().toString());
        Assert.areEqual(new JiffSpan().minutes(90), one(JiffUnit.MINUTE, 90L).toSpan());
    }

    @IsTest
    static void unitsBecomeASignedDuration() {
        JiffDurationUnits built = units(
            new List<JiffUnit>{
                JiffUnit.HOUR,
                JiffUnit.MINUTE,
                JiffUnit.SECOND,
                JiffUnit.MILLISECOND,
                JiffUnit.MICROSECOND,
                JiffUnit.NANOSECOND
            },
            new List<Long>{ 1L, 2L, 3L, 4L, 5L, 6L }
        );
        Assert.areEqual(JiffSignedDuration.newInstance(3723L, 4005006), built.toSignedDuration());
        built.setSign(-1);
        Assert.areEqual(JiffSignedDuration.newInstance(-3723L, -4005006), built.toSignedDuration());
        // 999:999:999 is balanced when it becomes a duration.
        Assert.areEqual(
            'PT1015H55M39S',
            units(
                    new List<JiffUnit>{ JiffUnit.HOUR, JiffUnit.MINUTE, JiffUnit.SECOND },
                    new List<Long>{ 999L, 999L, 999L }
                )
                .toSignedDuration()
                .toString()
        );
    }

    @IsTest
    static void nothingIsBuiltUntilAUnitIsSet() {
        JiffDurationUnits empty = new JiffDurationUnits();
        Assert.isNull(empty.getMin());
        try {
            empty.toSpan();
            Assert.fail('expected an empty builder to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('no parsed duration components', e.getMessage());
        }
        try {
            empty.toSignedDuration();
            Assert.fail('expected an empty builder to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('no parsed duration components', e.getMessage());
        }
    }

    @IsTest
    static void aZeroDurationHasNoSign() {
        JiffDurationUnits zero = one(JiffUnit.DAY, 0L);
        zero.setSign(-1);
        Assert.isTrue(zero.toSpan().isZero());
        JiffDurationUnits zeroSeconds = one(JiffUnit.SECOND, 0L);
        zeroSeconds.setFraction(0);
        zeroSeconds.setSign(-1);
        Assert.areEqual(JiffSignedDuration.ZERO, zeroSeconds.toSignedDuration());
        // A fraction on its own is enough to make it non-zero.
        JiffDurationUnits half = one(JiffUnit.SECOND, 0L);
        half.setFraction(500000000);
        half.setSign(-1);
        Assert.areEqual('-PT0.5S', half.toSpan().toString());
        Assert.areEqual('-PT0.5S', half.toSignedDuration().toString());
    }

    @IsTest
    static void unitsMustGoFromLargestToSmallestWithoutRepeats() {
        JiffDurationUnits built = one(JiffUnit.MONTH, 2L);
        try {
            built.setUnitValue(JiffUnit.YEAR, n(1L));
            Assert.fail('expected a larger unit after a smaller one to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'found value with unit year after unit month, but units must be written ' +
                'from largest to smallest (and they can\'t be repeated)',
                e.getMessage()
            );
        }
        try {
            built.setUnitValue(JiffUnit.MONTH, n(1L));
            Assert.fail('expected a repeated unit to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'found value with unit month after unit month, but units must be written ' +
                'from largest to smallest (and they can\'t be repeated)',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void clockTimeSetsHoursMinutesAndSeconds() {
        JiffDurationUnits built = one(JiffUnit.DAY, 5L);
        built.setHms(n(1L), n(2L), n(3L), 123456789);
        Assert.areEqual(JiffUnit.SECOND, built.getMin());
        Assert.areEqual('P5DT1H2M3.123456789S', built.toSpan().toString());
        JiffDurationUnits plain = new JiffDurationUnits();
        plain.setHms(n(1L), n(2L), n(3L), -1);
        plain.setSign(1);
        Assert.areEqual('PT1H2M3S', plain.toSpan().toString());
        Assert.areEqual('PT1H2M3S', plain.toSignedDuration().toString());
    }

    @IsTest
    static void clockTimeMayOnlyFollowCalendarUnits() {
        try {
            one(JiffUnit.HOUR, 2L).setHms(n(5L), n(6L), n(7L), -1);
            Assert.fail('expected a clock time after hours to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'found `HH:MM:SS` after unit hour, but `HH:MM:SS` can only appear after ' +
                'years, months, weeks or days',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void aFractionIsCarriedIntoSmallerUnits() {
        Map<JiffUnit, String> expected = new Map<JiffUnit, String>{
            JiffUnit.HOUR => 'PT1H30M',
            JiffUnit.MINUTE => 'PT1M30S',
            JiffUnit.SECOND => 'PT1.5S',
            JiffUnit.MILLISECOND => 'PT0.0015S',
            JiffUnit.MICROSECOND => 'PT0.0000015S'
        };
        for (JiffUnit unit : expected.keySet()) {
            JiffDurationUnits built = one(unit, 1L);
            built.setFraction(500000000);
            Assert.areEqual(expected.get(unit), built.toSpan().toString());
            Assert.areEqual(expected.get(unit), built.toSignedDuration().toString());
        }
        // 0.123456789 of an hour, spread over every unit below it.
        JiffDurationUnits hour = one(JiffUnit.HOUR, 0L);
        hour.setFraction(123456789);
        Assert.areEqual(
            new JiffSpan()
                .minutes(7)
                .seconds(24)
                .milliseconds(444)
                .microseconds(440)
                .nanoseconds(400),
            hour.toSpan()
        );
    }

    @IsTest
    static void onlyHoursThroughMicrosecondsMayHaveAFraction() {
        try {
            one(JiffUnit.YEAR, 1L).setFraction(500000000);
            Assert.fail('expected a fraction of a year to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('fractional years are not supported', e.getMessage());
        }
        try {
            one(JiffUnit.DAY, 1L).setFraction(500000000);
            Assert.fail('expected a fraction of a day to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('fractional days are not supported', e.getMessage());
        }
        try {
            one(JiffUnit.NANOSECOND, 1L).setFraction(500000000);
            Assert.fail('expected a fraction of a nanosecond to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('fractional nanoseconds are not supported', e.getMessage());
        }
    }

    @IsTest
    static void aTimeUnitBeyondItsLimitSpillsIntoSmallerUnits() {
        Assert.areEqual('PT175307616H60M', one(JiffUnit.HOUR, 175307617L).toSpan().toString());
        Assert.areEqual(
            'PT10518456960M60S',
            one(JiffUnit.MINUTE, 10518456961L).toSpan().toString()
        );
        Assert.areEqual(
            'PT631107417600.001S',
            one(JiffUnit.MILLISECOND, 631107417600001L).toSpan().toString()
        );
        // The excess is added to a smaller unit that was also set.
        JiffDurationUnits both = units(
            new List<JiffUnit>{ JiffUnit.HOUR, JiffUnit.MINUTE, JiffUnit.SECOND },
            new List<Long>{ 175307617L, 10518456960L, 1L }
        );
        Assert.areEqual('PT175307616H10518456960M3601S', both.toSpan().toString());
        both.setSign(-1);
        Assert.areEqual('-PT175307616H10518456960M3601S', both.toSpan().toString());
        // One whole second more than a span's seconds, milliseconds and microseconds hold
        // goes all the way down to the nanoseconds.
        Assert.areEqual(
            new JiffSpan()
                .seconds(631107417600L)
                .milliseconds(631107417600000L)
                .microseconds(631107417600000000L)
                .nanoseconds(1000000000L),
            one(JiffUnit.SECOND, 1893322252801L).toSpan()
        );
    }

    @IsTest
    static void spansRejectWhatDoesNotFitEvenAfterSpilling() {
        try {
            one(JiffUnit.MICROSECOND, 640330789636854776L).toSpan();
            Assert.fail('expected the microseconds to overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to set value for microsecond unit on span: ' +
                'failed to set nanosecond value from fractional component',
                e.getMessage()
            );
        }
        try {
            one(JiffUnit.YEAR, 19999L).toSpan();
            Assert.fail('expected the years to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to set value for year unit on span: ' +
                'parameter \'years\' is not in the required range of -19998..=19998',
                e.getMessage()
            );
        }
        try {
            one(JiffUnit.HOUR, 9223372036854775807L).toSpan();
            Assert.fail('expected the hours to overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to set value for hour unit on span: ' +
                'converting hours to seconds overflows a signed 64-bit integer',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void valuesBeyondASigned64BitIntegerNeedTheRightSign() {
        JiffI128 twoToThe63 = JiffI128.parse('9223372036854775808');
        JiffDurationUnits seconds = new JiffDurationUnits();
        seconds.setUnitValue(JiffUnit.SECOND, twoToThe63);
        seconds.setSign(1);
        try {
            seconds.toSignedDuration();
            Assert.fail('expected 2^63 seconds to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'value for seconds is too big (or small) to fit into a signed 64-bit integer',
                e.getMessage()
            );
        }
        seconds.setSign(-1);
        Assert.areEqual(JiffMath.LONG_MIN, seconds.toSignedDuration().asSecs());

        // A span's nanoseconds stop one short of the most negative 64 bit integer.
        JiffDurationUnits nanos = new JiffDurationUnits();
        nanos.setUnitValue(JiffUnit.NANOSECOND, twoToThe63);
        nanos.setSign(-1);
        try {
            nanos.toSpan();
            Assert.fail('expected -2^63 nanoseconds to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to set value for nanosecond unit on span: ' +
                    'parameter \'nanoseconds\' is not in the required range of ' +
                    '-9223372036854775807..=9223372036854775807',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void signedDurationsRejectCalendarUnitsAndOverflow() {
        try {
            one(JiffUnit.DAY, 1L).toSignedDuration();
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsing calendar units (days in this case) in this context is not supported ' +
                '(perhaps try parsing into a `JiffSpan` instead)',
                e.getMessage()
            );
        }
        try {
            one(JiffUnit.HOUR, 2562047788015216L).toSignedDuration();
            Assert.fail('expected the hours to overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'accumulated duration overflowed when adding value to unit hour',
                e.getMessage()
            );
        }
        JiffDurationUnits fractional = one(JiffUnit.HOUR, 2562047788015215L);
        fractional.setFraction(600000000);
        try {
            fractional.toSignedDuration();
            Assert.fail('expected the fraction to overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'accumulated duration overflowed when adding fractional value to unit hour',
                e.getMessage()
            );
        }
    }
}
