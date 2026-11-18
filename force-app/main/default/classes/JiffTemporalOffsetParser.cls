/**
 * A parser for UTC offsets: `Z`, `-05`, `+05:30`, `-0530`, `+05:30:15`, `-00:44:30.5`.
 * Internal: the datetime parsers in `JiffTemporalParser` use it, and it is configurable so
 * that the other formats (`strptime`'s `%z`, RFC 9557 annotations) can use it too.
 *
 * The general form is a sign, two digit hours, and then optionally minutes, seconds and a
 * fraction of a second: `{+,-}HH[:MM[:SS[.fffffffff]]]`. The colons may be left out
 * (`-053015`), which is ISO 8601's basic format, but one offset may not mix the two styles.
 *
 * Parsing stops at the first character that cannot continue the offset, and what is left is
 * for the caller. So `-0512:34` parses as `-05:12` and leaves `:34` behind.
 *
 * The options, with their defaults:
 *
 * - `zulu(true)`: accept `Z` and `z`.
 * - `requireMinute(false)`: fail when the minutes are missing.
 * - `requireSecond(false)`: fail when the seconds are missing.
 * - `subminute(true)`: accept seconds. When false, a `:` after the minutes is an error.
 * - `subsecond(true)`: accept a fraction of a second. When false, a `.` or `,` after the
 *   seconds is an error.
 * - `colon(OPTIONAL)`: see `JiffTemporalOffsetColon`.
 *
 * Instances are immutable; each option method returns a new parser. A null option, and a
 * null scanner, are rejected with a `JiffException`.
 *
 * Mirrors `jiff::fmt::offset::Parser`.
 */
public class JiffTemporalOffsetParser {
    private static final String OPTION_IS_NULL = 'an option of the UTC offset parser must not be null';

    private final Boolean allowZulu;
    private final Boolean needMinute;
    private final Boolean needSecond;
    private final Boolean allowSubminute;
    private final Boolean allowSubsecond;
    private final JiffTemporalOffsetColon colonRule;

    /** A parser with the default options. */
    public JiffTemporalOffsetParser() {
        this(true, false, false, true, true, JiffTemporalOffsetColon.OPTIONAL);
    }

    private JiffTemporalOffsetParser(
        Boolean allowZulu,
        Boolean needMinute,
        Boolean needSecond,
        Boolean allowSubminute,
        Boolean allowSubsecond,
        JiffTemporalOffsetColon colonRule
    ) {
        this.allowZulu = allowZulu;
        this.needMinute = needMinute;
        this.needSecond = needSecond;
        this.allowSubminute = allowSubminute;
        this.allowSubsecond = allowSubsecond;
        this.colonRule = colonRule;
    }

    /** Whether `Z` and `z` are accepted. When they are not, finding one is an error. */
    public JiffTemporalOffsetParser zulu(Boolean yes) {
        if (yes == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            yes,
            needMinute,
            needSecond,
            allowSubminute,
            allowSubsecond,
            colonRule
        );
    }

    /** Whether the minutes component is required. */
    public JiffTemporalOffsetParser requireMinute(Boolean yes) {
        if (yes == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            allowZulu,
            yes,
            needSecond,
            allowSubminute,
            allowSubsecond,
            colonRule
        );
    }

    /**
     * Whether the seconds component (and so the minutes too) is required. Has no effect when
     * `subminute` is off.
     */
    public JiffTemporalOffsetParser requireSecond(Boolean yes) {
        if (yes == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            allowZulu,
            needMinute,
            yes,
            allowSubminute,
            allowSubsecond,
            colonRule
        );
    }

    /**
     * Whether offsets more precise than a minute are accepted. When off, `subsecond` is
     * ignored.
     */
    public JiffTemporalOffsetParser subminute(Boolean yes) {
        if (yes == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            allowZulu,
            needMinute,
            needSecond,
            yes,
            allowSubsecond,
            colonRule
        );
    }

    /**
     * Whether a fraction of a second is accepted. The fraction only ever rounds the offset to
     * the nearest second, since a `JiffOffset` has whole seconds.
     */
    public JiffTemporalOffsetParser subsecond(Boolean yes) {
        if (yes == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            allowZulu,
            needMinute,
            needSecond,
            allowSubminute,
            yes,
            colonRule
        );
    }

    /** How colons between the components are treated. See `JiffTemporalOffsetColon`. */
    public JiffTemporalOffsetParser colon(JiffTemporalOffsetColon rule) {
        if (rule == null) {
            throw new JiffException(OPTION_IS_NULL);
        }
        return new JiffTemporalOffsetParser(
            allowZulu,
            needMinute,
            needSecond,
            allowSubminute,
            allowSubsecond,
            rule
        );
    }

