/**
 * Text helpers shared by the `strftime` / `strptime` machinery and the RFC 2822 parser and
 * printer. Internal: not part of the public API.
 *
 * Jiff's formatters work on bytes of UTF-8, while Apex strings are sequences of UTF-16 code
 * units. Nothing in these formats gives a character outside ASCII a meaning, so the port
 * works on code units and only converts to UTF-8 where Jiff's error messages show a byte:
 * `utf8Bytes` gives the bytes of one character, and `describeByte` writes a byte the way
 * Jiff's error messages do (`\xE5`).
 *
 * The English names of months and weekdays live here too; Jiff's `strtime` and `rfc2822`
 * modules each have a copy of them.
 *
 * Mirrors the helpers in `jiff::util::escape`, `jiff::util::parse` and the name tables of
 * `jiff::fmt::strtime` and `jiff::fmt::rfc2822`.
 */
public class JiffFmtUtil {
    /** Full English weekday names, starting with Sunday. */
    public static final List<String> WEEKDAY_NAMES = new List<String>{
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday'
    };

    /** Full English month names, January first. */
    public static final List<String> MONTH_NAMES = new List<String>{
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
    };

    /** The full English name of a weekday, as Rust's `Debug` prints it: `Monday`. */
    public static String weekdayName(JiffWeekday weekday) {
        return WEEKDAY_NAMES.get(JiffWeekdays.toSundayZeroOffset(weekday));
    }

    /** The three letter English abbreviation of a weekday: `Mon`. */
    public static String weekdayAbbreviation(JiffWeekday weekday) {
        return weekdayName(weekday).substring(0, 3);
    }

    /** The full English name of a month (`1..12`): `July`. */
    public static String monthName(Integer month) {
        return MONTH_NAMES.get(month - 1);
    }

    /** The three letter English abbreviation of a month (`1..12`): `Jul`. */
    public static String monthAbbreviation(Integer month) {
        return monthName(month).substring(0, 3);
    }

    /**
     * Wraps an exception's message in a context, the way Jiff's `ErrorContext::context`
     * shows a chain of errors: `context: message`.
     */
    public static JiffException context(String context, JiffException cause) {
        return new JiffException(context + ': ' + cause.getMessage(), cause);
    }

    /** Whether `ch` is an ASCII digit. */
    public static Boolean isDigit(Integer ch) {
        return ch >= 48 && ch <= 57;
    }

    /** Whether `ch` is an ASCII letter. */
    public static Boolean isAsciiAlphabetic(Integer ch) {
        return (ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122);
    }

    /**
     * Whether `ch` is ASCII whitespace in Rust's sense (`u8::is_ascii_whitespace`): a space,
     * tab, line feed, form feed or carriage return. A vertical tab is not.
     */
    public static Boolean isAsciiWhitespace(Integer ch) {
        return ch == 32 || ch == 9 || ch == 10 || ch == 12 || ch == 13;
    }

    /** `ch` with ASCII `A-Z` lowered to `a-z`; every other code unit is returned unchanged. */
    public static Integer toAsciiLower(Integer ch) {
        return ch >= 65 && ch <= 90 ? ch + 32 : ch;
    }

    /** `text` with ASCII letters upper cased and everything else unchanged. */
    public static String toAsciiUpperCase(String text) {
        return mapAsciiCase(text, true);
    }

    /** `text` with ASCII letters lower cased and everything else unchanged. */
    public static String toAsciiLowerCase(String text) {
        return mapAsciiCase(text, false);
    }

    private static String mapAsciiCase(String text, Boolean upper) {
        List<Integer> units = new List<Integer>();
        for (Integer i = 0; i < text.length(); i++) {
            Integer ch = text.charAt(i);
            if (upper && ch >= 97 && ch <= 122) {
                ch -= 32;
            } else if (!upper && ch >= 65 && ch <= 90) {
                ch += 32;
            }
            units.add(ch);
        }
        return String.fromCharArray(units);
    }

    /**
     * Whether `text`, from `start`, begins with `expected` when ASCII letters are compared
     * without regard to case.
     */
    public static Boolean startsWithIgnoreAsciiCase(String text, Integer start, String expected) {
        if (text.length() - start < expected.length()) {
            return false;
        }
        for (Integer i = 0; i < expected.length(); i++) {
            if (toAsciiLower(text.charAt(start + i)) != toAsciiLower(expected.charAt(i))) {
                return false;
            }
        }
        return true;
    }

    /**
     * The UTF-8 bytes of the character that starts at `index` in `text`. A surrogate pair is
     * one four byte character; a surrogate without its partner is encoded as three bytes, the
     * way Jiff would see the invalid UTF-8 that stands for it.
     */
    public static List<Integer> utf8Bytes(String text, Integer index) {
        Integer unit = text.charAt(index);
        if (unit < 128) {
            return new List<Integer>{ unit };
        }
        if (unit < 2048) {
            return new List<Integer>{ 192 + unit / 64, 128 + Math.mod(unit, 64) };
        }
        if (unit >= 55296 && unit <= 56319 && index + 1 < text.length()) {
            Integer low = text.charAt(index + 1);
            if (low >= 56320 && low <= 57343) {
                Integer codePoint = 65536 + (unit - 55296) * 1024 + (low - 56320);
                return new List<Integer>{
                    240 + codePoint / 262144,
                    128 + Math.mod(codePoint / 4096, 64),
                    128 + Math.mod(codePoint / 64, 64),
                    128 + Math.mod(codePoint, 64)
                };
            }
        }
        return new List<Integer>{
            224 + unit / 4096,
            128 + Math.mod(unit / 64, 64),
            128 + Math.mod(unit, 64)
        };
    }

    /**
     * The number of bytes the UTF-8 encoding of `text` from `start` on takes, but counting no
     * further than `maxBytes`. Jiff measures what is left of its input in bytes.
     */
    public static Integer utf8Length(String text, Integer start, Integer maxBytes) {
        Integer total = 0;
        Integer i = start;
        while (i < text.length() && total < maxBytes) {
            Integer width = utf8Bytes(text, i).size();
            total += width;
            i += width == 4 ? 2 : 1;
        }
        return Math.min(total, maxBytes);
    }

    /** The first UTF-8 byte of the character at `index`, as Jiff's errors show it: `\xC3`. */
    public static String describeLeadByte(String text, Integer index) {
        return describeByte(utf8Bytes(text, index).get(0));
    }

    /**
     * One byte as `jiff::util::escape::Byte` shows it: printable ASCII as itself, the usual
     * backslash escapes, and `\xNN` with uppercase hex digits for the rest.
     */
    public static String describeByte(Integer value) {
        return JiffDurationScanner.escapeByte(value);
    }

    /**
     * Text as `jiff::util::escape::Bytes` shows it, without surrounding quotes: control
     * characters, quotes and backslashes escaped, everything visible kept as it is.
     */
    public static String describeText(String text) {
        String quoted = JiffDurationScanner.quote(text);
        return quoted.substring(1, quoted.length() - 1);
    }
}
