/**
 * The public entry points of the friendly format. The cases are the examples in the module
 * documentation of Jiff's `fmt/friendly/mod.rs`; the parser and the printer have their own,
 * much larger, test classes.
 */
@IsTest
private class JiffFriendlyTest {
    private static final String CONTEXT = 'failed to parse input in the "friendly" duration format: ';

    @IsTest
    static void parseSpanReadsTheDocumentedExamples() {
        JiffSpan everyUnit = new JiffSpan()
            .years(1)
            .months(1)
            .days(1)
            .hours(1)
            .minutes(1)
            .seconds(1)
            .milliseconds(100);
        Map<String, JiffSpan> expected = new Map<String, JiffSpan>{
            '40d' => new JiffSpan().days(40),
            '40 days' => new JiffSpan().days(40),
            '1y1d' => new JiffSpan().years(1).days(1),
            '1yr 1d' => new JiffSpan().years(1).days(1),
            '3d4h59m' => new JiffSpan().days(3).hours(4).minutes(59),
            '3 days, 4 hours, 59 minutes' => new JiffSpan().days(3).hours(4).minutes(59),
            '3d 4h 59m' => new JiffSpan().days(3).hours(4).minutes(59),
            '2h30m' => new JiffSpan().hours(2).minutes(30),
            '2h 30m' => new JiffSpan().hours(2).minutes(30),
            '1mo' => new JiffSpan().months(1),
            '1w' => new JiffSpan().weeks(1),
            '1 week' => new JiffSpan().weeks(1),
            '1w4d' => new JiffSpan().weeks(1).days(4),
            '1 wk 4 days' => new JiffSpan().weeks(1).days(4),
            '1m' => new JiffSpan().minutes(1),
            '0.0021s' => new JiffSpan().milliseconds(2).microseconds(100),
            '0s' => new JiffSpan(),
            '0d' => new JiffSpan(),
            '0 days' => new JiffSpan(),
            '3 mins 34s 123ms' => new JiffSpan().minutes(3).seconds(34).milliseconds(123),
            '3 mins 34.123 secs' => new JiffSpan().minutes(3).seconds(34).milliseconds(123),
            '3 mins 34,123s' => new JiffSpan().minutes(3).seconds(34).milliseconds(123),
            '1y1mo1d1h1m1.1s' => everyUnit,
            '1yr 1mo 1day 1hr 1min 1.1sec' => everyUnit,
            '1 year, 1 month, 1 day, 1 hour, 1 minute 1.1 seconds' => everyUnit,
            '1 year, 1 month, 1 day, 01:01:01.1' => everyUnit
        };
        for (String text : expected.keySet()) {
            Assert.areEqual(
                expected.get(text),
                JiffFriendly.parseSpan(text),
                'result of parsing ' + text
            );
        }
    }

    @IsTest
    static void equivalentSpellingsParseToTheSameSpan() {
        JiffSpan expected = new JiffSpan()
            .years(1)
            .months(2)
            .days(3)
            .hours(4)
            .minutes(59)
            .milliseconds(1100);
        List<String> texts = new List<String>{
            '1y 2mo 3d 4h 59m 1100ms',
            '1 year 2 months 3 days 4h59m1100ms',
            '1 year, 2 months, 3 days, 4h59m1100ms',
            '1 year, 2 months, 3 days, 4 hours 59 minutes 1100 milliseconds'
        };
        for (String text : texts) {
            Assert.areEqual(expected, JiffFriendly.parseSpan(text), text);
        }
        JiffSpan fractional = new JiffSpan().hours(1).minutes(1).seconds(1).milliseconds(500);
        List<String> fractionalTexts = new List<String>{
            '1h 1m 1.5s',
            '1h 1m 1,5s',
            '01:01:01.5',
            '01:01:01,5'
        };
        for (String text : fractionalTexts) {
            Assert.areEqual(fractional, JiffFriendly.parseSpan(text), text);
        }
    }

