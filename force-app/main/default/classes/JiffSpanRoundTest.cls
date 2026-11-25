@IsTest
private class JiffSpanRoundTest {
    private static final String DAY_NEEDS_RELATIVE = 'using unit \'day\' in a span or configuration requires that either a relative reference time be given or `JiffSpanRelativeTo.daysAre24Hours()` is used to indicate invariant 24-hour days, but neither were provided';
    private static final String MONTH_NEEDS_RELATIVE = 'using unit \'month\' in a span or configuration requires that a relative reference time be given, but none was provided';
    private static final String MONTH_NOT_24_HOURS = 'using unit \'month\' in span or configuration requires that a relative reference time be given (`JiffSpanRelativeTo.daysAre24Hours()` was given but this only permits using days and weeks without a relative reference time)';

    private static JiffSpan span(String text) {
        return JiffOracleSupport.toSpan(text);
    }

    private static JiffSpanRelativeTo onDate(Integer year, Integer month, Integer day) {
        return JiffSpanRelativeTo.fromDate(JiffDate.newInstance(year, month, day));
    }

    private static JiffSpanRelativeTo zonedAt(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        String zone
    ) {
        return JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(year, month, day).at(hour, 0, 0, 0).inTz(zone)
        );
    }

    private static String failureOf(JiffSpan value, JiffSpanRound options) {
        try {
            value.round(options);
        } catch (JiffException e) {
            return e.getMessage();
        }
        Assert.fail('rounding ' + value + ' was expected to fail');
        return null;
    }

    // ---- the options -----------------------------------------------------

    @IsTest
    static void defaultOptionsOnlyBalanceUpToTheSpansBiggestUnit() {
        JiffSpanRound options = new JiffSpanRound();
        Assert.areEqual(JiffUnit.NANOSECOND, options.getSmallest());
        Assert.isNull(options.getLargest());
        Assert.areEqual(JiffRoundMode.HALF_EXPAND, options.getMode());
        Assert.areEqual(1L, options.getIncrement());
        Assert.isNull(options.getRelative());
        // Jiff rebalances below the span's biggest unit even when nothing is rounded.
        Assert.areEqual(span('90m 1s 500ms'), span('90m 1500ms').round(options));
        Assert.areEqual(span('90m 1s 500ms'), span('90m 1s 500ms').round(options));
    }

    @IsTest
    static void settersReturnNewOptions() {
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.daysAre24Hours();
        JiffSpanRound base = new JiffSpanRound();
        JiffSpanRound options = base.smallest(JiffUnit.MINUTE)
            .largest(JiffUnit.DAY)
            .mode(JiffRoundMode.TRUNC)
            .increment(15L)
            .relative(relative);
        Assert.areEqual(JiffUnit.MINUTE, options.getSmallest());
        Assert.areEqual(JiffUnit.DAY, options.getLargest());
        Assert.areEqual(JiffRoundMode.TRUNC, options.getMode());
        Assert.areEqual(15L, options.getIncrement());
        Assert.areEqual(relative, options.getRelative());
        Assert.areEqual(JiffUnit.NANOSECOND, base.getSmallest(), 'the original is unchanged');
        Assert.isNull(options.largest(null).getLargest(), 'null restores the default');
        Assert.isNull(options.relative(null).getRelative(), 'null removes the reference');
        Assert.areEqual(JiffUnit.HOUR, JiffSpanRound.to(JiffUnit.HOUR).getSmallest());
    }

    @IsTest
    static void nullSettingsAreRejected() {
        List<String> messages = new List<String>();
        try {
            new JiffSpanRound().smallest(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffSpanRound().mode(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffSpanRound().increment(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            span('1h').round((JiffSpanRound) null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'smallest unit must not be null',
                'rounding mode must not be null',
                'rounding increment must not be null',
                'the rounding options must not be null'
            },
            messages
        );
    }

    // ---- vectors from Jiff -------------------------------------------------

    @IsTest
    static void roundingAgreesWithJiff() {
        JiffSpanVectorSupport vectors = new JiffSpanVectorSupport();
        for (String row : JiffSpanRoundVectors.rows()) {
            List<String> f = JiffOracleSupport.fields(row);
            JiffSpanRound options = new JiffSpanRound()
                .smallest(JiffOracleSupport.unit(f.get(2)))
                .largest(JiffSpanVectorSupport.optionalUnit(f.get(3)))
                .mode(JiffOracleSupport.mode(f.get(4)))
                .increment(Long.valueOf(f.get(5)))
                .relative(JiffSpanVectorSupport.relative(f.get(1)));
            String actual;
            try {
                actual = JiffOracleSupport.spanText(span(f.get(0)).round(options));
            } catch (JiffException e) {
                actual = JiffSpanVectorSupport.failure(e);
            }
            vectors.check(f.get(6), actual, 'round', row);
        }
        vectors.verify(800);
    }

    // ---- Jiff's examples -------------------------------------------------

    @IsTest
    static void balancingWithoutAReferenceStopsAtHours() {
        // From Jiff's documentation of `Span::round`.
        JiffSpan nanos = new JiffSpan().nanoseconds(123456789123456789L);
        Assert.areEqual(
            span('34293h 33m 9s 123ms 456us 789ns'),
            nanos.round(new JiffSpanRound().largest(JiffUnit.HOUR))
        );
        Assert.areEqual(
            span('1428d 21h 33m 9s 123ms 456us 789ns'),
            nanos.round(
                new JiffSpanRound()
                    .largest(JiffUnit.DAY)
                    .relative(JiffSpanRelativeTo.daysAre24Hours())
            )
        );
        Assert.areEqual(
            span('34293h 33m 9s'),
            nanos.round(new JiffSpanRound().largest(JiffUnit.HOUR).smallest(JiffUnit.SECOND))
        );
        Assert.areEqual(span('34294h'), nanos.round(JiffUnit.HOUR));
    }

    @IsTest
    static void balancingWithAReferenceUsesTheCalendar() {
        Assert.areEqual(
            span('2y 8mo 26d'),
            span('1000d')
                .round(new JiffSpanRound().largest(JiffUnit.YEAR).relative(onDate(2000, 1, 1)))
        );
        // From the documentation of `TryFrom<SignedDuration> for Span`.
        Assert.areEqual(
            span('1y 2mo 25d 7m 30s'),
            JiffSpan.fromDuration(JiffSignedDuration.fromSecs(450L * 86401))
                .round(new JiffSpanRound().largest(JiffUnit.YEAR).relative(onDate(2024, 1, 1)))
        );
    }

    @IsTest
    static void roundingToIncrementsAndModes() {
        Assert.areEqual(
            span('24h'),
            JiffSpan.parse('PT23h50m3.123s').round(JiffSpanRound.to(JiffUnit.MINUTE).increment(30L))
        );
        // Whole quarters in 10 months and 15 days.
        JiffSpan quarters = span('10mo 15d')
            .round(
                JiffSpanRound.to(JiffUnit.MONTH)
                    .increment(3L)
                    .mode(JiffRoundMode.TRUNC)
                    .relative(onDate(2024, 1, 1))
            );
        Assert.areEqual(3L, quarters.getMonths() / 3);
        // From Jiff's documentation of `RoundMode`.
        Assert.areEqual(span('2h'), span('1h 59m').round(JiffUnit.HOUR));
        Assert.areEqual(
            span('1h'),
            span('1h 59m').round(JiffSpanRound.to(JiffUnit.HOUR).mode(JiffRoundMode.TRUNC))
        );
    }

    @IsTest
    static void roundingDayTimeSpansAsJiffTestsDo() {
        // Jiff's `test_round_day_time`.
        Assert.areEqual(span('0'), span('29s').round(JiffUnit.MINUTE));
        Assert.areEqual(span('1m'), span('30s').round(JiffUnit.MINUTE));
        Assert.areEqual(
            span('8000000us'),
            span('8s')
                .round(
                    new JiffSpanRound().smallest(JiffUnit.NANOSECOND).largest(JiffUnit.MICROSECOND)
                )
        );
        Assert.areEqual(
            span('2h 10m'),
            span('130m')
                .round(
                    new JiffSpanRound()
                        .largest(JiffUnit.DAY)
                        .relative(JiffSpanRelativeTo.daysAre24Hours())
                )
        );
        Assert.areEqual(span('11m'), span('10m 52s').round(JiffUnit.MINUTE));
        Assert.areEqual(
            span('10m'),
            span('10m 52s').round(JiffSpanRound.to(JiffUnit.MINUTE).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(
            span('9258s'),
            span('2h 34m 18s').round(new JiffSpanRound().largest(JiffUnit.SECOND))
        );
        Assert.areEqual(
            span('10m'),
            span('6m')
                .round(JiffSpanRound.to(JiffUnit.MINUTE).increment(5L).mode(JiffRoundMode.CEIL))
        );
    }

    @IsTest
    static void roundingAZeroSpanGivesZero() {
        // Jiff's `test_round_zero`.
        JiffDate d = JiffDate.newInstance(2023, 10, 9);
        JiffSpanRelativeTo zoned = JiffSpanRelativeTo.fromZonedDateTime(d.inTz('America/New_York'));
        for (
            JiffUnit smallest : new List<JiffUnit>{
                JiffUnit.YEAR,
                JiffUnit.MONTH,
                JiffUnit.WEEK,
                JiffUnit.DAY
            }
        ) {
            JiffSpanRound options = JiffSpanRound.to(smallest);
            Assert.areEqual(
                new JiffSpan(),
                new JiffSpan().round(options.relative(JiffSpanRelativeTo.fromDate(d)))
            );
            Assert.areEqual(new JiffSpan(), new JiffSpan().round(options.relative(zoned)));
        }
        Assert.areEqual(
            new JiffSpan(),
            new JiffSpan()
                .round(JiffSpanRound.to(JiffUnit.HOUR).largest(JiffUnit.DAY).relative(zoned))
        );
    }

    @IsTest
    static void roundingRelativeToZonedCalendarDays() {
        // Jiff's `test_round_relative_zoned_calendar`.
        Assert.areEqual(
            span('3mo 24d'),
            span('2756h')
                .round(
                    new JiffSpanRound()
                        .largest(JiffUnit.YEAR)
                        .smallest(JiffUnit.DAY)
                        .relative(zonedAt(2020, 1, 1, 0, 'America/New_York'))
                )
        );
        Assert.areEqual(
            span('24h 30m'),
            span('24h 5ns')
                .round(
                    new JiffSpanRound()
                        .largest(JiffUnit.DAY)
                        .smallest(JiffUnit.MINUTE)
                        .relative(zonedAt(2000, 10, 29, 0, 'America/Vancouver'))
                        .mode(JiffRoundMode.EXPAND)
                        .increment(30L)
                )
        );
        // The month back from 2024-04-11 02:00 in New York crosses the 23 hour day.
        JiffSpanRelativeTo april = zonedAt(2024, 4, 11, 2, 'America/New_York');
        Assert.areEqual(
            span('-1mo -1d -1h'),
            span('-1mo -24h').round(JiffSpanRound.to(JiffUnit.MILLISECOND).relative(april))
        );
        JiffSpanRelativeTo june = zonedAt(2024, 6, 11, 2, 'America/New_York');
        Assert.areEqual(
            span('-1mo -1d'),
            span('-1mo -24h').round(JiffSpanRound.to(JiffUnit.MILLISECOND).relative(june))
        );
    }

    @IsTest
    static void roundingRelativeToZonedTimes() {
        // Jiff's `test_round_relative_zoned_time`.
        JiffSpanRound toYears = new JiffSpanRound().largest(JiffUnit.YEAR);
        Assert.areEqual(
            span('3mo 23d 21h'),
            span('2756h').round(toYears.relative(zonedAt(2020, 1, 1, 0, 'America/New_York')))
        );
        Assert.areEqual(
            span('3mo 23d 19h'),
            span('2756h').round(toYears.relative(zonedAt(2020, 9, 1, 0, 'America/New_York')))
        );
        Assert.areEqual(
            span('3h'),
            span('3h').round(toYears.relative(zonedAt(2020, 3, 8, 0, 'America/New_York')))
        );
    }

    @IsTest
    static void roundingRelativeToCivilDays() {
        // Jiff's `test_round_relative_day_time`.
        JiffSpanRound toYears = new JiffSpanRound().largest(JiffUnit.YEAR);
        Assert.areEqual(
            span('3mo 23d 20h'),
            span('2756h').round(toYears.relative(onDate(2020, 1, 1)))
        );
        Assert.areEqual(
            span('3mo 23d 20h'),
            span('2756h').round(toYears.relative(onDate(2020, 9, 1)))
        );
        Assert.areEqual(span('6mo 8d'), span('190d').round(toYears.relative(onDate(2020, 1, 1))));
        JiffSpanRound toMicros = toYears.smallest(JiffUnit.MICROSECOND);
        Assert.areEqual(
            span('1mo'),
            span('30d 23h 59m 59s 999ms 999us 999ns').round(toMicros.relative(onDate(2024, 5, 1)))
        );
        Assert.areEqual(
            span('1y'),
            span('364d 23h 59m 59s 999ms 999us 999ns').round(toMicros.relative(onDate(2023, 1, 1)))
        );
        Assert.areEqual(
            span('1y 1d'),
            span('365d 23h 59m 59s 999ms 999us 999ns').round(toMicros.relative(onDate(2023, 1, 1)))
        );
        // 2024 is a leap year, so the same span is just a year from its first day.
        Assert.areEqual(
            span('1y'),
            span('365d 23h 59m 59s 999ms 999us 999ns').round(toMicros.relative(onDate(2024, 1, 1)))
        );
        Assert.areEqual(span('3h'), span('3h').round(toYears.relative(onDate(2020, 3, 8))));
    }

    @IsTest
    static void negativeZonedTimesThatRoundToAWholeDayReproduceJiffsSignBug() {
        // Jiff 1.0.0 adds the day that rounded time spills into as +1 whatever the span's
        // sign (`days(balanced.get_days() + day_delta)` in `Nudge::relative_zoned_time`). The
        // port matches Jiff, so these are Jiff's actual answers, not the expected -2d and -1d.
        JiffSpanRelativeTo june = zonedAt(2024, 6, 11, 2, 'America/New_York');
        JiffSpanRound toMinutes = JiffSpanRound.to(JiffUnit.MINUTE).relative(june);
        Assert.areEqual(
            span('0'),
            span('-1d -23h -59m -59s').round(toMinutes.largest(JiffUnit.DAY))
        );
        Assert.areEqual(span('1d'), span('-23h -59m -59s').round(toMinutes.largest(JiffUnit.DAY)));
        Assert.areEqual(
            span('-4d'),
            span('-5d -23h -59m -59s').round(toMinutes.largest(JiffUnit.MONTH))
        );
        // Positive spans are unaffected.
        Assert.areEqual(span('2d'), span('1d 23h 59m 59s').round(toMinutes.largest(JiffUnit.DAY)));
    }

    // ---- errors ----------------------------------------------------------

    @IsTest
    static void invalidIncrementsAreReportedAsFailedRounding() {
        Assert.areEqual(
            'failed rounding span: increment for rounding to \'hours\' must divide into `24` evenly',
            failureOf(span('1h'), JiffSpanRound.to(JiffUnit.HOUR).increment(7L))
        );
        Assert.areEqual(
            'failed rounding span: parameter \'rounding increment\' is not in the required range of 1..=1000000000',
            failureOf(span('1h'), JiffSpanRound.to(JiffUnit.HOUR).increment(0L))
        );
        Assert.areEqual(
            'failed rounding span: parameter \'rounding increment\' is not in the required range of 1..=1000000000',
            failureOf(
                span('1y'),
                JiffSpanRound.to(JiffUnit.YEAR).increment(1000000001L).relative(onDate(2000, 1, 1))
            )
        );
    }

    @IsTest
    static void largestMustNotBeSmallerThanSmallest() {
        Assert.areEqual(
            'largest unit (\'minute\') cannot be smaller than smallest unit (\'hour\')',
            failureOf(span('1h'), JiffSpanRound.to(JiffUnit.HOUR).largest(JiffUnit.MINUTE))
        );
    }

    @IsTest
    static void eachOptionThatNeedsAReferenceIsNamed() {
        Assert.areEqual(
            'error with `smallest` rounding option: ' + DAY_NEEDS_RELATIVE,
            failureOf(span('1h'), JiffSpanRound.to(JiffUnit.DAY))
        );
        Assert.areEqual(
            'error with `largest` rounding option: ' + DAY_NEEDS_RELATIVE,
            failureOf(span('1h'), new JiffSpanRound().largest(JiffUnit.DAY))
        );
        Assert.areEqual(
            'error with `largest` rounding option: ' + MONTH_NEEDS_RELATIVE,
            failureOf(span('1h'), new JiffSpanRound().largest(JiffUnit.MONTH))
        );
        Assert.areEqual(
            'error with largest unit in span to be rounded: ' + DAY_NEEDS_RELATIVE,
            failureOf(span('1d'), JiffSpanRound.to(JiffUnit.HOUR))
        );
        Assert.areEqual(
            MONTH_NOT_24_HOURS,
            failureOf(
                span('1mo'),
                new JiffSpanRound().relative(JiffSpanRelativeTo.daysAre24Hours())
            )
        );
        Assert.areEqual(
            MONTH_NOT_24_HOURS,
            failureOf(
                span('1h'),
                JiffSpanRound.to(JiffUnit.MONTH).relative(JiffSpanRelativeTo.daysAre24Hours())
            )
        );
    }

    @IsTest
    static void resultsThatDoNotFitAreReported() {
        Assert.areEqual(
            'failed to convert rounded nanoseconds to span for largest unit set to \'nanoseconds\': parameter \'nanoseconds\' is not in the required range of -9223372036854775807..=9223372036854775807',
            failureOf(
                new JiffSpan().nanoseconds(JiffMath.LONG_MAX),
                JiffSpanRound.to(JiffUnit.NANOSECOND)
                    .largest(JiffUnit.NANOSECOND)
                    .increment(2L)
                    .mode(JiffRoundMode.EXPAND)
            )
        );
        Assert.areEqual(
            'failed to add span to date: parameter \'year\' is not in the required range of -9999..=9999',
            failureOf(
                span('19998y'),
                new JiffSpanRound().largest(JiffUnit.NANOSECOND).relative(onDate(2000, 1, 1))
            )
        );
        Assert.areEqual(
            'failed to add span to date: parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896',
            failureOf(span('1w'), JiffSpanRound.to(JiffUnit.WEEK).relative(onDate(9999, 12, 25)))
        );
    }
}
