{ pkgs, ... }: with pkgs.vimPlugins; [
  # Icons (required by many plugins)
  nvim-web-devicons

  # Code outline / navigation (aerial)
  {
    plugin = aerial-nvim;
    type = "lua";
    config = ''
      require("aerial").setup {
        backends = { "treesitter", "lsp", "markdown", "man" },
        layout = {
          max_width = { 40, 0.2 },
          width = nil,
          min_width = 10,
          default_direction = "prefer_right",
        },
        attach_mode = "global",
        show_guides = true,
        on_attach = function(bufnr)
          vim.keymap.set("n", "{", "<cmd>AerialPrev<cr>", { buffer = bufnr, desc = "Previous symbol" })
          vim.keymap.set("n", "}", "<cmd>AerialNext<cr>", { buffer = bufnr, desc = "Next symbol" })
        end,
      }
      vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<cr>", { desc = "Toggle Aerial" })
    '';
  }

  # Terminal
  {
    plugin = toggleterm-nvim;
    type = "lua";
    config = ''
      require("toggleterm").setup {
        size = function(term)
          if term.direction == "horizontal" then
            return 15
          elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
          end
        end,
        open_mapping = [[<C-\>]],
        hide_numbers = true,
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          winblend = 0,
        },
      }

      -- Custom terminals
      local Terminal = require("toggleterm.terminal").Terminal

      local lazygit = Terminal:new({ cmd = "lazygit", hidden = true })
      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end
      vim.keymap.set("n", "<leader>gg", "<cmd>lua _LAZYGIT_TOGGLE()<cr>", { desc = "Lazygit" })
      vim.api.nvim_create_user_command("LazyGit", function() _LAZYGIT_TOGGLE() end, { desc = "Open LazyGit" })

      -- Terminal keymaps
      vim.keymap.set("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Float terminal" })
      vim.keymap.set("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Horizontal terminal" })
      vim.keymap.set("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Vertical terminal" })

      -- Escape terminal mode
      vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
      vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Go to left window" })
      vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Go to lower window" })
      vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Go to upper window" })
      vim.keymap.set("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Go to right window" })
    '';
  }

  # Colorscheme
  {
    plugin = kanagawa-nvim;
    type = "lua";
    config = ''
      require("kanagawa").setup {
        theme = "dragon",
        background = {
          dark = "dragon",
          light = "lotus"
        },
      }
      vim.cmd("colorscheme kanagawa-dragon")
    '';
  }

  # Fuzzy finder
  {
    plugin = telescope-nvim;
    type = "lua";
    config = ''
      require("telescope").setup {
        defaults = {
          prompt_prefix = "   ",
          selection_caret = "  ",
          entry_prefix = "  ",
        },
      }
    '';
  }

  # Status line
  {
    plugin = lualine-nvim;
    type = "lua";
    config = ''
      require("lualine").setup {
        options = {
          theme = "kanagawa",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff", "diagnostics" },
          lualine_c = { "filename" },
          lualine_x = { "encoding", "fileformat", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    '';
  }

  # Buffer line (tabs)
  {
    plugin = bufferline-nvim;
    type = "lua";
    config = ''
      require("bufferline").setup {
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "slant",
          show_buffer_close_icons = true,
          show_close_icon = false,
          offsets = {
            {
              filetype = "NvimTree",
              text = "File Explorer",
              highlight = "Directory",
              separator = true,
            },
          },
        },
      }
    '';
  }

  # File explorer
  {
    plugin = nvim-tree-lua;
    type = "lua";
    config = ''
      require("nvim-tree").setup {
        view = {
          width = 30,
          side = "left",
        },
        renderer = {
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
      }
      vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "Toggle file explorer" })
    '';
  }

  # Git signs in gutter
  {
    plugin = gitsigns-nvim;
    type = "lua";
    config = ''
      require("gitsigns").setup {
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        current_line_blame = true,
        current_line_blame_opts = {
          delay = 500,
        },
      }
    '';
  }

  # Indent guides
  {
    plugin = indent-blankline-nvim;
    type = "lua";
    config = ''
      require("ibl").setup {
        indent = {
          char = "│",
        },
        scope = {
          enabled = true,
          show_start = true,
        },
      }
    '';
  }

  # Keybinding hints
  {
    plugin = which-key-nvim;
    type = "lua";
    config = ''
      require("which-key").setup {
        delay = 100,
      }
    '';
  }

  # Better UI for inputs and selects
  {
    plugin = dressing-nvim;
    type = "lua";
    config = ''
      require("dressing").setup {
        input = {
          enabled = true,
          default_prompt = "Input:",
          border = "rounded",
        },
        select = {
          enabled = true,
          backend = { "telescope", "builtin" },
        },
      }
    '';
  }

  # Notifications and command line UI
  nui-nvim
  nvim-notify
  {
    plugin = noice-nvim;
    type = "lua";
    config = ''
      require("noice").setup {
        lsp = {
          override = {
            ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
            ["vim.lsp.util.stylize_markdown"] = true,
            ["cmp.entry.get_documentation"] = true,
          },
        },
        presets = {
          bottom_search = true,
          command_palette = true,
          long_message_to_split = true,
          inc_rename = false,
          lsp_doc_border = true,
        },
        routes = {
          {
            filter = { event = "msg_show", min_height = 10 },
            view = "split",
          },
        },
      }

      -- Copy last message to clipboard
      vim.keymap.set("n", "<leader>ny", function()
        local messages = require("noice").api.status.message.get_hl()
        if messages then
          vim.fn.setreg("+", messages)
          vim.notify("Message copied to clipboard", vim.log.levels.INFO)
        end
      end, { desc = "Copy last message to clipboard" })

      -- Open Noice history in a buffer where you can yank
      vim.keymap.set("n", "<leader>nb", function()
        vim.cmd("Noice history")
        vim.defer_fn(function()
          vim.notify("Use 'y' to yank selected text", vim.log.levels.INFO)
        end, 100)
      end, { desc = "Noice history (buffer)" })
    '';
  }

  # Dashboard / start screen
  {
    plugin = alpha-nvim;
    type = "lua";
    config = ''
      local alpha = require("alpha")
      local dashboard = require("alpha.themes.dashboard")

      dashboard.section.header.val = {
        "                                                     ",
        "  ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗ ",
        "  ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║ ",
        "  ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║ ",
        "  ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║ ",
        "  ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║ ",
        "  ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝ ",
        "                                                     ",
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "  Find file", ":Telescope find_files<CR>"),
        dashboard.button("e", "  New file", ":ene <BAR> startinsert<CR>"),
        dashboard.button("r", "  Recent files", ":Telescope oldfiles<CR>"),
        dashboard.button("g", "  Find text", ":Telescope live_grep<CR>"),
        dashboard.button("c", "  Configuration", ":e ~/.config/nvim/init.lua<CR>"),
        dashboard.button("q", "  Quit", ":qa<CR>"),
      }

      dashboard.section.footer.val = "Happy Coding! 🚀"

      alpha.setup(dashboard.config)
    '';
  }

  # Highlight color codes
  {
    plugin = nvim-colorizer-lua;
    type = "lua";
    config = ''
      require("colorizer").setup {
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          names = false,
          css = true,
          tailwind = true,
        },
      }
    '';
  }
]
