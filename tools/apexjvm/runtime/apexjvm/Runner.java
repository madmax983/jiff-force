package apexjvm;

import java.io.File;
import java.lang.annotation.Annotation;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * Runs translated Apex test classes.
 *
 * <p>Each test method runs in its own class loader so that static state starts
 * fresh, as it does at the start of an Apex transaction. Without this, a
 * cache warmed by one test could hide a bug in another.
 *
 * <pre>
 *   java apexjvm.Runner &lt;classesDir&gt; &lt;TestClass&gt;... [--filter text] [--shared]
 * </pre>
 *
 * {@code --shared} loads every class once (required when a coverage agent is
 * attached, since it keys execution data by class identity).
 */
public final class Runner {
    private static final String PACKAGE = "jiffapex";

    private Runner() {}

    public static void main(String[] args) throws Exception {
        File classesDir = new File(args[0]);
        List<String> classNames = new ArrayList<>();
        String filter = null;
        boolean shared = false;
        for (int i = 1; i < args.length; i++) {
            if (args[i].equals("--filter")) {
                filter = args[++i].toLowerCase();
            } else if (args[i].equals("--shared")) {
                shared = true;
            } else {
                classNames.add(args[i]);
            }
        }
        URL[] urls = {classesDir.toURI().toURL()};
        ClassLoader sharedLoader = shared ? Runner.class.getClassLoader() : null;

        int passed = 0;
        List<String> failures = new ArrayList<>();
        long started = System.nanoTime();
        for (String className : classNames) {
            ClassLoader probe = shared ? sharedLoader : new URLClassLoader(urls, null);
            List<String> methods = testMethods(probe.loadClass(PACKAGE + "." + className));
            for (String methodName : methods) {
                String id = className + "." + methodName;
                if (filter != null && !id.toLowerCase().contains(filter)) {
                    continue;
                }
                ClassLoader loader = shared ? sharedLoader : new URLClassLoader(urls, null);
                Throwable error = runOne(loader, className, methodName);
                if (error == null) {
                    passed++;
                } else {
                    failures.add(describe(id, error));
                    System.out.println("FAIL " + id);
                }
            }
        }
        long millis = (System.nanoTime() - started) / 1_000_000;
        for (String failure : failures) {
            System.out.println();
            System.out.println(failure);
        }
        System.out.println();
        System.out.println(passed + " passed, " + failures.size() + " failed (" + millis + " ms)");
        System.exit(failures.isEmpty() && passed > 0 ? 0 : 1);
    }

    private static List<String> testMethods(Class<?> cls) {
        List<String> names = new ArrayList<>();
        for (Method m : cls.getDeclaredMethods()) {
            if (isTest(m) && Modifier.isStatic(m.getModifiers()) && m.getParameterCount() == 0) {
                names.add(m.getName());
            }
        }
        names.sort(Comparator.naturalOrder());
        return names;
    }

    private static boolean isTest(Method m) {
        for (Annotation a : m.getAnnotations()) {
            if (a.annotationType().getName().equals(PACKAGE + ".IsTest")) {
                return true;
            }
        }
        return false;
    }

    private static Throwable runOne(ClassLoader loader, String className, String methodName) {
        try {
            Class<?> cls = loader.loadClass(PACKAGE + "." + className);
            Method m = cls.getDeclaredMethod(methodName);
            m.setAccessible(true);
            m.invoke(null);
            return null;
        } catch (InvocationTargetException e) {
            return e.getCause();
        } catch (Throwable t) {
            return t;
        }
    }

    private static String describe(String id, Throwable error) {
        StringBuilder sb = new StringBuilder();
        sb.append(id).append("\n  ").append(error.getClass().getSimpleName()).append(": ")
            .append(error.getMessage());
        StackTraceElement[] frames = error.getStackTrace();
        int shown = 0;
        for (StackTraceElement frame : frames) {
            String file = frame.getFileName();
            if (!frame.getClassName().startsWith(PACKAGE + ".") || file == null) {
                continue;
            }
            // Translation is line preserving, so the Java line is the Apex line.
            boolean shim = !Arrays.asList(frame.getClassName().split("\\.")).get(1).startsWith("Jiff");
            if (shim) {
                continue;
            }
            sb.append("\n    at ").append(frame.getClassName().substring(PACKAGE.length() + 1)).append('.')
                .append(frame.getMethodName()).append(" (").append(file.replace(".java", ".cls"))
                .append(':').append(frame.getLineNumber()).append(')');
            if (++shown == 12) {
                break;
            }
        }
        if (error.getCause() != null && error.getCause() != error) {
            sb.append("\n  caused by ").append(error.getCause());
        }
        return sb.toString();
    }
}
