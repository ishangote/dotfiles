-- Shared Neovim core: the options and keymaps that are the same on every machine.
--
-- VENDORED IDENTICALLY in the personal dotfiles repo and the work chezmoi repo, at
-- the same relative path (lua/shared/core.lua). Keep the two byte-identical - a
-- plain diff between them is the drift check. Everything ELSE about the two configs
-- is deliberately different: LazyVim plus meta.nvim at work, nine hand-picked
-- plugins personally.
--
-- What belongs here: settings both sides already agreed on independently, i.e. the
-- muscle memory. What does NOT: anything one side's plugin framework already
-- provides (LazyVim sets number, expandtab, shiftwidth, ignorecase, smartcase,
-- undofile and mapleader itself, so declaring them here would be a silent override
-- rather than a shared default).
--
-- Split into two functions because the two sides apply them at different times:
-- LazyVim wants options before lazy.nvim starts and keymaps on VeryLazy.

local M = {}

function M.options()
  local o = vim.opt
  o.relativenumber = true      -- relative line numbers for fast jumps
  o.clipboard = "unnamedplus"  -- share the system clipboard (OSC 52 over SSH)
  o.scrolloff = 16             -- keep the cursor well away from the screen edge
end

function M.keymaps()
  -- Normal-mode <Esc> saves. Insert-mode <Esc> is untouched. Note this overrides
  -- <Esc>'s normal-mode role of cancelling a pending count or operator.
  vim.keymap.set("n", "<Esc>", ":w<CR>", { desc = "Save", silent = true })
  -- Ctrl-A selects the whole buffer. Shadows vim's default <C-a> (increment the
  -- number under the cursor).
  vim.keymap.set("n", "<C-a>", "ggVG", { desc = "Select All" })
  -- Pasting over a visual selection no longer clobbers the yank register.
  vim.cmd([[ xnoremap <expr> p 'pgv"'.v:register.'y' ]])
end

return M
