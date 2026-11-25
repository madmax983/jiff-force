/**
 * `JiffStrtimeFormatReader`: walking a format string and reading the flag, width and colons
 * after a `%`. Error messages are Jiff 1.0.0's (see the `invalidFormats` rows of
 * `JiffStrtimeFormatterTest`, which were generated with Jiff).
 */
@IsTest
private class JiffStrtimeFormatReaderTest {
    private static JiffStrtimeExtension extensionOf(String fmt) {
        JiffStrtimeFormatReader reader = new JiffStrtimeFormatReader(fmt);
        JiffStrtimeExtension ext = reader.parseExtension();
        Assert.areEqual('d', fmt.substring(reader.position(), reader.position() + 1), fmt);
        return ext;
    }

    @IsTest
    static void walksTheFormat() {
        JiffStrtimeFormatReader reader = new JiffStrtimeFormatReader('ab');
        Assert.areEqual('ab', reader.text());
        Assert.isFalse(reader.isDone());
        Assert.areEqual(97, reader.f());
        Assert.areEqual('a', reader.describeCurrent());
        Assert.isTrue(reader.bump());
        Assert.areEqual(1, reader.position());
        Assert.isFalse(reader.bump());
        Assert.isTrue(reader.isDone());
        reader.rewind(0);
        Assert.areEqual(97, reader.f());
    }

    @IsTest
    static void describesACharacterOutsideAsciiByItsFirstByte() {
        Assert.areEqual('\\xC3', new JiffStrtimeFormatReader('é').describeCurrent());
    }

    @IsTest
    static void readsFlagWidthAndColons() {
        JiffStrtimeExtension ext = extensionOf('d');
        Assert.isNull(ext.flag());
        Assert.isNull(ext.width());
        Assert.areEqual(0, ext.colons());

        ext = extensionOf('_12d');
        Assert.areEqual('_', ext.flag());
        Assert.areEqual(12, ext.width());

        ext = extensionOf('0255::d');
        Assert.areEqual('0', ext.flag());
        Assert.areEqual(255, ext.width());
        Assert.areEqual(2, ext.colons());

        ext = extensionOf('-:::d');
        Assert.areEqual('-', ext.flag());
        Assert.areEqual(3, ext.colons());

        // `0` right after the `%` is the flag; a second `0` is a width.
        ext = extensionOf('00d');
        Assert.areEqual('0', ext.flag());
        Assert.areEqual(0, ext.width());
    }

    @IsTest
    static void parseWidthReadsNothingWithoutDigits() {
        JiffStrtimeFormatReader reader = new JiffStrtimeFormatReader('f');
        Assert.isNull(reader.parseWidth());
        Assert.areEqual(0, reader.position());
    }

    @IsTest
    static void endingTooEarlyIsAnError() {
        List<String> messages = new List<String>();
        for (String fmt : new List<String>{ '^', '_5', '::', '256d', '99999999999999999999d' }) {
            try {
                new JiffStrtimeFormatReader(fmt).parseExtension();
            } catch (JiffException e) {
                messages.add(e.getMessage());
            }
        }
        Assert.areEqual(
            new List<String>{
                'expected to find specifier directive after flag `^`, but found end of format string',
                'expected to find specifier directive after parsed width, but found end of format string',
                'expected to find specifier directive after colons, but found end of format string',
                'parsed width is too big, max is 255',
                'failed to parse conversion specifier width: number too big to parse into 64-bit integer'
            },
            messages
        );
    }

    @IsTest
    static void aNullFormatIsRejected() {
        try {
            new JiffStrtimeFormatReader(null);
            Assert.fail('expected a null format to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('format string must not be null', e.getMessage());
        }
    }
}
