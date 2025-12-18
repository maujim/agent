-- NeoVim config for Lagos
-- Add this to your ~/.config/nvim/init.lua

-- 1. Add the plugin to your runtime path
vim.opt.runtimepath:append("/Users/mukund/conductor/workspaces/agent/lagos/neovim-plugin")

-- 2. Configure Lagos
require('lagos').setup({
    -- You MUST set your API key
    api_key = os.getenv("GOOGLE_AI_API_KEY"),

    -- If you haven't set the environment variable, you can set it directly:
    -- api_key = "your-actual-google-ai-api-key-here",

    -- Optional settings
    model = "gemini-2.5-flash",

    chat_window = {
        width = 80,
        height = 20,
        position = "right",
        border = "rounded",
    },

    -- Key mappings
    mappings = {
        ask = "<leader>la",     -- Ask a question
        chat = "<leader>lc",     -- Open chat window
        explain = "<leader>le",  -- Explain selected code
        fix = "<leader>lf",      -- Fix selected code
        refactor = "<leader>lr", -- Refactor selected code
        close = "<leader>lq",    -- Close chat window
    },
})

-- 3. Set up your Google AI API key
-- Run this in your terminal once:
-- echo "export GOOGLE_AI_API_KEY=\"your-api-key-here\"" >> ~/.zshrc
-- source ~/.zshrc