/**
 * A signed integer wide enough to count nanoseconds across Jiff's whole supported range.
 * Internal: not part of the public API.
 *
 * Jiff does its rounding and duration arithmetic on `i128` nanosecond counts. Apex tops out at
 * a 64 bit `Long`, which holds only about 292 years of nanoseconds, so this class supplies the
 * handful of wide operations the port needs.
 *
 * The value is stored as `hi * 10^18 + lo`, where `lo` has fewer than nineteen digits and both
 * halves share a sign. `hi` is kept below `10^17` in magnitude, so every value satisfies
 * `|value| < 10^35`. That is seven orders of magnitude more than the largest nanosecond count
 * a `JiffSignedDuration` can describe, and it leaves room for intermediate results to be
 * formed without overflowing a `Long`.
 *
 * Instances are immutable.
 */
public class JiffI128 implements Comparable {
    private static final Long BASE = 1000000000000000000L;
    private static final Long HI_LIMIT = 100000000000000000L;
    private static final Long LIMB = 1000000000L;
    /** The place value of the most significant digit of a half: `BASE / 10`. */
    private static final Long TOP_DIGIT = 100000000000000000L;

    public static final JiffI128 ZERO = new JiffI128(0L, 0L);
    public static final JiffI128 ONE = new JiffI128(0L, 1L);

    private final Long hi;
    private final Long lo;

    private JiffI128(Long hi, Long lo) {
        this.hi = hi;
        this.lo = lo;
    }

    /** Builds a value from halves that may be denormalized (any `lo`, mismatched signs). */
    private static JiffI128 normalize(Long hi, Long lo) {
        Long carry = lo / BASE;
        Long h = hi + carry;
        Long l = lo - carry * BASE;
        if (h > 0 && l < 0) {
            h -= 1;
            l += BASE;
        } else if (h < 0 && l > 0) {
            h += 1;
            l -= BASE;
        }
        if (!JiffMath.lessThan(h, HI_LIMIT) || !JiffMath.greaterThan(h, -HI_LIMIT)) {
            throw JiffMath.overflow('128-bit integer arithmetic');
        }
        return new JiffI128(h, l);
    }

    public static JiffI128 valueOf(Long value) {
        Long h = value / BASE;
        return new JiffI128(h, value - h * BASE);
    }

    /** `seconds * 10^9 + nanos`, computed without overflow for any pair of operands. */
    public static JiffI128 ofSecondsAndNanos(Long seconds, Long nanos) {
        Long upper = seconds / LIMB;
        Long lower = seconds - upper * LIMB;
        // |lower * LIMB| < 10^18 and |nanos| fits comfortably beside it.
        Long nanoCarry = nanos / BASE;
        return normalize(upper + nanoCarry, lower * LIMB + (nanos - nanoCarry * BASE));
    }

    /** The exact product of two Longs. */
    public static JiffI128 product(Long a, Long b) {
        return valueOf(a).multiply(b);
    }

    /** Parses an optionally signed run of decimal digits. */
    public static JiffI128 parse(String text) {
        Boolean negative = text.startsWith('-');
        String digits = negative || text.startsWith('+') ? text.substring(1) : text;
        if (digits.length() == 0 || digits.length() > 35 || !digits.isNumeric()) {
            throw new JiffException('invalid 128-bit integer: ' + text);
        }
        Integer split = Math.max(0, digits.length() - 18);
        Long upper = split == 0 ? 0L : Long.valueOf(digits.substring(0, split));
        Long lower = Long.valueOf(digits.substring(split));
        return negative ? new JiffI128(-upper, -lower) : new JiffI128(upper, lower);
    }

    public Boolean isZero() {
        return hi == 0 && lo == 0;
    }

    public Integer signum() {
        if (hi != 0) {
            return hi < 0 ? -1 : 1;
        }
        return lo < 0 ? -1 : (lo > 0 ? 1 : 0);
    }

