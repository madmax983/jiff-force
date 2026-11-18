/**
 * `JiffSpan.parse` and `JiffSpan.toFriendly`: Jiff's `FromStr` and alternate `Display` for a
 * span. The cases are the examples in the doc comments of Jiff's `span.rs` and the `from_str`
 * and `humantime_compatibility_*` tests in its `#[cfg(test)]` module.
 */
@IsTest
private class JiffSpanParseTest {
    private static JiffSpan everyUnit() {
        return new JiffSpan()
            .years(1)
            .months(1)
            .days(1)
            .hours(1)
            .minutes(1)
            .seconds(1)
            .milliseconds(100);
    }

    private static void assertParses(JiffSpan expected, List<String> texts) {
        for (String text : texts) {
            Assert.areEqual(expected, JiffSpan.parse(text), 'result of parsing ' + text);
        }
    }

    @IsTest
    static void parsesIso8601Durations() {
        assertParses(new JiffSpan().days(40), new List<String>{ 'P40D' });
        assertParses(new JiffSpan().years(1).days(1), new List<String>{ 'P1y1d' });
        assertParses(new JiffSpan().days(3).hours(4).minutes(59), new List<String>{ 'P3dT4h59m' });
        assertParses(new JiffSpan().hours(2).minutes(30), new List<String>{ 'PT2H30M' });
        assertParses(new JiffSpan().months(1), new List<String>{ 'P1m' });
        assertParses(new JiffSpan().weeks(1), new List<String>{ 'P1w' });
        assertParses(new JiffSpan().weeks(1).days(4), new List<String>{ 'P1w4d' });
        assertParses(new JiffSpan().minutes(1), new List<String>{ 'PT1m' });
        assertParses(
            new JiffSpan().milliseconds(2).microseconds(100),
            new List<String>{ 'PT0.0021s' }
        );
        assertParses(new JiffSpan(), new List<String>{ 'PT0s', 'P0d' });
        assertParses(everyUnit(), new List<String>{ 'P1y1m1dT1h1m1.1s' });
        assertParses(
            new JiffSpan().months(2).days(35).hours(2).minutes(30),
            new List<String>{ 'P2M35DT2H30M' }
        );
    }

    @IsTest
    static void parsesFriendlyDurations() {
        assertParses(new JiffSpan().days(40), new List<String>{ '40d', '40 days' });
        assertParses(new JiffSpan().years(1).days(1), new List<String>{ '1y1d', '1yr 1d' });
        assertParses(
            new JiffSpan().days(3).hours(4).minutes(59),
            new List<String>{ '3d4h59m', '3 days, 4 hours, 59 minutes', '3d 4h 59m' }
        );
        assertParses(new JiffSpan().hours(2).minutes(30), new List<String>{ '2h30m', '2h 30m' });
        assertParses(new JiffSpan().months(1), new List<String>{ '1mo' });
        assertParses(new JiffSpan().weeks(1), new List<String>{ '1w', '1 week' });
        assertParses(new JiffSpan().weeks(1).days(4), new List<String>{ '1w4d', '1 wk 4 days' });
        assertParses(new JiffSpan().minutes(1), new List<String>{ '1m' });
        assertParses(
            new JiffSpan().milliseconds(2).microseconds(100),
            new List<String>{ '0.0021s' }
        );
        assertParses(new JiffSpan(), new List<String>{ '0s', '0d', '0 days' });
        assertParses(
            new JiffSpan().minutes(3).seconds(34).milliseconds(123),
            new List<String>{ '3 mins 34s 123ms', '3 mins 34.123 secs', '3 mins 34,123s' }
        );
        assertParses(
            everyUnit(),
            new List<String>{
                '1y1mo1d1h1m1.1s',
                '1yr 1mo 1day 1hr 1min 1.1sec',
                '1 year, 1 month, 1 day, 1 hour, 1 minute 1.1 seconds',
                '1 year, 1 month, 1 day, 01:01:01.1'
            }
        );
        assertParses(
            new JiffSpan().months(2).days(35).hours(2).minutes(30),
            new List<String>{ '2 months, 35 days, 02:30:00' }
        );
        assertParses(
            new JiffSpan().months(2).days(10).hours(2).minutes(30),
            new List<String>{
                'P2m10dT2h30m',
                '2mo 10d 2h 30m',
                '2 months, 10 days, 2 hours, 30 minutes'
            }
        );
        assertParses(
            new JiffSpan().years(1).months(2).hours(36).milliseconds(1100),
            new List<String>{ '1 year 2 months 36 hours 1100ms' }
        );
    }

