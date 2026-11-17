/**
 * Readers and writers for the encodings used in the vector rows that the oracle generates from
 * the real Jiff crate (see `oracle/src/text.rs`).
 *
 * The readers build values with plain constructors and setters, never with the port's own
 * parsers, so that a vector row means the same thing whether or not the parser under test is
 * right. The writers spell a result the way the oracle spells Jiff's.
 *
 * - A row is fields separated by `|`. `ERR` stands for "Jiff reported an error".
 * - A span is its non-zero units, each with its own sign: `-1y -2mo`, or `0` when empty.
 * - A duration and a timestamp are `seconds,nanoseconds`.
 * - A date, a time and a datetime are ISO 8601 as Jiff prints them.
 * - A weekday is its distance from Monday; an ISO week date is `year,week,weekday`.
 * - Units and rounding modes are the names of their enum constants.
 */
@IsTest
public class JiffOracleSupport {
    /** What a row records when Jiff reported an error. */
    public static final String ERR = 'ERR';

    private static final List<JiffWeekday> WEEKDAYS = JiffWeekday.values();

    private static final Map<String, JiffUnit> UNITS = new Map<String, JiffUnit>{
        'NANOSECOND' => JiffUnit.NANOSECOND,
        'MICROSECOND' => JiffUnit.MICROSECOND,
        'MILLISECOND' => JiffUnit.MILLISECOND,
        'SECOND' => JiffUnit.SECOND,
        'MINUTE' => JiffUnit.MINUTE,
        'HOUR' => JiffUnit.HOUR,
        'DAY' => JiffUnit.DAY,
        'WEEK' => JiffUnit.WEEK,
        'MONTH' => JiffUnit.MONTH,
        'YEAR' => JiffUnit.YEAR
    };

    private static final Map<String, JiffRoundMode> MODES = new Map<String, JiffRoundMode>{
        'CEIL' => JiffRoundMode.CEIL,
        'FLOOR' => JiffRoundMode.FLOOR,
        'EXPAND' => JiffRoundMode.EXPAND,
        'TRUNC' => JiffRoundMode.TRUNC,
        'HALF_CEIL' => JiffRoundMode.HALF_CEIL,
        'HALF_FLOOR' => JiffRoundMode.HALF_FLOOR,
        'HALF_EXPAND' => JiffRoundMode.HALF_EXPAND,
        'HALF_TRUNC' => JiffRoundMode.HALF_TRUNC,
        'HALF_EVEN' => JiffRoundMode.HALF_EVEN
    };

    // The label of each span unit in a row, and the units from largest to smallest.
    private static final Map<String, JiffUnit> SPAN_UNITS = new Map<String, JiffUnit>{
        'y' => JiffUnit.YEAR,
        'mo' => JiffUnit.MONTH,
        'w' => JiffUnit.WEEK,
        'd' => JiffUnit.DAY,
        'h' => JiffUnit.HOUR,
        'm' => JiffUnit.MINUTE,
        's' => JiffUnit.SECOND,
        'ms' => JiffUnit.MILLISECOND,
        'us' => JiffUnit.MICROSECOND,
        'ns' => JiffUnit.NANOSECOND
    };
    private static final List<String> SPAN_LABELS = new List<String>{
        'y',
        'mo',
        'w',
        'd',
        'h',
        'm',
        's',
        'ms',
        'us',
        'ns'
    };

    private static final Map<String, JiffFriendlyDesignator> DESIGNATORS = new Map<String, JiffFriendlyDesignator>{
        'COMPACT' => JiffFriendlyDesignator.COMPACT,
        'VERBOSE' => JiffFriendlyDesignator.VERBOSE,
        'SHORT_FORM' => JiffFriendlyDesignator.SHORT_FORM,
        'HUMAN_TIME' => JiffFriendlyDesignator.HUMAN_TIME
    };

    private static final Map<String, JiffFriendlySpacing> SPACINGS = new Map<String, JiffFriendlySpacing>{
        'NONE' => JiffFriendlySpacing.NONE,
        'BETWEEN_UNITS' => JiffFriendlySpacing.BETWEEN_UNITS,
        'BETWEEN_UNITS_AND_DESIGNATORS' => JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS
    };

