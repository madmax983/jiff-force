/**
 * The getters, setters, conversions and assembly rules of `JiffBrokenDownTime`.
 *
 * Expected values come from the doc examples of `jiff::fmt::strtime::BrokenDownTime` and the
 * tests in Jiff's `fmt::strtime` module, or from running Jiff 1.0.0 on the same input.
 */
@IsTest
private class JiffBrokenDownTimeTest {
    private static JiffZonedDateTime newYork(Integer year, Integer month, Integer day) {
        return JiffDate.newInstance(year, month, day).at(14, 56, 0, 0).inTz('America/New_York');
    }

    private static void assertFails(JiffBrokenDownTime tm, String format, String message) {
        try {
            tm.format(format);
            Assert.fail('expected formatting ' + format + ' to fail');
        } catch (JiffException e) {
            Assert.areEqual(message, e.getMessage());
        }
    }

    // ---- getters after parsing -----------------------------------------------

    @IsTest
    static void aNewBrokenDownTimeHasNoFields() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        Assert.isNull(tm.year());
        Assert.isNull(tm.month());
        Assert.isNull(tm.day());
        Assert.isNull(tm.dayOfYear());
        Assert.isNull(tm.isoWeekYear());
        Assert.isNull(tm.isoWeek());
        Assert.isNull(tm.sundayBasedWeek());
        Assert.isNull(tm.mondayBasedWeek());
        Assert.isNull(tm.hour());
        Assert.isNull(tm.minute());
        Assert.isNull(tm.second());
        Assert.isNull(tm.subsecNanosecond());
        Assert.isNull(tm.offset());
        Assert.isNull(tm.ianaTimeZone());
        Assert.isNull(tm.weekday());
        Assert.isNull(tm.meridiem());
        Assert.isNull(tm.timestamp());
        Assert.areEqual('00:00:00', tm.toTime().toString());
    }

    @IsTest
    static void parsedFieldsAreAvailable() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%G-W%V-%u', '2020-W01-1');
        Assert.areEqual(2020, tm.isoWeekYear());
        Assert.areEqual(1, tm.isoWeek());
        Assert.areEqual(JiffWeekday.MONDAY, tm.weekday());
        Assert.areEqual(JiffDate.newInstance(2019, 12, 30), tm.toDate());

        tm = JiffBrokenDownTime.parse('%Y-%U-%w', '2025-01-0');
        Assert.areEqual(2025, tm.year());
        Assert.areEqual(1, tm.sundayBasedWeek());
        Assert.areEqual(JiffWeekday.SUNDAY, tm.weekday());
        Assert.areEqual(JiffDate.newInstance(2025, 1, 5), tm.toDate());

        tm = JiffBrokenDownTime.parse('%Y-%W-%w', '2025-01-1');
        Assert.areEqual(1, tm.mondayBasedWeek());
        Assert.areEqual(JiffDate.newInstance(2025, 1, 6), tm.toDate());
    }

    @IsTest
    static void parsedHourIncludesTheMeridiem() {
        Assert.areEqual(13, JiffBrokenDownTime.parse('%H', '13').hour());
        Assert.areEqual(1, JiffBrokenDownTime.parse('%I', '1').hour());
        Assert.areEqual(13, JiffBrokenDownTime.parse('%I%P', '1pm').hour());
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%H%P', '13am');
        Assert.areEqual(1, tm.hour());
        Assert.areEqual(JiffMeridiem.AM, tm.meridiem());
        Assert.areEqual(JiffMeridiem.PM, JiffBrokenDownTime.parse('%P', 'pm').meridiem());
    }

    @IsTest
    static void parsedOffsetAndTimeZoneAreAvailable() {
        Assert.areEqual(
            JiffOffset.fromSeconds(-16200),
            JiffBrokenDownTime.parse('%z', '-0430').offset()
        );
        Assert.areEqual(
            JiffOffset.fromSeconds(-16259),
            JiffBrokenDownTime.parse('%z', '-043059').offset()
        );
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%Q', 'America/New_York');
        Assert.areEqual('America/New_York', tm.ianaTimeZone());
        Assert.isNull(tm.offset());
        tm = JiffBrokenDownTime.parse('%Q', '-0400');
        Assert.isNull(tm.ianaTimeZone());
        Assert.areEqual(JiffOffset.fromHours(-4), tm.offset());
    }

    @IsTest
    static void aWeekdayIsOnlyAvailableWhenParsed() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%F', '2024-07-27');
        Assert.isNull(tm.weekday());
        Assert.areEqual(JiffWeekday.SATURDAY, tm.toDate().weekday());
    }

    @IsTest
    static void aParsedWeekdayIsCheckedOnlyWhenAssemblingADate() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse('%a, %F', 'Wed, 2024-07-27');
        Assert.areEqual(JiffWeekday.WEDNESDAY, tm.weekday());
        try {
            tm.toDate();
            Assert.fail('expected the wrong weekday to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsed weekday `Wednesday` does not match weekday `Saturday` from parsed date',
                e.getMessage()
            );
        }
        Assert.areEqual(JiffDate.newInstance(2024, 7, 27), tm.withWeekday(null).toDate());
    }

    @IsTest
    static void dayOfYearIsKeptEvenWhenMonthAndDayDecide() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse(
            '%Y-%m-%d (day of year: %j)',
            '2024-02-29 (day of year: 1)'
        );
        Assert.areEqual(JiffDate.newInstance(2024, 2, 29), tm.toDate());
        Assert.areEqual(1, tm.dayOfYear());
        tm = JiffBrokenDownTime.parse('%j', '5');
        Assert.areEqual('005', tm.format('%j'));
        Assert.areEqual('5', tm.format('%-j'));
    }

    @IsTest
    static void anInvalidDateIsOnlyRejectedWhenAssembled() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse(
            '%Y-%m-%d %H:%M:%S',
            '2024-06-31 21:14:59'
        );
        Assert.areEqual('21:14:59', tm.toTime().toString());
        try {
            tm.toDate();
            Assert.fail('expected June 31 to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'invalid date: parameter \'day\' for `2024-06` is invalid, must be in range `1..=30`',
                e.getMessage()
            );
        }
    }

    // ---- conversions from datetime types ---------------------------------------

    @IsTest
    static void fromDateSetsOnlyTheDate() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDate(JiffDate.newInstance(2024, 7, 14));
        Assert.areEqual(2024, tm.year());
        Assert.areEqual(7, tm.month());
        Assert.areEqual(14, tm.day());
        Assert.isNull(tm.hour());
        Assert.isNull(tm.weekday());
        Assert.isNull(tm.meridiem());
    }

    @IsTest
    static void fromTimeSetsTheTimeAndMeridiem() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromTime(JiffTime.newInstance(17, 30, 59, 5));
        Assert.areEqual(17, tm.hour());
        Assert.areEqual(30, tm.minute());
        Assert.areEqual(59, tm.second());
        Assert.areEqual(5, tm.subsecNanosecond());
        Assert.areEqual(JiffMeridiem.PM, tm.meridiem());
        Assert.isNull(tm.year());
        Assert.areEqual(
            JiffMeridiem.AM,
            JiffBrokenDownTime.fromTime(JiffTime.newInstance(11, 59, 59, 0)).meridiem()
        );
    }

    @IsTest
    static void fromIsoWeekDateSetsTheWeekFields() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromIsoWeekDate(
            JiffIsoWeekDate.newInstance(2020, 1, JiffWeekday.MONDAY)
        );
        Assert.areEqual(2020, tm.isoWeekYear());
        Assert.areEqual(1, tm.isoWeek());
        Assert.areEqual(JiffWeekday.MONDAY, tm.weekday());
        Assert.areEqual('2019-12-30', tm.format('%F'));
    }

    @IsTest
    static void fromTimestampIsInUtc() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromTimestamp(JiffTimestamp.fromSecond(86400L));
        Assert.areEqual(JiffOffset.UTC, tm.offset());
        Assert.areEqual(JiffTimestamp.fromSecond(86400L), tm.timestamp());
        Assert.areEqual('1970-01-02 00:00:00 +0000', tm.format('%F %T %z'));
        Assert.isNull(tm.ianaTimeZone());
        assertFails(
            tm,
            '%Z',
            'strftime formatting failed: %Z failed: requires IANA time zone identifier'
        );
    }

    @IsTest
    static void fromZonedDateTimeTakesTheZoneName() {
        JiffZonedDateTime zdt = JiffDate.newInstance(2024, 7, 15)
            .at(16, 24, 59, 0)
            .inTz('America/New_York');
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromZonedDateTime(zdt);
        Assert.areEqual('America/New_York', tm.ianaTimeZone());
        Assert.areEqual(zdt.toTimestamp(), tm.timestamp());
        Assert.areEqual(JiffOffset.fromHours(-4), tm.offset());
        Assert.areEqual('America/New_York EDT', tm.format('%Q %Z'));

        // Clearing the name keeps the zone for the abbreviation.
        tm = tm.withIanaTimeZone(null);
        Assert.isNull(tm.ianaTimeZone());
        Assert.areEqual('-0400 EDT', tm.format('%Q %Z'));
        tm = tm.withIanaTimeZone('Australia/Tasmania');
        Assert.areEqual('Australia/Tasmania', tm.ianaTimeZone());
    }

    @IsTest
    static void theUnknownTimeZoneHasNoNameAndIsAbbreviatedUtc() {
        JiffZonedDateTime zdt = JiffTimestamp.UNIX_EPOCH.toZonedDateTime(JiffTimeZone.unknown());
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromZonedDateTime(zdt);
        Assert.isNull(tm.ianaTimeZone());
        Assert.areEqual('+0000 UTC', tm.format('%Q %Z'));
    }

    @IsTest
    static void conversionsRejectNull() {
        Integer failures = 0;
        try {
            JiffBrokenDownTime.fromDate(null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffBrokenDownTime.fromTime(null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffBrokenDownTime.fromDateTime(null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffBrokenDownTime.fromIsoWeekDate(null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffBrokenDownTime.fromTimestamp(null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffBrokenDownTime.fromZonedDateTime(null);
        } catch (JiffException e) {
            Assert.areEqual(
                'cannot make a broken down time from a null zoned datetime',
                e.getMessage()
            );
            failures++;
        }
        Assert.areEqual(6, failures);
    }

    // ---- setters ----------------------------------------------------------------

    @IsTest
    static void settersCheckTheRangeOfEachField() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        List<String> messages = new List<String>();
        try {
            tm.withYear(10000);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withMonth(0);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withDay(32);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withDayOfYear(367);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withIsoWeekYear(10000);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withIsoWeek(0);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withIsoWeek(54);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withSundayBasedWeek(56);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withMondayBasedWeek(56);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withHour(24);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withMinute(60);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withSecond(60);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            tm.withSubsecNanosecond(1000000000);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'parameter \'year\' is not in the required range of -9999..=9999',
                'parameter \'month\' is not in the required range of 1..=12',
                'parameter \'day\' is not in the required range of 1..=31',
                'parameter \'day-of-year\' is not in the required range of 1..=366',
                'parameter \'iso-year\' is not in the required range of -9999..=9999',
                'parameter \'iso-week\' is not in the required range of 1..=53',
                'parameter \'iso-week\' is not in the required range of 1..=53',
                'parameter \'week-number\' is not in the required range of 0..=53',
                'parameter \'week-number\' is not in the required range of 0..=53',
                'parameter \'hour\' is not in the required range of 0..=23',
                'parameter \'minute\' is not in the required range of 0..=59',
                'parameter \'second\' is not in the required range of 0..=59',
                'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
            },
            messages
        );
    }

    @IsTest
    static void settersFormatLikeJiffsDocExamples() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime();
        Assert.areEqual('2024', tm.withYear(2024).format('%Y'));
        Assert.areEqual('December', tm.withMonth(12).format('%B'));
        Assert.areEqual('31', tm.withDay(31).format('%d'));
        Assert.areEqual('2024-04-31', tm.withYear(2024).withMonth(4).withDay(31).format('%F'));
        Assert.areEqual('031', tm.withDayOfYear(31).format('%j'));
        Assert.areEqual('2023/366', tm.withYear(2023).withDayOfYear(366).format('%Y/%j'));
        Assert.areEqual('2024', tm.withIsoWeekYear(2024).format('%G'));
        JiffBrokenDownTime week = tm.withIsoWeekYear(2020)
            .withIsoWeek(1)
            .withWeekday(JiffWeekday.MONDAY);
        Assert.areEqual('2020-W01-1', week.format('%G-W%V-%u'));
        Assert.areEqual('2019-12-30', week.format('%F'));
        Assert.areEqual('09', tm.withSundayBasedWeek(9).format('%U'));
        Assert.areEqual('09', tm.withMondayBasedWeek(9).format('%W'));
        Assert.areEqual('00', tm.withHour(0).format('%H'));
        Assert.areEqual('0', tm.withHour(0).format('%-H'));
        Assert.areEqual('59', tm.withMinute(59).format('%M'));
        Assert.areEqual('059', tm.withMinute(59).format('%03M'));
        Assert.areEqual(' 59', tm.withMinute(59).format('%_3M'));
        Assert.areEqual('59', tm.withSecond(59).format('%S'));
        Assert.areEqual('123', tm.withSubsecNanosecond(123000000).format('%f'));
        Assert.areEqual('.123000', tm.withSubsecNanosecond(123000000).format('%.6f'));
        JiffBrokenDownTime saturday = tm.withWeekday(JiffWeekday.SATURDAY);
        Assert.areEqual('Saturday', saturday.format('%A'));
        Assert.areEqual('Sat', saturday.format('%a'));
        Assert.areEqual('SAT', saturday.format('%^a'));
    }

    @IsTest
    static void settersReturnACopyAndNullClears() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime().withYear(2024).withMonth(7);
        JiffBrokenDownTime cleared = tm.withYear(null);
        Assert.areEqual(2024, tm.year());
        Assert.isNull(cleared.year());
        Assert.areEqual(7, cleared.month());
        JiffBrokenDownTime all = new JiffBrokenDownTime()
            .withYear(1)
            .withMonth(2)
            .withDay(3)
            .withDayOfYear(4)
            .withIsoWeekYear(5)
            .withIsoWeek(6)
            .withSundayBasedWeek(7)
            .withMondayBasedWeek(8)
            .withHour(9)
            .withMinute(10)
            .withSecond(11)
            .withSubsecNanosecond(12)
            .withOffset(JiffOffset.fromHours(13))
            .withIanaTimeZone('Etc/GMT-13')
            .withWeekday(JiffWeekday.FRIDAY)
            .withMeridiem(JiffMeridiem.AM)
            .withTimestamp(JiffTimestamp.UNIX_EPOCH);
        JiffBrokenDownTime none = all.withYear(null)
            .withMonth(null)
            .withDay(null)
            .withDayOfYear(null)
            .withIsoWeekYear(null)
            .withIsoWeek(null)
            .withSundayBasedWeek(null)
            .withMondayBasedWeek(null)
            .withHour(null)
            .withMinute(null)
            .withSecond(null)
            .withSubsecNanosecond(null)
            .withOffset(null)
            .withIanaTimeZone(null)
            .withWeekday(null)
            .withMeridiem(null)
            .withTimestamp(null);
        Assert.areEqual(1, all.year());
        Assert.areEqual(8, all.mondayBasedWeek());
        Assert.areEqual(9, all.hour());
        Assert.areEqual(JiffMeridiem.AM, all.meridiem());
        Assert.areEqual(
            '0001-02-03 4 0005 06 7 8 09:10:11.000000012 +13:00 Etc/GMT-13 Friday 0',
            all.format('%F %-j %G %V %-U %-W %T.%N %:z %Q %A %s')
        );
        Assert.isNull(none.year());
        Assert.isNull(none.timestamp());
        Assert.isNull(none.meridiem());
        Assert.isNull(none.ianaTimeZone());
    }

    @IsTest
    static void aMeridiemAdjustsTheHour() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime().withHour(3).withMeridiem(JiffMeridiem.PM);
        Assert.areEqual(15, tm.toTime().hour());
        tm = new JiffBrokenDownTime()
            .withHour(3)
            .withMinute(4)
            .withSecond(5)
            .withMeridiem(JiffMeridiem.PM);
        Assert.areEqual('15:04:05', tm.format('%T'));
        tm = new JiffBrokenDownTime()
            .withHour(13)
            .withMinute(4)
            .withSecond(5)
            .withMeridiem(JiffMeridiem.AM);
        Assert.areEqual('01:04:05', tm.format('%T'));
        // A meridiem set first applies to an hour set later.
        tm = new JiffBrokenDownTime().withMeridiem(JiffMeridiem.PM).withHour(12);
        Assert.areEqual(12, tm.hour());
        tm = new JiffBrokenDownTime().withMeridiem(JiffMeridiem.AM).withHour(12);
        Assert.areEqual(0, tm.hour());
    }

    @IsTest
    static void withoutAMeridiemTheHourDecidesAmOrPm() {
        Assert.areEqual(
            'PM pm pm 01',
            new JiffBrokenDownTime().withHour(13).format('%p %P %#p %I')
        );
        Assert.areEqual('AM am 12', new JiffBrokenDownTime().withHour(0).format('%p %P %l'));
    }

    @IsTest
    static void settingTheOffsetChangesNothingElse() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromZonedDateTime(newYork(2024, 8, 28))
            .withOffset(JiffOffset.fromHours(12));
        Assert.areEqual(
            '2024-08-28 at 14:56:00 in America/New_York +12:00',
            tm.format('%Y-%m-%d at %H:%M:%S in %Q %:z')
        );
    }

    @IsTest
    static void settingTheTimeZoneChangesNothingElse() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromZonedDateTime(newYork(2024, 8, 28));
        Assert.areEqual(
            '2024-08-28 at 14:56:00 in Australia/Hobart -04:00',
            tm.withIanaTimeZone('Australia/Hobart').format('%Y-%m-%d at %H:%M:%S in %Q %:z')
        );
        Assert.areEqual(
            '2024-08-28 at 14:56:00 in Clearly/Invalid -04:00',
            tm.withIanaTimeZone('Clearly/Invalid').format('%Y-%m-%d at %H:%M:%S in %Q %:z')
        );
    }

    @IsTest
    static void anOffsetOrTimeZoneCanBeSuppliedAfterParsing() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.parse(
            '%Y-%m-%d at %H:%M:%S',
            '1970-01-01 at 01:00:00'
        );
        Assert.areEqual(
            '1970-01-01T01:00:00Z',
            tm.withOffset(JiffOffset.UTC).toTimestamp().toString()
        );
        Assert.areEqual(
            '1970-01-01T01:00:00-05:00[America/New_York]',
            tm.withIanaTimeZone('America/New_York').toZonedDateTime().toString()
        );
    }

    @IsTest
    static void anExplicitTimestampWins() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime()
            .withYear(2025)
            .withMonth(10)
            .withDay(17)
            .withHour(13)
            .withMinute(45)
            .withOffset(JiffOffset.fromHours(-4));
        Assert.areEqual(JiffTimestamp.fromSecond(1760723100L), tm.toTimestamp());
        Assert.isNull(tm.timestamp());
        tm = tm.withTimestamp(JiffTimestamp.UNIX_EPOCH);
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, tm.timestamp());
        Assert.areEqual(JiffTimestamp.UNIX_EPOCH, tm.toTimestamp());
        Assert.areEqual('1969-12-31T20:00:00-04:00[-04:00]', tm.toZonedDateTime().toString());
    }

    @IsTest
    static void aTimestampAndAnOffsetMustAgreeWithTheTimeZone() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime()
            .withTimestamp(JiffTimestamp.fromSecond(1720000000L))
            .withIanaTimeZone('America/New_York');
        Assert.areEqual(
            '2024-07-03T05:46:40-04:00[America/New_York]',
            tm.toZonedDateTime().toString()
        );
        Assert.areEqual(
            '2024-07-03T05:46:40-04:00[America/New_York]',
            tm.withOffset(JiffOffset.fromHours(-4)).toZonedDateTime().toString()
        );
        try {
            tm.withOffset(JiffOffset.fromHours(-5)).toZonedDateTime();
            Assert.fail('expected the wrong offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsed time zone offset `-05`, but offset from timestamp and time zone is `-04`',
                e.getMessage()
            );
        }
    }

    // ---- assembly -----------------------------------------------------------------

    @IsTest
    static void toDateNeedsAYearAndADay() {
        try {
            new JiffBrokenDownTime().withMonth(7).withDay(25).toDate();
            Assert.fail('expected a missing year to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('year required to parse date', e.getMessage());
        }
        try {
            new JiffBrokenDownTime().withYear(2024).toDate();
            Assert.fail('expected a missing day to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'a month/day, day-of-year or week date must be present to create a date, but none were found',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void toDateTimeAndToTimeReportWhatIsMissing() {
        try {
            new JiffBrokenDownTime()
                .withYear(2024)
                .withMonth(1)
                .withDay(1)
                .withMinute(5)
                .toDateTime();
            Assert.fail('expected a minute without an hour to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'time required to parse datetime: parsing format did not include hour directive, but did include minute directive (cannot have smaller time units with bigger time units missing)',
                e.getMessage()
            );
        }
        List<String> messages = new List<String>();
        List<JiffBrokenDownTime> cases = new List<JiffBrokenDownTime>{
            new JiffBrokenDownTime().withSubsecNanosecond(1),
            new JiffBrokenDownTime().withHour(1).withSubsecNanosecond(1),
            new JiffBrokenDownTime().withHour(1).withMinute(1).withSubsecNanosecond(1),
            new JiffBrokenDownTime().withSecond(1)
        };
        for (JiffBrokenDownTime tm : cases) {
            try {
                tm.toTime();
            } catch (JiffException e) {
                messages.add(e.getMessage().substringBefore(' (cannot'));
            }
        }
        Assert.areEqual(
            new List<String>{
                'parsing format did not include hour directive, but did include fractional second directive',
                'parsing format did not include minute directive, but did include fractional second directive',
                'parsing format did not include second directive, but did include fractional second directive',
                'parsing format did not include hour directive, but did include second directive'
            },
            messages
        );
        Assert.areEqual(
            '01:02:03.000000004',
            new JiffBrokenDownTime()
                .withHour(1)
                .withMinute(2)
                .withSecond(3)
                .withSubsecNanosecond(4)
                .toTime()
                .toString()
        );
    }

    @IsTest
    static void toTimestampAndToZonedDateTimeReportWhatIsMissing() {
        JiffBrokenDownTime offsetOnly = new JiffBrokenDownTime()
            .withOffset(JiffOffset.fromHours(1));
        try {
            offsetOnly.toTimestamp();
            Assert.fail('expected a missing datetime to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime required to parse timestamp: date required to parse datetime: year required to parse date',
                e.getMessage()
            );
        }
        try {
            offsetOnly.withIanaTimeZone('America/New_York').toZonedDateTime();
            Assert.fail('expected a missing datetime to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime required to parse zoned datetime: date required to parse datetime: year required to parse date',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void aDatetimeAtTheEdgeOfTheRangeCannotBecomeATimestamp() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDateTime(JiffDateTime.MAX)
            .withOffset(JiffOffset.fromHours(-25));
        try {
            tm.toTimestamp();
            Assert.fail('expected the timestamp to be out of range');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsed datetime and offset, but combining them into a zoned datetime is outside Jiff\'s supported timestamp range: converting datetime with time zone offset `-25` to timestamp overflowed: parameter \'Unix timestamp seconds\' is not in the required range of -377705023201..=253402207200',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void weekDatesBeforeTheFirstWeekStartMustExist() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime()
            .withYear(2025)
            .withSundayBasedWeek(0)
            .withWeekday(JiffWeekday.TUESDAY);
        try {
            tm.toDate();
            Assert.fail('expected Tuesday of week 0 to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'weekday `Tuesday` is not valid for Sunday based week number',
                e.getMessage()
            );
        }
        Assert.areEqual(
            JiffDate.newInstance(2025, 1, 4),
            tm.withWeekday(JiffWeekday.SATURDAY).toDate()
        );
    }

    @IsTest
    static void formatNeedsAConfiguration() {
        try {
            new JiffBrokenDownTime().format('%Y', null);
            Assert.fail('expected a null configuration to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('strtime configuration must not be null', e.getMessage());
        }
    }

    @IsTest
    static void parsePrefixLeavesTheRestOfTheInput() {
        String input = '2024-01-20T17:55Z';
        JiffBrokenDownTimePrefix prefix = JiffBrokenDownTime.parsePrefix('%Y-%m-%d', input);
        Assert.areEqual(JiffDate.newInstance(2024, 1, 20), prefix.value().toDate());
        Assert.areEqual('T17:55Z', input.substring(prefix.consumed()));
    }
}
