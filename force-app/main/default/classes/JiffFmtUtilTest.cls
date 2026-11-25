/**
 * `JiffFmtUtil`: names, ASCII helpers and the UTF-8 view of text used in error messages.
 *
 * The UTF-8 encodings are those of the Unicode standard; the escapes are the ones Jiff's
 * `util::escape` writes (see also `JiffDurationScannerTest`).
 */
@IsTest
private class JiffFmtUtilTest {
    @IsTest
    static void namesWeekdaysAndMonthsInEnglish() {
        Assert.areEqual('Sunday', JiffFmtUtil.weekdayName(JiffWeekday.SUNDAY));
        Assert.areEqual('Wednesday', JiffFmtUtil.weekdayName(JiffWeekday.WEDNESDAY));
        Assert.areEqual('Sat', JiffFmtUtil.weekdayAbbreviation(JiffWeekday.SATURDAY));
        Assert.areEqual('January', JiffFmtUtil.monthName(1));
        Assert.areEqual('September', JiffFmtUtil.monthName(9));
        Assert.areEqual('Dec', JiffFmtUtil.monthAbbreviation(12));
        Assert.areEqual(7, JiffFmtUtil.WEEKDAY_NAMES.size());
        Assert.areEqual(12, JiffFmtUtil.MONTH_NAMES.size());
    }

    @IsTest
    static void contextPrefixesTheMessageAndKeepsTheCause() {
        JiffException cause = new JiffException('inner');
        JiffException wrapped = JiffFmtUtil.context('outer', cause);
        Assert.areEqual('outer: inner', wrapped.getMessage());
        Assert.areEqual(cause, wrapped.getCause());
    }

    @IsTest
    static void classifiesAsciiCharacters() {
        Assert.isTrue(JiffFmtUtil.isDigit(48));
        Assert.isFalse(JiffFmtUtil.isDigit(58));
        Assert.isTrue(JiffFmtUtil.isAsciiAlphabetic(65));
        Assert.isTrue(JiffFmtUtil.isAsciiAlphabetic(122));
        Assert.isFalse(JiffFmtUtil.isAsciiAlphabetic(91));
        Assert.isFalse(JiffFmtUtil.isAsciiAlphabetic(233));
        for (Integer ch : new List<Integer>{ 32, 9, 10, 12, 13 }) {
            Assert.isTrue(JiffFmtUtil.isAsciiWhitespace(ch), String.valueOf(ch));
        }
        // Rust's ASCII whitespace does not include the vertical tab.
        Assert.isFalse(JiffFmtUtil.isAsciiWhitespace(11));
        Assert.isFalse(JiffFmtUtil.isAsciiWhitespace(160));
    }

    @IsTest
    static void changesTheCaseOfAsciiLettersOnly() {
        Assert.areEqual('JULY é', JiffFmtUtil.toAsciiUpperCase('July é'));
        Assert.areEqual('edt é', JiffFmtUtil.toAsciiLowerCase('EDT é'));
        Assert.areEqual(97, JiffFmtUtil.toAsciiLower(65));
        Assert.areEqual(201, JiffFmtUtil.toAsciiLower(201));
        Assert.isTrue(JiffFmtUtil.startsWithIgnoreAsciiCase('xxsUnDaY', 2, 'Sunday'));
        Assert.isFalse(JiffFmtUtil.startsWithIgnoreAsciiCase('xxSun', 2, 'Sunday'));
        Assert.isFalse(JiffFmtUtil.startsWithIgnoreAsciiCase('Monday', 0, 'Sunday'));
    }

    @IsTest
    static void encodesCharactersAsUtf8() {
        Assert.areEqual(new List<Integer>{ 65 }, JiffFmtUtil.utf8Bytes('A', 0));
        Assert.areEqual(new List<Integer>{ 195, 169 }, JiffFmtUtil.utf8Bytes('é', 0));
        Assert.areEqual(new List<Integer>{ 229, 185, 180 }, JiffFmtUtil.utf8Bytes('年', 0));
        String pile = String.fromCharArray(new List<Integer>{ 55357, 56489 });
        Assert.areEqual(new List<Integer>{ 240, 159, 146, 169 }, JiffFmtUtil.utf8Bytes(pile, 0));
        // A surrogate without its partner is three bytes.
        String lone = String.fromCharArray(new List<Integer>{ 55357, 65 });
        Assert.areEqual(new List<Integer>{ 237, 160, 189 }, JiffFmtUtil.utf8Bytes(lone, 0));
    }

    @IsTest
    static void measuresTextInUtf8Bytes() {
        Assert.areEqual(3, JiffFmtUtil.utf8Length('abc', 0, 10));
        Assert.areEqual(2, JiffFmtUtil.utf8Length('abc', 0, 2));
        Assert.areEqual(2, JiffFmtUtil.utf8Length('é', 0, 10));
        Assert.areEqual(1, JiffFmtUtil.utf8Length('xé', 0, 1));
        String pile = String.fromCharArray(new List<Integer>{ 55357, 56489, 65 });
        Assert.areEqual(5, JiffFmtUtil.utf8Length(pile, 0, 10));
        Assert.areEqual(0, JiffFmtUtil.utf8Length('abc', 3, 10));
    }

    @IsTest
    static void describesBytesAndTextLikeJiff() {
        Assert.areEqual('a', JiffFmtUtil.describeByte(97));
        Assert.areEqual(' ', JiffFmtUtil.describeByte(32));
        Assert.areEqual('\\xFF', JiffFmtUtil.describeByte(255));
        Assert.areEqual('\\xE5', JiffFmtUtil.describeLeadByte('年', 0));
        Assert.areEqual('xyz\\"\\\'\\t', JiffFmtUtil.describeText('xyz"\'\t'));
        Assert.areEqual('', JiffFmtUtil.describeText(''));
    }
}
