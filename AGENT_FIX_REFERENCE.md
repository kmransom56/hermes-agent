# System Admin Agent - Hermes Fixes Quick Reference

**Last Updated**: 2026-06-25  
**Status**: Production Deployed  
**Commit**: d423e7f6d

---

## 🚨 Issue Detection Guide

### Issue 1: Telegram Silent Failure
**Symptoms**:
```
✓ Gateway process running (systemctl status shows active)
✓ No error logs (journalctl shows clean startup)
✗ Messages not arriving from Telegram
✗ No error messages or alerts
✗ User can send messages to bot, but bot doesn't respond
```

**Diagnosis**:
```bash
# Check gateway logs for 409 Conflict
journalctl -u hermes-gateway.service | grep -i "409\|conflict"

# Check if Pre-flight deleteWebhook is in use
grep -n "Pre-flight deleteWebhook" /path/to/hermes-agent/plugins/platforms/telegram/adapter.py

# If not found → Apply Fix 1
```

**Quick Fix**:
```bash
# 1. Check if fix is deployed
git log --oneline | grep "d423e7f6d"  # Should show the commit

# 2. If missing, update Hermes
git pull origin main
git checkout d423e7f6d  # Or pull latest main

# 3. Restart gateway (fix is applied at startup)
sudo systemctl restart hermes-gateway

# 4. Test
sleep 3
# Send test message → Should arrive immediately
```

---

### Issue 2: CLI Task Output Freezing
**Symptoms**:
```
$ hermes --cli
> /background Summarize something
🔄 Background task #1 started: "Summarize something"
Task ID: bg_021033_abc123
You can continue chatting — results will appear when done.

[User must type something]

Type anything:
_

[Then results appear]
```

**Diagnosis**:
```bash
# Check if fix is deployed
grep -n "sys.stdout.flush()" /path/to/hermes-agent/hermes_cli/cli_commands_mixin.py

# If <5 matches found → Apply Fix 2
```

**Quick Fix**:
```bash
# 1. Check if fix is deployed
git log --oneline | grep "d423e7f6d"  # Should show the commit

# 2. If missing, update Hermes
git pull origin main
git checkout d423e7f6d  # Or pull latest main

# 3. CLI doesn't need restart (hot-loaded)
# Restart hermes CLI session

# 4. Test
hermes --cli
/background Check the current date
# → Results should appear immediately, no typing needed
```

---

## 📋 Fix Deployment Checklist

### Before Deployment
- [ ] Read FIXES_HERMES_TELEGRAM_CLI.md for full context
- [ ] Review commit d423e7f6d changes
- [ ] Backup current configuration
- [ ] Schedule during low-traffic window

### Deployment Steps
```bash
# 1. Verify current state
git status  # Should be clean
git branch  # Should be on main

# 2. Pull fix
git pull origin main

# 3. For Telegram fix: Restart gateway
sudo systemctl restart hermes-gateway
sleep 5
journalctl -u hermes-gateway.service -n 20  # Check for "Pre-flight deleteWebhook OK"

# 4. For CLI fix: No restart needed
# (New hermes CLI invocations will pick it up)

# 5. Verify
hermes --version  # Check you have latest
```

### Post-Deployment
- [ ] Check logs for any errors
- [ ] Test both fixes (see test commands below)
- [ ] Monitor for 24 hours
- [ ] Document deployment in agent memory

---

## ✅ Testing Procedures

### Test Telegram Fix
```bash
#!/bin/bash
echo "Testing Telegram Gateway 409 Fix..."

# Start gateway
sudo systemctl start hermes-gateway
sleep 3

# Check for pre-flight message
echo "1. Check logs for pre-flight deleteWebhook..."
journalctl -u hermes-gateway.service -n 5 | grep "deleteWebhook"

# Simulate restart scenario
echo "2. Restart gateway..."
sudo systemctl restart hermes-gateway
sleep 3

# Check logs again
echo "3. Check post-restart logs..."
journalctl -u hermes-gateway.service -n 5 | grep -E "deleteWebhook|Connected|ready"

# Send test message
echo "4. Send test message to bot and verify delivery..."
# (Manual: send message via Telegram app)
sleep 2

echo "✅ Telegram Gateway test complete"
```

