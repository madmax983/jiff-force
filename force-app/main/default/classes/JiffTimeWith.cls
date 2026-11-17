/**
 * A builder for a new `JiffTime` that starts from the fields of an existing one. Create it
 * with `JiffTime.with()`, set the fields that should change and call `build()`:
 *
 *     JiffTime t1 = JiffTime.newInstance(0, 0, 24, 0);
 *     JiffTime t2 = t1.with().hour(15).minute(30).millisecond(10).build();  // 15:30:24.01
 *
 * Fields that are not set keep the value they have on the original time. Nothing is validated
 * until `build()`, which checks every field once. The one exception is a null value, which
 * the setter itself rejects: there is no such thing as "no hour" to build a time from.
 *
 * The fractional second can be set in two ways, and they cannot be mixed. `millisecond`,
 * `microsecond` and `nanosecond` each replace three digits of the fraction and leave the rest
 * alone, while `subsecNanosecond` replaces the whole fraction. Setting `subsecNanosecond`
 * together with any of the other three makes `build()` throw, whatever the values are.
 *
 * Builders are immutable; each setter returns a new builder, and setting the same field
 * again replaces the earlier value.
 *
 * Mirrors `jiff::civil::TimeWith`.
 */
public class JiffTimeWith {
    // Indexes into `fields`.
    private static final Integer HOUR_SLOT = 0;
    private static final Integer MINUTE_SLOT = 1;
    private static final Integer SECOND_SLOT = 2;
    private static final Integer MILLISECOND_SLOT = 3;
    private static final Integer MICROSECOND_SLOT = 4;
    private static final Integer NANOSECOND_SLOT = 5;
    private static final Integer SUBSEC_SLOT = 6;

    private final JiffTime original;
    // One slot per field, holding null until that field's setter is called. The setters refuse
    // a null value, so null always means "not set".
    private final List<Integer> fields;

    /** Starts a builder from `original`. Prefer `original.with()`, which reads better. */
    public JiffTimeWith(JiffTime original) {
        this(original, new List<Integer>{ null, null, null, null, null, null, null });
    }

    private JiffTimeWith(JiffTime original, List<Integer> fields) {
        this.original = original;
        this.fields = fields;
    }

    /** Sets the hour. `build()` throws unless it is in `0..23`. */
    public JiffTimeWith hour(Integer hour) {
        if (hour == null) {
            throw missing('hour');
        }
        return withField(HOUR_SLOT, hour);
    }

    /** Sets the minute. `build()` throws unless it is in `0..59`. */
    public JiffTimeWith minute(Integer minute) {
        if (minute == null) {
            throw missing('minute');
        }
        return withField(MINUTE_SLOT, minute);
    }

    /** Sets the second. `build()` throws unless it is in `0..59`. */
    public JiffTimeWith second(Integer second) {
        if (second == null) {
            throw missing('second');
        }
        return withField(SECOND_SLOT, second);
    }

    /**
     * Sets the millisecond component of the fractional second, leaving the microsecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     *
     *     JiffTime.newInstance(15, 21, 35, 0).with().millisecond(123).build();  // 15:21:35.123
     */
    public JiffTimeWith millisecond(Integer millisecond) {
        if (millisecond == null) {
            throw missing('millisecond');
        }
        return withField(MILLISECOND_SLOT, millisecond);
    }

    /**
     * Sets the microsecond component of the fractional second, leaving the millisecond and
     * nanosecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     *
     *     JiffTime.newInstance(15, 21, 35, 0).with().microsecond(123).build();  // 15:21:35.000123
     */
    public JiffTimeWith microsecond(Integer microsecond) {
        if (microsecond == null) {
            throw missing('microsecond');
        }
        return withField(MICROSECOND_SLOT, microsecond);
    }

    /**
     * Sets the nanosecond component of the fractional second, leaving the millisecond and
     * microsecond components alone. `build()` throws unless it is in `0..999`, or if
     * `subsecNanosecond` is also set.
     *
     *     JiffTime t = JiffTime.newInstance(15, 21, 35, 0);
     *     t.with().nanosecond(123).build();  // 15:21:35.000000123
     */
    public JiffTimeWith nanosecond(Integer nanosecond) {
        if (nanosecond == null) {
            throw missing('nanosecond');
        }
        return withField(NANOSECOND_SLOT, nanosecond);
    }

    /**
     * Sets the whole fractional second, in nanoseconds. `build()` throws unless it is in
     * `0..999,999,999`, or if any of `millisecond`, `microsecond` or `nanosecond` is also set.
     *
     *     JiffTime t = JiffTime.newInstance(15, 21, 35, 0);
     *     t.with().subsecNanosecond(123456789).build();  // 15:21:35.123456789
     */
    public JiffTimeWith subsecNanosecond(Integer subsecNanosecond) {
        if (subsecNanosecond == null) {
            throw missing('subsecNanosecond');
        }
        return withField(SUBSEC_SLOT, subsecNanosecond);
    }

    /**
     * Creates the time. Fields that were not set come from the original time, so a builder
     * with nothing set returns a time equal to the original.
     *
     * Throws if a field is out of range, or if `subsecNanosecond` was set together with any
     * of `millisecond`, `microsecond` or `nanosecond`.
     */
    public JiffTime build() {
        Integer hour = valueOr(HOUR_SLOT, original.hour());
        Integer minute = valueOr(MINUTE_SLOT, original.minute());
        Integer second = valueOr(SECOND_SLOT, original.second());
        if (isSet(SUBSEC_SLOT)) {
            if (isSet(MILLISECOND_SLOT)) {
                throw conflict('millisecond');
            }
            if (isSet(MICROSECOND_SLOT)) {
                throw conflict('microsecond');
            }
            if (isSet(NANOSECOND_SLOT)) {
                throw conflict('nanosecond');
            }
            return JiffTime.newInstance(hour, minute, second, fields.get(SUBSEC_SLOT));
        }
        // As in Jiff, the hour, minute and second are checked before the fraction.
        JiffTime.newInstance(hour, minute, second, 0);
        Integer millisecond = valueOr(MILLISECOND_SLOT, original.millisecond());
        Integer microsecond = valueOr(MICROSECOND_SLOT, original.microsecond());
        Integer nanosecond = valueOr(NANOSECOND_SLOT, original.nanosecond());
        JiffMath.check(millisecond, 0L, 999L, 'millisecond');
        JiffMath.check(microsecond, 0L, 999L, 'microsecond');
        JiffMath.check(nanosecond, 0L, 999L, 'nanosecond');
        return JiffTime.newInstance(
            hour,
            minute,
            second,
            millisecond * 1000000 + microsecond * 1000 + nanosecond
        );
    }

    private JiffTimeWith withField(Integer index, Integer value) {
        List<Integer> next = fields.clone();
        next.set(index, value);
        return new JiffTimeWith(original, next);
    }

    private Boolean isSet(Integer index) {
        return fields.get(index) != null;
    }

    private Integer valueOr(Integer index, Integer fallback) {
        return isSet(index) ? fields.get(index) : fallback;
    }

    private static JiffException missing(String field) {
        return new JiffException(field + ' must not be null');
    }

    private static JiffException conflict(String field) {
        return new JiffException(
            'cannot set both `JiffTimeWith.' + field + '` and `JiffTimeWith.subsecNanosecond`'
        );
    }
}
