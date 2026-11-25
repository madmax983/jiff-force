/**
 * `JiffStrtimeDefaultCustom`, called directly. Expected values come from the doc examples of
 * `jiff::fmt::strtime::DefaultCustom` and Jiff's `ok_format_default_locale` and
 * `ok_format_compound_uppercase` tests.
 */
@IsTest
private class JiffStrtimeDefaultCustomTest {
    private static final JiffStrtimeConfig CONFIG = new JiffStrtimeConfig();
    private static final JiffStrtimeExtension PLAIN = new JiffStrtimeExtension(null, null, 0);
    private static final JiffStrtimeExtension UPPER = new JiffStrtimeExtension('^', null, 0);

    private static JiffBrokenDownTime at(Integer hour, Integer minute, Integer second) {
        return JiffBrokenDownTime.fromDateTime(
            JiffDateTime.newInstance(2024, 7, 14, hour, minute, second, 0)
        );
    }

    @IsTest
    static void formatsTheDateAndTime() {
        JiffStrtimeDefaultCustom custom = new JiffStrtimeDefaultCustom();
        Assert.areEqual(
            '2024 M07 14, Sun 00:00:00',
            custom.formatDateTime(CONFIG, PLAIN, at(0, 0, 0))
        );
        Assert.areEqual(
            '2024 M07 14, SUN 00:00:00',
            custom.formatDateTime(CONFIG, UPPER, at(0, 0, 0))
        );
        Assert.areEqual(
            '2024 M07 14, Sun 00:00:00',
            custom.formatDateTime(CONFIG, null, at(0, 0, 0))
        );
    }

    @IsTest
    static void formatsTheDate() {
        Assert.areEqual(
            '2024 M07 14',
            new JiffStrtimeDefaultCustom().formatDate(CONFIG, UPPER, at(0, 0, 0))
        );
    }

    @IsTest
    static void formatsTheTime() {
        Assert.areEqual(
            '08:30:00',
            new JiffStrtimeDefaultCustom().formatTime(CONFIG, UPPER, at(8, 30, 0))
        );
    }

    @IsTest
    static void formatsThe12HourTime() {
        JiffStrtimeDefaultCustom custom = new JiffStrtimeDefaultCustom();
        Assert.areEqual('8:30:00 AM', custom.format12HourTime(CONFIG, PLAIN, at(8, 30, 0)));
        Assert.areEqual('5:31:59 PM', custom.format12HourTime(CONFIG, UPPER, at(17, 31, 59)));
    }
}
