--[[
  HoVValorHeli (UE4SS Lua mod) - helicopters and a higher ceiling on Valor Village.

  Runs on the PC that hosts the game (listen server or single player). On every Valor Village
  map load it:
    1. raises the top of the combat area and replicates the new box to every client, including
       players who join later (each client checks the combat zone itself, so a host-only change
       wouldn't do anything for them);
    2. spawns a Sikorsky helicopter (BP_Sikorsky_C) at each configured spot, through the game
       state's RespawnActor - the same function the game uses to respawn vehicles - so the
       helicopter replicates normally and respawns at that spot 5 s after it's destroyed.
    3. spawns AA guns (BP_AAGun) at fixed spots;
    4. makes each base a repair zone for its team;
    5. spawns half-scale tanks at fixed spots: Shermans (Allied) at the Allied base and Panzer IIIs
       (Axis) at the Axis base, also through RespawnActor.
  F10 spawns an extra helicopter in front of the host.

  Also sets up Rusty River (see MAPS). Data from the 2026-11-15 server export.
]]

local CFG = {
  FALLBACK_Z  = -4100,       -- used if a ground trace fails and the entry has no Z
  SPAWN_ABOVE = 250,         -- uu above the ground for helicopters
  SPAWN_KEY   = Key.F10,
  SPAWN_AHEAD = 1500,        -- uu in front of the host for F10
  TANK_SCALE  = 0.5,
  TANK_ABOVE  = 30,          -- tanks: uu above the given Z, so they settle onto the ground
  AA_SCALE    = 1.0,
  -- Make each team's base area (the map's Allied/Axis base combat zones) a repair zone for that
  -- team. Helicopters auto-repair while inside a repair zone of their team (server-side check).
  BASE_REPAIR_ZONES = true,
  BASE_REPAIR_HEIGHT = 0.15,  -- repair zone height as a fraction of the base box (6400 uu -> 960)
  BASE_REPAIR_BELOW  = 200,   -- the zone starts this far below the base floor (found by a trace
                              -- at the base centre; the base boxes themselves reach far underground)
}

