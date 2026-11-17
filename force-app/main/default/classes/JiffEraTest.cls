@IsTest
private class JiffEraTest {
    @IsTest
    static void hasExactlyTheTwoErasInChronologicalOrder() {
        Assert.areEqual(new List<JiffEra>{ JiffEra.BCE, JiffEra.CE }, JiffEra.values());
        Assert.areEqual('BCE', JiffEra.BCE.name());
        Assert.areEqual('CE', JiffEra.CE.name());
    }

    @IsTest
    static void yearsUpToZeroAreBceAndTheRestAreCe() {
        // The examples from Jiff's documentation of `Date::era_year`.
        Assert.areEqual(JiffEra.CE, JiffDate.newInstance(2024, 10, 3).era());
        Assert.areEqual(JiffEra.CE, JiffDate.newInstance(1, 10, 3).era());
        Assert.areEqual(JiffEra.BCE, JiffDate.newInstance(0, 10, 3).era());
        Assert.areEqual(JiffEra.BCE, JiffDate.newInstance(-1, 10, 3).era());
        Assert.areEqual(JiffEra.BCE, JiffDate.newInstance(-9999, 10, 3).era());
    }
}
