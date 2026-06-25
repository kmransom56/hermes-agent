// Neo4j import for Hermes Critical Fixes
// Usage: cypher-shell < add-hermes-fixes-to-neo4j.cypher

// Create fix registry
CREATE (fixes:FixRegistry {
  name: "Hermes Critical Fixes",
  version: "2026-06-25",
  status: "deployed",
  severity: "P1"
});

// Create Fix 1: Telegram 409 Conflict
CREATE (fix1:Fix {
  id: "hermes-telegram-409",
  name: "Telegram Gateway 409 Conflict Silent Failure",
  description: "Gateway goes silent after restart due to 409 Conflict on getUpdates endpoint",
  severity: "P1",
  impact: "All Telegram messages silently dropped after process restart",
  rootCause: "Previous process's getUpdates session persists for ~30s on Telegram infrastructure, causing 409 Conflict when new process initializes",
  solution: "Pre-flight HTTP deleteWebhook call before PTB initializes (Option B from RCA)",
  status: "deployed",
  commit: "d423e7f6d",
  file: "plugins/platforms/telegram/adapter.py",
  lines: "2022-2043",
  deployedDate: "2026-06-25",
  riskLevel: "low",
  backward_compatible: true,
  requires_config_change: false,
  requires_restart: true,
  estimated_fix_time_minutes: 5,
  testing_commands: "hermes gateway & sleep 2; kill %1; sleep 3; echo 'Check for immediate message delivery'"
});

// Create Fix 2: CLI Task Output Freezing
CREATE (fix2:Fix {
  id: "hermes-cli-task-output",
  name: "CLI Background Task Output Freezing",
  description: "Background task results don't display until user provides input (buffering issue)",
  severity: "P1",
  impact: "User experience degraded - task results hidden until TUI refresh triggered",
  rootCause: "stdout buffering in daemon thread - results flushed only on next TUI interaction",
  solution: "Explicit sys.stdout.flush() after each output section + TUI invalidation",
  status: "deployed",
  commit: "d423e7f6d",
  file: "hermes_cli/cli_commands_mixin.py",
  lines: "1513-1575",
  deployedDate: "2026-06-25",
  riskLevel: "low",
  backward_compatible: true,
  requires_config_change: false,
  requires_restart: false,
  estimated_fix_time_minutes: 2,
  testing_commands: "/background Check the current date"
});

// Create Fix Registry relationships
MATCH (fixes:FixRegistry {name: "Hermes Critical Fixes"}), (fix1:Fix {id: "hermes-telegram-409"})
CREATE (fixes)-[:CONTAINS {added_date: "2026-06-25"}]->(fix1);

MATCH (fixes:FixRegistry {name: "Hermes Critical Fixes"}), (fix2:Fix {id: "hermes-cli-task-output"})
CREATE (fixes)-[:CONTAINS {added_date: "2026-06-25"}]->(fix2);

// Create tags for easy discovery
CREATE (tag_telegram:Tag {name: "telegram", domain: "platforms"});
CREATE (tag_cli:Tag {name: "cli", domain: "interface"});
CREATE (tag_critical:Tag {name: "critical", domain: "severity"});
CREATE (tag_production:Tag {name: "production", domain: "environment"});

MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "telegram"})
CREATE (fix1)-[:TAGGED_WITH]->(tag);

MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "critical"})
CREATE (fix1)-[:TAGGED_WITH]->(tag);

MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "cli"})
CREATE (fix2)-[:TAGGED_WITH]->(tag);

MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "critical"})
CREATE (fix2)-[:TAGGED_WITH]->(tag);

MATCH (f:Fix), (tag:Tag {name: "production"})
CREATE (f)-[:TAGGED_WITH]->(tag);

// Create SystemAdminAgent relationships
MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "critical"})
CREATE (tag)-[:IMPORTANT_FOR {role: "SystemAdmin", reason: "Prevents silent message loss"}]->(fix1);

MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "critical"})
CREATE (tag)-[:IMPORTANT_FOR {role: "SystemAdmin", reason: "Improves user experience"}]->(fix2);

// Verification queries
RETURN (
  SELECT (fixes:FixRegistry)-[:CONTAINS]->(fix:Fix)
  WHERE fixes.name = "Hermes Critical Fixes"
  RETURN COUNT(fix) as total_fixes
);
