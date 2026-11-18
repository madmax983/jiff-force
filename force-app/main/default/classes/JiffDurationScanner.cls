/**
 * A cursor over the text of a duration that is being parsed. Internal: not part of the public
 * API.
 *
 * Jiff's parsers work on byte slices and hand back "the rest of the input" after each step.
 * Apex has no slices, so the ISO 8601 duration parser in `JiffTemporal` and the friendly
 * parser in `JiffFriendlyParser` share this cursor instead. It knows the pieces both formats
 * have in common: unsigned unit values, fractional digits, whitespace, and the error raised
 * when input is left over.
 *
 * Characters are UTF-16 code units, as returned by `String.charAt`.
 *
 * Mirrors the helpers in `jiff::util::parse`, `jiff::fmt::util::parse_temporal_fraction`,
 * `jiff::fmt::Parsed::into_full` and `jiff::util::escape`.
 */
public class JiffDurationScanner {
    // The largest value of an unsigned 64 bit integer, which is what Jiff parses each unit
    // value into before it knows the sign of the duration.
    private static final JiffI128 U64_MAX = JiffI128.parse('18446744073709551615');
    // Jiff reads at most this many digits for one unit value. It is one more than the longest
    // unsigned 64 bit integer, so that a leading zero does not hide an overflow.
    private static final Integer MAX_VALUE_DIGITS = 21;
    private static final Integer MAX_FRACTION_DIGITS = 9;
    private static final String HEX_DIGITS = '0123456789abcdef';

    private final String input;
    private final Integer size;
    private Integer pos = 0;

    /** Starts scanning at the beginning of `input`, which must not be null. */
    public JiffDurationScanner(String input) {
        if (input == null) {
            throw new JiffException('cannot parse a duration from a null string');
        }
        this.input = input;
        this.size = input.length();
    }

    /** Whether all of the input has been consumed. */
    public Boolean isDone() {
        return pos >= size;
    }

    /** The next character without consuming it, or -1 at the end of the input. */
    public Integer peek() {
        return pos < size ? input.charAt(pos) : -1;
    }

    /** The offset of the next character. Pass it to `rewind` to come back here. */
    public Integer position() {
        return pos;
    }

    /** Moves back to an offset previously returned by `position`. */
    public void rewind(Integer position) {
        pos = position;
    }

    /** Consumes `count` characters. */
    public void advance(Integer count) {
        pos += count;
    }

    /** Consumes the next character when it is `ch`, and says whether it did. */
    public Boolean eat(Integer ch) {
        if (peek() != ch) {
            return false;
        }
        pos++;
        return true;
    }

    /** Consumes the next character when it is `first` or `second`, and says whether it did. */
    public Boolean eatEither(Integer first, Integer second) {
        return eat(first) || eat(second);
    }

    /** Consumes `text` when the input continues with exactly that, and says whether it did. */
    public Boolean eatText(String text) {
        if (!upcoming(text.length()).equals(text)) {
            return false;
        }
        pos += text.length();
        return true;
    }

    /** Up to `maxLength` characters of the remaining input, without consuming them. */
    public String upcoming(Integer maxLength) {
        return input.substring(pos, Math.min(size, pos + maxLength));
    }

    /**
     * Whether the next character is whitespace: a space, tab, line feed, form feed or carriage
     * return.
     */
    public Boolean isAtWhitespace() {
        Integer ch = peek();
        return ch == 32 || ch == 9 || ch == 10 || ch == 13 || ch == 12;
    }

    /** Consumes any run of whitespace. */
    public void skipWhitespace() {
        while (isAtWhitespace()) {
            pos++;
        }
    }

    /**
     * Consumes a run of ASCII digits and returns its value, or null (consuming nothing) when
     * the next character is not a digit.
     *
     * The value is unsigned and may be as large as an unsigned 64 bit integer, which is more
     * than a `Long` holds; `JiffDurationUnits` applies the sign and the range checks later.
     * Throws when the digits spell a number beyond that.
     */
    public JiffI128 unitValue() {
        Integer start = pos;
        while (pos - start < MAX_VALUE_DIGITS && isDigit(peek())) {
            pos++;
        }
        if (pos == start) {
            return null;
        }
        JiffI128 value = JiffI128.parse(input.substring(start, pos));
        if (value.compareTo(U64_MAX) > 0) {
            throw new JiffException('number too big to parse into 64-bit integer');
        }
        return value;
    }

    /**
     * Consumes a decimal separator (`.` or `,`) and the one to nine digits after it, and
     * returns them scaled to nine places, so `.5` is `500000000`. Returns -1 (consuming
     * nothing) when the next character is not a decimal separator.
     *
     * Throws when the separator is not followed by a digit. Digits beyond the ninth are left
     * unconsumed, which makes the caller reject them.
     */
    public Integer fraction() {
        if (!eatEither(46, 44)) {
            return -1;
        }
        Integer start = pos;
        Integer value = 0;
        while (pos - start < MAX_FRACTION_DIGITS && isDigit(peek())) {
            value = value * 10 + (peek() - 48);
            pos++;
        }
        if (pos == start) {
            throw new JiffException(
                'found decimal after seconds component, ' +
                'but did not find any digits after decimal'
            );
        }
        for (Integer i = pos - start; i < MAX_FRACTION_DIGITS; i++) {
            value *= 10;
        }
        return value;
    }

