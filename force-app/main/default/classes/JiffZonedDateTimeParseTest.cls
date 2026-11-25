/**
 * Expected values are real Jiff 1.0.0 output for `"...".parse::<ZonedDateTime>()`.
 */
@IsTest
private class JiffZonedDateTimeParseTest {
    // input|what Jiff prints for the result
    private static final List<String> ACCEPTED = new List<String>{
        '2024-07-04T08:39:00-04:00[America/New_York]|2024-07-04T08:39:00-04:00[America/New_York]',
        '2024-07-04T08:39:00[America/New_York]|2024-07-04T08:39:00-04:00[America/New_York]',
        '2024-07-04[America/New_York]|2024-07-04T00:00:00-04:00[America/New_York]',
        '2024-07-04T12:39:00Z[America/New_York]|2024-07-04T08:39:00-04:00[America/New_York]',
        // A gap with no offset: compatible resolution moves forward by the gap.
        '2024-03-10T02:30:00[America/New_York]|2024-03-10T03:30:00-04:00[America/New_York]',
        // A fold: with no offset the earlier reading, otherwise the one the offset names.
        '2024-11-03T01:30:00[America/New_York]|2024-11-03T01:30:00-04:00[America/New_York]',
        '2024-11-03T01:30:00-04:00[America/New_York]|2024-11-03T01:30:00-04:00[America/New_York]',
        '2024-11-03T01:30:00-05:00[America/New_York]|2024-11-03T01:30:00-05:00[America/New_York]',
        // Monrovia was 44 minutes 30 seconds behind UTC; text to the minute says -00:45.
        '1970-06-01T00:00:00-00:45[Africa/Monrovia]|1970-06-01T00:00:00-00:45[Africa/Monrovia]',
        '1970-06-01T00:00:00-00:44:30[Africa/Monrovia]|1970-06-01T00:00:00-00:45[Africa/Monrovia]',
        '2024-07-04T08:39:00.123456789+01:00[Europe/London]|2024-07-04T08:39:00.123456789+01:00[Europe/London]',
        '2024-07-04T08:39:00+05:30[+05:30]|2024-07-04T08:39:00+05:30[+05:30]',
        '2024-07-04T08:39:00[UTC]|2024-07-04T08:39:00+00:00[UTC]',
        '2024-07-04T08:39:00[!America/New_York][u-ca=iso8601]|2024-07-04T08:39:00-04:00[America/New_York]'
    };

    // input|the error Jiff reports
    private static final List<String> REJECTED = new List<String>{
        '2024-07-04T08:39:00-05:00[America/New_York]|datetime could not resolve to a timestamp since `reject` conflict resolution was chosen, and because datetime has offset `-05`, but the time zone `America/New_York` for the given datetime unambiguously has offset `-04`',
        '2024-03-10T02:30:00-05:00[America/New_York]|datetime could not resolve to timestamp since `reject` conflict resolution was chosen, and because datetime has offset `-05`, but the time zone `America/New_York` for the given datetime falls in a gap (between offsets `-05` and `-04`), and all offsets for a gap are regarded as invalid',
        '1970-06-01T00:00:00-00:44[Africa/Monrovia]|datetime could not resolve to a timestamp since `reject` conflict resolution was chosen, and because datetime has offset `-00:44`, but the time zone `Africa/Monrovia` for the given datetime unambiguously has offset `-00:44:30`',
        '2024-07-04T08:39:00-04:00[-05:00]|datetime could not resolve to a timestamp since `reject` conflict resolution was chosen, and because datetime has offset `-04`, but the time zone `-05` for the given datetime unambiguously has offset `-05`',
        '2024-07-04T08:39:00-04:00|failed to find time zone annotation in square brackets, which is required for parsing a zoned datetime',
        '2024-07-04T08:39:00Z|failed to find time zone annotation in square brackets, which is required for parsing a zoned datetime'
    };

    @IsTest
    static void parsesWhatJiffParses() {
        for (String row : ACCEPTED) {
            List<String> f = row.split('\\|');
            Assert.areEqual(
                f.get(1),
                JiffZonedDateTime.parse(f.get(0)).toString(),
                'parsing ' + f.get(0)
            );
        }
    }

    @IsTest
    static void rejectsWhatJiffRejects() {
        for (String row : REJECTED) {
            List<String> f = row.split('\\|');
            try {
                JiffZonedDateTime.parse(f.get(0));
                Assert.fail('expected ' + f.get(0) + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(f.get(1), e.getMessage(), 'error for ' + f.get(0));
            }
        }
    }

    @IsTest
    static void rejectsUnknownZonesAndMalformedText() {
        for (String text : new List<String>{ '2024-07-04T08:39:00-04:00[Not/AZone]', 'garbage' }) {
            try {
                JiffZonedDateTime.parse(text);
                Assert.fail('expected ' + text + ' to be rejected');
            } catch (JiffException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
    }

    @IsTest
    static void roundTripsWhatItPrints() {
        JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
        List<JiffZonedDateTime> values = new List<JiffZonedDateTime>{
            JiffTimestamp.fromMillisecond(1720093140123L).toZonedDateTime(newYork),
            // Both readings of the fold must come back as themselves.
            JiffTimestamp.newInstance(1730611800L, 0).toZonedDateTime(newYork),
            JiffTimestamp.newInstance(1730615400L, 0).toZonedDateTime(newYork),
            JiffTimestamp.newInstance(0L, 1).toZonedDateTime(JiffTimeZone.get('Asia/Kolkata')),
            JiffTimestamp.newInstance(0L, 0)
                .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromSeconds(-16200))),
            JiffTimestamp.newInstance(0L, 0).toZonedDateTime(JiffTimeZone.UTC)
        };
        for (JiffZonedDateTime value : values) {
            Assert.areEqual(
                value,
                JiffZonedDateTime.parse(value.toString()),
                'round trip of ' + value
            );
        }
    }
}
