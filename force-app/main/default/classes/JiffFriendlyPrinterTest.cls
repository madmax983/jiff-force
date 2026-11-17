/**
 * The cases here are the snapshot assertions of the `#[cfg(test)]` module in Jiff's
 * `fmt/friendly/printer.rs` and the examples in its doc comments, plus a few vectors generated
 * by running Jiff 1.0.0 itself where its own tests do not reach.
 *
 * Spans are written as `H=1 M=30`: unit keys and values, with a leading `-` for a negative
 * span. Signed durations are written as `seconds` or `seconds,nanoseconds`, or `MIN` / `MAX`.
 */
@IsTest
private class JiffFriendlyPrinterTest {
    private static final Map<String, JiffUnit> UNIT_KEYS = new Map<String, JiffUnit>{
        'Y' => JiffUnit.YEAR,
        'MO' => JiffUnit.MONTH,
        'W' => JiffUnit.WEEK,
        'D' => JiffUnit.DAY,
        'H' => JiffUnit.HOUR,
        'M' => JiffUnit.MINUTE,
        'S' => JiffUnit.SECOND,
        'MS' => JiffUnit.MILLISECOND,
        'US' => JiffUnit.MICROSECOND,
        'NS' => JiffUnit.NANOSECOND
    };

    // The spans and durations Jiff runs through every designator, spacing, sign and padding
    // setting. Each test below lists the expected text for these, in this order.
    private static final List<String> BASIC_SPANS = new List<String>{
        'S=1',
        'S=2',
        'S=10',
        'M=1 S=40',
        'M=1',
        'M=2',
        'M=10',
        'H=1 M=40',
        'H=1',
        'H=2',
        'H=10',
        'H=100',
        'H=1 M=1 S=1',
        'H=2 M=2 S=2',
        'H=10 M=10 S=10',
        'H=100 M=100 S=100',
        '-H=1',
        '-H=1 S=30'
    };
    private static final List<String> BASIC_DURATIONS = new List<String>{
        '1',
        '2',
        '10',
        '100',
        '60',
        '120',
        '600',
        '6000',
        '3600',
        '7200',
        '36000',
        '360000',
        '3661',
        '7322',
        '36610',
        '366100',
        '-3600',
        '-3630'
    };

    private static JiffSpan span(String spec) {
        Boolean negative = spec.startsWith('-');
        JiffSpan out = new JiffSpan();
        for (String part : (negative ? spec.substring(1) : spec).split(' ')) {
            Integer eq = part.indexOf('=');
            out = out.withUnit(
                UNIT_KEYS.get(part.substring(0, eq)),
                Long.valueOf(part.substring(eq + 1))
            );
        }
        return negative ? out.negate() : out;
    }

    private static JiffSignedDuration duration(String spec) {
        if (spec.equals('MIN')) {
            return JiffSignedDuration.MIN;
        }
        if (spec.equals('MAX')) {
            return JiffSignedDuration.MAX;
        }
        Integer comma = spec.indexOf(',');
        if (comma < 0) {
            return JiffSignedDuration.fromSecs(Long.valueOf(spec));
        }
        return JiffSignedDuration.newInstance(
            Long.valueOf(spec.substring(0, comma)),
            Integer.valueOf(spec.substring(comma + 1))
        );
    }

