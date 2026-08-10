-- ~/.config/wezterm/wezterm.lua  -  Ishan's WezTerm config
--
-- ONE file, vendored identically in both dotfiles repos (personal Mac and the
-- Meta chezmoi repo). Everything Meta-specific sits behind the `is_meta` guard
-- below and self-disables where /usr/facebook is absent, so the two copies stay
-- byte-identical and a plain `diff` between them is meaningful. Same pattern
-- ~/.config/nvim/init.lua already uses to load meta.nvim conditionally.
--
-- Config auto-reloads on save (or Cmd+Shift+R). Never put side-effecting code at
-- the top level - WezTerm may evaluate this file multiple times per process.

local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

-- Is this a Meta-managed machine? Probes for a file the corp image always ships
-- and a personal Mac never has, rather than matching on hostname (which is not
-- stable across a laptop refresh).
local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end
local is_meta = file_exists("/usr/facebook/ops/rc/master.zshrc")

-- ── Look ─────────────────────────────────────────────────────────────────────
-- rose-pine-moon is the shared palette: WezTerm, Neovim and herdr all render it,
-- so there is no seam between the terminal, the editor and the multiplexer.
config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.tab_max_width = 32
config.adjust_window_size_when_changing_font_size = false
config.window_close_confirmation = "NeverPrompt"
config.default_cursor_style = "BlinkingBar"
config.cursor_blink_rate = 500
config.audible_bell = "Disabled"

