local M = {}

function M.setup(opts)
  require("nvim-tree.actions.fs.trash").setup(opts)
  require("nvim-tree.actions.node.system-open").setup(opts)
  require("nvim-tree.actions.node.file-popup").setup(opts)
  require("nvim-tree.actions.node.open-file").setup(opts)
  require("nvim-tree.actions.root.change-dir").setup(opts)
  require("nvim-tree.actions.fs.create-file").setup(opts)
  require("nvim-tree.actions.fs.rename-file").setup(opts)
  require("nvim-tree.actions.fs.remove-file").setup(opts)
  require("nvim-tree.actions.fs.copy-paste").setup(opts)
  require("nvim-tree.actions.tree-modifiers.expand-all").setup(opts)
end

return M
