import { createHash } from "crypto";
import { readFileSync, writeFileSync, readdirSync } from "fs";
import { join, basename, normalize, relative, resolve } from "path";
import { fileURLToPath } from "url";

// ── Types ──────────────────────────────────────────────────────────────────────

export interface BaseEntry {
  kind: "assignment";
  key: string;
  value: string;
  rawLines: string[];
}

export interface BaseComment {
  kind: "comment";
  rawLine: string;
}

export interface BaseBlank {
  kind: "blank";
}

export type BaseElement = BaseEntry | BaseComment | BaseBlank;

export type LocaleEntryStatus =
  | "translated"
  | "untranslated-marked"
  | "todo-commented"
  | "stale-flagged";

const SAME_VALUE_ALLOWLIST: ReadonlySet<string> = new Set([
  // Expansion names are intentionally kept in English by most translators
  "EXPANSION_MIDNIGHT",
  "EXPANSION_WW",
  "EXPANSION_DF",
  "EXPANSION_SL",
  "EXPANSION_BFA",
  "EXPANSION_LEGION",
  "EXPANSION_WOD",
  "EXPANSION_CATA",
  "EXPANSION_WOTLK",
  "EXPANSION_MOP",
  "EXPANSION_CLASSIC",
  // Date format key — translators set locale-appropriate format which may match base
  "%month%-%day%-%year%",
]);

export interface LocaleEntry {
  key: string;
  value: string;
  status: LocaleEntryStatus;
  rawLines: string[];
  /** Stale marker payload: enUS@hash12 digits, or legacy full base value string. */
  todoValue?: string;
  noTranslate: boolean;
}

export interface LocaleReport {
  locale: string;
  newKeys: string[];
  removedKeys: string[];
  staleKeys: string[];
  updatedTodoValues: string[];
  totalKeys: number;
  translatedKeys: number;
  parseWarnings: number;
}

// ── Patterns ───────────────────────────────────────────────────────────────────

const L_KEY_RE = /^L\["([^"]+)"\]\s*=/;
const TODO_L_KEY_RE = /^\s*--\s*TODO:\s*L\["([^"]+)"\]\s*=/;
const DIFF_LINE_L_KEY_RE = /^\s*(?:--\s*TODO:\s*)?L\["([^"]+)"\]\s*=/;
const TO_TRANSLATE_RE = /--\s*(?:TODO:\s*)?To Translate\s*$/;
const NO_TRANSLATE_RE = /--\s*@no-translate\b/;
const STALE_HASH_RE = /--\s*TODO:\s*enUS@([a-f0-9]+)\s*$/;
const STALE_LEGACY_RE = /--\s*TODO:\s*"([^"]*)"$/;
const LOOKS_LIKE_LOCALE_LINE_RE = /(?:^|\s)--\s*TODO:\s*L\[|L\[/;

// ── Parsing helpers ────────────────────────────────────────────────────────────

export function extractValueString(rawLines: string[]): string {
  const full = rawLines.join("\n");
  const eqIdx = full.indexOf("=");
  if (eqIdx === -1) return "";
  const rhs = full.substring(eqIdx + 1);
  const segments: string[] = [];
  const regex = /"((?:[^"\\]|\\.|"")*)"/g;
  let match: RegExpExecArray | null;
  while ((match = regex.exec(rhs)) !== null) {
    segments.push(match[1]);
  }
  return segments.join("");
}

export function hashBaseValue(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex").slice(0, 12);
}

export function isStaleMarkerCurrent(marker: string | undefined, baseValue: string): boolean {
  if (marker === undefined) {
    return false;
  }

  const expectedHash = hashBaseValue(baseValue);
  if (/^[a-f0-9]+$/.test(marker)) {
    return marker === expectedHash;
  }

  // Legacy full-value marker from older sync-locales runs
  return marker === baseValue;
}

function isLineContinuation(line: string): boolean {
  return /\.\.\s*$/.test(line.trimEnd());
}

function splitNormalizedLines(content: string): string[] {
  const lines = content.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  if (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }
  return lines;
}

function readLines(filePath: string): string[] {
  return splitNormalizedLines(readFileSync(filePath, "utf-8"));
}

function trimTrailingBlankLines(lines: string[]): string[] {
  const trimmedLines = [...lines];

  while (trimmedLines.length > 0 && trimmedLines[trimmedLines.length - 1].trim() === "") {
    trimmedLines.pop();
  }

  return trimmedLines;
}

