local M = {}

-- --- Configuration ---
local config = {
    debug = false,
    handle_enter = true,
    wrap_internal_navigation = true,
    hide_cursor_on_enter = true,
    log_file = vim.fn.stdpath("cache") .. "/seamless_nav.log",
}

local OSC_PREFIX = "\27]8671;"
local ST = "\27\\"

-- --- State ---
local win_history = {} -- A simple list of winids in order of access

-- --- Helpers ---

local function log(msg)
    if not config.debug then
        return
    end
    local fd = io.open(config.log_file, "a")
    if fd then
        fd:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), msg))
        fd:close()
    end
end

local function send_osc(payload)
    io.stderr:write(OSC_PREFIX .. payload .. ST)
end

--- Ensures the cursor is visible after a redraw
local function restore_cursor()
    -- Using schedule ensures this happens after the current event loop
    -- processing (like window switching) is done.
    vim.schedule(function()
        -- Force a redraw to ensure we're synchronized
        vim.cmd("redraw")
        vim.defer_fn(function()
            io.stderr:write("\27[?25h")
        end, 20)
    end)
end

local function update_history()
    local curr_win = vim.api.nvim_get_current_win()
    -- Remove winid if it already exists in history to move it to the front
    for i, winid in ipairs(win_history) do
        if winid == curr_win then
            table.remove(win_history, i)
            break
        end
    end
    table.insert(win_history, curr_win)

    -- Clean up: remove invalid windows
    for i = #win_history, 1, -1 do
        if not vim.api.nvim_win_is_valid(win_history[i]) then
            table.remove(win_history, i)
        end
    end
end

local function get_tiled_boundaries()
    local wins = vim.api.nvim_tabpage_list_wins(0)
    local min_row, max_row = 9999, 0
    local min_col, max_col = 9999, 0

    for _, winid in ipairs(wins) do
        local config = vim.api.nvim_win_get_config(winid)
        if config.relative == "" then -- Only tiled windows
            local info = vim.fn.getwininfo(winid)[1]
            if info then
                min_row = math.min(min_row, info.winrow)
                max_row = math.max(max_row, info.winrow + info.height - 1)
                min_col = math.min(min_col, info.wincol)
                max_col = math.max(max_col, info.wincol + info.width - 1)
            end
        end
    end
    return min_row, max_row, min_col, max_col
end

-- --- Core Logic ---

--- Handles the 'enter' event by focusing the best matching window
local function handle_enter(metadata, direction)
    -- If we told the terminal we handle hiding (h=true),
    -- we must now reveal it.
    if config.hide_cursor_on_enter then
        restore_cursor()
    end

    local params = {}
    for pair in metadata:gmatch("[^:]+") do
        local k, v = pair:match("([^=]+)=(.+)")
        if k then
            params[k] = v
        end
    end

    local range_str = params.r
    if not range_str then
        return
    end

    local r_min, r_max = range_str:match("(%d+),(%d+)")
    r_min, r_max = tonumber(r_min), tonumber(r_max)
    if not r_min or not r_max then
        return
    end

    local min_r, max_r, min_c, max_c = get_tiled_boundaries()
    local target_edge_map = {
        up = "bottom",
        down = "top",
        left = "right",
        right = "left",
    }
    local entering_at = target_edge_map[direction]

    local candidates = {}
    local current_win = vim.api.nvim_get_current_win()
    local win_infos = vim.fn.getwininfo()

    for _, info in ipairs(win_infos) do
        if info.tabnr == vim.fn.tabpagenr() then
            local win_cfg = vim.api.nvim_win_get_config(info.winid)
            if win_cfg.relative == "" then
                local top = info.winrow
                local bottom = info.winrow + info.height - 1
                local left = info.wincol
                local right = info.wincol + info.width - 1

                -- 1. Use dynamic boundaries instead of hardcoded 1 or editor_h
                local on_edge = false
                if entering_at == "top" and top == min_r then
                    on_edge = true
                elseif entering_at == "bottom" and bottom == max_r then
                    on_edge = true
                elseif entering_at == "left" and left == min_c then
                    on_edge = true
                elseif entering_at == "right" and right == max_c then
                    on_edge = true
                end

                -- 2. Check intersection
                if on_edge then
                    local aligned = false
                    if direction == "up" or direction == "down" then
                        aligned = (left <= r_max and r_min <= right)
                    else
                        aligned = (top <= r_max and r_min <= bottom)
                    end

                    if aligned then
                        if info.winid == current_win then
                            return
                        end
                        candidates[info.winid] = true
                    end
                end
            end
        end
    end

    -- Pick the candidate that appears latest in our win_history stack
    for i = #win_history, 1, -1 do
        local winid = win_history[i]
        if candidates[winid] then
            vim.api.nvim_set_current_win(winid)
            update_history()

            return
        end
    end

    -- If our cache is incomplete just pick the first one.
    for winid in pairs(candidates) do
        vim.api.nvim_set_current_win(winid)
        update_history()
    end
