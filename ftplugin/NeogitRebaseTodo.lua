if vim.b.did_ftplugin then
  return
end

vim.cmd.source("$VIMRUNTIME/ftplugin/gitrebase.vim")

local ok, _ = pcall(vim.treesitter.language.inspect, "git_rebase")
if ok then
  vim.treesitter.start(0, "git_rebase")
  vim.cmd([[au BufUnload <buffer> lua vim.treesitter.stop(0)]])
end