-- ── Keys ─────────────────────────────────────────────────────────────────────
-- Cmd-based throughout, so nothing shadows readline's C-a or the bare Ctrl+hjkl
-- that vim-tmux-navigator needs to pass through untouched.
--
-- Word and line motion:
--   Option+arrow  -> ESC-b / ESC-f   (zsh backward-word / forward-word)
--   Command+arrow -> Ctrl-A / Ctrl-E (beginning-of-line / end-of-line)
config.keys = {
  { key = "LeftArrow",  mods = "ALT", action = act.SendKey({ key = "b", mods = "ALT" }) },
  { key = "RightArrow", mods = "ALT", action = act.SendKey({ key = "f", mods = "ALT" }) },
  { key = "LeftArrow",  mods = "CMD", action = act.SendKey({ key = "a", mods = "CTRL" }) },
  { key = "RightArrow", mods = "CMD", action = act.SendKey({ key = "e", mods = "CTRL" }) },

  -- Companion deletions: Cmd+Backspace kills to line start, Opt+Backspace kills a word.
  { key = "Backspace", mods = "CMD", action = act.SendKey({ key = "u", mods = "CTRL" }) },
  { key = "Backspace", mods = "ALT", action = act.SendKey({ key = "w", mods = "CTRL" }) },

  -- Explicit, so copy/paste can't drift if the mouse bindings below change.
  { key = "c", mods = "CMD", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },

  -- Panes. The defaults are Ctrl+Shift+Opt+' and Ctrl+Shift+Opt+5, which nobody
  -- builds muscle memory for, and there is no default binding for closing a
  -- single pane at all - Cmd+W closes the whole tab and every pane in it.
  { key = "d", mods = "CMD",       action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) }, -- pane to the right
  { key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },   -- pane below
  { key = "w", mods = "CMD|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },

  -- Pane focus. Ctrl+Shift+Arrow still works (it's a default), but the Cmd+Opt
  -- chord is reachable one-handed. Plain Cmd+Arrow is taken by line motion above.
  { key = "LeftArrow",  mods = "CMD|ALT", action = act.ActivatePaneDirection("Left") },
  { key = "RightArrow", mods = "CMD|ALT", action = act.ActivatePaneDirection("Right") },
  { key = "UpArrow",    mods = "CMD|ALT", action = act.ActivatePaneDirection("Up") },
  { key = "DownArrow",  mods = "CMD|ALT", action = act.ActivatePaneDirection("Down") },
  { key = "[", mods = "CMD", action = act.ActivatePaneDirection("Prev") },
  { key = "]", mods = "CMD", action = act.ActivatePaneDirection("Next") },

  -- Pane resize (Cmd+Ctrl+arrows).
  { key = "LeftArrow",  mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Left", 3 }) },
  { key = "RightArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Right", 3 }) },
  { key = "UpArrow",    mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Up", 3 }) },
  { key = "DownArrow",  mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Down", 3 }) },

  -- Zoom / clear / copy-mode / palette.
  { key = "Enter", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
  { key = "k", mods = "CMD",       action = act.ClearScrollback("ScrollbackAndViewport") },
  { key = "x", mods = "CMD|SHIFT", action = act.ActivateCopyMode },
  { key = "p", mods = "CMD|SHIFT", action = act.ActivateCommandPalette },
}

-- ── Mouse: selecting text must NOT put it on the clipboard ───────────────────
-- Cmd+C does that explicitly.
--
-- There is no "copy nowhere" destination, so every mouse-up that would complete
-- a selection is bound to Nop. The selection itself is made on Down/Drag, not
-- Up, so text still highlights normally and Cmd+C still copies it.
--
-- Do NOT use CompleteSelection("PrimarySelection") here hoping it lands
-- somewhere harmless. On macOS there is no separate primary selection - it
-- resolves to the same system pasteboard as "Clipboard", so it clobbers Cmd+V
-- exactly like the default does. This was the bug.
--
-- Every Up variant has to be listed. Any one left out silently keeps the
-- default, which copies - Shift+click and Alt+click are the easy ones to miss.
-- The modified variants matter more than they look: a fullscreen TUI (Claude
-- Code, nvim) grabs mouse reporting, so selecting inside one means Shift+drag.
-- Verify with: wezterm show-keys | grep 'Up {'  (nothing may say Complete*)
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = "Left" } }, mods = "NONE",      action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "SHIFT",     action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "ALT",       action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "SHIFT|ALT", action = act.Nop },
  { event = { Up = { streak = 2, button = "Left" } }, mods = "NONE",      action = act.Nop }, -- word
  { event = { Up = { streak = 2, button = "Left" } }, mods = "SHIFT",     action = act.Nop },
  { event = { Up = { streak = 3, button = "Left" } }, mods = "NONE",      action = act.Nop }, -- line
  { event = { Up = { streak = 3, button = "Left" } }, mods = "SHIFT",     action = act.Nop },

  -- Plain click used to open links, via the same action that did the copying.
  -- Cmd+click takes that over, which matches the rest of macOS anyway.
  { event = { Up = { streak = 1, button = "Left" } }, mods = "CMD", action = act.OpenLinkAtMouseCursor },
}

-- Dim unfocused windows so the focused one is obvious at a glance.
local UNFOCUSED_FOREGROUND_TEXT_HSB = { hue = 1.0, saturation = 0.25, brightness = 0.45 }
local UNFOCUSED_WINDOW_BACKGROUND_OPACITY = 0.62

-- get_config_overrides() hands back a copy, so the current value is never the
-- same table we last stored; compare the fields instead of the identity.
local function same_text_hsb(actual, expected)
  if actual == nil or expected == nil then
    return actual == expected
  end
  return actual.hue == expected.hue
    and actual.saturation == expected.saturation
    and actual.brightness == expected.brightness
end

wezterm.on("window-focus-changed", function(window)
  local overrides = window:get_config_overrides() or {}
  local text_hsb, opacity
  if not window:is_focused() then
    text_hsb = UNFOCUSED_FOREGROUND_TEXT_HSB
    opacity = UNFOCUSED_WINDOW_BACKGROUND_OPACITY
  end

  -- Only write when one of the two values we own actually changes; a redundant
  -- set_config_overrides() call would trigger another config reload.
  if same_text_hsb(overrides.foreground_text_hsb, text_hsb) and overrides.window_background_opacity == opacity then
    return
  end

  overrides.foreground_text_hsb = text_hsb
  overrides.window_background_opacity = opacity
  window:set_config_overrides(overrides)
end)

