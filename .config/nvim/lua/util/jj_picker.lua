local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local entry_display = require("telescope.pickers.entry_display")
local p_utils = require("telescope.previewers.utils")
local make_entry = require("telescope.make_entry")

local M = {}

-- Discover JJ repository root directory (pure Lua, sub-millisecond)
function M.get_jj_root(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if not path or path == "" then
    path = vim.fn.getcwd()
  end
  path = path:gsub("^%w+://", "")

  local jj_dir = vim.fs.find(".jj", { upward = true, path = path })[1]
  if jj_dir then
    return vim.fs.normalize(vim.fs.dirname(jj_dir))
  end

  local cwd = vim.fn.getcwd()
  local cmd = string.format("cd %s && jj --ignore-working-copy root", vim.fn.shellescape(cwd))
  local res = vim.fn.systemlist(cmd)
  if vim.v.shell_error == 0 and res and res[1] and res[1] ~= "" then
    return vim.fs.normalize(res[1])
  end

  return nil
end

-- Fast base revision detection without slow subprocesses
function M.get_base_rev(jj_root)
  -- An overlay may provide a different baseline revision (see util/util.lua)
  local override = require("util.util").jj_base_rev(jj_root)
  if override then
    return override
  end
  -- In git repositories, trunk() is the default base
  return "trunk()"
end

-- Create the custom previewer displaying revision diffs, conflicts, or baseline diffs asynchronously
local function create_previewer(diff_state, jj_root, base_rev)
  return previewers.new_buffer_previewer({
    title = "JJ Diff",
    dyn_title = function(_, entry)
      if entry.is_conflict then
        return string.format("⚠️ CONFLICT %s: %s", entry.rev_label or "", entry.repo_path or "")
      elseif diff_state.mode == "baseline" then
        return string.format("Baseline Diff (%s -> @): %s", base_rev, entry.repo_path or "")
      else
        local desc = (entry.commit_desc and entry.commit_desc ~= "") and (" ─ " .. entry.commit_desc) or ""
        return string.format("Diff %s%s: %s", entry.rev_label or "", desc, entry.repo_path or "")
      end
    end,

    get_buffer_by_name = function(_, entry)
      return "jj_diff_" .. diff_state.mode .. "_" .. (entry.rev or "") .. "_" .. (entry.repo_path or "")
    end,

    define_preview = function(self, entry)
      if self.state.bufname then
        return
      end

      local path = entry.repo_path
      if not path or path == "" then
        return
      end

      local cmd
      if diff_state.mode == "baseline" then
        cmd = { "jj", "--no-pager", "diff", "--git", "--from", base_rev, "--to", "@", "--", path }
      else
        cmd = { "jj", "--no-pager", "diff", "--git", "-r", entry.rev, "--", path }
      end

      p_utils.job_maker(cmd, self.state.bufnr, {
        cwd = jj_root,
        callback = function(bufnr, result)
          p_utils.highlighter(bufnr, "diff")
          if result and #result == 0 then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
              "",
              "  (No changes for " .. path .. " in revision " .. (entry.rev_label or "") .. ")",
            })
          end
        end,
      })
    end,
  })
end

