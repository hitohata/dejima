{ pkgs, ... }: with pkgs.vimPlugins; [
  {
    plugin = rustaceanvim;
    type = "lua";
    config = ''
      vim.g.rustaceanvim = {
        server = {
          on_attach = _G.lsp_on_attach,
          capabilities = _G.lsp_capabilities,
        },
      }
    '';
  }

  # Markdown rendering
  {
    plugin = render-markdown-nvim;
    type = "lua";
    config = ''
      require("render-markdown").setup {
        file_types = { "markdown" },
        render_modes = { "n", "c" },
      }
      vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", { desc = "Toggle markdown render" })
    '';
  }

  # Zen mode for focused writing
  {
    plugin = zen-mode-nvim;
    type = "lua";
    config = ''
      require("zen-mode").setup {
        window = {
          backdrop = 0.85,
          options = {
            number = false,
            relativenumber = false,
          },
        },
      }
      vim.keymap.set("n", "<leader>z", "<cmd>ZenMode<cr>", { desc = "Toggle zen mode" })
    '';
  }

  # Markdown preview in browser
  {
    plugin = markdown-preview-nvim;
    type = "lua";
    config = ''
      vim.g.mkdp_auto_close = 0
      vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { desc = "Markdown preview" })
      vim.keymap.set("n", "<leader>ms", "<cmd>MarkdownPreviewStop<cr>", { desc = "Stop markdown preview" })
    '';
  }
]
