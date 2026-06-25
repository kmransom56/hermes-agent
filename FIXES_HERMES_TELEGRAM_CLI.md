# Hermes Agent Critical Fixes - Telegram & CLI

**Date**: 2026-06-25  
**Commit**: d423e7f6d  
**Status**: Deployed and tested  
**Target Teams**: System Admin Agents, DevOps, Hermes Gateway Operations

---

## Overview

Two critical production issues fixed:

1. **Telegram Gateway Silent Failure** — Gateway goes silent after restart with no error logs
2. **CLI Task Output Freezing** — Background tasks display but no results shown until user input

Both fixes are deployed in the main Hermes repository and ready for reuse.

---

## Fix 1: Telegram Gateway 409 Conflict

### Problem
After `hermes gateway` restarts:
- No messages arrive
- No error logs or stack traces
- Gateway appears healthy (process running, no crashes)
- Manual Telegram messages are silently dropped
- **Root cause**: 409 Conflict error exhausts retry limit within 30-second server-side session TTL

### Technical Details
```
Timeline:
1. Old Hermes process: getUpdates session opened on Telegram's infrastructure (~30s TTL)
2. Process exits/restarts immediately
3. New process: initialize() triggers getUpdates before old session expires
4. Telegram returns 409 Conflict (two simultaneous getUpdates)
5. Hermes retries 3 times (10s, 20s, 30s delays) but all fail within 30s window
6. _set_fatal_error() called → adapter marked permanently dead
7. Gateway sees no adapter → no new messages arrive
```

### Solution Applied
**File**: `plugins/platforms/telegram/adapter.py` lines 2022-2043

**Code change**: Added pre-flight HTTP deleteWebhook call BEFORE PTB initializes

```python
# Pre-flight Telegram reset (called immediately after platform lock acquisition)
try:
    import httpx as _httpx
    _preflight_url = f"https://api.telegram.org/bot{self.config.token}/deleteWebhook"
    async with _httpx.AsyncClient(timeout=10.0) as _preflight:
        _r = await _preflight.post(_preflight_url, json={"drop_pending_updates": False})
        _data = _r.json()
        if _data.get("ok"):
            logger.info("[%s] Pre-flight deleteWebhook OK", self.name)
        else:
            logger.warning("[%s] Pre-flight deleteWebhook returned: %s", self.name, _data)
except Exception as _pf_err:
    logger.warning("[%s] Pre-flight deleteWebhook failed (non-fatal): %s", self.name, _pf_err)
```

### How It Works
1. Uses separate `httpx` client (not PTB's connection pool)
2. Clears any stale webhook before PTB tries to initialize
3. Prevents 409 Conflict from occurring in the first place
4. Non-fatal: if it fails, normal PTB retry logic handles it
5. Works on first restart without waiting for 30s TTL

### Deployment Checklist
- [ ] Ensure `httpx` is installed (check requirements.txt)
- [ ] Test restart: `hermes gateway` → restart → verify messages arrive within 2-3s
- [ ] Check logs for "Pre-flight deleteWebhook OK"
- [ ] Monitor for any network timeouts (logs: "Pre-flight deleteWebhook failed")

### Related Issues
- Issue #11016: Split-brain stale lock fix (related conflict handling)
- Issue #17758: Recursive stack overflow with 409 conflict retries

---

## Fix 2: CLI Task Output Freezing

### Problem
When running background task with `/background <prompt>`:
1. Task name displays: "🔄 Background task #1 started: ..."
2. CLI returns to prompt
3. **But**: Task results never display
4. **Workaround**: User must type something to trigger TUI refresh
5. Then results suddenly appear

### Technical Details
```
Cause: stdout buffering in daemon thread

Timeline:
1. Background task runs in daemon thread
2. Task completes and prints results to stdout
3. Results are buffered (not flushed)
4. Main thread shows prompt (which flushes TUI buffer)
5. User must interact to trigger TUI refresh
6. At that point, buffered task output finally appears
```

### Solution Applied
**File**: `hermes_cli/cli_commands_mixin.py` lines 1513-1575

**Code changes**: Added explicit flushing and TUI invalidation

1. **After blank line**: `sys.stdout.flush()`
2. **After task header**: `sys.stdout.flush()`
3. **After task response**: `sys.stdout.flush()`
4. **After bell (if enabled)**: Already had `sys.stdout.flush()` — kept
5. **Final step**: TUI invalidation with `self._app.invalidate()`
6. **Error path**: Same pattern for failure messages

### How It Works
```python
# Success path
print()
sys.stdout.flush()  # flush blank line
# ... print header ...
sys.stdout.flush()  # flush header
# ... print response ...
sys.stdout.flush()  # flush response
if self._app:
    self._app.invalidate()  # refresh TUI immediately

# Error path
print()
sys.stdout.flush()  # flush error line
_cprint(f"❌ Background task failed: {e}")
sys.stdout.flush()  # ensure error visible
if self._app:
    self._app.invalidate()  # refresh TUI
```

### Deployment Checklist
- [ ] Test: `/background Summarize something`
- [ ] Verify results appear immediately (within 100ms)
- [ ] No need to type anything to see results
- [ ] Error messages also appear immediately
- [ ] TUI prompt refreshes properly after completion

---

## Reuse Instructions for Agent Team

### For System Admin Agents
These fixes are production-ready and should be applied to any Hermes deployment:

1. **Telegram issue**: Check if your gateway goes silent after restart
   - Apply Fix 1 if experiencing this
   - Minimal risk (non-fatal pre-flight call)
   - Major impact (prevents hours of silent failures)

2. **CLI issue**: Check if background tasks don't show output immediately
   - Apply Fix 2 if experiencing this
   - Zero risk (just adds flushing)
   - Major impact (improves user experience significantly)

### Verification Commands
```bash
# Check if fixes are applied
grep -n "Pre-flight deleteWebhook" plugins/platforms/telegram/adapter.py
grep -n "sys.stdout.flush()" hermes_cli/cli_commands_mixin.py

# Test Telegram fix
hermes gateway &
sleep 2
kill %1  # restart
sleep 3
# → Should receive any messages sent during restart without delay

# Test CLI fix
hermes --cli
/background Check the current date
# → Result should appear immediately, no need to type anything
```

### Emergency Rollback
If either fix causes issues:
```bash
# Revert to previous commit
git revert d423e7f6d
hermes gateway  # restart with previous version

# Or apply just one fix
git cherry-pick <individual-commit-if-split>
```

---

## Documentation Links
- **Telegram RCA**: `/home/keith/Downloads/telegram_gateway_fix.md`
- **Commit**: `d423e7f6d` in NousResearch/hermes-agent
- **Files Modified**: 
  - `plugins/platforms/telegram/adapter.py` (23 lines added)
  - `hermes_cli/cli_commands_mixin.py` (11 lines added)

---

## Agent Knowledge Base

### For Neo4j Memory Integration
```cypher
MATCH (n:Fix) WHERE n.name = "Telegram_409_Conflict" RETURN n
MATCH (n:Fix) WHERE n.name = "CLI_Task_Output_Freezing" RETURN n
```

### For Honcho Memory Integration
```
Category: Hermes Fixes
Tags: #telegram, #cli, #critical, #production
Status: Deployed (2026-06-25)
Severity: P1 (both are production-impacting)
```

---

## Questions? Testing?

For system admin agents to implement or test:
1. Always test on staging first
2. Monitor logs for any anomalies
3. Report failures to the DevOps team
4. Both fixes are backward compatible (no config changes needed)

**Owner**: System Admin Team  
**Last Updated**: 2026-06-25  
**Review Cycle**: Monthly (verify no regressions)
