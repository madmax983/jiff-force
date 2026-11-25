/**
 * `JiffStrtimePosixCustom`, called directly. Expected values come from the doc examples of
 * `jiff::fmt::strtime::PosixCustom` and Jiff's `ok_format_posix_locale` test, or from Jiff
 * 1.0.0 itself for the upper case forms.
 */
@IsTest
private class JiffStrtimePosixCustomTest {
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
        JiffStrtimePosixCustom custom = new JiffStrtimePosixCustom();
        Assert.areEqual(
            'Sun Jul 14 00:00:00 2024',
            custom.formatDateTime(CONFIG, PLAIN, at(0, 0, 0))
        );
        Assert.areEqual(
            'SUN JUL 14 00:00:00 2024',
            custom.formatDateTime(CONFIG, UPPER, at(0, 0, 0))
        );
        Assert.areEqual(
            'Tue Jul  1 17:30:00 2025',
            custom.formatDateTime(
                CONFIG,
                null,
                JiffBrokenDownTime.fromDateTime(JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0))
            )
        );
    }

    @IsTest
    static void formatsTheDate() {
        Assert.areEqual(
            '07/14/24',
            new JiffStrtimePosixCustom().formatDate(CONFIG, PLAIN, at(0, 0, 0))
        );
    }

    @IsTest
    static void formatsTheTime() {
        Assert.areEqual(
            '17:31:59',
            new JiffStrtimePosixCustom().formatTime(CONFIG, PLAIN, at(17, 31, 59))
        );
    }

    @IsTest
    static void formatsThe12HourTime() {
        JiffStrtimePosixCustom custom = new JiffStrtimePosixCustom();
        Assert.areEqual('08:30:00 AM', custom.format12HourTime(CONFIG, PLAIN, at(8, 30, 0)));
        Assert.areEqual('05:31:59 PM', custom.format12HourTime(CONFIG, UPPER, at(17, 31, 59)));
    }
}
