if vim.b.did_ftplugin then
  return
end

vim.cmd.source("$VIMRUNTIME/ftplugin/gitrebase.vim")

local parser = vim.treesitter.language.get_lang("git_rebase")
if parser then
  vim.treesitter.start(0, parser)
  vim.cmd([[au BufUnload <buffer> lua vim.treesitter.stop(0)]])
end