    /** Each row is `span => expected text`. */
    private static void assertSpans(JiffFriendlyPrinter printer, List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            Assert.areEqual(
                row.substring(at + 4),
                printer.spanToString(span(row.substring(0, at))),
                row
            );
        }
    }

    /** Each row is `duration => expected text`. */
    private static void assertDurations(JiffFriendlyPrinter printer, List<String> rows) {
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            Assert.areEqual(
                row.substring(at + 4),
                printer.durationToString(duration(row.substring(0, at))),
                row
            );
        }
    }

    private static void assertBasicSpans(JiffFriendlyPrinter printer, List<String> expected) {
        Assert.areEqual(BASIC_SPANS.size(), expected.size());
        for (Integer i = 0; i < expected.size(); i++) {
            Assert.areEqual(
                expected.get(i),
                printer.spanToString(span(BASIC_SPANS.get(i))),
                BASIC_SPANS.get(i)
            );
        }
    }

    private static void assertBasicDurations(JiffFriendlyPrinter printer, List<String> expected) {
        Assert.areEqual(BASIC_DURATIONS.size(), expected.size());
        for (Integer i = 0; i < expected.size(); i++) {
            Assert.areEqual(
                expected.get(i),
                printer.durationToString(duration(BASIC_DURATIONS.get(i))),
                BASIC_DURATIONS.get(i)
            );
        }
    }

    private static JiffFriendlyPrinter fractional(JiffFriendlyFractionalUnit unit) {
        return new JiffFriendlyPrinter().fractional(unit);
    }

    private static JiffFriendlyPrinter clock() {
        return new JiffFriendlyPrinter().hoursMinutesSeconds(true);
    }

    // ---- spans: designators, spacing, sign, padding ----------------------------

    @IsTest
    static void spansPrintCompactLabelsByDefault() {
        List<String> expected = new List<String>{
            '1s',
            '2s',
            '10s',
            '1m 40s',
            '1m',
            '2m',
            '10m',
            '1h 40m',
            '1h',
            '2h',
            '10h',
            '100h',
            '1h 1m 1s',
            '2h 2m 2s',
            '10h 10m 10s',
            '100h 100m 100s',
            '1h ago',
            '1h 30s ago'
        };
        assertBasicSpans(new JiffFriendlyPrinter(), expected);
        assertBasicSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.COMPACT),
            expected
        );
        // Units are written as stored, not balanced.
        assertSpans(new JiffFriendlyPrinter(), new List<String>{ 'S=1 MS=2000 => 1s 2000ms' });
    }

    @IsTest
    static void spansPrintVerboseLabels() {
        assertBasicSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{
                '1second',
                '2seconds',
                '10seconds',
                '1minute 40seconds',
                '1minute',
                '2minutes',
                '10minutes',
                '1hour 40minutes',
                '1hour',
                '2hours',
                '10hours',
                '100hours',
                '1hour 1minute 1second',
                '2hours 2minutes 2seconds',
                '10hours 10minutes 10seconds',
                '100hours 100minutes 100seconds',
                '1hour ago',
                '1hour 30seconds ago'
            }
        );
    }

    @IsTest
    static void spansPrintShortLabels() {
        assertBasicSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{
                '1sec',
                '2secs',
                '10secs',
                '1min 40secs',
                '1min',
                '2mins',
                '10mins',
                '1hr 40mins',
                '1hr',
                '2hrs',
                '10hrs',
                '100hrs',
                '1hr 1min 1sec',
                '2hrs 2mins 2secs',
                '10hrs 10mins 10secs',
                '100hrs 100mins 100secs',
                '1hr ago',
                '1hr 30secs ago'
            }
        );
    }

    @IsTest
    static void everyUnitHasASingularAndPluralLabelInEachStyle() {
        String one = 'Y=1 MO=1 W=1 D=1 H=1 M=1 S=1 MS=1 US=1 NS=1 => ';
        String two = 'Y=2 MO=2 W=2 D=2 H=2 M=2 S=2 MS=2 US=2 NS=2 => ';
        assertSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{
                one +
                '1year 1month 1week 1day 1hour 1minute 1second ' +
                '1millisecond 1microsecond 1nanosecond',
                two +
                '2years 2months 2weeks 2days 2hours 2minutes 2seconds ' +
                '2milliseconds 2microseconds 2nanoseconds'
            }
        );
        assertSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{
                one + '1yr 1mo 1wk 1day 1hr 1min 1sec 1msec 1µsec 1nsec',
                two + '2yrs 2mos 2wks 2days 2hrs 2mins 2secs 2msecs 2µsecs 2nsecs'
            }
        );
        assertSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.COMPACT),
            new List<String>{
                one + '1y 1mo 1w 1d 1h 1m 1s 1ms 1µs 1ns',
                two + '2y 2mo 2w 2d 2h 2m 2s 2ms 2µs 2ns'
            }
        );
        assertSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.HUMAN_TIME),
            new List<String>{
                one + '1y 1month 1w 1d 1h 1m 1s 1ms 1us 1ns',
                two + '2y 2months 2w 2d 2h 2m 2s 2ms 2us 2ns'
            }
        );
    }

    @IsTest
    static void theMicroSignInLabelsIsU00B5() {
        String printed = new JiffFriendlyPrinter().spanToString(new JiffSpan().microseconds(5));
        Assert.areEqual(3, printed.length());
        Assert.areEqual(181, printed.charAt(1));
    }

    @IsTest
    static void humanTimeLabelsMatchWhatTheHumantimeCrateParses() {
        JiffFriendlyPrinter printer = new JiffFriendlyPrinter()
            .designator(JiffFriendlyDesignator.HUMAN_TIME);
        assertSpans(
            printer,
            new List<String>{
                'Y=2 MO=1 D=15 H=5 M=59 S=1 MS=123 US=456 NS=789 => ' +
                '2y 1month 15d 5h 59m 1s 123ms 456us 789ns',
                'Y=1 MO=1 D=15 H=7 M=26 S=24 MS=123 US=456 NS=789 => ' +
                '1y 1month 15d 7h 26m 24s 123ms 456us 789ns',
                'Y=1 MO=2 => 1y 2months'
            }
        );
        assertDurations(
            printer,
            new List<String>{ '26784,123456789 => 7h 26m 24s 123ms 456us 789ns' }
        );
    }

    @IsTest
    static void spansPrintAForcedSign() {
        assertBasicSpans(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{
                '+1s',
                '+2s',
                '+10s',
                '+1m 40s',
                '+1m',
                '+2m',
                '+10m',
                '+1h 40m',
                '+1h',
                '+2h',
                '+10h',
                '+100h',
                '+1h 1m 1s',
                '+2h 2m 2s',
                '+10h 10m 10s',
                '+100h 100m 100s',
                '-1h',
                '-1h 30s'
            }
        );
    }

    @IsTest
    static void spansPrintTheSignAsAPrefixOrSuffixOnRequest() {
        assertSpans(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.SIGN),
            new List<String>{ '-H=1 M=30 => -1h 30m', 'H=1 M=30 => 1h 30m' }
        );
        assertSpans(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.SUFFIX),
            new List<String>{ '-H=1 M=30 => 1h 30m ago', 'H=1 M=30 => 1h 30m' }
        );
        // An explicit suffix is honoured even without spacing, where `AUTO` uses a prefix.
        assertSpans(
            new JiffFriendlyPrinter()
                .direction(JiffFriendlyDirection.SUFFIX)
                .spacing(JiffFriendlySpacing.NONE),
            new List<String>{ '-H=1 M=30 => 1h30m ago' }
        );
        assertSpans(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{ 'S=0 => +0s' }
        );
    }

    @IsTest
    static void spansPrintZeroPaddedValues() {
        assertBasicSpans(
            new JiffFriendlyPrinter().padding(2),
            new List<String>{
                '01s',
                '02s',
                '10s',
                '01m 40s',
                '01m',
                '02m',
                '10m',
                '01h 40m',
                '01h',
                '02h',
                '10h',
                '100h',
                '01h 01m 01s',
                '02h 02m 02s',
                '10h 10m 10s',
                '100h 100m 100s',
                '01h ago',
                '01h 30s ago'
            }
        );
        assertSpans(new JiffFriendlyPrinter().padding(3), new List<String>{ 'H=1 => 001h' });
    }

    @IsTest
    static void spansPrintWithoutSpaces() {
        assertBasicSpans(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.NONE),
            new List<String>{
                '1s',
                '2s',
                '10s',
                '1m40s',
                '1m',
                '2m',
                '10m',
                '1h40m',
                '1h',
                '2h',
                '10h',
                '100h',
                '1h1m1s',
                '2h2m2s',
                '10h10m10s',
                '100h100m100s',
                '-1h',
                '-1h30s'
            }
        );
    }

    @IsTest
    static void spansPrintWithSpacesBeforeLabels() {
        assertBasicSpans(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{
                '1 s',
                '2 s',
                '10 s',
                '1 m 40 s',
                '1 m',
                '2 m',
                '10 m',
                '1 h 40 m',
                '1 h',
                '2 h',
                '10 h',
                '100 h',
                '1 h 1 m 1 s',
                '2 h 2 m 2 s',
                '10 h 10 m 10 s',
                '100 h 100 m 100 s',
                '1 h ago',
                '1 h 30 s ago'
            }
        );
    }

    @IsTest
    static void spansPrintWithCommasBetweenUnits() {
        assertBasicSpans(
            new JiffFriendlyPrinter()
                .commaAfterDesignator(true)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{
                '1 s',
                '2 s',
                '10 s',
                '1 m, 40 s',
                '1 m',
                '2 m',
                '10 m',
                '1 h, 40 m',
                '1 h',
                '2 h',
                '10 h',
                '100 h',
                '1 h, 1 m, 1 s',
                '2 h, 2 m, 2 s',
                '10 h, 10 m, 10 s',
                '100 h, 100 m, 100 s',
                '1 h ago',
                '1 h, 30 s ago'
            }
        );
    }

    @IsTest
    static void theDocumentedStylesPrintTheSameSpanDifferently() {
        String units = 'Y=1 MO=2 H=15 S=30 NS=1 => ';
        assertSpans(new JiffFriendlyPrinter(), new List<String>{ units + '1y 2mo 15h 30s 1ns' });
        assertSpans(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{ units + '1yr 2mos 15hrs 30secs 1nsec' }
        );
        assertSpans(
            new JiffFriendlyPrinter()
                .spacing(JiffFriendlySpacing.NONE)
                .designator(JiffFriendlyDesignator.COMPACT),
            new List<String>{ units + '1y2mo15h30s1ns', '-' + units + '-1y2mo15h30s1ns' }
        );
        JiffFriendlyPrinter verbose = new JiffFriendlyPrinter()
            .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS)
            .commaAfterDesignator(true)
            .designator(JiffFriendlyDesignator.VERBOSE);
        assertSpans(
            verbose,
            new List<String>{
                units + '1 year, 2 months, 15 hours, 30 seconds, 1 nanosecond',
                'Y=5 MO=3 MS=123 => 5 years, 3 months, 123 milliseconds',
                'Y=1 MO=2 => 1 year, 2 months'
            }
        );
        assertSpans(
            verbose.hoursMinutesSeconds(true),
            new List<String>{ units + '1 year, 2 months, 15:00:30.000000001' }
        );
        assertSpans(
            new JiffFriendlyPrinter(),
            new List<String>{
                '-' +
                units +
                '1y 2mo 15h 30s 1ns ago',
                'Y=1 MO=2 W=3 D=4 H=5 M=6 S=7 MS=8 US=9 NS=10 => ' +
                '1y 2mo 3w 4d 5h 6m 7s 8ms 9µs 10ns'
            }
        );
    }

    @IsTest
    static void aZeroSpanPrintsTheZeroUnit() {
        assertSpans(new JiffFriendlyPrinter(), new List<String>{ 'S=0 => 0s', 'Y=0 => 0s' });
        assertSpans(
            new JiffFriendlyPrinter().zeroUnit(JiffUnit.YEAR),
            new List<String>{ 'S=0 => 0y' }
        );
        // The fractional unit takes over from the zero unit.
        assertSpans(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.YEAR)
                .fractional(JiffFriendlyFractionalUnit.MINUTE),
            new List<String>{ 'S=0 => 0m' }
        );
        assertSpans(
            new JiffFriendlyPrinter().zeroUnit(JiffUnit.MINUTE),
            new List<String>{ 'H=5 M=31 => 5h 31m', 'S=0 => 0m' }
        );
        // The zero is always plural, and takes the padding, spacing and sign settings.
        assertSpans(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.YEAR)
                .designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{ 'S=0 => 0years' }
        );
        assertSpans(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.NANOSECOND)
                .designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{ 'S=0 => 0nsecs' }
        );
        assertSpans(
            new JiffFriendlyPrinter().zeroUnit(JiffUnit.MILLISECOND).padding(3),
            new List<String>{ 'S=0 => 000ms' }
        );
        assertSpans(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.DAY)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{ 'S=0 => 0 d' }
        );
        assertSpans(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.YEAR)
                .direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{ 'S=0 => +0y' }
        );
    }

    // ---- spans: fractional units ----------------------------------------------

    @IsTest
    static void spansPrintFractionalHours() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.HOUR);
        assertSpans(
            printer,
            new List<String>{
                'H=1 => 1h',
                'H=1 M=30 => 1.5h',
                'H=1 M=3 => 1.05h',
                'H=1 M=3 NS=1 => 1.05h',
                'S=1 => 0.000277777h',
                // Nine digits are not enough for a nanosecond of an hour.
                'S=1 NS=1 => 0.000277777h',
                'S=0 => 0h',
                'NS=1 => 0h',
                'D=100 H=1 M=30 => 100d 1.5h',
                '-H=1 M=30 => 1.5h ago'
            }
        );
        assertSpans(printer.precision(0), new List<String>{ 'H=1 => 1h', 'H=1 M=30 => 1h' });
        assertSpans(printer.precision(1), new List<String>{ 'H=1 => 1.0h', 'H=1 M=30 => 1.5h' });
        assertSpans(printer.precision(2), new List<String>{ 'H=1 => 1.00h', 'H=1 M=30 => 1.50h' });
    }

    @IsTest
    static void spansPrintFractionalMinutes() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MINUTE);
        assertSpans(
            printer,
            new List<String>{
                'H=1 => 1h',
                'H=1 M=30 => 1h 30m',
                'M=1 => 1m',
                'M=1 S=30 => 1.5m',
                'H=1 NS=1 => 1h',
                'M=1 S=3 => 1.05m',
                'M=1 S=3 NS=1 => 1.05m',
                'S=1 => 0.016666666m',
                'S=1 NS=1 => 0.016666666m',
                'S=0 => 0m',
                'NS=1 => 0m'
            }
        );
        assertSpans(printer.precision(0), new List<String>{ 'M=1 => 1m', 'M=1 S=30 => 1m' });
        assertSpans(printer.precision(1), new List<String>{ 'M=1 => 1.0m', 'M=1 S=30 => 1.5m' });
        assertSpans(printer.precision(2), new List<String>{ 'M=1 => 1.00m', 'M=1 S=30 => 1.50m' });
    }

    @IsTest
    static void spansPrintFractionalSeconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.SECOND);
        assertSpans(
            printer,
            new List<String>{
                'H=1 => 1h',
                'H=1 M=30 => 1h 30m',
                'S=1 => 1s',
                'S=1 MS=500 => 1.5s',
                'S=1 NS=1 => 1.000000001s',
                'NS=1 => 0.000000001s',
                'S=0 => 0s',
                // Everything below a minute is folded together, so this one is balanced.
                'S=1 MS=2000 => 3s'
            }
        );
        assertSpans(printer.precision(0), new List<String>{ 'S=1 => 1s', 'S=1 MS=500 => 1s' });
        assertSpans(printer.precision(1), new List<String>{ 'S=1 => 1.0s', 'S=1 MS=500 => 1.5s' });
        assertSpans(
            printer.precision(2),
            new List<String>{ 'S=1 => 1.00s', 'S=1 MS=500 => 1.50s' }
        );
        assertSpans(printer.precision(3), new List<String>{ 'S=1 MS=1 US=1 NS=1 => 1.001s' });
    }

    @IsTest
    static void spansPrintFractionalMilliseconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MILLISECOND);
        assertSpans(
            printer,
            new List<String>{
                'H=1 => 1h',
                'H=1 M=30 => 1h 30m',
                'H=1 M=30 S=10 => 1h 30m 10s',
                'S=1 => 1s',
                'S=1 MS=500 => 1s 500ms',
                'MS=1 NS=1 => 1.000001ms',
                'NS=1 => 0.000001ms',
                'S=0 => 0ms'
            }
        );
        assertSpans(
            printer.precision(0),
            new List<String>{ 'S=1 => 1s', 'S=1 MS=1 US=500 => 1s 1ms' }
        );
        assertSpans(
            printer.precision(1),
            new List<String>{ 'S=1 => 1s 0.0ms', 'S=1 MS=1 US=500 => 1s 1.5ms' }
        );
        assertSpans(
            printer.precision(2),
            new List<String>{ 'S=1 => 1s 0.00ms', 'S=1 MS=1 US=500 => 1s 1.50ms', 'S=0 => 0.00ms' }
        );
    }

    @IsTest
    static void spansPrintFractionalMicroseconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MICROSECOND);
        assertSpans(
            printer,
            new List<String>{
                'H=1 => 1h',
                'H=1 M=30 => 1h 30m',
                'H=1 M=30 S=10 => 1h 30m 10s',
                'S=1 => 1s',
                'S=1 MS=500 => 1s 500ms',
                'MS=1 NS=1 => 1ms 0.001µs',
                'NS=1 => 0.001µs',
                'S=0 => 0µs'
            }
        );
        assertSpans(
            printer.precision(0),
            new List<String>{ 'S=1 => 1s', 'S=1 MS=1 US=500 => 1s 1ms 500µs' }
        );
        assertSpans(
            printer.precision(1),
            new List<String>{ 'S=1 => 1s 0.0µs', 'S=1 MS=1 US=500 => 1s 1ms 500.0µs' }
        );
        assertSpans(
            printer.precision(2),
            new List<String>{ 'S=1 => 1s 0.00µs', 'S=1 MS=1 US=500 => 1s 1ms 500.00µs' }
        );
    }

    @IsTest
    static void aFractionalValueIsPluralUnlessItIsExactlyOne() {
        JiffFriendlyPrinter hours = fractional(JiffFriendlyFractionalUnit.HOUR)
            .designator(JiffFriendlyDesignator.SHORT_FORM);
        assertSpans(hours, new List<String>{ 'H=1 M=30 => 1.5hrs' });
        // A precision of zero drops the fraction, so what is printed is exactly one.
        assertSpans(hours.precision(0), new List<String>{ 'H=1 M=30 => 1hr' });
        // But a fraction that is merely truncated away still counts.
        assertSpans(hours.precision(1), new List<String>{ 'H=1 => 1.0hr', 'H=1 M=3 => 1.0hrs' });
        JiffFriendlyPrinter seconds = fractional(JiffFriendlyFractionalUnit.SECOND)
            .designator(JiffFriendlyDesignator.VERBOSE);
        assertSpans(
            seconds,
            new List<String>{ 'S=1 MS=500 => 1.5seconds', 'S=1 => 1second', 'MS=500 => 0.5seconds' }
        );
        assertSpans(
            seconds.precision(3),
            new List<String>{ 'S=0 => 0.000seconds', 'S=1 => 1.000second' }
        );
        assertSpans(
            seconds.precision(3).spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{ 'S=1 => 1.000 second' }
        );
    }

    @IsTest
    static void precisionOnlyAppliesWhenFractionsAreOn() {
        assertSpans(new JiffFriendlyPrinter().precision(2), new List<String>{ 'H=1 => 1h' });
        assertSpans(
            new JiffFriendlyPrinter().precision(2).fractional(JiffFriendlyFractionalUnit.HOUR),
            new List<String>{ 'H=1 => 1.00h' }
        );
        // Anything above nine digits is nine digits.
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.SECOND).precision(12),
            new List<String>{ 'S=1 NS=1 => 1.000000001s' }
        );
        // And the automatic precision can be restored.
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.SECOND).precision(4).precision(null),
            new List<String>{ 'S=1 MS=500 => 1.5s', 'S=1 => 1s' }
        );
    }

    @IsTest
    static void fractionsOfSpansAtTheirLimitsDoNotOverflow() {
        String clockUnits = 'H=175307616 M=10518456960 S=631107417600';
        String subsec = 'MS=631107417600000 US=631107417600000000 NS=9223372036854775807';
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.HOUR),
            new List<String>{ clockUnits + ' ' + subsec + ' => 879100127.788015215h' }
        );
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.MINUTE),
            new List<String>{ clockUnits + ' => 175307616h 21036913920m' }
        );
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.SECOND),
            new List<String>{ 'S=631107417600 ' + subsec + ' => 1902545624836.854775807s' }
        );
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.MILLISECOND),
            new List<String>{ subsec + ' => 1271438207236854.775807ms' }
        );
        assertSpans(
            fractional(JiffFriendlyFractionalUnit.MICROSECOND),
            new List<String>{
                'US=631107417600000000 NS=9223372036854775807 => 640330789636854775.807µs'
            }
        );
        assertSpans(
            clock(),
            new List<String>{
                clockUnits +
                ' ' +
                subsec +
                ' => 175307616:10518456960:1902545624836.854775807'
            }
        );
    }

    // ---- spans: hours-minutes-seconds -------------------------------------------

    @IsTest
    static void spansPrintAsAClockWithValuesAsStored() {
        assertSpans(
            clock(),
            new List<String>{
                'S=1 => 00:00:01',
                'S=2 => 00:00:02',
                'S=10 => 00:00:10',
                'S=100 => 00:00:100',
                'M=1 => 00:01:00',
                'M=2 => 00:02:00',
                'M=10 => 00:10:00',
                'M=100 => 00:100:00',
                'M=120 => 00:120:00',
                'H=1 => 01:00:00',
                'H=2 => 02:00:00',
                'H=10 => 10:00:00',
                'H=100 => 100:00:00',
                'H=1 M=1 S=1 => 01:01:01',
                'H=2 M=2 S=2 => 02:02:02',
                'H=10 M=10 S=10 => 10:10:10',
                'H=100 M=100 S=100 => 100:100:100',
                'D=1 H=1 M=1 S=1 => 1d 01:01:01',
                'D=1 => 1d 00:00:00',
                'D=1 S=2 => 1d 00:00:02',
                'S=0 => 00:00:00',
                'H=2 M=59 S=15 MS=123 => 02:59:15.123',
                '-H=2 M=59 S=15 MS=123 => -02:59:15.123',
                'D=15 H=2 M=59 S=15 MS=123 => 15d 02:59:15.123',
                '-D=15 H=2 M=59 S=15 MS=123 => 15d 02:59:15.123 ago'
            }
        );
    }

    @IsTest
    static void calendarUnitsBeforeAClockKeepTheirLabelsAndSeparators() {
        assertSpans(
            clock()
                .commaAfterDesignator(true)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{
                'D=1 H=1 M=1 S=1 => 1 d, 01:01:01',
                'Y=1 MO=1 W=1 D=1 H=1 M=1 S=1 => 1 y, 1 mo, 1 w, 1 d, 01:01:01',
                'D=1 H=1 M=1 S=1 NS=1 => 1 d, 01:01:01.000000001'
            }
        );
        // Even with spacing off, a space keeps the clock apart from the last label.
        assertSpans(
            clock().spacing(JiffFriendlySpacing.NONE),
            new List<String>{ 'Y=1 MO=2 H=15 => 1y2mo 15:00:00' }
        );
        assertSpans(
            clock().spacing(JiffFriendlySpacing.NONE).commaAfterDesignator(true),
            new List<String>{ 'Y=1 MO=2 H=15 => 1y,2mo, 15:00:00' }
        );
        assertSpans(
            clock().designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{ 'D=2 => 2days 00:00:00', '-Y=1 MS=1 => 1year 00:00:00.001 ago' }
        );
    }

    @IsTest
    static void aClockShowsTheSignAsAPrefixUnlessCalendarUnitsPrecedeIt() {
        assertSpans(
            clock().direction(JiffFriendlyDirection.AUTO),
            new List<String>{
                'H=1 => 01:00:00',
                '-H=1 => -01:00:00',
                'D=1 H=1 => 1d 01:00:00',
                '-D=1 H=1 => 1d 01:00:00 ago'
            }
        );
        assertSpans(
            clock().direction(JiffFriendlyDirection.SIGN),
            new List<String>{
                'H=1 => 01:00:00',
                '-H=1 => -01:00:00',
                'D=1 H=1 => 1d 01:00:00',
                '-D=1 H=1 => -1d 01:00:00'
            }
        );
        assertSpans(
            clock().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{
                'H=1 => +01:00:00',
                '-H=1 => -01:00:00',
                'D=1 H=1 => +1d 01:00:00',
                '-D=1 H=1 => -1d 01:00:00',
                'S=0 => +00:00:00'
            }
        );
        assertSpans(
            clock().direction(JiffFriendlyDirection.SUFFIX),
            new List<String>{
                'H=1 => 01:00:00',
                '-H=1 => 01:00:00 ago',
                'D=1 H=1 => 1d 01:00:00',
                '-D=1 H=1 => 1d 01:00:00 ago'
            }
        );
        assertSpans(
            clock().spacing(JiffFriendlySpacing.NONE),
            new List<String>{ '-D=1 H=1 => -1d 01:00:00' }
        );
        assertSpans(
            clock().spacing(JiffFriendlySpacing.NONE).direction(JiffFriendlyDirection.SUFFIX),
            new List<String>{ '-H=1 => 01:00:00 ago' }
        );
        assertSpans(
            clock().spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{ '-D=1 H=1 => 1 d 01:00:00 ago' }
        );
    }

    @IsTest
    static void aClockFoldsEverythingBelowASecondIntoAFraction() {
        assertSpans(
            clock(),
            new List<String>{
                'NS=1 => 00:00:00.000000001',
                '-NS=1 => -00:00:00.000000001',
                'S=1 NS=123 => 00:00:01.000000123',
                'S=1 MS=123 => 00:00:01.123',
                'S=1 MS=1123 => 00:00:02.123',
                'S=1 MS=61123 => 00:00:62.123'
            }
        );
        assertSpans(
            clock().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{ 'NS=1 => +00:00:00.000000001' }
        );
        assertSpans(
            clock().precision(3),
            new List<String>{
                'S=1 => 00:00:01.000',
                'S=1 MS=1 => 00:00:01.001',
                'S=1 MS=123 => 00:00:01.123',
                'S=1 MS=100 => 00:00:01.100',
                'S=1 MS=1 US=1 NS=1 => 00:00:01.001'
            }
        );
        assertSpans(
            clock().precision(0),
            new List<String>{ 'S=1 => 00:00:01', 'S=1 MS=1 => 00:00:01' }
        );
        assertSpans(clock().precision(1), new List<String>{ 'S=1 MS=999 => 00:00:01.9' });
        assertSpans(clock().precision(12), new List<String>{ 'S=1 NS=1 => 00:00:01.000000001' });
        // The fractional unit setting is ignored: the seconds always carry the fraction.
        assertSpans(
            clock().fractional(JiffFriendlyFractionalUnit.HOUR),
            new List<String>{ 'H=1 M=30 S=1 MS=500 => 01:30:01.5' }
        );
    }

    @IsTest
    static void aClockIsPaddedToTwoDigitsUnlessPaddingIsSet() {
        assertSpans(clock(), new List<String>{ 'H=1 => 01:00:00', 'D=1 H=1 => 1d 01:00:00' });
        assertSpans(clock().padding(0), new List<String>{ 'H=1 => 1:0:0' });
        assertSpans(clock().padding(3), new List<String>{ 'D=1 H=1 => 001d 001:000:000' });
        // Padding stops at twenty digits.
        assertSpans(
            clock().padding(30),
            new List<String>{
                'H=1 => 00000000000000000001:00000000000000000000:00000000000000000000'
            }
        );
        assertSpans(
            new JiffFriendlyPrinter().padding(25),
            new List<String>{ 'H=1 => 00000000000000000001h' }
        );
    }

    // ---- signed durations --------------------------------------------------------

    @IsTest
    static void durationsPrintCompactLabelsByDefault() {
        List<String> expected = new List<String>{
            '1s',
            '2s',
            '10s',
            '1m 40s',
            '1m',
            '2m',
            '10m',
            '1h 40m',
            '1h',
            '2h',
            '10h',
            '100h',
            '1h 1m 1s',
            '2h 2m 2s',
            '10h 10m 10s',
            '101h 41m 40s',
            '1h ago',
            '1h 30s ago'
        };
        assertBasicDurations(new JiffFriendlyPrinter(), expected);
        assertBasicDurations(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.COMPACT),
            expected
        );
        assertDurations(
            new JiffFriendlyPrinter(),
            new List<String>{
                '86525,123000789 => 24h 2m 5s 123ms 789ns',
                '-86525,-123000789 => 24h 2m 5s 123ms 789ns ago',
                '9000,123456789 => 2h 30m 123ms 456µs 789ns',
                '54030,1 => 15h 30s 1ns',
                '0,-1 => 1ns ago',
                '0 => 0s'
            }
        );
    }

    @IsTest
    static void durationsPrintVerboseLabels() {
        assertBasicDurations(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{
                '1second',
                '2seconds',
                '10seconds',
                '1minute 40seconds',
                '1minute',
                '2minutes',
                '10minutes',
                '1hour 40minutes',
                '1hour',
                '2hours',
                '10hours',
                '100hours',
                '1hour 1minute 1second',
                '2hours 2minutes 2seconds',
                '10hours 10minutes 10seconds',
                '101hours 41minutes 40seconds',
                '1hour ago',
                '1hour 30seconds ago'
            }
        );
    }

    @IsTest
    static void durationsPrintShortLabels() {
        assertBasicDurations(
            new JiffFriendlyPrinter().designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{
                '1sec',
                '2secs',
                '10secs',
                '1min 40secs',
                '1min',
                '2mins',
                '10mins',
                '1hr 40mins',
                '1hr',
                '2hrs',
                '10hrs',
                '100hrs',
                '1hr 1min 1sec',
                '2hrs 2mins 2secs',
                '10hrs 10mins 10secs',
                '101hrs 41mins 40secs',
                '1hr ago',
                '1hr 30secs ago'
            }
        );
    }

    @IsTest
    static void durationsPrintAForcedSign() {
        assertBasicDurations(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{
                '+1s',
                '+2s',
                '+10s',
                '+1m 40s',
                '+1m',
                '+2m',
                '+10m',
                '+1h 40m',
                '+1h',
                '+2h',
                '+10h',
                '+100h',
                '+1h 1m 1s',
                '+2h 2m 2s',
                '+10h 10m 10s',
                '+101h 41m 40s',
                '-1h',
                '-1h 30s'
            }
        );
        assertDurations(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{ '0 => +0s' }
        );
    }

    @IsTest
    static void durationsPrintTheSignAsAPrefixOrSuffixOnRequest() {
        assertDurations(new JiffFriendlyPrinter(), new List<String>{ '-1 => 1s ago' });
        assertDurations(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.SIGN),
            new List<String>{ '-1 => -1s' }
        );
        assertDurations(
            new JiffFriendlyPrinter()
                .direction(JiffFriendlyDirection.SUFFIX)
                .spacing(JiffFriendlySpacing.NONE),
            new List<String>{ '-90 => 1m30s ago' }
        );
        assertDurations(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.NONE),
            new List<String>{ '-90 => -1m30s' }
        );
    }

    @IsTest
    static void durationsPrintZeroPaddedValues() {
        assertBasicDurations(
            new JiffFriendlyPrinter().padding(2),
            new List<String>{
                '01s',
                '02s',
                '10s',
                '01m 40s',
                '01m',
                '02m',
                '10m',
                '01h 40m',
                '01h',
                '02h',
                '10h',
                '100h',
                '01h 01m 01s',
                '02h 02m 02s',
                '10h 10m 10s',
                '101h 41m 40s',
                '01h ago',
                '01h 30s ago'
            }
        );
    }

    @IsTest
    static void durationsPrintWithoutSpaces() {
        assertBasicDurations(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.NONE),
            new List<String>{
                '1s',
                '2s',
                '10s',
                '1m40s',
                '1m',
                '2m',
                '10m',
                '1h40m',
                '1h',
                '2h',
                '10h',
                '100h',
                '1h1m1s',
                '2h2m2s',
                '10h10m10s',
                '101h41m40s',
                '-1h',
                '-1h30s'
            }
        );
    }

    @IsTest
    static void durationsPrintWithSpacesBeforeLabels() {
        assertBasicDurations(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{
                '1 s',
                '2 s',
                '10 s',
                '1 m 40 s',
                '1 m',
                '2 m',
                '10 m',
                '1 h 40 m',
                '1 h',
                '2 h',
                '10 h',
                '100 h',
                '1 h 1 m 1 s',
                '2 h 2 m 2 s',
                '10 h 10 m 10 s',
                '101 h 41 m 40 s',
                '1 h ago',
                '1 h 30 s ago'
            }
        );
    }

    @IsTest
    static void durationsPrintWithCommasBetweenUnits() {
        assertBasicDurations(
            new JiffFriendlyPrinter()
                .commaAfterDesignator(true)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS),
            new List<String>{
                '1 s',
                '2 s',
                '10 s',
                '1 m, 40 s',
                '1 m',
                '2 m',
                '10 m',
                '1 h, 40 m',
                '1 h',
                '2 h',
                '10 h',
                '100 h',
                '1 h, 1 m, 1 s',
                '2 h, 2 m, 2 s',
                '10 h, 10 m, 10 s',
                '101 h, 41 m, 40 s',
                '1 h ago',
                '1 h, 30 s ago'
            }
        );
    }

    @IsTest
    static void aZeroDurationPrintsTheZeroUnit() {
        assertDurations(new JiffFriendlyPrinter(), new List<String>{ '0 => 0s' });
        assertDurations(
            new JiffFriendlyPrinter().zeroUnit(JiffUnit.MINUTE),
            new List<String>{ '0 => 0m' }
        );
        assertDurations(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.HOUR)
                .designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{ '0 => 0hours' }
        );
    }

    @IsTest
    static void durationsPrintFractionalHours() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.HOUR);
        assertDurations(
            printer,
            new List<String>{
                '3600 => 1h',
                '5400 => 1.5h',
                '3780 => 1.05h',
                '3780,1 => 1.05h',
                '3663 => 1.0175h',
                '1 => 0.000277777h',
                '1,1 => 0.000277777h',
                '0 => 0h',
                '0,1 => 0h',
                'MIN => 2562047788015215.502499999h ago'
            }
        );
        assertDurations(printer.precision(0), new List<String>{ '3600 => 1h', '5400 => 1h' });
        assertDurations(printer.precision(1), new List<String>{ '3600 => 1.0h', '5400 => 1.5h' });
        assertDurations(printer.precision(2), new List<String>{ '3600 => 1.00h', '5400 => 1.50h' });
        assertDurations(
            printer.designator(JiffFriendlyDesignator.VERBOSE),
            new List<String>{ '-5400 => 1.5hours ago' }
        );
    }

    @IsTest
    static void durationsPrintFractionalMinutes() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MINUTE);
        assertDurations(
            printer,
            new List<String>{
                '3600 => 1h',
                '5400 => 1h 30m',
                '60 => 1m',
                '90 => 1.5m',
                '3600,1 => 1h',
                '63 => 1.05m',
                '63,1 => 1.05m',
                '3663 => 1h 1.05m',
                '1 => 0.016666666m',
                '1,1 => 0.016666666m',
                '0 => 0m',
                '0,1 => 0m',
                'MIN => 2562047788015215h 30.149999999m ago'
            }
        );
        assertDurations(printer.precision(0), new List<String>{ '60 => 1m', '90 => 1m' });
        assertDurations(printer.precision(1), new List<String>{ '60 => 1.0m', '90 => 1.5m' });
        assertDurations(printer.precision(2), new List<String>{ '60 => 1.00m', '90 => 1.50m' });
        assertDurations(
            printer.designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{ '60 => 1min', '90 => 1.5mins' }
        );
    }

    @IsTest
    static void durationsPrintFractionalSeconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.SECOND);
        assertDurations(
            printer,
            new List<String>{
                '3600 => 1h',
                '5400 => 1h 30m',
                '3663 => 1h 1m 3s',
                '1 => 1s',
                '1,500000000 => 1.5s',
                '1,1 => 1.000000001s',
                '0,1 => 0.000000001s',
                '0 => 0s',
                '-86525,-123000789 => 24h 2m 5.123000789s ago',
                'MIN => 2562047788015215h 30m 8.999999999s ago'
            }
        );
        assertDurations(printer.precision(0), new List<String>{ '1 => 1s', '1,500000000 => 1s' });
        assertDurations(
            printer.precision(1),
            new List<String>{ '1 => 1.0s', '1,500000000 => 1.5s' }
        );
        assertDurations(
            printer.precision(2),
            new List<String>{ '1 => 1.00s', '1,500000000 => 1.50s' }
        );
        JiffFriendlyPrinter verbose = printer.designator(JiffFriendlyDesignator.VERBOSE);
        assertDurations(verbose, new List<String>{ '1,500000000 => 1.5seconds', '1 => 1second' });
        assertDurations(verbose.precision(0), new List<String>{ '1,500000000 => 1second' });
    }

    @IsTest
    static void durationsPrintFractionalMilliseconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MILLISECOND);
        assertDurations(
            printer,
            new List<String>{
                '3600 => 1h',
                '5400 => 1h 30m',
                '5410 => 1h 30m 10s',
                '1 => 1s',
                '1,500000000 => 1s 500ms',
                '0,1000001 => 1.000001ms',
                '0,1 => 0.000001ms',
                '0 => 0ms',
                'MIN => 2562047788015215h 30m 8s 999.999999ms ago'
            }
        );
        assertDurations(printer.precision(0), new List<String>{ '1 => 1s', '1,1500000 => 1s 1ms' });
        assertDurations(
            printer.precision(1),
            new List<String>{ '1 => 1s 0.0ms', '1,1500000 => 1s 1.5ms' }
        );
        assertDurations(
            printer.precision(2),
            new List<String>{ '1 => 1s 0.00ms', '1,1500000 => 1s 1.50ms' }
        );
        assertDurations(
            printer.designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{ '0,1000000 => 1msec', '0,1500000 => 1.5msecs' }
        );
    }

    @IsTest
    static void durationsPrintFractionalMicroseconds() {
        JiffFriendlyPrinter printer = fractional(JiffFriendlyFractionalUnit.MICROSECOND);
        assertDurations(
            printer,
            new List<String>{
                '3600 => 1h',
                '5400 => 1h 30m',
                '5410 => 1h 30m 10s',
                '1 => 1s',
                '1,500000000 => 1s 500ms',
                '0,1000001 => 1ms 0.001µs',
                '0,1 => 0.001µs',
                '0 => 0µs',
                'MIN => 2562047788015215h 30m 8s 999ms 999.999µs ago'
            }
        );
        assertDurations(
            printer.precision(0),
            new List<String>{ '1 => 1s', '1,1500000 => 1s 1ms 500µs' }
        );
        assertDurations(
            printer.precision(1),
            new List<String>{ '1 => 1s 0.0µs', '1,1500000 => 1s 1ms 500.0µs' }
        );
        assertDurations(
            printer.precision(2),
            new List<String>{ '1 => 1s 0.00µs', '1,1500000 => 1s 1ms 500.00µs' }
        );
        assertDurations(
            printer.designator(JiffFriendlyDesignator.SHORT_FORM),
            new List<String>{ '0,1000 => 1µsec', '0,2000 => 2µsecs' }
        );
    }

    @IsTest
    static void durationsPrintAsABalancedClock() {
        assertDurations(
            clock(),
            new List<String>{
                '1 => 00:00:01',
                '2 => 00:00:02',
                '10 => 00:00:10',
                '100 => 00:01:40',
                '60 => 00:01:00',
                '120 => 00:02:00',
                '600 => 00:10:00',
                '6000 => 01:40:00',
                '3600 => 01:00:00',
                '7200 => 02:00:00',
                '36000 => 10:00:00',
                '360000 => 100:00:00',
                '3661 => 01:01:01',
                '7322 => 02:02:02',
                '36610 => 10:10:10',
                '366100 => 101:41:40',
                '10755,123000000 => 02:59:15.123',
                '-10755,-123000000 => -02:59:15.123',
                'MIN => -2562047788015215:30:08.999999999',
                'MAX => 2562047788015215:30:07.999999999'
            }
        );
        assertDurations(clock().padding(0), new List<String>{ '3661,5 => 1:1:1.000000005' });
        assertDurations(
            clock().padding(4).precision(2),
            new List<String>{ '3661,5 => 0001:0001:0001.00' }
        );
    }

    @IsTest
    static void aDurationClockShowsTheSignAsAPrefixUnlessASuffixIsAsked() {
        assertDurations(
            clock().direction(JiffFriendlyDirection.AUTO),
            new List<String>{ '1 => 00:00:01', '-1 => -00:00:01' }
        );
        assertDurations(
            clock().direction(JiffFriendlyDirection.SIGN),
            new List<String>{ '1 => 00:00:01', '-1 => -00:00:01' }
        );
        assertDurations(
            clock().direction(JiffFriendlyDirection.FORCE_SIGN),
            new List<String>{ '1 => +00:00:01', '-1 => -00:00:01', '0,1 => +00:00:00.000000001' }
        );
        assertDurations(
            clock().direction(JiffFriendlyDirection.SUFFIX),
            new List<String>{
                '1 => 00:00:01',
                '-1 => 00:00:01 ago',
                'MIN => 2562047788015215:30:08.999999999 ago'
            }
        );
    }

    @IsTest
    static void aDurationClockCarriesTheFractionOnTheSeconds() {
        assertDurations(
            clock(),
            new List<String>{
                '0,1 => 00:00:00.000000001',
                '0,-1 => -00:00:00.000000001',
                '1,123 => 00:00:01.000000123',
                '1,123000000 => 00:00:01.123',
                '1,1123000000 => 00:00:02.123',
                '61,1123000000 => 00:01:02.123'
            }
        );
        assertDurations(
            clock().precision(3),
            new List<String>{
                '1 => 00:00:01.000',
                '1,1000000 => 00:00:01.001',
                '1,123000000 => 00:00:01.123',
                '1,100000000 => 00:00:01.100'
            }
        );
        assertDurations(
            clock().precision(0),
            new List<String>{ '1 => 00:00:01', '1,1000000 => 00:00:01' }
        );
        assertDurations(clock().precision(1), new List<String>{ '1,999000000 => 00:00:01.9' });
    }

    @IsTest
    static void theLongestValuesPrintInFull() {
        JiffFriendlyPrinter printer = new JiffFriendlyPrinter()
            .padding(255)
            .designator(JiffFriendlyDesignator.VERBOSE)
            .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS)
            .commaAfterDesignator(true);
        assertSpans(
            printer,
            new List<String>{
                '-Y=19998 MO=239976 W=1043497 D=7304484 H=175307616 M=10518456960 ' +
                'S=631107417600 MS=631107417600000 US=631107416600000000 ' +
                'NS=9223372036854775807 => ' +
                '00000000000000019998 years, 00000000000000239976 months, ' +
                '00000000000001043497 weeks, 00000000000007304484 days, ' +
                '00000000000175307616 hours, 00000000010518456960 minutes, ' +
                '00000000631107417600 seconds, 00000631107417600000 milliseconds, ' +
                '00631107416600000000 microseconds, 09223372036854775807 nanoseconds ago'
            }
        );
        assertDurations(
            printer,
            new List<String>{
                'MAX => 00002562047788015215 hours, 00000000000000000030 minutes, ' +
                '00000000000000000007 seconds, 00000000000000000999 milliseconds, ' +
                '00000000000000000999 microseconds, 00000000000000000999 nanoseconds'
            }
        );
        assertDurations(
            new JiffFriendlyPrinter(),
            new List<String>{
                'MIN => 2562047788015215h 30m 8s 999ms 999µs 999ns ago',
                'MAX => 2562047788015215h 30m 7s 999ms 999µs 999ns'
            }
        );
        assertDurations(
            new JiffFriendlyPrinter()
                .designator(JiffFriendlyDesignator.VERBOSE)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS)
                .commaAfterDesignator(true),
            new List<String>{
                'MIN => 2562047788015215 hours, 30 minutes, 8 seconds, ' +
                '999 milliseconds, 999 microseconds, 999 nanoseconds ago'
            }
        );
    }

    // ---- the options object ------------------------------------------------------

    @IsTest
    static void aNewPrinterHasTheDefaultSettings() {
        JiffFriendlyPrinter printer = new JiffFriendlyPrinter();
        Assert.areEqual(JiffFriendlyDesignator.COMPACT, printer.getDesignator());
        Assert.areEqual(JiffFriendlySpacing.BETWEEN_UNITS, printer.getSpacing());
        Assert.areEqual(JiffFriendlyDirection.AUTO, printer.getDirection());
        Assert.isNull(printer.getFractional());
        Assert.isFalse(printer.getCommaAfterDesignator());
        Assert.isFalse(printer.getHoursMinutesSeconds());
        Assert.isNull(printer.getPadding());
        Assert.isNull(printer.getPrecision());
        Assert.areEqual(JiffUnit.SECOND, printer.getZeroUnit());
    }

    @IsTest
    static void settersReturnANewPrinterAndLeaveTheOriginalAlone() {
        JiffFriendlyPrinter original = new JiffFriendlyPrinter();
        JiffFriendlyPrinter changed = original.designator(JiffFriendlyDesignator.VERBOSE)
            .spacing(JiffFriendlySpacing.NONE)
            .direction(JiffFriendlyDirection.SIGN)
            .fractional(JiffFriendlyFractionalUnit.MINUTE)
            .commaAfterDesignator(true)
            .hoursMinutesSeconds(true)
            .padding(4)
            .precision(3)
            .zeroUnit(JiffUnit.HOUR);
        Assert.areEqual(JiffFriendlyDesignator.VERBOSE, changed.getDesignator());
        Assert.areEqual(JiffFriendlySpacing.NONE, changed.getSpacing());
        Assert.areEqual(JiffFriendlyDirection.SIGN, changed.getDirection());
        Assert.areEqual(JiffFriendlyFractionalUnit.MINUTE, changed.getFractional());
        Assert.isTrue(changed.getCommaAfterDesignator());
        Assert.isTrue(changed.getHoursMinutesSeconds());
        Assert.areEqual(4, changed.getPadding());
        Assert.areEqual(3, changed.getPrecision());
        Assert.areEqual(JiffUnit.HOUR, changed.getZeroUnit());

        Assert.areEqual(JiffFriendlyDesignator.COMPACT, original.getDesignator());
        Assert.areEqual(JiffFriendlySpacing.BETWEEN_UNITS, original.getSpacing());
        Assert.areEqual(JiffFriendlyDirection.AUTO, original.getDirection());
        Assert.isNull(original.getFractional());
        Assert.isFalse(original.getCommaAfterDesignator());
        Assert.isFalse(original.getHoursMinutesSeconds());
        Assert.isNull(original.getPadding());
        Assert.isNull(original.getPrecision());
        Assert.areEqual(JiffUnit.SECOND, original.getZeroUnit());

        // Settings that have an "off" position can be turned back off.
        JiffFriendlyPrinter restored = changed.fractional(null)
            .commaAfterDesignator(false)
            .hoursMinutesSeconds(false)
            .precision(null);
        Assert.isNull(restored.getFractional());
        Assert.isFalse(restored.getCommaAfterDesignator());
        Assert.isFalse(restored.getHoursMinutesSeconds());
        Assert.isNull(restored.getPrecision());
        Assert.areEqual(4, restored.getPadding());
    }

    @IsTest
    static void paddingAndPrecisionAreCapped() {
        Assert.areEqual(20, new JiffFriendlyPrinter().padding(255).getPadding());
        Assert.areEqual(20, new JiffFriendlyPrinter().padding(20).getPadding());
        Assert.areEqual(0, new JiffFriendlyPrinter().padding(0).getPadding());
        Assert.areEqual(9, new JiffFriendlyPrinter().precision(10).getPrecision());
        Assert.areEqual(9, new JiffFriendlyPrinter().precision(9).getPrecision());
        Assert.areEqual(0, new JiffFriendlyPrinter().precision(0).getPrecision());
    }

    @IsTest
    static void settersRejectNullsAndNegativeNumbers() {
        JiffFriendlyPrinter printer = new JiffFriendlyPrinter();
        try {
            printer.designator(null);
            Assert.fail('expected a null designator to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('designator must not be null', e.getMessage());
        }
        try {
            printer.spacing(null);
            Assert.fail('expected a null spacing to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('spacing must not be null', e.getMessage());
        }
        try {
            printer.direction(null);
            Assert.fail('expected a null direction to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('direction must not be null', e.getMessage());
        }
        try {
            printer.zeroUnit(null);
            Assert.fail('expected a null zero unit to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('zero unit must not be null', e.getMessage());
        }
        try {
            printer.padding(-1);
            Assert.fail('expected negative padding to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('padding must not be negative', e.getMessage());
        }
        try {
            printer.precision(-1);
            Assert.fail('expected negative precision to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('precision must not be negative', e.getMessage());
        }
    }

    @IsTest
    static void labelsAndFractionalUnitsCanBeLookedUpDirectly() {
        JiffFriendlyPrinter verbose = new JiffFriendlyPrinter()
            .designator(JiffFriendlyDesignator.VERBOSE);
        Assert.areEqual('month', verbose.label(JiffUnit.MONTH, false));
        Assert.areEqual('months', verbose.label(JiffUnit.MONTH, true));
        Assert.areEqual('mo', new JiffFriendlyPrinter().label(JiffUnit.MONTH, true));
        Assert.areEqual(JiffUnit.HOUR, JiffFriendlyPrinter.toUnit(JiffFriendlyFractionalUnit.HOUR));
        Assert.areEqual(
            JiffUnit.MINUTE,
            JiffFriendlyPrinter.toUnit(JiffFriendlyFractionalUnit.MINUTE)
        );
        Assert.areEqual(
            JiffUnit.SECOND,
            JiffFriendlyPrinter.toUnit(JiffFriendlyFractionalUnit.SECOND)
        );
        Assert.areEqual(
            JiffUnit.MILLISECOND,
            JiffFriendlyPrinter.toUnit(JiffFriendlyFractionalUnit.MILLISECOND)
        );
        Assert.areEqual(
            JiffUnit.MICROSECOND,
            JiffFriendlyPrinter.toUnit(JiffFriendlyFractionalUnit.MICROSECOND)
        );
    }
}
