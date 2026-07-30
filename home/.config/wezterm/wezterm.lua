local wezterm = require("wezterm")
local act = wezterm.action

local config = wezterm.config_builder()

config.color_scheme = "rose-pine-moon"
config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 15.0
config.window_background_opacity = 0.8
config.macos_window_background_blur = 50
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Word and line motion.
-- Option+arrow  -> ESC-b / ESC-f   (zsh backward-word / forward-word)
-- Command+arrow -> Ctrl-A / Ctrl-E (beginning-of-line / end-of-line)
config.keys = {
  { key = "LeftArrow",  mods = "ALT", action = act.SendKey({ key = "b", mods = "ALT" }) },
  { key = "RightArrow", mods = "ALT", action = act.SendKey({ key = "f", mods = "ALT" }) },
  { key = "LeftArrow",  mods = "CMD", action = act.SendKey({ key = "a", mods = "CTRL" }) },
  { key = "RightArrow", mods = "CMD", action = act.SendKey({ key = "e", mods = "CTRL" }) },

  -- Explicit, so copy/paste can't drift if the mouse bindings below change.
  { key = "c", mods = "CMD", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CMD", action = act.PasteFrom("Clipboard") },
}

-- Selecting text must NOT put it on the clipboard - Cmd+C does that explicitly.
--
-- WezTerm's defaults for all three of these are
-- "ClipboardAndPrimarySelection", which is what makes a plain drag clobber the
-- clipboard. Switching to "PrimarySelection" still *completes* the selection, so
-- it stays highlighted and Cmd+C can copy it, but on macOS the primary selection
-- is not the system clipboard, so Cmd+V is untouched.
--
-- Keeping CompleteSelectionOrOpenLinkAtMouseCursor for the single click (rather
-- than Nop) preserves click-to-open-link.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor("PrimarySelection"),
  },
  { -- double click: word
    event = { Up = { streak = 2, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("PrimarySelection"),
  },
  { -- triple click: line
    event = { Up = { streak = 3, button = "Left" } },
    mods = "NONE",
    action = act.CompleteSelection("PrimarySelection"),
  },
}

return config