function collectContinuationLines(
  lines: string[],
  startIndex: number
): { rawLines: string[]; endIndex: number } {
  const rawLines: string[] = [lines[startIndex]];
  let i = startIndex;
  let current = lines[i];
  while (isLineContinuation(current) && i + 1 < lines.length) {
    i++;
    current = lines[i];
    rawLines.push(current);
  }
  return { rawLines, endIndex: i };
}

// ── Diff parser ────────────────────────────────────────────────────────────────

function normalizeDiffFilePath(filePath: string): string {
  return normalize(filePath.replace(/^[ab]\//, "")).replace(/\\/g, "/");
}

function getDiffLookupPaths(filePath: string): string[] {
  const absolutePath = normalize(filePath).replace(/\\/g, "/");
  const relativePath = normalize(relative(process.cwd(), filePath)).replace(/\\/g, "/");
  return [absolutePath, relativePath, basename(filePath)];
}

export function getChangedKeysForFile(
  changedKeysByFile: Map<string, Set<string>>,
  filePath: string
): Set<string> {
  for (const candidate of getDiffLookupPaths(filePath)) {
    const changedKeys = changedKeysByFile.get(candidate);
    if (changedKeys) {
      return changedKeys;
    }
  }

  return new Set<string>();
}

function extractDiffLineKey(line: string): string | null {
  if (line.startsWith("+++") || line.startsWith("---")) {
    return null;
  }

  // Unified diffs often put the assignment on the hunk header:
  // @@ -17,7 +17,7 @@ L["KEY"] = "..."
  if (line.startsWith("@@")) {
    const hunkMatch = line.match(/@@.*?@@\s*(?:--\s*TODO:\s*)?L\["([^"]+)"\]/);
    return hunkMatch ? hunkMatch[1] : null;
  }

  if (!(line.startsWith("+") || line.startsWith("-") || line.startsWith(" "))) {
    return null;
  }

  const content = line.slice(1);
  const match = content.match(DIFF_LINE_L_KEY_RE);
  return match ? match[1] : null;
}

function isDiffContinuationAddedLine(line: string): boolean {
  if (!line.startsWith("+") || line.startsWith("+++")) {
    return false;
  }

  const content = line.slice(1);
  if (DIFF_LINE_L_KEY_RE.test(content)) {
    return false;
  }

  return /"/.test(content) || /\.\.\s*$/.test(content.trimEnd());
}

/**
 * Parse a unified diff and collect changed locale keys per file.
 * Tracks the current L["key"] across context/add/remove lines so edits that
 * only touch multi-line string continuations still mark the parent key.
 */
export function parseDiffContent(content: string): Map<string, Set<string>> {
  const changedKeysByFile = new Map<string, Set<string>>();
  const lines = splitNormalizedLines(content);
  let currentFilePath: string | null = null;
  let currentKey: string | null = null;

  const ensureSet = (path: string): Set<string> => {
    let changedKeys = changedKeysByFile.get(path);
    if (!changedKeys) {
      changedKeys = new Set<string>();
      changedKeysByFile.set(path, changedKeys);
    }
    return changedKeys;
  };

  for (const line of lines) {
    if (line.startsWith("+++ ")) {
      const rawPath = line.slice(4).trim();
      currentFilePath = rawPath === "/dev/null" ? null : normalizeDiffFilePath(rawPath);
      currentKey = null;
      continue;
    }

    if (!currentFilePath) {
      continue;
    }

    if (
      line.startsWith("@@") ||
      line.startsWith("+") ||
      line.startsWith("-") ||
      line.startsWith(" ")
    ) {
      const keyFromLine = extractDiffLineKey(line);
      if (keyFromLine) {
        currentKey = keyFromLine;
      }
    }

    if (!line.startsWith("+") || line.startsWith("+++")) {
      continue;
    }

    const addedKey = extractDiffLineKey(line);
    if (addedKey) {
      ensureSet(currentFilePath).add(addedKey);
      continue;
    }

    if (currentKey && isDiffContinuationAddedLine(line)) {
      ensureSet(currentFilePath).add(currentKey);
    }
  }

  return changedKeysByFile;
}

export function parseDiffByFile(diffPath: string): Map<string, Set<string>> {
  return parseDiffContent(readFileSync(diffPath, "utf-8"));
}

// ── Base locale parser ────────────────────────────────────────────────────────

const TRANSLATIONS_START_MARKER = "-- ## Translations Start ## --";

function findTranslationsStart(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === TRANSLATIONS_START_MARKER) {
      return i + 1;
    }
  }
  throw new Error(`Missing "${TRANSLATIONS_START_MARKER}" marker in enUS.lua`);
}

