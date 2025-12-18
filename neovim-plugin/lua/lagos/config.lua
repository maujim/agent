-- Configuration module for Lagos NeoVim plugin

local M = {}

-- Default settings
M.defaults = {
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

-- Validate configuration
function M.validate(config)
    local validated = vim.deepcopy(M.defaults)

    -- Validate chat window settings
    if config.chat_window then
        if config.chat_window.width then
            validated.chat_window.width = math.max(40, math.min(200, config.chat_window.width))
        end
        if config.chat_window.height then
            validated.chat_window.height = math.max(10, math.min(100, config.chat_window.height))
        end
        if config.chat_window.position then
            if vim.tbl_contains({"left", "right", "top", "bottom"}, config.chat_window.position) then
                validated.chat_window.position = config.chat_window.position
            end
        end
        if config.chat_window.border then
            if vim.tbl_contains({"single", "double", "rounded", "solid", "none"}, config.chat_window.border) then
                validated.chat_window.border = config.chat_window.border
            end
        end
    end

    -- Validate mappings
    if config.mappings then
        for key, mapping in pairs(config.mappings) do
            if validated.mappings[key] and type(mapping) == "string" then
                validated.mappings[key] = mapping
            end
        end
    end

    -- Validate other settings
    if config.model then
        validated.model = config.model
    end

    if config.api_key then
        validated.api_key = config.api_key
    end

    if type(config.auto_save_context) == "boolean" then
        validated.auto_save_context = config.auto_save_context
    end

    if type(config.include_file_context) == "boolean" then
        validated.include_file_context = config.include_file_context
    end

    if type(config.max_context_lines) == "number" then
        validated.max_context_lines = math.max(10, math.min(1000, config.max_context_lines))
    end

    return validated
end

return M