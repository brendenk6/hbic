#!/bin/bash
# PostToolUse hook (matcher: Bash)
# Detects AppleScript clipboard-paste-into-Terminal pattern and reminds
# Claude to set up a monitoring loop instead of reporting to the user.
set -u
jq -c 'if ((.tool_input.command // "" | test("Terminal")) and (.tool_input.command // "" | test("keystroke.*command down"))) then {hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: "You just sent a message to another LLM. MANDATORY: Set up a ScheduleWakeup (60-120s) to check their response. Do NOT end your turn with a status update to Brenden. Stay in the orchestration loop — read their terminal history on the next wake."}} else empty end' 2>/dev/null || true