export function parseBaseLocale(filePath: string): { header: string[]; elements: BaseElement[] } {
  const lines = readLines(filePath);
  const contentStart = findTranslationsStart(lines);
  const header = lines.slice(0, contentStart);
  const elements: BaseElement[] = [];
  let i = contentStart;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      elements.push({ kind: "blank" });
      i++;
      continue;
    }

    const assignMatch = line.match(L_KEY_RE);
    if (assignMatch) {
      const key = assignMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const value = extractValueString(rawLines);
      elements.push({ kind: "assignment", key, value, rawLines });
      i = endIndex + 1;
      continue;
    }

    // Comments and non-assignment lines (including TODO: lines without L["KEY"])
    elements.push({ kind: "comment", rawLine: line });
    i++;
  }

  return { header, elements };
}

// ── Translation locale parser ─────────────────────────────────────────────────

function findLocaleHeaderEnd(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*if\s+not\s+L\s+then\s+return\s+end/.test(lines[i])) {
      return i + 1;
    }
  }
  throw new Error("Missing 'if not L then return end' in locale file");
}

export function findFirstContentElement(baseElements: BaseElement[]): BaseComment | BaseEntry | null {
  for (const element of baseElements) {
    if (element.kind !== "blank") {
      return element;
    }
  }

  return null;
}

function hasLeadingBlank(baseElements: BaseElement[]): boolean {
  return baseElements.length > 0 && baseElements[0].kind === "blank";
}

function isLineMatchingBaseElementStart(
  line: string,
  firstContentElement: BaseComment | BaseEntry | null
): boolean {
  if (!firstContentElement) {
    return false;
  }

  if (firstContentElement.kind === "comment") {
    return line === firstContentElement.rawLine;
  }

  const todoMatch = line.match(TODO_L_KEY_RE);
  if (todoMatch?.[1] === firstContentElement.key) {
    return true;
  }

  const assignMatch = line.match(L_KEY_RE);
  return assignMatch?.[1] === firstContentElement.key;
}

export function parseLocale(
  filePath: string,
  baseEntries: Map<string, BaseEntry>,
  firstContentElement: BaseComment | BaseEntry | null
): {
  header: string[];
  introLines: string[];
  entries: Map<string, LocaleEntry>;
  parseWarnings: number;
} {
  const lines = readLines(filePath);
  const headerEnd = findLocaleHeaderEnd(lines);
  const header = lines.slice(0, headerEnd);
  const introLines: string[] = [];
  const entries = new Map<string, LocaleEntry>();
  let parseWarnings = 0;
  let i = headerEnd;

  while (i < lines.length && !isLineMatchingBaseElementStart(lines[i], firstContentElement)) {
    introLines.push(lines[i]);
    i++;
  }

  const trimmedIntroLines = trimTrailingBlankLines(introLines);

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      i++;
      continue;
    }

    const todoMatch = line.match(TODO_L_KEY_RE);
    if (todoMatch) {
      const key = todoMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const value = extractValueString(rawLines);
      const lastLine = rawLines[rawLines.length - 1];
      entries.set(key, {
        key,
        value,
        status: "todo-commented",
        rawLines,
        noTranslate: NO_TRANSLATE_RE.test(lastLine),
      });
      i = endIndex + 1;
      continue;
    }

    const assignMatch = line.match(L_KEY_RE);
    if (assignMatch) {
      const key = assignMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const lastLine = rawLines[rawLines.length - 1];
      const noTranslate = NO_TRANSLATE_RE.test(lastLine);

      const staleHashMatch = lastLine.match(STALE_HASH_RE);
      if (staleHashMatch) {
        const value = extractValueString(rawLines);
        entries.set(key, {
          key,
          value,
          status: "stale-flagged",
          rawLines,
          todoValue: staleHashMatch[1],
          noTranslate,
        });
        i = endIndex + 1;
        continue;
      }

      const staleLegacyMatch = lastLine.match(STALE_LEGACY_RE);
      if (staleLegacyMatch) {
        const value = extractValueString(rawLines);
        entries.set(key, {
          key,
          value,
          status: "stale-flagged",
          rawLines,
          todoValue: staleLegacyMatch[1],
          noTranslate,
        });
        i = endIndex + 1;
        continue;
      }

      const hasToTranslateMarker = TO_TRANSLATE_RE.test(lastLine);

      const value = extractValueString(rawLines);

      if (hasToTranslateMarker) {
        entries.set(key, { key, value, status: "untranslated-marked", rawLines, noTranslate });
      } else {
        const baseEntry = baseEntries.get(key);
        if (
          baseEntry !== undefined &&
          value === baseEntry.value &&
          !SAME_VALUE_ALLOWLIST.has(key) &&
          !noTranslate
        ) {
          entries.set(key, { key, value, status: "untranslated-marked", rawLines, noTranslate });
        } else {
          entries.set(key, { key, value, status: "translated", rawLines, noTranslate });
        }
      }

      i = endIndex + 1;
      continue;
    }

    if (LOOKS_LIKE_LOCALE_LINE_RE.test(line)) {
      process.stderr.write(`Warning: ${filePath}:${i + 1}: unrecognized locale line: ${line}\n`);
      parseWarnings++;
    }

    i++;
  }

  return { header, introLines: trimmedIntroLines, entries, parseWarnings };
}

