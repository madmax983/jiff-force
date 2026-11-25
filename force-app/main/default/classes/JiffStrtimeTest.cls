/**
 * The `JiffStrtime` entry points and the `strftime` / `strptime` methods of the datetime
 * types.
 *
 * Expected values come from the doc examples of `jiff::fmt::strtime` and of the `strftime`
 * and `strptime` methods of `Date`, `Time`, `DateTime`, `Timestamp` and `ZonedDateTime` in
 * Jiff 1.0.0, and from Jiff's tests in `fmt::strtime`.
 */
@IsTest
private class JiffStrtimeTest {
    private static JiffZonedDateTime newYorkAfternoon() {
        return JiffDate.newInstance(2024, 7, 15).at(16, 24, 59, 0).inTz('America/New_York');
    }

    // ---- JiffStrtime ----------------------------------------------------------------

    @IsTest
    static void parsesADateAndItsWeekday() {
        JiffDate value = JiffStrtime.parse('%Y-%m-%d is a %A', '2024-07-15 is a Monday').toDate();
        Assert.areEqual('2024-07-15', value.toString());
        try {
            JiffStrtime.parse('%Y-%m-%d is a %A', '2024-07-15 is a Tuesday').toDate();
            Assert.fail('expected the wrong weekday to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parsed weekday `Tuesday` does not match weekday `Monday` from parsed date',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void parsesSomethingLikeRfc2822() {
        JiffZonedDateTime zdt = JiffStrtime.parse(
                '%a, %d %b %Y %T %z',
                'Mon, 15 Jul 2024 16:24:59 -0400'
            )
            .toZonedDateTime();
        Assert.areEqual('2024-07-15T16:24:59-04:00[-04:00]', zdt.toString());
        Assert.areEqual(
            JiffDate.newInstance(2024, 7, 15)
                .at(16, 24, 59, 0)
                .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(-4))),
            zdt
        );
    }

    @IsTest
    static void parsesRfc3339WithFractionalSeconds() {
        JiffZonedDateTime zdt = JiffStrtime.parse(
                '%Y-%m-%dT%H:%M:%S%.f%:z',
                '2024-07-15T16:24:59.123456789-04:00'
            )
            .toZonedDateTime();
        Assert.areEqual(
            JiffDate.newInstance(2024, 7, 15)
                .at(16, 24, 59, 123456789)
                .inTz('America/New_York')
                .toTimestamp(),
            zdt.toTimestamp()
        );
    }

    @IsTest
    static void undelimitedNumbersAreGreedy() {
        Assert.areEqual('2024-07-15', JiffStrtime.parse('%Y%m%d', '20240715').toDate().toString());
        try {
            JiffStrtime.parse('%Y%m%d', '9990715').toDate();
            Assert.fail('expected month 71 to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('month'), e.getMessage());
        }
        JiffDate value = JiffStrtime.parse('%Y%m%d', '09990715').toDate();
        Assert.areEqual('0999-07-15', value.toString());
        Assert.areEqual('09990715', value.strftime('%Y%m%d'));
    }

    @IsTest
    static void formatsEachDatetimeType() {
        Assert.areEqual('2024-07-15', JiffStrtime.format('%F', JiffDate.newInstance(2024, 7, 15)));
        Assert.areEqual('16:24:59', JiffStrtime.format('%T', JiffTime.newInstance(16, 24, 59, 0)));
        Assert.areEqual(
            'Monday, July 15, 2024 at 16:24:59',
            JiffStrtime.format(
                '%A, %B %e, %Y at %H:%M:%S',
                JiffDateTime.newInstance(2024, 7, 15, 16, 24, 59, 0)
            )
        );
        Assert.areEqual(
            '1737396540',
            JiffStrtime.format('%s', JiffTimestamp.parse('2025-01-20T18:09:00Z'))
        );
        Assert.areEqual(
            'Mon, 15 Jul 2024 16:24:59 -0400',
            JiffStrtime.format('%a, %-d %b %Y %T %z', newYorkAfternoon())
        );
        Assert.areEqual(
            'Mon Jul 15 04:24:59 PM EDT 2024',
            JiffStrtime.format('%a %b %e %I:%M:%S %p %Z %Y', newYorkAfternoon())
        );
        Assert.areEqual(
            '2024-07-15T16:24:59.123456789-04:00',
            JiffStrtime.format(
                '%Y-%m-%dT%H:%M:%S%.f%:z',
                JiffDate.newInstance(2024, 7, 15).at(16, 24, 59, 123456789).inTz('America/New_York')
            )
        );
    }

    @IsTest
    static void formatsAnIsoWeekDate() {
        Assert.areEqual(
            '2020-W53-7 2021-01-03 Sunday',
            JiffStrtime.format(
                '%G-W%V-%u %F %A',
                JiffIsoWeekDate.newInstance(2020, 53, JiffWeekday.SUNDAY)
            )
        );
    }

    @IsTest
    static void formatReportsWhatIsMissing() {
        try {
            JiffStrtime.format('%Y', JiffTime.newInstance(23, 59, 59, 0));
            Assert.fail('expected a time to have no year');
        } catch (JiffException e) {
            Assert.areEqual(
                'strftime formatting failed: %Y failed: requires date to format',
                e.getMessage()
            );
        }
        try {
            JiffStrtime.format('%Y %', JiffDate.newInstance(2024, 7, 15));
            Assert.fail('expected a trailing % to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'strftime formatting failed: invalid format string, expected byte after `%`, but found end of format string',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void formatRejectsNullValues() {
        Integer failures = 0;
        try {
            JiffStrtime.format('%Y', (JiffDate) null);
        } catch (JiffException e) {
            failures++;
        }
        try {
            JiffStrtime.format('%Y', (JiffZonedDateTime) null);
        } catch (JiffException e) {
            failures++;
        }
        Assert.areEqual(2, failures);
    }

    // ---- strptime on the datetime types ---------------------------------------------

    @IsTest
    static void dateStrptimeParsesADate() {
        Assert.areEqual('2024-07-14', JiffDate.strptime('%m/%d/%y', '7/14/24').toString());
        try {
            JiffDate.strptime('%H', '12');
            Assert.fail('expected an hour alone to give no date');
        } catch (JiffException e) {
            Assert.areEqual('year required to parse date', e.getMessage());
        }
    }

    @IsTest
    static void timeStrptimeParsesATime() {
        Assert.areEqual('16:30:00', JiffTime.strptime('%I:%M%P', '4:30pm').toString());
        try {
            JiffTime.strptime('%M:%S', '15:36');
            Assert.fail('expected minutes without hours to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(
                e.getMessage().contains('did not include hour directive'),
                e.getMessage()
            );
        }
    }

    @IsTest
    static void dateTimeStrptimeParsesADatetime() {
        Assert.areEqual(
            '2024-07-14T21:14:00',
            JiffDateTime.strptime('%F %H:%M', '2024-07-14 21:14').toString()
        );
        Assert.areEqual(
            '2022-02-04T03:58:59',
            JiffDateTime.strptime('%Y年%m月%d日，%H时%M分%S秒', '2022年02月04日，03时58分59秒')
                .toString()
        );
    }

    @IsTest
    static void timestampStrptimeNeedsAnOffset() {
        Assert.areEqual(
            '2024-07-15T01:14:00Z',
            JiffTimestamp.strptime('%F %H:%M %:z', '2024-07-14 21:14 -04:00').toString()
        );
        Assert.areEqual(
            '2024-07-29T20:56:25Z',
            JiffTimestamp.strptime('%Y%m%d-%H%M%S%z', '20240730-005625+0400').toString()
        );
        try {
            JiffTimestamp.strptime('%F %H:%M', '2024-07-14 21:14');
            Assert.fail('expected a missing offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('offset required to parse timestamp', e.getMessage());
        }
    }

    @IsTest
    static void zonedDateTimeStrptimeUsesTheTimeZone() {
        Assert.areEqual(
            '2024-07-14T21:14:00-04:00[America/New_York]',
            JiffZonedDateTime.strptime('%F %H:%M %:Q', '2024-07-14 21:14 America/New_York')
                .toString()
        );
        Assert.areEqual(
            '2024-07-30T00:56:25+04:00[+04:00]',
            JiffZonedDateTime.strptime('%Y%m%d-%H%M%S%z', '20240730-005625+0400').toString()
        );
        Assert.areEqual(
            JiffDate.newInstance(2024, 7, 15).at(17, 30, 0, 0).inTz('Australia/Hobart'),
            JiffZonedDateTime.strptime(
                '%A, %B %d, %Y at %-I:%M%P %:Q',
                'Monday, July 15, 2024 at 5:30pm Australia/Hobart'
            )
        );
    }

    // ---- strftime on the datetime types ---------------------------------------------

    @IsTest
    static void dateStrftimeIsLenient() {
        JiffDate value = JiffDate.newInstance(2024, 7, 15);
        Assert.areEqual('2024-07-15 is a Monday', value.strftime('%Y-%m-%d is a %A'));
        Assert.areEqual('2024 %', value.strftime('%Y %'));
        Assert.areEqual('2024 %H', value.strftime('%Y %H'));
    }

    @IsTest
    static void timeStrftimeIsLenient() {
        JiffTime value = JiffTime.newInstance(16, 30, 59, 0);
        Assert.areEqual('4:30pm', value.strftime('%-I:%M%P'));
        Assert.areEqual('4:31pm', value.round(JiffUnit.MINUTE).strftime('%-I:%M%P'));
        Assert.areEqual('16 %', value.strftime('%H %'));
    }

    @IsTest
    static void dateTimeStrftimeIsLenient() {
        JiffDateTime value = JiffDateTime.newInstance(2024, 7, 15, 16, 24, 59, 0);
        Assert.areEqual(
            'Monday, July 15, 2024 at 16:24:59',
            value.strftime('%A, %B %e, %Y at %H:%M:%S')
        );
        Assert.areEqual('2024 %', value.strftime('%Y %'));
    }

    @IsTest
    static void timestampStrftimeIsLenient() {
        Assert.areEqual(
            'Fri Jan  2 12:00:00 AM UTC 1970',
            JiffTimestamp.fromSecond(86400L).strftime('%a %b %e %I:%M:%S %p UTC %Y')
        );
        Assert.areEqual('1970 %', JiffTimestamp.UNIX_EPOCH.strftime('%Y %'));
        Assert.areEqual('%Z', JiffTimestamp.UNIX_EPOCH.strftime('%Z'));
    }

    @IsTest
    static void zonedDateTimeStrftimeIsLenient() {
        JiffZonedDateTime zdt = newYorkAfternoon();
        Assert.areEqual(
            'Mon Jul 15 04:24:59 PM EDT 2024',
            zdt.strftime('%a %b %e %I:%M:%S %p %Z %Y')
        );
        Assert.areEqual('Mon, 15 Jul 2024 16:24:59 -0400', zdt.strftime('%a, %-d %b %Y %T %z'));
        Assert.areEqual('the date is: 7/15/2024', 'the date is: ' + zdt.strftime('%-m/%-d/%-Y'));
        Assert.areEqual('1970 %', JiffZonedDateTime.UNIX_EPOCH.strftime('%Y %'));
    }
}
