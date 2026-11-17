// Generates (or checks) the `-meta.xml` companion file every Apex class needs.
//
//   node tools/gen-meta.mjs           write any missing companions
//   node tools/gen-meta.mjs --check   exit 1 if a companion is missing or stale
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const classesDir = path.join(root, "force-app/main/default/classes");
const apiVersion = JSON.parse(
    fs.readFileSync(path.join(root, "sfdx-project.json"), "utf8"),
).sourceApiVersion;

const meta = `<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>${apiVersion}</apiVersion>
    <status>Active</status>
</ApexClass>
`;

const check = process.argv.includes("--check");
const problems = [];
const entries = fs.existsSync(classesDir) ? fs.readdirSync(classesDir) : [];
for (const name of entries.filter((f) => f.endsWith(".cls"))) {
    const target = path.join(classesDir, `${name}-meta.xml`);
    const current = fs.existsSync(target) ? fs.readFileSync(target, "utf8") : null;
    if (current === meta) continue;
    if (check) problems.push(`${name}-meta.xml is ${current === null ? "missing" : "stale"}`);
    else fs.writeFileSync(target, meta);
}
for (const name of entries.filter((f) => f.endsWith(".cls-meta.xml"))) {
    const cls = path.join(classesDir, name.replace(/-meta\.xml$/, ""));
    if (fs.existsSync(cls)) continue;
    if (check) problems.push(`${name} has no matching class`);
    else fs.unlinkSync(path.join(classesDir, name));
}
if (problems.length > 0) {
    console.error(problems.join("\n"));
    console.error("Run `npm run meta` to fix.");
    process.exit(1);
}
