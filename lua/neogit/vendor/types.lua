--This file exists to facilitate llscheck CI types

---@class Path
---@field absolute fun(self): boolean
---@field exists fun(self): boolean
---@field touch fun(self, opts:table)
---@field write fun(self, txt:string, flag:string)
---@field read fun(self): string|nil
---@field iter fun(self): self

---@class uv_timer_t
---@field start fun(self, time:number, repeat: number, fn: function)
---@field stop fun(self)
---@field is_closing fun(self): boolean
---@field close fun(self)
---
---@class uv_fs_event_t
---@field start fun(self, path: string, opts: table, callback: function)
---@field stop fun(self)
