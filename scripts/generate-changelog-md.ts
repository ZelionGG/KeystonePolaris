import { readdirSync, readFileSync, writeFileSync } from "fs";

const baseDir = "Modules/Changelog";
const changelogPath = "CHANGELOG.md";
const repoUrl = "https://github.com/ZelionGG/KeystonePolaris";

const categoryOrder = ["important", "new", "improvment", "bugfix"] as const;

const prefixMap: Record<(typeof categoryOrder)[number], string> = {
  important: "- 🔥 _**IMPORTANT** -_",
  new: "- 🆕 _**NEW** -_",
  improvment: "- 🛠️ _**IMPROVEMENT** -_",
  bugfix: "- 🐞 _**BUGFIX** -_",
};

type CategoryName = (typeof categoryOrder)[number];

interface ParsedHeader {
  title: string | null;
  text: string;
}

interface ParsedChangelog {
  version: string;
  releaseDate: string;
  header: ParsedHeader;
  entries: Record<CategoryName, string[]>;
}

function versionKeyFromString(version: string): number[] {
  const normalized = version.replace(/^[vV]/, "");

  if (!/^\d+(?:\.\d+)*$/.test(normalized)) {
    return [9999, 9999, 9999, 9999];
  }

  const parts = normalized.split(".").map((part) => Number.parseInt(part, 10));

  while (parts.length < 4) {
    parts.push(0);
  }

  return parts;
}

function compareVersions(left: string, right: string): number {
  const leftKey = versionKeyFromString(left);
  const rightKey = versionKeyFromString(right);

  for (let index = 0; index < 4; index += 1) {
    if (leftKey[index] !== rightKey[index]) {
      return leftKey[index] - rightKey[index];
    }
  }

  return 0;
}

function unescapeLuaString(text: string): string {
  return text.replace(/\\n/g, "\n").replace(/\\"/g, '"').replace(/\\\\/g, "\\");
}

function stripWowMarkup(text: string): string {
  return text
    .replace(/\|T[^|]+\|t/g, "")
    .replace(/\|c[0-9a-fA-F]{8}/g, "")
    .replace(/\|r/g, "")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function findLatestLiveLua(): string {
  const files = readdirSync(baseDir)
    .filter((fileName) => /^\d+(?:\.\d+)*\.lua$/i.test(fileName))
    .filter((fileName) => fileName !== "_changelog_tpl.lua" && !/^load_changelog\.xml$/i.test(fileName))
    .map((fileName) => `${baseDir}/${fileName}`);

  if (files.length === 0) {
    throw new Error(`No live changelog lua files found in ${baseDir}`);
  }

  files.sort((left, right) => compareVersions(right.replace(/^.*\//, "").replace(/\.lua$/i, ""), left.replace(/^.*\//, "").replace(/\.lua$/i, "")));
  return files[0];
}

function parseLuaChangelog(filePath: string): ParsedChangelog {
  const lines = readFileSync(filePath, "utf-8").split(/\r?\n/);

  let version: string | null = null;
  let releaseDate: string | null = null;
  const header: ParsedHeader = { title: null, text: "" };
  const entries = Object.fromEntries(categoryOrder.map((category) => [category, [] as string[]])) as Record<CategoryName, string[]>;

  let currentCategory: CategoryName | "header" | null = null;
  let inEnUs = false;
  let inHeaderEnUs = false;

  for (const line of lines) {
    if (version === null) {
      const match = line.match(/version_string\s*=\s*"([^"]+)"/);
      if (match) {
        version = match[1];
        continue;
      }
    }

    if (releaseDate === null) {
      const match = line.match(/release_date\s*=\s*"([^"]+)"/);
      if (match) {
        releaseDate = match[1];
        continue;
      }
    }

    if (/^\s*header\s*=\s*\{/.test(line)) {
      currentCategory = "header";
      inEnUs = false;
      inHeaderEnUs = false;
      continue;
    }

    const categoryMatch = line.match(/^\s*(important|new|improvment|bugfix)\s*=\s*\{/);
    if (categoryMatch) {
      currentCategory = categoryMatch[1] as CategoryName;
      inEnUs = false;
      inHeaderEnUs = false;
      continue;
    }

    if (currentCategory !== null && /^\s*\["enUS"\]\s*=\s*\{/.test(line)) {
      if (currentCategory === "header") {
        inHeaderEnUs = true;
      } else {
        inEnUs = true;
      }
      continue;
    }

    if ((inEnUs || inHeaderEnUs) && /^\s*\},\s*$/.test(line)) {
      inEnUs = false;
      inHeaderEnUs = false;
      continue;
    }

    if (inHeaderEnUs) {
      const titleMatch = line.match(/^\s*title\s*=\s*"((?:[^"\\]|\\.)*)",?\s*$/);
      if (titleMatch) {
        header.title = unescapeLuaString(titleMatch[1]);
        continue;
      }

      const textMatch = line.match(/^\s*(?:text\s*=\s*|\.\.\s*)"((?:[^"\\]|\\.)*)",?\s*$/);
      if (textMatch) {
        header.text += unescapeLuaString(textMatch[1]);
        continue;
      }
    }

    if (inEnUs && currentCategory && currentCategory !== "header") {
      const textMatch = line.match(/^\s*"((?:[^"\\]|\\.)*)",?\s*$/);
      if (textMatch) {
        entries[currentCategory].push(unescapeLuaString(textMatch[1]));
      }
    }
  }

  if (version === null) {
    throw new Error(`Could not parse version_string in ${filePath}`);
  }

  if (releaseDate === null) {
    throw new Error(`Could not parse release_date in ${filePath}`);
  }

  return {
    version,
    releaseDate: releaseDate.replace(/\//g, "-"),
    header,
    entries,
  };
}

