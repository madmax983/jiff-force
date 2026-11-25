/**
 * `JiffStrtimeExtension`: the flag, width and colons of a conversion specifier.
 */
@IsTest
private class JiffStrtimeExtensionTest {
    @IsTest
    static void holdsTheFlagWidthAndColons() {
        JiffStrtimeExtension ext = new JiffStrtimeExtension('_', 3, 2);
        Assert.areEqual('_', ext.flag());
        Assert.areEqual(3, ext.width());
        Assert.areEqual(2, ext.colons());
        Assert.isFalse(ext.isUppercase());
        Assert.isTrue(new JiffStrtimeExtension('^', null, 0).isUppercase());
    }

    @IsTest
    static void anEmptyExtensionHasNoFlagOrWidth() {
        JiffStrtimeExtension ext = new JiffStrtimeExtension(null, null, 0);
        Assert.isNull(ext.flag());
        Assert.isNull(ext.width());
        Assert.areEqual(0, ext.colons());
        Assert.isFalse(ext.isUppercase());
    }

    @IsTest
    static void withWidthReplacesOnlyTheWidth() {
        JiffStrtimeExtension ext = new JiffStrtimeExtension('#', 5, 1);
        JiffStrtimeExtension changed = ext.withWidth(9);
        Assert.areEqual(9, changed.width());
        Assert.areEqual('#', changed.flag());
        Assert.areEqual(1, changed.colons());
        Assert.isNull(ext.withWidth(null).width());
        Assert.areEqual(5, ext.width());
    }

    @IsTest
    static void invalidPartsAreRejected() {
        List<String> messages = new List<String>();
        try {
            new JiffStrtimeExtension('x', null, 0);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffStrtimeExtension('__', null, 0);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffStrtimeExtension(null, 256, 0);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffStrtimeExtension(null, null, 4);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            new JiffStrtimeExtension(null, null, null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'strftime flag must be one of `_`, `0`, `-`, `^` or `#`, but got `x`',
                'strftime flag must be one of `_`, `0`, `-`, `^` or `#`, but got `__`',
                'parameter \'strftime width\' is not in the required range of 0..=255',
                'parameter \'strftime colons\' is not in the required range of 0..=3',
                'the number of colons must not be null'
            },
            messages
        );
    }
}
