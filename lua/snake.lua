local M = {}

local game = {
  running = false,
  buffer = nil,
  window = nil,
  width = 50,
  height = 22,
  snake = {},
  food = {},
  direction = { x = 1, y = 0 },
  score = 0,
  game_over = false,
  in_insert_mode = false,
  move_counter = 0,
  original_guicursor = nil
}

local function init_game()
  game.snake = {
    { x = 25, y = 10 },
    { x = 24, y = 10 },
    { x = 23, y = 10 }
  }
  game.direction = { x = 1, y = 0 }
  game.score = 0
  game.game_over = false
  game.in_insert_mode = false
  game.move_counter = 0
  spawn_food()
end

function spawn_food()
  local valid_position = false
  local attempts = 0
  
  while not valid_position and attempts < 100 do
    game.food = {
      x = math.random(1, game.width),
      y = math.random(1, game.height)
    }
    
    -- Check if food spawns on snake
    valid_position = true
    for _, segment in ipairs(game.snake) do
      if segment.x == game.food.x and segment.y == game.food.y then
        valid_position = false
        break
      end
    end
    attempts = attempts + 1
  end
end

local function is_snake_position(x, y)
  for _, segment in ipairs(game.snake) do
    if segment.x == x and segment.y == y then
      return true
    end
  end
  return false
end

local function hide_cursor()
  game.original_guicursor = vim.o.guicursor
  vim.o.guicursor = "a:Cursor/lCursor-blinkon0"
  vim.cmd("highlight Cursor blend=100")
end

local function restore_cursor()
  if game.original_guicursor then
    vim.o.guicursor = game.original_guicursor
  end
  vim.cmd("highlight Cursor blend=0")
end