// ── Output generation ──────────────────────────────────────────────────────────

function formatTodoEntry(baseEntry: BaseEntry): string[] {
  return baseEntry.rawLines.map((line) => `-- TODO: ${line}`);
}

export function stripStaleTodoSuffix(rawLines: string[]): string[] {
  const lines = [...rawLines];
  const lastIdx = lines.length - 1;
  lines[lastIdx] = lines[lastIdx].replace(/\s*--\s*TODO:.*$/, "");
  return lines;
}

export function formatStaleEntry(localeEntry: LocaleEntry, newBaseValue: string): string[] {
  const lines = stripStaleTodoSuffix(localeEntry.rawLines);
  const lastIdx = lines.length - 1;
  lines[lastIdx] = `${lines[lastIdx]} -- TODO: enUS@${hashBaseValue(newBaseValue)}`;
  return lines;
}

function stripToTranslateFromComment(comment: string): string {
  return comment.replace(/\s*\(To Translate\)\s*$/, "");
}

export function generateLocaleFile(
  localeCode: string,
  localeHeader: string[],
  introLines: string[],
  baseElements: BaseElement[],
  baseEntries: Map<string, BaseEntry>,
  localeEntries: Map<string, LocaleEntry>,
  changedBaseKeys: Set<string>,
  changedLocaleKeys: Set<string>,
  parseWarnings = 0
): { content: string; report: LocaleReport } {
  const outputLines: string[] = [];
  const report: LocaleReport = {
    locale: localeCode,
    newKeys: [],
    removedKeys: [],
    staleKeys: [],
    updatedTodoValues: [],
    totalKeys: 0,
    translatedKeys: 0,
    parseWarnings,
  };

  const seenBaseKeys = new Set<string>();

  outputLines.push(...localeHeader);

  if (introLines.length > 0) {
    outputLines.push(...introLines);
  } else if (!hasLeadingBlank(baseElements)) {
    outputLines.push("");
  }

  for (const element of baseElements) {
    if (element.kind === "blank") {
      outputLines.push("");
      continue;
    }

    if (element.kind === "comment") {
      outputLines.push(stripToTranslateFromComment(element.rawLine));
      continue;
    }

    const key = element.key;
    const baseValue = element.value;

    if (seenBaseKeys.has(key)) {
      continue;
    }
    seenBaseKeys.add(key);
    report.totalKeys++;

    const localeEntry = localeEntries.get(key);

    if (!localeEntry) {
      outputLines.push(...formatTodoEntry(element));
      report.newKeys.push(key);
      continue;
    }

    switch (localeEntry.status) {
      case "translated": {
        // Flag translations as stale only when the base changed and this locale key did not.
        if (
          changedBaseKeys.has(key) &&
          !changedLocaleKeys.has(key) &&
          !localeEntry.noTranslate
        ) {
          outputLines.push(...formatStaleEntry(localeEntry, baseValue));
          report.staleKeys.push(key);
        } else {
          outputLines.push(...localeEntry.rawLines);
        }
        report.translatedKeys++;
        break;
      }

      case "untranslated-marked": {
        outputLines.push(...formatTodoEntry(element));
        break;
      }

      case "todo-commented": {
        if (localeEntry.value !== baseValue) {
          outputLines.push(...formatTodoEntry(element));
          report.updatedTodoValues.push(key);
        } else {
          outputLines.push(...localeEntry.rawLines);
        }
        break;
      }

      case "stale-flagged": {
        if (localeEntry.noTranslate) {
          outputLines.push(...stripStaleTodoSuffix(localeEntry.rawLines));
        } else if (!isStaleMarkerCurrent(localeEntry.todoValue, baseValue)) {
          // Update the TODO marker to the current base value hash
          outputLines.push(...formatStaleEntry(localeEntry, baseValue));
          report.staleKeys.push(key);
        } else {
          outputLines.push(...localeEntry.rawLines);
        }
        report.translatedKeys++;
        break;
      }
    }
  }

  for (const key of localeEntries.keys()) {
    if (!baseEntries.has(key)) {
      report.removedKeys.push(key);
    }
  }

  const content = outputLines.join("\n") + "\n";
  return { content, report };
}