    public Boolean isNegative() {
        return hi < 0 || lo < 0;
    }

    public JiffI128 negate() {
        return new JiffI128(-hi, -lo);
    }

    public JiffI128 abs() {
        return isNegative() ? negate() : this;
    }

    public JiffI128 add(JiffI128 other) {
        return normalize(hi + other.hi, lo + other.lo);
    }

    public JiffI128 subtract(JiffI128 other) {
        return normalize(hi - other.hi, lo - other.lo);
    }

    public JiffI128 add(Long other) {
        return add(valueOf(other));
    }

    public JiffI128 subtract(Long other) {
        return subtract(valueOf(other));
    }

    /** Whether the value fits in a Long. */
    public Boolean fitsLong() {
        if (hi > 9 || hi < -9) {
            return false;
        }
        if (hi == 9) {
            return !JiffMath.greaterThan(lo, JiffMath.LONG_MAX - 9 * BASE);
        }
        if (hi == -9) {
            return !JiffMath.lessThan(lo, JiffMath.LONG_MIN + 9 * BASE);
        }
        return true;
    }

    public Long toLong() {
        if (!fitsLong()) {
            throw JiffMath.overflow('conversion of a 128-bit integer to a 64-bit integer');
        }
        return hi * BASE + lo;
    }

    public Double toDouble() {
        Double upper = hi;
        Double lower = lo;
        Double base = BASE;
        return upper * base + lower;
    }

    /**
     * Multiplies by a Long using schoolbook multiplication on base 10^9 limbs, so that no
     * intermediate product can exceed a Long.
     */
    public JiffI128 multiply(Long factor) {
        if (isZero() || factor == 0) {
            return ZERO;
        }
        Boolean negative = isNegative() != (factor < 0);
        // Limbs of |this|, least significant first.
        Long absHi = JiffMath.abs(hi);
        Long absLo = JiffMath.abs(lo);
        List<Long> a = new List<Long>{
            limb(absLo, 0),
            limb(absLo, 1),
            limb(absHi, 0),
            limb(absHi, 1)
        };
        // Limbs of |factor|. LONG_MIN has no positive counterpart, so peel its limbs off
        // with truncating division on the negative value instead.
        List<Long> b = new List<Long>();
        Long rest = factor;
        for (Integer i = 0; i < 3; i++) {
            Long next = rest / LIMB;
            b.add(JiffMath.abs(rest - next * LIMB));
            rest = next;
        }
        List<Long> out = new List<Long>{ 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L };
        for (Integer i = 0; i < 4; i++) {
            if (a.get(i) == 0) {
                continue;
            }
            Long carry = 0L;
            for (Integer j = 0; j < 3; j++) {
                Long sum = out.get(i + j) + a.get(i) * b.get(j) + carry;
                carry = sum / LIMB;
                out.set(i + j, sum - carry * LIMB);
            }
            Integer k = i + 3;
            while (carry != 0) {
                Long sum = out.get(k) + carry;
                carry = sum / LIMB;
                out.set(k, sum - carry * LIMB);
                k++;
            }
        }
        if (out.get(4) != 0 || out.get(5) != 0 || out.get(6) != 0 || out.get(7) != 0) {
            throw JiffMath.overflow('128-bit integer arithmetic');
        }
        Long newLo = out.get(1) * LIMB + out.get(0);
        Long newHi = out.get(3) * LIMB + out.get(2);
        if (!JiffMath.lessThan(newHi, HI_LIMIT)) {
            throw JiffMath.overflow('128-bit integer arithmetic');
        }
        return negative ? new JiffI128(-newHi, -newLo) : new JiffI128(newHi, newLo);
    }

    /** Whether the non-negative value `(hi, lo)` is at least `(otherHi, otherLo)`. */
    private static Boolean atLeast(Long hi, Long lo, Long otherHi, Long otherLo) {
        Integer byHi = JiffMath.compare(hi, otherHi);
        return byHi != 0 ? byHi > 0 : !JiffMath.lessThan(lo, otherLo);
    }