    @IsTest
    static void parseDurationReadsHoursAndSmallerUnits() {
        JiffSignedDuration expected = JiffSignedDuration.fromSecs(37800L);
        List<String> texts = new List<String>{
            '10h30m',
            '10hrs 30mins',
            '10 hours 30 minutes',
            '10 hours, 30 minutes',
            '10:30:00',
            '10.5 hours'
        };
        for (String text : texts) {
            Assert.areEqual(expected, JiffFriendly.parseDuration(text), text);
        }
        Assert.areEqual(JiffSignedDuration.fromHours(1L), JiffFriendly.parseDuration('1 hour'));
        Assert.areEqual(
            JiffSignedDuration.newInstance(9000L, 123456789),
            JiffFriendly.parseDuration('2h 30m 0,123456789s')
        );
    }

    @IsTest
    static void parseDurationRefusesCalendarUnitsThatParseSpanAccepts() {
        try {
            JiffFriendly.parseDuration('1 day');
            Assert.fail('expected days to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                CONTEXT +
                    'parsing calendar units (days in this case) in this context is not ' +
                    'supported (perhaps try parsing into a `JiffSpan` instead)',
                e.getMessage()
            );
        }
        Assert.areEqual(new JiffSpan().days(1), JiffFriendly.parseSpan('1 day'));
    }

