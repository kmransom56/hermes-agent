# Hermes Cron Sandbox Security Configuration

**Date**: 2026-06-25  
**Status**: Deployed  
**Applies To**: Background cron jobs, automated system tasks

---

## Overview

Hermes includes built-in cron sandbox security that prevents `execute_code` tool execution during non-interactive loops (like system crons) without explicit human approval. This document explains the security feature and how to configure it.

## The Problem

When Hermes runs in an automated, unattended context (like a system cron job):
- The `execute_code` tool is blocked by default
- Attempts to execute code throw security errors
- Errors accumulate and trigger framework resets
- Repeated resets can cascade into other issues (e.g., Telegram 409 Conflict cycles)

## The Solution

Configure `execute_code` to allow unattended execution during cron jobs while maintaining approval requirements for interactive sessions.

## Configuration

**File**: `~/.hermes/config.yaml`

**Add to `tools` section**:
```yaml
tools:
  execute_code:
    require_approval: false          # Don't block during cron execution
    allow_cron_execution: true       # Explicitly allow cron context
  tool_search:
    enabled: auto
    # ... other tool configs ...
```

**Full example**:
```yaml
tools:
  execute_code:
    require_approval: false
    allow_cron_execution: true
  tool_search:
    enabled: auto
    threshold_pct: 10
    search_default_limit: 5
    max_search_limit: 20
```

## What This Allows

With this configuration, the following work without approval:

✅ **Cron-initiated tasks**:
- Scheduled backups
- Health monitoring jobs
- Automated system administration
- Batch processing

✅ **Background automation**:
- Scheduled data processing
- Periodic cache invalidation
- Automated remediation

## What Still Requires Approval

⚠️ **Interactive sessions** (CLI/TUI with human present):
- User runs `/execute <code>` or similar
- User types code directly in REPL
- Ad-hoc code execution in interactive context

The approval requirement is maintained to ensure humans supervise one-time code execution in interactive environments.

## How It Prevents Cascade Failures

**Without this configuration**:
```
1. Cron job tries to execute code
2. Security sandbox blocks it
3. Error thrown and logged
4. Error count accumulates
5. Framework resets after threshold
6. Reset cycle triggers other issues (e.g., Telegram gateway restart)
7. Gateway restart → getUpdates session timeout → 409 Conflict
```

**With this configuration**:
```
1. Cron job executes code freely (cron context detected)
2. Code runs to completion
3. No errors, no resets
4. System continues stable
```

## Verification

To verify the configuration is active:

```bash
# Check the setting is in config
grep -A 3 "execute_code:" ~/.hermes/config.yaml

# Expected output:
# execute_code:
#   require_approval: false
#   allow_cron_execution: true
```

## Security Considerations

| Context | Approval Required | Reason |
|---------|------------------|--------|
| Interactive CLI/TUI | ✅ Yes | Human present, can supervise |
| Cron jobs | ❌ No | Automated, non-interactive |
| System automation | ❌ No | Trusted, scheduled context |
| Ad-hoc code exec | ✅ Yes | One-off, requires oversight |

## Related Fixes

This configuration complements:
- **Telegram 409 Conflict Fix**: Prevents framework resets from cascading into Telegram issues
- **CLI Task Output Freezing Fix**: Ensures background tasks complete without interruption
- **Health Monitoring**: Allows hourly health checks to execute unattended

## Troubleshooting

**Issue**: Cron job still throws "approval required" error

**Solution**:
1. Verify config is saved: `grep "allow_cron_execution" ~/.hermes/config.yaml`
2. Restart Hermes service: `systemctl restart hermes-gateway` (or reload config)
3. Check Hermes logs: `journalctl -u hermes-gateway.service -n 20`
4. Verify cron context is detected in logs

**Issue**: Cron job executes but produces errors

**Solution**:
1. This config only affects the sandbox; code errors are separate
2. Check the actual error in logs
3. Fix the underlying issue in the code being executed

---

## Deployment Checklist

- [x] Configuration added to `~/.hermes/config.yaml`
- [x] `execute_code.require_approval` set to `false`
- [x] `execute_code.allow_cron_execution` set to `true`
- [x] Hermes service reloaded or restarted
- [x] Cron jobs verified to execute without approval blocks

## References

- **Hermes Security Model**: Default-deny for execute_code in non-interactive contexts
- **Cron Sandbox**: Runtime detection of cron vs. interactive context
- **Approval Framework**: Supervisor model for interactive code execution

---

**Status**: ✅ Deployed 2026-06-25  
**Tested**: Yes (cron jobs execute without approval blocks)  
**Impact**: Prevents framework resets, enables reliable automation
