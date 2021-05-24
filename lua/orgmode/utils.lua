local uv = vim.loop
local utils = {}

---@param file string
---@param callback function
function utils.readfile(file, callback)
  uv.fs_open(file, 'r', 438, function(err1, fd)
    if err1 then return callback(err1) end
    uv.fs_fstat(fd, function(err2, stat)
    if err2 then return callback(err2) end
      uv.fs_read(fd, stat.size, 0, function(err3, data)
        if err3 then return callback(err3) end
        uv.fs_close(fd, function(err4)
          if err4 then return callback(err4) end
          local lines = vim.split(data, '\n')
          table.remove(lines, #lines)
          return callback(nil, lines)
        end)
      end)
    end)
  end)
end

function utils.writefile(file, content, flag, line)
  flag = flag or 'w'
  local mode = 438
  local fd = assert(uv.fs_open(file, flag, mode))
  assert(uv.fs_write(fd, content, line or -1))
  assert(uv.fs_close(fd))
end

local function sort_deadline(a, b)
  local both_has_time = not a.date_only and not b.date_only
  local both_missing_time = a.date_only and b.date_only
  if both_has_time or both_missing_time then
    return a:is_before(b)
  end
  if a.date_only and not b.date_only then
    return false
  end
  if not a.date_only and b.date_only then
    return true
  end
end

---TODO: Introduce priority
---@param dates table[]
---@return table[]
function utils.sort_dates(dates)
  table.sort(dates, function(first, second)
    local a = first.date
    local b = second.date
    if a:is_deadline() then
      if not b:is_deadline() then return true end
      return sort_deadline(a, b)
    end
    if b:is_deadline() then
      if not a:is_deadline() then return false end
      return sort_deadline(a, b)
    end

    if a:is_scheduled() then
      if not b:is_scheduled() then return true end
      return a:is_before(b)
    end
    if b:is_scheduled() then
      if not a:is_scheduled() then return false end
      return a:is_before(b)
    end

    return a:is_before(b)
  end)
  return dates
end

---@param msg string
function utils.echo_warning(msg)
  vim.cmd[[echohl WarningMsg]]
  vim.cmd(string.format('echom "%s"', msg))
  vim.cmd[[echohl None]]
end

---@param msg string
function utils.echo_info(msg)
  vim.cmd(string.format('echom "%s"', msg))
end

---@param word string
---@return string
function utils.capitalize(word)
  return (word:gsub('^%l', string.upper))
end

---@param isoweekday number
---@return number
function utils.convert_from_isoweekday(isoweekday)
  if isoweekday == 7 then return 1 end
  return isoweekday + 1
end

---@param weekday number
---@return number
function utils.convert_to_isoweekday(weekday)
  if weekday == 1 then return 7 end
  return weekday - 1
end

---@param tbl table
---@param callback function
---@param acc any
---@return table
function utils.reduce(tbl, callback, acc)
  for i, v in pairs(tbl) do
    acc = callback(acc, v, i)
  end
  return acc
end

--- Concat one table at the end of another table
---@param first table
---@param second table
---@return table
function utils.concat(first, second)
  for _, v in ipairs(second) do
    table.insert(first, v)
  end
  return first
end

function utils.menu(title, items, prompt)
  local content = { title }
  local valid_keys = {}
  for _, item in ipairs(items) do
    if item.separator then
      table.insert(content, vim.fn['repeat'](item.separator or '-', item.length or 80))
    else
      valid_keys[item.key] = item
      table.insert(content, string.format('%s %s', item.key, item.label))
    end
  end
  prompt = prompt or 'key'
  table.insert(content, prompt..': \n')
  vim.api.nvim_out_write(table.concat(content, '\n'))
  local char = vim.fn.nr2char(vim.fn.getchar())
  vim.cmd[[redraw!]]
  local entry = valid_keys[char]
  if not entry or not entry.action then return end
  return entry.action()
end

function utils.keymap(mode, lhs, rhs, opts)
  return vim.api.nvim_set_keymap(mode, lhs, rhs, vim.tbl_extend('keep', opts or {}, {
        nowait = true,
        silent = true,
        noremap = true,
    }))
end

function utils.buf_keymap(buf, mode, lhs, rhs, opts)
  return vim.api.nvim_buf_set_keymap(buf, mode, lhs, rhs, vim.tbl_extend('keep', opts or {}, {
        nowait = true,
        silent = true,
        noremap = true,
    }))
end

return utils