end

-- --- Core Logic: Navigation ---

local function handle_navigate(metadata, direction)
    local params = {}
    for pair in metadata:gmatch("[^:]+") do
        local k, v = pair:match("([^=]+)=(.+)")
        if k then
            params[k] = v
        end
    end

    local id = params.id or "0"
    local wrap = params.w == "true"

    local old_win = vim.api.nvim_get_current_win()
    local dir_map = { left = "h", right = "l", up = "k", down = "j" }

    -- 1. Attempt standard movement
    if dir_map[direction] then
        vim.cmd("wincmd " .. dir_map[direction])
    end

    local new_win = vim.api.nvim_get_current_win()

    -- 2. Check outcomes
    if new_win ~= old_win then
        update_history()

        -- Successful move: Acknowledge only if not wrapping
        if not wrap then
            send_osc("t=acknowledge:id=" .. id .. ";" .. direction)
        end
    else
        -- Move failed (we hit an edge)
        if wrap then
            -- INTERNAL WRAP: Jump to the opposite side of the editor
            -- We simulate an 'enter' event coming from the SAME direction
            -- to find the windows on the opposite edge.

            -- Example: If moving 'down' and we hit the bottom, we want to
            -- 'enter' from the 'top'. Our handle_enter logic already
            -- calculates the entering edge based on the direction.

            if config.wrap_internal_navigation then
                -- We need to provide a range 'r' to mimic the current window's span
                local info = vim.fn.getwininfo(old_win)[1]
                local r_min, r_max
                if direction == "up" or direction == "down" then
                    r_min, r_max = info.wincol, info.wincol + info.width - 1
                else
                    r_min, r_max = info.winrow, info.winrow + info.height - 1
                end

                -- Synthesize an enter event internally
                local synthetic_meta = string.format("t=enter:r=%d,%d", r_min, r_max)
                handle_enter(synthetic_meta, direction)
            end
        else
            -- EXTERNAL MOVE: Tell the terminal to take over
            local info = vim.fn.getwininfo(old_win)[1]
            local r_min, r_max
            if direction == "up" or direction == "down" then
                r_min, r_max = info.wincol, info.wincol + info.width - 1
            else
                r_min, r_max = info.winrow, info.winrow + info.height - 1
            end

            local resp = string.format("t=navigate:id=%s:r=%d,%d;%s", id, r_min, r_max, direction)
            send_osc(resp)
        end
    end
end

-- --- Event Router ---

local function on_term_response(args)
    local seq = args.data.sequence
    if not seq or not seq:find("8671") then
        return
    end

    -- Pattern to capture: metadata ; payload
    -- (Handling potential BEL \7 or ST \27\\ terminators)
    local metadata, payload = seq:match("8671;([^;]+);?%s*([^%s\27\7]*)")
    if not metadata then
        return
    end

    if metadata:find("t=navigate") then
        handle_navigate(metadata, payload)
    elseif metadata:find("t=enter") and config.handle_enter then
        handle_enter(metadata, payload)
    end
end

-- --- Setup ---

function M.setup(opts)
    config = vim.tbl_extend("force", config, opts or {})
    local group = vim.api.nvim_create_augroup("SeamlessNav", { clear = true })

    vim.api.nvim_create_autocmd("TermResponse", {
        group = group,
        callback = on_term_response,
    })

    local function register()
        local h_val = config.hide_cursor_on_enter and "true" or "false"
        send_osc("t=register:h=" .. h_val)
    end

    if vim.v.vim_did_enter == 1 then
        register()
    else
        vim.api.nvim_create_autocmd("VimEnter", { group = group, callback = register })
    end

    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
        group = group,
        callback = update_history,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            send_osc("t=unregister")
        end,
    })
end

return M
