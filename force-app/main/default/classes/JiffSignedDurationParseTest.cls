/**
 * `JiffSignedDuration.parse` and `JiffSignedDuration.toFriendly`: Jiff's `FromStr` and
 * alternate `Display` for a signed duration. The cases are the examples in the doc comments of
 * Jiff's `signed_duration.rs` and `fmt/friendly/mod.rs`, and the `from_str` and
 * `humantime_compatibility_*` tests in its `#[cfg(test)]` module.
 */
@IsTest
private class JiffSignedDurationParseTest {
    private static void assertParses(JiffSignedDuration expected, List<String> texts) {
        for (String text : texts) {
            Assert.areEqual(expected, JiffSignedDuration.parse(text), 'result of parsing ' + text);
        }
    }

    @IsTest
    static void parsesIso8601Durations() {
        assertParses(
            JiffSignedDuration.fromSecs(9000L),
            new List<String>{ 'PT2H30M', 'PT2.5h', 'PT2h30m' }
        );
        assertParses(JiffSignedDuration.fromMins(1L), new List<String>{ 'PT1m' });
        assertParses(JiffSignedDuration.fromSecs(90L), new List<String>{ 'PT1.5m' });
        assertParses(JiffSignedDuration.newInstance(0L, 2100000), new List<String>{ 'PT0.0021s' });
        assertParses(JiffSignedDuration.ZERO, new List<String>{ 'PT0s' });
        assertParses(JiffSignedDuration.fromNanos(1L), new List<String>{ 'PT0.000000001s' });
        assertParses(
            JiffSignedDuration.newInstance(9000L, 123456789),
            new List<String>{ 'PT2h30m0.123456789s' }
        );
    }

    @IsTest
    static void parsesFriendlyDurations() {
        assertParses(
            JiffSignedDuration.fromSecs(9000L),
            new List<String>{
                '2h30m',
                '2h 30m',
                '2 hrs 30 mins',
                '2 hours 30 minutes',
                '2 hours, 30 minutes',
                '2.5h'
            }
        );
        assertParses(JiffSignedDuration.fromMins(1L), new List<String>{ '1m' });
        assertParses(JiffSignedDuration.fromSecs(90L), new List<String>{ '1.5m' });
        assertParses(JiffSignedDuration.newInstance(0L, 2100000), new List<String>{ '0.0021s' });
        assertParses(JiffSignedDuration.ZERO, new List<String>{ '0s' });
        assertParses(JiffSignedDuration.fromNanos(1L), new List<String>{ '0.000000001s' });
        assertParses(
            JiffSignedDuration.newInstance(9000L, 123456789),
            new List<String>{ '2h 30m 0,123456789s' }
        );
        // Ten hours and thirty minutes, six ways.
        assertParses(
            JiffSignedDuration.fromSecs(37800L),
            new List<String>{
                '10h30m',
                '10hrs 30mins',
                '10 hours 30 minutes',
                '10 hours, 30 minutes',
                '10:30:00',
                '10.5 hours'
            }
        );
        assertParses(JiffSignedDuration.fromHours(1L), new List<String>{ '1 hour' });
    }

    @IsTest
    static void theFormatIsChosenByWhatFollowsTheSign() {
        Assert.areEqual('PT1H', JiffSignedDuration.parse('1 hour').toString());
        Assert.areEqual('PT1H', JiffSignedDuration.parse('+1 hour').toString());
        Assert.areEqual('-PT1H', JiffSignedDuration.parse('-1 hour').toString());
        Assert.areEqual('PT1H', JiffSignedDuration.parse('PT1h').toString());
        Assert.areEqual('PT1H', JiffSignedDuration.parse('+PT1h').toString());
        Assert.areEqual('-PT1H', JiffSignedDuration.parse('-PT1h').toString());
        Assert.areEqual('-PT1H', JiffSignedDuration.parse('-pT1h').toString());
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
            // Days have no fixed length, so neither format accepts them here.
            'P1d' => 'parsing ISO 8601 duration in this context requires that the duration ' +
            'contain a time component and no components of days or greater',
            '1 day' => 'failed to parse input in the "friendly" duration format: ' +
            'parsing calendar units (days in this case) in this context is not supported ' +
            '(perhaps try parsing into a `JiffSpan` instead)',
            'x' => 'failed to parse input in the "friendly" duration format: ' +
            'expected duration to start with a unit value (a decimal integer) ' +
            'after an optional sign, but no integer was found'
        };
        for (String text : expected.keySet()) {
            try {
                JiffSignedDuration.parse(text);
                Assert.fail('expected a parse error for: ' + text);
            } catch (JiffException e) {
                Assert.areEqual(expected.get(text), e.getMessage(), text);
            }
        }
        try {
            JiffSignedDuration.parse(null);
            Assert.fail('expected null to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('cannot parse a duration from a null string', e.getMessage());
        }
    }

    @IsTest
    static void toFriendlyUsesTheDefaultFriendlyPrinter() {
        JiffSignedDuration duration = JiffSignedDuration.parse('PT2h30m');
        Assert.areEqual('PT2H30M', duration.toString());
        Assert.areEqual('2h 30m', duration.toFriendly());
        JiffSignedDuration precise = JiffSignedDuration.newInstance(9000L, 123456789);
        Assert.areEqual('PT2H30M0.123456789S', precise.toString());
        Assert.areEqual('2h 30m 123ms 456µs 789ns', precise.toFriendly());
        Assert.areEqual('15h 30s 1ns', JiffSignedDuration.newInstance(54030L, 1).toFriendly());
        Assert.areEqual('1s ago', JiffSignedDuration.fromSecs(-1L).toFriendly());
        Assert.areEqual('0s', JiffSignedDuration.ZERO.toFriendly());
        Assert.areEqual(
            '2562047788015215h 30m 8s 999ms 999µs 999ns ago',
            JiffSignedDuration.MIN.toFriendly()
        );
    }

    @IsTest
    static void whatToFriendlyWritesParsesBackToTheSameDuration() {
        List<JiffSignedDuration> durations = new List<JiffSignedDuration>{
            JiffSignedDuration.ZERO,
            JiffSignedDuration.fromSecs(-1L),
            JiffSignedDuration.newInstance(9000L, 123456789),
            JiffSignedDuration.newInstance(-86525L, -123000789),
            JiffSignedDuration.MIN,
            JiffSignedDuration.MAX
        };
        for (JiffSignedDuration duration : durations) {
            Assert.areEqual(
                duration,
                JiffSignedDuration.parse(duration.toFriendly()),
                duration.toFriendly()
            );
            Assert.areEqual(
                duration,
                JiffSignedDuration.parse(duration.toString()),
                duration.toString()
            );
        }
    }

    @IsTest
    static void parsesWhatTheHumantimeCrateWrites() {
        Assert.areEqual(
            JiffSignedDuration.newInstance(26784L, 123456789),
            JiffSignedDuration.parse('7h 26m 24s 123ms 456us 789ns')
        );
    }
}