    @IsTest
    static void theFormatIsChosenByWhatFollowsTheSign() {
        Assert.areEqual('P1D', JiffSpan.parse('1 day').toString());
        Assert.areEqual('P1D', JiffSpan.parse('+1 day').toString());
        Assert.areEqual('-P1D', JiffSpan.parse('-1 day').toString());
        Assert.areEqual('P1D', JiffSpan.parse('P1d').toString());
        Assert.areEqual('P1D', JiffSpan.parse('+P1d').toString());
        Assert.areEqual('-P1D', JiffSpan.parse('-P1d').toString());
        Assert.areEqual('P1D', JiffSpan.parse('p1d').toString());
        Assert.areEqual('-P1D', JiffSpan.parse('-p1d').toString());
    }

    @IsTest
    static void errorsComeFromTheFormatThatWasChosen() {
        Map<String, String> expected = new Map<String, String>{
            '' => 'an empty string is not a valid duration in either ' +
            'the ISO 8601 format or Jiff\'s "friendly" format',
            '+' => 'found nothing after sign `+`, which is not a valid duration in either ' +
            'the ISO 8601 format or Jiff\'s "friendly" format',
            '-' => 'found nothing after sign `-`, which is not a valid duration in either ' +
            'the ISO 8601 format or Jiff\'s "friendly" format',
            '-P' => 'no parsed duration components',
            'x' => 'failed to parse input in the "friendly" duration format: ' +
            'expected duration to start with a unit value (a decimal integer) ' +
            'after an optional sign, but no integer was found',
            '+x' => 'failed to parse input in the "friendly" duration format: ' +
            'expected duration to start with a unit value (a decimal integer) ' +
            'after an optional sign, but no integer was found',
            // Only a `P` directly after the sign selects ISO 8601.
            ' P1D' => 'failed to parse input in the "friendly" duration format: ' +
            'expected duration to start with a unit value (a decimal integer) ' +
            'after an optional sign, but no integer was found',
            // `M` is not a friendly label: it could mean months or minutes.
            '1M' => 'failed to parse input in the "friendly" duration format: ' +
            'expected to find unit designator suffix ' +
            '(e.g., `years` or `secs`) after parsing integer'
        };
        for (String text : expected.keySet()) {
            try {
                JiffSpan.parse(text);
                Assert.fail('expected a parse error for: ' + text);
            } catch (JiffException e) {
                Assert.areEqual(expected.get(text), e.getMessage(), text);
            }
        }
        try {
            JiffSpan.parse(null);
            Assert.fail('expected null to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('cannot parse a duration from a null string', e.getMessage());
        }
    }

    @IsTest
    static void toFriendlyUsesTheDefaultFriendlyPrinter() {
        Assert.areEqual('3mo 29d 15h', new JiffSpan().months(3).days(29).hours(15).toFriendly());
        JiffSpan span = JiffSpan.parse('P2m10dT2h30m');
        Assert.areEqual('P2M10DT2H30M', span.toString());
        Assert.areEqual('2mo 10d 2h 30m', span.toFriendly());
        Assert.areEqual(
            '2mo 35d 2h 30m',
            new JiffSpan().months(2).days(35).hours(2).minutes(30).toFriendly()
        );
        JiffSpan everything = new JiffSpan()
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
        Assert.areEqual('P1Y2M3W4DT5H6M7.00800901S', everything.toString());
        Assert.areEqual('1y 2mo 3w 4d 5h 6m 7s 8ms 9µs 10ns', everything.toFriendly());
        Assert.areEqual('1d ago', JiffSpan.parse('-p1d').toFriendly());
        Assert.areEqual('0s', new JiffSpan().toFriendly());
    }

    @IsTest
    static void theFriendlyFormatRoundTripsWhereIso8601CannotTellSpansApart() {
        JiffSpan split = new JiffSpan().seconds(1).milliseconds(100);
        JiffSpan whole = new JiffSpan().milliseconds(1100);
        Assert.areEqual(split.toString(), whole.toString());
        Assert.areEqual('1s 100ms', split.toFriendly());
        Assert.areEqual('1100ms', whole.toFriendly());
        Assert.areEqual(split, JiffSpan.parse(split.toFriendly()));
        Assert.areEqual(whole, JiffSpan.parse(whole.toFriendly()));
        Assert.isFalse(split.equals(whole));
    }

    @IsTest
    static void parsesWhatTheHumantimeCrateWrites() {
        Assert.areEqual(
            new JiffSpan()
                .years(2)
                .months(1)
                .days(15)
                .hours(5)
                .minutes(59)
                .seconds(1)
                .milliseconds(123)
                .microseconds(456)
                .nanoseconds(789),
            JiffSpan.parse('2years 1month 15days 5h 59m 1s 123ms 456us 789ns')
        );
        Assert.areEqual(
            new JiffSpan()
                .years(1)
                .months(1)
                .days(15)
                .hours(7)
                .minutes(26)
                .seconds(24)
                .milliseconds(123)
                .microseconds(456)
                .nanoseconds(789),
            JiffSpan.parse('1year 1month 15days 7h 26m 24s 123ms 456us 789ns')
        );
    }
}
