/**
 * Expected values are Jiff's: from the tests and doc comments of `jiff::tz::TimeZone`, and
 * for the zones those do not cover, from running Jiff 1.0.0 with its bundled time zone
 * database. Named zones are answered by the platform's own zone data, so the cases stick to
 * well-known zones and to dates from 1970 onward.
 */
@IsTest
private class JiffTimeZoneTest {
    private static final String RANGE_SECONDS =
        'parameter \'Unix timestamp seconds\' is not in the required range of ' +
        '-377705023201..=253402207200';

    private static JiffTimeZone zone(String name) {
        return JiffTimeZone.get(name);
    }

    private static JiffOffset hours(Integer value) {
        return JiffOffset.fromHours(value);
    }

    private static JiffTimestamp sec(Long second) {
        return JiffTimestamp.fromSecond(second);
    }

    private static JiffDateTime dt(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer nanosecond
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, second, nanosecond);
    }

    /** The instant at the given hour, UTC. */
    private static JiffTimestamp utc(Integer year, Integer month, Integer day, Integer hour) {
        return JiffOffset.UTC.toTimestamp(dt(year, month, day, hour, 0, 0, 0));
    }

    private static void assertUnambiguous(JiffTimeZone tz, JiffDateTime civil, JiffOffset offset) {
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(offset),
            tz.toAmbiguousTimestamp(civil).offset(),
            tz.toString() + ' at ' + civil
        );
    }

    private static void assertGap(
        JiffTimeZone tz,
        JiffDateTime civil,
        JiffOffset before,
        JiffOffset after
    ) {
        Assert.areEqual(
            JiffAmbiguousOffset.gap(before, after),
            tz.toAmbiguousTimestamp(civil).offset(),
            tz.toString() + ' at ' + civil
        );
    }

    private static void assertFold(
        JiffTimeZone tz,
        JiffDateTime civil,
        JiffOffset before,
        JiffOffset after
    ) {
        Assert.areEqual(
            JiffAmbiguousOffset.fold(before, after),
            tz.toAmbiguousTimestamp(civil).offset(),
            tz.toString() + ' at ' + civil
        );
    }

    /** Asserts what a zone reports at an instant: its offset, abbreviation and local time. */
    private static void assertInfo(
        JiffTimeZone tz,
        JiffTimestamp timestamp,
        JiffOffset offset,
        String abbreviation,
        JiffDateTime civil
    ) {
        JiffTimeZoneOffsetInfo info = tz.toOffsetInfo(timestamp);
        String context = tz.toString() + ' at ' + timestamp;
        Assert.areEqual(offset, info.offset(), context);
        Assert.areEqual(abbreviation, info.abbreviation(), context);
        Assert.areEqual(offset, tz.toOffset(timestamp), context);
        Assert.areEqual(civil, tz.toDateTime(timestamp), context);
    }

    private static void assertPrevious(
        JiffTimeZone tz,
        JiffTimestamp given,
        JiffTimestamp expected
    ) {
        JiffTimeZoneTransition transition = tz.previousTransition(given);
        Assert.areEqual(
            expected,
            transition == null ? null : transition.toTimestamp(),
            tz.toString() + ' before ' + given
        );
    }

    private static void assertNext(JiffTimeZone tz, JiffTimestamp given, JiffTimestamp expected) {
        JiffTimeZoneTransition transition = tz.nextTransition(given);
        Assert.areEqual(
            expected,
            transition == null ? null : transition.toTimestamp(),
            tz.toString() + ' after ' + given
        );
    }

    private static void assertNotFound(String name) {
        try {
            JiffTimeZone.get(name);
            Assert.fail('expected `' + name + '` not to be found');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time zone `' + name + '` in time zone database',
                e.getMessage()
            );
        }
    }

    // ---- UTC, fixed and unknown zones -----------------------------------

    @IsTest
    static void utcIsAlwaysAtOffsetZero() {
        JiffTimeZone tz = JiffTimeZone.UTC;
        Assert.areEqual('UTC', tz.ianaName());
        Assert.areEqual('UTC', tz.toString());
        Assert.isFalse(tz.isUnknown());
        Assert.areEqual(JiffOffset.UTC, tz.toOffset(sec(1720493204L)));
        Assert.areEqual(JiffOffset.UTC, tz.toFixedOffset());
        JiffTimeZoneOffsetInfo info = tz.toOffsetInfo(sec(123456789L));
        Assert.areEqual(JiffOffset.UTC, info.offset());
        Assert.areEqual(JiffDst.NO, info.dst());
        Assert.areEqual('UTC', info.abbreviation());
        Assert.areEqual(dt(1973, 11, 29, 21, 33, 9, 0), tz.toDateTime(sec(123456789L)));
        Assert.areEqual(sec(123456789L), tz.toTimestamp(dt(1973, 11, 29, 21, 33, 9, 0)));
        assertUnambiguous(tz, dt(2024, 3, 10, 2, 30, 0, 0), JiffOffset.UTC);
    }

    @IsTest
    static void utcHasNoTransitions() {
        for (
            JiffTimestamp given : new List<JiffTimestamp>{
                utc(1969, 12, 31, 19),
                utc(2024, 3, 10, 2),
                utc(-9999, 12, 1, 0),
                utc(9999, 12, 1, 0)
            }
        ) {
            assertPrevious(JiffTimeZone.UTC, given, null);
            assertNext(JiffTimeZone.UTC, given, null);
        }
    }

    @IsTest
    static void fixedZonesKeepOneOffset() {
        Assert.areEqual(
            '1970-01-01T10:00:00',
            JiffTimeZone.fixed(hours(10)).toDateTime(JiffTimestamp.UNIX_EPOCH).toString()
        );
        Assert.areEqual(
            dt(1969, 12, 31, 19, 0, 0, 0),
            hours(-5).toTimeZone().toDateTime(JiffTimestamp.UNIX_EPOCH)
        );
        Assert.areEqual(
            JiffDateTime.MAX,
            JiffOffset.fromSeconds(93599).toTimeZone().toDateTime(JiffTimestamp.MAX)
        );
        Assert.areEqual(
            JiffDateTime.MIN,
            JiffOffset.fromSeconds(-93599).toTimeZone().toDateTime(JiffTimestamp.MIN)
        );
        JiffTimeZone tz = JiffTimeZone.fixed(hours(-10));
        Assert.isNull(tz.ianaName());
        Assert.isFalse(tz.isUnknown());
        Assert.areEqual(hours(-10), tz.toFixedOffset());
        Assert.areEqual(hours(-10), tz.toOffset(sec(1720493204L)));
        Assert.areEqual('-10', tz.toString());
        assertPrevious(tz, utc(2024, 3, 10, 2), null);
        assertNext(tz, utc(2024, 3, 10, 2), null);
        assertUnambiguous(tz, dt(2024, 3, 10, 2, 30, 0, 0), hours(-10));
    }

    @IsTest
    static void fixedZonesAreAbbreviatedByTheirOffset() {
        JiffTimestamp timestamp = sec(123456789L);
        Map<Integer, String> expected = new Map<Integer, String>{
            -5 => '-05',
            5 => '+05',
            -12 => '-12',
            12 => '+12',
            0 => 'UTC'
        };
        for (Integer offsetHours : expected.keySet()) {
            JiffTimeZoneOffsetInfo info = JiffTimeZone.fixed(hours(offsetHours))
                .toOffsetInfo(timestamp);
            Assert.areEqual(hours(offsetHours), info.offset());
            Assert.areEqual(JiffDst.NO, info.dst());
            Assert.areEqual(expected.get(offsetHours), info.abbreviation());
        }
        Assert.areEqual(
            '-00:44:30',
            JiffTimeZone.fixed(JiffOffset.fromSeconds(-2670)).toOffsetInfo(timestamp).abbreviation()
        );
    }

    @IsTest
    static void fixedZonesConvertCivilTimesExactly() {
        Assert.areEqual(
            JiffTimestamp.UNIX_EPOCH,
            hours(-5).toTimeZone().toTimestamp(dt(1969, 12, 31, 19, 0, 0, 0))
        );
        Assert.areEqual(
            JiffTimestamp.MAX,
            JiffOffset.fromSeconds(93599).toTimeZone().toTimestamp(JiffDateTime.MAX)
        );
        Assert.areEqual(
            JiffTimestamp.MIN,
            JiffOffset.fromSeconds(-93599).toTimeZone().toTimestamp(JiffDateTime.MIN)
        );
        try {
            JiffOffset.fromSeconds(93598).toTimeZone().toTimestamp(JiffDateTime.MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('to timestamp overflowed'), e.getMessage());
        }
        try {
            JiffOffset.fromSeconds(-93598).toTimeZone().toTimestamp(JiffDateTime.MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('to timestamp overflowed'), e.getMessage());
        }
    }

    @IsTest
    static void aFixedZoneAtOffsetZeroIsUtc() {
        Assert.areEqual(JiffTimeZone.UTC, JiffTimeZone.fixed(JiffOffset.UTC));
        Assert.areEqual('UTC', JiffTimeZone.fixed(hours(0)).ianaName());
        try {
            JiffTimeZone.fixed(null);
            Assert.fail('expected a null offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a fixed time zone needs an offset', e.getMessage());
        }
    }

    @IsTest
    static void theUnknownZoneBehavesLikeUtcButSaysSo() {
        JiffTimeZone tz = JiffTimeZone.unknown();
        Assert.isTrue(tz.isUnknown());
        Assert.isNull(tz.ianaName());
        Assert.areEqual('Etc/Unknown', tz.toString());
        Assert.areNotEqual(JiffTimeZone.UTC, tz);
        Assert.areEqual(JiffTimeZone.unknown(), tz);
        Assert.areEqual(JiffOffset.UTC, tz.toFixedOffset());
        Assert.areEqual(JiffOffset.UTC, tz.toOffset(sec(1720493204L)));
        JiffTimeZoneOffsetInfo info = tz.toOffsetInfo(JiffTimestamp.UNIX_EPOCH);
        Assert.areEqual(JiffOffset.UTC, info.offset());
        Assert.areEqual('UTC', info.abbreviation());
        Assert.areEqual(JiffDst.NO, info.dst());
        Assert.areEqual(utc(2025, 2, 1, 17), tz.toTimestamp(dt(2025, 2, 1, 17, 0, 0, 0)));
        assertPrevious(tz, utc(2024, 3, 10, 2), null);
        assertNext(tz, utc(2024, 3, 10, 2), null);
    }

    // ---- lookup ---------------------------------------------------------

    @IsTest
    static void getFindsZonesByIanaName() {
        Assert.areEqual(
            '1970-01-01T09:00:00',
            zone('Asia/Tokyo').toDateTime(JiffTimestamp.UNIX_EPOCH).toString()
        );
        Assert.areEqual(
            '1970-01-01T01:00:00',
            zone('Europe/Rome').toDateTime(JiffTimestamp.UNIX_EPOCH).toString()
        );
        Assert.areEqual(
            '1969-12-31T19:00:00',
            zone('America/New_York').toDateTime(JiffTimestamp.UNIX_EPOCH).toString()
        );
        Assert.areEqual(
            '1970-01-01T11:00:00',
            zone('Australia/Hobart').toDateTime(JiffTimestamp.UNIX_EPOCH).toString()
        );
        JiffTimeZone tz = zone('America/New_York');
        Assert.areEqual('America/New_York', tz.ianaName());
        Assert.areEqual('America/New_York', tz.toString());
        Assert.isFalse(tz.isUnknown());
    }

    @IsTest
    static void getRejectsNamesThePlatformDoesNotKnow() {
        assertNotFound('Not/AZone');
        assertNotFound('does not exist');
        assertNotFound('');
        assertNotFound(null);
        // Java style custom ids are fixed offsets, not IANA names.
        assertNotFound('GMT+05:00');
        assertNotFound('GMT-5');
        assertNotFound('+05:00');
        assertNotFound(' UTC');
        assertNotFound('America/New_York ');
    }

    @IsTest
    static void namesAreCaseSensitiveUnlikeInJiff() {
        // Jiff resolves `america/NEW_YORK` to `America/New_York`. The platform cannot.
        assertNotFound('america/NEW_YORK');
        assertNotFound('america/new_york');
        assertNotFound('AMERICA/NEW_YORK');
    }

    @IsTest
    static void utcAndTheUnknownZoneAreFoundInAnyCase() {
        for (String name : new List<String>{ 'UTC', 'utc', 'Utc' }) {
            Assert.areEqual(JiffTimeZone.UTC, JiffTimeZone.get(name));
            Assert.areEqual('UTC', JiffTimeZone.get(name).ianaName());
        }
        for (String name : new List<String>{ 'Etc/Unknown', 'etc/unknown' }) {
            Assert.isTrue(JiffTimeZone.get(name).isUnknown());
            Assert.isNull(JiffTimeZone.get(name).ianaName());
        }
    }

    @IsTest
    static void genuineGmtZonesAreNotMistakenForUnknownNames() {
        // The platform answers an unknown id with its GMT zone, so GMT itself and its aliases
        // need to be told apart from that fallback.
        for (
            String name : new List<String>{
                'GMT',
                'Etc/GMT',
                'Etc/UTC',
                'Etc/Greenwich',
                'Africa/Abidjan'
            }
        ) {
            JiffTimeZone tz = JiffTimeZone.get(name);
            Assert.areEqual(name, tz.ianaName());
            Assert.areEqual(JiffOffset.UTC, tz.toOffset(JiffTimestamp.UNIX_EPOCH));
            Assert.isFalse(tz.isUnknown());
        }
        Assert.areEqual('GMT', zone('GMT').toOffsetInfo(JiffTimestamp.UNIX_EPOCH).abbreviation());
        // A named zone that happens to be at offset zero is still not the UTC zone.
        Assert.areNotEqual(JiffTimeZone.UTC, zone('Etc/UTC'));
    }

    @IsTest
    static void userTimeZoneIsTheRunningUsersZone() {
        String expected = UserInfo.getTimeZone().getID();
        JiffTimeZone tz = JiffTimeZone.userTimeZone();
        Assert.isFalse(tz.isUnknown());
        Assert.areEqual(expected, tz.ianaName());
        Assert.areEqual(JiffTimeZone.get(expected), tz);
    }

    @IsTest
    static void aZoneThatCannotBeLookedUpFallsBackToUnknown() {
        Assert.isTrue(JiffTimeZone.lookupOrUnknown('Not/AZone').isUnknown());
        Assert.isTrue(JiffTimeZone.lookupOrUnknown(null).isUnknown());
        Assert.areEqual(zone('Europe/London'), JiffTimeZone.lookupOrUnknown('Europe/London'));
    }

    @IsTest
    static void equalityComparesKindAndNameOrOffset() {
        Assert.areEqual(zone('Europe/London'), zone('Europe/London'));
        Assert.areEqual(zone('Europe/London').hashCode(), zone('Europe/London').hashCode());
        Assert.areNotEqual(zone('Europe/London'), zone('Europe/Dublin'));
        Assert.areEqual(JiffTimeZone.fixed(hours(-5)), JiffTimeZone.fixed(hours(-5)));
        Assert.areEqual(
            JiffTimeZone.fixed(hours(-5)).hashCode(),
            JiffTimeZone.fixed(hours(-5)).hashCode()
        );
        Assert.areNotEqual(JiffTimeZone.fixed(hours(-5)), JiffTimeZone.fixed(hours(-4)));
        // Same offsets today, different kinds of zone.
        Assert.areNotEqual(JiffTimeZone.fixed(hours(9)), zone('Asia/Tokyo'));
        Assert.areNotEqual(JiffTimeZone.UTC, JiffTimeZone.fixed(hours(1)));
        Assert.isFalse(zone('Europe/London').equals('Europe/London'));
        Map<JiffTimeZone, String> cities = new Map<JiffTimeZone, String>{
            zone('Asia/Tokyo') => 'Tokyo',
            JiffTimeZone.UTC => 'nowhere'
        };
        Assert.areEqual('Tokyo', cities.get(zone('Asia/Tokyo')));
        Assert.areEqual('nowhere', cities.get(JiffTimeZone.get('utc')));
    }

    @IsTest
    static void aliasesBehaveAlikeButAreNotEqualUnlikeInJiff() {
        JiffTimeZone calcutta = zone('Asia/Calcutta');
        JiffTimeZone kolkata = zone('Asia/Kolkata');
        Assert.areEqual('Asia/Calcutta', calcutta.ianaName());
        Assert.areEqual(
            kolkata.toOffset(JiffTimestamp.UNIX_EPOCH),
            calcutta.toOffset(JiffTimestamp.UNIX_EPOCH)
        );
        // Jiff compares the underlying zone data and calls these equal.
        Assert.areNotEqual(kolkata, calcutta);
    }

    @IsTest
    static void onlyZonesWithOneOffsetConvertToAFixedOffset() {
        try {
            zone('America/New_York').toFixedOffset();
            Assert.fail('expected a named zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'cannot convert non-fixed IANA time zone to offset ' +
                'without a timestamp or civil datetime',
                e.getMessage()
            );
        }
        Assert.areEqual(JiffOffset.UTC, JiffTimeZone.UTC.toFixedOffset());
        Assert.areEqual(hours(1), JiffTimeZone.fixed(hours(1)).toFixedOffset());
    }

    // ---- instant to civil -----------------------------------------------

    @IsTest
    static void toOffsetFollowsDaylightSavingInNewYork() {
        JiffTimeZone tz = zone('America/New_York');
        JiffTimestamp summer = sec(1720493204L);
        Assert.areEqual(hours(-4), tz.toOffset(summer));
        Assert.areEqual('2024-07-08T22:46:44', tz.toOffset(summer).toDateTime(summer).toString());
        JiffTimestamp winter = sec(1704941204L);
        Assert.areEqual(hours(-5), tz.toOffset(winter));
        Assert.areEqual('2024-01-10T21:46:44', tz.toOffset(winter).toDateTime(winter).toString());
    }

    @IsTest
    static void toOffsetInfoAddsTheAbbreviationAndDstFlag() {
        JiffTimeZone tz = zone('America/New_York');
        JiffTimeZoneOffsetInfo summer = tz.toOffsetInfo(sec(1720493204L));
        Assert.areEqual(hours(-4), summer.offset());
        Assert.areEqual(JiffDst.YES, summer.dst());
        Assert.areEqual('EDT', summer.abbreviation());
        JiffTimeZoneOffsetInfo winter = tz.toOffsetInfo(sec(1704941204L));
        Assert.areEqual(hours(-5), winter.offset());
        Assert.areEqual(JiffDst.NO, winter.dst());
        Assert.areEqual('EST', winter.abbreviation());
    }

    @IsTest
    static void newYorkInstantsMapToCivilTimes() {
        JiffTimeZone tz = zone('America/New_York');
        assertInfo(tz, sec(0L), hours(-5), 'EST', dt(1969, 12, 31, 19, 0, 0, 0));
        assertInfo(tz, sec(1710052200L), hours(-5), 'EST', dt(2024, 3, 10, 1, 30, 0, 0));
        assertInfo(
            tz,
            JiffTimestamp.newInstance(1710053999L, 999999999),
            hours(-5),
            'EST',
            dt(2024, 3, 10, 1, 59, 59, 999999999)
        );
        assertInfo(tz, sec(1710054000L), hours(-4), 'EDT', dt(2024, 3, 10, 3, 0, 0, 0));
        assertInfo(tz, sec(1710055800L), hours(-4), 'EDT', dt(2024, 3, 10, 3, 30, 0, 0));
        assertInfo(tz, sec(1730610000L), hours(-4), 'EDT', dt(2024, 11, 3, 1, 0, 0, 0));
        assertInfo(tz, sec(1730611800L), hours(-4), 'EDT', dt(2024, 11, 3, 1, 30, 0, 0));
        assertInfo(
            tz,
            JiffTimestamp.newInstance(1730613599L, 999999999),
            hours(-4),
            'EDT',
            dt(2024, 11, 3, 1, 59, 59, 999999999)
        );
        assertInfo(tz, sec(1730613600L), hours(-5), 'EST', dt(2024, 11, 3, 1, 0, 0, 0));
        assertInfo(tz, sec(1730615400L), hours(-5), 'EST', dt(2024, 11, 3, 1, 30, 0, 0));
        assertInfo(tz, sec(123456789L), hours(-5), 'EST', dt(1973, 11, 29, 16, 33, 9, 0));
        assertInfo(tz, sec(1456789123L), hours(-5), 'EST', dt(2016, 2, 29, 18, 38, 43, 0));
    }

    @IsTest
    static void tasmanianInstantsMapToCivilTimes() {
        JiffTimeZone tz = zone('Australia/Tasmania');
        assertInfo(tz, sec(0L), hours(11), 'AEDT', dt(1970, 1, 1, 11, 0, 0, 0));
        assertInfo(tz, sec(1728142200L), hours(10), 'AEST', dt(2024, 10, 6, 1, 30, 0, 0));
        assertInfo(
            tz,
            JiffTimestamp.newInstance(1728143999L, 999999999),
            hours(10),
            'AEST',
            dt(2024, 10, 6, 1, 59, 59, 999999999)
        );
        assertInfo(tz, sec(1728144000L), hours(11), 'AEDT', dt(2024, 10, 6, 3, 0, 0, 0));
        assertInfo(tz, sec(1728145800L), hours(11), 'AEDT', dt(2024, 10, 6, 3, 30, 0, 0));
        assertInfo(tz, sec(1712415600L), hours(11), 'AEDT', dt(2024, 4, 7, 2, 0, 0, 0));
        assertInfo(tz, sec(1712417400L), hours(11), 'AEDT', dt(2024, 4, 7, 2, 30, 0, 0));
        assertInfo(
            tz,
            JiffTimestamp.newInstance(1712419199L, 999999999),
            hours(11),
            'AEDT',
            dt(2024, 4, 7, 2, 59, 59, 999999999)
        );
        assertInfo(tz, sec(1712419200L), hours(10), 'AEST', dt(2024, 4, 7, 2, 0, 0, 0));
        assertInfo(tz, sec(1712421000L), hours(10), 'AEST', dt(2024, 4, 7, 2, 30, 0, 0));
    }

    @IsTest
    static void wellKnownZonesReportTheirOffsetsAndAbbreviations() {
        JiffTimestamp summer = sec(1720493204L);
        JiffTimestamp winter = sec(1704941204L);
        assertInfo(zone('Europe/London'), summer, hours(1), 'BST', dt(2024, 7, 9, 3, 46, 44, 0));
        assertInfo(zone('Europe/London'), winter, hours(0), 'GMT', dt(2024, 1, 11, 2, 46, 44, 0));
        assertInfo(
            zone('Australia/Sydney'),
            summer,
            hours(10),
            'AEST',
            dt(2024, 7, 9, 12, 46, 44, 0)
        );
        assertInfo(
            zone('Australia/Sydney'),
            winter,
            hours(11),
            'AEDT',
            dt(2024, 1, 11, 13, 46, 44, 0)
        );
        JiffOffset india = JiffOffset.fromSeconds(19800);
        assertInfo(zone('Asia/Kolkata'), summer, india, 'IST', dt(2024, 7, 9, 8, 16, 44, 0));
        assertInfo(zone('Asia/Kolkata'), sec(0L), india, 'IST', dt(1970, 1, 1, 5, 30, 0, 0));
        // 2024-07-15T21:27 in New York is 04:27 the next morning in Jerusalem.
        JiffTimestamp evening = zone('America/New_York').toTimestamp(dt(2024, 7, 15, 21, 27, 0, 0));
        Assert.areEqual(hours(-4), zone('America/New_York').toOffset(evening));
        Assert.areEqual(hours(3), zone('Asia/Jerusalem').toOffset(evening));
        Assert.areEqual(dt(2024, 7, 16, 4, 27, 0, 0), zone('Asia/Jerusalem').toDateTime(evening));
    }

    @IsTest
    static void zonesWithoutANameUseTheDatabasesNumericAbbreviations() {
        // The time zone database abbreviates Etc/GMT+5 as `-05`. The platform has no name
        // for it and prints `GMT-05:00`, which is converted.
        JiffTimeZoneOffsetInfo west = zone('Etc/GMT+5').toOffsetInfo(JiffTimestamp.UNIX_EPOCH);
        Assert.areEqual(hours(-5), west.offset());
        Assert.areEqual('-05', west.abbreviation());
        Assert.areEqual(JiffDst.NO, west.dst());
        JiffTimeZoneOffsetInfo east = zone('Etc/GMT-14').toOffsetInfo(JiffTimestamp.UNIX_EPOCH);
        Assert.areEqual(hours(14), east.offset());
        Assert.areEqual('+14', east.abbreviation());
        Assert.areEqual(JiffDst.NO, east.dst());
    }

    @IsTest
    static void numericAbbreviationsAreAsShortAsTheOffsetAllows() {
        // The database writes these as `+hh`, `+hhmm` or `+hhmmss`, whichever is shortest:
        // Pacific/Apia is `+13`, Asia/Kathmandu `+0545`, Antarctica/Troll in winter `+00`.
        Assert.areEqual('+13', JiffTimeZone.numericAbbreviation(46800));
        Assert.areEqual('-03', JiffTimeZone.numericAbbreviation(-10800));
        Assert.areEqual('+0545', JiffTimeZone.numericAbbreviation(20700));
        Assert.areEqual('-0330', JiffTimeZone.numericAbbreviation(-12600));
        Assert.areEqual('+00', JiffTimeZone.numericAbbreviation(0));
        Assert.areEqual('+055328', JiffTimeZone.numericAbbreviation(21208));
        Assert.areEqual('-000030', JiffTimeZone.numericAbbreviation(-30));
    }

    // ---- daylight saving inference ---------------------------------------

    @IsTest
    static void dstIsInferredForNorthernAndSouthernSummers() {
        JiffTimestamp july = sec(1720493204L);
        JiffTimestamp january = sec(1704941204L);
        Assert.areEqual(JiffDst.YES, zone('Europe/London').toOffsetInfo(july).dst());
        Assert.areEqual(JiffDst.NO, zone('Europe/London').toOffsetInfo(january).dst());
        Assert.areEqual(JiffDst.YES, zone('Europe/Dublin').toOffsetInfo(july).dst());
        Assert.areEqual(JiffDst.NO, zone('Europe/Dublin').toOffsetInfo(january).dst());
        Assert.areEqual(JiffDst.NO, zone('Australia/Sydney').toOffsetInfo(july).dst());
        Assert.areEqual(JiffDst.YES, zone('Australia/Sydney').toOffsetInfo(january).dst());
        Assert.areEqual(JiffDst.YES, zone('Antarctica/Troll').toOffsetInfo(july).dst());
        Assert.areEqual(JiffDst.NO, zone('Antarctica/Troll').toOffsetInfo(january).dst());
        Assert.areEqual(JiffDst.YES, zone('Asia/Jerusalem').toOffsetInfo(sec(1721093220L)).dst());
        // Either side of a transition, in Tasmania.
        JiffTimeZone tasmania = zone('Australia/Tasmania');
        Assert.areEqual(JiffDst.YES, tasmania.toOffsetInfo(sec(0L)).dst());
        Assert.areEqual(JiffDst.NO, tasmania.toOffsetInfo(sec(1728142200L)).dst());
        Assert.areEqual(JiffDst.YES, tasmania.toOffsetInfo(sec(1728144000L)).dst());
        Assert.areEqual(JiffDst.YES, tasmania.toOffsetInfo(sec(1712415600L)).dst());
        Assert.areEqual(JiffDst.NO, tasmania.toOffsetInfo(sec(1712419200L)).dst());
    }

    @IsTest
    static void dstIsNotInferredWhereTheOffsetNeverDrops() {
        Assert.areEqual(JiffDst.NO, zone('Asia/Kolkata').toOffsetInfo(sec(1720493204L)).dst());
        Assert.areEqual(JiffDst.NO, zone('Asia/Tokyo').toOffsetInfo(sec(0L)).dst());
        // Britain kept `+01` all year from 1968 to 1971, as its standard time.
        JiffTimeZoneOffsetInfo london = zone('Europe/London').toOffsetInfo(sec(0L));
        Assert.areEqual(hours(1), london.offset());
        Assert.areEqual(JiffDst.NO, london.dst());
        // Brazil stopped observing daylight saving time in 2019.
        JiffTimeZone saoPaulo = zone('America/Sao_Paulo');
        Assert.areEqual(JiffDst.YES, saoPaulo.toOffsetInfo(sec(1546300800L)).dst());
        Assert.areEqual(hours(-2), saoPaulo.toOffset(sec(1546300800L)));
        Assert.areEqual(JiffDst.NO, saoPaulo.toOffsetInfo(sec(1720493204L)).dst());
        Assert.areEqual(hours(-3), saoPaulo.toOffset(sec(1720493204L)));
    }

    @IsTest
    static void dstInferenceIgnoresAJumpAcrossTheDateLine() {
        // Samoa skipped 2011-12-30 to move west of the date line, from -10 to +14, in the
        // middle of its summer. The jump of a whole day is not daylight saving time.
        JiffTimeZone apia = zone('Pacific/Apia');
        JiffTimeZoneOffsetInfo before = apia.toOffsetInfo(sec(1325239199L));
        Assert.areEqual(hours(-10), before.offset());
        Assert.areEqual(JiffDst.YES, before.dst());
        JiffTimeZoneOffsetInfo after = apia.toOffsetInfo(sec(1325239200L));
        Assert.areEqual(hours(14), after.offset());
        Assert.areEqual(JiffDst.YES, after.dst());
        // The winters either side of the move are standard time.
        Assert.areEqual(hours(-11), apia.toOffset(sec(1309478400L)));
        Assert.areEqual(JiffDst.NO, apia.toOffsetInfo(sec(1309478400L)).dst());
        Assert.areEqual(hours(13), apia.toOffset(sec(1340000000L)));
        Assert.areEqual(JiffDst.NO, apia.toOffsetInfo(sec(1340000000L)).dst());
        Assert.areEqual(JiffDst.NO, apia.toOffsetInfo(sec(1720493204L)).dst());
    }

    @IsTest
    static void dstInferenceMistakesARecentPermanentShiftForDaylightSaving() {
        // A documented limit of the inference. Russia moved its clocks forward for good in
        // March 2011. The time zone database (and Jiff) call the following June standard
        // time; with only offsets to go on, it looks like any other summer.
        JiffTimeZone moscow = zone('Europe/Moscow');
        Assert.areEqual(hours(4), moscow.toOffset(sec(1307000000L)));
        Assert.areEqual(JiffDst.YES, moscow.toOffsetInfo(sec(1307000000L)).dst());
        // A year later no lower offset is in sight and the answer agrees with the database.
        Assert.areEqual(hours(4), moscow.toOffset(sec(1340000000L)));
        Assert.areEqual(JiffDst.NO, moscow.toOffsetInfo(sec(1340000000L)).dst());
    }

    // ---- civil to instant -----------------------------------------------

    @IsTest
    static void newYorkCivilTimesAreClassified() {
        JiffTimeZone tz = zone('America/New_York');
        assertUnambiguous(tz, dt(1969, 12, 31, 19, 0, 0, 0), hours(-5));
        assertUnambiguous(tz, dt(2024, 3, 10, 1, 59, 59, 999999999), hours(-5));
        assertGap(tz, dt(2024, 3, 10, 2, 0, 0, 0), hours(-5), hours(-4));
        assertGap(tz, dt(2024, 3, 10, 2, 59, 59, 999999999), hours(-5), hours(-4));
        assertUnambiguous(tz, dt(2024, 3, 10, 3, 0, 0, 0), hours(-4));
        assertUnambiguous(tz, dt(2024, 11, 3, 0, 59, 59, 999999999), hours(-4));
        assertFold(tz, dt(2024, 11, 3, 1, 0, 0, 0), hours(-4), hours(-5));
        assertFold(tz, dt(2024, 11, 3, 1, 59, 59, 999999999), hours(-4), hours(-5));
        assertUnambiguous(tz, dt(2024, 11, 3, 2, 0, 0, 0), hours(-5));
        assertUnambiguous(tz, dt(2024, 7, 15, 17, 30, 0, 0), hours(-4));
        // Before 2007 the United States changed its clocks in April.
        Assert.isTrue(tz.toAmbiguousTimestamp(dt(2006, 4, 2, 2, 0, 0, 0)).isAmbiguous());
    }

    @IsTest
    static void dublinCivilTimesAreClassified() {
        JiffTimeZone tz = zone('Europe/Dublin');
        assertUnambiguous(tz, dt(1970, 1, 1, 0, 0, 0, 0), hours(1));
        assertUnambiguous(tz, dt(2024, 3, 31, 0, 59, 59, 999999999), hours(0));
        assertGap(tz, dt(2024, 3, 31, 1, 0, 0, 0), hours(0), hours(1));
        assertGap(tz, dt(2024, 3, 31, 1, 59, 59, 999999999), hours(0), hours(1));
        assertUnambiguous(tz, dt(2024, 3, 31, 2, 0, 0, 0), hours(1));
        assertUnambiguous(tz, dt(2024, 10, 27, 0, 59, 59, 999999999), hours(1));
        assertFold(tz, dt(2024, 10, 27, 1, 0, 0, 0), hours(1), hours(0));
        assertFold(tz, dt(2024, 10, 27, 1, 59, 59, 999999999), hours(1), hours(0));
        assertUnambiguous(tz, dt(2024, 10, 27, 2, 0, 0, 0), hours(0));
    }

    @IsTest
    static void tasmanianCivilTimesAreClassified() {
        JiffTimeZone tz = zone('Australia/Tasmania');
        assertUnambiguous(tz, dt(1970, 1, 1, 11, 0, 0, 0), hours(11));
        assertUnambiguous(tz, dt(2024, 4, 7, 1, 59, 59, 999999999), hours(11));
        assertFold(tz, dt(2024, 4, 7, 2, 0, 0, 0), hours(11), hours(10));
        assertFold(tz, dt(2024, 4, 7, 2, 59, 59, 999999999), hours(11), hours(10));
        assertUnambiguous(tz, dt(2024, 4, 7, 3, 0, 0, 0), hours(10));
        assertUnambiguous(tz, dt(2024, 10, 6, 1, 59, 59, 999999999), hours(10));
        assertGap(tz, dt(2024, 10, 6, 2, 0, 0, 0), hours(10), hours(11));
        assertGap(tz, dt(2024, 10, 6, 2, 59, 59, 999999999), hours(10), hours(11));
        assertUnambiguous(tz, dt(2024, 10, 6, 3, 0, 0, 0), hours(11));
    }

    @IsTest
    static void aTwoHourTransitionMakesATwoHourGapAndFold() {
        JiffTimeZone tz = zone('Antarctica/Troll');
        assertUnambiguous(tz, dt(1970, 1, 1, 0, 0, 0, 0), hours(0));
        assertUnambiguous(tz, dt(2024, 3, 31, 0, 59, 59, 999999999), hours(0));
        assertGap(tz, dt(2024, 3, 31, 1, 0, 0, 0), hours(0), hours(2));
        assertGap(tz, dt(2024, 3, 31, 1, 59, 59, 999999999), hours(0), hours(2));
        assertGap(tz, dt(2024, 3, 31, 2, 0, 0, 0), hours(0), hours(2));
        assertGap(tz, dt(2024, 3, 31, 2, 59, 59, 999999999), hours(0), hours(2));
        assertUnambiguous(tz, dt(2024, 3, 31, 3, 0, 0, 0), hours(2));
        assertUnambiguous(tz, dt(2024, 10, 27, 0, 59, 59, 999999999), hours(2));
        assertFold(tz, dt(2024, 10, 27, 1, 0, 0, 0), hours(2), hours(0));
        assertFold(tz, dt(2024, 10, 27, 1, 59, 59, 999999999), hours(2), hours(0));
        assertFold(tz, dt(2024, 10, 27, 2, 0, 0, 0), hours(2), hours(0));
        assertFold(tz, dt(2024, 10, 27, 2, 59, 59, 999999999), hours(2), hours(0));
        assertUnambiguous(tz, dt(2024, 10, 27, 3, 0, 0, 0), hours(0));
    }

    @IsTest
    static void halfHourOffsetsAreClassified() {
        JiffTimeZone tz = zone('America/St_Johns');
        JiffOffset standard = JiffOffset.fromSeconds(-12600);
        JiffOffset daylight = JiffOffset.fromSeconds(-9000);
        assertUnambiguous(tz, dt(1969, 12, 31, 20, 30, 0, 0), standard);
        assertUnambiguous(tz, dt(2024, 3, 10, 1, 59, 59, 999999999), standard);
        assertGap(tz, dt(2024, 3, 10, 2, 0, 0, 0), standard, daylight);
        assertGap(tz, dt(2024, 3, 10, 2, 59, 59, 999999999), standard, daylight);
        assertUnambiguous(tz, dt(2024, 3, 10, 3, 0, 0, 0), daylight);
        assertUnambiguous(tz, dt(2024, 11, 3, 0, 59, 59, 999999999), daylight);
        assertFold(tz, dt(2024, 11, 3, 1, 0, 0, 0), daylight, standard);
        assertFold(tz, dt(2024, 11, 3, 1, 59, 59, 999999999), daylight, standard);
        assertUnambiguous(tz, dt(2024, 11, 3, 2, 0, 0, 0), standard);
    }

    @IsTest
    static void londonSydneyAndSaoPauloCivilTimesAreClassified() {
        JiffTimeZone london = zone('Europe/London');
        assertUnambiguous(london, dt(2024, 3, 31, 0, 59, 59, 999999999), hours(0));
        assertGap(london, dt(2024, 3, 31, 1, 0, 0, 0), hours(0), hours(1));
        assertGap(london, dt(2024, 3, 31, 1, 30, 0, 0), hours(0), hours(1));
        assertUnambiguous(london, dt(2024, 3, 31, 2, 0, 0, 0), hours(1));
        assertUnambiguous(london, dt(2024, 10, 27, 0, 59, 59, 999999999), hours(1));
        assertFold(london, dt(2024, 10, 27, 1, 0, 0, 0), hours(1), hours(0));
        assertFold(london, dt(2024, 10, 27, 1, 30, 0, 0), hours(1), hours(0));
        assertUnambiguous(london, dt(2024, 10, 27, 2, 0, 0, 0), hours(0));

        JiffTimeZone sydney = zone('Australia/Sydney');
        assertUnambiguous(sydney, dt(2024, 4, 7, 1, 59, 59, 999999999), hours(11));
        assertFold(sydney, dt(2024, 4, 7, 2, 0, 0, 0), hours(11), hours(10));
        assertFold(sydney, dt(2024, 4, 7, 2, 30, 0, 0), hours(11), hours(10));
        assertUnambiguous(sydney, dt(2024, 4, 7, 3, 0, 0, 0), hours(10));
        assertUnambiguous(sydney, dt(2024, 10, 6, 1, 59, 59, 0), hours(10));
        assertGap(sydney, dt(2024, 10, 6, 2, 0, 0, 0), hours(10), hours(11));
        assertGap(sydney, dt(2024, 10, 6, 2, 30, 0, 0), hours(10), hours(11));
        assertUnambiguous(sydney, dt(2024, 10, 6, 3, 0, 0, 0), hours(11));

        // Brazil's last daylight saving season began and ended at midnight.
        JiffTimeZone saoPaulo = zone('America/Sao_Paulo');
        assertUnambiguous(saoPaulo, dt(2018, 11, 3, 23, 59, 59, 0), hours(-3));
        assertGap(saoPaulo, dt(2018, 11, 4, 0, 0, 0, 0), hours(-3), hours(-2));
        assertGap(saoPaulo, dt(2018, 11, 4, 0, 30, 0, 0), hours(-3), hours(-2));
        assertUnambiguous(saoPaulo, dt(2018, 11, 4, 1, 0, 0, 0), hours(-2));
        assertUnambiguous(saoPaulo, dt(2019, 2, 16, 22, 59, 59, 0), hours(-2));
        assertFold(saoPaulo, dt(2019, 2, 16, 23, 0, 0, 0), hours(-2), hours(-3));
        assertFold(saoPaulo, dt(2019, 2, 16, 23, 30, 0, 0), hours(-2), hours(-3));
        assertUnambiguous(saoPaulo, dt(2019, 2, 17, 0, 0, 0, 0), hours(-3));
        assertUnambiguous(saoPaulo, dt(2024, 11, 3, 0, 30, 0, 0), hours(-3));

        JiffOffset india = JiffOffset.fromSeconds(19800);
        assertUnambiguous(zone('Asia/Kolkata'), dt(2024, 3, 10, 2, 30, 0, 0), india);
        assertUnambiguous(zone('Asia/Kolkata'), dt(1970, 1, 1, 5, 30, 0, 0), india);
    }

    @IsTest
    static void samoaSkippedAWholeDayIn2011() {
        JiffTimeZone tz = zone('Pacific/Apia');
        assertUnambiguous(tz, dt(2011, 12, 29, 20, 0, 0, 0), hours(-10));
        assertUnambiguous(tz, dt(2011, 12, 29, 23, 59, 59, 999999999), hours(-10));
        // All of 2011-12-30 is a gap, 24 hours wide.
        assertGap(tz, dt(2011, 12, 30, 0, 0, 0, 0), hours(-10), hours(14));
        assertGap(tz, dt(2011, 12, 30, 12, 0, 0, 0), hours(-10), hours(14));
        assertGap(tz, dt(2011, 12, 30, 23, 59, 59, 999999999), hours(-10), hours(14));
        assertUnambiguous(tz, dt(2011, 12, 31, 0, 0, 0, 0), hours(14));
        assertUnambiguous(tz, dt(2011, 12, 31, 5, 0, 0, 0), hours(14));

        JiffAmbiguousTimestamp noon = tz.toAmbiguousTimestamp(dt(2011, 12, 30, 12, 0, 0, 0));
        Assert.areEqual('2011-12-30T22:00:00Z', noon.compatible().toString());
        Assert.areEqual('2011-12-29T22:00:00Z', noon.earlier().toString());
        Assert.areEqual('2011-12-30T22:00:00Z', noon.later().toString());
        // Noon on the missing day lands on noon of the day after.
        Assert.areEqual(dt(2011, 12, 31, 12, 0, 0, 0), tz.toDateTime(noon.compatible()));
        Assert.areEqual(dt(2011, 12, 29, 12, 0, 0, 0), tz.toDateTime(noon.earlier()));
        Assert.areEqual(
            '2011-12-30T10:00:00Z',
            tz.toTimestamp(dt(2011, 12, 31, 0, 0, 0, 0)).toString()
        );
        Assert.areEqual(
            '2011-12-30T09:59:59.999999999Z',
            tz.toTimestamp(dt(2011, 12, 29, 23, 59, 59, 999999999)).toString()
        );
    }

    @IsTest
    static void toTimestampResolvesGapsAndFoldsCompatibly() {
        JiffTimeZone tz = zone('America/New_York');
        // A gap: 02:30 does not exist, and becomes 03:30.
        Assert.areEqual(
            '2024-03-10T07:30:00Z',
            tz.toTimestamp(dt(2024, 3, 10, 2, 30, 0, 0)).toString()
        );
        // A fold: 01:30 happens twice, and means the first, while still in daylight time.
        Assert.areEqual(
            '2024-11-03T05:30:00Z',
            tz.toTimestamp(dt(2024, 11, 3, 1, 30, 0, 0)).toString()
        );
        Assert.areEqual(
            '2024-06-30T12:36:00Z',
            tz.toTimestamp(dt(2024, 6, 30, 8, 36, 0, 0)).toString()
        );
    }

    @IsTest
    static void toAmbiguousTimestampOffersEveryResolution() {
        JiffTimeZone tz = zone('America/New_York');
        JiffAmbiguousTimestamp plain = tz.toAmbiguousTimestamp(dt(2024, 7, 10, 17, 15, 0, 0));
        Assert.areEqual(dt(2024, 7, 10, 17, 15, 0, 0), plain.toDateTime());
        Assert.isFalse(plain.isAmbiguous());
        Assert.areEqual(
            '2024-03-10T06:00:00Z',
            tz.toAmbiguousTimestamp(dt(2024, 3, 10, 1, 0, 0, 0)).unambiguous().toString()
        );

        JiffAmbiguousTimestamp gap = tz.toAmbiguousTimestamp(dt(2024, 3, 10, 2, 30, 0, 0));
        Assert.isTrue(gap.isAmbiguous());
        Assert.areEqual('2024-03-10T07:30:00Z', gap.compatible().toString());
        Assert.areEqual('2024-03-10T06:30:00Z', gap.earlier().toString());
        Assert.areEqual('2024-03-10T07:30:00Z', gap.later().toString());
        // The earlier instant shows 01:30 on the clock and the later one 03:30.
        Assert.areEqual(dt(2024, 3, 10, 1, 30, 0, 0), tz.toDateTime(gap.earlier()));
        Assert.areEqual(dt(2024, 3, 10, 3, 30, 0, 0), tz.toDateTime(gap.later()));

        JiffAmbiguousTimestamp fold = tz.toAmbiguousTimestamp(dt(2024, 11, 3, 1, 30, 0, 0));
        Assert.isTrue(fold.isAmbiguous());
        Assert.areEqual('2024-11-03T05:30:00Z', fold.compatible().toString());
        Assert.areEqual('2024-11-03T05:30:00Z', fold.earlier().toString());
        Assert.areEqual('2024-11-03T06:30:00Z', fold.later().toString());
        Assert.areEqual(dt(2024, 11, 3, 1, 30, 0, 0), tz.toDateTime(fold.earlier()));
        Assert.areEqual(dt(2024, 11, 3, 1, 30, 0, 0), tz.toDateTime(fold.later()));

        for (
            JiffDateTime ambiguous : new List<JiffDateTime>{
                dt(2024, 3, 10, 2, 0, 0, 0),
                dt(2024, 11, 3, 1, 0, 0, 0)
            }
        ) {
            try {
                tz.toAmbiguousTimestamp(ambiguous).unambiguous();
                Assert.fail('expected ' + ambiguous + ' to be ambiguous');
            } catch (JiffException e) {
                Assert.isTrue(e.getMessage().contains('datetime is ambiguous'), e.getMessage());
            }
        }
    }

    @IsTest
    static void civilTimesAtTheEdgeOfTheRangeOverflow() {
        JiffTimeZone tz = zone('America/New_York');
        assertUnambiguous(tz, JiffDateTime.MAX, hours(-5));
        try {
            tz.toTimestamp(JiffDateTime.MAX);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.areEqual(
                'converting datetime with time zone offset `-05` to timestamp overflowed: ' +
                RANGE_SECONDS,
                e.getMessage()
            );
        }
        // The first day of the civil range is before the first timestamp in any western zone.
        try {
            tz.toTimestamp(JiffDateTime.MIN);
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('to timestamp overflowed'), e.getMessage());
        }
    }

    // ---- transitions ----------------------------------------------------

    @IsTest
    static void newYorkPreviousTransitions() {
        JiffTimeZone tz = zone('America/New_York');
        assertPrevious(tz, utc(2024, 3, 10, 8), utc(2024, 3, 10, 7));
        // One nanosecond after a transition, the previous transition is that one.
        assertPrevious(tz, JiffTimestamp.newInstance(1710054000L, 1), utc(2024, 3, 10, 7));
        // Exactly at a transition, it is the one before.
        assertPrevious(tz, utc(2024, 3, 10, 7), utc(2023, 11, 5, 6));
        assertPrevious(tz, utc(2023, 11, 5, 6), utc(2023, 3, 12, 7));
        assertPrevious(tz, utc(2000, 4, 2, 8), utc(2000, 4, 2, 7));
        assertPrevious(tz, JiffTimestamp.newInstance(954658800L, 1), utc(2000, 4, 2, 7));
        assertPrevious(tz, utc(2000, 4, 2, 7), utc(1999, 10, 31, 6));
        assertPrevious(tz, utc(1999, 10, 31, 6), utc(1999, 4, 4, 7));
        assertPrevious(tz, utc(1970, 6, 1, 0), utc(1970, 4, 26, 7));
    }

    @IsTest
    static void newYorkNextTransitions() {
        JiffTimeZone tz = zone('America/New_York');
        assertNext(tz, utc(2024, 3, 10, 6), utc(2024, 3, 10, 7));
        // One nanosecond before a transition, the next transition is that one.
        assertNext(tz, JiffTimestamp.newInstance(1710053999L, 999999999), utc(2024, 3, 10, 7));
        // Exactly at a transition, it is the one after.
        assertNext(tz, utc(2024, 3, 10, 7), utc(2024, 11, 3, 6));
        assertNext(tz, utc(2024, 11, 3, 6), utc(2025, 3, 9, 7));
        assertNext(tz, utc(1969, 12, 31, 19), utc(1970, 4, 26, 7));
        assertNext(tz, utc(2000, 4, 2, 6), utc(2000, 4, 2, 7));
        assertNext(tz, JiffTimestamp.newInstance(954658799L, 999999999), utc(2000, 4, 2, 7));
        assertNext(tz, utc(2000, 4, 2, 7), utc(2000, 10, 29, 6));
        assertNext(tz, utc(2000, 10, 29, 6), utc(2001, 4, 1, 7));
    }

    @IsTest
    static void transitionsBeforeTheEpochAreMeasuredInFlooredSeconds() {
        // New York's last transition before 1970 was at 1969-10-26T06:00:00Z. Around it the
        // timestamps are negative, and their fractions count backward.
        JiffTimeZone tz = zone('America/New_York');
        JiffTimestamp transition = sec(-5767200L);
        assertNext(tz, JiffTimestamp.newInstance(-5767200L, -1), transition);
        assertNext(tz, transition, utc(1970, 4, 26, 7));
        assertPrevious(tz, JiffTimestamp.newInstance(-5767199L, -999999999), transition);
        assertPrevious(tz, utc(1969, 12, 31, 19), transition);
    }

    @IsTest
    static void tasmanianTransitions() {
        JiffTimeZone tz = zone('Australia/Tasmania');
        assertPrevious(tz, utc(2010, 4, 3, 17), utc(2010, 4, 3, 16));
        assertPrevious(tz, JiffTimestamp.newInstance(1270310400L, 1), utc(2010, 4, 3, 16));
        assertPrevious(tz, utc(2010, 4, 3, 16), utc(2009, 10, 3, 16));
        assertPrevious(tz, utc(2009, 10, 3, 16), utc(2009, 4, 4, 16));
        assertPrevious(tz, utc(2000, 3, 25, 17), utc(2000, 3, 25, 16));
        assertPrevious(tz, utc(2000, 3, 25, 16), utc(1999, 10, 2, 16));
        assertPrevious(tz, utc(1999, 10, 2, 16), utc(1999, 3, 27, 16));
        assertNext(tz, utc(2010, 4, 3, 15), utc(2010, 4, 3, 16));
        assertNext(tz, JiffTimestamp.newInstance(1270310399L, 999999999), utc(2010, 4, 3, 16));
        assertNext(tz, utc(2010, 4, 3, 16), utc(2010, 10, 2, 16));
        assertNext(tz, utc(2010, 10, 2, 16), utc(2011, 4, 2, 16));
        assertNext(tz, utc(2000, 3, 25, 15), utc(2000, 3, 25, 16));
        // Daylight saving time started early in 2000, for the Sydney Olympics.
        assertNext(tz, utc(2000, 3, 25, 16), utc(2000, 8, 26, 16));
        assertNext(tz, utc(2000, 8, 26, 16), utc(2001, 3, 24, 16));
    }

    @IsTest
    static void dublinTransitions() {
        JiffTimeZone tz = zone('Europe/Dublin');
        assertPrevious(tz, utc(2010, 3, 28, 2), utc(2010, 3, 28, 1));
        assertPrevious(tz, JiffTimestamp.newInstance(1269738000L, 1), utc(2010, 3, 28, 1));
        assertPrevious(tz, utc(2010, 3, 28, 1), utc(2009, 10, 25, 1));
        assertPrevious(tz, utc(2009, 10, 25, 1), utc(2009, 3, 29, 1));
        assertPrevious(tz, utc(1990, 3, 25, 2), utc(1990, 3, 25, 1));
        assertPrevious(tz, utc(1990, 3, 25, 1), utc(1989, 10, 29, 1));
        assertPrevious(tz, utc(1989, 10, 25, 1), utc(1989, 3, 26, 1));
        assertNext(tz, utc(2010, 3, 28, 0), utc(2010, 3, 28, 1));
        assertNext(tz, JiffTimestamp.newInstance(1269737999L, 999999999), utc(2010, 3, 28, 1));
        assertNext(tz, utc(2010, 3, 28, 1), utc(2010, 10, 31, 1));
        assertNext(tz, utc(2010, 10, 31, 1), utc(2011, 3, 27, 1));
        assertNext(tz, utc(1990, 3, 25, 0), utc(1990, 3, 25, 1));
        assertNext(tz, utc(1990, 3, 25, 1), utc(1990, 10, 28, 1));
        assertNext(tz, utc(1990, 10, 28, 1), utc(1991, 3, 31, 1));
    }

    @IsTest
    static void londonAndSydneyTransitions() {
        JiffTimeZone london = zone('Europe/London');
        assertPrevious(london, utc(2024, 6, 1, 0), utc(2024, 3, 31, 1));
        assertNext(london, utc(2024, 6, 1, 0), utc(2024, 10, 27, 1));
        assertPrevious(london, utc(2024, 3, 31, 1), utc(2023, 10, 29, 1));
        assertNext(london, utc(2024, 10, 27, 1), utc(2025, 3, 30, 1));
        // Britain made no change from 1968 until it returned to GMT in October 1971.
        assertNext(london, JiffTimestamp.UNIX_EPOCH, utc(1971, 10, 31, 2));
        assertNext(london, utc(1971, 10, 31, 2), utc(1972, 3, 19, 2));
        JiffTimeZone sydney = zone('Australia/Sydney');
        assertPrevious(sydney, utc(2024, 6, 1, 0), utc(2024, 4, 6, 16));
        assertNext(sydney, utc(2024, 6, 1, 0), utc(2024, 10, 5, 16));
        assertPrevious(sydney, utc(2024, 1, 1, 0), utc(2023, 9, 30, 16));
        assertNext(sydney, utc(2024, 1, 1, 0), utc(2024, 4, 6, 16));
        // Zurich: the first transition after 2025-02-25 is at 03:00 local time on March 30.
        JiffTimeZoneTransition zurich = zone('Europe/Zurich').nextTransition(utc(2025, 2, 25, 0));
        Assert.areEqual('2025-03-30T01:00:00Z', zurich.toTimestamp().toString());
        Assert.areEqual(hours(2), zurich.offset());
        Assert.areEqual(JiffDst.YES, zurich.dst());
        Assert.areEqual(
            dt(2025, 3, 30, 3, 0, 0, 0),
            zone('Europe/Zurich').toDateTime(zurich.toTimestamp())
        );
    }

    @IsTest
    static void aZoneThatStoppedChangingHasNoNextTransition() {
        // Brazil abolished daylight saving time in 2019.
        JiffTimeZone saoPaulo = zone('America/Sao_Paulo');
        assertPrevious(saoPaulo, utc(2024, 3, 10, 8), utc(2019, 2, 17, 2));
        assertNext(saoPaulo, utc(2024, 3, 10, 8), null);
        assertNext(saoPaulo, utc(2019, 2, 17, 2), null);
        assertPrevious(saoPaulo, utc(2019, 2, 17, 2), utc(2018, 11, 4, 3));
        assertNext(saoPaulo, utc(2018, 11, 4, 3), utc(2019, 2, 17, 2));
        assertPrevious(saoPaulo, utc(2018, 11, 4, 3), utc(2018, 2, 18, 2));
    }

    @IsTest
    static void indiaHasNotChangedItsClocksSince1945() {
        JiffTimeZone tz = zone('Asia/Kolkata');
        assertNext(tz, utc(2024, 3, 10, 8), null);
        assertNext(tz, JiffTimestamp.UNIX_EPOCH, null);
        JiffTimeZoneTransition last = tz.previousTransition(utc(2024, 3, 10, 8));
        Assert.areEqual('1945-10-14T17:30:00Z', last.toTimestamp().toString());
        Assert.areEqual(JiffOffset.fromSeconds(19800), last.offset());
        Assert.areEqual(JiffDst.NO, last.dst());
        Assert.areEqual('IST', last.abbreviation());
    }

    @IsTest
    static void aNamedZoneThatNeverChangesHasNoTransitions() {
        JiffTimeZone tz = zone('Etc/GMT+5');
        assertPrevious(tz, utc(2024, 3, 10, 2), null);
        assertNext(tz, utc(2024, 3, 10, 2), null);
    }

    @IsTest
    static void transitionsAreSoughtOnlyWhereZoneDataHasThem() {
        // Nothing in the time zone database changes before 1844.
        for (
            String name : new List<String>{
                'America/New_York',
                'Australia/Tasmania',
                'Europe/Dublin'
            }
        ) {
            assertPrevious(zone(name), utc(-9999, 1, 31, 0), null);
            assertPrevious(zone(name), utc(1800, 1, 1, 0), null);
        }
        // Far in the future, a zone with a yearly rule keeps following it.
        JiffTimestamp distant = utc(9999, 12, 1, 0);
        assertPrevious(zone('America/New_York'), distant, utc(9999, 11, 7, 6));
        assertNext(zone('America/New_York'), distant, null);
        assertPrevious(zone('Australia/Tasmania'), distant, utc(9999, 10, 2, 16));
        assertNext(zone('Australia/Tasmania'), distant, null);
        assertPrevious(zone('Europe/Dublin'), distant, utc(9999, 10, 31, 1));
        assertNext(zone('Europe/Dublin'), distant, null);
        // ...and a zone without one is searched back to its last change.
        assertPrevious(zone('America/Sao_Paulo'), distant, utc(2019, 2, 17, 2));
        assertNext(zone('America/New_York'), JiffTimestamp.MAX, null);
        assertPrevious(zone('America/New_York'), JiffTimestamp.MIN, null);
    }

    @IsTest
    static void walkingBackwardVisitsEachTransitionInTurn() {
        // Jiff's `preceding` example: the five transitions before 2024-12-31T18:25-05.
        JiffTimeZone tz = zone('America/New_York');
        List<String> seen = new List<String>();
        JiffTimestamp cursor = sec(1735687500L);
        for (Integer i = 0; i < 5; i++) {
            JiffTimeZoneTransition transition = tz.previousTransition(cursor);
            cursor = transition.toTimestamp();
            seen.add(
                tz.toDateTime(cursor).toString() +
                    ' ' +
                    transition.offset() +
                    ' ' +
                    transition.abbreviation()
            );
        }
        Assert.areEqual(
            new List<String>{
                '2024-11-03T01:00:00 -05 EST',
                '2024-03-10T03:00:00 -04 EDT',
                '2023-11-05T01:00:00 -05 EST',
                '2023-03-12T03:00:00 -04 EDT',
                '2022-11-06T01:00:00 -05 EST'
            },
            seen
        );
    }

    @IsTest
    static void walkingForwardVisitsEachTransitionInTurn() {
        // Jiff's `following` example: the five transitions after 2024-12-31T18:25-05.
        JiffTimeZone tz = zone('America/New_York');
        List<String> seen = new List<String>();
        JiffTimestamp cursor = sec(1735687500L);
        for (Integer i = 0; i < 5; i++) {
            JiffTimeZoneTransition transition = tz.nextTransition(cursor);
            cursor = transition.toTimestamp();
            seen.add(
                tz.toDateTime(cursor).toString() +
                    ' ' +
                    transition.offset() +
                    ' ' +
                    transition.abbreviation()
            );
        }
        Assert.areEqual(
            new List<String>{
                '2025-03-09T03:00:00 -04 EDT',
                '2025-11-02T01:00:00 -05 EST',
                '2026-03-08T03:00:00 -04 EDT',
                '2026-11-01T01:00:00 -05 EST',
                '2027-03-14T03:00:00 -04 EDT'
            },
            seen
        );
    }

    @IsTest
    static void aTransitionDescribesWhatFollowsIt() {
        JiffTimeZone tz = zone('America/New_York');
        // 2024-03-09T00:00 in New York.
        JiffTimestamp start = tz.toTimestamp(dt(2024, 3, 9, 0, 0, 0, 0));
        Assert.areEqual(sec(1709960400L), start);
        JiffTimeZoneTransition next = tz.nextTransition(start);
        Assert.areEqual('2024-03-10T07:00:00Z', next.toTimestamp().toString());
        Assert.areEqual(dt(2024, 3, 10, 3, 0, 0, 0), tz.toDateTime(next.toTimestamp()));
        Assert.areEqual(hours(-4), next.offset());
        Assert.areEqual('EDT', next.abbreviation());
        Assert.areEqual(JiffDst.YES, next.dst());
        JiffTimeZoneTransition previous = tz.previousTransition(start);
        Assert.areEqual('2023-11-05T06:00:00Z', previous.toTimestamp().toString());
        Assert.areEqual(hours(-5), previous.offset());
        Assert.areEqual('EST', previous.abbreviation());
        Assert.areEqual(JiffDst.NO, previous.dst());
    }

    @IsTest
    static void transitionsAWeekApartAreBothFound() {
        // Boa Vista's last four transitions; the final two are seven days less an hour apart,
        // the closest any zone has come to undoing a change.
        JiffTimeZone tz = zone('America/Boa_Vista');
        List<JiffTimestamp> lastFour = new List<JiffTimestamp>{
            utc(1999, 10, 3, 4),
            utc(2000, 2, 27, 3),
            utc(2000, 10, 8, 4),
            utc(2000, 10, 15, 3)
        };
        JiffTimestamp cursor = utc(2001, 1, 1, 0);
        for (Integer i = 3; i >= 0; i--) {
            JiffTimeZoneTransition transition = tz.previousTransition(cursor);
            Assert.areEqual(lastFour.get(i), transition.toTimestamp());
            cursor = transition.toTimestamp();
        }
        cursor = utc(1990, 1, 1, 0);
        for (Integer i = 0; i < 4; i++) {
            JiffTimeZoneTransition transition = tz.nextTransition(cursor);
            Assert.areEqual(lastFour.get(i), transition.toTimestamp());
            cursor = transition.toTimestamp();
        }
        Assert.isNull(tz.nextTransition(cursor));
        JiffTimeZoneTransition summer = tz.previousTransition(utc(2000, 10, 15, 3));
        Assert.areEqual(hours(-3), summer.offset());
        Assert.areEqual(JiffDst.YES, summer.dst());
        JiffTimeZoneTransition winter = tz.previousTransition(utc(2001, 1, 1, 0));
        Assert.areEqual(hours(-4), winter.offset());
        Assert.areEqual(JiffDst.NO, winter.dst());
    }

    @IsTest
    static void theDateLineSkipIsOneTransition() {
        JiffTimeZone tz = zone('Pacific/Apia');
        JiffTimestamp skip = sec(1325239200L);
        Assert.areEqual('2011-12-30T10:00:00Z', skip.toString());
        JiffTimeZoneTransition next = tz.nextTransition(utc(2011, 12, 1, 0));
        Assert.areEqual(skip, next.toTimestamp());
        Assert.areEqual(hours(14), next.offset());
        Assert.areEqual(JiffDst.YES, next.dst());
        assertPrevious(tz, utc(2011, 12, 31, 0), skip);
        assertPrevious(tz, utc(2012, 1, 1, 0), skip);
        assertPrevious(tz, skip, sec(1316872800L));
        assertNext(tz, skip, sec(1333202400L));
        // Samoa dropped daylight saving time in 2021.
        assertPrevious(tz, utc(2024, 1, 1, 0), sec(1617458400L));
        assertNext(tz, utc(2024, 1, 1, 0), null);
    }

    // ---- civil to zoned datetime ----------------------------------------

    @IsTest
    static void toZonedDateTimeResolvesGapsAndFoldsCompatibly() {
        JiffTimeZone tz = zone('America/New_York');
        // This demonstrates disambiguation behavior for a gap.
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            tz.toZonedDateTime(dt(2024, 3, 10, 2, 30, 0, 0)).toString()
        );
        // This demonstrates disambiguation behavior for a fold. Notice the offset: the -04
        // corresponds to the time while still in DST.
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            tz.toZonedDateTime(dt(2024, 11, 3, 1, 30, 0, 0)).toString()
        );
        Assert.areEqual(
            '2024-07-04T12:00:00+05:30[Asia/Kolkata]',
            zone('Asia/Kolkata').toZonedDateTime(dt(2024, 7, 4, 12, 0, 0, 0)).toString()
        );
        Assert.areEqual(
            '2024-07-04T12:00:00-05:00[-05:00]',
            JiffTimeZone.fixed(hours(-5)).toZonedDateTime(dt(2024, 7, 4, 12, 0, 0, 0)).toString()
        );
        Assert.areEqual(
            '2024-03-31T01:30:00Z[Etc/Unknown]',
            JiffTimeZone.unknown().toZonedDateTime(dt(2024, 3, 31, 1, 30, 0, 0)).toString()
        );
    }

    @IsTest
    static void toZonedDateTimeNamesTheZoneWhenTheInstantIsOutOfRange() {
        try {
            JiffTimeZone.UTC.toZonedDateTime(JiffDateTime.MAX);
            Assert.fail('expected the maximum datetime to have no instant in UTC');
        } catch (JiffException e) {
            Assert.areEqual(
                'error converting datetime to instant in time zone UTC: converting datetime ' +
                    'with time zone offset `+00` to timestamp overflowed: ' +
                    RANGE_SECONDS,
                e.getMessage()
            );
        }
    }

    @IsTest
    static void toAmbiguousZonedDateTimeLeavesTheChoiceOpen() {
        JiffTimeZone tz = zone('America/New_York');
        // This is not ambiguous:
        JiffAmbiguousZonedDateTime plain = tz.toAmbiguousZonedDateTime(dt(2024, 3, 10, 1, 0, 0, 0));
        Assert.isFalse(plain.isAmbiguous());
        Assert.areEqual(
            '2024-03-10T01:00:00-05:00[America/New_York]',
            plain.unambiguous().toString()
        );
        Assert.areEqual(tz, plain.timeZone());
        // But this is a gap, and thus ambiguous! So an error is returned.
        JiffAmbiguousZonedDateTime gap = tz.toAmbiguousZonedDateTime(dt(2024, 3, 10, 2, 0, 0, 0));
        Assert.areEqual(JiffAmbiguousOffset.gap(hours(-5), hours(-4)), gap.offset());
        try {
            gap.unambiguous();
            Assert.fail('expected a datetime in a gap to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('gap'), e.getMessage());
        }
        // And so is this, because it's a fold.
        JiffAmbiguousZonedDateTime fold = tz.toAmbiguousZonedDateTime(dt(2024, 11, 3, 1, 0, 0, 0));
        Assert.areEqual(JiffAmbiguousOffset.fold(hours(-4), hours(-5)), fold.offset());
        try {
            fold.unambiguous();
            Assert.fail('expected a datetime in a fold to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('fold'), e.getMessage());
        }
        // It carries the same answer as the ambiguous timestamp.
        Assert.areEqual(
            tz.toAmbiguousTimestamp(dt(2024, 11, 3, 1, 0, 0, 0)).later(),
            fold.later().toTimestamp()
        );
    }
}
