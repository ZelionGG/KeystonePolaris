import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, describe, it } from "node:test";
import {
  extractValueString,
  formatStaleEntry,
  generateLocaleFile,
  hashBaseValue,
  isStaleMarkerCurrent,
  parseBaseLocale,
  parseDiffContent,
  parseLocale,
  type BaseEntry,
  type LocaleEntry,
} from "./sync-locales.ts";

const tempDirs: string[] = [];

function makeTempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), "sync-locales-"));
  tempDirs.push(dir);
  return dir;
}

afterEach(() => {
  while (tempDirs.length > 0) {
    const dir = tempDirs.pop();
    if (dir) {
      rmSync(dir, { recursive: true, force: true });
    }
  }
});

describe("parseDiffContent", () => {
  it("detects a key when only a multi-line continuation is changed", () => {
    const diff = `
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -1,4 +1,4 @@
 L["COMPATIBILITY_WARNING_MESSAGE"] = "|cffff0000header|r\\n" ..
-                                "|cff8888ff• old line|r\\n" ..
+                                "|cff8888ff• new line|r\\n" ..
                                 "footer\\n"
`.trimStart();

    const changed = parseDiffContent(diff);
    const keys = changed.get("Locales/enUS.lua");
    assert.ok(keys);
    assert.equal(keys.has("COMPATIBILITY_WARNING_MESSAGE"), true);
  });

  it("detects a classic single-line assignment change", () => {
    const diff = `
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -1,1 +1,1 @@
-L["FINISHED"] = "Old"
+L["FINISHED"] = "New"
`.trimStart();

    const changed = parseDiffContent(diff);
    const keys = changed.get("Locales/enUS.lua");
    assert.ok(keys);
    assert.equal(keys.has("FINISHED"), true);
  });

  it("ignores continuation adds when no L key was seen in the hunk", () => {
    const diff = `
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -10,1 +10,1 @@
-                                "|cff8888ff• old line|r\\n" ..
+                                "|cff8888ff• new line|r\\n" ..
`.trimStart();

    const changed = parseDiffContent(diff);
    const keys = changed.get("Locales/enUS.lua");
    assert.equal(keys === undefined || keys.size === 0, true);
  });

  it("detects a key from the @@ hunk header when only a continuation changes", () => {
    const diff = `
diff --git a/Locales/enUS.lua b/Locales/enUS.lua
--- a/Locales/enUS.lua
+++ b/Locales/enUS.lua
@@ -17,7 +17,7 @@ L["COMPATIBILITY_WARNING_MESSAGE"] = "|cffff0000header|r\\n" ..
                                 "|cff8888ff• keep|r\\n" ..
-                                "|cff8888ff• Projected values|r\\n\\n" ..
+                                "|cff8888ff• Projected values CHANGED|r\\n\\n" ..
                                 "footer\\n"
`.trimStart();

    const changed = parseDiffContent(diff);
    const keys = changed.get("Locales/enUS.lua");
    assert.ok(keys);
    assert.equal(keys.has("COMPATIBILITY_WARNING_MESSAGE"), true);
  });
});

describe("same-value and @no-translate handling", () => {
  it("marks identical values without @no-translate as untranslated", () => {
    const dir = makeTempDir();
    const localePath = join(dir, "frFR.lua");
    writeFileSync(
      localePath,
      `
local AddonName, Engine = ...;
local L = {};
if not L then return end

-- Section
L["HELLO"] = "Hello"
`.trimStart() + "\n",
      "utf-8"
    );

    const baseEntries = new Map<string, BaseEntry>([
      [
        "HELLO",
        {
          kind: "assignment",
          key: "HELLO",
          value: "Hello",
          rawLines: ['L["HELLO"] = "Hello"'],
        },
      ],
    ]);

    const { entries } = parseLocale(localePath, baseEntries, {
      kind: "comment",
      rawLine: "-- Section",
    });

    assert.equal(entries.get("HELLO")?.status, "untranslated-marked");
  });

  it("keeps identical @no-translate values as translated and skips stale", () => {
    const dir = makeTempDir();
    const localePath = join(dir, "frFR.lua");
    writeFileSync(
      localePath,
      `
local AddonName, Engine = ...;
local L = {};
if not L then return end

-- Section
L["ZONE"] = "Zone" -- @no-translate
`.trimStart() + "\n",
      "utf-8"
    );

    const baseEntries = new Map<string, BaseEntry>([
      [
        "ZONE",
        {
          kind: "assignment",
          key: "ZONE",
          value: "Zone",
          rawLines: ['L["ZONE"] = "Zone"'],
        },
      ],
    ]);

    const { entries } = parseLocale(localePath, baseEntries, {
      kind: "comment",
      rawLine: "-- Section",
    });

    assert.equal(entries.get("ZONE")?.status, "translated");
    assert.equal(entries.get("ZONE")?.noTranslate, true);

    const { content, report } = generateLocaleFile(
      "frFR",
      ["local L = {}", "if not L then return end"],
      [],
      [
        { kind: "comment", rawLine: "-- Section" },
        {
          kind: "assignment",
          key: "ZONE",
          value: "Zone Changed",
          rawLines: ['L["ZONE"] = "Zone Changed"'],
        },
      ],
      baseEntries,
      entries,
      new Set(["ZONE"]),
      new Set()
    );

    assert.equal(report.staleKeys.includes("ZONE"), false);
    assert.match(content, /L\["ZONE"\] = "Zone" -- @no-translate/);
    assert.doesNotMatch(content, /enUS@/);
  });
});

