" Lagos NeoVim Plugin
" AI-powered coding assistant using Google's Gemini AI

" Only load once
if exists('g:loaded_lagos') || &compatible
    finish
endif
let g:loaded_lagos = 1

" Default configuration
if !exists('g:lagos_config')
    let g:lagos_config = {}
endif

" Lua-side initialization
lua require('lagos').setup(vim.g.lagos_config)