/**
 * `JiffBrokenDownTimePrefix`, the result of parsing a prefix. Expected values are the doc
 * examples of `jiff::fmt::strtime::BrokenDownTime::parse_prefix`.
 */
@IsTest
private class JiffBrokenDownTimePrefixTest {
    @IsTest
    static void aTwoDigitYearLeavesTheRestUnparsed() {
        String input = '7/14/2499';
        JiffBrokenDownTimePrefix prefix = JiffBrokenDownTime.parsePrefix('%m/%d/%y', input);
        Assert.areEqual(JiffDate.newInstance(2024, 7, 14), prefix.value().toDate());
        Assert.areEqual(7, prefix.consumed());
        Assert.areEqual('99', input.substring(prefix.consumed()));
    }

    @IsTest
    static void parsingAllOfTheInputConsumesItsLength() {
        JiffBrokenDownTimePrefix prefix = JiffBrokenDownTime.parsePrefix('%m/%d/%y', '7/14/24');
        Assert.areEqual(JiffDate.newInstance(2024, 7, 14), prefix.value().toDate());
        Assert.areEqual(7, prefix.consumed());
    }

    @IsTest
    static void consumedCountsUtf16CodeUnits() {
        JiffBrokenDownTimePrefix prefix = JiffBrokenDownTime.parsePrefix('%Y年', '2024年07月');
        Assert.areEqual(2024, prefix.value().year());
        Assert.areEqual(5, prefix.consumed());
    }

    @IsTest
    static void bothPartsAreRequired() {
        Integer failures = 0;
        try {
            new JiffBrokenDownTimePrefix(null, 0);
        } catch (JiffException e) {
            failures++;
        }
        try {
            new JiffBrokenDownTimePrefix(new JiffBrokenDownTime(), null);
        } catch (JiffException e) {
            failures++;
        }
        Assert.areEqual(2, failures);
    }
}
