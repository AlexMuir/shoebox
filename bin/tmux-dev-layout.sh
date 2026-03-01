#!/usr/bin/env bash
set -euo pipefail

SESSION="photos-work"
PROJECT_DIR="/home/pippin/projects/photos"

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach-session -t "$SESSION"
  exit 0
fi

WIN_IDX=$(tmux show-option -gv base-index 2>/dev/null || echo 0)
PANE_IDX=$(tmux show-option -gv pane-base-index 2>/dev/null || echo 0)

tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n main
tmux send-keys -t "$SESSION":"$WIN_IDX"."$PANE_IDX" "opencode" C-m
tmux split-window -h -t "$SESSION":"$WIN_IDX" -c "$PROJECT_DIR"
tmux split-window -v -t "$SESSION":"$WIN_IDX"."$((PANE_IDX + 1))" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION":"$WIN_IDX"."$((PANE_IDX + 2))" "bin/dev" C-m
tmux select-pane -t "$SESSION":"$WIN_IDX"."$PANE_IDX"
tmux attach-session -t "$SESSION"
