import { readFileSync, writeFileSync, readdirSync } from "fs";
import { join, basename } from "path";

// ── Types ──────────────────────────────────────────────────────────────────────

interface EnusEntry {
  kind: "assignment";
  key: string;
  value: string;
  rawLines: string[];
}

interface EnusComment {
  kind: "comment";
  rawLine: string;
}

interface EnusBlank {
  kind: "blank";
}

type EnusElement = EnusEntry | EnusComment | EnusBlank;

type LocaleEntryStatus =
  | "translated"
  | "untranslated-marked"
  | "untranslated-unmarked"
  | "todo-commented"
  | "stale-flagged";

interface LocaleEntry {
  key: string;
  value: string;
  status: LocaleEntryStatus;
  rawLines: string[];
  todoValue?: string;
}

interface LocaleReport {
  locale: string;
  newKeys: string[];
  removedKeys: string[];
  staleKeys: string[];
  updatedTodoValues: string[];
  totalKeys: number;
  translatedKeys: number;
}

// ── Parsing helpers ────────────────────────────────────────────────────────────

function extractValueString(rawLines: string[]): string {
  // Extract the value portion (after the first =) and concatenate all quoted segments
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

function isLineContinuation(line: string): boolean {
  return /\.\.\s*$/.test(line.trimEnd());
}

function readLines(filePath: string): string[] {
  const lines = readFileSync(filePath, "utf-8").split("\n");
  if (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }
  return lines;
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

function parseEnusDiff(diffPath: string): Set<string> {
  // Parse a unified diff of enUS.lua to find keys whose values changed.
  // We look at added lines (starting with +) that contain L["KEY"] assignments,
  // since a changed value appears as a removed old line and an added new line.
  const changedKeys = new Set<string>();
  const content = readFileSync(diffPath, "utf-8");
  const lines = content.split("\n");

  for (const line of lines) {
    if (!line.startsWith("+") || line.startsWith("+++")) continue;
    const match = line.match(/^\+\s*L\["([^"]+)"\]\s*=/);
    if (match) {
      changedKeys.add(match[1]);
    }
  }

  return changedKeys;
}

// ── enUS parser ────────────────────────────────────────────────────────────────

const TRANSLATIONS_START_MARKER = "-- ## Translations Start ## --";

function findTranslationsStart(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].trim() === TRANSLATIONS_START_MARKER) {
      return i + 1;
    }
  }
  throw new Error(`Missing "${TRANSLATIONS_START_MARKER}" marker in enUS.lua`);
}

function parseEnUS(filePath: string): { header: string[]; elements: EnusElement[] } {
  const lines = readLines(filePath);
  const contentStart = findTranslationsStart(lines);
  const header = lines.slice(0, contentStart);
  const elements: EnusElement[] = [];
  let i = contentStart;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      elements.push({ kind: "blank" });
      i++;
      continue;
    }

    if (/^\s*--/.test(line) && !/^\s*--\s*TODO:/.test(line)) {
      elements.push({ kind: "comment", rawLine: line });
      i++;
      continue;
    }

    const assignMatch = line.match(/^L\["([^"]+)"\]\s*=/);
    if (assignMatch) {
      const key = assignMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const value = extractValueString(rawLines);
      elements.push({ kind: "assignment", key, value, rawLines });
      i = endIndex + 1;
      continue;
    }

    elements.push({ kind: "comment", rawLine: line });
    i++;
  }

  return { header, elements };
}

// ── Non-enUS locale parser ─────────────────────────────────────────────────────

function findLocaleHeaderEnd(lines: string[]): number {
  for (let i = 0; i < lines.length; i++) {
    if (/^\s*if\s+not\s+L\s+then\s+return\s+end/.test(lines[i])) {
      return i + 1;
    }
  }
  throw new Error("Missing 'if not L then return end' in locale file");
}

