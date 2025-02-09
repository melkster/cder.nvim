-- Verify dependencies are installed
local has_telescope, telescope = pcall(require, 'telescope')

if not has_telescope then
  error(
    'cder requires telescope.nvim: https://github.com/nvim-telescope/telescope.nvim'
  )
end

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')

local opts = {
  -- The title of the prompt.
  prompt_title = 'cder',

  -- The command used to generate a list of directories.
  -- Defaults to fd on the home directory.
  -- Example for showing hidden directories:
  --   dir_command = { 'fd', '--hidden', '--type=d', '.', os.getenv('HOME') },
  dir_command = { 'fd', '--type=d', '.', os.getenv('HOME') },

  -- The binary used to execute previewer_command | pager_command.
  -- This is needed because termopen in Neovim does not support piping
  -- multiple commands, so we get around this by just using bash -c.
  command_executer = { 'bash', '-c' },

  -- The command used to preview directories. Defaults to ls.
  -- Example:
  --   previewer_command = 'exa -a --icons'
  previewer_command = 'ls -a',

  -- The command used to page directory previews. Defaults to bat.
  -- Receives the output of the previewer_command as input.
  -- Example without bat:
  --   pager_command = 'less -RS'
  pager_command = 'bat --plain --paging=always --pager="less -RS"',

  -- Function to create an entry in the picker given
  -- a line outputted from the dir_command.
  --   value is used as the directory in the :cd command
  --   display is what is actually displayed, so this can
  --     be a function that trims a path prefix for example.
  entry_maker = function(line)
    return {
      value = line,
      display = function(entry)
        return ' ' .. line:gsub(os.getenv('HOME') .. '/', ''),
          { { { 1, 3 }, 'Directory' } }
      end,
      ordinal = line,
    }
  end,
}

local function setup(o)
  o = o or {}
  opts = vim.tbl_deep_extend('force', opts, o)
end

local function run()
  pickers.new(opts, {
    prompt_title = opts.prompt_title,
    finder = finders.new_oneshot_job(opts.dir_command, opts),
    previewer = previewers.new_termopen_previewer({
      get_command = function(entry)
        return vim.tbl_flatten({
          opts.command_executer,
          opts.previewer_command
            .. ' '
            .. entry.value
            .. ' | '
            .. opts.pager_command,
        })
      end,
    }),
    sorter = sorters.get_fuzzy_file(),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)

        local directory = action_state.get_selected_entry()
        if directory ~= nil then
          vim.api.nvim_command('cd ' .. directory.value)
        end
      end)
      return true
    end,
  }):find()
end

return telescope.register_extension({
  setup = setup,
  exports = {
    cder = run,
  },
})