    private static final Map<String, JiffFriendlyDirection> DIRECTIONS = new Map<String, JiffFriendlyDirection>{
        'AUTO' => JiffFriendlyDirection.AUTO,
        'SIGN' => JiffFriendlyDirection.SIGN,
        'FORCE_SIGN' => JiffFriendlyDirection.FORCE_SIGN,
        'SUFFIX' => JiffFriendlyDirection.SUFFIX
    };

    private static final Map<String, JiffFriendlyFractionalUnit> FRACTIONAL_UNITS = new Map<String, JiffFriendlyFractionalUnit>{
        'HOUR' => JiffFriendlyFractionalUnit.HOUR,
        'MINUTE' => JiffFriendlyFractionalUnit.MINUTE,
        'SECOND' => JiffFriendlyFractionalUnit.SECOND,
        'MILLISECOND' => JiffFriendlyFractionalUnit.MILLISECOND,
        'MICROSECOND' => JiffFriendlyFractionalUnit.MICROSECOND
    };

    /** Splits a row into its fields. */
    public static List<String> fields(String row) {
        return row.split('\\|');
    }

    /** The unit with the given enum constant name. */
    public static JiffUnit unit(String name) {
        JiffUnit found = UNITS.get(name);
        Assert.isNotNull(found, 'unknown unit in a vector: ' + name);
        return found;
    }

    /** The rounding mode with the given enum constant name. */
    public static JiffRoundMode mode(String name) {
        JiffRoundMode found = MODES.get(name);
        Assert.isNotNull(found, 'unknown rounding mode in a vector: ' + name);
        return found;
    }

    /** The weekday that is `index` days after Monday. */
    public static JiffWeekday weekday(String index) {
        return WEEKDAYS.get(Integer.valueOf(index));
    }

    /** Reads a date such as `2024-02-29` or `-009999-01-01`. */
    public static JiffDate toDate(String text) {
        // The year may itself start with a minus sign, so the fields are found from the right.
        Integer dayAt = text.lastIndexOf('-');
        String yearAndMonth = text.substring(0, dayAt);
        Integer monthAt = yearAndMonth.lastIndexOf('-');
        return JiffDate.newInstance(
            Integer.valueOf(yearAndMonth.substring(0, monthAt)),
            Integer.valueOf(yearAndMonth.substring(monthAt + 1)),
            Integer.valueOf(text.substring(dayAt + 1))
        );
    }

    /** Reads a time such as `15:45:10` or `15:45:10.000000001`. */
    public static JiffTime toTime(String text) {
        Integer nanosecond = 0;
        if (text.length() > 8) {
            // A fraction has between one and nine digits; pad it out to nanoseconds.
            nanosecond = Integer.valueOf(text.substring(9).rightPad(9, '0'));
        }
        return JiffTime.newInstance(
            Integer.valueOf(text.substring(0, 2)),
            Integer.valueOf(text.substring(3, 5)),
            Integer.valueOf(text.substring(6, 8)),
            nanosecond
        );
    }

    /** Reads a datetime such as `2024-03-10T02:30:00`. */
    public static JiffDateTime toDateTime(String text) {
        Integer timeAt = text.indexOf('T');
        return JiffDateTime.fromParts(
            toDate(text.substring(0, timeAt)),
            toTime(text.substring(timeAt + 1))
        );
    }

    /** Reads a span such as `-1y -2mo`, setting each unit with its named setter. */
    public static JiffSpan toSpan(String text) {
        JiffSpan span = new JiffSpan();
        if (text.equals('0')) {
            return span;
        }
        for (String token : text.split(' ')) {
            // The label is whatever follows the sign and the digits.
            Integer labelAt = token.startsWith('-') ? 1 : 0;
            while (token.substring(labelAt, labelAt + 1).isNumeric()) {
                labelAt++;
            }
            Long value = Long.valueOf(token.substring(0, labelAt));
            span = setUnit(span, token.substring(labelAt), value);
        }
        return span;
    }

