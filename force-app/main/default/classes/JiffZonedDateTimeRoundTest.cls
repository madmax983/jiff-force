/**
 * Rounding of `JiffZonedDateTime`.
 *
 * Expected values are from the examples in Jiff's documentation of `ZonedDateTime::round` and
 * `ZonedDateTimeRound`, from the tests in `jiff/src/zoned.rs`, or were printed by Jiff 1.0.0
 * itself.
 */
@IsTest
private class JiffZonedDateTimeRoundTest {
    private static final String NEW_YORK = 'America/New_York';
    private static final String OVERFLOW_UTC =
        'converting datetime with time zone offset `+00` to timestamp overflowed: ' +
        'parameter \'Unix timestamp seconds\' is not in the required range of ' +
        '-377705023201..=253402207200';
    // The order of the columns in the table of rounding to days.
    private static final List<JiffRoundMode> MODES = new List<JiffRoundMode>{
        JiffRoundMode.CEIL,
        JiffRoundMode.FLOOR,
        JiffRoundMode.EXPAND,
        JiffRoundMode.TRUNC,
        JiffRoundMode.HALF_CEIL,
        JiffRoundMode.HALF_FLOOR,
        JiffRoundMode.HALF_EXPAND,
        JiffRoundMode.HALF_TRUNC,
        JiffRoundMode.HALF_EVEN
    };

    private static JiffZonedDateTime zoned(String text) {
        return JiffZonedTestSupport.zoned(text);
    }

    private static JiffZonedDateTime newYork(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDate.newInstance(year, month, day)
            .at(hour, minute, second, subsecNanosecond)
            .inTz(NEW_YORK);
    }

