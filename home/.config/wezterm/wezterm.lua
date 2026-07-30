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
}

-- Selecting text must NOT put it on the clipboard - Cmd+C does that explicitly.
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
-- Verify with: wezterm show-keys | grep 'Up {'  (nothing may say Complete*)
config.mouse_bindings = {
  { event = { Up = { streak = 1, button = "Left" } }, mods = "NONE",      action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "SHIFT",     action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "ALT",       action = act.Nop },
  { event = { Up = { streak = 1, button = "Left" } }, mods = "SHIFT|ALT", action = act.Nop },
  { event = { Up = { streak = 2, button = "Left" } }, mods = "NONE",      action = act.Nop }, -- word
  { event = { Up = { streak = 3, button = "Left" } }, mods = "NONE",      action = act.Nop }, -- line

  -- Plain click used to open links, via the same action that did the copying.
  -- Cmd+click takes that over, which matches the rest of macOS anyway.
  { event = { Up = { streak = 1, button = "Left" } }, mods = "CMD", action = act.OpenLinkAtMouseCursor },
}

return config
