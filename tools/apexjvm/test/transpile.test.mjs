// Regression tests for the Apex-to-Java translator: each lint must fire on the
// Apex it exists to catch, and each rewrite must produce the Java it promises.
//
//   npm run test:harness
import assert from "node:assert/strict";
import { test } from "node:test";
import { transpile } from "../transpile.mjs";

/** Translates one class body; `members` is placed inside `public class T { ... }`. */
function translate(members, { enums = [], types = [] } = {}) {
    const source = `public class T {\n${members}\n}\n`;
    return transpile("T.cls", source, new Set(enums), new Set(["t", ...types]));
}

function errorsOf(members, options) {
    return translate(members, options).errors.join("\n");
}

function assertRejected(members, fragment, options) {
    const errors = errorsOf(members, options);
    assert.match(errors, fragment, `expected an error matching ${fragment} for:\n${members}`);
}

function assertAccepted(members, options) {
    assert.equal(errorsOf(members, options), "", `expected no errors for:\n${members}`);
}

test("keeps every line on the same line", () => {
    const members = "    void a() {\n        Integer x = 1;\n\n        x++;\n    }";
    const { java } = translate(members);
    assert.equal(java.split("\n").length, `public class T {\n${members}\n}\n`.split("\n").length);
});

test("rejects reserved words as names", () => {
    assertRejected("    void a() { Integer limit = 1; }", /'limit' is a reserved word in Apex/);
    assertRejected("    void a() { Integer date = 1; }", /'date' is a reserved word in Apex/);
});

test("rejects names that collide when case is ignored", () => {
    assertRejected(
        "    private static final Integer HOUR = 1;\n    Integer a(Integer hour) { return hour; }",
        /'hour' and 'HOUR' are the same identifier/,
    );
    assertRejected("    void a() { String string = ''; }", /hides the type of the same name/);
});

test("rejects the qualified primitive names AER does not accept", () => {
    assertRejected("    System.Integer a() { return 1; }", /AER rejects the qualified name/);
});

test("keeps a number boxed exactly where the code treats it as nullable", () => {
    const { java } = translate(
        "    Integer a(String s) { if (s == null) { return null; } return 1; }\n" +
            "    Integer b() { return 1; }\n" +
            "    void c(Long x) { if (x == null) { return; } }\n" +
            "    void d(Long x) { x++; }",
    );
    assert.match(java, /Integer a\(String s\)/);
    assert.match(java, /int b\(\)/);
    assert.match(java, /void c\(Long x\)/);
    assert.match(java, /void d\(long x\)/);
});

test("rejects integer literals with a leading zero", () => {
    assertRejected("    void a() { Integer x = 010; }", /leading zero/);
    assertRejected("    void a() { Long x = 08L; }", /leading zero/);
    assertAccepted("    void a() { Integer x = 0; Long y = 0L; Integer z = 10; }");
});

test("allows decimal literals only as the whole initializer of a Double", () => {
    assertAccepted("    void a() { Double half = 0.5; Double minus = -0.25; }");
    assertAccepted("    private static final Double HALF = 0.5;");
    assertRejected("    void a(Double x) { Double y = x * 0.5; }", /'0\.5' is a Decimal in Apex/);
    assertRejected("    void a() { Long x = 1; Double y = x + 1.5; }", /'1\.5' is a Decimal/);
    assertRejected("    void b(Double x) {}\n    void a() { b(0.5); }", /'0\.5' is a Decimal/);
});

test("allows only the wrapper statics Apex has", () => {
    assertAccepted(
        "    void a() { Integer i = Integer.valueOf('1'); Long l = Long.valueOf('2');" +
            " String s = String.valueOf(3) + String.join(new List<String>(), ','); }",
    );
    assertRejected(
        "    void a() { String s = String.format('%d', 1); }",
        /String\.format is not in the supported subset/,
    );
    assertRejected(
        "    void a() { Integer i = Integer.parseInt('1'); }",
        /Integer\.parseInt is not/,
    );
    assertRejected("    void a() { Long l = Long.MAX_VALUE; }", /Long\.MAX_VALUE is not/);
});

test("rejects Java-only String methods", () => {
    assertRejected(
        "    void a(String s) { s.strip(); }",
        /strip\(\) exists in Java but not in Apex/,
    );
});

test("rewrites Apex equality to value equality", () => {
    const { java } = translate("    Boolean a(String x, String y) { return x == y; }");
    assert.match(java, /Rt\.eq\(x, ?y\)/);
});

test("rewrites switch on enums and collection literals", () => {
    const { java, errors } = translate(
        "    Integer a(Colour c) { switch on c { when RED { return 1; } when else { return 2; } } }\n" +
            "    List<Long> b() { return new List<Long>{ 1L, 2L }; }",
        { enums: ["colour"], types: ["colour"] },
    );
    assert.deepEqual(errors, []);
    assert.match(java, /switch\s*\(c\)/);
    assert.match(java, /case RED ->/);
    assert.match(java, /List\.<Long>of\( 1L, 2L/);
});

test("rejects properties, arrays, SOQL and safe navigation", () => {
    assertRejected("    public Integer x { get; set; }", /properties are not supported/);
    assertRejected("    void a() { Integer[] xs = new Integer[3]; }", /array/);
    assertRejected("    void a() { List<Account> xs = [SELECT Id FROM Account]; }", /SOQL/);
    assertRejected("    void a(T t) { Object o = t?.a(); }", /safe navigation/);
});
