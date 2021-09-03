-- This module does all necessary dependency checks and takes care of
-- initializing global values and configuration.
-- It MUST NOT error, as this function is called from viml and errors won't
-- be caught.
--
-- The module returns true if everything went well, or false if any part of
-- the initialization failed.
local res, err = pcall(require, 'plenary')
if not res then
  print("WARNING: Neogit depends on `nvim-lua/plenary.nvim` to work, but loading the plugin failed!")
  print("Make sure you add `nvim-lua/plenary.nvim` to your plugin manager BEFORE neogit for everything to work")
  print(err) -- TODO: find out how to print the error without raising it AND properly print tabs
  return false
end

return true