    /**
     * Requires that all of the input was consumed. `parsed` is the text of the value parsed
     * so far, which is quoted in the error along with whatever input is left.
     */
    public void finish(String parsed) {
        if (isDone()) {
            return;
        }
        throw new JiffException(
            'parsed value \'' +
                parsed +
                '\', but unparsed input ' +
                quote(input.substring(pos)) +
                ' remains (expected no unparsed input)'
        );
    }

    /**
     * The next character as Jiff shows a single unexpected byte in its error messages. Jiff
     * parses UTF-8, so for a character outside ASCII this is the first byte of its encoding,
     * written as a hex escape such as `\xC2`. Must not be called at the end of the input.
     */
    public String describeNext() {
        return escapeByte(nextUtf8Byte());
    }

    /** The first byte of the UTF-8 encoding of the next character. */
    private Integer nextUtf8Byte() {
        Integer unit = input.charAt(pos);
        if (unit < 128) {
            return unit;
        }
        if (unit < 2048) {
            return 192 + unit / 64;
        }
        Boolean isPair =
            unit >= 55296 &&
            unit <= 56319 &&
            pos + 1 < size &&
            input.charAt(pos + 1) >= 56320 &&
            input.charAt(pos + 1) <= 57343;
        if (!isPair) {
            return 224 + unit / 4096;
        }
        // A surrogate pair is one code point of four bytes: 65536 plus ten bits from each
        // half. The leading byte carries the bits above the eighteenth.
        Integer codePoint = 65536 + (unit - 55296) * 1024 + (input.charAt(pos + 1) - 56320);
        return 240 + codePoint / 262144;
    }

    /**
     * Formats one byte the way `jiff::util::escape::Byte` does: printable ASCII as itself, the
     * usual backslash escapes for tabs, line breaks, quotes and backslashes, and `\xNN` with
     * uppercase hex digits for everything else.
     */
    public static String escapeByte(Integer value) {
        return escapeAscii(value, true);
    }

    /**
     * Wraps `text` in double quotes with the escapes `jiff::util::escape::Bytes` applies:
     *
     * - ASCII control characters, quotes and backslashes are escaped (`\t`, `\"`, `\x7f`).
     * - A character outside ASCII that cannot be seen on its own is written as a Unicode
     *   escape holding its code point: a no-break space, a zero width space, a combining
     *   accent. `JiffUnicodeEscape` knows which characters those are and how they are written.
     * - Every other character is kept as it is.
     *
     * A surrogate without its partner is not a character at all. Jiff would see it as three
     * bytes that are not valid UTF-8, and it escapes such bytes one at a time (`\xed\xa0\x80`).
     */
    public static String quote(String text) {
        String out = '"';
        Integer textLength = text.length();
        Integer i = 0;
        while (i < textLength) {
            Integer unit = text.charAt(i);
            Integer width = 1;
            if (unit == 0) {
                out += '\\0';
            } else if (unit < 128) {
                out += escapeAscii(unit, false);
            } else if (unit < 55296 || unit > 57343) {
                out += JiffUnicodeEscape.isEscaped(unit)
                    ? JiffUnicodeEscape.escape(unit)
                    : text.substring(i, i + 1);
            } else if (
                unit <= 56319 &&
                i + 1 < textLength &&
                text.charAt(i + 1) >= 56320 &&
                text.charAt(i + 1) <= 57343
            ) {
                // A surrogate pair is one code point: 65536 plus ten bits from each half.
                Integer codePoint = 65536 + (unit - 55296) * 1024 + (text.charAt(i + 1) - 56320);
                width = 2;
                out += JiffUnicodeEscape.isEscaped(codePoint)
                    ? JiffUnicodeEscape.escape(codePoint)
                    : text.substring(i, i + 2);
            } else {
                out +=
                    escapeAscii(224 + unit / 4096, false) +
                    escapeAscii(128 + Math.mod(unit / 64, 64), false) +
                    escapeAscii(128 + Math.mod(unit, 64), false);
            }
            i += width;
        }
        return out + '"';
    }

    private static String escapeAscii(Integer value, Boolean upperHex) {
        if (value == 9) {
            return '\\t';
        }
        if (value == 10) {
            return '\\n';
        }
        if (value == 13) {
            return '\\r';
        }
        if (value == 39) {
            return '\\\'';
        }
        if (value == 34) {
            return '\\"';
        }
        if (value == 92) {
            return '\\\\';
        }
        if (value >= 32 && value <= 126) {
            return String.fromCharArray(new List<Integer>{ value });
        }
        Integer high = value / 16;
        Integer low = value - high * 16;
        String hex = HEX_DIGITS.substring(high, high + 1) + HEX_DIGITS.substring(low, low + 1);
        return '\\x' + (upperHex ? hex.toUpperCase() : hex);
    }

    private static Boolean isDigit(Integer ch) {
        return ch >= 48 && ch <= 57;
    }
}
