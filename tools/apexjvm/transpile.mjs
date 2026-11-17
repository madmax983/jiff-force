// Apex -> Java source translator for the local test harness.
//
// This is NOT a general Apex compiler. It translates the disciplined subset
// of Apex that jiff-force is written in (see docs/adr/0002) into Java that is
// compiled against the shims in ./runtime. The translation is line preserving:
// line N of Foo.cls becomes line N of Foo.java, so javac diagnostics, stack
// traces and coverage all point at the Apex source.
//
// Anything outside the subset is reported as an error rather than guessed at.
import { ApexParserFactory } from "@apexdevtools/apex-parser";

export const JAVA_PACKAGE = "jiffapex";

// Apex value types that become Java primitives outside of generic arguments.
const PRIMITIVES = new Map([
    ["integer", "int"],
    ["long", "long"],
    ["boolean", "boolean"],
    ["double", "double"],
]);

// `String.<name>(...)` statics that differ from java.lang.String.
const STRING_STATICS = new Set(["join", "fromchararray", "isblank", "isempty", "isnotblank"]);

// `Math.<name>(...)` statics that differ from java.lang.Math.
const MATH_STATICS = new Set(["mod"]);
const MATH_ALLOWED = new Set(["abs", "min", "max", "mod"]);

// Instance methods that exist on Apex system types but not (or not with the
// same meaning) on the Java type the value is mapped to. These are routed by
// name to `Rt.<name>(receiver, args...)`, so jiff-force classes must not
// declare methods with these names.
const INSTANCE_ROUTES = new Set([
    "leftpad",
    "rightpad",
    "left",
    "right",
    "mid",
    "charat",
    "getchars",
    "split",
    "repeat",
    "reverse",
    "isnumeric",
    "containsignorecase",
    "substringbefore",
    "substringafter",
    "removestart",
    "removeend",
    "intvalue",
    "longvalue",
    "doublevalue",
]);

// Methods java.lang.String has that Apex's String does not. javac would
// accept them, the Apex compiler would not, so they are rejected by name.
const JAVA_ONLY_METHODS = new Set([
    "strip",
    "stripleading",
    "striptrailing",
    "chars",
    "codepoints",
    "matches",
    "tochararray",
    "concat",
    "intern",
    "lines",
    "isblank",
    "formatted",
    "getbytes",
    "regionmatches",
    "stream",
    "foreach",
    "tolist",
    "putifabsent",
    "getordefault",
    "computeifabsent",
    "entryset",
]);

const ANNOTATIONS = new Map([
    ["istest", "@IsTest"],
    ["testvisible", ""],
    ["suppresswarnings", ""],
    ["namespaceaccessible", ""],
    ["deprecated", "@Deprecated"],
]);

const JAVA_RESERVED = new Set(
    (
        "abstract assert boolean break byte case catch char class const continue default do " +
        "double else enum extends final finally float for goto if implements import instanceof " +
        "int interface long native new package private protected public return short static " +
        "strictfp super switch synchronized this throw throws transient try void volatile while " +
        "var yield record sealed permits"
    ).split(" "),
);

// Apex reserved keywords, including those "reserved for future use". The
// grammar accepts many of them as identifiers, but the platform compiler
// rejects them, so the harness refuses any declaration that uses one.
const APEX_RESERVED = new Set(
    (
        "abstract activate and any array as asc autonomous begin bigdecimal blob boolean break " +
        "bulk by byte case cast catch char class collect commit const continue currency date " +
        "datetime decimal default delete desc do double else end enum exception exit export " +
        "extends false final finally float for from global goto group having hint if implements " +
        "import in inner insert instanceof int integer interface into join like limit list long " +
        "loop map merge new not null nulls number object of on or outer override package parallel " +
        "pragma private protected public retrieve return rollback select set short sobject sort " +
        "static string super switch synchronized system testmethod then this throw time " +
        "transaction trigger true try undelete update upsert using virtual void webservice when " +
        "where while"
    ).split(" "),
);

// Parse-tree rules whose `id` child introduces a new name.
const DECLARING_RULES = new Set([
    "classDeclaration",
    "enumDeclaration",
    "interfaceDeclaration",
    "methodDeclaration",
    "interfaceMethodDeclaration",
    "variableDeclarator",
    "formalParameter",
    "enumConstants",
    "catchClause",
    "enhancedForControl",
]);