    @IsTest
    static void parseSpanAcceptsOnlyTheFriendlyFormat() {
        try {
            JiffFriendly.parseSpan('P1D');
            Assert.fail('expected an ISO 8601 duration to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                CONTEXT +
                    'expected duration to start with a unit value (a decimal integer) ' +
                    'after an optional sign, but no integer was found',
                e.getMessage()
            );
        }
        // `M` could be months or minutes, so it is not a label at all.
        try {
            JiffFriendly.parseSpan('1M');
            Assert.fail('expected the ambiguous label M to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                CONTEXT +
                    'expected to find unit designator suffix ' +
                    '(e.g., `years` or `secs`) after parsing integer',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void printUsesTheDefaultPrinter() {
        JiffSpan span = new JiffSpan().months(2).days(35).hours(2).minutes(30);
        Assert.areEqual('P2M35DT2H30M', span.toString());
        Assert.areEqual('2mo 35d 2h 30m', JiffFriendly.printSpan(span));
        Assert.areEqual('2mo 35d 2h 30m ago', JiffFriendly.printSpan(span.negate()));
        Assert.areEqual(
            '1y 2mo 15h 30s 1ns',
            JiffFriendly.printSpan(
                new JiffSpan().years(1).months(2).hours(15).seconds(30).nanoseconds(1)
            )
        );
        Assert.areEqual('3y 5mo', JiffFriendly.printSpan(new JiffSpan().years(3).months(5)));

        JiffSignedDuration duration = JiffSignedDuration.newInstance(9000L, 123456789);
        Assert.areEqual('PT2H30M0.123456789S', duration.toString());
        Assert.areEqual('2h 30m 123ms 456µs 789ns', JiffFriendly.printDuration(duration));
        Assert.areEqual(
            '24h 2m 5s 123ms 789ns',
            JiffFriendly.printDuration(JiffSignedDuration.newInstance(86525L, 123000789))
        );
        Assert.areEqual(
            '24h 2m 5s 123ms 789ns ago',
            JiffFriendly.printDuration(JiffSignedDuration.newInstance(-86525L, -123000789))
        );
    }

    @IsTest
    static void printAcceptsAConfiguredPrinter() {
        JiffSpan span = new JiffSpan()
            .years(2)
            .months(1)
            .days(15)
            .hours(5)
            .minutes(59)
            .seconds(1)
            .milliseconds(123)
            .microseconds(456)
            .nanoseconds(789);
        JiffFriendlyPrinter humanTime = new JiffFriendlyPrinter()
            .designator(JiffFriendlyDesignator.HUMAN_TIME);
        Assert.areEqual(
            '2y 1month 15d 5h 59m 1s 123ms 456us 789ns',
            JiffFriendly.printSpan(span, humanTime)
        );
        JiffFriendlyPrinter fractionalSeconds = new JiffFriendlyPrinter()
            .fractional(JiffFriendlyFractionalUnit.SECOND);
        Assert.areEqual(
            '24h 2m 5.123000789s ago',
            JiffFriendly.printDuration(
                JiffSignedDuration.newInstance(-86525L, -123000789),
                fractionalSeconds
            )
        );
    }

    @IsTest
    static void whatIsPrintedParsesBackToTheSameSpan() {
        List<JiffSpan> spans = new List<JiffSpan>{
            new JiffSpan(),
            new JiffSpan().seconds(1).milliseconds(100),
            new JiffSpan().milliseconds(1100),
            new JiffSpan().years(1).months(2).weeks(3).days(4).negate(),
            new JiffSpan()
                .years(19998)
                .months(239976)
                .weeks(1043497)
                .days(7304484)
                .hours(175307616)
                .minutes(10518456960L)
                .seconds(631107417600L)
                .milliseconds(631107417600000L)
                .microseconds(631107417600000000L)
                .nanoseconds(9223372036854775807L)
                .negate()
        };
        for (JiffSpan span : spans) {
            String printed = JiffFriendly.printSpan(span);
            Assert.areEqual(span, JiffFriendly.parseSpan(printed), printed);
        }
    }

    @IsTest
    static void isoOrFriendlyPicksTheFormatFromTheFirstCharacter() {
        JiffSpan span = new JiffSpan().months(2).days(35).hours(2).minutes(30);
        Assert.areEqual(span, JiffFriendly.parseIsoOrFriendlySpan('2 months, 35 days, 02:30:00'));
        Assert.areEqual(span, JiffFriendly.parseIsoOrFriendlySpan('P2M35DT2H30M'));
        Assert.areEqual(span.negate(), JiffFriendly.parseIsoOrFriendlySpan('-p2m35dt2h30m'));
        JiffSignedDuration duration = JiffSignedDuration.newInstance(9000L, 123456789);
        Assert.areEqual(duration, JiffFriendly.parseIsoOrFriendlyDuration('2h 30m 0,123456789s'));
        Assert.areEqual(duration, JiffFriendly.parseIsoOrFriendlyDuration('PT2h30m0.123456789s'));
        Assert.areEqual(
            duration.negate(),
            JiffFriendly.parseIsoOrFriendlyDuration('-PT2h30m0.123456789s')
        );
        Assert.areEqual(
            duration.negate(),
            JiffFriendly.parseIsoOrFriendlyDuration('2h 30m 0,123456789s ago')
        );
    }

    @IsTest
    static void isoOrFriendlyRejectsTextThatCanBeNeither() {
        String neither = 'not a valid duration in either the ISO 8601 format or Jiff\'s "friendly" format';
        Map<String, String> expected = new Map<String, String>{
            '' => 'an empty string is ' + neither,
            '+' => 'found nothing after sign `+`, which is ' + neither,
            '-' => 'found nothing after sign `-`, which is ' + neither
        };
        for (String text : expected.keySet()) {
            try {
                JiffFriendly.parseIsoOrFriendlySpan(text);
                Assert.fail('expected a span parse error for: ' + text);
            } catch (JiffException e) {
                Assert.areEqual(expected.get(text), e.getMessage(), text);
            }
            try {
                JiffFriendly.parseIsoOrFriendlyDuration(text);
                Assert.fail('expected a duration parse error for: ' + text);
            } catch (JiffException e) {
                Assert.areEqual(expected.get(text), e.getMessage(), text);
            }
        }
        try {
            JiffFriendly.parseIsoOrFriendlySpan(null);
            Assert.fail('expected null to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('cannot parse a duration from a null string', e.getMessage());
        }
    }
}