local function render_game()
  if not game.buffer or not vim.api.nvim_buf_is_valid(game.buffer) then
    return
  end

  local lines = {}
  
  -- Render game grid
  for y = 1, game.height do
    local line = {}
    for x = 1, game.width do
      if x == game.food.x and y == game.food.y then
        table.insert(line, "*")
      elseif is_snake_position(x, y) then
        if game.snake[1].x == x and game.snake[1].y == y then
          table.insert(line, "@") -- head
        else
          table.insert(line, "o") -- body
        end
      else
        table.insert(line, " ")
      end
    end
    table.insert(lines, table.concat(line))
  end
  
  -- Separator line
  table.insert(lines, string.rep("─", game.width))
  
  -- Game info
  table.insert(lines, " Score: " .. game.score)
  table.insert(lines, "")
  table.insert(lines, " hjkl - Move snake (normal mode only)")
  table.insert(lines, " i    - Enter insert mode to eat food")
  table.insert(lines, " Esc  - Return to normal mode")
  table.insert(lines, " q    - Quit game")
  table.insert(lines, "")
  
  if game.in_insert_mode then
    table.insert(lines, " --INSERT--")
  else
    table.insert(lines, " --NORMAL--")
  end
  
  if game.game_over then
    table.insert(lines, " GAME OVER! Press r to restart or q to quit")
  end

  vim.api.nvim_buf_set_option(game.buffer, 'modifiable', true)
  vim.api.nvim_buf_set_lines(game.buffer, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(game.buffer, 'modifiable', false)
end

local function move_snake()
  if game.game_over then
    return
  end

  local head = game.snake[1]
  local new_head = {
    x = head.x + game.direction.x,
    y = head.y + game.direction.y
  }

  -- Wrap around edges
  if new_head.x < 1 then
    new_head.x = game.width
  elseif new_head.x > game.width then
    new_head.x = 1
  end

  if new_head.y < 1 then
    new_head.y = game.height
  elseif new_head.y > game.height then
    new_head.y = 1
  end

  -- Check self collision
  for _, segment in ipairs(game.snake) do
    if new_head.x == segment.x and new_head.y == segment.y then
      game.game_over = true
      return
    end
  end

  table.insert(game.snake, 1, new_head)

  -- Check food collision (only in insert mode)
  if new_head.x == game.food.x and new_head.y == game.food.y and game.in_insert_mode then
    game.score = game.score + 1
    spawn_food()
  else
    table.remove(game.snake)
  end
end

-- Prevent opposite direction moves
local function is_valid_direction_change(new_direction)
  local current_dir = game.direction
  
  if (current_dir.x == 1 and new_direction.x == -1) or
     (current_dir.x == -1 and new_direction.x == 1) or
     (current_dir.y == 1 and new_direction.y == -1) or
     (current_dir.y == -1 and new_direction.y == 1) then
    return false
  end
  
  return true
end

local function setup_keybindings()
  local opts = { buffer = game.buffer, silent = true }
  
  -- Movement keys (normal mode only)
  vim.keymap.set('n', 'h', function()
    if not game.in_insert_mode and not game.game_over then
      local new_dir = { x = -1, y = 0 }
      if is_valid_direction_change(new_dir) then
        game.direction = new_dir
      end
    end
  end, opts)
  
  vim.keymap.set('n', 'j', function()
    if not game.in_insert_mode and not game.game_over then
      local new_dir = { x = 0, y = 1 }
      if is_valid_direction_change(new_dir) then
        game.direction = new_dir
      end
    end
  end, opts)
  
  vim.keymap.set('n', 'k', function()
    if not game.in_insert_mode and not game.game_over then
      local new_dir = { x = 0, y = -1 }
      if is_valid_direction_change(new_dir) then
        game.direction = new_dir
      end
    end
  end, opts)
  
  vim.keymap.set('n', 'l', function()
    if not game.in_insert_mode and not game.game_over then
      local new_dir = { x = 1, y = 0 }
      if is_valid_direction_change(new_dir) then
        game.direction = new_dir
      end
    end
  end, opts)
  
  -- Mode switching
  vim.keymap.set('n', 'i', function()
    if not game.game_over then
      game.in_insert_mode = true
      render_game()
    end
  end, opts)
  
  vim.keymap.set('n', '<Esc>', function()
    if game.in_insert_mode then
      game.in_insert_mode = false
      render_game()
    end
  end, opts)
  
  -- Block problematic keys
  vim.keymap.set('n', '<CR>', '<Nop>', opts)
  vim.keymap.set('n', '<Enter>', '<Nop>', opts)
  
  -- Game controls
  vim.keymap.set('n', 'q', function()
    M.stop_game()
  end, opts)
  
  vim.keymap.set('n', 'r', function()
    if game.game_over then
      init_game()
      render_game()
    end
  end, opts)
  
  -- Disable insert mode keys
  local disabled_keys = {'a', 'A', 'o', 'O', 's', 'S', 'c', 'C'}
  for _, key in ipairs(disabled_keys) do
    vim.keymap.set('n', key, '<Nop>', opts)
  end
end

local function create_game_window()
  local screen_width = vim.o.columns
  local max_width = math.min(screen_width - 8, 80)
  game.width = math.max(40, max_width)
  
  game.buffer = vim.api.nvim_create_buf(false, true)
  
  -- Buffer options
  vim.api.nvim_buf_set_option(game.buffer, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(game.buffer, 'swapfile', false)
  vim.api.nvim_buf_set_option(game.buffer, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(game.buffer, 'modifiable', false)
  
  -- Window positioning
  local width = game.width
  local height = game.height + 18
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  game.window = vim.api.nvim_open_win(game.buffer, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = '',
    title_pos = 'center'
  })
  
  -- Window options
  vim.api.nvim_win_set_option(game.window, 'cursorline', false)
  vim.api.nvim_win_set_option(game.window, 'cursorcolumn', false)
  vim.api.nvim_win_set_option(game.window, 'number', false)
  vim.api.nvim_win_set_option(game.window, 'relativenumber', false)
  vim.api.nvim_win_set_option(game.window, 'signcolumn', 'no')
  
  hide_cursor()
end

local function game_loop()
  if not game.running then
    return
  end
  
  move_snake()
  render_game()
  
  if game.running then
    vim.defer_fn(game_loop, 180)
  end
end

function M.start_game()
  if game.running then
    return
  end
  
  math.randomseed(os.time())
  game.running = true
  
  create_game_window()
  setup_keybindings()
  init_game()
  render_game()
  
  game_loop()
end

function M.stop_game()
  game.running = false
  
  restore_cursor()
  
  if game.window and vim.api.nvim_win_is_valid(game.window) then
    vim.api.nvim_win_close(game.window, true)
  end
  
  game.window = nil
  game.buffer = nil
end

function M.setup()
  vim.api.nvim_create_user_command('Snake', function()
    M.start_game()
  end, {
    desc = 'Start the Snake Game for hjkl practice'
  })
end

return M
