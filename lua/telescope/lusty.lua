-- Use home row keys to quickly pick telescope results in normal mode
-- Inspired  by the old lusty juggler vim plugin for switching
-- See https://github.com/vim-scripts/LustyJuggler/blob/master/plugin/lusty-juggler.vim

local Path = require('plenary.path')

local utils = require('telescope.utils')
local strings = require('plenary.strings')
local entry_display = require('telescope.pickers.entry_display')
local make_entry = require('telescope.make_entry')
local action_state = require('telescope.actions.state')
local action_set = require('telescope.actions.set')
local actions = require('telescope.actions')

local M = {}

-- minimal buffer entry maker
M.buffer_entry_maker = function()
  local icon_width = 0
  local icon, _ = utils.get_devicons("fname", false)
  icon_width = strings.strdisplaywidth(icon)

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 1 }, -- readonly/changed
      { width = icon_width },
      { remaining = true },
    },
  }

  local cwd = vim.fn.expand(vim.loop.cwd())

  local make_display = function(entry)
    local display_bufname = utils.transform_path({
      path_display = { 'tail' },
      -- readonly/changed + icon + 1 space
      __prefix = 1 + icon_width + 1
    }, entry.filename)
    local icon, hl_group = utils.get_devicons(entry.filename, false)

    return displayer {
      { entry.indicator, 'TelescopeResultsComment' },
      { icon, hl_group },
      display_bufname
    }
  end

  return function(entry)
    local bufname = entry.info.name ~= '' and entry.info.name or '[No Name]'
    -- if bufname is inside the cwd, trim that part of the string
    bufname = Path:new(bufname):normalize(cwd)

    -- CHANGED: removed all the flags/modes except readonly & changed which are now exclusive
    local readonly = vim.api.nvim_buf_get_option(entry.bufnr, 'readonly')
    local changed = entry.info.changed == 1
    local indicator = readonly and '=' or changed and '+' or ' '
    local lnum = 1

    -- account for potentially stale lnum as getbufinfo might not be updated or from resuming buffers picker
    if entry.info.lnum ~= 0 then
      -- but make sure the buffer is loaded, otherwise line_count is 0
      if vim.api.nvim_buf_is_loaded(entry.bufnr) then
        local line_count = vim.api.nvim_buf_line_count(entry.bufnr)
        lnum = math.max(math.min(entry.info.lnum, line_count), 1)
      else
        lnum = entry.info.lnum
      end
    end

    return make_entry.set_default_entry_mt({
      value = bufname,
      ordinal = bufname, -- CHANGED: removed bufnr
      display = make_display,

      bufnr = entry.bufnr,
      filename = bufname,
      lnum = lnum,
      indicator = indicator,
    }, {})
  end
end

local last_quick_jump = -1
local quick_jump = function(index)
  return function(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)

    local max_index = picker.manager:num_results() - 1
    local target = math.min(index, max_index)

    if target == picker:get_selection_row() and last_quick_jump == index then
      action_set.select(prompt_bufnr, 'default')
      last_quick_jump = -1
    else
      picker:set_selection(target)
      last_quick_jump = index
    end
  end
end

-- can be passed to attach_mappings to enable home row key based jumps
M.attach_quick_jump_letter_mappings = function(prompt_bufnr, map)
  map('n', 'a', quick_jump(0))
  map('n', 's', quick_jump(1))
  map('n', 'd', quick_jump(2))
  map('n', 'f', quick_jump(3))
  map('n', 'g', quick_jump(4))
  map('n', 'h', quick_jump(5))
  map('n', 'j', quick_jump(6))
  map('n', 'k', quick_jump(7))
  map('n', 'l', quick_jump(8))
  map('n', ';', quick_jump(9))
  map('n', '\'', quick_jump(10))

  -- j/k are used for quick jump, so you can use Ctrl-j/k for moving up/down instead
  map('n', '<C-j>', actions.move_selection_next)
  map('n', '<C-k>', actions.move_selection_previous)
  -- alternatively Ctrl-p/n can be used
  map('n', '<C-n>', actions.move_selection_next)
  map('n', '<C-p>', actions.move_selection_previous)

  local original_timeoutlen = vim.o.timeoutlen
  vim.o.timeoutlen = 0
  vim.api.nvim_buf_attach(prompt_bufnr, false, {
    on_detach = function()
      vim.o.timeoutlen = original_timeoutlen
    end
  })
  return true
end

-- E.g. vim.keymap.set('n', '<leader>b', require('telescope.lusty').lusty, {})
M.lusty = function()
  require('telescope.builtin').buffers(
    require('telescope.themes').get_dropdown({
      sort_mru = true,
      ignore_current_buffer = true,
      initial_mode = 'normal',
      previewer = false,
      entry_maker = M.buffer_entry_maker(),
      attach_mappings = M.attach_quick_jump_letter_mappings,
    })
  )
end

return M
