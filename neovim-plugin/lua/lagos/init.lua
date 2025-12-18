-- Main entry point for the Lagos NeoVim plugin

local M = {}

-- Default configuration
M.config = {
    -- AI Model settings
    model = "gemini-2.5-flash",
    api_key = os.getenv("GOOGLE_AI_API_KEY"),

    -- UI settings
    chat_window = {
        width = 80,
        height = 20,
        position = "right", -- left, right, bottom, top
        border = "rounded",
    },

    -- Behavior settings
    auto_save_context = true,
    include_file_context = true,
    max_context_lines = 100,

    -- Key mappings
    mappings = {
        ask = "<leader>la",
        chat = "<leader>lc",
        explain = "<leader>le",
        fix = "<leader>lf",
        refactor = "<leader>lr",
        close = "<leader>lq",
    },

    -- Highlight groups
    highlights = {
        user_message = "LagosUserMessage",
        ai_response = "LagosAIResponse",
        tool_call = "LagosToolCall",
    }
}

-- Internal state
M.state = {
    rpc_job_id = nil,
    chat_buf = nil,
    chat_win = nil,
    history = {},
    current_context = {
        buffer = nil,
        selection = nil,
    }
}

-- Initialize the plugin
function M.setup(user_config)
    -- Merge user config
    M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

    -- Set up highlights
    M._setup_highlights()

    -- Set up autocommands
    M._setup_autocommands()

    -- Set up user commands
    M._setup_commands()

    -- Set up key mappings
    M._setup_mappings()

    -- Start the RPC server
    M._start_rpc_server()

    print("Lagos AI assistant initialized")
end

-- Set up highlight groups
function M._setup_highlights()
    vim.api.nvim_set_hl(0, M.config.highlights.user_message, {
        fg = "#5e81ac",
        bold = true,
    })

    vim.api.nvim_set_hl(0, M.config.highlights.ai_response, {
        fg = "#ebcb8b",
        bold = true,
    })

    vim.api.nvim_set_hl(0, M.config.highlights.tool_call, {
        fg = "#a3be8c",
        bold = true,
    })
end

-- Set up autocommands
function M._setup_autocommands()
    local group = vim.api.nvim_create_augroup("Lagos", { clear = true })

    -- Auto-save context on cursor move
    if M.config.auto_save_context then
        vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            group = group,
            callback = function()
                M._update_context()
            end,
        })
    end

    -- Clean up on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            M._cleanup()
        end,
    })
end

-- Set up user commands
function M._setup_commands()
    vim.api.nvim_create_user_command("LagosChat", function()
        M.open_chat()
    end, { desc = "Open Lagos AI chat window" })

    vim.api.nvim_create_user_command("LagosAsk", function(opts)
        local question = opts.args or ""
        if question == "" then
            question = vim.fn.input("Ask Lagos: ")
        end
        M.ask(question)
    end, {
        desc = "Ask Lagos AI a question",
        nargs = "*",
        range = true,
        complete = "file",
    })

    vim.api.nvim_create_user_command("LagosExplain", function(opts)
        M.explain_visual()
    end, {
        desc = "Explain selected code with Lagos AI",
        range = true,
    })

    vim.api.nvim_create_user_command("LagosFix", function(opts)
        M.fix_visual()
    end, {
        desc = "Fix selected code with Lagos AI",
        range = true,
    })

    vim.api.nvim_create_user_command("LagosRefactor", function(opts)
        local instruction = vim.fn.input("Refactor instruction: ")
        M.refactor_visual(instruction)
    end, {
        desc = "Refactor selected code with Lagos AI",
        range = true,
    })
end

-- Set up key mappings
function M._setup_mappings()
    local opts = { noremap = true, silent = true }

    -- Normal mode mappings
    vim.keymap.set("n", M.config.mappings.ask, function()
        M.ask()
    end, opts)

    vim.keymap.set("n", M.config.mappings.chat, M.open_chat, opts)

    -- Visual mode mappings
    vim.keymap.set("v", M.config.mappings.explain, M.explain_visual, opts)
    vim.keymap.set("v", M.config.mappings.fix, M.fix_visual, opts)
    vim.keymap.set("v", M.config.mappings.refactor, function()
        local instruction = vim.fn.input("Refactor instruction: ")
        M.refactor_visual(instruction)
    end, opts)
end