--[[ Per-map setup. The key is matched against the map's level name.
  Team: 0 Neutral, 1 Allied, 2 Axis.  Yaw: 0 = +X, 90 = +Y, -90 = -Y, 180 = -X.
  HELIS: entries with Z (an F9 reading) are dropped onto the ground just below that point;
         entries without Z trace down from high above (can land on a roof).
  TANKS: Kind "Sherman" or "Panzer3"; placed at Z + TANK_ABOVE.
  AA:    dropped onto the ground just below the given Z (F9 readings work as-is).
  CEILING_RAISE: uu added to the top of the combat area (0 = leave it); RAISE_BASES raises the
         Allied/Axis base boxes too.
]]
local MAPS = {
  Valor_Village = {
    CEILING_RAISE = 16000, RAISE_BASES = true,
    HELIS = {
      { X = 23400,    Y = -7400,                 Yaw = 90,  Team = 1 },   -- Allied base
      { X = 23400,    Y = 15900,                 Yaw = -90, Team = 2 },   -- Axis base (estimate)
      { X = 26692.29, Y = 5133.57, Z = -5444.10, Yaw = -90, Team = 0 },   -- mid (neutral)
    },
    TANKS = {
      -- Allied base
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 22049.60, Y = -7026.49, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 21691.39, Y = -6767.79, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 20851.09, Y = -6204.79, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 21372.84, Y = -7349.43, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 21961.35, Y = -7535.75, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 21531.88, Y = -8784.20, Z = -3918.43 },
      { Kind = "Sherman", Team = 1, Yaw = -90, X = 22165.26, Y = -8746.63, Z = -3918.43 },
      -- Axis base
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 21829.52, Y = 17377.90, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 22062.74, Y = 18463.92, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 21688.03, Y = 18200.62, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 21306.39, Y = 17934.31, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 20809.41, Y = 17587.50, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 20685.53, Y = 16923.04, Z = -3722.65 },
      { Kind = "Panzer3", Team = 2, Yaw = 90, X = 21222.07, Y = 17053.83, Z = -3722.65 },
    },
    AA = {
      { Team = 1, Yaw = 70, X = 22317.26, Y = -6542.24, Z = -3918.43 },   -- Allied base
      { Team = 0, Yaw = 0,  X = 19532.61, Y =  5452.84, Z = -4098.29 },   -- mid
      { Team = 0, Yaw = 0,  X = 27345.92, Y =  5521.18, Z = -5359.85 },   -- mid
      { Team = 2, Yaw = 0,  X = 23893.42, Y = 17021.48, Z = -3724.16 },   -- Axis base
    },
  },

  -- Rusty River: Allied base in the west (floor Z ~627), Axis base in the east (floor Z ~815).
  -- Spots are estimated from the map export (next to the existing jeeps/Kubelwagens and spawn
  -- points), not checked in game - stand on better spots, press F9 and replace these lines.
  Rusty_River = {
    CEILING_RAISE = 16000, RAISE_BASES = true,
    HELIS = {
      { X = -5470.34, Y = -633.80, Z = 189.93, Yaw = -20, Team = 1 },   -- Allied base
      { X = 19341.27, Y = -673.85, Z = 839.72, Yaw = 161, Team = 2 },   -- Axis base
    },
    TANKS = {
      -- Allied base, east of the spawns, facing the centre (+X)
      { Kind = "Sherman", Team = 1, Yaw = 0, X = -3900, Y = 2600, Z = 627 },
      { Kind = "Sherman", Team = 1, Yaw = 0, X = -3900, Y = 3300, Z = 627 },
      { Kind = "Sherman", Team = 1, Yaw = 0, X = -3900, Y = 4300, Z = 627 },
      -- Axis base, west of the spawns, facing the centre (-X)
      { Kind = "Panzer3", Team = 2, Yaw = 180, X = 19100, Y =  700, Z = 815 },
      { Kind = "Panzer3", Team = 2, Yaw = 180, X = 19100, Y = 1500, Z = 815 },
      { Kind = "Panzer3", Team = 2, Yaw = 180, X = 19100, Y = 2400, Z = 815 },
    },
    AA = {
      { Team = 1, Yaw = 0,   X = -4600, Y = 1500, Z = 900 },    -- Allied base
      { Team = 2, Yaw = 180, X = 20500, Y = -200, Z = 1100 },   -- Axis base
    },
  },
}

local P = {
  Heli    = "/Game/Blueprints/Vehicles/Helicopters/BP_Sikorsky",
  Sherman = "/Game/Blueprints/Vehicles/Tanks/BP_Sherman",
  Panzer3 = "/Game/Blueprints/Vehicles/Tanks/BP_Panzer3",
  AAGun   = "/Game/Blueprints/Vehicles/StationaryVehicles/BP_AAGun",
  Repair  = "/Game/Blueprints/Vehicles/BP_VehicleRepairZone",
  GSL     = "/Script/Engine.Default__GameplayStatics",
  KSL     = "/Script/Engine.Default__KismetSystemLibrary",
}
local BOX_EXTENT = 32        -- BP_CombatZone's Box uses the default extent; the actor is scaled