describe("stale hash markers", () => {
  it("writes enUS@hash and updates when base value changes", () => {
    const baseValue = "New English";
    const entry: LocaleEntry = {
      key: "HELLO",
      value: "Bonjour",
      status: "translated",
      rawLines: ['L["HELLO"] = "Bonjour"'],
      noTranslate: false,
    };

    const staleLines = formatStaleEntry(entry, baseValue);
    assert.equal(staleLines[0], `L["HELLO"] = "Bonjour" -- TODO: enUS@${hashBaseValue(baseValue)}`);
    assert.equal(isStaleMarkerCurrent(hashBaseValue(baseValue), baseValue), true);
    assert.equal(isStaleMarkerCurrent(hashBaseValue(baseValue), "Other"), false);

    // Legacy full-value marker still recognized as current
    assert.equal(isStaleMarkerCurrent("Legacy Value", "Legacy Value"), true);

    const localeEntries = new Map<string, LocaleEntry>([
      [
        "HELLO",
        {
          key: "HELLO",
          value: "Bonjour",
          status: "stale-flagged",
          rawLines: [`L["HELLO"] = "Bonjour" -- TODO: enUS@${hashBaseValue("Old English")}`],
          todoValue: hashBaseValue("Old English"),
          noTranslate: false,
        },
      ],
    ]);

    const baseEntries = new Map<string, BaseEntry>([
      [
        "HELLO",
        {
          kind: "assignment",
          key: "HELLO",
          value: baseValue,
          rawLines: [`L["HELLO"] = "${baseValue}"`],
        },
      ],
    ]);

    const { content, report } = generateLocaleFile(
      "frFR",
      ["if not L then return end"],
      [],
      [baseEntries.get("HELLO")!],
      baseEntries,
      localeEntries,
      new Set(),
      new Set()
    );

    assert.equal(report.staleKeys.includes("HELLO"), true);
    assert.match(content, new RegExp(`enUS@${hashBaseValue(baseValue)}`));
  });
});

describe("parse warnings", () => {
  it("emits a warning for malformed L[ lines", () => {
    const dir = makeTempDir();
    const localePath = join(dir, "frFR.lua");
    writeFileSync(
      localePath,
      `
local AddonName, Engine = ...;
local L = {};
if not L then return end

-- Section
L["BROKEN"
L["OK"] = "D'accord"
`.trimStart() + "\n",
      "utf-8"
    );

    const baseEntries = new Map<string, BaseEntry>([
      [
        "OK",
        {
          kind: "assignment",
          key: "OK",
          value: "Ok",
          rawLines: ['L["OK"] = "Ok"'],
        },
      ],
    ]);

    const stderrChunks: string[] = [];
    const originalWrite = process.stderr.write.bind(process.stderr);
    process.stderr.write = ((chunk: string | Uint8Array, ...args: unknown[]) => {
      stderrChunks.push(String(chunk));
      return originalWrite(chunk, ...(args as []));
    }) as typeof process.stderr.write;

    try {
      const { parseWarnings, entries } = parseLocale(localePath, baseEntries, {
        kind: "comment",
        rawLine: "-- Section",
      });
      assert.equal(parseWarnings, 1);
      assert.equal(entries.get("OK")?.status, "translated");
      assert.match(stderrChunks.join(""), /unrecognized locale line/);
    } finally {
      process.stderr.write = originalWrite;
    }
  });
});

describe("extractValueString", () => {
  it("joins multi-line concatenated segments", () => {
    const value = extractValueString([
      'L["MSG"] = "hello\\n" ..',
      '                                "world"',
    ]);
    assert.equal(value, "hello\\nworld");
  });
});

describe("parseBaseLocale smoke", () => {
  it("requires the translations start marker", () => {
    const dir = makeTempDir();
    const basePath = join(dir, "enUS.lua");
    writeFileSync(basePath, 'L["A"] = "a"\n', "utf-8");
    assert.throws(() => parseBaseLocale(basePath), /Translations Start/);
  });
});
