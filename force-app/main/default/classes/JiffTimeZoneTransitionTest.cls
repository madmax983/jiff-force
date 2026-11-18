@IsTest
private class JiffTimeZoneTransitionTest {
    // 2024-03-10T07:00:00Z, when New York's clocks went from 02:00 to 03:00.
    private static final Long SPRING_FORWARD = 1710054000L;

    private static JiffTimeZoneTransition springForward() {
        return new JiffTimeZoneTransition(
            JiffTimestamp.fromSecond(SPRING_FORWARD),
            new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'EDT', JiffDst.YES)
        );
    }

    @IsTest
    static void exposesTheInstantAndWhatFollowsIt() {
        JiffTimeZoneTransition transition = springForward();
        Assert.areEqual('2024-03-10T07:00:00Z', transition.toTimestamp().toString());
        Assert.areEqual(JiffOffset.fromHours(-4), transition.offset());
        Assert.areEqual('EDT', transition.abbreviation());
        Assert.areEqual(JiffDst.YES, transition.dst());
    }

    @IsTest
    static void equalityComparesTheInstantAndTheInfo() {
        Assert.areEqual(springForward(), springForward());
        Assert.areEqual(springForward().hashCode(), springForward().hashCode());
        Assert.areNotEqual(
            springForward(),
            new JiffTimeZoneTransition(
                JiffTimestamp.fromSecond(SPRING_FORWARD + 1),
                new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-4), 'EDT', JiffDst.YES)
            )
        );
        Assert.areNotEqual(
            springForward(),
            new JiffTimeZoneTransition(
                JiffTimestamp.fromSecond(SPRING_FORWARD),
                new JiffTimeZoneOffsetInfo(JiffOffset.fromHours(-5), 'EST', JiffDst.NO)
            )
        );
        Assert.isFalse(springForward().equals(JiffTimestamp.fromSecond(SPRING_FORWARD)));
    }

    @IsTest
    static void toStringShowsEverything() {
        Assert.areEqual('2024-03-10T07:00:00Z -04 EDT (DST)', springForward().toString());
    }
}