local function log(fmt, ...) print(string.format("[HoVValorHeli] " .. fmt .. "\n", ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local function gameState()
  local gs = FindFirstOf("BP_GameState_InGame_Base_C")
  if valid(gs) and gs:HasAuthority() then return gs end
  return nil
end

-- Which MAPS entry is loaded: look for a combat zone whose full name contains the map key.
local function currentMap()
  local zones = FindAllOf("BP_CombatZone_C")
  if not zones then return nil end
  for key, m in pairs(MAPS) do
    local list = {}
    for _, z in pairs(zones) do
      if valid(z) and z:GetFullName():find(key, 1, true) then list[#list + 1] = z end
    end
    if #list > 0 then return key, m, list end
  end
  return nil
end

---------------------------------------------------------------- ceiling
-- ZoneType: 0 Combat Area, 1 Allied Base, 2 Axis Base, 3 No Go Zone
local function raiseCeiling(m, zones)
  if (m.CEILING_RAISE or 0) == 0 then return end
  for _, z in ipairs(zones) do
    local t = z.ZoneType
    if t == 0 or (m.RAISE_BASES and (t == 1 or t == 2)) then
      local root = z.RootComponent
      local s, l = root.RelativeScale3D, root.RelativeLocation
      local half = BOX_EXTENT * s.Z
      local newHalf = half + m.CEILING_RAISE / 2
      -- Replicate the zone so clients get the new box (they normally use their own map copy).
      z:SetReplicates(true)
      z.bAlwaysRelevant = true
      root:SetIsReplicated(true)
      root:K2_SetRelativeLocation({ X = l.X, Y = l.Y, Z = l.Z + m.CEILING_RAISE / 2 }, false, {}, false)
      root:SetRelativeScale3D({ X = s.X, Y = s.Y, Z = newHalf / BOX_EXTENT })
      z:ForceNetUpdate()
      log("zone type %d: top %.0f -> %.0f", t, l.Z + half, l.Z + half + m.CEILING_RAISE)
    end
  end
end

---------------------------------------------------------------- helicopters
-- BP_Sikorsky_C isn't loaded on maps that don't place a helicopter, so load it. UE4SS's LoadAsset
-- expects different path forms in different versions/games, so try each and log what happened.
local loadTried = {}   -- package path -> true once loading was attempted this map
local function vehicleClass(pkg)
  local name = pkg:match("([^/]+)$")
  local classPath = pkg .. "." .. name .. "_C"
  local cls = StaticFindObject(classPath)
  if valid(cls) then return cls end
  if loadTried[pkg] then return nil end
  loadTried[pkg] = true

  local attempts = { classPath, pkg .. "." .. name, pkg }
  for _, path in ipairs(attempts) do
    if type(LoadAsset) ~= "function" then log("this UE4SS has no LoadAsset"); break end
    local ok, res = pcall(LoadAsset, path)
    cls = StaticFindObject(classPath)
    log("LoadAsset(%s): %s, result %s, class %s", path, ok and "ok" or ("error: " .. tostring(res)),
        tostring(res), valid(cls) and "found" or "missing")
    if valid(cls) then return cls end
  end

  -- Engine fallback: KismetSystemLibrary::LoadClassAsset_Blocking takes a soft class path.
  local ksl = StaticFindObject(P.KSL)
  if valid(ksl) then
    local ok, res = pcall(function() return ksl:LoadClassAsset_Blocking(classPath) end)
    cls = StaticFindObject(classPath)
    log("LoadClassAsset_Blocking(%s): %s, class %s", classPath,
        ok and "ok" or ("error: " .. tostring(res)), valid(cls) and "found" or "missing")
    if valid(cls) then return cls end
  end
  log("%s not found", classPath)
  return nil
end

local function groundZ(world, x, y)
  local ksl = StaticFindObject(P.KSL)
  if not valid(ksl) then return CFG.FALLBACK_Z end
  local hit = {}
  local ok, blocked = pcall(function()
    return ksl:LineTraceSingle(world, { X = x, Y = y, Z = 3000 }, { X = x, Y = y, Z = -12000 },
      0, false, {}, 0, hit, true, { R = 1, G = 0, B = 0, A = 1 }, { R = 0, G = 1, B = 0, A = 1 }, 0)
  end)
  if ok and blocked and hit.ImpactPoint then return hit.ImpactPoint.Z end
  if ok and blocked and hit.Location then return hit.Location.Z end
  log("ground trace failed at %.0f, %.0f; using Z %.0f", x, y, CFG.FALLBACK_Z)
  return CFG.FALLBACK_Z
end

-- Ground directly under (x, y, z): trace from just above z down 1000 uu. Falls back to z - 90
-- (an F9 reading is the middle of the player's capsule, about 90 uu above the feet).
local function groundBelow(world, x, y, z)
  local ksl = StaticFindObject(P.KSL)
  if valid(ksl) then
    local hit = {}
    local ok, blocked = pcall(function()
      return ksl:LineTraceSingle(world, { X = x, Y = y, Z = z + 50 }, { X = x, Y = y, Z = z - 1000 },
        0, false, {}, 0, hit, true, { R = 1, G = 0, B = 0, A = 1 }, { R = 0, G = 1, B = 0, A = 1 }, 0)
    end)
    if ok and blocked and hit.ImpactPoint then return hit.ImpactPoint.Z end
    if ok and blocked and hit.Location then return hit.Location.Z end
  end
  return z - 90
end

-- First blocking hit tracing straight down from ztop to zbot, or nil.
local function traceDown(world, x, y, ztop, zbot)
  local ksl = StaticFindObject(P.KSL)
  if not valid(ksl) then return nil end
  local hit = {}
  local ok, blocked = pcall(function()
    return ksl:LineTraceSingle(world, { X = x, Y = y, Z = ztop }, { X = x, Y = y, Z = zbot },
      0, false, {}, 0, hit, true, { R = 1, G = 0, B = 0, A = 1 }, { R = 0, G = 1, B = 0, A = 1 }, 0)
  end)
  if ok and blocked and hit.ImpactPoint then return hit.ImpactPoint.Z end
  if ok and blocked and hit.Location then return hit.Location.Z end
  return nil
end

local function yawQuat(deg)
  local r = math.rad(deg) / 2
  return { X = 0, Y = 0, Z = math.sin(r), W = math.cos(r) }
end

local function spawnVehicle(gs, cls, x, y, z, yaw, team, scale, what)
  scale = scale or 1
  gs:RespawnActor({ Translation = { X = x, Y = y, Z = z }, Rotation = yawQuat(yaw),
                    Scale3D = { X = scale, Y = scale, Z = scale } },
                  cls, false, team, 0, nil, false)   -- player-driven, team, default skin, no swap board
  log("%s spawned at %.0f, %.0f, %.0f (team %d, scale %.2f)", what, x, y, z, team, scale)
end

local function spawnAAGuns(gs, m)
  if not m.AA or #m.AA == 0 then return end
  local cls = vehicleClass(P.AAGun)
  if not cls then return end
  for _, a in ipairs(m.AA) do
    local ok, err = pcall(spawnVehicle, gs, cls, a.X, a.Y, groundBelow(gs, a.X, a.Y, a.Z) + 5,
                          a.Yaw or 0, a.Team or 0, CFG.AA_SCALE, "AA gun")
    if not ok then log("AA gun spawn failed: %s", tostring(err)) end
  end
end

local function spawnTanks(gs, m)
  for _, t in ipairs(m.TANKS or {}) do
    local cls = vehicleClass(P[t.Kind])
    if cls then
      local ok, err = pcall(spawnVehicle, gs, cls, t.X, t.Y, t.Z + CFG.TANK_ABOVE, t.Yaw or 0,
                            t.Team or 1, CFG.TANK_SCALE, t.Kind)
      if not ok then log("%s spawn failed: %s", t.Kind, tostring(err)) end
    end
  end
end

---------------------------------------------------------------- per map load
local doneFor = nil   -- game state the setup ran for

-- UE FRotator (degrees) -> quaternion, for spawn transforms.
local function rotQuat(r)
  local p, y, l = math.rad(r.Pitch or 0) / 2, math.rad(r.Yaw or 0) / 2, math.rad(r.Roll or 0) / 2
  local SP, CP, SY, CY, SR, CR = math.sin(p), math.cos(p), math.sin(y), math.cos(y), math.sin(l), math.cos(l)
  return { X = CR * SP * SY - SR * CP * CY, Y = -CR * SP * CY - SR * CP * SY,
           Z = CR * CP * SY - SR * SP * CY, W = CR * CP * CY + SR * SP * SY }
end

-- BP_VehicleRepairZone is a plain actor (a box on the RepairZone channel plus a Team), so it's
-- spawned with GameplayStatics, setting Team before the actor finishes spawning. It only has to
-- exist on the host: vehicles check for it server-side.
local function spawnRepairZone(gs, tf, team, what)
  local cls = vehicleClass(P.Repair)
  local gsl = StaticFindObject(P.GSL)
  if not (cls and valid(gsl)) then log("repair zone: class or GameplayStatics missing"); return end
  local zone = gsl:BeginDeferredActorSpawnFromClass(gs, cls, tf, 1, nil)   -- 1 = always spawn
  if not valid(zone) then log("repair zone: spawn failed"); return end
  zone.Team = team
  gsl:FinishSpawningActor(zone, tf)
  local hz = tf.Scale3D.Z * BOX_EXTENT
  log("repair zone (%s, team %d) at %.0f, %.0f: Z %.0f to %.0f, size %.0f x %.0f uu", what, team,
      tf.Translation.X, tf.Translation.Y, tf.Translation.Z - hz, tf.Translation.Z + hz,
      tf.Scale3D.X * BOX_EXTENT * 2, tf.Scale3D.Y * BOX_EXTENT * 2)
end

-- One repair zone per base box, with the same location, rotation and scale (both blueprints use a
-- default 32 uu box at the actor's origin, so the footprints match exactly). Called before the
-- ceiling is raised; the height is BASE_REPAIR_HEIGHT of the base box's, from just below the floor.
local function spawnBaseRepairZones(gs, zones)
  if not CFG.BASE_REPAIR_ZONES then return end
  for _, z in ipairs(zones) do
    local t = z.ZoneType
    if t == 1 or t == 2 then                    -- Allied base -> team 1, Axis base -> team 2
      local ok, err = pcall(function()
        local l, r, sc = z:K2_GetActorLocation(), z:K2_GetActorRotation(), z:GetActorScale3D()
        -- Same footprint; height BASE_REPAIR_HEIGHT of the base box's, starting BASE_REPAIR_BELOW
        -- under the floor. The floor is the first hit tracing down from the box top to its bottom.
        local f = CFG.BASE_REPAIR_HEIGHT or 1
        local half = BOX_EXTENT * sc.Z
        local floor = traceDown(gs, l.X, l.Y, l.Z + half, l.Z - half) or (l.Z - half * (1 - f))
        local bottom = floor - (CFG.BASE_REPAIR_BELOW or 0)
        spawnRepairZone(gs, { Translation = { X = l.X, Y = l.Y, Z = bottom + half * f },
                              Rotation = rotQuat(r),
                              Scale3D = { X = sc.X, Y = sc.Y, Z = sc.Z * f } },
                        t, t == 1 and "Allied base" or "Axis base")
      end)
      if not ok then log("base repair zone failed: %s", tostring(err)) end
    end
  end
end

local function spawnHelis(gs, m)
  if not m.HELIS or #m.HELIS == 0 then return end
  local cls = vehicleClass(P.Heli)
  if not cls then return end
  for _, h in ipairs(m.HELIS) do
    local z = h.Z and groundBelow(gs, h.X, h.Y, h.Z) or groundZ(gs, h.X, h.Y)
    local ok, err = pcall(spawnVehicle, gs, cls, h.X, h.Y, z + CFG.SPAWN_ABOVE, h.Yaw or 0,
                          h.Team or 1, 1, "helicopter")
    if not ok then log("helicopter spawn failed: %s", tostring(err)) end
  end
end

local function setup()
  local gs = gameState()
  if not gs then return end
  local key = gs:GetFullName()
  if doneFor == key then return end
  local mapKey, m, zones = currentMap()
  if not mapKey then return end            -- another map, or the level isn't streamed in yet

  doneFor = key
  loadTried = {}
  log("map %s: setting up", mapKey)
  spawnBaseRepairZones(gs, zones)
  raiseCeiling(m, zones)
  spawnHelis(gs, m)
  spawnAAGuns(gs, m)
  spawnTanks(gs, m)
end

LoopAsync(2000, function()
  ExecuteInGameThread(function()
    local ok, err = pcall(setup)
    if not ok then log("setup failed: %s", tostring(err)) end
  end)
  return false
end)

---------------------------------------------------------------- F10: helicopter in front of the host
RegisterKeyBind(CFG.SPAWN_KEY, function()
  ExecuteInGameThread(function()
    local ok, err = pcall(function()
      local gs = gameState()
      local pc = FindFirstOf("BP_GameController_C")
      if not (gs and valid(pc)) then return end
      local pawn = pc:K2_GetPawn()
      if not valid(pawn) then return end
      loadTried = {}
      local cls = vehicleClass(P.Heli)
      if not cls then return end
      local loc, fwd = pawn:K2_GetActorLocation(), pawn:GetActorForwardVector()
      local x, y = loc.X + fwd.X * CFG.SPAWN_AHEAD, loc.Y + fwd.Y * CFG.SPAWN_AHEAD
      local yaw = math.deg(math.atan(fwd.Y, fwd.X))
      spawnVehicle(gs, cls, x, y, groundZ(gs, x, y) + CFG.SPAWN_ABOVE, yaw,
                   pawn.PawnDataComponent.Team or 1, 1, "helicopter")
    end)
    if not ok then log("F10 spawn failed: %s", tostring(err)) end
  end)
end)

---------------------------------------------------------------- F8: helicopter repair status
-- Host only: one line per helicopter with its team and the game's own repair state.
RegisterKeyBind(Key.F8, function()
  ExecuteInGameThread(function()
    local ok, err = pcall(function()
      local helis = FindAllOf("BP_HelicopterBase_C") or {}
      local n = 0
      for _, v in pairs(helis) do
        if valid(v) then
          n = n + 1
          local l = v:K2_GetActorLocation()
          local pteam = v.PawnDataComponent and v.PawnDataComponent.Team
          log("heli %d at %.0f, %.0f, %.0f: Team %s, pilot-team %s, piloted %s, AutoRepairInBase %s, " ..
              "CanRepair %s, InRepairZoneServer %s, Repairing %s, RepairProgress %.1f/%.1f",
              n, l.X, l.Y, l.Z, tostring(v.Team), tostring(pteam), tostring(v.bIsPawnControlled),
              tostring(v.UseAutoRepairInBase), tostring(v.CanRepair), tostring(v.InRepairZoneServer),
              tostring(v.Repairing), v.RepairProgress or -1, v.TimeToRepair or -1)
        end
      end
      if n == 0 then log("F8: no helicopters found") end
    end)
    if not ok then log("F8 failed: %s", tostring(err)) end
  end)
end)

------------------------------------------------------------------------ F9: log the player's position
-- Prints X, Y, Z and yaw in the same form as the TANKS entries, so lines can be pasted in.
RegisterKeyBind(Key.F9, function()
  ExecuteInGameThread(function()
    local ok, err = pcall(function()
      local pc
      for _, c in pairs(FindAllOf("BP_GameController_C") or {}) do
        if valid(c) and c:IsLocalController() then pc = c; break end
      end
      if not pc then log("F9: no local player controller"); return end
      local pawn = pc:K2_GetPawn()
      if not valid(pawn) then log("F9: no pawn (dead or spectating?)"); return end
      local loc, rot = pawn:K2_GetActorLocation(), pawn:K2_GetActorRotation()
      log("player at %.2f, %.2f, %.2f  yaw %.1f  ->  X = %.2f, Y = %.2f, Z = %.2f, Yaw = %.0f",
          loc.X, loc.Y, loc.Z, rot.Yaw, loc.X, loc.Y, loc.Z, rot.Yaw)
    end)
    if not ok then log("F9 failed: %s", tostring(err)) end
  end)
end)

log("loaded")
