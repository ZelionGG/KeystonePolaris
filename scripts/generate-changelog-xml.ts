import { existsSync, readdirSync, readFileSync, writeFileSync } from "fs";
import { join, relative, sep } from "path";

const baseDir = "Modules/Changelog";
const outputFile = join(baseDir, "Load_Changelog.xml");

interface ChangelogFile {
  relativePath: string;
  groupName: string;
  subgroupName?: string;
  fileName: string;
}

function isVersionFileName(fileName: string): boolean {
  return /^\d+(?:\.\d+)*\.lua$/.test(fileName);
}

function getVersionParts(fileName: string): number[] {
  const stem = fileName.replace(/\.lua$/i, "");

  if (!/^\d+(?:\.\d+)*$/.test(stem)) {
    return [];
  }

  return stem.split(".").map((part) => Number.parseInt(part, 10));
}

function getVersionSortKey(fileName: string, normalizeSingleDigitPatch: boolean): string {
  const parts = [...getVersionParts(fileName)];

  if (parts.length === 0) {
    return "9999.9999.9999.9999";
  }

  if (normalizeSingleDigitPatch && parts.length === 3 && parts[2] < 10) {
    parts[2] *= 10;
  }

  while (parts.length < 4) {
    parts.push(0);
  }

  return parts
    .slice(0, 4)
    .map((part) => part.toString().padStart(4, "0"))
    .join(".");
}

function collectVersionFiles(dirPath: string): ChangelogFile[] {
  const entries = readdirSync(dirPath, { withFileTypes: true });
  const files: ChangelogFile[] = [];

  for (const entry of entries) {
    const fullPath = join(dirPath, entry.name);

    if (entry.isDirectory()) {
      files.push(...collectVersionFiles(fullPath));
      continue;
    }

    if (!entry.isFile() || !isVersionFileName(entry.name)) {
      continue;
    }

    const relativePath = relative(baseDir, fullPath);
    const segments = relativePath.split(sep);

    files.push({
      relativePath: segments.join("/"),
      groupName: segments[0] === "Old" ? "Old" : "LIVE",
      subgroupName: segments[0] === "Old" ? segments[1] : undefined,
      fileName: entry.name,
    });
  }

  return files;
}

function hasDoubleDigitPatch(files: ChangelogFile[]): boolean {
  return files.some((file) => /^\d+\.\d+\.\d{2,}\.lua$/.test(file.fileName));
}

function sortFiles(files: ChangelogFile[]): ChangelogFile[] {
  const normalizeSingleDigitPatch = hasDoubleDigitPatch(files);

  return [...files].sort((left, right) => {
    const leftKey = getVersionSortKey(left.fileName, normalizeSingleDigitPatch);
    const rightKey = getVersionSortKey(right.fileName, normalizeSingleDigitPatch);
    return leftKey.localeCompare(rightKey);
  });
}

function detectNewline(filePath: string): string {
  if (!existsSync(filePath)) {
    return "\n";
  }

  return readFileSync(filePath, "utf-8").includes("\r\n") ? "\r\n" : "\n";
}

function main(): void {
  const files = collectVersionFiles(baseDir);
  const liveFiles = sortFiles(files.filter((file) => file.groupName === "LIVE"));
  const oldSubgroups = Array.from(
    new Set(
      files
        .filter((file) => file.groupName === "Old" && file.subgroupName)
        .map((file) => file.subgroupName as string)
    )
  ).sort();

  const xmlLines: string[] = ['<Ui xmlns="http://www.blizzard.com/wow/ui/">'];

  for (const subgroupName of oldSubgroups) {
    const subgroupFiles = sortFiles(files.filter((file) => file.subgroupName === subgroupName));
    xmlLines.push(`    <!-- OLD ${subgroupName.toUpperCase()} -->`);

    for (const file of subgroupFiles) {
      xmlLines.push(`    <Script file='${file.relativePath}'/>`);
    }
  }

  if (liveFiles.length > 0) {
    xmlLines.push("    <!-- LIVE -->");

    for (const file of liveFiles) {
      xmlLines.push(`    <Script file='${file.relativePath}'/>`);
    }
  }

  xmlLines.push("</Ui>");

  const newline = detectNewline(outputFile);
  const prefix = "\uFEFF";
  writeFileSync(outputFile, `${prefix}${xmlLines.join(newline)}${newline}`, "utf-8");
  console.log(`Generated ${outputFile} with ${files.length} entries.`);
}

main();