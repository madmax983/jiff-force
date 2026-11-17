/**
 * `JiffTemporalParsed`: the components of a datetime string and the conversions that decide
 * what they become.
 *
 * The expected values are what Jiff 1.0.0 gives for the same string through
 * `DateTimeParser::parse_date`, `parse_datetime`, `parse_timestamp` and `parse_pieces`, each
 * of which is `parse_temporal_datetime` followed by one of these conversions. The written-back
 * forms are what Jiff quotes in its "unparsed input remains" error.
 */
@IsTest
private class JiffTemporalParsedTest {
    private static final JiffDate JUNE_19 = JiffDate.newInstance(2024, 6, 19);
    private static final JiffTime AFTERNOON = JiffTime.newInstance(15, 22, 45, 0);
    private static final String ZULU_ERROR =
        'cannot parse civil date/time from string with a Zulu offset, ' +
        'parse as a `jiff::Timestamp` first and convert to a civil date/time instead';

    @IsTest
    static void aDateAloneHasNoOtherParts() {
        JiffTemporalParsed parsed = JiffTemporal.parseParts('2024-06-19');
        Assert.areEqual(JUNE_19, parsed.civilDate());
        Assert.isNull(parsed.civilTime());
        Assert.areEqual(JiffTime.midnight(), parsed.civilTimeOrMidnight());
        Assert.isNull(parsed.offset());
        Assert.isNull(parsed.timeZoneAnnotation());
        Assert.areEqual(JUNE_19, parsed.toDate());
        Assert.areEqual(JiffDateTime.newInstance(2024, 6, 19, 0, 0, 0, 0), parsed.toDateTime());
        Assert.areEqual(JiffPieces.fromDate(JUNE_19), parsed.toPieces());
        Assert.areEqual('2024-06-19', parsed.toString());
    }

    @IsTest
    static void everyPartOfAFullStringIsAvailable() {
        JiffTemporalParsed parsed = JiffTemporal.parseParts(
            '2024-06-19T15:22:45-04:00[America/New_York]'
        );
        Assert.areEqual(JUNE_19, parsed.civilDate());
        Assert.areEqual(AFTERNOON, parsed.civilTime());
        Assert.areEqual(AFTERNOON, parsed.civilTimeOrMidnight());
        Assert.areEqual(JiffOffset.fromHours(-4), parsed.offset().toOffset());
        Assert.isFalse(parsed.offset().isZulu());
        Assert.isFalse(parsed.offset().hasSubminute());
        Assert.areEqual(
            JiffPiecesTimeZoneAnnotation.fromName('America/New_York'),
            parsed.timeZoneAnnotation()
        );
        // A civil type ignores the offset and the annotation.
        Assert.areEqual(JUNE_19, parsed.toDate());
        Assert.areEqual(JiffDateTime.fromParts(JUNE_19, AFTERNOON), parsed.toDateTime());
        // A timestamp uses the offset and ignores the annotation.
        Assert.areEqual('2024-06-19T19:22:45Z', parsed.toTimestamp().toString());
        Assert.areEqual(
            '2024-06-19T15:22:45-04:00[America/New_York]',
            parsed.toPieces().toString()
        );
    }

    @IsTest
    static void aTimestampIgnoresAnAnnotationThatDisagreesWithTheOffset() {
        // The second example on `DateTimeParser::parse_timestamp`, and the same string with a
        // zone that is never at -04.
        Assert.areEqual(
            '2024-03-10T06:05:00Z',
            JiffTemporal.parseParts('2024-03-10T02:05-04[America/New_York]')
                .toTimestamp()
                .toString()
        );
        Assert.areEqual(
            '2024-03-10T06:05:00Z',
            JiffTemporal.parseParts('2024-03-10T02:05-04[America/Los_Angeles]')
                .toTimestamp()
                .toString()
        );
    }

