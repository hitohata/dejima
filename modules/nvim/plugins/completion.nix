{ pkgs, ... }: with pkgs.vimPlugins; [
  cmp-nvim-lsp
  cmp-buffer
  cmp-path
  luasnip
  cmp_luasnip

  # GitHub Copilot
  {
    plugin = copilot-lua;
    type = "lua";
    config = ''
      require("copilot").setup {
        panel = {
          enabled = true,
          auto_refresh = true,
          keymap = {
            open = "<M-CR>",
          },
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<M-l>",
            accept_word = "<M-k>",
            accept_line = "<M-j>",
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<C-]>",
          },
        },
        filetypes = {
          yaml = true,
          markdown = true,
          gitcommit = true,
          gitrebase = true,
        },
      }
    '';
  }

  {
    plugin = nvim-cmp;
    type = "lua";
    config = ''
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
          { name = "path" },
        }),
      })
    '';
  }
]