-- ═════════════════════════════════════════════════════════════════════════════
-- Meta-only. Everything below is inert on a personal Mac.
-- ═════════════════════════════════════════════════════════════════════════════
if is_meta then
  -- Rendering: Metal on Apple Silicon. Switch front_end to 'OpenGL' if you ever
  -- see artifacts.
  config.front_end = "WebGpu"
  config.webgpu_power_preference = "HighPerformance"
  config.max_fps = 120
  config.scrollback_lines = 20000

  -- Jump between shell prompts. Needs OSC 133, which
  -- ~/.config/wezterm/wezterm.sh provides on the remote shell.
  table.insert(config.keys, { key = "UpArrow",   mods = "CMD|SHIFT", action = act.ScrollToPrompt(-1) })
  table.insert(config.keys, { key = "DownArrow", mods = "CMD|SHIFT", action = act.ScrollToPrompt(1) })

  -- Make T/D/P numbers clickable, and quick-selectable with Ctrl+Shift+Space.
  config.hyperlink_rules = wezterm.default_hyperlink_rules()
  table.insert(config.hyperlink_rules, {
    -- T1234567 (tasks), D12345678 (diffs), P123456789 (pastes) -> fburl resolver
    regex = [[\b([tTdDpP]\d+)\b]],
    format = "https://fburl.com/$1",
  })
  config.quick_select_patterns = { [[\b[tTdDpP]\d+\b]] }

  -- ── Pane label: which devserver a pane is attached to ──────────────────────
  -- ~/.zshrc's `_herdr_dev` stamps the short host name (dev37748) into a
  -- PANE_LABEL user var (OSC 1337) before launching herdr, and clears it when
  -- herdr exits. A plain OSC 0/1/2 title can't carry this: the prompt rewrites
  -- the title on every command and herdr rewrites it again from the remote
  -- side, so the host name survives seconds at best. User vars are sticky pane
  -- state nothing else touches, which is exactly what a "what am I connected
  -- to" label needs. Both title formatters below prefer it.
  local function pane_label(pane)
    local label = pane and pane.user_vars and pane.user_vars.PANE_LABEL
    if label and #label > 0 then
      return label
    end
    return nil
  end

  wezterm.on("format-tab-title", function(tab, _tabs, _panes, _cfg, _hover, _max_width)
    local title = tab.tab_title
    if not title or #title == 0 then
      title = pane_label(tab.active_pane) or tab.active_pane.title
    end
    return { { Text = string.format(" %d: %s ", tab.tab_index + 1, title) } }
  end)

  -- Window title: herdr pane label -> legacy Enkaku env -> the pane's own title.
  -- The old unconditional 'WezTerm' fallback made every window look identical,
  -- which is the whole problem when several devservers are open at once.
  wezterm.on("format-window-title", function(tab, _pane, tabs, _panes, _cfg)
    local title = pane_label(tab.active_pane)
    if not title then
      -- Legacy `ekdev*` flow: `ek c -W` spawns a WezTerm whose own process env
      -- carries the host it connected to (os.getenv reads the GUI process, so
      -- this only ever works for that Enkaku-spawned-window case).
      local host = os.getenv("ENKAKU_WEZTERM_HOSTNAME")
      local desc = os.getenv("ENKAKU_WEZTERM_DESCRIPTION")
      if host and #host > 0 then
        title = (desc and #desc > 0) and (host .. " - " .. desc) or host
      end
    end
    title = title or tab.active_pane.title
    if #tabs > 1 then
      title = string.format("%s  [%d/%d]", title, tab.tab_index + 1, #tabs)
    end
    return title
  end)
end

return config