// ── CLI ────────────────────────────────────────────────────────────────────────

export function main(): void {
  const args = process.argv.slice(2);

  const dryRun = args.includes("--dry-run");

  const diffIdx = args.indexOf("--diff");
  let diffPath: string | null = null;
  if (diffIdx !== -1) {
    const next = args[diffIdx + 1];
    if (!next || next.startsWith("--")) {
      process.stderr.write("Error: --diff requires a file path argument\n");
      process.exit(1);
    }
    diffPath = next;
  }
  const changedKeysByFile = diffPath ? parseDiffByFile(diffPath) : new Map<string, Set<string>>();

  const fileArgs = args.filter((a: string, i: number) => !a.startsWith("--") && i !== diffIdx + 1);

  const localesDir = join(process.cwd(), "Locales");
  const basePath = join(localesDir, "enUS.lua");
  const changedBaseKeys = getChangedKeysForFile(changedKeysByFile, basePath);

  const { elements: baseElements } = parseBaseLocale(basePath);
  const firstContentElement = findFirstContentElement(baseElements);

  const baseEntries = new Map<string, BaseEntry>();
  for (const el of baseElements) {
    if (el.kind === "assignment") {
      baseEntries.set(el.key, el);
    }
  }

  let localeFiles: string[];
  if (fileArgs.length > 0) {
    localeFiles = fileArgs.map((f: string) => {
      if (f.includes("/")) return f;
      return join(localesDir, f);
    });
  } else {
    localeFiles = readdirSync(localesDir)
      .filter((f: string) => f.endsWith(".lua") && f !== "enUS.lua")
      .sort()
      .map((f: string) => join(localesDir, f));
  }

  const reports: LocaleReport[] = [];

  for (const filePath of localeFiles) {
    const localeCode = basename(filePath, ".lua");
    const { header, introLines, entries, parseWarnings } = parseLocale(
      filePath,
      baseEntries,
      firstContentElement
    );
    const changedLocaleKeys = getChangedKeysForFile(changedKeysByFile, filePath);

    const { content, report } = generateLocaleFile(
      localeCode,
      header,
      introLines,
      baseElements,
      baseEntries,
      entries,
      changedBaseKeys,
      changedLocaleKeys,
      parseWarnings
    );

    reports.push(report);

    if (!dryRun) {
      writeFileSync(filePath, content, "utf-8");
    }
  }

  const totalBaseKeys = baseEntries.size;
  process.stderr.write("\nLocale Sync Report\n");
  process.stderr.write("==================\n");

  for (const r of reports) {
    const pct = totalBaseKeys > 0 ? Math.round((r.translatedKeys / totalBaseKeys) * 100) : 0;
    const changes: string[] = [];
    if (r.newKeys.length > 0) changes.push(`${r.newKeys.length} new TODOs`);
    if (r.staleKeys.length > 0) changes.push(`${r.staleKeys.length} stale flagged`);
    if (r.updatedTodoValues.length > 0) changes.push(`${r.updatedTodoValues.length} TODO values updated`);
    if (r.removedKeys.length > 0) changes.push(`${r.removedKeys.length} removed`);
    if (r.parseWarnings > 0) changes.push(`${r.parseWarnings} parse warnings`);
    const changesStr = changes.length > 0 ? changes.join(", ") : "no changes";
    process.stderr.write(
      `${r.locale}.lua:  ${r.translatedKeys}/${totalBaseKeys} translated (${pct}%)  |  ${changesStr}\n`
    );
  }

  if (dryRun) {
    process.stderr.write("\n(dry run — no files modified)\n");
  }

  process.stderr.write("\n");
}

function isExecutedAsCli(): boolean {
  const entry = process.argv[1];
  if (!entry) {
    return false;
  }

  try {
    return resolve(entry) === resolve(fileURLToPath(import.meta.url));
  } catch {
    return basename(entry) === "sync-locales.ts" || basename(entry) === "sync-locales.js";
  }
}

if (isExecutedAsCli()) {
  main();
}
