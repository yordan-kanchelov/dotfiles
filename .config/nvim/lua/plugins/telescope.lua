return {
  "nvim-telescope/telescope.nvim",
  opts = {
    pickers = {
      find_files = {
        hidden = true,
        -- no_ignore = false, -- to respect .gitignore
      },
    },
    -- Or, more broadly if using LazyVim utils:
    -- defaults = {
    --   file_ignore_patterns = {}, -- Clear default ignore patterns if needed
    --   mappings = {
    --     i = {
    --       ["<leader><leader>"] = function()
    --         require("telescope.builtin").find_files({ hidden = true })
    --       end,
    --     },
    --   },
    -- },
  },
  -- Example of overriding a specific LazyVim keymap for Telescope
  keys = {
    {
      "<leader><leader>", -- Or <leader>ff, etc.
      function()
        require("telescope.builtin").find_files({ hidden = true, no_ignore = false })
      end,
      desc = "Find Files (including hidden)",
    },
  },
}