// Declarations that introduce a variable (as opposed to a type or a method).
const VARIABLE_RULES = new Set([
    "variableDeclarator",
    "formalParameter",
    "catchClause",
    "enhancedForControl",
]);

// Platform types the library refers to by simple name.
const SYSTEM_TYPES = new Set(
    (
        "string integer long double boolean object list map set math system datetime date time " +
        "timezone assert test userinfo exception"
    ).split(" "),
);

function ruleName(parser, node) {
    return parser.ruleNames[node.ruleIndex];
}

function isTerminal(node) {
    return node.symbol !== undefined;
}

/** Collects the names of every enum declared in `source`. */
export function collectEnums(source) {
    const parser = ApexParserFactory.createParser(source);
    parser.removeErrorListeners();
    const tree = parser.compilationUnit();
    const names = [];
    (function walk(node) {
        if (isTerminal(node) || !node.children) return;
        if (ruleName(parser, node) === "enumDeclaration") {
            names.push(node.children[1].getText().toLowerCase());
        }
        for (const child of node.children) walk(child);
    })(tree);
    return names;
}

/**
 * Translates one Apex class file.
 *
 * @param {string} fileName   e.g. `JiffDate.cls`, used in diagnostics
 * @param {string} source     Apex source text
 * @param {Set<string>} enums lower-cased names of all enums in the project
 * @param {Set<string>} typeNames lower-cased names of all classes in the project
 * @returns {{java: string, errors: string[], isTest: boolean, className: string}}
 */