function parseLocale(
  filePath: string,
  enusEntries: Map<string, EnusEntry>
): {
  header: string[];
  fileComment: string | null;
  entries: Map<string, LocaleEntry>;
} {
  const lines = readLines(filePath);
  const headerEnd = findLocaleHeaderEnd(lines);
  const header = lines.slice(0, headerEnd);
  const entries = new Map<string, LocaleEntry>();
  let fileComment: string | null = null;
  let i = headerEnd;

  if (i < lines.length && lines[i].trim() === "") {
    i++;
  }

  if (i < lines.length && /^\s*--\s*(?:TRANSLATION REQUIRED|Traduction:)/.test(lines[i])) {
    fileComment = lines[i];
    i++;
  }

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "") {
      i++;
      continue;
    }

    // Non-TODO comments (section headers, etc.) — skip, output uses enUS ordering
    if (/^\s*--/.test(line) && !/^\s*--\s*TODO:\s*L\[/.test(line)) {
      i++;
      continue;
    }

    // TODO-commented entry: -- TODO: L["KEY"] = "value"
    const todoMatch = line.match(/^\s*--\s*TODO:\s*L\["([^"]+)"\]\s*=/);
    if (todoMatch) {
      const key = todoMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const value = extractValueString(rawLines);
      entries.set(key, { key, value, status: "todo-commented", rawLines });
      i = endIndex + 1;
      continue;
    }

    // Active assignment: L["KEY"] = "value" possibly with markers
    const assignMatch = line.match(/^L\["([^"]+)"\]\s*=/);
    if (assignMatch) {
      const key = assignMatch[1];
      const { rawLines, endIndex } = collectContinuationLines(lines, i);
      const lastLine = rawLines[rawLines.length - 1];

      const staleMatch = lastLine.match(/--\s*TODO:\s*"([^"]*)"$/);
      if (staleMatch) {
        const value = extractValueString(rawLines);
        entries.set(key, {
          key,
          value,
          status: "stale-flagged",
          rawLines,
          todoValue: staleMatch[1],
        });
        i = endIndex + 1;
        continue;
      }

      const hasToTranslateMarker =
        /--\s*To Translate\s*$/.test(lastLine) ||
        /--\s*TODO:\s*To Translate\s*$/.test(lastLine);

      const value = extractValueString(rawLines);

      if (hasToTranslateMarker) {
        entries.set(key, { key, value, status: "untranslated-marked", rawLines });
      } else {
        const enusEntry = enusEntries.get(key);
        if (enusEntry !== undefined && value === enusEntry.value) {
          entries.set(key, { key, value, status: "untranslated-unmarked", rawLines });
        } else {
          entries.set(key, { key, value, status: "translated", rawLines });
        }
      }

      i = endIndex + 1;
      continue;
    }

    i++;
  }

  return { header, fileComment, entries };
}

// ── Output generation ──────────────────────────────────────────────────────────

function formatTodoEntry(enusEntry: EnusEntry): string[] {
  if (enusEntry.rawLines.length === 1) {
    return [`-- TODO: ${enusEntry.rawLines[0]}`];
  }
  return enusEntry.rawLines.map((line) => `-- TODO: ${line}`);
}

function formatStaleEntry(localeEntry: LocaleEntry, newEnusValue: string): string[] {
  const lines = [...localeEntry.rawLines];
  const lastIdx = lines.length - 1;
  const lastLine = lines[lastIdx].replace(/\s*--\s*TODO:.*$/, "");
  lines[lastIdx] = `${lastLine} -- TODO: "${newEnusValue}"`;
  return lines;
}

function stripToTranslateFromComment(comment: string): string {
  return comment.replace(/\s*\(To Translate\)\s*$/, "");
}

