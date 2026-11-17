package jiffapex;

/**
 * Runtime helpers the translator routes Apex constructs to when Java's own
 * semantics differ. Every method here models documented Apex behaviour; if a
 * behaviour is unknown it throws instead of guessing.
 */
public final class Rt {
    private Rt() {}

    // ---- equality -------------------------------------------------------

    public static boolean eq(long a, long b) {
        return a == b;
    }

    public static boolean eq(double a, double b) {
        return a == b;
    }

    public static boolean eq(boolean a, boolean b) {
        return a == b;
    }

    public static boolean eq(Object a, long b) {
        return eq(a, (Object) Long.valueOf(b));
    }

    public static boolean eq(long a, Object b) {
        return eq((Object) Long.valueOf(a), b);
    }

    /** Apex `==`: case-insensitive for strings, value equality for numbers. */
    public static boolean eq(Object a, Object b) {
        if (a == null || b == null) {
            return a == b;
        }
        if (a instanceof String && b instanceof String) {
            return ((String) a).equalsIgnoreCase((String) b);
        }
        if (a instanceof Number && b instanceof Number) {
            if (a instanceof Double || b instanceof Double) {
                return ((Number) a).doubleValue() == ((Number) b).doubleValue();
            }
            return ((Number) a).longValue() == ((Number) b).longValue();
        }
        if (a instanceof Boolean && b instanceof Boolean) {
            return a.equals(b);
        }
        if (a instanceof Enum && b instanceof Enum) {
            return a == b;
        }
        throw new IllegalStateException(
            "'==' between " + a.getClass().getSimpleName() + " and " + b.getClass().getSimpleName()
                + " is outside the supported subset; call equals() instead");
    }

    // ---- Math -----------------------------------------------------------

    /** Apex Math.mod: remainder with the sign of the dividend, like Java's %. */
    public static int mod(int a, int b) {
        return a % b;
    }

    public static long mod(long a, long b) {
        return a % b;
    }

    // ---- numeric conversions -------------------------------------------

    public static int intValue(long v) {
        return (int) v;
    }

    public static int intValue(double v) {
        return (int) v;
    }

    public static long longValue(long v) {
        return v;
    }

    public static long longValue(double v) {
        return (long) v;
    }

    public static double doubleValue(long v) {
        return (double) v;
    }

    public static double doubleValue(double v) {
        return v;
    }

    // ---- String statics --------------------------------------------------

    public static String String_join(Object iterable, String separator) {
        StringBuilder sb = new StringBuilder();
        boolean first = true;
        for (Object o : (Iterable<?>) iterable) {
            if (!first) {
                sb.append(separator);
            }
            first = false;
            sb.append(String.valueOf(o));
        }
        return sb.toString();
    }

    public static String String_fromCharArray(List<Integer> chars) {
        StringBuilder sb = new StringBuilder();
        for (Integer c : chars) {
            sb.appendCodePoint(c);
        }
        return sb.toString();
    }

    public static boolean String_isBlank(String s) {
        return s == null || s.trim().isEmpty();
    }

    public static boolean String_isNotBlank(String s) {
        return !String_isBlank(s);
    }

    public static boolean String_isEmpty(String s) {
        return s == null || s.isEmpty();
    }

    // ---- String instance methods ----------------------------------------

    /** Apex leftPad(length): pads with spaces, never truncates. */
    public static String leftPad(String s, int length) {
        return leftPad(s, length, " ");
    }

    public static String leftPad(String s, int length, String pad) {
        if (pad == null || pad.isEmpty()) {
            pad = " ";
        }
        int need = length - s.length();
        if (need <= 0) {
            return s;
        }
        StringBuilder sb = new StringBuilder();
        while (sb.length() < need) {
            sb.append(pad);
        }
        sb.setLength(need);
        return sb.append(s).toString();
    }

    public static String rightPad(String s, int length) {
        return rightPad(s, length, " ");
    }

    public static String rightPad(String s, int length, String pad) {
        if (pad == null || pad.isEmpty()) {
            pad = " ";
        }
        StringBuilder sb = new StringBuilder(s);
        while (sb.length() < length) {
            sb.append(pad);
        }
        if (s.length() < length) {
            sb.setLength(length);
        }
        return sb.toString();
    }

    public static String left(String s, int length) {
        if (length <= 0) {
            return "";
        }
        return length >= s.length() ? s : s.substring(0, length);
    }

    public static String right(String s, int length) {
        if (length <= 0) {
            return "";
        }
        return length >= s.length() ? s : s.substring(s.length() - length);
    }

    public static String mid(String s, int start, int length) {
        if (start < 0) {
            start = 0;
        }
        if (start >= s.length() || length <= 0) {
            return "";
        }
        return s.substring(start, Math.min(s.length(), start + length));
    }

    /** Apex charAt returns the UTF-16 code unit as an Integer. */
    public static int charAt(String s, int index) {
        if (index < 0 || index >= s.length()) {
            throw new ApexException("String index out of range: " + index);
        }
        return s.charAt(index);
    }

    public static List<Integer> getChars(String s) {
        List<Integer> out = new List<Integer>();
        for (int i = 0; i < s.length(); i++) {
            out.add((int) s.charAt(i));
        }
        return out;
    }

    public static List<String> split(String s, String regex) {
        List<String> out = new List<String>();
        for (String part : s.split(regex)) {
            out.add(part);
        }
        return out;
    }

    public static List<String> split(String s, String regex, int limit) {
        List<String> out = new List<String>();
        for (String part : s.split(regex, limit)) {
            out.add(part);
        }
        return out;
    }

    public static String repeat(String s, int times) {
        return times <= 0 ? "" : s.repeat(times);
    }

    public static String reverse(String s) {
        return new StringBuilder(s).reverse().toString();
    }

    public static boolean isNumeric(String s) {
        if (s.isEmpty()) {
            return false;
        }
        for (int i = 0; i < s.length(); i++) {
            if (!Character.isDigit(s.charAt(i))) {
                return false;
            }
        }
        return true;
    }

    public static boolean containsIgnoreCase(String s, String other) {
        return other != null && s.toLowerCase().contains(other.toLowerCase());
    }

    public static String substringBefore(String s, String sep) {
        int i = s.indexOf(sep);
        return i < 0 ? s : s.substring(0, i);
    }

    public static String substringAfter(String s, String sep) {
        int i = s.indexOf(sep);
        return i < 0 ? "" : s.substring(i + sep.length());
    }

    public static String removeStart(String s, String prefix) {
        return s.startsWith(prefix) ? s.substring(prefix.length()) : s;
    }

    public static String removeEnd(String s, String suffix) {
        return s.endsWith(suffix) ? s.substring(0, s.length() - suffix.length()) : s;
    }

    // ---- enums ------------------------------------------------------------

    public static <T> List<T> enumValues(T[] values) {
        List<T> out = new List<T>();
        for (T v : values) {
            out.add(v);
        }
        return out;
    }
}
