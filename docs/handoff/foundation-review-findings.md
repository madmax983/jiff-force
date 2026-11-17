# Foundation review: confirmed findings

An adversarial review of the foundation layer (as of commit `76c2dbe`) produced these 39 findings.
Each was confirmed by two independent verifiers (finding 15 by one) who reproduced it under AER and,
where relevant, against real Jiff 1.0.0. None has been fixed yet. The code has moved on since the
review, so re-check each against the current source before changing anything.

Suggested grouping for the fix: library (0-14, 29-31, 34-38), harness (15-28), oracle (32-33).

## 0. fromSecsDouble(NaN) does not throw: the `secs != secs` NaN test is false on the Apex runtime, so NaN becomes a garbage duration

- **Area:** signed-duration  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:119
- **Claim:** The NaN guard `if (secs != secs)` relies on IEEE primitive semantics. Under AER, `nan != nan` evaluates to false (and `nan == nan` to true), and every relational comparison with NaN is false, so NaN passes both the NaN guard and the range guard on line 123. `secs.longValue()` then yields Long.MIN and the method returns the duration (-9223372036854775808 s, 0 ns) instead of throwing. Jiff returns Err(ConvertNonFinite) from try_from_secs_f64 and panics in from_secs_f64 / mul_f64 / div_f64. The same hole is reachable through multiplyDouble/divideDouble (NaN factor, or ZERO.multiplyDouble(Infinity) = 0*inf = NaN). The existing test only covers +/-1e30, not NaN, so nothing catches this.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(Double.valueOf('NaN'))` returns secs=-9223372036854775808, nanos=0 (no exception). `JiffSignedDuration.fromSecs(1L).multiplyDouble(Double.valueOf('NaN'))` and `JiffSignedDuration.ZERO.multiplyDouble(Double.valueOf('Infinity'))` return the same value. Jiff 1.0.0: `SignedDuration::try_from_secs_f64(f64::NAN)` = Err("could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)"); mul_f64/div_f64 panic.
- **Fix:** In JiffSignedDuration.fromSecsDouble, replace both guards with forms that do not depend on NaN self-inequality. `!(secs == secs)` must not be used, because `nan == nan` is true under AER.

    // Not finite: NaN - NaN and inf - inf are both NaN, which is not equal to 0 on any runtime.
    if (!((secs - secs) == 0)) {
        throw new JiffException('could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)');
    }
    Double bound = JiffMath.LONG_MAX;
    // Positive form: every comparison with NaN is false, so NaN can never pass.
    if (!(secs >= -bound && secs <= bound)) {
        throw new JiffException('parameter \'floating point seconds\' is not in the required range of ' + JiffMath.LONG_MIN + '..=' + JiffMath.LONG_MAX);
    }

This also makes Infinity report the non-finite message, as Jiff does. The positive-form range test …

## 1. fromSecsDouble at exactly 2^63 (and multiplyDouble/divideDouble on durations near MAX) returns a hugely negative duration under AER; Jiff saturates to i64::MAX seconds

- **Area:** signed-duration  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:131
- **Claim:** The range guard (line 123) correctly admits secs == 2^63 because, as in Jiff, `i64::MAX as f64` is 2^63. Jiff then relies on Rust's saturating float-to-int cast: `secs.trunc() as i64` = i64::MAX, giving (i64::MAX, 0). The port relies on `Double.longValue()` to do the same, but under AER `longValue()` of 2^63 returns Long.MIN, so the result is (Long.MIN, 0): a sign flip from the largest positive input to nearly the most negative duration, with no exception. Because every duration within about 512 s of MAX (or of MIN, when negated) has asSecsDouble() == 2^63, this is reachable through ordinary-looking calls such as MAX.multiplyDouble(1.0). This is runtime dependent: Java's (long) cast saturates, so on the JVM harness (and presumably a real org) the result should match Jiff; I could only execute AER.
- **Failure scenario:** `JiffSignedDuration.MAX.multiplyDouble(1.0)` and `JiffSignedDuration.MAX.divideDouble(1.0)` return secs=-9223372036854775808, nanos=0; Jiff returns (9223372036854775807, 0). `JiffSignedDuration.MIN.multiplyDouble(-1.0)` returns (-9223372036854775808, 0); Jiff returns (9223372036854775807, 0). `JiffSignedDuration.fromSecsDouble(9223372036854775808.0)` returns (-9223372036854775808, 0); Jiff `try_from_secs_f64(9223372036854775808.0)` = Ok((9223372036854775807, 0)). Also (4611686018427387904 s).multiplyDouble(2.0) and (9223372036.854775807 s).multiplyDouble(1e9).
- **Fix:** In JiffSignedDuration.fromSecsDouble, immediately after the range check and before `Long whole = secs.longValue();`, saturate explicitly instead of relying on the runtime's out-of-range Double-to-Long conversion:

    // 2^63 passes the range check (LONG_MAX as a Double is 2^63) but does not fit a Long.
    // Rust's `as i64` saturates; do the same explicitly, since AER's longValue() wraps to LONG_MIN.
    if (secs >= bound) {
        return new JiffSignedDuration(JiffMath.LONG_MAX, 0);
    }

The guard is a Double-to-Double comparison, so the Long relational-operator hazard does not apply; under AER it is true for MAX.asSecsDouble() and false for (MAX-2000s) and for -2^63. No lower-bound branch is needed: -2^63 is exactly Long.MIN and longValue() converts it correctly on AER. The fractional part at 2^63 is zero, so returning nanos = 0 matches Jiff's (i64::MAX, 0).

Add tests to …

## 2. fromSecsDouble rounds by adding 0.5 and truncating, which rounds 0.49999999999999994 ns up to 1 ns; Jiff's f64::round gives 0

- **Area:** signed-duration  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:135
- **Claim:** `nudged = scaled +/- HALF; n = nudged.longValue()` is not equivalent to Rust's `f64::round` (half away from zero). When `scaled` is the largest double below 0.5 (0.5 - 2^-54), `scaled + 0.5` is not representable and rounds to exactly 1.0, so the port produces 1 ns where Jiff produces 0 ns (and -1 ns vs 0 for the negative). The input 4.999999999999999e-10 seconds hits this exactly (4.999999999999999e-10 * 1e9 == 0.49999999999999994 in IEEE double arithmetic), and it is reachable through multiplyDouble/divideDouble as well. For all other scaled values below 2^30 the add is exact or cannot cross an integer, so this is confined to that one magnitude.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(4.999999999999999e-10)` returns (0 s, 1 ns); Jiff `SignedDuration::from_secs_f64(4.999999999999999e-10)` returns 0s. `JiffSignedDuration.newInstance(0L, 1).multiplyDouble(0.49999999999999994)` returns 1 ns; Jiff `SignedDuration::new(0, 1).mul_f64(0.49999999999999994)` = 0s. `newInstance(0L, 1).divideDouble(2.0000000000000004)` returns 1 ns; Jiff div_f64 gives 0s. Negated inputs give -1 ns vs 0.
- **Fix:** In JiffSignedDuration.fromSecsDouble, replace the add-half-and-truncate lines (135-136) with a truncate-then-inspect-fraction round, keeping the rest (the +/-1e9 carry) unchanged:

    // Round half away from zero, as Rust's `f64::round` does. Adding 0.5 first is not
    // equivalent: 0.49999999999999994 + 0.5 rounds to exactly 1.0.
    Long n = scaled.longValue();
    Double truncated = n;
    Double frac = scaled - truncated; // exact, |scaled| < 1e9
    if (frac >= HALF) {
        n += 1;
    } else if (frac <= -HALF) {
        n -= 1;
    }

Add test vectors: fromSecsDouble(Double.valueOf('4.999999999999999e-10')) and its negation -> zero; newInstance(0L, 1).multiplyDouble(Double.valueOf('0.49999999999999994')) -> zero; newInstance(0L, 1).divideDouble(Double.valueOf('2.0000000000000004')) -> zero; keep 5e-10 -> 1 ns as the tie control.

## 3. divDuration by a zero duration and divideDouble(0.0) throw System.MathException instead of matching Jiff (inf/NaN result, or a JiffException)

- **Area:** signed-duration  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:351
- **Claim:** Double division by zero throws `System.MathException: Divide by 0` on the Apex runtime instead of producing Infinity/NaN. (1) `divDuration` (line 351) therefore throws a platform exception for a zero divisor, where Jiff's `div_duration_f64` succeeds and returns +inf, -inf or NaN. (2) `divideDouble(0.0)` (line 346) fails before reaching fromSecsDouble, so the caller gets a System.MathException rather than the JiffException the class documents ('Operations that would overflow throw JiffException'; CLAUDE.md rule 12 'throw only JiffException'). Jiff panics for div_f64(0.0), so only the exception type is wrong there, but code that catches JiffException will not catch it. Neither case is documented or tested.
- **Failure scenario:** `JiffSignedDuration.fromSecs(5L).divDuration(JiffSignedDuration.ZERO)` throws System.MathException 'Divide by 0'; Jiff `SignedDuration::from_secs(5).div_duration_f64(SignedDuration::ZERO)` returns inf (-inf for -5 s, NaN for 0 s / 0 s). `JiffSignedDuration.fromSecs(5L).divideDouble(0.0)` throws System.MathException (`e instanceof JiffException` is false); a `try { ... } catch (JiffException e)` around it does not catch.
- **Fix:** In /home/user/jiff-force/force-app/main/default/classes/JiffSignedDuration.cls:

divideDouble — guard before dividing, since Jiff's outcome is a failure for every dividend (x/0.0 is inf or NaN, which from_secs_f64 rejects):

    public JiffSignedDuration divideDouble(Double divisor) {
        if (divisor == 0) {
            throw new JiffException('could not convert non-finite seconds to signed duration');
        }
        return fromSecsDouble(asSecsDouble() / divisor);
    }

