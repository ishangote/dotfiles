#!/bin/bash
# Claude Code status line: shows model, cwd, and context-window usage.

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_name=$(basename "$cwd" 2>/dev/null)

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Colors (dim variants for readability on both light/dark terminals)
DIM=$'\033[2m'
RESET=$'\033[0m'
CYAN=$'\033[2;36m'
YELLOW=$'\033[2;33m'
RED=$'\033[2;31m'
GREEN=$'\033[2;32m'

# Build context usage segment with color thresholds
ctx_segment=""
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  if [ "$pct_int" -ge 80 ]; then
    color="$RED"
  elif [ "$pct_int" -ge 50 ]; then
    color="$YELLOW"
  else
    color="$GREEN"
  fi

  if [ -n "$total_tokens" ] && [ -n "$window_size" ]; then
    # Format tokens as e.g. 12.3k
    tok_fmt=$(awk -v t="$total_tokens" 'BEGIN { printf "%.1fk", t/1000 }')
    win_fmt=$(awk -v w="$window_size" 'BEGIN { printf "%.0fk", w/1000 }')
    ctx_segment=$(printf "%sCtx: %s%%%s %s(%s/%s)%s" "$color" "$pct_int" "$RESET" "$DIM" "$tok_fmt" "$win_fmt" "$RESET")
  else
    ctx_segment=$(printf "%sCtx: %s%%%s" "$color" "$pct_int" "$RESET")
  fi
else
  ctx_segment=$(printf "%sCtx: --%s" "$DIM" "$RESET")
fi

# Optional rate limit segment (5h / 7d), shown only when present
five=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
rate_segment=""
if [ -n "$five" ] || [ -n "$week" ]; then
  parts=""
  [ -n "$five" ] && parts="5h:$(printf '%.0f' "$five")%"
  if [ -n "$week" ]; then
    week_fmt="7d:$(printf '%.0f' "$week")%"
    if [ -n "$parts" ]; then parts="$parts $week_fmt"; else parts="$week_fmt"; fi
  fi
  rate_segment=$(printf "%s%s%s" "$DIM" "$parts" "$RESET")
fi

printf "%s%s%s %s%s%s %s|%s %s" "$CYAN" "$model" "$RESET" "$DIM" "$dir_name" "$RESET" "$DIM" "$RESET" "$ctx_segment"

if [ -n "$rate_segment" ]; then
  printf " %s|%s %s" "$DIM" "$RESET" "$rate_segment"
fi

printf "\n"