export function transpile(fileName, source, enums, typeNames = new Set()) {
    const errors = [];
    const listener = {
        syntaxError: (_r, _sym, line, col, msg) => errors.push(`${fileName}:${line}:${col} ${msg}`),
        reportAmbiguity() {},
        reportAttemptingFullContext() {},
        reportContextSensitivity() {},
    };
    const { lexer, parser } = ApexParserFactory.createLexerAndParser(source, listener);
    void lexer;
    const tree = parser.compilationUnit();
    const tokens = parser.getTokenStream().tokens;
    const rn = (node) => ruleName(parser, node);
    const fail = (node, msg) => {
        const tok = isTerminal(node) ? node.symbol : node.start;
        errors.push(`${fileName}:${tok.line}:${tok.column} ${msg}`);
    };

    // Apex identifiers are case-insensitive and Java's are not. Two variables in
    // one class that differ only by case are the same name in Apex (the inner
    // one silently shadows the outer), and a variable named like a type hides
    // that type. Both compile and run here, so both are rejected.
    const variableSpellings = new Map();
    function checkVariableName(node, text) {
        const lower = text.toLowerCase();
        const seen = variableSpellings.get(lower);
        if (seen !== undefined && seen !== text) {
            fail(
                node,
                `'${text}' and '${seen}' are the same identifier in Apex (names ignore case)`,
            );
        }
        variableSpellings.set(lower, text);
        if (typeNames.has(lower) || SYSTEM_TYPES.has(lower)) {
            fail(node, `variable '${text}' hides the type of the same name (names ignore case)`);
        }
    }

    let isTest = false;
    let className = fileName.replace(/\.cls$/, "");

    /** Hidden tokens (whitespace, comments) immediately before token `index`. */
    function lead(index) {
        let start = index;
        while (start > 0 && tokens[start - 1].channel !== 0) start--;
        let out = "";
        for (let i = start; i < index; i++) out += tokens[i].text;
        return out;
    }

    function javaString(text) {
        const body = text.slice(1, -1);
        let out = '"';
        for (let i = 0; i < body.length; i++) {
            const ch = body[i];
            if (ch === "\\") {
                const next = body[i + 1];
                i++;
                out += next === "'" ? "'" : "\\" + next;
            } else if (ch === '"') {
                out += '\\"';
            } else {
                out += ch;
            }
        }
        return out + '"';
    }

    function terminal(node) {
        const tok = node.symbol;
        if (tok.type === -1) return lead(tok.tokenIndex);
        let text = tok.text;
        if (text.length >= 2 && text.startsWith("'") && text.endsWith("'")) {
            text = javaString(text);
        }
        return lead(tok.tokenIndex) + text;
    }

    /** Splits generated text into its leading whitespace/comments and the rest. */
    function splitLead(text) {
        const m = /^(?:\s|\/\*[\s\S]*?\*\/|\/\/[^\n]*\n)*/.exec(text);
        return [m[0], text.slice(m[0].length)];
    }

    function wrap(text, before, after) {
        const [ws, rest] = splitLead(text);
        return ws + before + rest + after;
    }

    function children(node) {
        return node.children ? node.children.map(emit).join("") : "";
    }

    function hasAncestor(node, name) {
        for (let p = node.parentCtx; p; p = p.parentCtx) if (rn(p) === name) return true;
        return false;
    }

    function isLiteral(node, pattern) {
        return !isTerminal(node) && pattern.test(node.getText());
    }

    function emitTypeRef(node) {
        const text = node.getText();
        const lower = text.toLowerCase();
        if (/\[/.test(text)) fail(node, "array types are not supported; use List<T>");
        const parent = node.parentCtx;
        const generic = parent && rn(parent) === "typeList";
        if (PRIMITIVES.has(lower) && !generic) {
            // A value that the code itself treats as possibly null stays a
            // boxed Java type; everything else becomes a primitive.
            const java = isNullable(node)
                ? lower[0].toUpperCase() + lower.slice(1)
                : PRIMITIVES.get(lower);
            return lead(node.start.tokenIndex) + java;
        }
        if (lower.startsWith("system.") && PRIMITIVES.has(lower.slice(7))) {
            fail(node, `write '${text.slice(7)}', not '${text}' (AER rejects the qualified name)`);
        }
        if (lower === "decimal") fail(node, "Decimal is not part of the supported subset");
        return children(node);
    }

    /** Whether `name` is assigned null or compared with null anywhere under `scope`. */
    function nullTouched(scope, name) {
        const wanted = new Set([name.toLowerCase(), "this." + name.toLowerCase()]);
        let found = false;
        (function walk(n) {
            if (found || isTerminal(n) || !n.children) return;
            const kind = n.constructor.name;
            const first = n.children[0].getText().toLowerCase();
            const last = n.children[n.children.length - 1].getText().toLowerCase();
            if (kind === "EqualityExpressionContext" || kind === "AssignExpressionContext") {
                if (wanted.has(first) && last === "null") found = true;
                if (kind === "EqualityExpressionContext" && first === "null" && wanted.has(last)) {
                    found = true;
                }
            } else if (rn(n) === "variableDeclarator" && n.children.length === 3) {
                if (wanted.has(first) && last === "null") found = true;
            }
            for (const c of n.children) walk(c);
        })(scope);
        return found;
    }

    /** Whether a method body contains `return null` (directly or as a ternary branch). */
    function returnsNull(method) {
        let found = false;
        (function walk(n) {
            if (found || isTerminal(n) || !n.children) return;
            if (rn(n) === "returnStatement") {
                const value = n.children.find((c) => !isTerminal(c));
                if (value) {
                    const parts =
                        value.constructor.name === "CondExpressionContext"
                            ? [value.children[2], value.children[4]]
                            : [value];
                    if (parts.some((part) => part.getText().toLowerCase() === "null")) found = true;
                }
                return;
            }
            for (const c of n.children) walk(c);
        })(method);
        return found;
    }

    function enclosing(node, rules) {
        for (let p = node.parentCtx; p; p = p.parentCtx) if (rules.includes(rn(p))) return p;
        return null;
    }

    function declaredNames(node) {
        const declarators = node.children.find(
            (c) => !isTerminal(c) && rn(c) === "variableDeclarators",
        );
        return declarators.children
            .filter((c) => !isTerminal(c))
            .map((d) => d.children[0].getText());
    }

    /**
     * Apex `Integer`, `Long`, `Boolean` and `Double` can be null; Java
     * primitives cannot. A declaration is treated as nullable exactly when the
     * code in its scope treats it that way: the name is assigned or compared
     * with null, or (for a method's return type) the method returns null.
     */
    function isNullable(typeRef) {
        const parent = typeRef.parentCtx;
        const body = ["methodDeclaration", "constructorDeclaration"];
        switch (rn(parent)) {
            case "methodDeclaration":
                return returnsNull(parent);
            case "formalParameter": {
                const name = parent.children
                    .find((c) => !isTerminal(c) && rn(c) === "id")
                    .getText();
                const scope = enclosing(parent, body);
                return scope !== null && nullTouched(scope, name);
            }
            case "localVariableDeclaration": {
                const scope = enclosing(parent, body) || tree;
                return declaredNames(parent).some((name) => nullTouched(scope, name));
            }
            case "enhancedForControl": {
                const name = parent.children
                    .find((c) => !isTerminal(c) && rn(c) === "id")
                    .getText();
                return nullTouched(enclosing(parent, ["forStatement"]), name);
            }
            case "fieldDeclaration":
                return declaredNames(parent).some((name) => nullTouched(tree, name));
            default:
                return false;
        }
    }

    function emitModifier(node) {
        const first = node.children[0];
        const ws = lead(node.start.tokenIndex);
        if (!isTerminal(first) && rn(first) === "annotation") {
            const name = first.children[1].getText().toLowerCase();
            if (!ANNOTATIONS.has(name)) {
                fail(node, `unsupported annotation @${name}`);
                return ws;
            }
            return ws + ANNOTATIONS.get(name);
        }
        const text = node.getText().toLowerCase();
        switch (text) {
            case "global":
                return ws + "public";
            case "withsharing":
            case "withoutsharing":
            case "inheritedsharing":
            case "virtual":
                return ws;
            case "override":
                return ws + "@Override";
            case "public":
            case "private":
            case "protected":
            case "static":
            case "final":
            case "abstract":
                return ws + text;
            default:
                fail(node, `unsupported modifier '${text}'`);
                return ws;
        }
    }

    function modifierText(node) {
        const first = node.children[0];
        if (!isTerminal(first) && rn(first) === "annotation") {
            return "@" + first.children[1].getText().toLowerCase();
        }
        return node.getText().toLowerCase();
    }

    function emitTypeDeclaration(node) {
        let out = "";
        for (const child of node.children) {
            if (!isTerminal(child) && rn(child) === "modifier") {
                const text = modifierText(child);
                if (text === "@istest") isTest = true;
                // Java has no private top-level types.
                out += text === "private" ? lead(child.start.tokenIndex) : emit(child);
            } else {
                out += emit(child);
            }
        }
        return out;
    }

    function emitClassBodyDeclaration(node) {
        const mods = node.children.filter((c) => !isTerminal(c) && rn(c) === "modifier");
        const texts = mods.map(modifierText);
        const testVisible = texts.includes("@testvisible");
        const member = node.children.find((c) => !isTerminal(c) && rn(c) === "memberDeclaration");
        if (member) {
            const decl = member.children[0];
            const kind = rn(decl);
            if (kind === "propertyDeclaration") {
                fail(decl, "properties are not supported; use a field and accessor methods");
            }
            if (kind === "fieldDeclaration") {
                const type = decl.children[0].getText().toLowerCase();
                const isFinal = texts.includes("final");
                for (const d of decl.children[1].children) {
                    if (isTerminal(d)) continue;
                    const nullable = nullTouched(tree, d.children[0].getText());
                    if (PRIMITIVES.has(type) && !isFinal && !nullable && d.children.length === 1) {
                        fail(
                            d,
                            `field '${d.getText()}' must be final or initialized ` +
                                "(Apex defaults it to null, Java to zero)",
                        );
                    }
                }
            }
        }
        let out = "";
        let sawAccess = false;
        for (const child of node.children) {
            if (!isTerminal(child) && rn(child) === "modifier") {
                const text = modifierText(child);
                if (["private", "protected", "public", "global"].includes(text)) {
                    sawAccess = true;
                    out += testVisible ? lead(child.start.tokenIndex) + "public" : emit(child);
                } else {
                    out += emit(child);
                }
            } else if (child === member) {
                out += testVisible && !sawAccess ? wrap(emit(child), "public ", "") : emit(child);
            } else {
                out += emit(child);
            }
        }
        return out;
    }

    function emitClassDeclaration(node) {
        // "class" id ("extends" typeRef)? ("implements" typeList)? classBody
        const name = node.children[1].getText();
        const nested = hasAncestor(node, "classBody");
        if (!nested) className = name;
        let out = "";
        let extendsException = false;
        for (let i = 0; i < node.children.length; i++) {
            const child = node.children[i];
            if (isTerminal(child) && child.getText().toLowerCase() === "class") {
                out += lead(child.symbol.tokenIndex) + (nested ? "static class" : "class");
            } else if (!isTerminal(child) && rn(child) === "typeRef" && /exception$/i.test(name)) {
                extendsException = true;
                const parentName = child.getText();
                out +=
                    lead(child.start.tokenIndex) +
                    (parentName.toLowerCase() === "exception" ? "ApexException" : parentName);
            } else if (!isTerminal(child) && rn(child) === "classBody" && extendsException) {
                const body = emit(child);
                const brace = body.indexOf("{");
                const ctors =
                    ` public ${name}() { super(); }` +
                    ` public ${name}(String message) { super(message); }` +
                    ` public ${name}(Exception cause) { super(cause); }` +
                    ` public ${name}(String message, Exception cause) { super(message, cause); }`;
                out += body.slice(0, brace + 1) + ctors + body.slice(brace + 1);
            } else {
                out += emit(child);
            }
        }
        if (/exception$/i.test(name) && !extendsException) {
            fail(node, "classes named *Exception must extend Exception");
        }
        return out;
    }

    function emitSwitch(node) {
        // "switch" "on" expression "{" whenControl+ "}"
        const [kwSwitch, kwOn, expr, ...rest] = node.children;
        let out = lead(kwSwitch.symbol.tokenIndex) + "switch";
        out += lead(kwOn.symbol.tokenIndex) + "(" + emit(expr).trimStart() + ")";
        for (const child of rest) out += emit(child);
        return out;
    }

    function emitWhenControl(node) {
        // "when" whenValue block
        const [kwWhen, value, block] = node.children;
        let out = lead(kwWhen.symbol.tokenIndex);
        const first = value.children[0];
        if (isTerminal(first) && first.getText().toLowerCase() === "else") {
            out += "default ->";
        } else {
            const literals = value.children.filter((c) => !isTerminal(c));
            if (literals.some((c) => rn(c) !== "whenLiteral")) {
                fail(value, "type-pattern 'when' clauses are not supported");
            }
            out += "case" + children(value) + " ->";
        }
        return out + emit(block);
    }

    function emitEquality(node) {
        const left = node.children[0];
        const right = node.children[node.children.length - 1];
        const op = node.children
            .slice(1, -1)
            .map((c) => c.getText())
            .join("");
        const l = emit(left);
        const r = emit(right);
        const simple = /^(null|-?\d+[lL]?|true|false)$/i;
        if (isLiteral(left, simple) || isLiteral(right, simple)) {
            const javaOp = op === "==" || op === "===" ? "==" : "!=";
            return l + " " + javaOp + r;
        }
        if (op === "===" || op === "!==") {
            fail(node, "exact equality (===) is not part of the supported subset");
        }
        const negate = op !== "==";
        const [ws, rest] = splitLead(l);
        return ws + (negate ? "!" : "") + "Rt.eq(" + rest + "," + r + ")";
    }

    function emitArrayExpression(node) {
        // expression "[" expression "]"
        const [target, , index] = node.children;
        return emit(target) + ".get(" + emit(index).trimStart() + ")";
    }

    function emitAssign(node) {
        const [target, opNode, value] = [
            node.children[0],
            node.children.slice(1, -1),
            node.children[node.children.length - 1],
        ];
        if (!isTerminal(target) && target.constructor.name === "ArrayExpressionContext") {
            const op = opNode.map((c) => c.getText()).join("");
            if (op !== "=") {
                fail(node, "compound assignment to a list element is not supported; use set()");
            }
            const [list, , index] = target.children;
            return emit(list) + ".set(" + emit(index).trimStart() + "," + emit(value) + ")";
        }
        return children(node);
    }

    function emitArgs(call) {
        // anyId "(" expressionList? ")"
        const list = call.children.find((c) => !isTerminal(c) && rn(c) === "expressionList");
        return list ? emit(list) : "";
    }

    function emitDot(node) {
        // expression ("." | "?.") (dotMethodCall | anyId)
        const [recv, dot, member] = node.children;
        if (dot.getText() !== ".") fail(node, "safe navigation (?.) is not supported");
        if (isTerminal(member) || rn(member) !== "dotMethodCall") return children(node);
        const name = member.children[0].getText();
        const lower = name.toLowerCase();
        const recvText = recv.getText().toLowerCase();
        const args = emitArgs(member);
        const ws = lead(recv.start.tokenIndex);
        if (recvText === "string" && STRING_STATICS.has(lower)) {
            return ws + `Rt.String_${name}(` + args.trimStart() + ")";
        }
        if (recvText === "math") {
            if (!MATH_ALLOWED.has(lower)) fail(node, `Math.${name} is not in the supported subset`);
            if (MATH_STATICS.has(lower)) return ws + `Rt.${name}(` + args.trimStart() + ")";
        }
        if (enums.has(recvText) && lower === "values") {
            return ws + `Rt.enumValues(${recv.getText()}.values())`;
        }
        if (INSTANCE_ROUTES.has(lower)) {
            const r = emit(recv).slice(ws.length);
            return ws + `Rt.${name}(` + r + (args.trim() ? "," + args : "") + ")";
        }
        if (JAVA_ONLY_METHODS.has(lower)) {
            fail(member, `${name}() exists in Java but not in Apex`);
        }
        return children(node);
    }

    function emitCreator(node) {
        // createdName (noRest | classCreatorRest | arrayCreatorRest | mapCreatorRest | setCreatorRest)
        const [created, rest] = node.children;
        const kind = rn(rest);
        if (kind === "classCreatorRest") return children(node);
        if (kind === "arrayCreatorRest") {
            fail(node, "array creation is not supported; use new List<T>()");
            return children(node);
        }
        // Collection literal: new List<T>{a, b} / new Map<K, V>{k => v}
        const pair = created.children[0];
        const base = pair.children[0].getText();
        const typeList = pair.children.find((c) => !isTerminal(c) && rn(c) === "typeList");
        if (!typeList) {
            fail(node, "collection literal needs explicit type arguments");
            return children(node);
        }
        const items = [];
        for (const child of rest.children) {
            if (isTerminal(child)) continue;
            if (rn(child) === "mapCreatorRestPair") {
                items.push(emit(child.children[0]) + "," + emit(child.children[2]));
            } else {
                items.push(emit(child));
            }
        }
        // Keep any line breaks inside the literal so line numbers stay aligned.
        const tail = lead(rest.stop.tokenIndex).replace(/[^\n]/g, "");
        return (
            lead(created.start.tokenIndex) +
            `${base}.<${emit(typeList).trim()}>of(` +
            items.join(",") +
            tail +
            ")"
        );
    }

    function emitNew(node) {
        // "new" creator
        const [kwNew, creator] = node.children;
        const rest = creator.children[1];
        if (rn(rest) === "classCreatorRest" || rn(rest) === "arrayCreatorRest") {
            return children(node);
        }
        return lead(kwNew.symbol.tokenIndex) + emit(creator).trimStart();
    }

    function emit(node) {
        if (isTerminal(node)) return terminal(node);
        switch (rn(node)) {
            case "typeRef":
                return emitTypeRef(node);
            case "modifier":
                return emitModifier(node);
            case "typeDeclaration":
                return emitTypeDeclaration(node);
            case "classBodyDeclaration":
                return emitClassBodyDeclaration(node);
            case "classDeclaration":
                return emitClassDeclaration(node);
            case "switchStatement":
                return emitSwitch(node);
            case "whenControl":
                return emitWhenControl(node);
            case "creator":
                return emitCreator(node);
            case "id":
            case "anyId": {
                const text = node.getText();
                if (JAVA_RESERVED.has(text)) fail(node, `'${text}' is a reserved word in Java`);
                if (
                    APEX_RESERVED.has(text.toLowerCase()) &&
                    node.parentCtx &&
                    DECLARING_RULES.has(rn(node.parentCtx))
                ) {
                    fail(node, `'${text}' is a reserved word in Apex and cannot be declared`);
                }
                if (node.parentCtx && VARIABLE_RULES.has(rn(node.parentCtx)))
                    checkVariableName(node, text);
                return children(node);
            }
            case "insertStatement":
            case "updateStatement":
            case "deleteStatement":
            case "undeleteStatement":
            case "upsertStatement":
            case "mergeStatement":
            case "runAsStatement":
            case "soqlLiteral":
            case "soslLiteral":
                fail(node, "DML, SOQL and SOSL are not supported by the harness");
                return children(node);
            case "expression":
                switch (node.constructor.name) {
                    case "EqualityExpressionContext":
                        return emitEquality(node);
                    case "ArrayExpressionContext":
                        return emitArrayExpression(node);
                    case "AssignExpressionContext":
                        return emitAssign(node);
                    case "DotExpressionContext":
                        return emitDot(node);
                    case "NewExpressionContext":
                        return emitNew(node);
                    case "CoalExpressionContext":
                        fail(node, "null coalescing (??) is not supported");
                        return children(node);
                    default:
                        return children(node);
                }
            default:
                return children(node);
        }
    }

    const body = emit(tree);
    const java = `package ${JAVA_PACKAGE}; ` + body;
    return { java, errors, isTest, className };
}
