/**
 * The datetime entry points of `JiffTemporal`, and `parse(String)` on the types that use them.
 *
 * The cases are the examples in the doc comments of `jiff::fmt::temporal` and of
 * `DateTimeParser::parse_timestamp`, `parse_datetime`, `parse_date`, `parse_time`,
 * `parse_time_zone` and `parse_pieces` (`fmt/temporal/mod.rs`). Where a doc example only says
 * that parsing fails, the message is the one Jiff 1.0.0 produces for that input. The exhaustive
 * tables are in `JiffTemporalParserTest`.
 */
@IsTest
private class JiffTemporalDateTimeTest {
    private static final String ZULU_ERROR =
        'cannot parse civil date/time from string with a Zulu offset, ' +
        'parse as a `jiff::Timestamp` first and convert to a civil date/time instead';

    private static void assertZuluRejected(String kind, String text) {
        try {
            if (kind.equals('date')) {
                JiffDate.parse(text);
            } else if (kind.equals('datetime')) {
                JiffDateTime.parse(text);
            } else {
                JiffTime.parse(text);
            }
            Assert.fail('expected a Zulu offset to be rejected: ' + text);
        } catch (JiffException e) {
            Assert.areEqual(ZULU_ERROR, e.getMessage(), text);
        }
    }

    @IsTest
    static void aSmallerTypeParsesFromAStringForABiggerOne() {
        // The module documentation: `2020-08-21T02:21:58` and `2020-08-21 02:21:58` both parse
        // into a civil datetime, `2020-08-21T02:21:58-04` into a timestamp, and a date can be
        // parsed from `2020-08-21T02:21:58`.
        JiffDateTime expected = JiffDateTime.newInstance(2020, 8, 21, 2, 21, 58, 0);
        Assert.areEqual(expected, JiffDateTime.parse('2020-08-21T02:21:58'));
        Assert.areEqual(expected, JiffDateTime.parse('2020-08-21 02:21:58'));
        Assert.areEqual(
            '2020-08-21T06:21:58Z',
            JiffTimestamp.parse('2020-08-21T02:21:58-04').toString()
        );
        Assert.areEqual(JiffDate.newInstance(2020, 8, 21), JiffDate.parse('2020-08-21T02:21:58'));
        // "`2024-06-16T10.5` is a valid ISO 8601 datetime, but isn't supported by Jiff."
        try {
            JiffDateTime.parse('2024-06-16T10.5');
            Assert.fail('expected a fractional hour to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsed value \'2024-06-16T10:00:00\', but unparsed input ".5" remains ' +
                '(expected no unparsed input)',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void aTimestampParsesFromAnOffsetOrAZonedString() {
        // The examples on `DateTimeParser::parse_timestamp`.
        Assert.areEqual(
            '2024-03-10T06:05:00Z',
            JiffTemporal.parseTimestamp('2024-03-10T02:05-04').toString()
        );
        Assert.areEqual(
            '2024-03-10T06:05:00Z',
            JiffTimestamp.parse('2024-03-10T02:05-04[America/New_York]').toString()
        );
        Assert.areEqual(
            JiffTimestamp.fromSecond(1710050700L),
            JiffTimestamp.parse('2024-03-10T02:05-04')
        );
    }

    @IsTest
    static void aCivilDatetimeParsesAndRejectsZulu() {
        // The examples on `DateTimeParser::parse_datetime`.
        JiffDateTime expected = JiffDateTime.newInstance(2024, 3, 10, 2, 5, 0, 0);
        Assert.areEqual(expected, JiffTemporal.parseDateTime('2024-03-10T02:05'));
        assertZuluRejected('datetime', '2024-03-10T02:05Z');
        // Note though that -00 and +00 offsets parse successfully.
        Assert.areEqual(expected, JiffDateTime.parse('2024-03-10T02:05+00'));
        Assert.areEqual(expected, JiffDateTime.parse('2024-03-10T02:05-00'));
    }

    @IsTest
    static void aCivilDateParsesAndRejectsZulu() {
        // The examples on `DateTimeParser::parse_date`.
        JiffDate expected = JiffDate.newInstance(2024, 3, 10);
        Assert.areEqual(expected, JiffTemporal.parseDate('2024-03-10'));
        assertZuluRejected('date', '2024-03-10T00:00:00Z');
        Assert.areEqual(expected, JiffDate.parse('2024-03-10T00:00:00+00'));
        Assert.areEqual(expected, JiffDate.parse('2024-03-10T00:00:00-00'));
    }

    @IsTest
    static void aCivilTimeParsesAndRejectsZulu() {
        // The examples on `DateTimeParser::parse_time`.
        JiffTime expected = JiffTime.newInstance(2, 5, 0, 0);
        Assert.areEqual(expected, JiffTemporal.parseTime('02:05'));
        assertZuluRejected('time', '02:05Z');
        Assert.areEqual(expected, JiffTime.parse('02:05+00'));
        Assert.areEqual(expected, JiffTime.parse('02:05-00'));
    }

    @IsTest
    static void aTimeZoneParsesFromAnOffsetOrAName() {
        // The examples on `DateTimeParser::parse_time_zone`, less the POSIX time zone, which
        // this port does not have.
        Assert.areEqual(
            JiffTimeZone.fixed(JiffOffset.fromHours(-5)),
            JiffTemporal.parseTimeZone('-05:00')
        );
        Assert.areEqual(
            JiffTimeZone.fixed(JiffOffset.fromSeconds(5 * 60 * 60 + 1)),
            JiffTemporal.parseTimeZone('+05:00:01')
        );
        Assert.areEqual(
            JiffTimeZone.get('America/New_York'),
            JiffTemporal.parseTimeZone('America/New_York')
        );
        Assert.areEqual(
            JiffTimeZone.get('Asia/Jerusalem'),
            JiffTemporal.parseTimeZone('Asia/Jerusalem')
        );
        // Some error cases, with the messages Jiff gives for them.
        List<String> rows = new List<String>{
            'Z => parsed apparent IANA time zone identifier, but the tzdb lookup failed: failed to find time zone `Z` in time zone database',
            '05:00 => parsed apparent IANA time zone identifier, but the tzdb lookup failed: failed to find time zone `05:00` in time zone database',
            '+05:00:01.5 => subsecond precision for UTC numeric offset is not enabled in this context (must provide only integral minutes or seconds)',
            'Does/Not/Exist => parsed apparent IANA time zone identifier, but the tzdb lookup failed: failed to find time zone `Does/Not/Exist` in time zone database'
        };
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            try {
                JiffTemporal.parseTimeZone(row.substring(0, at));
                Assert.fail('expected a time zone parse error: ' + row);
            } catch (JiffException e) {
                Assert.areEqual(row.substring(at + 4), e.getMessage(), row);
            }
        }
    }

    @IsTest
    static void piecesParseWhatTheStricterTypesReject() {
        // The examples on `DateTimeParser::parse_pieces`.
        try {
            JiffTemporal.parseDate('2024-03-10T00:00:00Z');
            Assert.fail('expected a Zulu offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(ZULU_ERROR, e.getMessage());
        }
        JiffPieces pieces = JiffTemporal.parsePieces('2024-03-10T00:00:00Z');
        Assert.areEqual(JiffDate.newInstance(2024, 3, 10), pieces.toDate());
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 0), pieces.toTime());
        Assert.areEqual(JiffOffset.UTC, pieces.toNumericOffset());
        Assert.isNull(pieces.toTimeZone());

        // A fixed offset timestamp has no time zone annotation, but its pieces say enough to
        // pick a fixed offset zone.
        JiffPieces fixed = JiffTemporal.parsePieces('2025-01-02T15:13-05');
        Assert.isNull(fixed.toTimeZone());
        Assert.areEqual(JiffOffset.fromHours(-5), fixed.toNumericOffset());
        Assert.areEqual(JiffDate.newInstance(2025, 1, 2), fixed.toDate());
        Assert.areEqual(JiffTime.newInstance(15, 13, 0, 0), fixed.toTime());
    }

    @IsTest
    static void aWeekDateParsesInEitherFormatAndCase() {
        // `2024-W10-6` is the Saturday of week 10, as in the `ISOWeekDate` documentation.
        JiffIsoWeekDate expected = JiffIsoWeekDate.newInstance(2024, 10, JiffWeekday.SATURDAY);
        Assert.areEqual(expected, JiffIsoWeekDate.parse('2024-W10-6'));
        Assert.areEqual(expected, JiffIsoWeekDate.parse('2024W106'));
        Assert.areEqual(expected, JiffIsoWeekDate.parse('2024-w10-6'));
        Assert.areEqual(expected, JiffTemporal.parseIsoWeekDate('+002024-W10-6'));
        Assert.areEqual('2024-W10-6', expected.toString());
        Assert.areEqual('2024-W10-6', JiffTemporal.printIsoWeekDate(expected));
    }

    @IsTest
    static void everyValuePrintedCanBeParsedBack() {
        List<JiffDate> dates = new List<JiffDate>{
            JiffDate.MIN,
            JiffDate.MAX,
            JiffDate.ZERO,
            JiffDate.newInstance(-1, 12, 31),
            JiffDate.newInstance(2024, 2, 29)
        };
        for (JiffDate value : dates) {
            Assert.areEqual(value, JiffDate.parse(value.toString()), value.toString());
            JiffIsoWeekDate week = JiffIsoWeekDate.fromDate(value);
            Assert.areEqual(week, JiffIsoWeekDate.parse(week.toString()), week.toString());
        }
        List<JiffTime> times = new List<JiffTime>{
            JiffTime.MIN,
            JiffTime.MAX,
            JiffTime.newInstance(12, 14, 0, 0),
            JiffTime.newInstance(1, 2, 3, 1),
            JiffTime.newInstance(23, 59, 59, 120000000)
        };
        for (JiffTime value : times) {
            Assert.areEqual(value, JiffTime.parse(value.toString()), value.toString());
        }
        List<JiffDateTime> datetimes = new List<JiffDateTime>{
            JiffDateTime.MIN,
            JiffDateTime.MAX,
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 500)
        };
        for (JiffDateTime value : datetimes) {
            Assert.areEqual(value, JiffDateTime.parse(value.toString()), value.toString());
        }
        List<JiffTimestamp> timestamps = new List<JiffTimestamp>{
            JiffTimestamp.MIN,
            JiffTimestamp.MAX,
            JiffTimestamp.UNIX_EPOCH,
            JiffTimestamp.newInstance(-1L, -1),
            JiffTimestamp.newInstance(1720493204L, 123456789)
        };
        for (JiffTimestamp value : timestamps) {
            Assert.areEqual(value, JiffTimestamp.parse(value.toString()), value.toString());
            Assert.areEqual(
                value,
                JiffTimestamp.parse(value.toStringWithOffset(JiffOffset.fromSeconds(19800))),
                value.toString()
            );
        }
        List<JiffTimeZone> zones = new List<JiffTimeZone>{
            JiffTimeZone.UTC,
            JiffTimeZone.unknown(),
            JiffTimeZone.get('Europe/London'),
            JiffTimeZone.fixed(JiffOffset.fromSeconds(-2670)),
            JiffTimeZone.fixed(JiffOffset.MAX),
            JiffTimeZone.fixed(JiffOffset.MIN)
        };
        for (JiffTimeZone zone : zones) {
            String printed = JiffTemporal.printTimeZone(zone);
            Assert.areEqual(zone, JiffTemporal.parseTimeZone(printed), printed);
        }
    }
}
