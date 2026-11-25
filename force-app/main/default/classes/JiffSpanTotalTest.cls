@IsTest
private class JiffSpanTotalTest {
    private static final List<JiffUnit> UNITS = JiffUnit.values();

    private static JiffSpan span(String text) {
        return JiffOracleSupport.toSpan(text);
    }

    /** A Double from the decimal text Jiff printed, which converts back to exactly that value. */
    private static Double dbl(String text) {
        return Double.valueOf(text);
    }

    private static JiffSpanRelativeTo day24() {
        return JiffSpanRelativeTo.daysAre24Hours();
    }

    private static JiffSpanRelativeTo zonedAt(
        Integer year,
        Integer month,
        Integer day,
        String zone
    ) {
        return JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(year, month, day).inTz(zone)
        );
    }

    // ---- vectors from Jiff -------------------------------------------------

    /** The total, or `ERR:` and the error. `matches` compares a Double to Jiff's printed one. */
    private static String tryTotal(
        JiffSpan value,
        JiffUnit unit,
        JiffSpanRelativeTo relative,
        String expected
    ) {
        Double total;
        try {
            total = relative == null ? value.total(unit) : value.total(unit, relative);
        } catch (JiffException e) {
            return JiffSpanVectorSupport.failure(e);
        }
        if (expected.startsWith('ERR:')) {
            return String.valueOf(total);
        }
        Double wanted = Double.valueOf(expected);
        if (total == wanted) {
            return expected;
        }
        return String.valueOf(total);
    }

    @IsTest
    static void totalsInEveryUnitAgreeWithJiffToTheLastBit() {
        JiffSpanVectorSupport vectors = new JiffSpanVectorSupport();
        for (String row : JiffSpanTotalVectors.rows()) {
            List<String> f = JiffOracleSupport.fields(row);
            JiffSpan value = span(f.get(0));
            JiffSpanRelativeTo relative = JiffSpanVectorSupport.relative(f.get(1));
            for (Integer i = 0; i < UNITS.size(); i++) {
                String expected = f.get(2 + i);
                vectors.check(
                    expected,
                    tryTotal(value, UNITS.get(i), relative, expected),
                    'total in ' + UNITS.get(i),
                    row
                );
            }
        }
        vectors.verify(3000);
    }

    // ---- Jiff's examples and tests ----------------------------------------

    @IsTest
    static void totalOfTimeUnitsNeedsNoReference() {
        // From Jiff's documentation of `Span::total` and its `test_total`.
        Assert.areEqual(dbl('11400'), span('3h 10m').total(JiffUnit.SECOND));
        Assert.areEqual(dbl('469200'), span('130h 20m').total(JiffUnit.SECOND));
        Assert.areEqual(dbl('1428.8980208333332'), span('123456789s').total(JiffUnit.DAY, day24()));
    }

    @IsTest
    static void aMonthInATimeZoneCanBeAnHourShort() {
        // From Jiff's documentation: March 2024 in New York has a 23 hour day.
        Assert.areEqual(
            dbl('1.0013888888888889'),
            span('744h').total(JiffUnit.MONTH, zonedAt(2024, 3, 1, 'America/New_York'))
        );
        Assert.areEqual(
            dbl('1'),
            span('744h')
                .total(
                    JiffUnit.MONTH,
                    JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2024, 3, 1))
                )
        );
    }

    @IsTest
    static void monthsFromRomeAndFromACivilDateDiffer() {
        // Jiff's `test_total`.
        JiffDateTime start = JiffDateTime.newInstance(2020, 1, 1, 0, 0, 0, 0);
        Assert.areEqual(
            dbl('3.7958333333333334'),
            span('2756h')
                .total(
                    JiffUnit.MONTH,
                    JiffSpanRelativeTo.fromZonedDateTime(start.inTz('Europe/Rome'))
                )
        );
        Assert.areEqual(
            dbl('3.7944444444444443'),
            span('2756h').total(JiffUnit.MONTH, JiffSpanRelativeTo.fromDateTime(start))
        );
    }

    @IsTest
    static void aZeroSpanTotalsZeroInEveryCalendarUnit() {
        // Jiff's `test_total_zero`.
        JiffDate d = JiffDate.newInstance(2023, 10, 9);
        List<JiffSpanRelativeTo> references = new List<JiffSpanRelativeTo>{
            JiffSpanRelativeTo.fromDate(d),
            JiffSpanRelativeTo.fromDateTime(d.at(0, 0, 0, 0)),
            JiffSpanRelativeTo.fromZonedDateTime(d.inTz('America/New_York'))
        };
        Double zero = 0;
        for (
            JiffUnit unit : new List<JiffUnit>{
                JiffUnit.YEAR,
                JiffUnit.MONTH,
                JiffUnit.WEEK,
                JiffUnit.DAY
            }
        ) {
            for (JiffSpanRelativeTo reference : references) {
                Assert.areEqual(
                    zero,
                    new JiffSpan().total(unit, reference),
                    unit + ' from ' + reference
                );
            }
        }
        Assert.areEqual(zero, d.since(d).total(JiffUnit.DAY, references.get(0)));
    }

    @IsTest
    static void tenMinutesIsMeasuredAgainstATwentyFiveHourDay() {
        // Jiff's `span_total_minutes_to_days_dst`.
        JiffZonedDateTime zdt = JiffDate.newInstance(2024, 11, 3)
            .at(1, 50, 0, 0)
            .inTz('America/New_York');
        Double ten = 10;
        Double minutesInTheDay = 25 * 60;
        Assert.areEqual(
            ten / minutesInTheDay,
            span('10m').total(JiffUnit.DAY, JiffSpanRelativeTo.fromZonedDateTime(zdt))
        );
    }

    @IsTest
    static void sortingByTotalMatchesSortingByComparison() {
        // From Jiff's documentation of `Span::total` ("infallible sorting").
        JiffSpan span1 = span('79h 10m');
        JiffSpan span2 = span('3d 7h 630s');
        JiffSpan span3 = span('3d 6h 50m');
        JiffSpanRelativeTo losAngeles = JiffSpanRelativeTo.fromZonedDateTime(
            JiffDate.newInstance(2020, 11, 1).inTz('America/Los_Angeles')
        );
        Assert.isTrue(
            span1.total(JiffUnit.DAY, losAngeles) < span3.total(JiffUnit.DAY, losAngeles)
        );
        Assert.isTrue(
            span3.total(JiffUnit.DAY, losAngeles) < span2.total(JiffUnit.DAY, losAngeles)
        );
        JiffSpanRelativeTo civil = JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2020, 11, 1));
        Assert.isTrue(span3.total(JiffUnit.DAY, civil) < span1.total(JiffUnit.DAY, civil));
        Assert.isTrue(span1.total(JiffUnit.DAY, civil) < span2.total(JiffUnit.DAY, civil));
    }

    // ---- errors ----------------------------------------------------------

    @IsTest
    static void calendarUnitsNeedAReference() {
        try {
            span('1d').total(JiffUnit.YEAR);
            Assert.fail('years without a reference must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'using unit \'year\' in a span or configuration requires that a relative reference time be given, but none was provided',
                e.getMessage()
            );
        }
        try {
            span('1h').total(JiffUnit.YEAR, day24());
            Assert.fail('years with 24 hour days must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'using unit \'year\' in span or configuration requires that a relative reference time be given (`JiffSpanRelativeTo.daysAre24Hours()` was given but this only permits using days and weeks without a relative reference time)',
                e.getMessage()
            );
        }
        try {
            span('1y')
                .total(JiffUnit.DAY, JiffSpanRelativeTo.fromDate(JiffDate.newInstance(9999, 6, 1)));
            Assert.fail('a year past 9999 must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to add span to date: parameter \'year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
        String nanosRange = 'parameter \'nanoseconds\' is not in the required range of -9223372036854775807..=9223372036854775807';
        try {
            span('300y')
                .total(
                    JiffUnit.NANOSECOND,
                    JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2000, 1, 1))
                );
            Assert.fail('300 years of nanoseconds must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to get span between datetimes with largest unit set to \'nanoseconds\': ' +
                nanosRange,
                e.getMessage()
            );
        }
        try {
            span('300y').total(JiffUnit.NANOSECOND, zonedAt(2000, 1, 1, 'America/New_York'));
            Assert.fail('300 years of nanoseconds must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to get span between zoned datetimes with largest unit set to \'nanoseconds\': ' +
                nanosRange,
                e.getMessage()
            );
        }
        // 3000 years of microseconds still fits, and its total is exact to the last bit.
        Assert.areEqual(
            dbl('9.46708992e16'),
            span('3000y')
                .total(
                    JiffUnit.MICROSECOND,
                    JiffSpanRelativeTo.fromDate(JiffDate.newInstance(2000, 1, 1))
                )
        );
        try {
            span('1h').total(null);
            Assert.fail('a null unit must be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the unit to total must not be null', e.getMessage());
        }
    }

    // ---- floating point --------------------------------------------------

    @IsTest
    static void wideNanosecondCountsConvertToTheNearestDouble() {
        // Beyond a Long, the count is scaled down with a sticky bit. 2^64 + 1 and 2^64 + 2^11
        // (exactly halfway between two Doubles) both round to 2^64, while 2^64 + 2^11 + 1
        // rounds up: ties go to even, anything past the tie goes up.
        JiffSignedDuration twoTo64 = JiffSignedDuration.newInstance(18446744073L, 709551616);
        Double base = JiffSpanRelative.toDouble(twoTo64);
        Assert.areEqual(
            base,
            JiffSpanRelative.toDouble(twoTo64.add(JiffSignedDuration.fromNanos(1L)))
        );
        Assert.areEqual(
            base,
            JiffSpanRelative.toDouble(twoTo64.add(JiffSignedDuration.fromNanos(2048L)))
        );
        Double next = JiffSpanRelative.toDouble(twoTo64.add(JiffSignedDuration.fromNanos(4096L)));
        Assert.isTrue(next > base, 'the next Double up is 2^64 + 2^12');
        Assert.areEqual(
            next,
            JiffSpanRelative.toDouble(twoTo64.add(JiffSignedDuration.fromNanos(2049L)))
        );
        Assert.areEqual(
            -next,
            JiffSpanRelative.toDouble(twoTo64.add(JiffSignedDuration.fromNanos(2049L)).negate())
        );
        // 2^64 - 1 is just below a power of two, and rounds up to it.
        Assert.areEqual(
            base,
            JiffSpanRelative.toDouble(twoTo64.subtract(JiffSignedDuration.fromNanos(1L)))
        );
        Double viaLong = 9223372036854775807L;
        Double twice = viaLong * 2;
        Assert.areEqual(twice, base);
    }
}
