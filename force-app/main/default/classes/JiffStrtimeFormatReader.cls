/**
 * A cursor over a `strftime` / `strptime` format string. Internal: `JiffStrtimeFormatter`
 * and `JiffStrtimeParser` share it to walk the format and to read the flag, width and colons
 * after each `%`.
 *
 * Positions are UTF-16 code units. The directives and everything around them are ASCII, so
 * this sees the same structure Jiff sees in the bytes of the format.
 *
 * Mirrors the format handling of `jiff::fmt::strtime::Extension` and the `f` / `bump_fmt`
 * helpers of Jiff's strtime formatter and parser.
 */
public class JiffStrtimeFormatReader {
    private static final String FLAGS = '_0-^#';
    private static final Long WIDTH_MAX = 255L;

    private final String fmt;
    private final Integer size;
    private Integer pos = 0;

    /** A reader at the start of `fmt`, which must not be null. */
    public JiffStrtimeFormatReader(String fmt) {
        if (fmt == null) {
            throw new JiffException('format string must not be null');
        }
        this.fmt = fmt;
        this.size = fmt.length();
    }

    /** The whole format string. */
    public String text() {
        return fmt;
    }

    /** Whether the whole format has been read. */
    public Boolean isDone() {
        return pos >= size;
    }

    /** The position of the current code unit. */
    public Integer position() {
        return pos;
    }

    /** Moves back (or forward) to a position returned by `position`. */
    public void rewind(Integer position) {
        pos = position;
    }

    /** The current code unit. Must not be called when `isDone()`. */
    public Integer f() {
        return fmt.charAt(pos);
    }

    /** Moves past the current code unit and says whether there is anything left. */
    public Boolean bump() {
        pos++;
        return pos < size;
    }

    /** The current character as Jiff shows a format byte in errors: `d`, or `\xC3`. */
    public String describeCurrent() {
        return JiffFmtUtil.describeLeadByte(fmt, pos);
    }

    /**
     * Reads the optional flag, width and colons that come right after a `%`, leaving the
     * reader on the directive. Throws when the format ends before the directive.
     */
    public JiffStrtimeExtension parseExtension() {
        if (JiffFmtUtil.isAsciiAlphabetic(f())) {
            return new JiffStrtimeExtension(null, null, 0);
        }
        String flag = parseFlag();
        // The width is passed on directly: it may be null.
        return new JiffStrtimeExtension(flag, parseWidth(), parseColons());
    }

    private String parseFlag() {
        String current = fmt.substring(pos, pos + 1);
        if (!FLAGS.contains(current)) {
            return null;
        }
        if (!bump()) {
            throw new JiffException(
                'expected to find specifier directive after flag `' +
                    current +
                    '`, but found end of format string'
            );
        }
        return current;
    }

    /**
     * Reads an optional run of digits as a width (or, for `%f` and after `%.`, a precision).
     * Returns null, consuming nothing, when there are no digits. Throws when the number is
     * above 255 or when the format ends right after it.
     */
    public Integer parseWidth() {
        Integer start = pos;
        while (pos < size && JiffFmtUtil.isDigit(fmt.charAt(pos))) {
            pos++;
        }
        if (pos == start) {
            return null;
        }
        Long width = 0L;
        for (Integer i = start; i < pos; i++) {
            Long digit = fmt.charAt(i) - 48;
            if (JiffMath.greaterThan(width, (JiffMath.LONG_MAX - digit) / 10)) {
                throw new JiffException(
                    'failed to parse conversion specifier width: ' +
                    'number too big to parse into 64-bit integer'
                );
            }
            width = width * 10 + digit;
        }
        if (JiffMath.greaterThan(width, WIDTH_MAX)) {
            throw new JiffException('parsed width is too big, max is ' + WIDTH_MAX);
        }
        if (isDone()) {
            throw new JiffException(
                'expected to find specifier directive after parsed width, ' +
                'but found end of format string'
            );
        }
        return width.intValue();
    }

    private Integer parseColons() {
        Integer colons = 0;
        while (colons < 3 && pos < size && fmt.charAt(pos) == 58) {
            colons++;
            pos++;
        }
        if (colons > 0 && isDone()) {
            throw new JiffException(
                'expected to find specifier directive after colons, ' +
                'but found end of format string'
            );
        }
        return colons;
    }
}