### Test CLI Fix
```bash
#!/bin/bash
echo "Testing CLI Task Output Fix..."

# Run in headless mode to test buffering
hermes --cli << 'EOF'
/background Check the current system uptime
EOF

# Should see results immediately without needing to type
# Check for: "✅ Background task #N complete"

echo "✅ CLI Task Output test complete"
```

---

## 🔧 Troubleshooting

### "Pre-flight deleteWebhook failed" Warning
```
Problem: Log shows "Pre-flight deleteWebhook failed (non-fatal): ..."
Cause: Network issue or bad token
Action: 
  1. Check network connectivity: ping api.telegram.org
  2. Verify token: hermes config telegram (should show valid token)
  3. If network issue, fix network
  4. If token issue, update token and restart
  5. Telegram fix continues to work (pre-flight is non-fatal)
Severity: Low (normal PTB retry logic handles it)
```

### CLI Still Shows Output Delay
```
Problem: /background task results still delayed
Cause: Fix not deployed or old CLI version running
Action:
  1. Verify fix is deployed: git log | grep d423e7f6d
  2. Exit and restart CLI: hermes --cli (fresh session)
  3. Try again: /background Something
  4. If still delayed: check for terminal buffering issues
Severity: Medium (UX impact)
```

### Both Fixes Deployed but Issues Persist
```
Problem: Fixes deployed but original issue still occurs
Action:
  1. Verify commit: git log -1 --oneline (should be d423e7f6d or later)
  2. Check file content: grep "Pre-flight" adapter.py (for Telegram fix)
  3. Verify no conflicting versions running
  4. Check system logs for other errors
  5. Escalate to DevOps team
Severity: Critical
```

---

## 📚 Documentation Files

| File | Purpose | Location |
|------|---------|----------|
| FIXES_HERMES_TELEGRAM_CLI.md | Detailed technical documentation | /hermes-agent/ |
| add-hermes-fixes-to-neo4j.cypher | Neo4j memory import | /hermes-agent/backend/scripts/ |
| add-hermes-fixes-to-honcho.json | Honcho memory import | /hermes-agent/backend/scripts/ |
| AGENT_FIX_REFERENCE.md | This file - quick reference | /hermes-agent/ |

---

## 🤖 Agent Team Integration

### For System Admin Agents
1. **Discovery**: Query Neo4j for fixes tagged with "critical"
2. **Assessment**: Check system for symptoms (see Issue Detection above)
3. **Deployment**: Run deployment steps with validation
4. **Monitoring**: Set up monitoring for both fixes
5. **Reporting**: Document results in agent memory

### Neo4j Query
```cypher
MATCH (fix:Fix)-[:TAGGED_WITH]->(tag:Tag {name: "critical"})
WHERE tag.domain = "severity"
RETURN fix.name, fix.severity, fix.status, fix.commit
```

### Honcho Query
```
GET /api/memory?tags=critical&system=hermes-agent
```

---

## 📞 Support Escalation

### When to Escalate
- [ ] Fix doesn't resolve the issue
- [ ] New errors appear after deployment
- [ ] Rollback doesn't restore functionality
- [ ] Conflicts with other fixes or configurations

### Escalation Path
1. Document all symptoms and logs
2. Update agent memory with findings
3. Contact DevOps team with:
   - System state before fix
   - Expected behavior after fix
   - Actual behavior observed
   - Relevant log excerpts

---

## ✨ Key Takeaways

| Fix | Impact | Effort | Risk |
|-----|--------|--------|------|
| Telegram 409 Conflict | Prevents silent message loss | 5 min | Low |
| CLI Output Freezing | Better user experience | 2 min | Low |

Both fixes are:
- ✅ Production-tested
- ✅ Backward compatible
- ✅ Low risk
- ✅ High impact
- ✅ Deployed in commit d423e7f6d

**Recommendation**: Apply both fixes to all Hermes deployments.

---

**Document Version**: 1.0  
**Last Verified**: 2026-06-25  
**Agent Team**: System Admin (va-claims-saas)
