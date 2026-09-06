# shellcheck shell=bash
# skill: put the MausOS skill where agents look for skills.
#
# The skill teaches an agent the control ladder and the maus commands. It is
# the same agentskills format OpenMausBot imports and Omarchy ships.

src="$MAUSOS_PATH/skill/mausos"
# OpenCode also scans ~/.claude/skills, so linking it into its own directories
# too only produces "duplicate skill" warnings.
for dir in \
  "$HOME/.claude/skills" \
  "$HOME/.codex/skills"; do
  link_into "$src" "$dir/mausos"
done
for stale in "$HOME/.agents/skills/mausos" "$HOME/.config/opencode/skill/mausos" "$HOME/.config/opencode/skills/mausos"; do
  [[ -L $stale ]] && rm -f "$stale"
done
ok "skill linked (claude, codex; opencode reads ~/.claude/skills)"
