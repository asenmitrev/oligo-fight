import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import * as fs from "node:fs";
import * as path from "node:path";

/**
 * Scans .claude/commands/ directories (cwd walking up to repo root)
 * and registers each .md file as a Pi slash command.
 *
 * When invoked, the command's content is sent to the agent as a user message,
 * so the LLM follows the steps defined in the file.
 */
export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const commandFiles = findClaudeCommands(ctx.cwd);

    for (const file of commandFiles) {
      const basename = path.basename(file, ".md");
      const content = fs.readFileSync(file, "utf-8");
      const firstLine = content.split("\n").find((l) => l.trim()) ?? "";
      const description = firstLine.replace(/^#+\s*/, "").trim();

      pi.registerCommand(basename, {
        description,
        handler: async (args, ctx) => {
          let prompt = content;
          if (args) {
            prompt += `\n\nUser arguments: ${args}`;
          }
          await ctx.sendUserMessage(prompt);
        },
      });
    }
  });
}

function findClaudeCommands(cwd: string): string[] {
  const results: string[] = [];
  const seen = new Set<string>();
  let current = path.resolve(cwd);

  while (true) {
    const cmdDir = path.join(current, ".claude", "commands");
    if (fs.existsSync(cmdDir) && fs.statSync(cmdDir).isDirectory()) {
      for (const entry of fs.readdirSync(cmdDir)) {
        if (entry.endsWith(".md")) {
          const fullPath = path.join(cmdDir, entry);
          if (!seen.has(fullPath)) {
            seen.add(fullPath);
            results.push(fullPath);
          }
        }
      }
    }
    // Stop at repo root or filesystem root
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }

  return results;
}
