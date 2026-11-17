/**
 * Which characters are written as a Unicode escape.
 *
 * Every expected value is what Rust 1.97 (Unicode 17.0.0) returns from `char::escape_debug`,
 * the function Jiff 1.0.0 formats leftover input with. Nothing here was computed by the port.
 */
@IsTest
private class JiffUnicodeEscapeTest {
    private static Integer hex(String digits) {
        Integer value = 0;
        for (Integer i = 0; i < digits.length(); i++) {
            value = value * 16 + '0123456789abcdef'.indexOf(digits.substring(i, i + 1));
        }
        return value;
    }

    /** Each row is a code point in hexadecimal and its escape, or `kept`. */
    private static void assertEscapes(List<String> rows) {
        for (String row : rows) {
            Integer space = row.indexOf(' ');
            Integer codePoint = hex(row.substring(0, space));
            String expected = row.substring(space + 1);
            Assert.areEqual(!expected.equals('kept'), JiffUnicodeEscape.isEscaped(codePoint), row);
            if (!expected.equals('kept')) {
                Assert.areEqual(expected, JiffUnicodeEscape.escape(codePoint), row);
            }
        }
    }

    @IsTest
    static void controlsFormatCharactersAndOddSpacesAreEscaped() {
        assertEscapes(
            new List<String>{
                '80 \\u{80}',
                '9f \\u{9f}',
                'a0 \\u{a0}',
                'ad \\u{ad}',
                '600 \\u{600}',
                '605 \\u{605}',
                '61c \\u{61c}',
                '6dd \\u{6dd}',
                '70f \\u{70f}',
                '1680 \\u{1680}',
                '180e \\u{180e}',
                '2000 \\u{2000}',
                '200a \\u{200a}',
                '200b \\u{200b}',
                '200c \\u{200c}',
                '200d \\u{200d}',
                '200e \\u{200e}',
                '200f \\u{200f}',
                '2028 \\u{2028}',
                '2029 \\u{2029}',
                '202a \\u{202a}',
                '202e \\u{202e}',
                '202f \\u{202f}',
                '205f \\u{205f}',
                '2060 \\u{2060}',
                '2064 \\u{2064}',
                '2066 \\u{2066}',
                '206f \\u{206f}',
                '3000 \\u{3000}',
                'feff \\u{feff}',
                'fff9 \\u{fff9}',
                'fffb \\u{fffb}',
                '1d173 \\u{1d173}',
                '1d17a \\u{1d17a}',
                'e0001 \\u{e0001}',
                'e0020 \\u{e0020}',
                'e007f \\u{e007f}'
            }
        );
    }

    @IsTest
    static void combiningMarksAreEscaped() {
        assertEscapes(
            new List<String>{
                '300 \\u{300}',
                '36f \\u{36f}',
                '483 \\u{483}',
                '489 \\u{489}',
                '93a \\u{93a}',
                '94d \\u{94d}',
                'e31 \\u{e31}',
                '1ab0 \\u{1ab0}',
                '20d0 \\u{20d0}',
                '20e3 \\u{20e3}',
                '302a \\u{302a}',
                '3099 \\u{3099}',
                '309a \\u{309a}',
                'a66f \\u{a66f}',
                'fb1e \\u{fb1e}',
                'fe00 \\u{fe00}',
                'fe0f \\u{fe0f}',
                'fe20 \\u{fe20}',
                'ff9e \\u{ff9e}',
                'ff9f \\u{ff9f}',
                '101fd \\u{101fd}',
                '1d165 \\u{1d165}',
                '1d167 \\u{1d167}',
                'e0100 \\u{e0100}',
                'e01ef \\u{e01ef}'
            }
        );
    }

    @IsTest
    static void privateUseAndUnassignedCodePointsAreEscaped() {
        assertEscapes(
            new List<String>{
                '378 \\u{378}',
                '379 \\u{379}',
                '2065 \\u{2065}',
                'd7a4 \\u{d7a4}',
                'd7ff \\u{d7ff}',
                'e000 \\u{e000}',
                'f8ff \\u{f8ff}',
                'fdd0 \\u{fdd0}',
                'fdef \\u{fdef}',
                'fffe \\u{fffe}',
                'ffff \\u{ffff}',
                '1fffe \\u{1fffe}',
                '2a6e0 \\u{2a6e0}',
                '2fa1e \\u{2fa1e}',
                '3134b \\u{3134b}',
                'e0000 \\u{e0000}',
                'e0080 \\u{e0080}',
                'e01f0 \\u{e01f0}',
                'f0000 \\u{f0000}',
                'ffffd \\u{ffffd}',
                '100000 \\u{100000}',
                '10fffd \\u{10fffd}',
                '10fffe \\u{10fffe}',
                '10ffff \\u{10ffff}'
            }
        );
    }

    @IsTest
    static void charactersThatCanBeSeenAreKept() {
        assertEscapes(
            new List<String>{
                'a1 kept',
                'ac kept',
                'ae kept',
                'b5 kept',
                'e9 kept',
                'ff kept',
                '2ff kept',
                '370 kept',
                '377 kept',
                '37a kept',
                '48a kept',
                '606 kept',
                '903 kept',
                '93b kept',
                '2010 kept',
                '2027 kept',
                '2030 kept',
                '2070 kept',
                '20ac kept',
                '2e80 kept',
                '3001 kept',
                '309b kept',
                '4e00 kept',
                'd7a3 kept',
                'f900 kept',
                'fffc kept',
                'fffd kept',
                '10000 kept',
                '1f1e6 kept',
                '1f3fa kept',
                '1f3fb kept',
                '1f3ff kept',
                '1f600 kept',
                '20000 kept',
                '2a6df kept',
                '2fa1d kept',
                '30000 kept',
                '3134a kept'
            }
        );
    }

    @IsTest
    static void aSweepOfEveryPlaneAgreesWithRust() {
        // Every 97th code point from U+0080 to the end of Unicode, surrogates left out. Rust
        // escapes 9,836 of them, and their code points add up to 221,288,712 modulo
        // 1,000,000,007.
        Integer escaped = 0;
        Long total = 0;
        for (Integer codePoint = 128; codePoint <= 1114111; codePoint += 97) {
            if (codePoint >= 55296 && codePoint <= 57343) {
                continue;
            }
            if (JiffUnicodeEscape.isEscaped(codePoint)) {
                escaped++;
                total = JiffMath.truncMod(total + codePoint, 1000000007L);
            }
        }
        Assert.areEqual(9836, escaped);
        Assert.areEqual(221288712L, total);
    }

    @IsTest
    static void anEscapeIsLowercaseHexWithoutPadding() {
        Assert.areEqual('\\u{a0}', JiffUnicodeEscape.escape(160));
        Assert.areEqual('\\u{200b}', JiffUnicodeEscape.escape(8203));
        Assert.areEqual('\\u{feff}', JiffUnicodeEscape.escape(65279));
        Assert.areEqual('\\u{e0100}', JiffUnicodeEscape.escape(917760));
        Assert.areEqual('\\u{10ffff}', JiffUnicodeEscape.escape(1114111));
    }
}
