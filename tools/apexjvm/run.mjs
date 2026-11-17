// Local test harness entry point: translate every Apex class to Java,
// compile against the runtime shims, and run the @IsTest methods on the JVM.
//
//   node tools/apexjvm/run.mjs                    run all tests
//   node tools/apexjvm/run.mjs --filter JiffDate  run tests whose Class.method contains the text
//   node tools/apexjvm/run.mjs --transpile-only   translate and compile, do not run
//   node tools/apexjvm/run.mjs --coverage         run under JaCoCo and print line coverage
//
// See docs/adr/0002-local-jvm-test-harness.md for why this exists.
import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { collectEnums, transpile, JAVA_PACKAGE } from "./transpile.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const classesDir = path.join(root, "force-app/main/default/classes");
const buildDir = path.join(root, "build/apexjvm");
const srcOut = path.join(buildDir, "src", JAVA_PACKAGE);
const classOut = path.join(buildDir, "classes");

const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : null);

function run(cmd, cmdArgs, opts = {}) {
    const result = spawnSync(cmd, cmdArgs, { stdio: "inherit", ...opts });
    if (result.error) throw result.error;
    return result.status;
}

function listFiles(dir, ext) {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) out.push(...listFiles(full, ext));
        else if (entry.name.endsWith(ext)) out.push(full);
    }
    return out;
}

// ---- translate -----------------------------------------------------------
fs.rmSync(buildDir, { recursive: true, force: true });
fs.mkdirSync(srcOut, { recursive: true });
fs.mkdirSync(classOut, { recursive: true });

const sources = listFiles(classesDir, ".cls").map((file) => ({
    file,
    name: path.basename(file),
    text: fs.readFileSync(file, "utf8"),
}));
const enums = new Set(sources.flatMap((s) => collectEnums(s.text)));
const typeNames = new Set(sources.map((s) => s.name.replace(/\.cls$/, "").toLowerCase()));
const tests = [];
const errors = [];
for (const s of sources) {
    const result = transpile(s.name, s.text, enums, typeNames);
    errors.push(...result.errors);
    if (result.isTest) tests.push(result.className);
    fs.writeFileSync(path.join(srcOut, s.name.replace(/\.cls$/, ".java")), result.java);
}
if (errors.length > 0) {
    console.error(errors.join("\n"));
    console.error(`\n${errors.length} translation error(s)`);
    process.exit(1);
}

// ---- compile -------------------------------------------------------------
const javaFiles = [
    ...listFiles(path.join(here, "runtime"), ".java"),
    ...listFiles(srcOut, ".java"),
];
const argFile = path.join(buildDir, "javac.args");
fs.writeFileSync(
    argFile,
    [
        "-d",
        classOut,
        "-g",
        "-nowarn",
        "-Xlint:-options",
        "-proc:none",
        "-encoding",
        "UTF-8",
        ...javaFiles,
    ]
        .map((a) => `"${a.replace(/\\/g, "/")}"`)
        .join("\n"),
);
const compiled = spawnSync("javac", [`@${argFile}`], { encoding: "utf8" });
const diagnostics = ((compiled.stdout || "") + (compiled.stderr || ""))
    // Point diagnostics at the Apex source; lines are identical by construction.
    .replaceAll(srcOut + path.sep, "force-app/main/default/classes/")
    .replace(/(classes\/\w+)\.java/g, "$1.cls");
if (compiled.status !== 0) {
    console.error(diagnostics);
    process.exit(1);
}
if (flag("--transpile-only")) {
    console.log(`translated and compiled ${sources.length} classes (${tests.length} test classes)`);
    process.exit(0);
}

// ---- run -----------------------------------------------------------------
tests.sort();
const filter = option("--filter");
const runnerArgs = [classOut, ...tests, ...(filter ? ["--filter", filter] : [])];
const jvmArgs = ["-Dapexjvm.userTimeZone=" + (option("--user-tz") || "America/Los_Angeles")];

if (!flag("--coverage")) {
    process.exit(run("java", [...jvmArgs, "-cp", classOut, "apexjvm.Runner", ...runnerArgs]));
}

// ---- coverage ------------------------------------------------------------
const jacoco = path.join(root, "tools/apexjvm/lib");
const agent = path.join(jacoco, "jacocoagent.jar");
const cli = path.join(jacoco, "jacococli.jar");
if (!fs.existsSync(agent) || !fs.existsSync(cli)) {
    console.error("JaCoCo jars not found. Run: node tools/apexjvm/fetch-jacoco.mjs");
    process.exit(1);
}
const exec = path.join(buildDir, "jacoco.exec");
const status = run("java", [
    ...jvmArgs,
    `-javaagent:${agent}=destfile=${exec},includes=${JAVA_PACKAGE}.Jiff*`,
    "-cp",
    classOut,
    "apexjvm.Runner",
    ...runnerArgs,
    "--shared",
]);
const csv = path.join(buildDir, "coverage.csv");
run(
    "java",
    ["-jar", cli, "report", exec, "--classfiles", path.join(classOut, JAVA_PACKAGE), "--csv", csv],
    {
        stdio: "ignore",
    },
);
const rows = fs
    .readFileSync(csv, "utf8")
    .trim()
    .split("\n")
    .slice(1)
    .map((line) => line.split(","))
    // Columns: GROUP,PACKAGE,CLASS,...,LINE_MISSED,LINE_COVERED,...
    .map((c) => ({ cls: c[2].split(".")[0], missed: Number(c[7]), covered: Number(c[8]) }))
    // Only the library itself counts: not the tests and not the runtime shims.
    .filter((r) => r.cls.startsWith("Jiff") && !tests.includes(r.cls));
const byClass = new Map();
for (const r of rows) {
    const agg = byClass.get(r.cls) || { missed: 0, covered: 0 };
    agg.missed += r.missed;
    agg.covered += r.covered;
    byClass.set(r.cls, agg);
}
let missed = 0;
let covered = 0;
console.log("\nLine coverage");
for (const [cls, agg] of [...byClass].sort()) {
    missed += agg.missed;
    covered += agg.covered;
    const pct = (100 * agg.covered) / Math.max(1, agg.covered + agg.missed);
    console.log(`  ${cls.padEnd(28)} ${pct.toFixed(1).padStart(5)}%  (${agg.missed} lines missed)`);
}
const total = (100 * covered) / Math.max(1, covered + missed);
console.log(`  ${"TOTAL".padEnd(28)} ${total.toFixed(1).padStart(5)}%`);
const minimum = Number(option("--min") || 85);
if (total < minimum) {
    console.error(`\ncoverage ${total.toFixed(1)}% is below the ${minimum}% gate`);
    process.exit(1);
}
process.exit(status);
