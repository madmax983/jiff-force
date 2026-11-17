@IsTest
private class JiffTimeZoneOffsetInfoTest {
    private static JiffTimeZoneOffsetInfo daylight() {
        return new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'EDT', JiffDst.YES);
    }

    private static JiffTimeZoneOffsetInfo standard() {
        return new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-5), 'EST', JiffDst.NO);
    }

    @IsTest
    static void exposesTheOffsetAbbreviationAndDstFlag() {
        Assert.areEqual(JiffOffset.fromHours(-4), daylight().offset());
        Assert.areEqual('EDT', daylight().abbreviation());
        Assert.areEqual(JiffDst.YES, daylight().dst());
        Assert.areEqual(JiffOffset.fromHours(-5), standard().offset());
        Assert.areEqual('EST', standard().abbreviation());
        Assert.areEqual(JiffDst.NO, standard().dst());
    }

    @IsTest
    static void equalityComparesAllThreeParts() {
        Assert.areEqual(daylight(), daylight());
        Assert.areEqual(daylight().hashCode(), daylight().hashCode());
        Assert.areNotEqual(daylight(), standard());
        Assert.areNotEqual(
            daylight(),
            new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'EDT', JiffDst.NO)
        );
        Assert.areNotEqual(
            daylight(),
            new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'AST', JiffDst.YES)
        );
        Assert.areNotEqual(
            daylight(),
            new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-3), 'EDT', JiffDst.YES)
        );
        // Abbreviations are compared exactly.
        Assert.areNotEqual(
            daylight(),
            new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'edt', JiffDst.YES)
        );
        Assert.isFalse(daylight().equals('EDT'));
        Map<JiffTimeZoneOffsetInfo, String> seasons = new Map<JiffTimeZoneOffsetInfo, String>{
            daylight() => 'summer',
            standard() => 'winter'
        };
        Assert.areEqual('summer', seasons.get(daylight()));
        Assert.areEqual('winter', seasons.get(standard()));
    }

    @IsTest
    static void toStringShowsEverything() {
        Assert.areEqual('-04 EDT (DST)', daylight().toString());
        Assert.areEqual('-05 EST', standard().toString());
    }

    @IsTest
    static void dstHasTwoValues() {
        Assert.areEqual(new List<JiffDst>{ JiffDst.NO, JiffDst.YES }, JiffDst.values());
    }
}
