# skill: put the MausOS skill where agents look for skills.
#
# The skill teaches an agent the control ladder and the maus commands. It is
# the same agentskills format OpenMausBot imports and Omarchy ships.

src="$MAUSOS_PATH/skill/mausos"
for dir in \
  "$HOME/.claude/skills" \
  "$HOME/.codex/skills" \
  "$HOME/.agents/skills" \
  "$HOME/.config/opencode/skill" \
  "$HOME/.config/opencode/skills"; do
  link_into "$src" "$dir/mausos"
done
ok "skill linked (claude, codex, agents, opencode)"
