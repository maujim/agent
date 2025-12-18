# Lagos - AI Assistant for NeoVim

Lagos is an AI-powered coding assistant for NeoVim that leverages Google's Gemini AI to help you write, debug, and understand code more efficiently.

## Features

- **Interactive Chat**: Open a dedicated chat window to converse with the AI
- **Code Explanation**: Select any code and get instant explanations
- **Code Fixes**: Automatically identify and fix bugs in your code
- **Code Refactoring**: Get intelligent refactoring suggestions
- **Context-Aware**: The AI automatically understands your current file and project structure
- **File System Integration**: Read files and explore your project with AI assistance

## Installation

### Prerequisites

1. **Python 3.10+** installed on your system
2. **Google AI API Key**:
   - Get your key from [Google AI Studio](https://aistudio.google.com/app/apikey)
   - Set it as an environment variable: `export GOOGLE_AI_API_KEY="your-api-key-here"`

### Using packer.nvim

```lua
use {
    'your-username/lagos-neovim',
    config = function()
        require('lagos').setup({
            -- Your configuration options
        })
    end
}
```

### Using vim-plug

```vim
Plug 'your-username/lagos-neovim'
lua require('lagos').setup()
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/lagos-neovim.git ~/.config/nvim/pack/plugins/start/lagos-neovim
```

2. Install Python dependencies:
```bash
pip install -r neovim-plugin/python/requirements.txt
```

## Configuration

### Default Configuration

```lua
require('lagos').setup({
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
})
```

### Customizing Highlights

You can customize the highlight groups in your NeoVim config:

```lua
-- Custom colors for Lagos
vim.api.nvim_set_hl(0, "LagosUserMessage", {
    fg = "#61afef",  -- Blue
    bold = true,
})

vim.api.nvim_set_hl(0, "LagosAIResponse", {
    fg = "#98c379",  -- Green
    bold = true,
})

vim.api.nvim_set_hl(0, "LagosToolCall", {
    fg = "#e5c07b",  -- Yellow
    bold = true,
})
```

## Usage

### Chat Window

Open the chat window with:
- `<leader>lc` or `:LagosChat`

In the chat window:
- Type your message and press Enter to send
- `<leader>lq` or `<Esc>` to close the window

### Quick Actions

- **Ask a question**: `<leader>la` or `:LagosAsk <question>`
- **Explain code**: Select code, then `<leader>le` or `:LagosExplain`
- **Fix code**: Select code, then `<leader>lf` or `:LagosFix`
- **Refactor code**: Select code, then `<leader>lr` or `:LagosRefactor`

### Examples

#### 1. Explaining Code

```python
# Select this code and press <leader>le
def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n-1) + fibonacci(n-2)
```

The AI will explain:
- What the function does
- Its time and space complexity
- Potential improvements

#### 2. Fixing Code

```python
# Select this buggy code and press <leader>lf
def sum_list(lst):
    total = 0
    for i in range(len(lst) + 1):  # Bug: should be len(lst)
        total += lst[i]
    return total
```

The AI will:
- Identify the bug (IndexError)
- Explain the issue
- Provide the corrected code

#### 3. Refactoring Code

```python
# Select this code and press <leader>lr
# Then type: "make it more Pythonic"
def calculate_price(items):
    total = 0
    for item in items:
        total = total + item['price']
    return total
```

The AI will suggest:
```python
def calculate_price(items):
    return sum(item['price'] for item in items)
```

## Commands

- `:LagosChat` - Open the chat window
- `:LagosAsk [question]` - Ask a question without opening chat
- `:LagosExplain` - Explain selected code
- `:LagosFix` - Fix selected code
- `:LagosRefactor` - Refactor selected code

## File System Integration

Lagos can read and analyze your project files:

```
You: What does the main.py file do?
Lagos: [reads main.py] The main.py file initializes a Flask web server...
```

## Troubleshooting

### RPC Server Not Starting

If you see "Failed to start Lagos RPC server":
1. Ensure Python 3 is installed: `python3 --version`
2. Check that dependencies are installed:
   ```bash
   pip install dspy-ai google-genai python-dotenv rich
   ```
3. Verify your API key is set correctly

### No Response from AI

1. Check your internet connection
2. Verify your Google AI API key is valid
3. Check if you've exceeded API quota

### Performance Issues

- Reduce `max_context_lines` in config to limit context sent to AI
- Consider using a faster model like "gemini-2.0-flash"

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Related Projects

- [Lagos CLI](../) - The original command-line version of Lagos
- [Copilot](https://github.com/features/copilot) - GitHub's AI pair programmer
- [Tabnine](https://www.tabnine.com/) - AI code completion tool