    /** Sets one unit of a span through its named setter; `label` is as in a row (`mo`, `us`). */
    public static JiffSpan setUnit(JiffSpan span, String label, Long value) {
        if (label.equals('y')) {
            return span.years(value);
        } else if (label.equals('mo')) {
            return span.months(value);
        } else if (label.equals('w')) {
            return span.weeks(value);
        } else if (label.equals('d')) {
            return span.days(value);
        } else if (label.equals('h')) {
            return span.hours(value);
        } else if (label.equals('m')) {
            return span.minutes(value);
        } else if (label.equals('s')) {
            return span.seconds(value);
        } else if (label.equals('ms')) {
            return span.milliseconds(value);
        } else if (label.equals('us')) {
            return span.microseconds(value);
        }
        Assert.areEqual('ns', label, 'unknown span unit in a vector');
        return span.nanoseconds(value);
    }

    /** Writes a span the way the vectors do. */
    public static String spanText(JiffSpan span) {
        List<String> tokens = new List<String>();
        for (String label : SPAN_LABELS) {
            Long value = span.get(SPAN_UNITS.get(label));
            if (value != 0) {
                tokens.add(value + label);
            }
        }
        return tokens.isEmpty() ? '0' : String.join(tokens, ' ');
    }

    /**
     * Reads a parser input. The empty string cannot be a field of a row, so the vectors spell
     * it `<empty>`.
     */
    public static String toInput(String text) {
        return text.equals('<empty>') ? '' : text;
    }

    /**
     * Builds a friendly printer from the settings that differ from the default, written as
     * `designator=VERBOSE;comma=1;precision=3`, or `default` for none.
     */
    public static JiffFriendlyPrinter toPrinter(String settings) {
        JiffFriendlyPrinter printer = new JiffFriendlyPrinter();
        if (settings.equals('default')) {
            return printer;
        }
        for (String setting : settings.split(';')) {
            List<String> parts = setting.split('=');
            String name = parts.get(0);
            String value = parts.get(1);
            if (name.equals('designator')) {
                printer = printer.designator(DESIGNATORS.get(value));
            } else if (name.equals('spacing')) {
                printer = printer.spacing(SPACINGS.get(value));
            } else if (name.equals('direction')) {
                printer = printer.direction(DIRECTIONS.get(value));
            } else if (name.equals('fractional')) {
                printer = printer.fractional(FRACTIONAL_UNITS.get(value));
            } else if (name.equals('comma')) {
                printer = printer.commaAfterDesignator(value.equals('1'));
            } else if (name.equals('hms')) {
                printer = printer.hoursMinutesSeconds(value.equals('1'));
            } else if (name.equals('padding')) {
                printer = printer.padding(Integer.valueOf(value));
            } else if (name.equals('precision')) {
                printer = printer.precision(Integer.valueOf(value));
            } else {
                Assert.areEqual('zero', name, 'unknown printer setting in a vector');
                printer = printer.zeroUnit(unit(value));
            }
        }
        return printer;
    }

    /** Reads a duration written as `seconds,nanoseconds`. */
    public static JiffSignedDuration toDuration(String text) {
        List<String> parts = text.split(',');
        return JiffSignedDuration.newInstance(
            Long.valueOf(parts.get(0)),
            Integer.valueOf(parts.get(1))
        );
    }

    /** Writes a duration the way the vectors do. */
    public static String durationText(JiffSignedDuration value) {
        return value.asSecs() + ',' + value.subsecNanos();
    }

    /** Reads a timestamp written as `seconds,nanoseconds` since the Unix epoch. */
    public static JiffTimestamp toTimestamp(String text) {
        List<String> parts = text.split(',');
        return JiffTimestamp.newInstance(Long.valueOf(parts.get(0)), Integer.valueOf(parts.get(1)));
    }

    /** Writes a timestamp the way the vectors do. */
    public static String timestampText(JiffTimestamp value) {
        return value.asSecond() + ',' + value.subsecNanosecond();
    }

    /** Reads an ISO week date written as `year,week,weekday`. */
    public static JiffIsoWeekDate toWeekDate(String text) {
        List<String> parts = text.split(',');
        return JiffIsoWeekDate.newInstance(
            Integer.valueOf(parts.get(0)),
            Integer.valueOf(parts.get(1)),
            weekday(parts.get(2))
        );
    }

    /** Writes an ISO week date the way the vectors do. */
    public static String weekDateText(JiffIsoWeekDate value) {
        return value.year() + ',' + value.week() + ',' + value.weekday().ordinal();
    }
}