    /**
     * Parses an offset at the scanner's position and leaves the scanner just after it.
     * Throws `JiffException` when there is no valid offset there.
     */
    public JiffTemporalParsedOffset parse(JiffDurationScanner scanner) {
        if (scanner == null) {
            throw new JiffException('cannot parse a UTC offset without input');
        }
        if (scanner.isDone()) {
            throw new JiffException('expected UTC offset, but found end of input');
        }
        Integer first = scanner.peek();
        if (first == 90 || first == 122) {
            if (!allowZulu) {
                throw new JiffException(
                    'found `' +
                        scanner.describeNext() +
                        '` where a numeric UTC offset was expected ' +
                        '(this context does not permit the Zulu offset)'
                );
            }
            scanner.advance(1);
            return JiffTemporalParsedOffset.zulu();
        }
        return parseNumeric(scanner);
    }

    /**
     * Like `parse`, but returns null (consuming nothing) when the next character cannot start
     * an offset: that is, at the end of the input, or when it is not one of `Z`, `z`, `+`
     * or `-`.
     */
    public JiffTemporalParsedOffset parseOptional(JiffDurationScanner scanner) {
        if (scanner == null) {
            throw new JiffException('cannot parse a UTC offset without input');
        }
        Integer first = scanner.peek();
        if (first != 90 && first != 122 && first != 43 && first != 45) {
            return null;
        }
        return parse(scanner);
    }

    private JiffTemporalParsedOffset parseNumeric(JiffDurationScanner scanner) {
        Boolean negative = scanner.peek() == 45;
        if (!negative && scanner.peek() != 43) {
            throw new JiffException(
                'failed to parse sign in UTC numeric offset: ' +
                'expected `+` or `-` sign at start of UTC numeric offset'
            );
        }
        scanner.advance(1);

        Integer hours = JiffTemporalParser.digits(
            scanner,
            2,
            'failed to parse hours in UTC numeric offset: ' +
            'expected two digit hour after sign, but found end of input',
            'failed to parse hours in UTC numeric offset: ' +
            'failed to parse hours (requires a two digit integer)',
            'time zone offset hours',
            -25,
            25
        );
        JiffTemporalParsedOffset offset = JiffTemporalParsedOffset.numeric(negative, hours);
        Boolean extended = false;
        if (colonRule == JiffTemporalOffsetColon.OPTIONAL) {
            extended = scanner.peek() == 58;
        } else if (colonRule == JiffTemporalOffsetColon.REQUIRED) {
            if (!scanner.isDone() && scanner.peek() != 58) {
                throw new JiffException(
                    'parsed hour component of time zone offset, ' +
                    'but could not find required colon separator'
                );
            }
            extended = true;
        } else if (scanner.peek() == 58) {
            throw new JiffException(
                'parsed hour component of time zone offset, ' +
                'but found colon after hours which is not allowed'
            );
        }

        if (!hasNextComponent(scanner, extended)) {
            if (needMinute || (allowSubminute && needSecond)) {
                throw new JiffException(
                    'parsed hour component of time zone offset, ' +
                    'but could not find required minute component'
                );
            }
            return offset;
        }
        offset = offset.withMinutes(
            JiffTemporalParser.digits(
                scanner,
                2,
                'failed to parse minutes in UTC numeric offset: ' +
                'expected two digit minute after hours, but found end of input',
                'failed to parse minutes in UTC numeric offset: ' +
                'failed to parse minutes (requires a two digit integer)',
                'time zone offset minutes',
                -59,
                59
            )
        );
        if (!allowSubminute) {
            // A colon here almost certainly means more precision than this context supports,
            // so say that instead of leaving the colon for the caller to trip over.
            if (scanner.peek() == 58) {
                throw new JiffException(
                    'subminute precision for UTC numeric offset is not enabled ' +
                    'in this context (must provide only integral minutes)'
                );
            }
            return offset;
        }

        if (!hasNextComponent(scanner, extended)) {
            if (needSecond) {
                throw new JiffException(
                    'parsed hour and minute components of time zone offset, ' +
                    'but could not find required second component'
                );
            }
            return offset;
        }
        offset = offset.withSeconds(
            JiffTemporalParser.digits(
                scanner,
                2,
                'failed to parse seconds in UTC numeric offset: ' +
                'expected two digit second after minutes, but found end of input',
                'failed to parse seconds in UTC numeric offset: ' +
                'failed to parse seconds (requires a two digit integer)',
                'time zone offset seconds',
                -59,
                59
            )
        );
        if (!allowSubsecond) {
            if (scanner.peek() == 46 || scanner.peek() == 44) {
                throw new JiffException(
                    'subsecond precision for UTC numeric offset is not enabled ' +
                    'in this context (must provide only integral minutes or seconds)'
                );
            }
            return offset;
        }

        Integer nanoseconds = JiffTemporalParser.fraction(
            scanner,
            'failed to parse fractional seconds in UTC numeric offset'
        );
        return nanoseconds < 0 ? offset : offset.withNanoseconds(nanoseconds);
    }

    /**
     * Whether another component follows, consuming the colon that introduces it in the
     * extended format. In the basic format there is no separator, so another component follows
     * exactly when the next two characters are digits.
     */
    private static Boolean hasNextComponent(JiffDurationScanner scanner, Boolean extended) {
        return extended ? scanner.eat(58) : JiffTemporalParser.atTwoDigits(scanner);
    }
}