    private static Long limb(Long nonNegative, Integer index) {
        return index == 0 ? nonNegative - (nonNegative / LIMB) * LIMB : nonNegative / LIMB;
    }

    /**
     * Truncating division. Returns `{ quotient, remainder }`, where the remainder takes the
     * sign of the dividend, exactly as `/` and `%` do on Rust integers.
     */
    public List<JiffI128> divRem(JiffI128 divisor) {
        if (divisor.isZero()) {
            throw new JiffException('division by zero');
        }
        if (hi == 0 && divisor.hi == 0) {
            Long q = lo / divisor.lo;
            return new List<JiffI128>{ new JiffI128(0L, q), new JiffI128(0L, lo - q * divisor.lo) };
        }
        Boolean negativeQuotient = isNegative() != divisor.isNegative();
        Boolean negativeRemainder = isNegative();
        JiffI128 n = abs();
        JiffI128 d = divisor.abs();
        // Long division one decimal digit at a time. `rem` stays below `d`, so the working
        // halves never exceed 10 * 10^17 in `hi`, which a Long holds with room to spare.
        Long qHi = 0L;
        Long qLo = 0L;
        Long rHi = 0L;
        Long rLo = 0L;
        for (Integer half = 0; half < 2; half++) {
            Long digits = half == 0 ? n.hi : n.lo;
            Long place = TOP_DIGIT;
            while (place > 0) {
                Long digit = digits / place;
                digits -= digit * place;
                place = place / 10;
                // rem = rem * 10 + digit. The top digit of `rLo` is moved into `rHi`
                // first, because `rLo * 10` itself would not fit in a Long.
                Long carry = rLo / TOP_DIGIT;
                rLo = (rLo - carry * TOP_DIGIT) * 10 + digit;
                rHi = rHi * 10 + carry;
                Long count = 0L;
                while (atLeast(rHi, rLo, d.hi, d.lo)) {
                    rHi -= d.hi;
                    rLo -= d.lo;
                    if (rLo < 0) {
                        rLo += BASE;
                        rHi -= 1;
                    }
                    count++;
                }
                // quotient = quotient * 10 + count
                Long qCarry = qLo / TOP_DIGIT;
                qLo = (qLo - qCarry * TOP_DIGIT) * 10 + count;
                qHi = qHi * 10 + qCarry;
            }
        }
        JiffI128 quotient = new JiffI128(qHi, qLo);
        JiffI128 remainder = new JiffI128(rHi, rLo);
        return new List<JiffI128>{
            negativeQuotient ? quotient.negate() : quotient,
            negativeRemainder ? remainder.negate() : remainder
        };
    }

    public JiffI128 divide(JiffI128 divisor) {
        return divRem(divisor).get(0);
    }

    public JiffI128 remainder(JiffI128 divisor) {
        return divRem(divisor).get(1);
    }

    /** Whether the value is odd. */
    public Boolean isOdd() {
        return lo - (lo / 2) * 2 != 0;
    }

    public Integer compareTo(Object other) {
        JiffI128 that = (JiffI128) other;
        return hi != that.hi ? JiffMath.compare(hi, that.hi) : JiffMath.compare(lo, that.lo);
    }

    public Boolean equals(Object other) {
        if (!(other instanceof JiffI128)) {
            return false;
        }
        JiffI128 that = (JiffI128) other;
        return hi == that.hi && lo == that.lo;
    }

    public Integer hashCode() {
        return JiffMath.floorMod(31 * hi + lo, 1000000007L).intValue();
    }

    public override String toString() {
        if (hi == 0) {
            return String.valueOf(lo);
        }
        return String.valueOf(hi) + String.valueOf(JiffMath.abs(lo)).leftPad(18, '0');
    }
}