    private static void assertRoundFails(
        JiffZonedDateTime zdt,
        JiffRound options,
        String expected
    ) {
        try {
            zdt.round(options);
            Assert.fail('expected rounding ' + zdt + ' to fail with: ' + expected);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    // ---- hours and smaller ----------------------------------------------

    @IsTest
    static void roundsToTheNearestDay() {
        // rounds up
        Assert.areEqual(
            newYork(2024, 6, 20, 0, 0, 0, 0),
            newYork(2024, 6, 19, 15, 0, 0, 0).round(JiffUnit.DAY)
        );
        // rounds down
        Assert.areEqual(
            newYork(2024, 6, 19, 0, 0, 0, 0),
            newYork(2024, 6, 19, 10, 0, 0, 0).round(JiffUnit.DAY)
        );
    }

    @IsTest
    static void theRoundingModeCanBeChanged() {
        JiffZonedDateTime zdt = newYork(2024, 6, 19, 15, 0, 0, 0);
        // The default will round up to the next day for any time past noon, but using
        // truncation rounding will always round down.
        Assert.areEqual(
            newYork(2024, 6, 19, 0, 0, 0, 0),
            zdt.round(JiffRound.to(JiffUnit.DAY).mode(JiffRoundMode.TRUNC))
        );
        zdt = newYork(2024, 6, 20, 16, 24, 59, 500000000);
        // The second rounds up and causes minutes to increase.
        Assert.areEqual(newYork(2024, 6, 20, 16, 25, 0, 0), zdt.round(JiffUnit.SECOND));
        // The second just gets truncated as if it wasn't there.
        Assert.areEqual(
            newYork(2024, 6, 20, 16, 24, 59, 0),
            zdt.round(JiffRound.to(JiffUnit.SECOND).mode(JiffRoundMode.TRUNC))
        );
        Assert.areEqual(
            newYork(2024, 6, 20, 3, 26, 0, 0),
            newYork(2024, 6, 20, 3, 25, 1, 0)
                .round(JiffRound.to(JiffUnit.MINUTE).mode(JiffRoundMode.CEIL))
        );
    }

    @IsTest
    static void roundsToAnIncrement() {
        // rounds down
        Assert.areEqual(
            newYork(2024, 6, 19, 15, 25, 0, 0),
            newYork(2024, 6, 19, 15, 27, 29, 999999999)
                .round(JiffRound.to(JiffUnit.MINUTE).increment(5))
        );
        // rounds up
        Assert.areEqual(
            newYork(2024, 6, 19, 15, 30, 0, 0),
            newYork(2024, 6, 19, 15, 27, 30, 0).round(JiffRound.to(JiffUnit.MINUTE).increment(5))
        );
        // The nearest third hour.
        Assert.areEqual(
            newYork(2024, 6, 19, 15, 0, 0, 0),
            newYork(2024, 6, 19, 16, 27, 29, 999999999)
                .round(JiffRound.to(JiffUnit.HOUR).increment(3))
        );
        Assert.areEqual(
            newYork(2024, 6, 20, 3, 20, 0, 0),
            newYork(2024, 6, 20, 3, 24, 59, 0).round(JiffRound.to(JiffUnit.MINUTE).increment(10))
        );
        Assert.areEqual(
            newYork(2024, 6, 20, 3, 26, 0, 0),
            newYork(2024, 6, 20, 3, 25, 30, 0).round(JiffUnit.MINUTE)
        );
    }

    @IsTest
    static void roundingIntoAGapMovesForward() {
        JiffZonedDateTime zdt = zoned('2024-03-10T01:59:00-05:00[America/New_York]');
        Assert.areEqual(
            '2024-03-10T03:00:00-04:00[America/New_York]',
            zdt.round(JiffUnit.HOUR).toString()
        );
    }

    @IsTest
    static void roundingInsideAFoldKeepsTheOffset() {
        JiffZonedDateTime first = zoned('2024-11-03T01:59:01-04:00[America/New_York]');
        Assert.areEqual(
            '2024-11-03T01:59:00-04:00[America/New_York]',
            first.round(JiffUnit.MINUTE).toString()
        );
        JiffZonedDateTime second = zoned('2024-11-03T01:59:01-05:00[America/New_York]');
        Assert.areEqual(
            '2024-11-03T01:59:00-05:00[America/New_York]',
            second.round(JiffUnit.MINUTE).toString()
        );
    }

    @IsTest
    static void roundsClockUnitsNearTransitionsInManyZones() {
        // Each row is: input | smallest unit | increment | mode | what Jiff gives.
        List<String> cases = new List<String>{
            '2024-03-10T01:59:00-05:00[America/New_York] | Hour | 1 | HalfExpand | 2024-03-10T03:00:00-04:00[America/New_York]',
            '2024-03-10T01:29:00-05:00[America/New_York] | Hour | 1 | HalfExpand | 2024-03-10T01:00:00-05:00[America/New_York]',
            '2024-03-10T03:01:00-04:00[America/New_York] | Hour | 2 | Floor | 2024-03-10T03:00:00-04:00[America/New_York]',
            '2024-03-10T03:01:00-04:00[America/New_York] | Hour | 1 | Floor | 2024-03-10T03:00:00-04:00[America/New_York]',
            '2024-11-03T01:59:01-04:00[America/New_York] | Minute | 1 | HalfExpand | 2024-11-03T01:59:00-04:00[America/New_York]',
            '2024-11-03T01:59:01-05:00[America/New_York] | Minute | 1 | HalfExpand | 2024-11-03T01:59:00-05:00[America/New_York]',
            '2024-11-03T01:59:31-04:00[America/New_York] | Minute | 1 | HalfExpand | 2024-11-03T02:00:00-05:00[America/New_York]',
            '2024-11-03T01:59:31-05:00[America/New_York] | Minute | 1 | HalfExpand | 2024-11-03T02:00:00-05:00[America/New_York]',
            '2024-11-03T01:31:00-04:00[America/New_York] | Hour | 1 | HalfExpand | 2024-11-03T02:00:00-05:00[America/New_York]',
            '2024-11-03T01:31:00-05:00[America/New_York] | Hour | 1 | HalfExpand | 2024-11-03T02:00:00-05:00[America/New_York]',
            '2024-11-03T01:29:00-05:00[America/New_York] | Hour | 1 | HalfExpand | 2024-11-03T01:00:00-05:00[America/New_York]',
            '2024-11-03T00:31:00-04:00[America/New_York] | Hour | 1 | HalfExpand | 2024-11-03T01:00:00-04:00[America/New_York]',
            '2024-11-03T01:31:00-05:00[America/New_York] | Hour | 12 | Floor | 2024-11-03T00:00:00-04:00[America/New_York]',
            '2024-10-27T01:45:00+01:00[Europe/London] | Minute | 30 | HalfExpand | 2024-10-27T02:00:00+00:00[Europe/London]',
            '2024-10-27T01:45:00+00:00[Europe/London] | Minute | 30 | HalfExpand | 2024-10-27T02:00:00+00:00[Europe/London]',
            '2024-03-31T00:59:59.5+00:00[Europe/London] | Second | 1 | HalfExpand | 2024-03-31T02:00:00+01:00[Europe/London]',
            '2024-10-06T01:59:59.999999999+10:00[Australia/Sydney] | Microsecond | 1 | Ceil | 2024-10-06T03:00:00+11:00[Australia/Sydney]',
            '2024-07-04T23:59:59.999999999+05:30[Asia/Kolkata] | Millisecond | 1 | HalfExpand | 2024-07-05T00:00:00+05:30[Asia/Kolkata]',
            '2024-07-04T23:59:59.999999999+05:30[Asia/Kolkata] | Nanosecond | 1 | HalfExpand | 2024-07-04T23:59:59.999999999+05:30[Asia/Kolkata]',
            '2024-07-04T23:59:59.999999999+05:30[Asia/Kolkata] | Nanosecond | 500 | Floor | 2024-07-04T23:59:59.9999995+05:30[Asia/Kolkata]'
        };
        for (String row : cases) {
            List<String> f = row.split(' \\| ');
            JiffRound options = JiffRound.to(JiffZonedTestSupport.unit(f.get(1)))
                .increment(Long.valueOf(f.get(2)))
                .mode(JiffZonedTestSupport.mode(f.get(3)));
            Assert.areEqual(f.get(4), zoned(f.get(0)).round(options).toString(), row);
        }
    }

    @IsTest
    static void roundingToNanosecondsChangesNothing() {
        JiffZonedDateTime zdt = zoned('2024-11-03T01:59:01.123456789-05:00[America/New_York]');
        Assert.areEqual(zdt.toString(), zdt.round(JiffUnit.NANOSECOND).toString());
        Assert.areEqual(zdt.toString(), zdt.round(new JiffRound()).toString());
    }

    // ---- days -----------------------------------------------------------

    @IsTest
    static void roundingToDaysKnowsThatADayCanBe23HoursLong() {
        JiffZonedDateTime zdt = zoned('2025-03-09T12:15:00-04:00[America/New_York]');
        Assert.areEqual(
            // Since this day is only 23 hours long, it rounds down instead of up.
            '2025-03-09T00:00:00-05:00[America/New_York]',
            zdt.round(JiffUnit.DAY).toString()
        );
        // For 23 hour days, 12:30 is the tipping point to round up in the default rounding
        // configuration.
        zdt = zoned('2025-03-09T12:30:00-04:00[America/New_York]');
        Assert.areEqual(
            '2025-03-10T00:00:00-04:00[America/New_York]',
            zdt.round(JiffUnit.DAY).toString()
        );
    }

    @IsTest
    static void roundingToDaysKnowsThatADayCanBe25HoursLong() {
        JiffZonedDateTime zdt = zoned('2025-11-02T11:45:00-05:00[America/New_York]');
        Assert.areEqual(
            '2025-11-03T00:00:00-05:00[America/New_York]',
            zdt.round(JiffUnit.DAY).toString()
        );
        // For 25 hour days, 11:30 is the tipping point to round up in the default rounding
        // configuration. So 11:29 will round down.
        zdt = zoned('2025-11-02T11:29:00-05:00[America/New_York]');
        Assert.areEqual(
            '2025-11-02T00:00:00-04:00[America/New_York]',
            zdt.round(JiffUnit.DAY).toString()
        );
    }

    @IsTest
    static void roundsToDaysInEveryMode() {
        // Each row is: the input, what Jiff gives when it rounds down, what Jiff gives when it
        // rounds up, and which of the two (D or U) each mode produces, in the order of MODES.
        List<List<String>> cases = new List<List<String>>{
            new List<String>{
                '2025-03-09T12:15:00-04:00[America/New_York]',
                '2025-03-09T00:00:00-05:00[America/New_York]',
                '2025-03-10T00:00:00-04:00[America/New_York]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2025-03-09T12:29:59.999999999-04:00[America/New_York]',
                '2025-03-09T00:00:00-05:00[America/New_York]',
                '2025-03-10T00:00:00-04:00[America/New_York]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2025-03-09T12:30:00-04:00[America/New_York]',
                '2025-03-09T00:00:00-05:00[America/New_York]',
                '2025-03-10T00:00:00-04:00[America/New_York]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2025-11-02T11:29:59.999999999-05:00[America/New_York]',
                '2025-11-02T00:00:00-04:00[America/New_York]',
                '2025-11-03T00:00:00-05:00[America/New_York]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2025-11-02T11:30:00-05:00[America/New_York]',
                '2025-11-02T00:00:00-04:00[America/New_York]',
                '2025-11-03T00:00:00-05:00[America/New_York]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2025-11-02T11:45:00-05:00[America/New_York]',
                '2025-11-02T00:00:00-04:00[America/New_York]',
                '2025-11-03T00:00:00-05:00[America/New_York]',
                'UDUDUUUUU'
            },
            new List<String>{
                '2024-06-19T12:00:00-04:00[America/New_York]',
                '2024-06-19T00:00:00-04:00[America/New_York]',
                '2024-06-20T00:00:00-04:00[America/New_York]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2024-06-19T00:00:00-04:00[America/New_York]',
                '2024-06-19T00:00:00-04:00[America/New_York]',
                '2024-06-19T00:00:00-04:00[America/New_York]',
                'DDDDDDDDD'
            },
            new List<String>{
                '2015-10-18T12:30:00-02:00[America/Sao_Paulo]',
                '2015-10-18T01:00:00-02:00[America/Sao_Paulo]',
                '2015-10-19T01:00:00-02:00[America/Sao_Paulo]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2015-10-18T12:29:59-02:00[America/Sao_Paulo]',
                '2015-10-18T01:00:00-02:00[America/Sao_Paulo]',
                '2015-10-19T01:00:00-02:00[America/Sao_Paulo]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2011-12-29T12:00:00-10:00[Pacific/Apia]',
                '2011-12-29T00:00:00-10:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-12-31T00:00:00+14:00[Pacific/Apia]',
                '2012-01-01T00:00:00+14:00[Pacific/Apia]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2024-03-31T12:30:00+01:00[Europe/London]',
                '2024-03-31T00:00:00+00:00[Europe/London]',
                '2024-04-01T00:00:00+01:00[Europe/London]',
                'UDUDUDUDD'
            },
            new List<String>{
                '2024-10-06T12:29:00+11:00[Australia/Sydney]',
                '2024-10-06T00:00:00+10:00[Australia/Sydney]',
                '2024-10-07T00:00:00+11:00[Australia/Sydney]',
                'UDUDDDDDD'
            },
            new List<String>{
                '2024-07-04T12:00:00+05:30[Asia/Kolkata]',
                '2024-07-04T00:00:00+05:30[Asia/Kolkata]',
                '2024-07-05T00:00:00+05:30[Asia/Kolkata]',
                'UDUDUDUDD'
            }
        };
        for (List<String> row : cases) {
            JiffZonedDateTime zdt = zoned(row.get(0));
            for (Integer i = 0; i < MODES.size(); i++) {
                String expected = row.get(3).substring(i, i + 1).equals('U')
                    ? row.get(2)
                    : row.get(1);
                Assert.areEqual(
                    expected,
                    zdt.round(JiffRound.to(JiffUnit.DAY).mode(MODES.get(i))).toString(),
                    row.get(0) + ' with ' + MODES.get(i)
                );
            }
        }
    }

    // ---- failures -------------------------------------------------------

    @IsTest
    static void rejectsUnsupportedUnits() {
        // From `zoned_round_errors` in Jiff's tests.
        JiffZonedDateTime zdt = newYork(2025, 3, 9, 12, 15, 0, 0);
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.YEAR),
            'failed rounding datetime: rounding to \'years\' is not supported'
        );
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.MONTH),
            'failed rounding datetime: rounding to \'months\' is not supported'
        );
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.WEEK),
            'failed rounding datetime: rounding to \'weeks\' is not supported'
        );
    }

    @IsTest
    static void rejectsUnsupportedIncrements() {
        JiffZonedDateTime zdt = newYork(2025, 3, 9, 12, 15, 0, 0);
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.DAY).increment(2),
            'failed rounding datetime: increment for rounding to \'days\' must be equal to `1`'
        );
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.DAY).increment(0),
            'failed rounding datetime: parameter \'rounding increment\' is not in the ' +
            'required range of 1..=1000000000'
        );
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.HOUR).increment(24),
            'failed rounding datetime: increment for rounding to \'hours\' must divide into ' +
            '`24` evenly'
        );
        assertRoundFails(
            zdt,
            JiffRound.to(JiffUnit.MINUTE).increment(7),
            'failed rounding datetime: increment for rounding to \'minutes\' must divide ' +
            'into `60` evenly'
        );
    }

    @IsTest
    static void roundingCanLeaveTheSupportedRange() {
        JiffZonedDateTime max = JiffTimestamp.MAX.inTz('UTC');
        // Rounding to a day measures the day first, and the day after the last has no start.
        String noLength = 'failed to add 1 day to zoned datetime to find length of day: ';
        assertRoundFails(max, JiffRound.to(JiffUnit.DAY), noLength + OVERFLOW_UTC);
        assertRoundFails(
            max,
            JiffRound.to(JiffUnit.DAY).mode(JiffRoundMode.TRUNC),
            noLength + OVERFLOW_UTC
        );
        assertRoundFails(
            max,
            JiffRound.to(JiffUnit.SECOND),
            'error converting datetime to instant in time zone UTC: ' + OVERFLOW_UTC
        );
        Assert.areEqual('9999-12-30T22:00:00+00:00[UTC]', max.round(JiffUnit.HOUR).toString());

        JiffZonedDateTime min = JiffTimestamp.MIN.inTz('UTC');
        assertRoundFails(
            min,
            JiffRound.to(JiffUnit.DAY),
            'failed to find start of day for zoned datetime: ' + OVERFLOW_UTC
        );
        assertRoundFails(
            min,
            JiffRound.to(JiffUnit.HOUR).mode(JiffRoundMode.FLOOR),
            'error converting datetime to instant in time zone UTC: ' + OVERFLOW_UTC
        );
    }
}
