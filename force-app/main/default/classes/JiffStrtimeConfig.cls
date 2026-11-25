/**
 * Configuration for `strftime` formatting: lenient mode, and the `JiffStrtimeCustom`
 * implementation behind the locale specifiers `%c`, `%r`, `%X` and `%x`.
 *
 *     JiffStrtimeConfig posix = new JiffStrtimeConfig().custom(new JiffStrtimePosixCustom());
 *     JiffBrokenDownTime.fromDateTime(JiffDateTime.newInstance(2025, 7, 1, 17, 30, 0, 0))
 *         .format('%c', posix);   // Tue Jul  1 17:30:00 2025
 *
 * Most callers never need one: `JiffBrokenDownTime.format(String)` uses the defaults.
 *
 * In lenient mode a conversion specifier that cannot be formatted, because it is unknown or
 * because the value lacks what it needs, is written out literally instead of failing:
 *
 *     JiffBrokenDownTime tm = JiffBrokenDownTime.fromDate(JiffDate.newInstance(2025, 4, 30));
 *     tm.format('%F %z', new JiffStrtimeConfig().lenient(true));   // 2025-04-30 %z
 *
 * The `strftime` methods of the datetime types always format leniently. Lenient mode has no
 * effect on parsing.
 *
 * Configurations are immutable; each setter returns a new instance.
 *
 * Mirrors `jiff::fmt::strtime::Config`.
 */
public class JiffStrtimeConfig {
    private final Boolean lenientValue;
    private final JiffStrtimeCustom customValue;

    /** The default configuration: strict, with `JiffStrtimeDefaultCustom`. */
    public JiffStrtimeConfig() {
        this(false, new JiffStrtimeDefaultCustom());
    }

    private JiffStrtimeConfig(Boolean lenientValue, JiffStrtimeCustom customValue) {
        this.lenientValue = lenientValue;
        this.customValue = customValue;
    }

    /**
     * Turns lenient formatting on or off. When on, a specifier that cannot be formatted is
     * written literally instead of throwing. Off by default.
     */
    public JiffStrtimeConfig lenient(Boolean yes) {
        if (yes == null) {
            throw new JiffException('lenient option must not be null');
        }
        return new JiffStrtimeConfig(yes, customValue);
    }

    /** Sets the implementation used for `%c`, `%r`, `%X` and `%x`. */
    public JiffStrtimeConfig custom(JiffStrtimeCustom custom) {
        if (custom == null) {
            throw new JiffException('strtime customization must not be null');
        }
        return new JiffStrtimeConfig(lenientValue, custom);
    }

    /** Whether lenient formatting is on. */
    public Boolean isLenient() {
        return lenientValue;
    }

    /** The implementation used for `%c`, `%r`, `%X` and `%x`. */
    public JiffStrtimeCustom getCustom() {
        return customValue;
    }
}
