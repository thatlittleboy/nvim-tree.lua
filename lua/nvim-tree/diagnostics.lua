local utils = require "nvim-tree.utils"
local view = require "nvim-tree.view"
local core = require "nvim-tree.core"
local log = require "nvim-tree.log"

local M = {}

local GROUP = "NvimTreeDiagnosticSigns"

local severity_levels = { Error = 1, Warning = 2, Information = 3, Hint = 4 }
local sign_names = {
  { "NvimTreeSignError", "NvimTreeLspDiagnosticsError" },
  { "NvimTreeSignWarning", "NvimTreeLspDiagnosticsWarning" },
  { "NvimTreeSignInformation", "NvimTreeLspDiagnosticsInformation" },
  { "NvimTreeSignHint", "NvimTreeLspDiagnosticsHint" },
}

local function add_sign(linenr, severity)
  local buf = view.get_bufnr()
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
    return
  end
  local sign_name = sign_names[severity][1]
  vim.fn.sign_place(0, GROUP, sign_name, buf, { lnum = linenr, priority = 2 })
end

local function from_nvim_lsp()
  local buffer_severity = {}

  for _, diagnostic in ipairs(vim.diagnostic.get(nil, { severity = M.severity })) do
    local buf = diagnostic.bufnr
    if vim.api.nvim_buf_is_valid(buf) then
      local bufname = vim.api.nvim_buf_get_name(buf)
      local lowest_severity = buffer_severity[bufname]
      if not lowest_severity or diagnostic.severity < lowest_severity then
        buffer_severity[bufname] = diagnostic.severity
      end
    end
  end

  return buffer_severity
end

local function from_coc()
  if vim.g.coc_service_initialized ~= 1 then
    return {}
  end

  local diagnostic_list = vim.fn.CocAction "diagnosticList"
  if type(diagnostic_list) ~= "table" or vim.tbl_isempty(diagnostic_list) then
    return {}
  end

  local buffer_severity = {}
  local diagnostics = {}

  for _, diagnostic in ipairs(diagnostic_list) do
    local bufname = diagnostic.file
    local severity = severity_levels[diagnostic.severity]

    local severity_list = diagnostics[bufname] or {}
    table.insert(severity_list, severity)
    diagnostics[bufname] = severity_list
  end

  for bufname, severity_list in pairs(diagnostics) do
    if not buffer_severity[bufname] then
      local severity = math.min(unpack(severity_list))
      buffer_severity[bufname] = severity
    end
  end

  return buffer_severity
end

local function is_using_coc()
  return vim.g.coc_service_initialized == 1
end

function M.clear()
  if not M.enable or not view.is_buf_valid(view.get_bufnr()) then
    return
  end

  vim.fn.sign_unplace(GROUP)
end

function M.update()
  if not M.enable or not core.get_explorer() or not view.is_buf_valid(view.get_bufnr()) then
    return
  end
  utils.debounce("diagnostics", M.debounce_delay, function()
    local profile = log.profile_start "diagnostics update"
    log.line("diagnostics", "update")

    local buffer_severity
    if is_using_coc() then
      buffer_severity = from_coc()
    else
      buffer_severity = from_nvim_lsp()
    end

    M.clear()

    local nodes_by_line = utils.get_nodes_by_line(core.get_explorer().nodes, core.get_nodes_starting_line())
    for _, node in pairs(nodes_by_line) do
      node.diag_status = nil
    end

    for bufname, severity in pairs(buffer_severity) do
      local bufpath = utils.canonical_path(bufname)
      log.line("diagnostics", " bufpath '%s' severity %d", bufpath, severity)
      if 0 < severity and severity < 5 then
        for line, node in pairs(nodes_by_line) do
          local nodepath = utils.canonical_path(node.absolute_path)
          log.line("diagnostics", "  %d checking nodepath '%s'", line, nodepath)
          if
            M.show_on_dirs
            and vim.startswith(bufpath:gsub("\\", "/"), nodepath:gsub("\\", "/") .. "/")
            and (not node.open or M.show_on_open_dirs)
          then
            log.line("diagnostics", " matched fold node '%s'", node.absolute_path)
            node.diag_status = severity
            add_sign(line, severity)
          elseif nodepath == bufpath then
            log.line("diagnostics", " matched file node '%s'", node.absolute_path)
            node.diag_status = severity
            add_sign(line, severity)
          end
        end
      end
    end
    log.profile_end(profile)
  end)
end

local links = {
  NvimTreeLspDiagnosticsError = "DiagnosticError",
  NvimTreeLspDiagnosticsWarning = "DiagnosticWarn",
  NvimTreeLspDiagnosticsInformation = "DiagnosticInfo",
  NvimTreeLspDiagnosticsHint = "DiagnosticHint",
}

function M.setup(opts)
  M.enable = opts.diagnostics.enable
  M.debounce_delay = opts.diagnostics.debounce_delay
  M.severity = opts.diagnostics.severity

  if M.enable then
    log.line("diagnostics", "setup")
  end

  M.show_on_dirs = opts.diagnostics.show_on_dirs
  M.show_on_open_dirs = opts.diagnostics.show_on_open_dirs
  vim.fn.sign_define(sign_names[1][1], { text = opts.diagnostics.icons.error, texthl = sign_names[1][2] })
  vim.fn.sign_define(sign_names[2][1], { text = opts.diagnostics.icons.warning, texthl = sign_names[2][2] })
  vim.fn.sign_define(sign_names[3][1], { text = opts.diagnostics.icons.info, texthl = sign_names[3][2] })
  vim.fn.sign_define(sign_names[4][1], { text = opts.diagnostics.icons.hint, texthl = sign_names[4][2] })

  for lhs, rhs in pairs(links) do
    vim.cmd("hi def link " .. lhs .. " " .. rhs)
  end
end

return M