function generateLocaleFile(
  localeCode: string,
  localeHeader: string[],
  fileComment: string | null,
  enusElements: EnusElement[],
  enusEntries: Map<string, EnusEntry>,
  localeEntries: Map<string, LocaleEntry>,
  changedEnusKeys: Set<string>
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
  };

  const seenEnusKeys = new Set<string>();

  outputLines.push(...localeHeader);
  outputLines.push("");

  if (fileComment) {
    outputLines.push(fileComment);
  }

  for (const element of enusElements) {
    if (element.kind === "blank") {
      outputLines.push("");
      continue;
    }

    if (element.kind === "comment") {
      outputLines.push(stripToTranslateFromComment(element.rawLine));
      continue;
    }

    const key = element.key;
    const enusValue = element.value;

    if (seenEnusKeys.has(key)) {
      continue;
    }
    seenEnusKeys.add(key);
    report.totalKeys++;

    const localeEntry = localeEntries.get(key);

    if (!localeEntry) {
      outputLines.push(...formatTodoEntry(element));
      report.newKeys.push(key);
      continue;
    }

    switch (localeEntry.status) {
      case "translated": {
        // If this key's enUS value changed in the diff, flag the translation as stale
        if (changedEnusKeys.has(key)) {
          outputLines.push(...formatStaleEntry(localeEntry, enusValue));
          report.staleKeys.push(key);
        } else {
          outputLines.push(...localeEntry.rawLines);
        }
        report.translatedKeys++;
        break;
      }

      case "untranslated-marked":
      case "untranslated-unmarked": {
        outputLines.push(...formatTodoEntry(element));
        break;
      }

      case "todo-commented": {
        if (localeEntry.value !== enusValue) {
          outputLines.push(...formatTodoEntry(element));
          report.updatedTodoValues.push(key);
        } else {
          outputLines.push(...localeEntry.rawLines);
        }
        break;
      }

      case "stale-flagged": {
        // Update the TODO marker to the current enUS value
        if (localeEntry.todoValue !== enusValue) {
          outputLines.push(...formatStaleEntry(localeEntry, enusValue));
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
    if (!enusEntries.has(key)) {
      report.removedKeys.push(key);
    }
  }

  const content = outputLines.join("\n") + "\n";
  return { content, report };
}

// ── CLI ────────────────────────────────────────────────────────────────────────

function main(): void {
  const args = process.argv.slice(2);

  const dryRun = args.includes("--dry-run");
  const reportJson = args.includes("--report-json");

  const diffIdx = args.indexOf("--diff");
  const diffPath = diffIdx !== -1 ? args[diffIdx + 1] : null;
  const changedEnusKeys = diffPath ? parseEnusDiff(diffPath) : new Set<string>();

  const fileArgs = args.filter((a, i) => !a.startsWith("--") && i !== diffIdx + 1);

  const localesDir = join(process.cwd(), "Locales");
  const enusPath = join(localesDir, "enUS.lua");

  const { elements: enusElements } = parseEnUS(enusPath);

  const enusEntries = new Map<string, EnusEntry>();
  for (const el of enusElements) {
    if (el.kind === "assignment") {
      enusEntries.set(el.key, el);
    }
  }

  let localeFiles: string[];
  if (fileArgs.length > 0) {
    localeFiles = fileArgs.map((f) => {
      if (f.includes("/")) return f;
      return join(localesDir, f);
    });
  } else {
    localeFiles = readdirSync(localesDir)
      .filter((f) => f.endsWith(".lua") && f !== "enUS.lua")
      .sort()
      .map((f) => join(localesDir, f));
  }

  const reports: LocaleReport[] = [];

  for (const filePath of localeFiles) {
    const localeCode = basename(filePath, ".lua");
    const { header, fileComment, entries } = parseLocale(filePath, enusEntries);

    const { content, report } = generateLocaleFile(
      localeCode,
      header,
      fileComment,
      enusElements,
      enusEntries,
      entries,
      changedEnusKeys
    );

    reports.push(report);

    if (!dryRun) {
      writeFileSync(filePath, content, "utf-8");
    }
  }

  const totalEnusKeys = enusEntries.size;
  process.stderr.write("\nLocale Sync Report\n");
  process.stderr.write("==================\n");

  for (const r of reports) {
    const pct = totalEnusKeys > 0 ? Math.round((r.translatedKeys / totalEnusKeys) * 100) : 0;
    const changes: string[] = [];
    if (r.newKeys.length > 0) changes.push(`${r.newKeys.length} new TODOs`);
    if (r.staleKeys.length > 0) changes.push(`${r.staleKeys.length} stale flagged`);
    if (r.updatedTodoValues.length > 0) changes.push(`${r.updatedTodoValues.length} TODO values updated`);
    if (r.removedKeys.length > 0) changes.push(`${r.removedKeys.length} removed`);
    const changesStr = changes.length > 0 ? changes.join(", ") : "no changes";
    process.stderr.write(
      `${r.locale}.lua:  ${r.translatedKeys}/${totalEnusKeys} translated (${pct}%)  |  ${changesStr}\n`
    );
  }

  if (dryRun) {
    process.stderr.write("\n(dry run — no files modified)\n");
  }

  process.stderr.write("\n");

  if (reportJson) {
    process.stdout.write(JSON.stringify(reports, null, 2) + "\n");
  }
}

main();
