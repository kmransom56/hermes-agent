// Neo4j import for Hermes Critical Fixes
// Usage: cypher-shell < add-hermes-fixes-to-neo4j.cypher

// Create fix registry (idempotent with MERGE)
MERGE (fixes:FixRegistry {name: "Hermes Critical Fixes"})
SET fixes.version = "2026-06-25",
    fixes.status = "deployed",
    fixes.severity = "P1";

// Create Fix 1: Telegram 409 Conflict
MERGE (fix1:Fix {id: "hermes-telegram-409"})
SET fix1.name = "Telegram Gateway 409 Conflict Silent Failure",
    fix1.description = "Gateway goes silent after restart due to 409 Conflict on getUpdates endpoint",
    fix1.severity = "P1",
    fix1.impact = "All Telegram messages silently dropped after process restart",
    fix1.rootCause = "Previous process's getUpdates session persists for ~30s on Telegram infrastructure, causing 409 Conflict when new process initializes",
    fix1.solution = "Pre-flight HTTP deleteWebhook call before PTB initializes (Option B from RCA)",
    fix1.status = "deployed",
    fix1.commit = "d423e7f6d",
    fix1.file = "plugins/platforms/telegram/adapter.py",
    fix1.lines = "2022-2043",
    fix1.deployedDate = "2026-06-25",
    fix1.riskLevel = "low",
    fix1.backward_compatible = true,
    fix1.requires_config_change = false,
    fix1.requires_restart = true,
    fix1.estimated_fix_time_minutes = 5,
    fix1.testing_commands = "hermes gateway & sleep 2; kill %1; sleep 3; echo 'Check for immediate message delivery'";

// Create Fix 2: CLI Task Output Freezing
MERGE (fix2:Fix {id: "hermes-cli-task-output"})
SET fix2.name = "CLI Background Task Output Freezing",
    fix2.description = "Background task results don't display until user provides input (buffering issue)",
    fix2.severity = "P1",
    fix2.impact = "User experience degraded - task results hidden until TUI refresh triggered",
    fix2.rootCause = "stdout buffering in daemon thread - results flushed only on next TUI interaction",
    fix2.solution = "Explicit sys.stdout.flush() after each output section + TUI invalidation",
    fix2.status = "deployed",
    fix2.commit = "d423e7f6d",
    fix2.file = "hermes_cli/cli_commands_mixin.py",
    fix2.lines = "1513-1575",
    fix2.deployedDate = "2026-06-25",
    fix2.riskLevel = "low",
    fix2.backward_compatible = true,
    fix2.requires_config_change = false,
    fix2.requires_restart = false,
    fix2.estimated_fix_time_minutes = 2,
    fix2.testing_commands = "/background Check the current date";

// Create registry relationships
MATCH (fixes:FixRegistry {name: "Hermes Critical Fixes"}), (fix1:Fix {id: "hermes-telegram-409"})
MERGE (fixes)-[:CONTAINS {added_date: "2026-06-25"}]->(fix1);

MATCH (fixes:FixRegistry {name: "Hermes Critical Fixes"}), (fix2:Fix {id: "hermes-cli-task-output"})
MERGE (fixes)-[:CONTAINS {added_date: "2026-06-25"}]->(fix2);

// Create tags
MERGE (tag_telegram:Tag {name: "telegram"}) SET tag_telegram.domain = "platforms";
MERGE (tag_cli:Tag {name: "cli"}) SET tag_cli.domain = "interface";
MERGE (tag_critical:Tag {name: "critical"}) SET tag_critical.domain = "severity";
MERGE (tag_production:Tag {name: "production"}) SET tag_production.domain = "environment";

// Tag Fix 1
MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "telegram"})
MERGE (fix1)-[:TAGGED_WITH]->(tag);

MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "critical"})
MERGE (fix1)-[:TAGGED_WITH]->(tag);

MATCH (fix1:Fix {id: "hermes-telegram-409"}), (tag:Tag {name: "production"})
MERGE (fix1)-[:TAGGED_WITH]->(tag);

// Tag Fix 2
MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "cli"})
MERGE (fix2)-[:TAGGED_WITH]->(tag);

MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "critical"})
MERGE (fix2)-[:TAGGED_WITH]->(tag);

MATCH (fix2:Fix {id: "hermes-cli-task-output"}), (tag:Tag {name: "production"})
MERGE (fix2)-[:TAGGED_WITH]->(tag);

// Return summary
MATCH (registry:FixRegistry)-[:CONTAINS]->(fix:Fix)
RETURN registry.name as registry, COUNT(fix) as total_fixes, COLLECT(fix.name) as fixes_imported;
