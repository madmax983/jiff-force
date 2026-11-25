package jiffapex;

/**
 * Shim for {@code System.Assert}. Equality is deliberately strict about
 * types (an Integer never equals a Long) so tests cannot pass here by
 * relying on a coercion the platform might not perform.
 */
public final class Assert {
    private Assert() {}

    public static void areEqual(Object expected, Object actual) {
        areEqual(expected, actual, null);
    }

    public static void areEqual(Object expected, Object actual, String message) {
        if (!same(expected, actual)) {
            fail(prefix(message) + "Expected: " + show(expected) + ", Actual: " + show(actual));
        }
    }

    public static void areNotEqual(Object notExpected, Object actual) {
        areNotEqual(notExpected, actual, null);
    }

    public static void areNotEqual(Object notExpected, Object actual, String message) {
        // Values of different types are never "equal" here, so a mismatch would make
        // this pass without testing anything; Apex would compare the values.
        if (notExpected != null && actual != null && notExpected.getClass() != actual.getClass()) {
            fail(prefix(message) + "areNotEqual operands have different types: "
                + show(notExpected) + " vs " + show(actual));
        }
        if (same(notExpected, actual)) {
            fail(prefix(message) + "Same value: " + show(actual));
        }
    }

    public static void isTrue(boolean condition) {
        isTrue(condition, null);
    }

    public static void isTrue(boolean condition, String message) {
        if (!condition) {
            fail(prefix(message) + "Expected: true, Actual: false");
        }
    }

    public static void isFalse(boolean condition) {
        isFalse(condition, null);
    }

    public static void isFalse(boolean condition, String message) {
        if (condition) {
            fail(prefix(message) + "Expected: false, Actual: true");
        }
    }

    public static void isNull(Object value) {
        isNull(value, null);
    }

    public static void isNull(Object value, String message) {
        if (value != null) {
            fail(prefix(message) + "Expected: null, Actual: " + show(value));
        }
    }

    public static void isNotNull(Object value) {
        isNotNull(value, null);
    }

    public static void isNotNull(Object value, String message) {
        if (value == null) {
            fail(prefix(message) + "Expected: not null, Actual: null");
        }
    }

    public static void isInstanceOfType(Object instance, Class<?> expectedType) {
        isInstanceOfType(instance, expectedType, null);
    }

    public static void isInstanceOfType(Object instance, Class<?> expectedType, String message) {
        if (!expectedType.isInstance(instance)) {
            fail(prefix(message) + "Expected instance of " + expectedType.getSimpleName()
                + ", Actual: " + show(instance));
        }
    }

    public static void fail() {
        throw new AssertException("Assertion Failed");
    }

    public static void fail(String message) {
        throw new AssertException("Assertion Failed: " + message);
    }

    private static boolean same(Object a, Object b) {
        if (a == null || b == null) {
            return a == b;
        }
        if (a.getClass() != b.getClass()) {
            return false;
        }
        return a.equals(b);
    }

    private static String prefix(String message) {
        return message == null ? "" : message + ": ";
    }

    private static String show(Object o) {
        if (o == null) {
            return "null";
        }
        return o + " (" + o.getClass().getSimpleName() + ")";
    }
}