function extractMarkdownVersions(content: string): string[] {
  return Array.from(content.matchAll(/^## \[([^\]]+)\]\(/gm), (match) => match[1]);
}

function getPreviousVersion(existingMarkdown: string, currentVersion: string): string {
  const versions = extractMarkdownVersions(existingMarkdown);

  if (versions.length === 0) {
    return currentVersion;
  }

  if (versions[0] === currentVersion && versions.length > 1) {
    return versions[1];
  }

  return versions[0];
}

function extractExistingCompareVersions(content: string): [string, string] | null {
  const match = content.match(/\[Full Changelog\]\([^)]*\/compare\/(v?\d+(?:\.\d+)*)\.\.\.(v?\d+(?:\.\d+)*)\)/);
  return match ? [match[1], match[2]] : null;
}

function boldBracketTokens(text: string): string {
  return text.replace(/\[([^\[\]]+)\]/g, "**$1**");
}

function buildHeaderLines(parsed: ParsedChangelog): string[] {
  const lines: string[] = [];

  if (parsed.header.title) {
    lines.push(`> **${stripWowMarkup(parsed.header.title)}**`);
  }

  if (parsed.header.text) {
    const paragraphs = parsed.header.text.trim().split(/\r?\n/);

    if (parsed.header.title && paragraphs.length > 0) {
      lines.push(">");
    }

    for (const paragraph of paragraphs) {
      const stripped = paragraph.trim();
      lines.push(stripped ? `> ${boldBracketTokens(stripWowMarkup(stripped))}` : ">");
    }
  }

  return lines;
}

function resolveCompareVersions(existingMarkdown: string, currentVersion: string, previousVersion: string): [string, string] {
  const existingCompare = extractExistingCompareVersions(existingMarkdown);

  if (existingCompare === null) {
    return [previousVersion, currentVersion];
  }

  const [existingFrom, existingTo] = existingCompare;
  if (compareVersions(existingTo, currentVersion) >= 0) {
    return [existingFrom, existingTo];
  }

  return [previousVersion, currentVersion];
}

function buildSection(parsed: ParsedChangelog, compareFrom: string, compareTo: string): string {
  const entryLines: string[] = [];

  for (const category of categoryOrder) {
    for (const entry of parsed.entries[category]) {
      entryLines.push(`${prefixMap[category]} ${boldBracketTokens(stripWowMarkup(entry))}`);
    }
  }

  const lines: string[] = [];
  lines.push(`## [${parsed.version}](${repoUrl}/releases/tag/${parsed.version}) (${parsed.releaseDate})`);
  lines.push("");
  lines.push(`[Full Changelog](${repoUrl}/compare/${compareFrom}...${compareTo}) [Previous Releases](${repoUrl}/releases)`);

  const headerLines = buildHeaderLines(parsed);
  if (headerLines.length > 0) {
    lines.push("");
    lines.push(...headerLines);
  }

  if (entryLines.length > 0) {
    lines.push("");
    lines.push(...entryLines);
  }

  return lines.join("\n");
}

function renderSingleVersionChangelog(existingMarkdown: string, section: string): string {
  const titleMatch = existingMarkdown.match(/^# .+$/m);
  const title = titleMatch ? titleMatch[0] : "# Keystone Polaris";
  return `${title}\n\n${section}\n`;
}

function main(): void {
  const latest = findLatestLiveLua();
  const parsed = parseLuaChangelog(latest);
  const existingMarkdown = readFileSync(changelogPath, "utf-8");
  const previousVersion = getPreviousVersion(existingMarkdown, parsed.version);
  const [compareFrom, compareTo] = resolveCompareVersions(existingMarkdown, parsed.version, previousVersion);
  const section = buildSection(parsed, compareFrom, compareTo);
  const updatedMarkdown = renderSingleVersionChangelog(existingMarkdown, section);

  writeFileSync(changelogPath, updatedMarkdown, "utf-8");
  console.log(`Updated ${changelogPath} from ${latest} (version ${parsed.version}).`);
}

main();