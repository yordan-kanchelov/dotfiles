call plug#begin()

Plug 'tpope/vim-sensible'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'Luxed/ayu-vim' 
Plug 'neovim/nvim-lspconfig'  " LSP configuration plugin

call plug#end()

set guicursor=
set scrolloff=8
set number
set relativenumber
set tabstop=4 softtabstop=4
set shiftwidth=4
set expandtab
set smartindent

set termguicolors
let ayucolor="mirage"
colorscheme ayu

let mapleader = " "
nnoremap <leader>pv :Vex<CR>
nnoremap <leader><CR> :so ~/.config/nvim/init.vim<CR>
nnoremap <C-p> :GFiles<CR>
nnoremap <C-j> :cnext<CR>
nnoremap <C-k> :cprev<CR>
nnoremap <leader>pf :Files<CR>  

lua << EOF
local lspconfig = require('lspconfig')

-- TypeScript language server configuration (requires global npm packages)
-- Run `npm install -g typescript typescript-language-server`
lspconfig.ts_ls.setup {
    on_attach = function(client, bufnr)
        -- Key mappings for LSP
        local buf_map = function(bufnr, mode, lhs, rhs, opts)
            vim.api.nvim_buf_set_keymap(bufnr, mode, lhs, rhs, opts or { noremap = true, silent = true })
        end

        buf_map(bufnr, 'n', 'gd', '<Cmd>lua vim.lsp.buf.definition()<CR>')
        buf_map(bufnr, 'n', 'K', '<Cmd>lua vim.lsp.buf.hover()<CR>')
        buf_map(bufnr, 'n', 'gi', '<Cmd>lua vim.lsp.buf.implementation()<CR>')
        buf_map(bufnr, 'n', '<leader>rn', '<Cmd>lua vim.lsp.buf.rename()<CR>')
        buf_map(bufnr, 'n', '<leader>ca', '<Cmd>lua vim.lsp.buf.code_action()<CR>')
        buf_map(bufnr, 'n', 'gr', '<Cmd>lua vim.lsp.buf.references()<CR>')
    end
}

-- ESLint language server configuration (requires global npm packages)
-- Run `npm install -g eslint vscode-langservers-extracted`
lspconfig.eslint.setup {
    on_attach = function(client, bufnr)
        -- Additional configuration for ESLint, if needed
    end
}
EOF