divDuration — return the IEEE result Jiff returns, chosen by the dividend's sign (AER showed both `Double.valueOf('Infinity')` and `Double.valueOf('NaN')` are representable):

    public Double divDuration(JiffSignedDuration other) {
        if (other.isZero()) {
            Integer sign = signum();
            if (sign == 0) {
                return Double.valueOf('NaN');
            }
            return …

## 4. Missing public API: SignedDuration::system_until has no counterpart

- **Area:** signed-duration  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:81
- **Claim:** Every public method of jiff::SignedDuration has a counterpart in the port except those excluded by convention or by the platform (the f32 variants, the *_i128 constructors covered by the Long convention plus the internal fromNanosI128, the try_* variants, unsigned_abs and the std::time::Duration conversions, which have no Apex type to map to, and parse/friendly output which another worker is adding). The one remaining gap is `SignedDuration::system_until(SystemTime, SystemTime) -> Result<SignedDuration>`. CLAUDE.md does not exclude it and defines the naming for platform interop ('uses the word System', e.g. JiffTimestamp.fromSystemDatetime), so the natural counterpart `JiffSignedDuration.systemUntil(Datetime time1, Datetime time2)` is absent. The conversions that live on other types (From<Offset>, TryFrom<Span>) depend on classes not yet in the tree and are not counted here.
- **Failure scenario:** A caller porting `SignedDuration::system_until(t1, t2)?` (elapsed time between two platform instants, negative when t2 is earlier) has no equivalent: `JiffSignedDuration.systemUntil(dt1, dt2)` does not compile. They must hand-write `JiffSignedDuration.fromMillis(dt2.getTime() - dt1.getTime())`.
- **Fix:** Add to JiffSignedDuration.cls, next to the other static constructors:

    /**
     * Returns the duration from `time1` until `time2`, where both are platform `Datetime`
     * values (millisecond precision). The result is negative when `time2` is earlier.
     * Mirrors `SignedDuration::system_until`.
     */
    public static JiffSignedDuration systemUntil(Datetime time1, Datetime time2) {
        if (time1 == null || time2 == null) {
            throw new JiffException('systemUntil requires two non-null Datetime values');
        }
        return fromMillis(JiffMath.checkedSub(time2.getTime(), time1.getTime()));
    }

Notes:
- The null check is my addition; the original suggestion had none, and without it a null argument would surface as a platform NullPointerException (rule 12 says to throw only JiffException).
- `JiffMath.checkedSub` follows rule 3. A platform Datetime's …

## 5. fromInvariantDuration silently wraps instead of throwing when the duration's seconds are Long.MIN and the largest unit is sub-second

- **Area:** span-data  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSpan.cls`:426
- **Claim:** The overflow guard in `scaled` computes `JiffMath.abs(secs)`. For secs == LONG_MIN the negation wraps and abs returns LONG_MIN (negative), so `greaterThan(abs(secs), bound)` is false, the guard is skipped, and `secs * perSecond + extra` is evaluated with silent wrap-around (2^63 * 1000^k mod 2^64 == 0). The result is a span holding only the sub-second remainder instead of a range error. This happens for largest = MILLISECOND, MICROSECOND or NANOSECOND; larger units are caught by the setter range checks. It is reachable with JiffSignedDuration.MIN, which is also what saturatingAdd/saturatingSubtract/saturatingMultiply return on negative overflow. The positive counterpart (MAX) throws correctly, so the behaviour is asymmetric. It also breaks CLAUDE.md rule 3 (no reliance on wrap-around).
- **Failure scenario:** JiffSpan.fromInvariantDuration(JiffUnit.NANOSECOND, JiffSignedDuration.MIN) returns -PT0.999999999S; with newInstance(LONG_MIN, 0) it returns PT0S (a zero span for a duration of about -292 billion years). Same for MILLISECOND (returns PT0S) and MICROSECOND (e.g. -PT0.999999999S). Jiff 1.0.0 returns an error for all of them: "parameter 'nanoseconds' is not in the required range of -9223372036854775807..=9223372036854775807" (respectively 'milliseconds' / 'microseconds').
- **Fix:** In JiffSpan.scaled (force-app/main/default/classes/JiffSpan.cls), stop taking abs of secs:

    private static Long scaled(Long secs, Long perSecond, Long extra, JiffUnit unit) {
        Long max = LIMITS.get(unit.ordinal());
        // `extra` is below one second in magnitude, so abs is safe; `secs` may be LONG_MIN, so compare it signed.
        Long bound = (max - JiffMath.abs(extra)) / perSecond;
        if (JiffMath.greaterThan(secs, bound) || JiffMath.lessThan(secs, -bound)) {
            throw JiffMath.rangeError(JiffMath.plural(unit), -max, max);
        }
        return secs * perSecond + extra;
    }

`bound` is non-negative, so `-bound` cannot overflow. secs and extra always share a sign (a JiffSignedDuration invariant), so |secs * perSecond + extra| <= max exactly when |secs| <= bound.

Add tests in JiffSpanTest asserting the range error for JiffSpan.fromInvariantDuration(u, …

## 6. multiply reports the smallest overflowing unit; Jiff reports the largest

- **Area:** span-data  **Severity:** low  **File:** `force-app/main/default/classes/JiffSpan.cls`:241
- **Claim:** Span::checked_mul checks units in the order years, months, weeks, days, hours, minutes, seconds, milliseconds, microseconds, nanoseconds and returns the first failure. JiffSpan.multiply loops over ordinals 0..9, i.e. nanoseconds first, so when more than one unit overflows the JiffException names a different unit and range than Jiff's error. Whether it throws is the same; only the message differs.
- **Failure scenario:** new JiffSpan().hours(-175307616).days(-4213602).multiply(2) throws "parameter 'hours' is not in the required range of -175307616..=175307616"; Jiff 1.0.0 returns "parameter 'days' is not in the required range of -7304484..=7304484". Likewise years(19998).hours(-32543) * 97652: Apex names 'hours', Jiff names 'years'.
- **Fix:** In JiffSpan.multiply, validate from the largest unit down so the first error thrown matches Jiff's. Not executed, since the repo is read-only for this task:

    Long[] next = new Long[UNIT_COUNT];
    for (Integer i = UNIT_COUNT - 1; i >= 0; i--) {
        Long magnitude = magnitudes.get(i);
        if (magnitude == 0) {
            next[i] = 0L;
            continue;
        }
        Long max = LIMITS.get(i);
        String what = JiffMath.plural(UNITS.get(i));
        if (
            JiffMath.greaterThan(absFactor, max) ||
            JiffMath.greaterThan(magnitude, max / absFactor)
        ) {
            throw JiffMath.rangeError(what, -max, max);
        }
        next[i] = magnitude * absFactor;
    }
    return new JiffSpan(factor < 0 ? -sign : sign, next);

Add a regression test in JiffSpanTest asserting that new JiffSpan().years(19998).hours(-32543).multiply(97652) throws a …

## 7. multiply by Long.MIN throws 'span multiple overflowed' instead of Jiff's range error, and the test pins the non-Jiff wording

- **Area:** span-data  **Severity:** low  **File:** `force-app/main/default/classes/JiffSpan.cls`:239
- **Claim:** Jiff maps a failed `rhs.checked_abs()` to `b::SpanMultiple::error()`, whose message is the standard range wording for the bound ("span multiple", i64::MIN + 1, i64::MAX). The port uses JiffMath.checkedNeg(..., 'span multiple'), which throws the generic overflow wording. CLAUDE.md says error messages follow Jiff's wording, and JiffSpanTest.multipliesEachUnitIndependently (line 161) asserts the port's own wording rather than a value taken from Jiff.
- **Failure scenario:** new JiffSpan().days(1).multiply(JiffMath.LONG_MIN) throws "span multiple overflowed"; Jiff 1.0.0's `1.day().checked_mul(i64::MIN)` returns "parameter 'span multiple' is not in the required range of -9223372036854775807..=9223372036854775807".
- **Fix:** In /home/user/jiff-force/force-app/main/default/classes/JiffSpan.cls, in multiply(Long factor), replace

    Long absFactor = JiffMath.checkedNeg(factor < 0 ? factor : -factor, 'span multiple');

with

    // Mirrors `rhs.checked_abs().ok_or_else(b::SpanMultiple::error)`: only Long.MIN has no absolute value.
    if (factor == JiffMath.LONG_MIN) {
        throw JiffMath.rangeError('span multiple', -JiffMath.LONG_MAX, JiffMath.LONG_MAX);
    }
    Long absFactor = factor < 0 ? -factor : factor;

In /home/user/jiff-force/force-app/main/default/classes/JiffSpanTest.cls (multipliesEachUnitIndependently, around line 161), change the expected message to the value taken from Jiff:

    Assert.areEqual(
        'parameter \'span multiple\' is not in the required range of -9223372036854775807..=9223372036854775807',
        e.getMessage()
    );

## 8. JiffI128.parse accepts non-ASCII Unicode digits past its validation, then leaks a platform exception (or silently parses them)

- **Area:** rounding-i128  **Severity:** low  **File:** `force-app/main/default/classes/JiffI128.cls`:76
- **Claim:** parse() validates its input with `digits.isNumeric()`, which in Apex (and in both local runtimes) is true for any Unicode decimal digit, not just ASCII 0-9. Such input therefore passes the guard and reaches `Long.valueOf(...)` on lines 80-81. Under AER that throws an uncaught System.TypeException instead of the JiffException the method is written to throw, violating CLAUDE.md rule 12 (throw only JiffException; validate digits before valueOf). In the JVM harness the shim is `Character.isDigit` followed by Java `Long.valueOf`, which accepts Unicode digits, so the same input is silently parsed as a number there; the two runners disagree. Impact is limited: parse currently has no production callers (only JiffRoundingTest uses it), so this is a latent defect in an internal helper, not a user-visible bug today.
- **Failure scenario:** JiffI128.parse('١٢٣') (Arabic-Indic digits) or JiffI128.parse('１２３') (fullwidth digits). Expected: JiffException 'invalid 128-bit integer: ...', as for every other malformed input ('1e3', ' 5', '+-5' all throw JiffException). Actual under AER: System.TypeException 'Invalid long: ١٢٣' escapes; a caller catching JiffException does not catch it. Under the JVM harness the call would return 123 instead of failing.
- **Fix:** In `JiffI128.parse` (force-app/main/default/classes/JiffI128.cls:73-83), replace the `isNumeric()` test with an explicit ASCII check before `Long.valueOf`:

    if (digits.length() == 0 || digits.length() > 35) {
        throw new JiffException('invalid 128-bit integer: ' + text);
    }
    for (Integer i = 0; i < digits.length(); i++) {
        Integer ch = digits.charAt(i);
        if (ch < 48 || ch > 57) {
            throw new JiffException('invalid 128-bit integer: ' + text);
        }
    }

Add a test asserting that `JiffI128.parse('١٢٣')` and `JiffI128.parse('１２３')` throw `JiffException`.

`isNumeric` then has no remaining caller in force-app (the only use is JiffI128.cls:76), so the Unicode-aware shim no longer affects library behaviour. No change is needed in `JiffDurationScanner`, which already filters to ASCII digits.

## 9. fromSecsDouble's NaN guard (`secs != secs`) does not fire under AER, so NaN becomes a huge negative duration

- **Area:** apex-portability  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:119
- **Claim:** The only NaN check in JiffSignedDuration.fromSecsDouble is `if (secs != secs)`, which relies on Java primitive semantics (NaN is not equal to itself). Under AER, `nan != nan` is false and `nan == nan` is true, so the guard is skipped. The following range check `secs < -bound || secs > bound` is also false for NaN, so NaN falls through to `secs.longValue()`, which AER evaluates to Long.MIN. The method returns a duration of LONG_MIN seconds instead of throwing. No test covers NaN, so neither runner catches this. Whether a real org compares NaN like Java or like AER can only be confirmed on a real org.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(Double.valueOf('NaN'))` and `JiffSignedDuration.ZERO.multiplyDouble(inf)` (with `inf = 1e300 * 1e300`, so the product is NaN) both return secs=-9223372036854775808, nanos=0 (printed as -PT2562047788015215H30M8S) under AER. Jiff 1.0.0: `try_from_secs_f64(NAN)` returns Err("could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)") and `SignedDuration::ZERO.mul_f64(f64::INFINITY)` panics.
- **Fix:** In JiffSignedDuration.fromSecsDouble, replace the self-inequality guard and the negative range test with one positively phrased test, which is false for NaN under both Java-style and AER comparison semantics. Only the `fix=true` expression was executed under AER; the rest of this sketch was not run.

  Double bound = JiffMath.LONG_MAX;
  if (!(secs >= -bound && secs <= bound)) {
      String text = String.valueOf(secs);
      if (text == 'NaN' || text == 'Infinity' || text == '-Infinity') {
          throw new JiffException(
              'could not convert non-finite floating point seconds to signed duration ' +
              '(floating point seconds must be finite)'
          );
      }
      throw new JiffException(
          'parameter \'floating point seconds\' is not in the required range of ' +
          JiffMath.LONG_MIN + '..=' + JiffMath.LONG_MAX
      );
  }

This also gives …

## 10. Double division by zero throws System.MathException under AER in divDuration and divideDouble

- **Area:** apex-portability  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:351
- **Claim:** `divDuration` (line 351, `asNanosDouble() / other.asNanosDouble()`) and `divideDouble` (line 346, `asSecsDouble() / divisor`) assume Java semantics, where dividing a Double by zero yields Infinity or NaN. Under AER, dividing a Double by 0.0 (or -0.0) throws System.MathException: Divide by 0. So `divDuration` throws where Jiff returns inf/NaN, and `divideDouble(0)` leaks a platform exception instead of the JiffException that fromSecsDouble would raise, breaking CLAUDE.md rule 12 (throw only JiffException). Neither zero-divisor case is tested. I did not run the JVM harness (read-only review); its Infinity result is inferred from Java semantics. Real-org behaviour can only be confirmed on a real org.
- **Failure scenario:** `JiffSignedDuration.fromSecs(5).divDuration(JiffSignedDuration.ZERO)` throws System.MathException under AER; Jiff's `div_duration_f64` returns inf (and NaN for 0/0). `Double z = 0; JiffSignedDuration.fromSecs(5).divideDouble(z)` throws System.MathException under AER, so a caller's `catch (JiffException e)` does not catch it; Jiff's `div_f64(0.0)` fails with its own non-finite error.
- **Fix:** Guard the divisor explicitly before dividing, in JiffSignedDuration.cls.

divideDouble:

    public JiffSignedDuration divideDouble(Double divisor) {
        if (divisor == 0) {
            // x/0 is inf or NaN in Jiff, which from_secs_f64 rejects as non-finite.
            throw new JiffException('could not convert non-finite seconds to signed duration');
        }
        return fromSecsDouble(asSecsDouble() / divisor);
    }

divDuration: throw a JiffException when `other.isZero()` (e.g. 'division of a signed duration by a zero duration') and document it in the method comment and CLAUDE.md as a deliberate difference from Jiff's inf/NaN result. I recommend throwing over returning `Double.valueOf('Infinity')` / `'NaN'`: those values parse under AER, but NaN does not behave as IEEE there (`n != n` is false), so a returned NaN is a trap for callers.

Add tests for both zero-divisor cases …

## 11. JiffSpan.fromInvariantDuration silently returns a tiny span for a duration of LONG_MIN seconds

- **Area:** apex-portability  **Severity:** low  **File:** `force-app/main/default/classes/JiffSpan.cls`:426
- **Claim:** `scaled()` guards its multiplication with `JiffMath.greaterThan(JiffMath.abs(secs), (max - JiffMath.abs(extra)) / perSecond)`. `JiffMath.abs` (JiffMath.cls:101) is `value < 0 ? -value : value` with no overflow check, so `abs(LONG_MIN)` wraps to LONG_MIN. The guard then compares a negative number against a positive limit, passes, and `secs * perSecond + extra` wraps (LONG_MIN * 1000 is 0 mod 2^64). The helper returns a wrong span instead of the range error its doc comment promises. This is reliance on wrap-around, which CLAUDE.md rule 3 forbids, and it behaves the same on any runtime with 64-bit wrapping. Today's only caller (JiffTime.until) cannot pass such a duration, but the method is public and CLAUDE.md lists it as a shared helper for the types still to be ported.
- **Failure scenario:** `JiffSpan.fromInvariantDuration(JiffUnit.MILLISECOND, JiffSignedDuration.MIN)` returns `-PT0.999999999S` (getMilliseconds() == -999); `JiffUnit.NANOSECOND` gives the same. Correct behaviour is a range error, which is what the port itself produces one second away: `MIN.add(fromSecs(1))` throws "parameter 'milliseconds' is not in the required range of -631107417600000..=631107417600000".
- **Fix:** In JiffSpan.scaled() drop abs on `secs` and bound it on both sides. `abs(extra)` stays safe because |extra| < 10^9, and `limit` is non-negative so `-limit` cannot overflow:

    private static Long scaled(Long secs, Long perSecond, Long extra, JiffUnit unit) {
        Long max = LIMITS.get(unit.ordinal());
        Long limit = (max - JiffMath.abs(extra)) / perSecond;
        if (JiffMath.greaterThan(secs, limit) || JiffMath.lessThan(secs, -limit)) {
            throw JiffMath.rangeError(JiffMath.plural(unit), -max, max);
        }
        return secs * perSecond + extra;
    }

After the guard, |secs * perSecond + extra| <= max <= LONG_MAX, so the arithmetic cannot wrap; using checkedMul/checkedAdd there as well is optional belt and braces.

Add tests asserting the range error for `fromInvariantDuration(MILLISECOND | MICROSECOND | NANOSECOND, JiffSignedDuration.MIN)`, matching Jiff's …

## 12. fromSecsDouble returns LONG_MIN seconds for +2^63 under AER because Double.longValue() does not saturate there

- **Area:** apex-portability  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:131
- **Claim:** `Double bound = JiffMath.LONG_MAX` rounds up to 2^63, and the range check `secs > bound` accepts secs == 2^63, as Jiff does. The code then relies on `secs.longValue()` saturating to Long.MAX for that out-of-range value, which is Java behaviour. Under AER the conversion yields Long.MIN, so the largest accepted positive input produces the most negative seconds value. A real org presumably saturates like Java, but that can only be confirmed on a real org. Only the single double value 2^63 is affected.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(Double.valueOf('9223372036854775808'))` and `JiffSignedDuration.fromSecs(4611686018427387904L).multiplyDouble(2)` both return secs=-9223372036854775808 (isNegative() == true) under AER. Jiff returns secs=9223372036854775807, nanos=0 for both.
- **Fix:** In JiffSignedDuration.fromSecsDouble, after the range check and before line 131 (`Long whole = secs.longValue();`), add:

    // 2^63 passes the range check (as in Jiff) but is outside Long; Rust's cast saturates,
    // and Double.longValue() is not guaranteed to on every runtime.
    if (secs >= bound) {
        return new JiffSignedDuration(JiffMath.LONG_MAX, 0);
    }

No change is needed on the negative side: -2^63 is exactly Long.MIN and already converts correctly. Add a test at exactly 2^63 for both `fromSecsDouble(Double.valueOf('9223372036854775808'))` and `fromSecs(4611686018427387904L).multiplyDouble(2)`, expecting secs = 9223372036854775807, nanos = 0, isNegative = false. I did not apply or run the fix (read-only review); only the guard condition was checked under AER.

## 13. fromSecsDouble rounds with `scaled + 0.5` then truncates, which is off by one nanosecond just below a half

- **Area:** apex-portability  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDuration.cls`:135
- **Claim:** Jiff computes the nanoseconds as `(secs.fract() * 1e9).round()`. The port emulates round-half-away-from-zero with `nudged = scaled ± HALF; n = nudged.longValue()`. When `scaled` is the largest double below 0.5 (0.49999999999999994), `scaled + 0.5` is not representable and rounds to exactly 1.0, so truncation gives 1 instead of 0. This is plain IEEE-754 double arithmetic, so it does not depend on the runtime; the scaled + 0.5 analysis shows no other value can trigger it.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(Double.valueOf('4.9999999999999994e-10')).subsecNanos()` returns 1, and the negated input returns -1. Jiff 1.0.0 returns 0 nanoseconds for both.
- **Fix:** In JiffSignedDuration.fromSecsDouble replace lines 134-136 with a truncate-then-compare rounding (keep operands Double-typed so no Decimal arithmetic sneaks in):

        // Round half away from zero, as Rust's `f64::round` does. Adding 0.5 first is wrong
        // for the largest double below 0.5, whose sum rounds up to exactly 1.0.
        Long n = scaled.longValue();
        Double truncated = n;
        Double rest = scaled - truncated; // exact
        if (rest >= HALF) {
            n += 1;
        } else if (rest <= -HALF) {
            n -= 1;
        }

The existing `n == ±1000000000L` carry block stays as is. Add tests asserting fromSecsDouble(Double.valueOf('4.9999999999999994e-10')) and its negation give asSecs 0 / subsecNanos 0, and that ±5e-10 still give ±1.

## 14. JiffI128.divRem takes the digit-by-digit slow path for any value of 10^18 ns or more (about 31.7 years), including values that fit in a Long

- **Area:** apex-portability  **Severity:** low  **File:** `force-app/main/default/classes/JiffI128.cls`:227
- **Claim:** The fast path in `divRem` requires `hi == 0 && divisor.hi == 0`, i.e. both magnitudes below 10^18. Anything larger goes through 36 iterations of decimal long division with repeated subtraction, each step calling `atLeast` and `JiffMath.compare`, even when dividend and divisor both fit in a Long and native `/` would be exact. `JiffRounding.roundDuration` performs two such divisions per call (JiffRounding.cls:121 and JiffSignedDuration.cls:146). 10^18 ns is only 31.7 years, so ordinary durations and every nanoseconds-since-1970 value after 2001-09-09 take the slow path. This is a CPU-governor risk for bulk work; the absolute cost on a real org can only be measured there.
- **Failure scenario:** Rounding a 40-year duration to 15 minutes makes 258 `JiffMath.compare` calls and 2 slow divisions, versus 12 calls and 0 slow divisions for a 20-year duration. Rounding a duration equal to the current Unix time (1763395200.5 s) to the second makes 302 compare calls. A batch that rounds or divides many such values pays that on every element, where a single Long division would do.
- **Fix:** In JiffI128.divRem, after the existing `hi == 0 && divisor.hi == 0` fast path and before the long division, add a Long-sized fast path (tested in a /tmp copy, 306 pairs identical to the slow path):

        if (fitsLong() && divisor.fitsLong()) {
            Long n64 = hi * BASE + lo;
            Long d64 = divisor.hi * BASE + divisor.lo;
            // LONG_MIN / -1 is the one quotient a Long cannot hold.
            if (d64 != -1 || n64 != JiffMath.LONG_MIN) {
                Long q = n64 / d64;
                return new List<JiffI128>{ valueOf(q), valueOf(n64 - q * d64) };
            }
        }

LONG_MIN / -1 falls through to the existing long division, which returns (9223372036854775808, 0) correctly. This covers about +-292 years of nanoseconds, so JiffTimestamp.round and JiffSignedDuration.round on ordinary values no longer hit the digit loop. Add a unit test in JiffI128Test …

## 15. TimeZone / Datetime.format shims disagree with AER (and Jiff) on abbreviations, pre-1900 offsets, post-2037 rules and the set of zone ids

- **Area:** harness-fidelity  **Severity:** high  **File:** `tools/apexjvm/runtime/jiffapex/TimeZone.java`:29
- **Claim:** TimeZone.getOffset delegates to java.util.TimeZone and Datetime.format(pattern, tz) (Datetime.java:99) to SimpleDateFormat with the local JDK's locale data. JiffTimeZone derives every offset, abbreviation, DST flag and transition from exactly these two calls, and the local JDK answers differently from AER for a large share of zones. The shim's header comment ("delegating to java.util.TimeZone reproduces platform behaviour") is not true of the Apex runtime the project actually tests against. Four classes of divergence: (1) 'z' abbreviations: JDK legacy names (NPT, BRT, WSST, LHST, IRST, WGT, VET, FJT, LINT, EET...) versus AER's GMT+hh:mm form, which the library maps to the tzdb numeric style; 14 of 37 sampled zones differ at every one of 34 instants. JDK also names by current rule rather than historical abbreviation (Europe/London at epoch 0: GMT vs BST). (2) Offsets before a zone's …
- **Failure scenario:** Apex: JiffTimeZone.get(zone).toOffsetInfo(JiffTimestamp.fromSecond(s)) printed as offset/abbreviation/dst, run against the current library.
- Asia/Kathmandu, 1704067200: harness '+05:45 NPT NO'; AER '+05:45 +0545 NO'; Jiff 1.0.0 abbr '+0545'.
- America/Sao_Paulo, 1704067200: harness '-03 BRT'; AER '-03 -03'; Jiff '-03'.
- Pacific/Apia, 1704067200: harness '+13 WSST'; AER '+13 +13'; Jiff '+13'.
- Europe/London, 0: harness '+01 GMT'; AER '+01 BST'; Jiff 'BST'.
- Africa/Casablanca, 2000000000: harness '+01 WEST'; AER '+00 +00'; Jiff offset 0 '+00'.
- America/New_York, -5364662400: harness '-05 EST'; AER '-04:56:02 EST'; Jiff -17762 'LMT'.
- Asia/Gaza, 0: harness 'EET'; AER 'IST'; Jiff 'IST'.
- …
- **Fix:** Keep the JDK backing: Salesforce is a JVM, and swapping in a pinned tzdb would trade agreement with the likely platform for agreement with AER. Instead:

1. **Reject Java-only ids in `JiffTimeZone.lookup`** (JiffTimeZone.cls, next to the existing `GMT+`/`GMT-` rejection). Return null for names starting with `SystemV/` and for the 25 legacy ids: ACT AET AGT ART AST BET BST CAT CNT CST CTT EAT ECT IET IST JST MIT NET NST PLT PNT PRT PST SST VST. Jiff rejects all 38; with this change the harness, AER and Jiff all throw "failed to find time zone". Add a `JiffTimeZoneTest` case asserting `get('AET')` and `get('SystemV/PST8PDT')` throw, and extend the class doc sentence about Java-style ids.

2. **Correct the shim header** in tools/apexjvm/runtime/jiffapex/TimeZone.java (and the `format` shim in Datetime.java). Say it models a JVM-backed platform as an assumption, that answers come from the …

## 16. Date/Datetime shims use the proleptic Gregorian calendar; AER's Date/Datetime are Julian before 1582-10-15

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/runtime/jiffapex/Date.java`:23
- **Claim:** Date.newInstance, addDays, addMonths, daysBetween, dayOfYear and Datetime.newInstanceGmt/yearGmt/monthGmt/dayGmt/dateGmt (Datetime.java:50 `lenient`, `utc()`) are built on java.time.LocalDate/LocalDateTime, which is proleptic Gregorian. AER (matching the platform's GregorianCalendar-style behaviour that JiffDate.toSystemDate's own doc comment describes) switches to the Julian calendar before 15 Oct 1582 and has no year 0 / negative years in Datetime. The harness therefore cannot construct the platform values that exercise the interop edge cases, and gives different arithmetic for every pre-1582 date.
- **Failure scenario:** - `JiffDate.fromSystemDate(Date.newInstance(1500, 2, 29))`: harness returns 1500-03-01 (shim normalises the day away); AER throws JiffException "parameter 'day' for `1500-02` is invalid, must be in range `1..=28`" because the platform Date really is the Julian leap day. Same for 1300-02-29 etc. A valid platform Date is rejected and no harness test can see it.
- `JiffDate.fromSystemDate(Date.newInstance(1582, 10, 4).addDays(1))`: harness 1582-10-05, AER 1582-10-15.
- `JiffDate.fromSystemDate(Date.newInstance(1582, 10, 10))`: harness 1582-10-10, AER 1582-10-20.
- `JiffDate.newInstance(1000,1,1).toSystemDate().daysBetween(JiffDate.newInstance(2000,1,1).toSystemDate())`: harness 365242, AER …
- **Fix:** Back the `Date` and `Datetime` shims with a lenient `java.util.GregorianCalendar` in GMT with the default cutover, instead of `LocalDate`/`LocalDateTime`. Three details from the AER probes matter:

1. **`Date` uses astronomical year numbers.** AER's `Date.newInstance(0,2,29).year()` is 0, and -4 and -9999 come back unchanged. Pass the year straight to lenient `calendar.set(YEAR, y)` (0 becomes 1 BC) and read it back as `era == BC ? 1 - YEAR : YEAR`. Otherwise `JiffDateTest.platformDatesKeepTheirFieldsAcrossTheWholeRange` (`ymd(0,2,29)`, `ymd(-4,2,29)`) breaks on the harness.
2. **`Datetime.yearGmt()` returns the raw era year.** AER gives 10000 for year -9999 and 1 for year 0, with no sign. `Datetime.dateGmt()` must still produce a `Date` with the astronomical year (AER returns -1 for a 2 BC instant).
3. **Leave `Date.daysInMonth` and `Date.isLeapYear` Gregorian.** AER returns 28 and …

## 17. Decimal literals are translated as Java doubles; rule 9 is not enforced

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/transpile.mjs`:248
- **Claim:** A literal such as `0.1` is an Apex Decimal and arithmetic involving it is exact decimal arithmetic (also when the other operand is a Double variable, per AER). terminal() emits the token unchanged, so javac treats it as a binary double. CLAUDE.md rule 9 tells authors to assign the literal to a Double first, but nothing in the translator rejects a decimal literal inside an expression (only the type name `Decimal` is rejected at line 299), so the two runners silently compute different values.
- **Failure scenario:** ```apex
Double a = 0.1 + 0.2;          // harness 0.30000000000000004   AER 0.3
Double x = 3; Double b = x * 0.1;   // harness 0.30000000000000004   AER 0.3
Integer i = 7; Double d = i * 1.1;  // harness 7.700000000000001     AER 7.7
Double e = 1.1 * 1.1;          // harness 1.2100000000000002    AER 1.21
Double s = 0.7 + 0.1;          // harness 0.7999999999999999    AER 0.8
(0.1 + 0.2 == 0.3)             // harness false                 AER true
'' + 1.50                      // harness '1.5'                 AER '1.50'
```
Any library code like `secs * 0.000000001` or a rounding nudge written with a bare literal produces different results on the gate runner and on Apex.
- **Fix:** Enforce rule 9 in `tools/apexjvm/transpile.mjs` with a syntactic check that needs no type inference. Add a `literal` case to `emit()` that fails when the literal text matches `/^\d*\.\d+[dD]?$/`, unless the literal is the whole initializer of a `Double` declaration.

This is narrower than the reviewer's suggestion: "direct Double argument" and "assigned value" would need type resolution the translator does not have. Rule 9 already says to assign to a Double variable first, and all five existing sites have that shape.

```js
case "literal": {
    if (/^\d*\.\d+[dD]?$/.test(node.getText()) && !isDoubleInitializer(node)) {
        fail(node, `decimal literal '${node.getText()}' is a Decimal in Apex; assign it to a ` +
            "Double variable first (`Double x = " + node.getText() + ";`) and use the variable");
    }
    return children(node);
}

/** Whether `literal` is the whole …

## 18. Integer literals with a leading zero are octal in the harness and decimal in Apex

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/transpile.mjs`:248
- **Claim:** Number tokens are copied verbatim into the Java source. Apex has no octal literals (`010` is ten); Java reads a leading zero as octal. Values 010..077 silently change, 08/09 fail javac although they are valid Apex.
- **Failure scenario:** ```apex
Integer oct = 010;            // harness 8,  AER 10
Integer sum = 0100 + 017;     // harness 79, AER 117
```
In a datetime library this is a natural thing to type: `JiffDate.newInstance(2024, 010, 05)` is October on Apex and August on the harness; `JiffTime.newInstance(09, 30, 0, 0)` is a javac error ('integer number too large: 09') on the harness but valid Apex.
- **Fix:** In terminal() in tools/apexjvm/transpile.mjs, normalise integer and long literal tokens before emitting them:

    let text = tok.text;
    // Apex has no octal literals: 010 is ten. Java would read it as eight (and reject 08/09).
    const lz = /^0+(\d+[lL]?)$/.exec(text);
    if (lz) text = lz[1];

This strips redundant leading zeros from pure-digit tokens with an optional L suffix only. `0`, `0L`, `0.5` and `010.5` are unaffected, and the length change is within a line, so line preservation holds.

Alternative, more in keeping with the "reject rather than guess" policy: report a translation error through the existing errors.push(`${fileName}:${tok.line}:${tok.column} ...`) path, with a message such as "integer literal with a leading zero: Apex reads it as decimal, Java as octal; drop the zero".

Either way, add a JiffHarnessTest case pinning the behaviour, e.g. Assert.areEqual(10, …

## 19. Assert.areNotEqual passes vacuously when the operands have different runtime classes

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/runtime/jiffapex/Assert.java`:94
- **Claim:** `same()` returns false whenever the two classes differ. That makes areEqual stricter than Apex (documented, intended), but areNotEqual shares the helper, so it becomes more lenient than Apex: an Integer vs Long, Integer vs Double or List<Long> vs List<Integer> comparison of equal values is reported as 'not equal' and the assertion passes.
- **Failure scenario:** ```apex
Long five = 5;
Assert.areNotEqual(5, five);
```
Harness: passes. AER: `System.AssertException: Assertion Failed: Same value: 5`. A test such as `Assert.areNotEqual(0, duration.asSecs())` (Integer literal against a Long result) can never fail on the harness, whatever the library returns.
- **Fix:** In tools/apexjvm/runtime/jiffapex/Assert.java, make areNotEqual reject a type mismatch instead of counting it as inequality (nulls keep their current behaviour):

    public static void areNotEqual(Object notExpected, Object actual, String message) {
        if (notExpected != null && actual != null && notExpected.getClass() != actual.getClass()) {
            fail(prefix(message) + "areNotEqual operands have different types: "
                + show(notExpected) + " vs " + show(actual));
        }
        if (same(notExpected, actual)) {
            fail(prefix(message) + "Same value: " + show(actual));
        }
    }

Verified on a scratch copy: Integer-vs-Long and Integer-vs-Double now fail with the type message, the same-type control still fails with "Same value", and the list case is unchanged. No existing call site should be affected, since all 27 compare same-class library …

## 20. Java-only java.lang API compiles on the harness; String.format silently returns the wrong value and s.isEmpty() is accepted despite CLAUDE.md

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/transpile.mjs`:57
- **Claim:** Only a short name list of String/collection methods is rejected (JAVA_ONLY_METHODS) and only Math is whitelisted (MATH_ALLOWED). Everything else that java.lang happens to offer is passed through emitDot (line 651) untouched, because the receiver's type is unknown. CLAUDE.md rule 10 says only shimmed system methods may be called and that `isEmpty()` is rejected; neither is enforced.
- **Failure scenario:** Each line translated, compiled and ran on the harness; AER result on the right.
- `String.format('{0}-{1}', new List<Object>{ 1, 2 })` -> harness returns '{0}-{1}' (java.lang.String.format, silently wrong); AER '1-2'.
- `String s = ''; s.isEmpty()` -> harness true; AER 'Method does not exist ... isEmpty() from the type String'.
- `Long.MAX_VALUE`, `Integer.MIN_VALUE` -> harness OK; AER 'Variable does not exist: MAX_VALUE'.
- `Integer.parseInt('42')`, `Long.parseLong('43')`, `Integer.toString(5)`, `Integer.signum(-4)`, `Long.numberOfLeadingZeros(1L)` -> harness OK; AER 'Method does not exist'.
- `Long.valueOf(i)` with Integer i -> harness 5; AER 'Method does not exist or incorrect signature: …
- **Fix:** In tools/apexjvm/transpile.mjs, switch the wrapper types from a blacklist to a whitelist. None of this needs a library change.

1. In `emitDot`, when the receiver text (lower-cased) is `string`, `integer`, `long`, `double` or `boolean`:
   - For a method call, allow only the statics Apex has and the library uses: `valueOf` on all five, plus the routed `STRING_STATICS` (join, fromCharArray, isBlank, isEmpty, isNotBlank) on String. Otherwise `fail(node, "<Type>.<name> is not in the supported subset")`. This rejects String.format, Integer.parseInt, Long.parseLong, Integer.toString(x), signum, numberOfLeadingZeros and the like.
   - For a non-call member (`Long.MAX_VALUE`, `Integer.MIN_VALUE`), fail likewise.
   - If String.format is ever needed, add `format` to `STRING_STATICS` with an `Rt.String_format(String, List<Object>)` shim that has MessageFormat semantics, and pin it in …

## 21. Apex visibility, virtual/override and case-insensitive method rules are not enforced

- **Area:** harness-fidelity  **Severity:** medium  **File:** `tools/apexjvm/transpile.mjs`:498
- **Claim:** All translated classes live in one Java package and several Apex-only rules are erased: (a) a member with no access modifier is private in Apex but package-private in Java, and `protected` is also package-visible in Java; (b) `@TestVisible private` is rewritten to `public` (line 498), so non-test classes can use it too; (c) `virtual` is dropped (line 424) and Java methods/classes are overridable by default, and a missing `override` keyword is not noticed; (d) static methods may be called through an instance; (e) the new case-collision lint (checkVariableName, line 203) only covers variables, not methods.
- **Failure scenario:** All of the following compile and run on the harness; AER rejects each:
- `class Probe { static Integer helper() {..} Integer fld = 3; }` used from class Other -> harness prints 4; AER 'Method is not visible: Integer Probe.helper()' / 'Variable is not visible: Probe.fld'.
- `protected Integer fld` read from an unrelated class -> harness 3; AER 'Variable is not visible'.
- `@TestVisible private static Integer secret()` called from non-test class Other -> harness 42; AER 'Method is not visible'.
- `public class Sub extends Base` where Base and Base.who() are not virtual -> harness prints 'sub'; AER 'Non-virtual and non-abstract type cannot be extended' and 'Non-virtual, non-abstract methods …
- **Fix:** Add a project-wide lint pass rather than changing the generated Java. run.mjs already parses every source before javac, so have transpile() also return per-class declarations and member references, then check them across classes in run.mjs. This keeps the line-preserving output and reports errors against the .cls line.

Checks to add:
1. Visibility: record each member's Apex access (no modifier means private) and whether it is @TestVisible. Reject a `Type.member` or `expr.member` reference from another top-level class to a private or protected member, unless the member is @TestVisible and the referencing class has isTest. A cheaper partial alternative is to emit `private` for members with no modifier and keep `private` on @TestVisible members that no other class references.
2. virtual/override: reject `extends X` when X is a project class not declared `virtual` or `abstract` (Exception …

## 22. Nullable values compared with a literal, switched on, or concatenated throw NullPointerException on the harness where Apex does not

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/transpile.mjs`:582
- **Claim:** emitEquality emits a plain Java `==`/`!=` whenever one side is a literal (`simple` regex). With the new nullability inference the other side may now be a boxed Integer/Long/Boolean/Double (or a Map/List element), which Java unboxes, throwing NullPointerException when it is null; Apex evaluates the comparison to false/true. emitSwitch (line 547) likewise maps `switch on` to a Java switch, which throws on a null selector, while Apex takes `when else`. The harness rejects valid Apex here.
- **Failure scenario:** ```apex
Map<String, Integer> m = new Map<String, Integer>{ 'a' => 1 };
Boolean b = m.get('zz') == 0;                 // harness NPE, AER false
Integer x = find(m, 'zz'); Boolean n = x == null;
if (x == 5) {...}                            // harness NPE, AER false
if (x != 0) {...}                            // harness NPE, AER true
Boolean flag = null; if (flag == true) {...} // harness NPE, AER false
String s = null; switch on s { when 'a' {..} when else {..} }   // harness NPE, AER 'else'
JiffLike e = null; switch on e { when A {..} when else {..} }   // harness NPE, AER 'else'
for (Integer v : new List<Integer>{ 1, null }) { str += v; }    // harness NPE, AER '1null'
```
- **Fix:** Verified in a scratch copy of the harness (full suite green, claimed cases match AER):

1. transpile.mjs `emitEquality`: narrow the raw-operator path to the null literal only: `const simple = /^null$/i;`. Every other comparison, including against integer and boolean literals, falls through to `Rt.eq(...)`. Java overload resolution then picks `eq(long,long)` / `eq(double,double)` / `eq(boolean,boolean)` for primitives and the null-safe `eq(Object,long)` for boxed values.

2. Rt.java: add the boolean overloads, otherwise `Rt.eq(boxedBoolean, true)` is ambiguous:
   `public static boolean eq(Object a, boolean b) { return eq(a, (Object) Boolean.valueOf(b)); }`
   `public static boolean eq(boolean a, Object b) { return eq((Object) Boolean.valueOf(a), b); }`

3. Switch:
   - `emitWhenControl`: emit `case null, default ->` for `when else` (valid on Java 21, which the harness uses).
   - …

## 23. Date.today(), String.valueOf(Date|Datetime) and ambiguous local Datetime construction differ from AER

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/runtime/jiffapex/Date.java`:26
- **Claim:** (a) Date.today() returns `Datetime.now().dateGmt()`, the GMT date; Apex returns the date in the running user's time zone. (b) `String.valueOf(x)` is not routed, so it is java.lang.String.valueOf -> toString(): for a Datetime the shim prints GMT, AER prints the user's local time; for a Date the shim prints 'yyyy-MM-dd 00:00:00', AER prints 'yyyy-MM-dd' (string concatenation agrees on both). (c) Datetime.newInstance(y,m,d,h,mi,s) (Datetime.java:34) resolves a repeated wall-clock time with java.time's earlier-offset rule; AER picks the later instant.
- **Failure scenario:** With user time zone Pacific/Kiritimati at 2026-11-17T16:40Z: `Date.today()` -> harness 2026-11-17, AER 2026-11-18 (while `Datetime.now().dateGmt()` is 2026-11-17 on both).
`String.valueOf(Date.newInstance(2024, 1, 2))` -> harness '2024-01-02 00:00:00', AER '2024-01-02'.
`String.valueOf(Datetime.newInstance(1709170323004L))` with user zone America/Los_Angeles -> harness '2024-02-29 01:32:03', AER '2024-02-28 17:32:03'.
`Datetime.newInstance(2024, 11, 3, 1, 30, 0).getTime()` in America/Los_Angeles -> harness 1730622600000 (PDT), AER 1730626200000 (PST).
A future `JiffDate.today()`-style helper or a message built with String.valueOf(systemDate) would be tested against the wrong behaviour.
- **Fix:** In tools/apexjvm/runtime/jiffapex:
1. Date.today(): compute in the user's zone, e.g. `Date.ofLocal(Instant.ofEpochMilli(Datetime.clockMillis()).atZone(ZoneId.of(UserInfo.getTimeZone().getID())).toLocalDate())`.
2. Datetime.newInstance(y,m,d,h,mi,s): resolve overlaps to the later offset: `lenient(...).atZone(zone).withLaterOffsetAtOverlap()`. Gaps already agree with AER.
3. String.valueOf: have transpile.mjs route `String.valueOf(x)` to an Rt helper (e.g. `Rt.stringValueOf(Object)`) that returns `yyyy-MM-dd` for a Date, `yyyy-MM-dd HH:mm:ss` in UserInfo.getTimeZone() for a Datetime, and otherwise falls back to the existing behaviour. Leave Date/Datetime toString() as they are, because concatenation ('' + date gives 'yyyy-MM-dd 00:00:00', '' + datetime gives GMT) already matches AER.
4. Pin all three in JiffHarnessTest with zone-independent or America/Los_Angeles-fixed assertions: …

## 24. Double semantics differ from AER: division by zero and out-of-range Double-to-Long conversion

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/runtime/jiffapex/Rt.java`:83
- **Claim:** On the harness a Double divided by zero yields Infinity/NaN and Rt.longValue(double) saturates (Java cast). On AER a Double division by zero throws System.MathException ('Divide by 0'), so NaN/Infinity can never be produced that way, and Double.longValue() of an out-of-range value returns Long.MIN_VALUE. Library code whose error handling depends on Infinity/NaN checks or on saturation is only correct on the harness.
- **Failure scenario:** - `Double z = 0; JiffSignedDuration.fromSecs(5).divideDouble(z)`: harness throws JiffException "parameter 'floating point seconds' is not in the required range ..." (Infinity caught by the range check); AER throws an uncaught System.MathException: Divide by 0, i.e. a non-Jiff exception escapes the API.
- `JiffSignedDuration.fromSecsDouble(9223372036854775807L)` (2^63 as a double, which passes the `secs > bound` check): harness 'PT2562047788015215H30M7S' (same as Jiff's Ok(2562047788015215h 30m 7s)); AER '-PT2562047788015215H30M8S' (Long.MIN_VALUE seconds).
- Raw: `Double d = lmax; d.longValue()` -> harness 9223372036854775807, AER -9223372036854775808; `1 / zero` -> harness Infinity, AER …
- **Fix:** Fix the library so it never relies on the runner-specific behaviour; all changes are in `force-app/main/default/classes/JiffSignedDuration.cls`. I ran these three guards on both runners in a scratchpad copy and they give identical, Jiff-matching results.

1. **`fromSecsDouble`**: after the range check and before `secs.longValue()`, saturate the one in-range value that does not fit a Long:
```apex
if (secs == bound) { // 2^63: Rust's `as i64` saturates
    return new JiffSignedDuration(JiffMath.LONG_MAX, 0);
}
```
Every other accepted Double is at most 2^63-1024 in magnitude or exactly -2^63, so `longValue()` is exact on both runners.

2. **`divideDouble`**: guard the divisor before dividing:
```apex
if (divisor == 0) {
    throw new JiffException('could not convert non-finite seconds to signed duration');
}
```
This is the error Jiff's `div_f64(0.0)` raises.

3. **`divDuration`**: guard …

## 25. Runner silently skips @IsTest methods that are not static, take parameters, or sit in a class not annotated @IsTest

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/runtime/apexjvm/Runner.java`:85
- **Claim:** testMethods() keeps only methods that are annotated, static and parameterless, and run.mjs only registers classes whose type declaration carries @IsTest. Anything else is dropped without a diagnostic, so a test that never runs is reported as part of a green run.
- **Failure scenario:** ```apex
@IsTest
private class InstanceTest {
    @IsTest
    void notStatic() { Assert.fail('this test fails'); }
    @IsTest
    static void fine() { Assert.isTrue(true); }
}
```
Harness: '1 passed, 0 failed', exit 0. AER: type error 'IsTest methods must be declared as static'. Likewise a failing `@IsTest static void x()` inside a class without the class-level annotation is never run by the harness (AER: 'Defining type for IsTest methods must be declared as IsTest'), and `@IsTest static void withParam(Integer x)` is skipped (AER reports FAIL 'method not found').
- **Fix:** Enforce it in the translator, where the other Apex-subset rules already fail the build with a file/line message. In tools/apexjvm/transpile.mjs emitClassBodyDeclaration, when a member's modifiers include "@istest": call fail(node, ...) unless the member is a method declaration whose modifiers include "static", whose return type is void and whose formal parameter list is empty ("@IsTest methods must be static void with no parameters"). Also record that the file contains a method-level @IsTest and, after the walk, fail if the top-level type declaration did not carry @IsTest ("@IsTest method in a class that is not annotated @IsTest"); an @IsTest method inside a nested class should be rejected the same way, since Runner only inspects the top-level class's declared methods. run.mjs already exits 1 on any translation error, so no Runner change is strictly needed; optionally, as defence in …

## 26. ApexException shim: getMessage() of the no-argument and cause-only constructors differs from AER

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/runtime/jiffapex/ApexException.java`:18
- **Claim:** `new MyException().getMessage()` returns null on the shim (line 7 leaves message unset) but 'Script-thrown exception' on AER; `new MyException(cause).getMessage()` copies the cause's message on the shim (line 18) but returns null on AER. String concatenation of an exception also differs ('jiffapex.MyException: boom' vs 'MyException:[]: boom').
- **Failure scenario:** ```apex
MyException e0 = new MyException();
MyException e2 = new MyException(new MyException('boom'));
System.debug(e0.getMessage());   // harness null,   AER 'Script-thrown exception'
System.debug(e2.getMessage());   // harness 'boom', AER null
```
Library code such as `CONTEXT + e.getMessage()` (JiffFriendlyParser.cls:64) applied to an exception built with the cause-only constructor would read 'boom' on the harness and 'null' on AER. Today the library only uses the (String) and (String, Exception) constructors, which agree.
- **Fix:** In /home/user/jiff-force/tools/apexjvm/runtime/jiffapex/ApexException.java:
- No-arg constructor: set `this.message = "Script-thrown exception";` (matches AER and documented Salesforce behaviour).
- Cause-only constructor: stop copying the cause's message. Set it to what the target runtime returns: AER gives null; confirm on a real org before pinning (the platform may return 'Script-thrown exception' there instead), or, since the library never uses this form, have the transpiler reject `new XException(causeVar)` / stop generating that constructor at transpile.mjs:534 so the unverified behaviour cannot be relied on.
- Optionally override toString() to return getTypeName() + ":[]: " + getMessage() so concatenating an exception matches AER ('JiffException:[]: boom'), or reject exception-in-string-concatenation in the transpiler.
- Add JiffHarnessTest cases pinning getMessage() for the …

## 27. Smaller shim divergences: Map.keySet() is a copy, String.isBlank whitespace definition, String.join of null, compound-assignment narrowing

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/runtime/jiffapex/Map.java`:47
- **Claim:** Several individually small behaviours of the shims differ from AER: (a) Map.keySet() returns an independent Set; on AER it is a view backed by the map. (b) Rt.String_isBlank (Rt.java:118) uses trim(), i.e. 'every char <= U+0020', where Apex uses Unicode whitespace. (c) Rt.String_join (Rt.java:97) renders a null element as 'null'; AER renders it as empty. (d) `i += longValue` on an Integer compiles to Java's implicit narrowing; AER stores the un-narrowed value. (e) Set/Map toString order is insertion order on the shim and sorted on AER (iteration order agrees).
- **Failure scenario:** - `Map<String,Integer> m = ...{'b'=>2,'a'=>1,'B'=>3}; m.keySet().remove('a'); m.containsKey('a')` -> harness true (size 3), AER false (size 2).
- `String.isBlank(' ')` harness false / AER true; `String.isBlank('\u0001')` harness true / AER false; `String.isBlank(' ')` harness false / AER true.
- `String.join(new List<String>{ 'a', null }, '-')` -> harness 'a-null', AER 'a-'.
- `Integer i = 5; Long big = 5000000000L; i += big;` -> harness 705032709, AER 5000000005.
- `'' + new Set<Integer>{ 30, 10, 20, 5 }` -> harness '{30, 10, 20, 5}', AER '{5, 10, 20, 30}'.
None is exercised by the library today (keySet() is only iterated in tests; isBlank/join-with-null/compound narrowing are unused).
- **Fix:** Keep it cheap and make misuse fail loudly rather than emulate everything:
(a) Map.keySet(): return a live view over the backing LinkedHashMap's keySet (removal writes through; add throws), matching Apex/AER; values() can stay a copy.
(b) String_isBlank: loop over code points with Character.isWhitespace (the Commons-Lang definition Apex is built on) instead of trim(). Note AER and Java disagree on U+00A0 and U+001C..U+001F, so pin only uncontroversial cases in JiffHarnessTest (space, tab, newline, U+2003 blank; U+0001 not blank).
(c) String_join: since real-org rendering of a null element is unconfirmed, throw an AssertException/IllegalArgument in the shim on a null element rather than pick 'null' or '' silently.
(d) Add `-Xlint:lossy-conversions` plus `-Werror` (or scan javac output for that category) to the javac args in tools/apexjvm/run.mjs so an Integer compound assignment with a …

## 28. Valid Apex containing \u sequences is rejected by javac (comments and string literals)

- **Area:** harness-fidelity  **Severity:** low  **File:** `tools/apexjvm/transpile.mjs`:230
- **Claim:** Java translates \uXXXX escapes before lexing, everywhere in the file. Comments are copied verbatim by lead(), and javaString() passes `\u....` through, so (a) any comment containing a backslash followed by 'u' that is not a valid escape is a javac error, and (b) an Apex string escape that denotes a quote, backslash or line terminator (", \, \u000a) breaks the generated literal. Both are valid Apex.
- **Failure scenario:** ```apex
// path C:\users\x
System.debug('ok');                 // harness: javac 'illegal unicode escape'; AER prints ok
System.debug('q\u0022q'.length());   // harness: javac 'unclosed string literal'; AER prints 3
```
- **Fix:** In tools/apexjvm/transpile.mjs:

1. lead(): neutralise backslash-u in hidden tokens (they are only whitespace and comments), e.g. `out += tokens[i].text.replace(/\\u/g, "\\ u");`. Inserting a space is safe for any run of backslashes; do not "fix" it by doubling the backslash, because an already-doubled `\\u` would become three backslashes and turn eligible again.

2. javaString(): decode \uXXXX and re-emit the four code points that Java's pre-lexing translation would break as ordinary escapes, passing every other escape through unchanged:

    const SAFE = { 0x22: '\\"', 0x5c: "\\\\", 0x0a: "\\n", 0x0d: "\\r" };
    ...
    if (ch === "\\") {
        const next = body[i + 1];
        i++;
        if (next === "u") {
            const hex = body.slice(i + 1, i + 5);
            out += SAFE[parseInt(hex, 16)] ?? "\\u" + hex;
            i += 4;
        } else {
            out += next === …

## 29. Platform Date/Datetime interop tests only hold for a Gregorian-calendar user locale; under th_TH five fail and fromSystemDate is 543 years off

- **Area:** test-quality  **Severity:** medium  **File:** `force-app/main/default/classes/JiffDateTest.cls`:762
- **Claim:** The interop tests build their platform values with Date.newInstance(y,m,d) / Datetime.newInstanceGmt(y,...) and read them back with year()/month()/day(). Those calls follow the running user's locale calendar. No test pins or exercises that assumption, and the configured runs (`aer test --timezone America/Los_Angeles`, JVM harness) never use a non-Gregorian locale. So JiffDate.fromSystemDate/toSystemDate (JiffDate.cls:200, :464), which use the same locale-sensitive calls, are wrong for a Thai-locale user without any default-run test noticing. The JiffTimestamp conversions themselves are correct (they use getTime()); there only the tests are locale-fragile.
- **Failure scenario:** Running user locale th_TH (Buddhist calendar). `JiffDate.fromSystemDate(Date.today())` returns 2569-11-17 instead of 2026-11-17. `JiffDate.newInstance(2024,2,29).toSystemDate()` yields a platform Date 199,309 days before today whose fields read back as 2024-03-01. Five tests fail: JiffDateTest.convertsToAndFromAPlatformDate (line 764: expected 2024-02-29, actual 2024-03-01), JiffDateTest.platformDatesKeepTheirFieldsAcrossTheWholeRange (line 794), JiffTimestampTest.convertsFromAPlatformDatetime (line 1047: expected 2024-02-29T12:30:45Z, actual 1481-03-10T12:30:45Z), JiffTimestampTest.convertsToAPlatformDatetimeDroppingSubMilliseconds (line 1070), …
- **Fix:** Library (JiffDate.cls): keep the documented field-for-field semantics but remove the locale calendar's year offset, rather than switching to epoch days (which would turn 1500-02-28 into platform 1500-02-19 and break the documented pre-1582 behaviour and platformDatesKeepTheirFieldsAcrossTheWholeRange).

  // 0 for Gregorian-calendar locales, 543 for th_TH (Buddhist era)
  private static Integer platformYearOffset() {
      return Datetime.newInstance(0L).dateGmt().year() - 1970;
  }
  public static JiffDate fromSystemDate(Date value) {
      if (value == null) { throw new JiffException('the system Date to convert must not be null'); }
      return newInstance(value.year() - platformYearOffset(), value.month(), value.day());
  }
  public Date toSystemDate() {
      ...existing 1582-10-05..14 check...
      return Date.newInstance(yearValue + platformYearOffset(), monthValue, dayValue);
  …

## 30. fromSecsDouble(NaN) is untested; the NaN guard does not fire under AER and can be deleted with every test still green

- **Area:** test-quality  **Severity:** medium  **File:** `force-app/main/default/classes/JiffSignedDurationTest.cls`:252
- **Claim:** convertsToAndFromFractionalSeconds only checks ±1e30 for rejection. Nothing exercises the non-finite branch of JiffSignedDuration.fromSecsDouble (JiffSignedDuration.cls:119, `if (secs != secs)`). Under AER that comparison is false for NaN, so the guard is dead and NaN is silently converted. JiffHarnessTest does not pin NaN comparison semantics either, so the two runners can disagree unnoticed.
- **Failure scenario:** `JiffSignedDuration.fromSecsDouble(Double.valueOf('NaN'))` returns secs=-9223372036854775808, nanos=0 (prints -PT2562047788015215H30M8S) under AER. Jiff 1.0.0 `SignedDuration::try_from_secs_f64(f64::NAN)` returns Err("could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)"). Expected: a JiffException.
- **Fix:** In JiffSignedDuration.fromSecsDouble (force-app/main/default/classes/JiffSignedDuration.cls:117-130), make the rejection independent of how the runner compares NaN. Keep the existing self-inequality test and add a positive-form range test, so NaN fails on any runner:

  Double bound = JiffMath.LONG_MAX;
  Boolean inRange = secs >= -bound && secs <= bound;
  if (secs != secs || (!inRange && !(secs < -bound) && !(secs > bound))) {
      throw new JiffException('could not convert non-finite floating point seconds to signed duration (floating point seconds must be finite)');
  }
  if (!inRange) { throw the existing range JiffException }

A simpler acceptable variant is a single `if (!(secs >= -bound && secs <= bound))` throwing the range error, at the cost of NaN getting the range message instead of Jiff's non-finite one.

To match Jiff's messages for infinities as well, test them …

## 31. Floating-point boundary and divide-by-zero behaviour of JiffSignedDuration is not tested; under AER it flips sign or throws a platform exception

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffSignedDurationTest.cls`:274
- **Claim:** The only range cases are ±1e30. No test covers the largest accepted double (2^63), multiplyDouble near MAX, or a zero divisor in divideDouble/divDuration. On those inputs the port, as executed by AER, diverges from Jiff. The 2^63 result depends on how the runtime converts an out-of-range double to Long, so the JVM harness and a real org may differ from AER; with no test, nothing shows which.
- **Failure scenario:** Under AER: `fromSecsDouble(Double.valueOf('9.223372036854775807e18'))` gives (-9223372036854775808, 0) and `JiffSignedDuration.MAX.multiplyDouble(1.0)` prints -PT2562047788015215H30M8S, a negative duration. Jiff gives (9223372036854775807, 0) for both. `JiffSignedDuration.newInstance(1L,0).divideDouble(0)` and `.divDuration(JiffSignedDuration.ZERO)` throw System.MathException 'Divide by 0', not JiffException (CLAUDE.md rule 12). In Jiff, div_duration_f64 by zero returns inf and div_f64(0.0) panics.
- **Fix:** In JiffSignedDuration.cls:
- fromSecsDouble: stop relying on Double.longValue() at the boundary. After the NaN and range checks, handle the edge explicitly, e.g. `if (secs >= bound) return new JiffSignedDuration(JiffMath.LONG_MAX, 0); if (secs <= -bound) return new JiffSignedDuration(JiffMath.LONG_MIN, 0);` (bound = 2^63 as a Double; these are the values Jiff returns for +/-2^63), then proceed with longValue() for values strictly inside the range.
- divideDouble: `if (divisor == 0) throw new JiffException('division of a signed duration by zero');` before dividing (Jiff's div_f64(0.0) panics, so throwing is the right mapping).
- divDuration: check `other.isZero()` before dividing and throw a JiffException; document it as a deliberate difference from Jiff (which returns inf/NaN), since Apex division by zero cannot portably yield Infinity.

In JiffSignedDurationTest.cls add cases that run …

## 32. JiffOracleDateTest never asserts the dayOfYear column the oracle generates; a wrong DAYS_BEFORE_MONTH entry passes it and all of JiffDateTest

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffOracleDateTest.cls`:26
- **Claim:** oracle/src/civil.rs emits `dayOfYear` as column 5 for all 400 dates (COLUMNS at line 9, d.day_of_year() at line 74). The driver reads columns 0-4, 6, 7 and 8 and skips f.get(5). The hand-written dayOfYear cases in JiffDateTest.countsTheDayOfTheYear only cover January, February, March, August and December, so the Jiff-generated values that would cover the other months go unused.
- **Failure scenario:** Change the November entry of JiffDate.DAYS_BEFORE_MONTH from 304 to 305 (or June from 151 to 150). `JiffDate.newInstance(2023,11,15).dayOfYear()` then returns 320 instead of Jiff's 319, yet JiffOracleDateTest and JiffDateTest both pass. The error is caught only indirectly, by round trips through with().dayOfYear() in JiffDateWithTest.
- **Fix:** In force-app/main/default/classes/JiffOracleDateTest.cls, inside the loop of datesAgreeWithJiff, after the weekday assertion add:

    Assert.areEqual(Integer.valueOf(f.get(5)), d.dayOfYear(), 'day of year of ' + row);

No oracle regeneration is needed, since column 5 is already in the committed JiffOracleDateData rows. I ran this in a scratch copy: it passes against the current JiffDate and fails on the 304 -> 305 mutant. Emitting and asserting day_of_year_no_leap and days_in_year as well is optional and would need an oracle regeneration.

## 33. Rounding vectors almost never land on a tie: HALF_EVEN and HALF_TRUNC tie-breaking is never checked against Jiff

- **Area:** test-quality  **Severity:** low  **File:** `oracle/src/duration.rs`:122
- **Claim:** round_rows pairs an arbitrary duration (mostly random nanoseconds, line 81) with an unrelated unit and increment, so the value is almost never exactly halfway between two multiples. For non-ties all five HALF_* modes give the same answer, so the 300 rows barely distinguish them. The tie tables that do distinguish them (JiffRoundingTest SMALL/WIDE) were, per their own comment, computed with rational arithmetic rather than produced by Jiff.
- **Failure scenario:** Make HALF_EVEN behave like HALF_EXPAND in JiffRounding.shouldExpand (`return expandIsNearer || tie;`), or make HALF_TRUNC expand on ties. JiffOracleDurationTest.roundingAgreesWithJiff still passes, although e.g. 2.5 s rounded to seconds would give 3 s instead of Jiff's 2 s.
- **Fix:** In oracle/src/duration.rs, keep the 300 random rows in round_rows and append a deterministic block of tie rows, then regenerate with `npm run oracle`. JiffOracleDurationTest needs no change apart from, optionally, a higher minimum row count.

For the tie block:
- Loop over every unit in UNITS, every increment in INCREMENTS whose step (nanos per unit * increment) is even, and a few k values covering odd and even, positive and negative, and one large magnitude (e.g. 0, 1, 2, 3, -1, -2, -3, -4, 4_611_686_018_427).
- Compute q = k*step + step/2 + delta in i128 for delta in {-1, 0, 1}.
- Build the duration as SignedDuration::new((q / 1e9) as i64, (q % 1e9) as i32), skipping values whose seconds do not fit in i64.
- Emit one row per mode in MODES, in the existing `secs,nanos|UNIT|increment|MODE|result` format.

Subsample (for example a fixed subset of k per unit/increment) to keep the …

## 34. nextTransition for a start after the 2100 scan horizon is never tested where a transition exists

- **Area:** test-quality  **Severity:** medium  **File:** `force-app/main/default/classes/JiffTimeZoneTest.cls`:1023
- **Claim:** JiffTimeZone.nextTransition has a special ceiling for starts beyond SCAN_HORIZON (JiffTimeZone.cls:403, `Math.max(same, SCAN_HORIZON) + SCAN_YEAR`). The only far-future nextTransition assertions use 9999-12-01 and JiffTimestamp.MAX, where the correct answer is null because nothing changes before the range ends. A version that never searches past 2101 gives the same null, so the path that finds a yearly-rule transition after 2100 is unverified.
- **Failure scenario:** Replace the ceiling with `Math.min(SCAN_HORIZON + SCAN_YEAR, MAX_SECOND)`. `JiffTimeZone.get('America/New_York').nextTransition(JiffTimestamp.fromSecond(16725225600L))` (2500-01-01T00:00:00Z) then returns null. Jiff gives 2500-03-14T07:00:00Z at offset -04; from 9000-01-01T00:00:00Z it gives 9000-03-09T07:00:00Z -04; from 2101-05-31 it gives 2101-11-06T06:00:00Z -05.
- **Fix:** In JiffTimeZoneTest.transitionsAreSoughtOnlyWhereZoneDataHasThem (or a new test beside it), add non-null far-future nextTransition cases whose expected values come from Jiff 1.0.0:

    // A start past the 2100 horizon still finds the yearly rule's next change.
    assertNext(zone('America/New_York'), utc(2500, 1, 1, 0), utc(2500, 3, 14, 7));
    assertNext(zone('America/New_York'), utc(2101, 5, 31, 0), utc(2101, 11, 6, 6));
    assertNext(zone('America/New_York'), utc(9999, 1, 1, 0), utc(9999, 3, 14, 7));

Each of these returns null under the mutant ceiling `Math.min(SCAN_HORIZON + SCAN_YEAR, MAX_SECOND)` and passes on the current code. Optionally add `assertPrevious(zone('America/New_York'), utc(2500, 1, 1, 0), utc(2499, 11, 1, 6))` for symmetry; it is correct per Jiff but does not exercise the nextTransition ceiling.

## 35. JiffOffset.round overflow is only tested on the positive side

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffOffsetTest.cls`:572
- **Claim:** The overflow test rounds JiffOffset.MAX only. Nothing rounds a negative offset past -25:59:59, so the lower half of the range check in JiffOffset.round (JiffOffset.cls:294, `roundedSeconds < -MAX_SECONDS`) is unexercised.
- **Failure scenario:** Drop the lower bound (`if (roundedSeconds > MAX_SECONDS)`). `JiffOffset.MIN.round(JiffUnit.MINUTE)` then returns an offset of -93600 seconds (-26:00), outside the supported range. Jiff 1.0.0 `Offset::MIN.round(Unit::Minute)` and `.round(Unit::Hour)` both return Err("rounding time zone offset resulted in a duration that overflows: parameter 'time zone offset total seconds' is not in the required range of -93599..=93599").
- **Fix:** Extend `roundingCanOverflow` in /home/user/jiff-force/force-app/main/default/classes/JiffOffsetTest.cls to cover the negative side, using the existing `secs()` helper and `RANGE` constant. All of these throw the expected message on the unmodified port and match Jiff 1.0.0:

@IsTest
static void roundingCanOverflow() {
    Map<String, JiffOffset> offsets = new Map<String, JiffOffset>{
        'MAX' => JiffOffset.MAX,
        'MIN' => JiffOffset.MIN
    };
    List<JiffRound> options = new List<JiffRound>{
        JiffRound.to(JiffUnit.MINUTE),
        JiffRound.to(JiffUnit.HOUR)
    };
    for (String name : offsets.keySet()) {
        for (JiffRound option : options) {
            try {
                offsets.get(name).round(option);
                Assert.fail('expected rounding ' + name + ' to overflow');
            } catch (JiffException e) {
                Assert.areEqual(
        …

## 36. The nanosecond-limit boundary test probes max+1, the one value where a wrap-around bug still produces the expected error

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffDateTimeArithmeticTest.cls`:791
- **Claim:** untilInNanosecondsReachesExactlyTheLargestSpan checks `fits` (9223372036854775807 ns) and `tooFar` (exactly one more). If the limit check in JiffSpan.scaled (JiffSpan.cls:426) is weakened so that secs*1e9+extra overflows, max+1 wraps to Long.MIN_VALUE, which JiffSpan.nanoseconds() rejects with the identical message. So the test cannot tell a correct check from an overflowing one. JiffTimestampTest.untilCoversTheWholeRange (line 743) only tests MIN..MAX, about 6e20 ns, far from the boundary.
- **Failure scenario:** With the check weakened to `max / perSecond`, `JiffTimestamp.UNIX_EPOCH.until(JiffTimestamp.newInstance(9223372036L, 854775809), JiffUnit.NANOSECOND)` returns -9223372036854775807 ns, and the same pair as datetimes (2000-01-01T00:00 until 2292-04-10T23:47:16.854775809) likewise: a negative span for a positive difference. With subsecond 999999999 it returns -9223372036709551617. Jiff returns Err("parameter 'nanoseconds' is not in the required range of -9223372036854775807..=9223372036854775807") for every difference above i64::MAX nanoseconds.
- **Fix:** Add out-of-range probes past max+1 so that a wrapped sum lands on a legal negative value and the test fails.

1. In `JiffDateTimeArithmeticTest.untilInNanosecondsReachesExactlyTheLargestSpan`, after the existing `tooFar` assertions, loop over `civil(2292, 4, 10, 23, 47, 16, 854775809)`, `civil(2292, 4, 10, 23, 47, 16, 999999999)` and `civil(2292, 4, 10, 23, 47, 17, 0)`. For each, assert `tryUntil(start, far, JiffUnit.NANOSECOND)` and `tryUntil(far, start, JiffUnit.NANOSECOND)` both equal `'ERR:' + ERROR_TEXT.get('nanos')`.

2. In `JiffTimestampTest` (for example in `untilCoversTheWholeRange`), assert that `JiffTimestamp.UNIX_EPOCH.until(stamp(9223372036L, sub), JiffUnit.NANOSECOND)` and the reverse direction throw the nanoseconds range error for sub = 854775808, 854775809 and 999999999. Also assert that sub = 854775807 returns exactly Long.MAX nanoseconds.

3. In …

## 37. JiffSpanTest pins multiply() error messages that are not Jiff's, and never multiplies a multi-unit span past a limit

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffSpanTest.cls`:161
- **Claim:** multipliesEachUnitIndependently asserts the exact message 'span multiple overflowed' for multiply(LONG_MIN). That text comes from the port (JiffMath.checkedNeg at JiffSpan.cls:239), not from Jiff. The other overflow cases use single-unit spans, so they cannot see that the port checks units from nanoseconds upward while Jiff checks from years downward and therefore names a different unit when more than one overflows.
- **Failure scenario:** `new JiffSpan().days(1).multiply(JiffMath.LONG_MIN)`: Jiff's message is "parameter 'span multiple' is not in the required range of -9223372036854775807..=9223372036854775807"; the test requires 'span multiple overflowed'. `new JiffSpan().years(12).days(15).multiply(7304484L)`: Jiff reports "parameter 'years' is not in the required range of -19998..=19998"; the port reports "parameter 'days' is not in the required range of -7304484..=7304484". No test notices. Success and failure themselves agree with Jiff; only the wording differs.
- **Fix:** In /home/user/jiff-force/force-app/main/default/classes/JiffSpan.cls multiply():

1. Replace the checkedNeg call with Jiff's range error:
   if (factor == JiffMath.LONG_MIN) {
       throw JiffMath.rangeError('span multiple', -JiffMath.LONG_MAX, JiffMath.LONG_MAX);
   }
   Long absFactor = factor < 0 ? -factor : factor;

2. Check units from the largest down so the reported unit matches Jiff, while keeping the result list in index order: start from `List<Long> next = magnitudes.clone();` and loop `for (Integer i = UNIT_COUNT - 1; i >= 0; i--)`, skipping zero magnitudes, throwing the existing rangeError(what, -max, max) on overflow, and otherwise `next.set(i, magnitude * absFactor)`.

In /home/user/jiff-force/force-app/main/default/classes/JiffSpanTest.cls multipliesEachUnitIndependently:

3. Line 161: expect Jiff's text, "parameter 'span multiple' is not in the required range of …

## 38. The epoch-second round-trip loop in JiffDateTimeTest runs only 8 iterations

- **Area:** test-quality  **Severity:** low  **File:** `force-app/main/default/classes/JiffDateTimeTest.cls`:121
- **Claim:** The loop `for (Long second = -377705116800L; second <= 253402300799L; second += 86028121L * 997)` looks like the whole-range sweeps used elsewhere (strides of 997, 1777 and so on over epoch days, thousands of samples). Here the stride is 85,770,036,637 seconds, about 2,718 years, so it takes 8 samples. It is also a pure self round trip (fromEpochSecond then toEpochSecond), so it adds almost nothing beyond the five literal cases above it.
- **Failure scenario:** A fromEpochSecond/toEpochSecond defect confined to some years or times of day (for example a wrong floor for negative seconds in a particular century) is very unlikely to be hit by 8 samples, while the test reads as if it swept -9999..9999.
- **Fix:** Replace the loop at JiffDateTimeTest.cls:121 with a denser sweep that checks against an independently built expected value, not only the round trip:

for (Long second = -377705116800L; second <= 253402300799L; second += 86028121L * 7) {
    Long epochDay = JiffMath.floorDiv(second, 86400L);
    Integer secondOfDay = (Integer) (second - epochDay * 86400L);
    JiffDate d = JiffDate.fromEpochDay(epochDay);
    JiffDateTime expected = JiffDateTime.newInstance(
        d.year(), d.month(), d.day(),
        secondOfDay / 3600, Math.mod(secondOfDay / 60, 60), Math.mod(secondOfDay, 60), 7
    );
    JiffDateTime dt = JiffDateTime.fromEpochSecond(second, 7);
    Assert.areEqual(expected, dt, 'from epoch second ' + second);
    Assert.areEqual(second, dt.toEpochSecond(), 'round trip of ' + dt);
}

Stride 86028121L * 7 gives about 1,049 samples spread over every century and time of day; the plain …