-- Start the RPC server
function M._start_rpc_server()
    local python_path = vim.fn.exepath("python3")
    if python_path == "" then
        error("Python 3 not found. Please install Python 3.")
    end

    local script_path = vim.fn.stdpath("config") .. "/plugins/lagos/python/lagos_rpc_server.py"
    if not vim.fn.filereadable(script_path) then
        -- Try relative path from plugin
        script_path = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h") .. "/python/lagos_rpc_server.py"
    end

    local cmd = { python_path, script_path, "--project-root", vim.fn.getcwd() }

    M.state.rpc_job_id = vim.fn.jobstart(cmd, {
        rpc = true,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.notify("Lagos RPC error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
            end
        end,
        on_exit = function()
            M.state.rpc_job_id = nil
        end,
    })

    if M.state.rpc_job_id == 0 then
        error("Failed to start Lagos RPC server")
    end
end

-- Make an RPC request
function M._rpc_request(method, params, callback)
    if not M.state.rpc_job_id then
        error("RPC server not running")
    end

    local request = {
        method = method,
        params = params,
    }

    if callback then
        vim.fn.rpcnotify(M.state.rpc_job_id, method, params)
    else
        local response = vim.fn.rpcrequest(M.state.rpc_job_id, method, params)
        return response
    end
end

-- Update current context
function M._update_context()
    local buf = vim.api.nvim_get_current_buf()
    local buf_info = {
        number = buf,
        name = vim.fn.bufname(buf),
        filetype = vim.bo.filetype,
        content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"),
    }

    -- Get visual selection if in visual mode
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    if start_pos[2] > 0 and start_pos[3] > 0 then
        local lines = vim.api.nvim_buf_get_lines(buf, start_pos[2] - 1, end_pos[2], false)
        local selection = table.concat(lines, "\n")
        if start_pos[2] == end_pos[2] then
            selection = selection:sub(start_pos[3], end_pos[3])
        else
            selection = selection:sub(start_pos[3]) .. "\n" .. selection:sub(1, end_pos[3])
        end
        buf_info.selection = selection
    end

    M.state.current_context.buffer = buf_info
    M._rpc_request("set_context", {
        buffer = buf_info,
        selection = buf_info.selection,
    })
end

-- Open chat window
function M.open_chat()
    if M.state.chat_win and vim.api.nvim_win_is_valid(M.state.chat_win) then
        -- Focus existing chat window
        vim.api.nvim_set_current_win(M.state.chat_win)
        return
    end

    -- Calculate window position
    local width = M.config.chat_window.width
    local height = M.config.chat_window.height
    local col, row

    if M.config.chat_window.position == "right" then
        col = vim.opt.columns:get() - width
        row = 0
    elseif M.config.chat_window.position == "left" then
        col = 0
        row = 0
    elseif M.config.chat_window.position == "bottom" then
        col = 0
        row = vim.opt.lines:get() - height - vim.opt.cmdheight:get() - 2
    else -- top
        col = 0
        row = 0
    end

    -- Create buffer
    M.state.chat_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(M.state.chat_buf, "lagos://chat")
    vim.api.nvim_buf_set_option(M.state.chat_buf, "filetype", "lagos")

    -- Create window
    local config = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = M.config.chat_window.border,
        style = "minimal",
    }

    M.state.chat_win = vim.api.nvim_open_win(M.state.chat_buf, true, config)

    -- Set up chat buffer
    vim.api.nvim_buf_set_option(M.state.chat_buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(M.state.chat_buf, 0, -1, false, {
        "Lagos AI Assistant",
        "─────────────────",
        "",
    })

    -- Set up local keymaps for chat window
    vim.keymap.set("n", M.config.mappings.close, function()
        M.close_chat()
    end, { buffer = M.state.chat_buf, noremap = true, silent = true })

    vim.keymap.set("n", "<CR>", function()
        M._send_chat_message()
    end, { buffer = M.state.chat_buf, noremap = true, silent = true })

    vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
        buffer = M.state.chat_buf,
        callback = function()
            M.state.chat_win = nil
        end,
    })
end

-- Close chat window
function M.close_chat()
    if M.state.chat_win and vim.api.nvim_win_is_valid(M.state.chat_win) then
        vim.api.nvim_win_close(M.state.chat_win, true)
        M.state.chat_win = nil
    end
end

