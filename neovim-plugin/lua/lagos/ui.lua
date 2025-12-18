-- UI module for Lagos NeoVim plugin

local M = {}

-- Create a floating window for displaying content
function M.create_floating_window(content, title, opts)
    opts = opts or {}

    -- Prepare content with title
    local lines = {}
    if title then
        table.insert(lines, title)
        table.insert(lines, string.rep("─", #title))
    end

    -- Add content
    local content_lines = vim.split(content, "\n")
    for _, line in ipairs(content_lines) do
        table.insert(lines, line)
    end

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "readonly", true)

    -- Calculate window dimensions
    local width = opts.width or math.min(vim.opt.columns:get() - 10, 120)
    local height = opts.height or math.min(vim.opt.lines:get() - 10, #lines + 2)

    -- Calculate position
    local col = opts.col or math.floor((vim.opt.columns:get() - width) / 2)
    local row = opts.row or math.floor((vim.opt.lines:get() - height) / 2)

    -- Create window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = opts.border or "rounded",
        style = "minimal",
        title = opts.win_title or "",
        title_pos = opts.title_pos or "center",
    })

    -- Set up keymaps
    local keymaps = opts.keymaps or {
        ["<Esc>"] = "close",
        ["q"] = "close",
    }

    for key, action in pairs(keymaps) do
        if action == "close" then
            vim.keymap.set("n", key, function()
                vim.api.nvim_win_close(win, true)
            end, { buffer = buf, noremap = true, silent = true })
        end
    end

    return buf, win
end

-- Create or update chat window
function M.create_chat_window(config)
    -- Window dimensions
    local width = config.width or 80
    local height = config.height or 20
    local position = config.position or "right"

    -- Calculate position
    local col, row
    if position == "right" then
        col = vim.opt.columns:get() - width
        row = 0
    elseif position == "left" then
        col = 0
        row = 0
    elseif position == "bottom" then
        col = 0
        row = vim.opt.lines:get() - height - vim.opt.cmdheight:get() - 2
    else -- top
        col = 0
        row = 0
    end

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "lagos://chat")
    vim.api.nvim_buf_set_option(buf, "filetype", "lagos")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

    -- Create window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = config.border or "rounded",
        style = "minimal",
        title = " Lagos AI Assistant ",
        title_pos = "center",
    })

    -- Set initial content
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "Lagos AI Assistant",
        "─────────────────",
        "",
    })

    -- Set up syntax highlighting
    M._setup_chat_syntax(buf)

    return buf, win
end

-- Setup syntax highlighting for chat buffer
function M._setup_chat_syntax(buf)
    -- Define highlight groups if not already defined
    if vim.fn.hlID("LagosUserMessage") == 0 then
        vim.api.nvim_set_hl(0, "LagosUserMessage", {
            fg = "#5e81ac",
            bold = true,
        })
    end

    if vim.fn.hlID("LagosAIResponse") == 0 then
        vim.api.nvim_set_hl(0, "LagosAIResponse", {
            fg = "#ebcb8b",
            bold = true,
        })
    end

    if vim.fn.hlID("LagosToolCall") == 0 then
        vim.api.nvim_set_hl(0, "LagosToolCall", {
            fg = "#a3be8c",
            bold = true,
        })
    end

    -- Add syntax patterns
    vim.fn.buf_call(buf, function()
        -- User messages
        vim.fn.matchadd("LagosUserMessage", "^You:")
        -- AI responses
        vim.fn.matchadd("LagosAIResponse", "^Lagos:")
        -- Tool calls
        vim.fn.matchadd("LagosToolCall", "^tool:")
    end)
end

-- Add message to chat buffer
function M.add_chat_message(buf, role, message, opts)
    opts = opts or {}

    local lines = vim.split(message, "\n")

    -- Add role label
    local role_line = role == "user" and "You: " or "Lagos: "
    if opts.prefix then
        role_line = opts.prefix .. role_line
    end

    lines[1] = role_line .. lines[1]

    -- Add continuation markers for multi-line messages
    for i = 2, #lines do
        lines[i] = "    " .. lines[i]
    end

    -- Get buffer line count
    local line_count = vim.api.nvim_buf_line_count(buf)

    -- Make buffer modifiable
    vim.api.nvim_buf_set_option(buf, "modifiable", true)

    -- Add lines
    vim.api.nvim_buf_set_lines(buf, line_count - 1, -1, false, {
        "",
    })
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, lines)

    -- Make buffer readonly again
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    -- Scroll to bottom
    if opts.scroll ~= false then
        local win = vim.fn.bufwinid(buf)
        if win ~= -1 then
            vim.api.nvim_win_set_cursor(win, {vim.api.nvim_buf_line_count(buf), 0})
        end
    end
end

-- Show typing indicator
function M.show_typing_indicator(buf)
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
        "",
        "Lagos is thinking...",
    })
    vim.api.nvim_buf_set_option(buf, "modifiable", false)

    return line_count + 1
end

-- Remove typing indicator
function M.remove_typing_indicator(buf, line)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, line - 1, line + 1, false, {})
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

-- Create input prompt
function M.create_input_prompt(prompt, callback, opts)
    opts = opts or {}

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)

    -- Add prompt text
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {prompt})

    -- Create window
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = opts.width or 60,
        height = 1,
        col = math.floor((vim.opt.columns:get() - (opts.width or 60)) / 2),
        row = math.floor(vim.opt.lines:get() / 2),
        border = "rounded",
        style = "minimal",
    })

    -- Set buffer options
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_win_set_option(win, "wrap", false)

    -- Set up keymaps
    vim.keymap.set("i", "<CR>", function()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local input = lines[1]:sub(#prompt + 1) -- Remove prompt prefix
        vim.api.nvim_win_close(win, true)
        callback(input)
    end, { buffer = buf, noremap = true })

    vim.keymap.set("i", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, noremap = true })

    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, noremap = true })

    -- Enter insert mode
    vim.cmd("startinsert!")

    -- Position cursor
    vim.api.nvim_win_set_cursor(win, {1, #prompt})
end

return M