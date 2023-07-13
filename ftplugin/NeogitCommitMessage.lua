if vim.b.did_ftplugin then
  return
end

vim.cmd.source("$VIMRUNTIME/ftplugin/gitcommit.vim")

local ok, _ = pcall(vim.treesitter.language.inspect, "gitcommit")
if ok then
  vim.treesitter.start(0, "gitcommit")
  vim.cmd([[au BufUnload <buffer> lua vim.treesitter.stop(0)]])
end