-- High-performance modified files picker for JJ with conflict detection
function M.modified(opts)
  opts = opts or {}

  local jj_root = M.get_jj_root()
  if not jj_root then
    vim.notify("Not in a JJ repository", vim.log.levels.WARN)
    return
  end

  local base_rev = M.get_base_rev(jj_root)

  -- Streaming template:
  -- 1) self.conflicted_files() emits conflicted files first with status C
  -- 2) diff.files() emits regular modified/added/deleted files
  local template =
    'self.conflicted_files().map(|f| change_id.shortest(8) ++ "\\t" ++ current_working_copy ++ "\\t" ++ description.first_line() ++ "\\tC\\t" ++ f.path() ++ "\\n").join("") ++ ' ..
    'diff.files().map(|f| change_id.shortest(8) ++ "\\t" ++ current_working_copy ++ "\\t" ++ description.first_line() ++ "\\t" ++ f.status_char() ++ "\\t" ++ f.path() ++ "\\n").join("")'

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 3 },  -- status e.g. " M ", " A ", " C "
      { width = 16 }, -- revision badge e.g. "[@] Current" or "[@] CONFLICT"
      { remaining = true }, -- path
    },
  })

  local make_display = function(entry)
    local display_path = require("telescope.utils").transform_path(opts, entry.abs_path)
    return displayer({
      { " " .. entry.status .. " ", entry.status_hl },
      { entry.rev_label, entry.rev_hl },
      { display_path },
    })
  end

  local seen_paths = {}
  local change_id_to_idx = {}
  local next_commit_idx = 0
  local cached_all = {}
  local cached_current = {}
  local cached_conflicts = {}

  local function parse_and_create_entry(line)
    if not line or line == "" then
      return nil
    end

    local parts = vim.split(line, "\t")
    if #parts < 5 then
      return nil
    end

    local change_id = parts[1]
    local is_current = (parts[2] == "true")
    local commit_desc = parts[3]
    local status_char = parts[4]
    local repo_path = parts[5]

    -- Deduplicate: conflicted files and newest commits arrive first
    -- Conflicted files (status C) take priority
    if seen_paths[repo_path] then
      return nil
    end
    seen_paths[repo_path] = true

    if not change_id_to_idx[change_id] then
      change_id_to_idx[change_id] = next_commit_idx
      next_commit_idx = next_commit_idx + 1
    end
    local idx = change_id_to_idx[change_id]
    local is_conflict = (status_char == "C")

    local rev_label, rev_hl
    if is_conflict then
      rev_label = is_current and "[@] CONFLICT" or string.format("[@-%d] CONFLICT", idx)
      rev_hl = "DiagnosticError"
    elseif is_current then
      rev_label = "[@] Current"
      rev_hl = "TelescopeResultsDiffAdd"
    elseif idx == 1 then
      rev_label = "[@-] " .. change_id
      rev_hl = "TelescopeResultsDiffChange"
    elseif idx == 2 then
      rev_label = string.format("[@-%d] %s", idx, change_id)
      rev_hl = "DiagnosticInfo"
    else
      rev_label = string.format("[@-%d] %s", idx, change_id)
      rev_hl = "Comment"
    end

    local status_hl = "TelescopeResultsDiffChange"
    if is_conflict then
      status_hl = "DiagnosticError"
    elseif status_char == "A" then
      status_hl = "TelescopeResultsDiffAdd"
    elseif status_char == "D" then
      status_hl = "TelescopeResultsDiffDelete"
    elseif status_char == "R" then
      status_hl = "DiagnosticInfo"
    end

    local abs_path = vim.fs.normalize(jj_root .. "/" .. repo_path)
    local ordinal = string.format(
      "%s %s %s %s %s %s",
      status_char,
      rev_label,
      is_conflict and "conflict conflicted" or "",
      commit_desc or "",
      repo_path,
      abs_path
    )

    local raw = {
      value = abs_path,
      path = abs_path,
      ordinal = ordinal,
      display = make_display,
      repo_path = repo_path,
      abs_path = abs_path,
      status = status_char,
      status_hl = status_hl,
      rev = is_current and "@" or change_id,
      rev_label = rev_label,
      rev_hl = rev_hl,
      is_current = is_current,
      is_conflict = is_conflict,
      commit_desc = commit_desc,
      commit_idx = idx,
    }

    local entry = make_entry.set_default_entry_mt(raw, opts)
    table.insert(cached_all, entry)
    if is_current then
      table.insert(cached_current, entry)
    end
    if is_conflict then
      table.insert(cached_conflicts, entry)
    end

    return entry
  end

  local diff_state = { mode = "revision" }
  local filter_state = { current = "stack" }

  local function get_prompt_title()
    local conflict_tag = ""
    if #cached_conflicts > 0 then
      conflict_tag = string.format("⚠️ %d CONFLICT%s | ", #cached_conflicts, #cached_conflicts == 1 and "" or "S")
    end

    if filter_state.current == "stack" then
      return string.format("JJ Modified: %sStack [<Tab> filter] [<C-d> diff]", conflict_tag)
    elseif filter_state.current == "current" then
      return string.format("JJ Modified: %sCurrent @ [<Tab> filter] [<C-d> diff]", conflict_tag)
    else
      return string.format("JJ Modified: ⚠️ %d CONFLICTS ONLY [<Tab> show stack] [<C-d> diff]", #cached_conflicts)
    end
  end

  -- Use async oneshot job finder for instant popup
  local stream_finder = finders.new_oneshot_job({
    "jj",
    "-R",
    jj_root,
    "--no-pager",
    "--ignore-working-copy",
    "log",
    "-r",
    base_rev .. "..@",
    "--no-graph",
    "-T",
    template,
  }, {
    cwd = jj_root,
    entry_maker = parse_and_create_entry,
  })

  pickers.new(opts, {
    prompt_title = get_prompt_title(),
    results_title = "Modified Files",
    finder = stream_finder,
    sorter = conf.file_sorter(opts),
    previewer = create_previewer(diff_state, jj_root, base_rev),
    attach_mappings = function(prompt_bufnr, map)
      -- Toggle between all stack files, current revision (@) only, and conflicts only
      local function toggle_scope()
        if #cached_conflicts > 0 then
          if filter_state.current == "stack" then
            filter_state.current = "current"
          elseif filter_state.current == "current" then
            filter_state.current = "conflicts"
          else
            filter_state.current = "stack"
          end
        else
          filter_state.current = (filter_state.current == "stack") and "current" or "stack"
        end

        local current_picker = action_state.get_current_picker(prompt_bufnr)
        local results
        if filter_state.current == "stack" then
          results = cached_all
        elseif filter_state.current == "current" then
          results = cached_current
        else
          results = cached_conflicts
        end

        local table_finder = finders.new_table({
          results = results,
          entry_maker = function(e)
            return e
          end,
        })

        local new_title = get_prompt_title()
        if current_picker.prompt_border and current_picker.prompt_border.change_title then
          current_picker.prompt_border:change_title(new_title)
        elseif current_picker.layout and current_picker.layout.prompt and current_picker.layout.prompt.border then
          current_picker.layout.prompt.border:change_title(new_title)
        end

        current_picker:refresh(table_finder, { reset_prompt = false })
      end

      -- Toggle diff mode between revision diff and baseline diff
      local function toggle_diff()
        diff_state.mode = (diff_state.mode == "revision") and "baseline" or "revision"
        local current_picker = action_state.get_current_picker(prompt_bufnr)
        current_picker:refresh_previewer()
        local mode_desc = (diff_state.mode == "revision")
          and "Revision diff (@ vs @-)"
          or ("Baseline diff (" .. base_rev .. " -> @)")
        vim.notify("Preview diff mode: " .. mode_desc, vim.log.levels.INFO)
      end

      map({ "i", "n" }, "<Tab>", toggle_scope)
      map({ "i", "n" }, "<C-r>", toggle_scope)
      map({ "i", "n" }, "<C-d>", toggle_diff)

      -- Open file on selection
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection and selection.abs_path then
          if selection.status == "D" then
            vim.notify("File was deleted in revision " .. (selection.rev_label or ""), vim.log.levels.WARN)
          else
            vim.cmd.edit(vim.fn.fnameescape(selection.abs_path))
            if selection.is_conflict then
              vim.notify("⚠️ Opened conflicted file: resolve conflict markers and save (:w)", vim.log.levels.WARN)
            end
          end
        end
      end)

      return true
    end,
  }):find()
end

return M
