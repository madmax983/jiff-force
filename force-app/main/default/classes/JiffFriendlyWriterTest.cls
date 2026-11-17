/**
 * The writer `JiffFriendlyPrinter` drives, exercised directly. The expected text is what Jiff's
 * printer tests (`fmt/friendly/printer.rs`) give for the same units and settings.
 */
@IsTest
private class JiffFriendlyWriterTest {
    private static JiffFriendlyWriter positive(JiffFriendlyPrinter printer) {
        return new JiffFriendlyWriter(printer, false, 1);
    }

    @IsTest
    static void unitsAreSeparatedAndZeroValuesAreSkipped() {
        JiffFriendlyWriter writer = positive(new JiffFriendlyPrinter());
        writer.write(JiffUnit.HOUR, 1L);
        writer.write(JiffUnit.MINUTE, 0L);
        writer.write(JiffUnit.SECOND, 30L);
        writer.writeZero();
        Assert.areEqual('1h 30s', writer.toString());
    }

    @IsTest
    static void aZeroIsWrittenOnlyWhenNothingElseWas() {
        JiffFriendlyWriter writer = positive(new JiffFriendlyPrinter());
        writer.write(JiffUnit.HOUR, 0L);
        writer.finishPreceding();
        Assert.areEqual('', writer.toString());
        writer.writeZero();
        Assert.areEqual('0s', writer.toString());

        JiffFriendlyWriter fractional = positive(
            new JiffFriendlyPrinter()
                .zeroUnit(JiffUnit.YEAR)
                .fractional(JiffFriendlyFractionalUnit.MINUTE)
        );
        fractional.writeZero();
        Assert.areEqual('0m', fractional.toString());
    }

    @IsTest
    static void commasSpacesAndPluralsFollowThePrinter() {
        JiffFriendlyWriter writer = positive(
            new JiffFriendlyPrinter()
                .designator(JiffFriendlyDesignator.VERBOSE)
                .spacing(JiffFriendlySpacing.BETWEEN_UNITS_AND_DESIGNATORS)
                .commaAfterDesignator(true)
        );
        writer.write(JiffUnit.YEAR, 1L);
        writer.write(JiffUnit.MONTH, 2L);
        Assert.areEqual('1 year, 2 months', writer.toString());

        JiffFriendlyWriter packed = positive(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.NONE).padding(2)
        );
        packed.write(JiffUnit.HOUR, 1L);
        packed.write(JiffUnit.MINUTE, 40L);
        Assert.areEqual('01h40m', packed.toString());
    }

    @IsTest
    static void theSignIsAPrefixOrASuffixButNeverBoth() {
        JiffFriendlyWriter suffix = new JiffFriendlyWriter(new JiffFriendlyPrinter(), false, -1);
        suffix.writePrefixSign();
        suffix.write(JiffUnit.HOUR, 1L);
        suffix.writeSuffixSign();
        Assert.areEqual('1h ago', suffix.toString());

        JiffFriendlyWriter prefix = new JiffFriendlyWriter(
            new JiffFriendlyPrinter().spacing(JiffFriendlySpacing.NONE),
            false,
            -1
        );
        prefix.writePrefixSign();
        prefix.write(JiffUnit.HOUR, 1L);
        prefix.writeSuffixSign();
        Assert.areEqual('-1h', prefix.toString());

        JiffFriendlyWriter forced = new JiffFriendlyWriter(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.FORCE_SIGN),
            false,
            0
        );
        forced.writePrefixSign();
        forced.writeZero();
        forced.writeSuffixSign();
        Assert.areEqual('+0s', forced.toString());

        JiffFriendlyWriter unsigned = positive(
            new JiffFriendlyPrinter().direction(JiffFriendlyDirection.SUFFIX)
        );
        unsigned.writePrefixSign();
        unsigned.write(JiffUnit.HOUR, 1L);
        unsigned.writeSuffixSign();
        Assert.areEqual('1h', unsigned.toString());
    }

    @IsTest
    static void aClockPrefersAPrefixSignUnlessCalendarUnitsPrecedeIt() {
        JiffFriendlyPrinter clock = new JiffFriendlyPrinter().hoursMinutesSeconds(true);
        JiffFriendlyWriter alone = new JiffFriendlyWriter(clock, false, -1);
        alone.writePrefixSign();
        alone.writeClock(1L, 0L, 0L, 0L);
        alone.writeSuffixSign();
        Assert.areEqual('-01:00:00', alone.toString());

        JiffFriendlyWriter afterDays = new JiffFriendlyWriter(clock, true, -1);
        afterDays.writePrefixSign();
        afterDays.write(JiffUnit.DAY, 1L);
        afterDays.finishPreceding();
        afterDays.writeClock(1L, 0L, 0L, 0L);
        afterDays.writeSuffixSign();
        Assert.areEqual('1d 01:00:00 ago', afterDays.toString());
    }

    @IsTest
    static void fractionalValuesFollowThePrecision() {
        JiffFriendlyPrinter hours = new JiffFriendlyPrinter()
            .fractional(JiffFriendlyFractionalUnit.HOUR);
        JiffFriendlyWriter automatic = positive(hours);
        automatic.writeFractional(JiffUnit.HOUR, 1L, 500000000L);
        Assert.areEqual('1.5h', automatic.toString());

        JiffFriendlyWriter nothing = positive(hours);
        nothing.writeFractional(JiffUnit.HOUR, 0L, 0L);
        Assert.areEqual('', nothing.toString());

        JiffFriendlyWriter truncated = positive(hours.precision(0));
        truncated.writeFractional(JiffUnit.HOUR, 1L, 500000000L);
        Assert.areEqual('1h', truncated.toString());

        JiffFriendlyWriter fixed = positive(hours.precision(2));
        fixed.writeFractional(JiffUnit.HOUR, 0L, 0L);
        Assert.areEqual('0.00h', fixed.toString());

        JiffFriendlyWriter afterAnother = positive(hours.precision(2));
        afterAnother.write(JiffUnit.DAY, 100L);
        afterAnother.writeFractional(JiffUnit.HOUR, 1L, 500000000L);
        afterAnother.writeZero();
        Assert.areEqual('100d 1.50h', afterAnother.toString());
    }

    @IsTest
    static void aClockIsPaddedAndCarriesTheFraction() {
        JiffFriendlyWriter writer = positive(new JiffFriendlyPrinter());
        writer.writeClock(2L, 59L, 15L, 123000000L);
        Assert.areEqual('02:59:15.123', writer.toString());

        JiffFriendlyWriter unpadded = positive(new JiffFriendlyPrinter().padding(0));
        unpadded.writeClock(1L, 0L, 0L, 0L);
        Assert.areEqual('1:0:0', unpadded.toString());

        JiffFriendlyWriter fixed = positive(new JiffFriendlyPrinter().precision(3));
        fixed.writeClock(0L, 0L, 1L, 0L);
        Assert.areEqual('00:00:01.000', fixed.toString());
    }

    @IsTest
    static void appendWritesTextAsItIs() {
        JiffFriendlyWriter writer = positive(new JiffFriendlyPrinter());
        writer.append('1y2mo');
        writer.append(' ');
        writer.writeClock(15L, 0L, 0L, 0L);
        Assert.areEqual('1y2mo 15:00:00', writer.toString());
    }
}
