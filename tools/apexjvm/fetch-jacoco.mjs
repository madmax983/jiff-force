// Downloads the JaCoCo agent and CLI used by `npm run test:coverage`.
// The jars are pinned by version and SHA-256 and land in tools/apexjvm/lib (git-ignored).
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const VERSION = "0.8.12";
const BASE = `https://repo1.maven.org/maven2/org/jacoco`;
const JARS = [
    {
        url: `${BASE}/org.jacoco.agent/${VERSION}/org.jacoco.agent-${VERSION}-runtime.jar`,
        file: "jacocoagent.jar",
        sha256: "115e8e6e6593ca3a9892dfef695df4d487c706e59e71e64dc0ab95716ee02622",
    },
    {
        url: `${BASE}/org.jacoco.cli/${VERSION}/org.jacoco.cli-${VERSION}-nodeps.jar`,
        file: "jacococli.jar",
        sha256: "594c01125b84864a7fc5a9efab19b71b7de36b27346863f6d7cd0cd45400ceb0",
    },
];

const lib = path.join(path.dirname(fileURLToPath(import.meta.url)), "lib");
fs.mkdirSync(lib, { recursive: true });
const printOnly = process.argv.includes("--print-checksums");

for (const jar of JARS) {
    const target = path.join(lib, jar.file);
    const response = await fetch(jar.url);
    if (!response.ok) throw new Error(`${jar.url}: HTTP ${response.status}`);
    const bytes = Buffer.from(await response.arrayBuffer());
    const actual = crypto.createHash("sha256").update(bytes).digest("hex");
    if (printOnly) {
        console.log(`${jar.file} ${actual}`);
        continue;
    }
    if (actual !== jar.sha256) {
        throw new Error(
            `${jar.file}: checksum mismatch\n  expected ${jar.sha256}\n  actual   ${actual}`,
        );
    }
    fs.writeFileSync(target, bytes);
    console.log(`fetched ${jar.file}`);
}
