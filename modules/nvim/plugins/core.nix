{ pkgs, ... }: with pkgs.vimPlugins; [
  nvim-treesitter.withAllGrammars
  {
    plugin = nvim-lspconfig;
    type = "lua";
    config = ''
      local on_attach = function(client, bufnr)
        local opts = { noremap = true, silent = true, buffer = bufnr }
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<C-i>", vim.lsp.buf.signature_help, { buffer = bufnr, desc = "Signature help" })
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
        vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format { async = true } end, opts)
      end

      -- Make on_attach global for other plugins
      _G.lsp_on_attach = on_attach

      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      _G.lsp_capabilities = capabilities

      -- LSP on_attach autocmd
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          on_attach(vim.lsp.get_client_by_id(args.data.client_id), args.buf)
        end,
      })

      -- Nix
      vim.lsp.config.nil_ls = {
        cmd = { "nil" },
        filetypes = { "nix" },
        root_markers = { "flake.nix", ".git" },
        settings = {
          ["nil"] = {
            formatting = {
              command = { "nixpkgs-fmt" },
            },
          },
        },
        capabilities = capabilities,
      }
      vim.lsp.enable("nil_ls")

      -- TypeScript
      vim.lsp.config.ts_ls = {
        cmd = { "typescript-language-server", "--stdio" },
        filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
        root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
        capabilities = capabilities,
      }
      vim.lsp.enable("ts_ls")

      -- Python
      vim.lsp.config.pyright = {
        cmd = { "pyright-langserver", "--stdio" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "setup.py", "requirements.txt", ".git" },
        capabilities = capabilities,
      }
      vim.lsp.enable("pyright")

      -- Lua
      vim.lsp.config.lua_ls = {
        cmd = { "lua-language-server" },
        filetypes = { "lua" },
        root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
        capabilities = capabilities,
      }
      vim.lsp.enable("lua_ls")

      -- CSpell
      vim.lsp.config.cspell = {
        cmd = { "cspell-lsp", "--stdio" },
        filetypes = { "markdown", "text", "gitcommit", "nix", "lua", "typescript", "javascript", "python" },
        root_markers = { ".git", "cspell.json", ".cspell.json" },
        capabilities = capabilities,
      }
      vim.lsp.enable("cspell")
    '';
  }
]
