/**
 * The flag, padding width and colons written between the `%` of a conversion specifier and
 * its directive. In `%_3d` the flag is `_` and the width is `3`; in `%::z` there are two
 * colons.
 *
 * The flags are:
 *
 * - `_`: pad a number with spaces.
 * - `-`: do not pad a number.
 * - `0`: pad a number with zeros.
 * - `^`: upper case letters.
 * - `#`: swap the case of letters (in practice only for `%p` and `%Z`, which are upper case
 *   by default).
 *
 * `strftime` hands one to the methods of `JiffStrtimeCustom`, so that an implementation can
 * honour, for example, the `^` in `%^c`.
 *
 * Jiff keeps the parts of its `Extension` private. Apex code outside this class cannot see
 * private fields, so the port gives them read-only accessors; that is what lets
 * `JiffStrtimeDefaultCustom` and `JiffStrtimePosixCustom` look at the flag.
 *
 * Mirrors `jiff::fmt::strtime::Extension`.
 */
public class JiffStrtimeExtension {
    private static final String FLAGS = '_0-^#';

    private final String flagValue;
    private final Integer widthValue;
    private final Integer colonsValue;

    /**
     * An extension with the given flag (one of `_`, `0`, `-`, `^`, `#`, or null for none),
     * width (`0..255`, or null for none) and number of colons (`0..3`).
     */
    public JiffStrtimeExtension(String flag, Integer width, Integer colons) {
        if (flag != null && (flag.length() != 1 || !FLAGS.contains(flag))) {
            throw new JiffException(
                'strftime flag must be one of `_`, `0`, `-`, `^` or `#`, but got `' + flag + '`'
            );
        }
        if (width != null) {
            JiffMath.check(width, 0L, 255L, 'strftime width');
        }
        if (colons == null) {
            throw new JiffException('the number of colons must not be null');
        }
        JiffMath.check(colons, 0L, 3L, 'strftime colons');
        this.flagValue = flag;
        this.widthValue = width;
        this.colonsValue = colons;
    }

    /** The flag (`_`, `0`, `-`, `^` or `#`), or null when there is none. */
    public String flag() {
        return flagValue;
    }

    /** The padding width (or precision, for `%f`), or null when none was written. */
    public Integer width() {
        if (widthValue == null) {
            return null;
        }
        return widthValue;
    }

    /** The number of colons, `0` to `3`. */
    public Integer colons() {
        return colonsValue;
    }

    /** Whether the flag is `^`, asking for upper case letters. */
    public Boolean isUppercase() {
        return '^'.equals(flagValue);
    }

    /** A copy of this extension with another width. Null clears the width. */
    public JiffStrtimeExtension withWidth(Integer width) {
        if (width == null) {
            return new JiffStrtimeExtension(flagValue, null, colonsValue);
        }
        return new JiffStrtimeExtension(flagValue, width, colonsValue);
    }
}