    @IsTest
    static void aTimestampNeedsATimeAndAnOffset() {
        try {
            JiffTemporal.parseParts('2024-06-19').toTimestamp();
            Assert.fail('expected a date without a time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time component, which is required for parsing a timestamp',
                e.getMessage()
            );
        }
        try {
            JiffTemporal.parseParts('2024-06-19T15:22:45[America/New_York]').toTimestamp();
            Assert.fail('expected a datetime without an offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find offset component, which is required for parsing a timestamp',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void aTimestampOutOfRangeSaysWhichOffsetWasUsed() {
        try {
            JiffTemporal.parseParts('-009999-01-01T00:00:00+02:00').toTimestamp();
            Assert.fail('expected an instant before the minimum to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to convert civil datetime to timestamp with offset +02: ' +
                    'converting datetime with time zone offset `+02` to timestamp overflowed: ' +
                    'parameter \'Unix timestamp seconds\' is not in the required range of ' +
                    '-377705023201..=253402207200',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void aZuluOffsetIsRejectedByTheCivilConversionsOnly() {
        JiffTemporalParsed parsed = JiffTemporal.parseParts('2024-03-10T00:00:00Z');
        Assert.isTrue(parsed.offset().isZulu());
        try {
            parsed.toDate();
            Assert.fail('expected a Zulu offset to be rejected for a date');
        } catch (JiffException e) {
            Assert.areEqual(ZULU_ERROR, e.getMessage());
        }
        try {
            parsed.toDateTime();
            Assert.fail('expected a Zulu offset to be rejected for a datetime');
        } catch (JiffException e) {
            Assert.areEqual(ZULU_ERROR, e.getMessage());
        }
        // The raw parts, the pieces and the timestamp are all still there. This is the
        // example on `DateTimeParser::parse_pieces`.
        Assert.areEqual(JiffDate.newInstance(2024, 3, 10), parsed.civilDate());
        JiffPieces pieces = parsed.toPieces();
        Assert.areEqual(JiffDate.newInstance(2024, 3, 10), pieces.toDate());
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 0), pieces.toTime());
        Assert.areEqual(JiffOffset.UTC, pieces.toNumericOffset());
        Assert.isNull(pieces.toTimeZone());
        Assert.areEqual('2024-03-10T00:00:00Z', parsed.toTimestamp().toString());
    }

    @IsTest
    static void rejectZuluPassesEverythingButZulu() {
        JiffTemporalParsedOffset none = null;
        JiffTemporalParsed.rejectZulu(none);
        JiffTemporalParsed.rejectZulu(JiffTemporalParsedOffset.numeric(true, 0));
        JiffTemporalParsed.rejectZulu(JiffTemporalParsedOffset.numeric(false, 5));
        try {
            JiffTemporalParsed.rejectZulu(JiffTemporalParsedOffset.zulu());
            Assert.fail('expected a Zulu offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(ZULU_ERROR, e.getMessage());
        }
    }

    @IsTest
    static void theOffsetRemembersWhetherSecondsWereWritten() {
        Assert.isTrue(
            JiffTemporal.parseParts('2024-06-19T15:22:45+05:30:00').offset().hasSubminute()
        );
        Assert.isFalse(
            JiffTemporal.parseParts('2024-06-19T15:22:45+05:30').offset().hasSubminute()
        );
    }

    @IsTest
    static void theAnnotationKeepsItsKindAndItsCriticalFlag() {
        JiffPiecesTimeZoneAnnotation ann = JiffTemporal.parseParts('2024-06-19[!-04:30]')
            .timeZoneAnnotation();
        Assert.areEqual(JiffPiecesTimeZoneAnnotationKind.OFFSET, ann.kind());
        Assert.areEqual(JiffOffset.fromSeconds(-16200), ann.offset());
        Assert.isTrue(ann.isCritical());
        // Annotations other than the time zone are checked and dropped.
        Assert.isNull(JiffTemporal.parseParts('2024-06-19[u-ca=gregory]').timeZoneAnnotation());
    }

    @IsTest
    static void theParsedValueIsWrittenBackAsJiffEchoesIt() {
        // `input => echoed`: the value Jiff quotes in "parsed value '<echoed>', but unparsed
        // input "junk" remains" for `<input>junk`.
        List<String> rows = new List<String>{
            '2024-06-19 => 2024-06-19',
            '20240619 => 2024-06-19',
            '2024-06-19T15 => 2024-06-19T15:00:00',
            '2024-06-19 15:22:45.5 => 2024-06-19T15:22:45.5',
            '2024-06-19T15:22:45+04:00 => 2024-06-19T15:22:45+04:00',
            '2024-06-19T15:22:45Z => 2024-06-19T15:22:45Z',
            '2024-06-19T15:22:45[America/New_York] => 2024-06-19T15:22:45[America/New_York]',
            '2024-06-19T15:22:45-04[-04] => 2024-06-19T15:22:45-04[-04]',
            '2024-06-19T15:22:45-04[!-04:30] => 2024-06-19T15:22:45-04[!-04:30]',
            '2024-06-19T15:22:45-0400[-0400] => 2024-06-19T15:22:45-04:00[-04:00]',
            '2024-06-19T15:22:45.5-04:30:15.25[!Europe/Paris][u-ca=iso8601] => 2024-06-19T15:22:45.5-04:30:15.25[!Europe/Paris]',
            '2024-06-19[u-ca=iso8601] => 2024-06-19'
        };
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            Assert.areEqual(
                row.substring(at + 4),
                JiffTemporal.parseParts(row.substring(0, at)).toString(),
                row
            );
        }
    }
}
