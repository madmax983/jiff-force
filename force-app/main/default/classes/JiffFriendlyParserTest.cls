/**
 * The cases here are the snapshot assertions of the `#[cfg(test)]` module in Jiff's
 * `fmt/friendly/parser.rs`, the grammar in `fmt/friendly/mod.rs`, and the error text in
 * `error/fmt/`. A row is `input => expected`.
 */
@IsTest
private class JiffFriendlyParserTest {
    private static final String CONTEXT = 'failed to parse input in the "friendly" duration format: ';

    /** Each row is `input => the ISO 8601 text of the span it parses to`. */
    private static void assertSpans(List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            String input = row.substring(0, at);
            Assert.areEqual(
                row.substring(at + 4),
                JiffFriendlyParser.parseSpan(input).toString(),
                row
            );
        }
    }

    /** Each row is `input => the ISO 8601 text of the signed duration it parses to`. */
    private static void assertDurations(List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            String input = row.substring(0, at);
            Assert.areEqual(
                row.substring(at + 4),
                JiffFriendlyParser.parseDuration(input).toString(),
                row
            );
        }
    }

    /** Each row is `input => the error message`, without the context every error starts with. */
    private static void assertSpanErrors(List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            try {
                JiffFriendlyParser.parseSpan(row.substring(0, at));
                Assert.fail('expected a span parse error: ' + row);
            } catch (JiffException e) {
                Assert.areEqual(CONTEXT + row.substring(at + 4), e.getMessage(), row);
            }
        }
    }

    private static void assertDurationErrors(List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            try {
                JiffFriendlyParser.parseDuration(row.substring(0, at));
                Assert.fail('expected a duration parse error: ' + row);
            } catch (JiffException e) {
                Assert.areEqual(CONTEXT + row.substring(at + 4), e.getMessage(), row);
            }
        }
    }

    // ---- spans ------------------------------------------------------------

    @IsTest
    static void spansParseFromUnitsAndClockTimes() {
        assertSpans(
            new List<String>{
                '5 years => P5Y',
                '5 years 4 months => P5Y4M',
                '5 years 4 months 3 hours => P5Y4MT3H',
                '5 years, 4 months, 3 hours => P5Y4MT3H',
                '01:02:03 => PT1H2M3S',
                '5 days 01:02:03 => P5DT1H2M3S',
                '5 days, 01:02:03 => P5DT1H2M3S',
                '3yrs 5 days 01:02:03 => P3Y5DT1H2M3S',
                '3yrs 5 days, 01:02:03 => P3Y5DT1H2M3S',
                '3yrs 5 days, 01:02:03.123456789 => P3Y5DT1H2M3.123456789S',
                '999:999:999 => PT999H999M999S'
            }
        );
    }

    @IsTest
    static void aFractionIsCarriedIntoSmallerUnitsOfASpan() {
        assertSpans(
            new List<String>{
                '1.5hrs => PT1H30M',
                '1.5mins => PT1M30S',
                '1.5secs => PT1.5S',
                '1.5msecs => PT0.0015S',
                '1.5µsecs => PT0.0000015S',
                '-0.5secs => -PT0.5S',
                '0.5secs ago => -PT0.5S',
                '1d 1.5hrs => P1DT1H30M',
                '1h 1.5mins => PT1H1M30S',
                '1m 1.5secs => PT1M1.5S',
                '1s 1.5msecs => PT1.0015S',
                '1ms 1.5µsecs => PT0.0010015S',
                '1s2000ms => PT3S'
            }
        );
    }

    @IsTest
    static void spansParseAtTheLimitOfEveryUnit() {
        assertSpans(
            new List<String>{
                '19998 years => P19998Y',
                '19998 years ago => -P19998Y',
                '239976 months => P239976M',
                '239976 months ago => -P239976M',
                '1043497 weeks => P1043497W',
                '1043497 weeks ago => -P1043497W',
                '7304484 days => P7304484D',
                '7304484 days ago => -P7304484D',
                '175307616 hours => PT175307616H',
                '175307616 hours ago => -PT175307616H',
                '10518456960 minutes => PT10518456960M',
                '10518456960 minutes ago => -PT10518456960M',
                '631107417600 seconds => PT631107417600S',
                '631107417600 seconds ago => -PT631107417600S',
                '631107417600000 milliseconds => PT631107417600S',
                '631107417600000 milliseconds ago => -PT631107417600S',
                '631107417600000000 microseconds => PT631107417600S',
                '631107417600000000 microseconds ago => -PT631107417600S',
                '9223372036854775807 nanoseconds => PT9223372036.854775807S',
                '9223372036854775807 nanoseconds ago => -PT9223372036.854775807S'
            }
        );
    }

    @IsTest
    static void aTimeUnitBeyondItsLimitSpillsIntoSmallerUnits() {
        assertSpans(
            new List<String>{
                '175307617 hours => PT175307616H60M',
                '175307617 hours ago => -PT175307616H60M',
                '10518456961 minutes => PT10518456960M60S',
                '10518456961 minutes ago => -PT10518456960M60S',
                '631107417601 seconds => PT631107417601S',
                '631107417601 seconds ago => -PT631107417601S',
                '631107417600001 milliseconds => PT631107417600.001S',
                '631107417600001 milliseconds ago => -PT631107417600.001S',
                '631107417600000001 microseconds => PT631107417600.000001S',
                '631107417600000001 microseconds ago => -PT631107417600.000001S'
            }
        );
    }

    @IsTest
    static void spilledExcessIsAddedToSmallerUnitsThatWereAlsoParsed() {
        List<String> rows = new List<String>{
            '175307617h 1m => PT175307616H61M',
            '175307617h 1m ago => -PT175307616H61M',
            '200000000h 30m => PT175307616H1481543070M',
            '200000000:30:00 => PT175307616H1481543070M',
            '200000000h 30.5m => PT175307616H1481543070M30S',
            '10518456961m 1s => PT10518456960M61S',
            '631107417601s 1ms => PT631107417601.001S',
            '631107417600001ms 1us => PT631107417600.001001S',
            '631107417600000001us 1ns => PT631107417600.000001001S',
            // The minutes are already at their limit, so the extra hour skips over them
            // and is added to the seconds.
            '175307617h 10518456960m 1s => PT175307616H10518456960M3601S'
        };
        assertSpans(rows);
        // The span parsed is the same length as the signed duration parsed from the same text.
        for (String row : rows) {
            String input = row.substring(0, row.indexOf(' => '));
            Assert.areEqual(
                JiffFriendlyParser.parseDuration(input),
                JiffFriendlyParser.parseSpan(input).toInvariantDuration(),
                input
            );
        }
        assertSpanErrors(
            new List<String>{
                // Combining the excess with the seconds overflows a 64 bit integer.
                '10518456961m 9223372036854775807s => failed to set value for second unit on span: ' +
                'failed to set nanosecond value from fractional component'
            }
        );
    }

    @IsTest
    static void everyUnitLabelIsAccepted() {
        assertSpans(
            new List<String>{
                '1years => P1Y',
                '1year => P1Y',
                '1yrs => P1Y',
                '1yr => P1Y',
                '1y => P1Y',
                '1months => P1M',
                '1month => P1M',
                '1mos => P1M',
                '1mo => P1M',
                '1weeks => P1W',
                '1week => P1W',
                '1wks => P1W',
                '1wk => P1W',
                '1w => P1W',
                '1days => P1D',
                '1day => P1D',
                '1d => P1D',
                '1hours => PT1H',
                '1hour => PT1H',
                '1hrs => PT1H',
                '1hr => PT1H',
                '1h => PT1H',
                '1minutes => PT1M',
                '1minute => PT1M',
                '1mins => PT1M',
                '1min => PT1M',
                '1m => PT1M',
                '1seconds => PT1S',
                '1second => PT1S',
                '1secs => PT1S',
                '1sec => PT1S',
                '1s => PT1S',
                '1milliseconds => PT0.001S',
                '1millisecond => PT0.001S',
                '1millis => PT0.001S',
                '1milli => PT0.001S',
                '1msecs => PT0.001S',
                '1msec => PT0.001S',
                '1ms => PT0.001S',
                '1microseconds => PT0.000001S',
                '1microsecond => PT0.000001S',
                '1micros => PT0.000001S',
                '1micro => PT0.000001S',
                '1usecs => PT0.000001S',
                '1usec => PT0.000001S',
                '1us => PT0.000001S',
                '1µsecs => PT0.000001S',
                '1µsec => PT0.000001S',
                '1µs => PT0.000001S',
                '1nanoseconds => PT0.000000001S',
                '1nanosecond => PT0.000000001S',
                '1nanos => PT0.000000001S',
                '1nano => PT0.000000001S',
                '1nsecs => PT0.000000001S',
                '1nsec => PT0.000000001S',
                '1ns => PT0.000000001S'
            }
        );
    }

    @IsTest
    static void microSignLabelsAreTheSingleCharacterU00B5() {
        String micro = String.fromCharArray(new List<Integer>{ 181 });
        Assert.areEqual(1L, JiffFriendlyParser.parseSpan('1' + micro + 's').getMicroseconds());
        Assert.areEqual(2L, JiffFriendlyParser.parseSpan('2 ' + micro + 'secs').getMicroseconds());
        // GREEK SMALL LETTER MU (U+03BC) looks the same but is not a label.
        String greekMu = String.fromCharArray(new List<Integer>{ 956 });
        try {
            JiffFriendlyParser.parseSpan('1' + greekMu + 's');
            Assert.fail('expected the Greek letter mu to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('unit designator suffix'), e.getMessage());
        }
    }

    @IsTest
    static void whitespaceMayBeAnyAsciiWhitespaceAndMayRepeat() {
        assertSpans(
            new List<String>{
                '1 y  2   mo => P1Y2M',
                '1\ty\t2\tmo => P1Y2M',
                '1\ny\n2\nmo => P1Y2M',
                '1\ry\r2\rmo => P1Y2M',
                '1\fy\f2\fmo => P1Y2M',
                '1y,\t2mo => P1Y2M',
                '1y \t\n ago => -P1Y',
                // Trailing whitespace is where `ago` would be, so it is accepted without it.
                '1y  => P1Y'
            }
        );
    }

    @IsTest
    static void aSignIsAPrefixOrATrailingAgo() {
        assertSpans(
            new List<String>{
                '+1 year 1 month => P1Y1M',
                '-1 year 1 month => -P1Y1M',
                '1 year 1 month ago => -P1Y1M',
                '-01:02:03 => -PT1H2M3S',
                '1 day, 01:02:03 ago => -P1DT1H2M3S',
                // A duration of zero has no sign however it is written.
                '-0s => PT0S',
                '0s ago => PT0S'
            }
        );
    }

    @IsTest
    static void aCommaActsAsADecimalSeparatorDirectlyAfterAValue() {
        assertSpans(
            new List<String>{
                '3 mins 34,123s => PT3M34.123S',
                '1,5 hours => PT1H30M',
                '01:01:01,5 => PT1H1M1.5S',
                '0.0021s => PT0.0021S'
            }
        );
        JiffSpan span = JiffFriendlyParser.parseSpan('0.0021s');
        Assert.areEqual(2L, span.getMilliseconds());
        Assert.areEqual(100L, span.getMicroseconds());
    }

    @IsTest
    static void spansRejectMalformedText() {
        assertSpanErrors(
            new List<String>{
                ' => an empty string is not valid',
                '  => expected duration to start with a unit value (a decimal integer) ' +
                'after an optional sign, but no integer was found',
                'a => expected duration to start with a unit value (a decimal integer) ' +
                'after an optional sign, but no integer was found',
                '2 months 1 year => found value with unit year after unit month, ' +
                'but units must be written from largest to smallest ' +
                '(and they can\'t be repeated)',
                '1 year 1 mont => parsed value \'P1Y1M\', but unparsed input "nt" remains ' +
                '(expected no unparsed input)',
                '2 months, => expected whitespace after comma, but found end of input',
                '2 months,  => found comma at the end of duration, ' +
                'but a comma indicates at least one more unit follows',
                '2 months , => parsed value \'P2M\', but unparsed input "," remains ' +
                '(expected no unparsed input)',
                '1M => expected to find unit designator suffix ' +
                '(e.g., `years` or `secs`) after parsing integer',
                '5 => expected to find unit designator suffix ' +
                '(e.g., `years` or `secs`) after parsing integer',
                '2 months,1 day => expected whitespace after comma, but found `1`',
                '1 day 1 day => found value with unit day after unit day, ' +
                'but units must be written from largest to smallest ' +
                '(and they can\'t be repeated)'
            }
        );
    }

    @IsTest
    static void spansRejectTwoSignsAndAgoWithoutASpace() {
        assertSpanErrors(
            new List<String>{
                '1yago => parsed value \'P1Y\', but unparsed input "ago" remains ' +
                '(expected no unparsed input)',
                '1 year 1 monthago => parsed value \'P1Y1M\', but unparsed input "ago" remains ' +
                '(expected no unparsed input)',
                '+1 year 1 month ago => expected to find either a prefix sign (+/-) ' +
                'or a suffix sign (`ago`), but found both',
                '-1 year 1 month ago => expected to find either a prefix sign (+/-) ' +
                'or a suffix sign (`ago`), but found both'
            }
        );
    }

    @IsTest
    static void spansRejectTimeTooLongToSpillIntoNanoseconds() {
        assertSpanErrors(
            new List<String>{
                // The maximum number of microseconds is subtracted off, and what is left
                // over does not fit in the nanoseconds.
                '640330789636854776 micros => failed to set value for microsecond unit on span: ' +
                'failed to set nanosecond value from fractional component',
                // The same, but with the overflow coming from an explicit fraction.
                '640330789636854775.808 micros => ' +
                'failed to set nanosecond value from fractional component',
                // Negated, the nanoseconds fit in 64 bits, but a span stops one short of that.
                '640330789636854775.808 micros ago => ' +
                'failed to set nanosecond value from fractional component: ' +
                'parameter \'nanoseconds\' is not in the required range of ' +
                '-9223372036854775807..=9223372036854775807',
                '9223372036854775807h => failed to set value for hour unit on span: ' +
                'converting hours to seconds overflows a signed 64-bit integer',
                '9223372036854775807m => failed to set value for minute unit on span: ' +
                'converting minutes to seconds overflows a signed 64-bit integer'
            }
        );
        // One fewer is fine in both cases.
        assertSpans(
            new List<String>{
                '640330789636854775 micros => PT640330789636.854775S',
                '640330789636854775.807 micros => PT640330789636.854775807S',
                '-640330789636854775.807 micros => -PT640330789636.854775807S'
            }
        );
    }

    @IsTest
    static void spansRejectCalendarUnitsBeyondTheirLimit() {
        assertSpanErrors(
            new List<String>{
                '19999 years => failed to set value for year unit on span: ' +
                'parameter \'years\' is not in the required range of -19998..=19998',
                '19999 years ago => failed to set value for year unit on span: ' +
                'parameter \'years\' is not in the required range of -19998..=19998',
                '239977 months => failed to set value for month unit on span: ' +
                'parameter \'months\' is not in the required range of -239976..=239976',
                '239977 months ago => failed to set value for month unit on span: ' +
                'parameter \'months\' is not in the required range of -239976..=239976',
                '1043498 weeks => failed to set value for week unit on span: ' +
                'parameter \'weeks\' is not in the required range of -1043497..=1043497',
                '1043498 weeks ago => failed to set value for week unit on span: ' +
                'parameter \'weeks\' is not in the required range of -1043497..=1043497',
                '7304485 days => failed to set value for day unit on span: ' +
                'parameter \'days\' is not in the required range of -7304484..=7304484',
                '7304485 days ago => failed to set value for day unit on span: ' +
                'parameter \'days\' is not in the required range of -7304484..=7304484'
            }
        );
    }

    @IsTest
    static void spansRejectValuesBeyondASigned64BitInteger() {
        assertSpanErrors(
            new List<String>{
                '9223372036854775808 nanoseconds => value for nanoseconds is too big (or small) ' +
                'to fit into a signed 64-bit integer',
                // Negated, the value fits in 64 bits, but a span stops one short of it.
                '9223372036854775808 nanoseconds ago => ' +
                'failed to set value for nanosecond unit on span: ' +
                'parameter \'nanoseconds\' is not in the required range of ' +
                '-9223372036854775807..=9223372036854775807',
                '18446744073709551615 nanoseconds => value for nanoseconds is too big (or small) ' +
                'to fit into a signed 64-bit integer',
                '18446744073709551616 nanoseconds => number too big to parse into 64-bit integer',
                '1h 18446744073709551616s => number too big to parse into 64-bit integer'
            }
        );
    }

    @IsTest
    static void spansRejectFractionsOfCalendarUnitsAndNanoseconds() {
        assertSpanErrors(
            new List<String>{
                '1.5 years => fractional years are not supported',
                '1.5 nanos => fractional nanoseconds are not supported',
                '1.h => found decimal after seconds component, ' +
                'but did not find any digits after decimal',
                // Only nine fractional digits are read; the tenth is not a unit label.
                '1.1234567891s => expected to find unit designator suffix ' +
                '(e.g., `years` or `secs`) after parsing integer',
                // Nothing may follow a unit that has a fraction.
                '1.5h 1m => parsed value \'PT1H30M\', but unparsed input "1m" remains ' +
                '(expected no unparsed input)'
            }
        );
    }

    @IsTest
    static void spansRejectMalformedClockTimes() {
        assertSpanErrors(
            new List<String>{
                '05: => when parsing the `HH:MM:SS` format, expected to parse minute following hour',
                '05:06 => when parsing the `HH:MM:SS` format, expected to parse `:` following minute',
                '05:06x => when parsing the `HH:MM:SS` format, expected to parse `:` following minute',
                '05:06: => when parsing the `HH:MM:SS` format, expected to parse second following minute',
                '2 hours, 05:06:07 => found `HH:MM:SS` after unit hour, ' +
                'but `HH:MM:SS` can only appear after years, months, weeks or days'
            }
        );
    }

    // ---- signed durations -------------------------------------------------

    @IsTest
    static void durationsParseFromUnitsAndClockTimes() {
        assertDurations(
            new List<String>{
                '1 hour, 2 minutes, 3 seconds => PT1H2M3S',
                '01:02:03 => PT1H2M3S',
                '999:999:999 => PT1015H55M39S'
            }
        );
    }

    @IsTest
    static void durationsCoverTheWholeRangeOfSeconds() {
        assertDurations(
            new List<String>{
                '9223372036854775807s => PT2562047788015215H30M7S',
                '-9223372036854775808s => -PT2562047788015215H30M8S',
                '9223372036854775808s ago => -PT2562047788015215H30M8S'
            }
        );
        assertDurationErrors(
            new List<String>{
                '9223372036854775808s => value for seconds is too big (or small) ' +
                'to fit into a signed 64-bit integer'
            }
        );
        Assert.areEqual(
            JiffMath.LONG_MIN,
            JiffFriendlyParser.parseDuration('-9223372036854775808s').asSecs()
        );
    }

    @IsTest
    static void aFractionIsAddedToASignedDuration() {
        assertDurations(
            new List<String>{
                '1.5hrs => PT1H30M',
                '1.5mins => PT1M30S',
                '1.5secs => PT1.5S',
                '1.5msecs => PT0.0015S',
                '1.5µsecs => PT0.0000015S',
                '-0.5secs => -PT0.5S',
                '0.5secs ago => -PT0.5S',
                '1h 1.5mins => PT1H1M30S',
                '1m 1.5secs => PT1M1.5S',
                '1s 1.5msecs => PT1.0015S',
                '1ms 1.5µsecs => PT0.0010015S',
                '1s2000ms => PT3S'
            }
        );
    }

    @IsTest
    static void durationsAreNotBoundByTheLimitsOfASpan() {
        assertDurations(
            new List<String>{
                '175307616 hours => PT175307616H',
                '175307616 hours ago => -PT175307616H',
                '10518456960 minutes => PT175307616H',
                '10518456960 minutes ago => -PT175307616H',
                '631107417600 seconds => PT175307616H',
                '631107417600 seconds ago => -PT175307616H',
                '631107417600000 milliseconds => PT175307616H',
                '631107417600000 milliseconds ago => -PT175307616H',
                '631107417600000000 microseconds => PT175307616H',
                '631107417600000000 microseconds ago => -PT175307616H',
                '9223372036854775807 nanoseconds => PT2562047H47M16.854775807S',
                '9223372036854775807 nanoseconds ago => -PT2562047H47M16.854775807S',
                '175307617 hours => PT175307617H',
                '175307617 hours ago => -PT175307617H',
                '10518456961 minutes => PT175307616H1M',
                '10518456961 minutes ago => -PT175307616H1M',
                '631107417601 seconds => PT175307616H1S',
                '631107417601 seconds ago => -PT175307616H1S',
                '631107417600001 milliseconds => PT175307616H0.001S',
                '631107417600001 milliseconds ago => -PT175307616H0.001S',
                '631107417600000001 microseconds => PT175307616H0.000001S',
                '631107417600000001 microseconds ago => -PT175307616H0.000001S',
                '2562047788015215hours => PT2562047788015215H',
                '-2562047788015215hours => -PT2562047788015215H',
                '153722867280912930minutes => PT2562047788015215H30M',
                '153722867280912930minutes ago => -PT2562047788015215H30M',
                '9223372036854775807seconds => PT2562047788015215H30M7S',
                '-9223372036854775807seconds => -PT2562047788015215H30M7S',
                '9223372036854775807 micros => PT2562047788H54.775807S'
            }
        );
    }

    @IsTest
    static void durationsRejectTotalsThatOverflow() {
        assertDurationErrors(
            new List<String>{
                '2562047788015216hrs => accumulated duration overflowed ' +
                'when adding value to unit hour',
                '153722867280912931mins => accumulated duration overflowed ' +
                'when adding value to unit minute',
                '9223372036854775808s => value for seconds is too big (or small) ' +
                'to fit into a signed 64-bit integer',
                '9223372036854775808 micros => value for microseconds is too big (or small) ' +
                'to fit into a signed 64-bit integer',
                '18446744073709551616s => number too big to parse into 64-bit integer',
                '1m 9223372036854775807s => accumulated duration overflowed ' +
                'when adding value to unit second',
                '2562047788015215.6h => accumulated duration overflowed ' +
                'when adding fractional value to unit hour'
            }
        );
    }

    @IsTest
    static void durationsRejectCalendarUnits() {
        assertDurationErrors(
            new List<String>{
                '1 day => parsing calendar units (days in this case) in this context ' +
                'is not supported (perhaps try parsing into a `JiffSpan` instead)',
                '0d => parsing calendar units (days in this case) in this context ' +
                'is not supported (perhaps try parsing into a `JiffSpan` instead)',
                '1 year 2 hours => parsing calendar units (years in this case) in this context ' +
                'is not supported (perhaps try parsing into a `JiffSpan` instead)',
                '1 week, 01:02:03 => parsing calendar units (weeks in this case) in this context ' +
                'is not supported (perhaps try parsing into a `JiffSpan` instead)'
            }
        );
    }

    @IsTest
    static void durationsRejectMalformedText() {
        assertDurationErrors(
            new List<String>{
                ' => an empty string is not valid',
                '  => expected duration to start with a unit value (a decimal integer) ' +
                'after an optional sign, but no integer was found',
                '5 => expected to find unit designator suffix ' +
                '(e.g., `years` or `secs`) after parsing integer',
                'a => expected duration to start with a unit value (a decimal integer) ' +
                'after an optional sign, but no integer was found',
                '2 minutes 1 hour => found value with unit hour after unit minute, ' +
                'but units must be written from largest to smallest ' +
                '(and they can\'t be repeated)',
                '1 hour 1 minut => parsed value \'PT1H1M\', but unparsed input "ut" remains ' +
                '(expected no unparsed input)',
                '2 minutes, => expected whitespace after comma, but found end of input',
                '2 minutes,  => found comma at the end of duration, ' +
                'but a comma indicates at least one more unit follows',
                '2 minutes , => parsed value \'PT2M\', but unparsed input "," remains ' +
                '(expected no unparsed input)',
                '1.5 nanos => fractional nanoseconds are not supported'
            }
        );
    }

    @IsTest
    static void durationsRejectTwoSignsAndAgoWithoutASpace() {
        assertDurationErrors(
            new List<String>{
                '1hago => parsed value \'PT1H\', but unparsed input "ago" remains ' +
                '(expected no unparsed input)',
                '1 hour 1 minuteago => parsed value \'PT1H1M\', but unparsed input "ago" remains ' +
                '(expected no unparsed input)',
                '+1 hour 1 minute ago => expected to find either a prefix sign (+/-) ' +
                'or a suffix sign (`ago`), but found both',
                '-1 hour 1 minute ago => expected to find either a prefix sign (+/-) ' +
                'or a suffix sign (`ago`), but found both'
            }
        );
    }

    @IsTest
    static void durationsRejectMalformedClockTimes() {
        assertDurationErrors(
            new List<String>{
                '05: => when parsing the `HH:MM:SS` format, expected to parse minute following hour',
                '05:06 => when parsing the `HH:MM:SS` format, expected to parse `:` following minute',
                '05:06: => when parsing the `HH:MM:SS` format, expected to parse second following minute',
                '2 hours, 05:06:07 => found `HH:MM:SS` after unit hour, ' +
                'but `HH:MM:SS` can only appear after years, months, weeks or days'
            }
        );
    }

    @IsTest
    static void nullTextIsRejected() {
        try {
            JiffFriendlyParser.parseSpan(null);
            Assert.fail('expected null to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CONTEXT + 'cannot parse a duration from a null string', e.getMessage());
        }
        try {
            JiffFriendlyParser.parseDuration(null);
            Assert.fail('expected null to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(CONTEXT + 'cannot parse a duration from a null string', e.getMessage());
        }
    }
}
