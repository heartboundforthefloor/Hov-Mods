--[[
  HoVNoSlipperyRoofs (UE4SS Lua mod) - roofs on Valor Village and Rusty River stop being slippery.

  How the game does slipperiness (BP_Character, run by whoever controls the character: each
  player's own client, the host for bots):
    - a trace under the character hits a surface whose physical material is M_Phys_SlipperySurface
      (all the roof materials: M_Roof1-6, M_Rooftiles05/06, M_Roof_Church2) -> OnSlipperySurface;
    - a second short trace on the SlipperinessDetect channel checks for a BP_AntiSlipperyVolume
      (a plain box that only blocks that channel) -> InsideAntiSlipperinessVolume;
    - slippery and not inside a volume: ground friction 0, a push down the slope, no jumping.
  Barricade Bridge uses one big BP_AntiSlipperyVolume for this. This mod does the same on the maps
  in MAPS: one volume over each combat zone (combat area and both bases), with extra height so every
  rooftop is inside. The box blocks only SlipperinessDetect, so players, shots and vehicles pass
  through it.

  The check runs on each player's machine, so the volumes have to exist there:
    - on the host they are spawned replicated and always relevant, so every client gets them
      (players without the mod included), and bots are covered;
    - a client running this mod also spawns its own local copies, in case replication doesn't
      reach it. Overlapping volumes are harmless.
]]

local MAPS         = { "Valor_Village", "Rusty_River" }
local HEIGHT_SCALE = 4      -- volume height = combat zone height x this (zones are 6400 uu tall)

local CLS = "/Game/Blueprints/BP_AntiSlipperyVolume.BP_AntiSlipperyVolume_C"
local PKG = "/Game/Blueprints/BP_AntiSlipperyVolume"
local GSL = "/Script/Engine.Default__GameplayStatics"

local function log(fmt, ...) print(string.format("[HoVNoSlipperyRoofs] " .. fmt .. "\n", ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local function volumeClass()
  local c = StaticFindObject(CLS)
  if valid(c) then return c end
  for _, p in ipairs({ CLS, PKG .. ".BP_AntiSlipperyVolume", PKG }) do
    if type(LoadAsset) == "function" then pcall(LoadAsset, p) end
    c = StaticFindObject(CLS)
    if valid(c) then return c end
  end
  log("BP_AntiSlipperyVolume_C not found")
  return nil
end

-- UE FRotator (degrees) -> quaternion.
local function rotQuat(r)
  local p, y, l = math.rad(r.Pitch or 0) / 2, math.rad(r.Yaw or 0) / 2, math.rad(r.Roll or 0) / 2
  local SP, CP, SY, CY, SR, CR = math.sin(p), math.cos(p), math.sin(y), math.cos(y), math.sin(l), math.cos(l)
  return { X = CR * SP * SY - SR * CP * CY, Y = -CR * SP * CY - SR * CP * SY,
           Z = CR * CP * SY - SR * SP * CY, W = CR * CP * CY + SR * SP * SY }
end

-- Combat zones (not No Go zones) of a map in MAPS that is loaded now.
local function mapZones()
  local zones = FindAllOf("BP_CombatZone_C")
  if not zones then return nil end
  for _, key in ipairs(MAPS) do
    local list = {}
    for _, z in pairs(zones) do
      if valid(z) and z:GetFullName():find(key, 1, true) and z.ZoneType ~= 3 then list[#list + 1] = z end
    end
    if #list > 0 then return key, list end
  end
  return nil
end

local function spawnVolume(world, cls, gsl, z, authority)
  local l, r, sc = z:K2_GetActorLocation(), z:K2_GetActorRotation(), z:GetActorScale3D()
  local tf = { Translation = { X = l.X, Y = l.Y, Z = l.Z }, Rotation = rotQuat(r),
               Scale3D = { X = sc.X, Y = sc.Y, Z = sc.Z * HEIGHT_SCALE } }
  local a = gsl:BeginDeferredActorSpawnFromClass(world, cls, tf, 1, nil)   -- 1 = always spawn
  if not valid(a) then return false end
  if authority then a.bAlwaysRelevant = true end
  gsl:FinishSpawningActor(a, tf)
  if authority then
    -- Only once fully spawned does the engine register it with the net driver.
    a:SetReplicates(true)
    a:ForceNetUpdate()
  end
  return true
end

local doneFor = nil
local function setup()
  local gs = FindFirstOf("BP_GameState_InGame_Base_C")
  if not valid(gs) then gs = FindFirstOf("GameStateBase") end
  if not valid(gs) then return end
  local key = gs:GetFullName()
  if doneFor == key then return end
  local mapKey, zones = mapZones()
  if not mapKey then return end

  local cls, gsl = volumeClass(), StaticFindObject(GSL)
  if not (cls and valid(gsl)) then doneFor = key; return end
  doneFor = key
  local authority = gs:HasAuthority()
  local n = 0
  for _, z in ipairs(zones) do
    local ok, res = pcall(spawnVolume, gs, cls, gsl, z, authority)
    if ok and res then n = n + 1 elseif not ok then log("spawn failed: %s", tostring(res)) end
  end
  log("%s: %d anti-slippery volume(s) %s", mapKey, n,
      authority and "spawned (replicated to clients)" or "spawned locally on this client")
end

LoopAsync(2000, function()
  ExecuteInGameThread(function()
    local ok, err = pcall(setup)
    if not ok then log("setup failed: %s", tostring(err)) end
  end)
  return false
end)

log("loaded")
