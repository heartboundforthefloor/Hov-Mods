--[[
  HoVNoBotChat (UE4SS Lua mod) - stops bots posting in chat, and prints chat to the console.

  Bots chat through BP_Character:AI_SendChatMessage(ChatMessageTable): on a kill or a death
  (1 in 26 chance) it reads the row names of DT_BotChatMessages_Kill / _Death, picks one at random
  and broadcasts it with the game state's MC_ShareChatMessage.

  UE4SS runs RegisterHook callbacks for Blueprint functions (like AI_SendChatMessage) only after
  they've run, so the hook is on the native DataTableFunctionLibrary:GetDataTableRowNames instead,
  whose callback runs before it. When the table is a bot-chat table, it's swapped for the DataTable
  class default object, which has no rows: AI_SendChatMessage gets no row names, its row lookup
  fails, and it returns before sending anything. Every other table is passed through untouched,
  so player chat, chat commands and server messages are unaffected.

  Chat log: every message broadcast through the game state's MC_ShareChatMessage (player chat,
  chat-command replies and server notices) is printed to the UE4SS console/log as
  [HoVNoBotChat] [chat] [Allied] Name: message
  and appended, with a timestamp, to chat_YYYY-MM-DD.log in the mod folder (one file per day).
  That's a Blueprint function, so this hook runs after it - fine for logging. Works on the host,
  and on a client running the mod (the message is multicast to everyone).

  Runs on the PC that hosts the game (bots only exist on the host).
]]

local FN          = "/Script/Engine.DataTableFunctionLibrary:GetDataTableRowNames"
local EMPTY_TABLE = "/Script/Engine.Default__DataTable"
local PREFIX      = "DT_BotChatMessages"       -- DT_BotChatMessages_Kill, DT_BotChatMessages_Death

local function log(fmt, ...) print(string.format("[HoVNoBotChat] " .. fmt .. "\n", ...)) end

local blocked = 0
local ok, err = pcall(RegisterHook, FN, function(ctx, tableParam, outRowNames)
  local t = tableParam:get()
  if not (t and t:IsValid()) then return end
  local name = t:GetFName():ToString()
  if name:sub(1, #PREFIX) ~= PREFIX then return end
  local empty = StaticFindObject(EMPTY_TABLE)
  if empty and empty:IsValid() then
    tableParam:set(empty)
    blocked = blocked + 1
    if blocked <= 3 then log("blocked a bot chat message (%s, %d so far)", name, blocked) end
  end
end)

if ok then log("hooked GetDataTableRowNames: bot chat disabled")
else log("hook failed: %s", tostring(err)) end

------------------------------------------------------------------------ chat log
local LOG_CHAT      = true
local LOG_CHAT_FILE = true    -- also append to HoVNoBotChat/chat_YYYY-MM-DD.log (one file per day)
local CHAT_FN  = "/Game/Blueprints/Gamestates/BP_GameState_InGame_Base.BP_GameState_InGame_Base_C:MC_ShareChatMessage"
local TEAMS    = { [0] = "Neutral", [1] = "Allied", [2] = "Axis" }

local function text(p)
  local okv, v = pcall(function() return p:get() end)
  if not okv or v == nil then return "" end
  local oks, s = pcall(function() return v:ToString() end)
  return oks and s or tostring(v)
end

-- The mod folder (…/Mods/HoVNoBotChat/), from this script's own path.
local MOD_DIR = (function()
  local src = debug.getinfo(1, "S").source:gsub("^@", "")
  return src:match("^(.*)[/\\]Scripts[/\\][^/\\]+$") or "."
end)()

local function writeChatLine(line)
  if not LOG_CHAT_FILE then return end
  local path = string.format("%s/chat_%s.log", MOD_DIR, os.date("%Y-%m-%d"))
  local f = io.open(path, "a")
  if not f then return end
  f:write(os.date("[%Y-%m-%d %H:%M:%S] "), line, "\n")
  f:close()
end

local function onChat(self, username, message, special, team)
  local name = text(username)
  local msg  = text(message)
  local isSpecial = special and special:get()
  local t = team and team:get()
  local line
  if isSpecial then
    line = string.format("[server] %s%s", name ~= "" and (name .. ": ") or "", msg)
  else
    line = string.format("[%s] %s: %s", TEAMS[t] or tostring(t), name, msg)
  end
  log("[chat] %s", line)
  writeChatLine(line)
end

-- The in-game game state isn't loaded in the main menu, so retry until the hook registers.
if LOG_CHAT then
  local chatHooked = false
  LoopAsync(2000, function()
    if chatHooked then return true end
    ExecuteInGameThread(function()
      if chatHooked then return end
      if pcall(RegisterHook, CHAT_FN, onChat) then
        chatHooked = true
        log("hooked MC_ShareChatMessage: chat is printed to the console%s",
            LOG_CHAT_FILE and (" and " .. MOD_DIR .. "/chat_<date>.log") or "")
      end
    end)
    return chatHooked
  end)
end