-- Send chat message
function M._send_chat_message()
    local lines = vim.api.nvim_buf_get_lines(M.state.chat_buf, 0, -1, false)

    -- Find the last prompt (line after "─────────────────")
    local prompt_start = 3
    for i = #lines, 1, -1 do
        if lines[i]:match("^%s*─+") then
            prompt_start = i + 1
            break
        end
    end

    local message_lines = {}
    for i = prompt_start, #lines do
        table.insert(message_lines, lines[i])
    end

    local message = table.concat(message_lines, "\n"):gsub("^%s+", "")
    if message == "" then
        return
    end

    -- Update context
    M._update_context()

    -- Add user message to buffer
    local line_count = vim.api.nvim_buf_line_count(M.state.chat_buf)
    vim.api.nvim_buf_set_lines(M.state.chat_buf, line_count - 1, -1, false, {
        "",
        "You: " .. message,
        "",
    })

    -- Show typing indicator
    local typing_line = vim.api.nvim_buf_line_count(M.state.chat_buf)
    vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line, -1, false, {
        "Lagos is thinking...",
    })

    vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line + 1, -1, false, {})
    vim.api.nvim_win_set_cursor(M.state.chat_win, { typing_line + 2, 0 })

    -- Send request
    vim.defer_fn(function()
        local response = M._rpc_request("chat", { message = message })
        if response and response.result then
            -- Remove typing indicator
            vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line - 1, typing_line + 1, false, {})

            -- Add AI response
            local ai_lines = vim.split(response.result.response, "\n")
            vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line - 1, typing_line - 1, false, {
                "Lagos: " .. ai_lines[1],
            })

            for i = 2, #ai_lines do
                vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line + i - 2, typing_line + i - 2, false, {
                    "    " .. ai_lines[i],
                })
            end

            -- Add separator for next message
            vim.api.nvim_buf_set_lines(M.state.chat_buf, typing_line + #ai_lines - 1, -1, false, {
                "",
                "─────────────────",
                "",
            })

            -- Move cursor to input line
            local new_line = vim.api.nvim_buf_line_count(M.state.chat_buf)
            vim.api.nvim_win_set_cursor(M.state.chat_win, { new_line, 0 })
        end
    end, 100)
end

-- Ask a question
function M.ask(question)
    if not question then
        question = vim.fn.input("Ask Lagos: ")
    end

    -- Update context
    M._update_context()

    -- Send request
    local response = M._rpc_request("ask", { message = question })
    if response and response.result then
        -- Display response in floating window
        M._show_response(response.result.response, "Question: " .. question)
    end
end

-- Explain selected code
function M.explain_visual()
    local selection = M._get_visual_selection()
    if not selection then
        vim.notify("No selection", vim.log.levels.WARN)
        return
    end

    local filetype = vim.bo.filetype
    local response = M._rpc_request("explain", {
        code = selection,
        language = filetype,
    })

    if response and response.result then
        M._show_response(response.result.response, "Code Explanation")
    end
end

-- Fix selected code
function M.fix_visual()
    local selection = M._get_visual_selection()
    if not selection then
        vim.notify("No selection", vim.log.levels.WARN)
        return
    end

    local filetype = vim.bo.filetype
    local response = M._rpc_request("fix", {
        code = selection,
        language = filetype,
    })

    if response and response.result then
        M._show_response(response.result.response, "Code Fix Suggestions")
    end
end

-- Refactor selected code
function M.refactor_visual(instruction)
    local selection = M._get_visual_selection()
    if not selection then
        vim.notify("No selection", vim.log.levels.WARN)
        return
    end

    local filetype = vim.bo.filetype
    local response = M._rpc_request("refactor", {
        code = selection,
        instruction = instruction,
        language = filetype,
    })

    if response and response.result then
        M._show_response(response.result.response, "Refactored Code")
    end
end

-- Get visual selection
function M._get_visual_selection()
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")

    if start_pos[2] == 0 or end_pos[2] == 0 then
        return nil
    end

    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    local selection = table.concat(lines, "\n")

    if start_pos[2] == end_pos[2] then
        selection = selection:sub(start_pos[3], end_pos[3])
    else
        selection = selection:sub(start_pos[3]) .. "\n" .. table.concat(vim.list_slice(lines, 2), "\n")
    end

    return selection
end

-- Show response in floating window
function M._show_response(response, title)
    local lines = vim.split(response, "\n")

    -- Add title
    vim.list_extend(lines, 1, { title, string.rep("─", #title) })

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "markdown")

    local width = math.min(vim.opt.columns:get() - 10, 120)
    local height = math.min(vim.opt.lines:get() - 10, #lines + 2)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.opt.columns:get() - width) / 2),
        row = math.floor((vim.opt.lines:get() - height) / 2),
        border = "rounded",
        style = "minimal",
    })

    -- Close on escape or q
    vim.keymap.set("n", "<Esc>", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, noremap = true, silent = true })

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, noremap = true, silent = true })
end

-- Clean up resources
function M._cleanup()
    if M.state.rpc_job_id then
        vim.fn.jobstop(M.state.rpc_job_id)
        M.state.rpc_job_id = nil
    end

    M.close_chat()
end

return M