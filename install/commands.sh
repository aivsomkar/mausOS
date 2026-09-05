# commands: link every bin/maus* into ~/.local/bin.

chmod +x "$MAUSOS_PATH"/bin/* "$MAUSOS_PATH/lib/atspi.py"

bindir="$HOME/.local/bin"
mkdir -p "$bindir"

# Remove links from an older checkout location first.
for old in "$bindir"/maus "$bindir"/maus-*; do
  [[ -L "$old" ]] || continue
  target=$(readlink -f "$old" 2>/dev/null || true)
  [[ -n "$target" && -e "$target" ]] || rm -f "$old"
done

count=0
for cmd in "$MAUSOS_PATH"/bin/maus "$MAUSOS_PATH"/bin/maus-*; do
  link_into "$cmd" "$bindir/$(basename "$cmd")"
  count=$((count + 1))
done
ok "$count commands linked into $bindir"

case ":$PATH:" in
  *":$bindir:"*) ;;
  *)
    warn "$bindir is not on PATH in this shell. Omarchy adds it at login; otherwise add: export PATH=\"\$HOME/.local/bin:\$PATH\""
    ;;
esac

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/mausos"
