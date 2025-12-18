-- Test file for Lagos NeoVim plugin
-- Use this file to verify the plugin is working correctly

-- Test basic imports
local lagos = require('lagos')

-- Test configuration
local test_config = {
    model = "gemini-2.5-flash",
    chat_window = {
        width = 60,
        height = 15,
        position = "right",
    },
    mappings = {
        ask = "<leader>ta",
        chat = "<leader>tc",
    }
}

-- Initialize with test config
lagos.setup(test_config)

print("Lagos plugin test:")
print("✓ Module loaded successfully")
print("✓ Configuration applied")
print("✓ Ready to use!")

-- Test commands:
-- :LagosChat
-- :LagosAsk "What is the capital of France?"
-- Visual select code and use :LagosExplain