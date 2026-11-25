/**
 * `JiffStrtimeConfig`: lenient mode and custom locale formatting.
 *
 * Expected values come from the doc examples of `jiff::fmt::strtime::Config` and `Custom`,
 * and from Jiff's tests in `fmt::strtime::printer`.
 */
@IsTest
private class JiffStrtimeConfigTest {
    // A customization that is not one of the built-in two, to show that `%c`, `%r`, `%X` and
    // `%x` go through the configured implementation and receive the flags.
    private class DottedCustom implements JiffStrtimeCustom {
        public String formatDateTime(
            JiffStrtimeConfig config,
            JiffStrtimeExtension ext,
            JiffBrokenDownTime tm
        ) {
            return tm.format('%d.%m.%Y %H:%M', config) + (ext.isUppercase() ? '!' : '');
        }
        public String formatDate(
            JiffStrtimeConfig config,
            JiffStrtimeExtension ext,
            JiffBrokenDownTime tm
        ) {
            return tm.format('%d.%m.%Y', config);
        }
        public String formatTime(
            JiffStrtimeConfig config,
            JiffStrtimeExtension ext,
            JiffBrokenDownTime tm
        ) {
            return tm.format('%H.%M', config) + (ext.width() == null ? '' : '/' + ext.width());
        }
        public String format12HourTime(
            JiffStrtimeConfig config,
            JiffStrtimeExtension ext,
            JiffBrokenDownTime tm
        ) {
            return null;
        }
    }

    @IsTest
    static void theDefaultConfigurationIsStrictAndUsesTheDefaultCustom() {
        JiffStrtimeConfig config = new JiffStrtimeConfig();
        Assert.isFalse(config.isLenient());
        Assert.isTrue(config.getCustom() instanceof JiffStrtimeDefaultCustom);
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDateTime(
            JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0)
        );
        Assert.areEqual('2025 M07 1, Tue 17:30:00', tm.format('%c', config));
    }

    @IsTest
    static void lenientModeWritesFailingSpecifiersLiterally() {
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDate(JiffDate.newInstance(2025, 4, 30));
        try {
            tm.format('%F %z');
            Assert.fail('expected a date to have no offset');
        } catch (JiffException e) {
            Assert.areEqual(
                'strftime formatting failed: %z failed: requires time zone offset',
                e.getMessage()
            );
        }
        JiffStrtimeConfig config = new JiffStrtimeConfig().lenient(true);
        Assert.isTrue(config.isLenient());
        Assert.areEqual('2025-04-30 %z', tm.format('%F %z', config));
        Assert.areEqual('%+ %0', tm.format('%+ %0', config));
    }

    @IsTest
    static void lenientModeKeepsWhatAFailedSpecifierWroteBeforeFailing() {
        JiffBrokenDownTime tm = new JiffBrokenDownTime().withYear(2024);
        Assert.areEqual('2024-%F|%D', tm.format('%F|%D', new JiffStrtimeConfig().lenient(true)));
    }

    @IsTest
    static void thePosixCustomFormatsLikeTheCLocale() {
        JiffStrtimeConfig config = new JiffStrtimeConfig().custom(new JiffStrtimePosixCustom());
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDateTime(
            JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0)
        );
        Assert.areEqual('Tue Jul  1 17:30:00 2025', tm.format('%c', config));
        Assert.isFalse(config.isLenient());
        Assert.isTrue(config.lenient(true).getCustom() instanceof JiffStrtimePosixCustom);
    }

    @IsTest
    static void aCustomImplementationIsUsedForTheLocaleSpecifiers() {
        JiffStrtimeConfig config = new JiffStrtimeConfig().custom(new DottedCustom());
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromDateTime(
            JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0)
        );
        Assert.areEqual(
            '01.07.2025 17:30 | 01.07.2025 17:30! | 01.07.2025 | 17.30/5 | ',
            tm.format('%c | %^c | %x | %5X | %r', config)
        );
    }

    @IsTest
    static void lenientModeCarriesIntoTheCustomImplementation() {
        JiffStrtimeConfig config = new JiffStrtimeConfig().custom(new DottedCustom()).lenient(true);
        JiffBrokenDownTime tm = JiffBrokenDownTime.fromTime(JiffTime.newInstance(17, 30, 0, 0));
        Assert.areEqual('%d.%m.%Y 17:30', tm.format('%c', config));
        try {
            tm.format('%c', config.lenient(false));
            Assert.fail('expected a time to have no date');
        } catch (JiffException e) {
            Assert.areEqual(
                'strftime formatting failed: %c failed: strftime formatting failed: %d failed: requires date to format',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void nullOptionsAreRejected() {
        try {
            new JiffStrtimeConfig().lenient(null);
            Assert.fail('expected a null lenient option to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('lenient option must not be null', e.getMessage());
        }
        try {
            new JiffStrtimeConfig().custom(null);
            Assert.fail('expected a null customization to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('strtime customization must not be null', e.getMessage());
        }
    }
}
