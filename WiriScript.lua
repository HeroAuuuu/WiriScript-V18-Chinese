--[[
--------------------------------
THIS FILE IS PART OF WIRISCRIPT
         Nowiry#2663
--------------------------------
]]

local scriptdir = filesystem.scripts_dir()
if not filesystem.exists(scriptdir .. "lib/wiriscript") then
	error("required directory not found: lib/wiriscript")
	
elseif not filesystem.exists(scriptdir .. "lib/wiriscript/functions.lua") then
	error("required file not found: lib/wiriscript/functions.lua")

elseif not filesystem.exists(scriptdir .. "lib/wiriscript/ufo.lua") then
	error("required file not found: lib/wiriscript/ufo.lua")

elseif not filesystem.exists(scriptdir .. "lib/wiriscript/guided_missile.lua") then
	error("required file not found: lib/wiriscript/guided_missile.lua")
end

if not filesystem.exists(scriptdir .. "lib/lua_imGUI V2-1.lua") then
	error("required file not found: lib/lua_imGUI V2-1.lua")
end

require "wiriscript.functions"
require "lua_imGUI V2-1"
json = require "pretty.json"
ufo = require "wiriscript.ufo"
guidedMissile = require "wiriscript.guided_missile"
UI = UI.new()

gVersion = 18
gShowingIntro = false
gWorldPtr = memory.rip(memory.scan("48 8B 05 ? ? ? ? 45 ? ? ? ? 48 8B 48 08 48 85 C9 74 07") + 3)
gWorldPtr = memory.read_long(gWorldPtr)
if gWorldPtr == 0 then 
	error("特征码扫描失败: CPedFactory") 
end

-----------------------------------
-- FILE SYSTEM
-----------------------------------

local wiriDir = scriptdir .. "WiriScript\\"
local languageDir = wiriDir .. "language\\"
local configFile = wiriDir .. "config.ini"

if not filesystem.exists(wiriDir) then
	filesystem.mkdir(wiriDir)
end

if not filesystem.exists(languageDir) then
	filesystem.mkdir(languageDir)
end

if not filesystem.exists(wiriDir .. "profiles") then
	filesystem.mkdir(wiriDir .. "profiles")
end

if not filesystem.exists(wiriDir .. "handling") then
	filesystem.mkdir(wiriDir .. "handling") 
end

if filesystem.exists(wiriDir .. "logo.png") then
	os.remove(wiriDir .. "logo.png")
end

if filesystem.exists(filesystem.resources_dir() .. "wiriscript_logo.png") then
	os.remove(filesystem.resources_dir() .. "wiriscript_logo.png")
end

-----------------------------------
-- CONSTANTS
-----------------------------------

-- label =  "weapon ID"
gWeapons = {												
	WT_PIST 		= "weapon_pistol",
	WT_STUN			= "weapon_stungun",
	WT_RAYPISTOL	= "weapon_raypistol",
	WT_RIFLE_SCBN 	= "weapon_specialcarbine",
	WT_SG_PMP		= "weapon_pumpshotgun",
	WT_MG			= "weapon_mg",
	WT_RIFLE_HVY 	= "weapon_heavysniper",
	WT_MINIGUN		= "weapon_minigun",
	WT_RPG			= "weapon_rpg",
	WT_RAILGUN 		= "weapon_railgun",
	WT_CMPGL 		= "weapon_compactlauncher",
	WT_EMPL 		= "weapon_emplauncher"
}


gMeleeWeapons = {
	WT_UNARMED 		= "weapon_unarmed",
	WT_KNIFE		= "weapon_knife",
	WT_MACHETE		= "weapon_machete",
	WT_BATTLEAXE	= "weapon_battleaxe",
	WT_WRENCH		= "weapon_wrench",
	WT_HAMMER		= "weapon_hammer",
	WT_BAT			= "weapon_bat"
}


-- here you can modify which peds are available to choose
-- ["name shown in Stand"] = "ped model ID"
gPedModels = {
	["犯人"] 				= "s_m_y_prismuscl_01",
	["哑剧演员"] 					= "s_m_y_mime",
	["宇航员"] 				= "s_m_m_movspace_01",
	["特警"] 					= "s_m_y_swat_01",
	["巴拉斯小混混"] 			= "csb_ballasog",
	["海军陆战队"] 					= "csb_ramp_marine",
	["女警官"] 	= "s_f_y_cop_01",
	["男警官"] 	= "s_m_y_cop_01",
	["上帝"] 					= "u_m_m_jesus_01",
	["丧尸"] 					= "u_m_y_zombie_01",
	["无赖战士"] 				= "u_m_y_juggernaut_01",
	["小丑"] 					= "s_m_y_clown_01",
	["站街女"] 					= "s_f_y_hooker_01",
	["邪教徒"] 				= "a_m_y_acult_01"
}


-- [name] = {"keyboard; controller", index}
gImputs = {
	INPUT_JUMP						= {"Spacebar; X", 22},
	INPUT_VEH_ATTACK				= {"Mouse L; RB", 69},
	INPUT_VEH_AIM					= {"Mouse R; LB", 68},
	INPUT_VEH_DUCK					= {"X; A", 73},
	INPUT_VEH_HORN					= {"E; L3", 86},
	INPUT_VEH_CINEMATIC_UP_ONLY 	= {"Numpad +; none", 96},
	INPUT_VEH_CINEMATIC_DOWN_ONLY 	= {"Numpad -; none", 97}
}

gProofs = {
	bullet 		= false,
	fire 		= false,
	explosion 	= false,
	collision 	= false,
	melee 		= false,
	steam 		= false,
	drown 		= false
}

gSound = 
{
	zoomOut 			= Sound.new("zoom_out_loop", "dlc_xm_orbital_cannon_sounds"),
	activating			= Sound.new("cannon_activating_loop", "dlc_xm_orbital_cannon_sounds"),
	backgroundLoop 		= Sound.new("background_loop", "dlc_xm_orbital_cannon_sounds"),
	fireLoop 			= Sound.new("cannon_charge_fire_loop", "dlc_xm_orbital_cannon_sounds")
}

NULL = 0

---------------------------------
-- CONFIG
---------------------------------

if filesystem.exists(configFile) then
	local loaded = ini.load(configFile)
	for s, t in pairs(loaded) do
		for k, v in pairs(t) do
			if gConfig[ s ] and gConfig[ s ][ k ] ~= nil then
				gConfig[ s ][ k ] = v
			end
		end
	end
end

if gConfig.general.language ~= "english" then
	local file = languageDir .. gConfig.general.language .. ".json"
	if not filesystem.exists(file) then
		notification.help("Translation file not found", HudColour.red)
	else
		local result = parseJsonFile(file, false)
		if result then
			menunames = result
		end
	end
end

-----------------------------------
-- HTTP
-----------------------------------


async_http.init("pastebin.com", "/raw/EhH1C6Dh", function(output)
	local cversion = tonumber(output)
	if cversion then 
		if cversion > gVersion then	
    	    notification.normal("WiriScript ~g~v" .. output .. "~s~" .. " is available", HudColour.purpleDark)
			menu.hyperlink(menu.my_root(), "How to get WiriScript v" .. output, "https://cutt.ly/get-wiriscript", "")
    	end
	end
end, function()
	util.log("[WiriScript] Failed to check for updates.")
end)
async_http.dispatch()


async_http.init("pastebin.com", "/raw/WMUmGzNj", function(output)
	if string.match(output, '^#') ~= nil then
		local msg = string.match(output, '^#(.+)')
        notification.normal("~b~" .. "~italic~" .. "Nowiry: " .. "~s~" .. msg, HudColour.purpleDark)
    end
end, function()
    util.log("[WiriScript] Failed to get message.")
end)
async_http.dispatch()

-------------------------------------
-- INTRO
-------------------------------------

local function ADD_TEXT_TO_SINGLE_LINE(scaleform, text, font, colour)
	GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "ADD_TEXT_TO_SINGLE_LINE")
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING(text)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING(font)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING(colour)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_BOOL(true)
	GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
end


local function HIDE(scaleform)
	GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "HIDE")
	GRAPHICS.BEGIN_TEXT_COMMAND_SCALEFORM_STRING("STRING")
	HUD.ADD_TEXT_COMPONENT_SUBSTRING_PLAYER_NAME("presents")
	GRAPHICS.END_TEXT_COMMAND_SCALEFORM_STRING()
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.16)
	GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
end


local function SETUP_SINGLE_LINE(scaleform)
	GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SETUP_SINGLE_LINE")
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.5)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.5)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(70.0)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(125.0)
	GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("left")
	GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
end


if SCRIPT_MANUAL_START and gConfig.general.showintro then
	gShowingIntro = true
	local state = 0
	local sTime = cTime()

	AUDIO.PLAY_SOUND_FROM_ENTITY(-1, "clown_die_wrapper", PLAYER.PLAYER_PED_ID(), "BARRY_02_SOUNDSET", true, 20)
	
	util.create_tick_handler(function()	
		local scaleform = GRAPHICS.REQUEST_SCALEFORM_MOVIE("OPENING_CREDITS")	
		while not GRAPHICS.HAS_SCALEFORM_MOVIE_LOADED(scaleform) do
			wait()
		end
		
		HUD.HIDE_HUD_AND_RADAR_THIS_FRAME()
		if state == 0 then
			SETUP_SINGLE_LINE(scaleform)
			ADD_TEXT_TO_SINGLE_LINE(scaleform, 'a', "$font5", "HUD_COLOUR_WHITE")
			ADD_TEXT_TO_SINGLE_LINE(scaleform, "nowiry", "$font2", "HUD_COLOUR_BLUE")
			ADD_TEXT_TO_SINGLE_LINE(scaleform, "production", "$font5", "HUD_COLOUR_WHITE")

			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_SINGLE_LINE")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_CREDIT_BLOCK")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.5)
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			AUDIO.PLAY_SOUND_FROM_ENTITY(-1, "Pre_Screen_Stinger", PLAYER.PLAYER_PED_ID(), "DLC_HEISTS_FINALE_SCREEN_SOUNDS", true, 20)
			state = 1
			sTime = cTime()
		end

		if cTime() - sTime >= 4000 and state == 1 then
			HIDE(scaleform)
			state = 2
			sTime = cTime()
		end

		if cTime() - sTime >= 3000 and state == 2 then
			SETUP_SINGLE_LINE(scaleform)
			ADD_TEXT_TO_SINGLE_LINE(scaleform, "wiriscript", "$font2", "HUD_COLOUR_BLUE")
			ADD_TEXT_TO_SINGLE_LINE(scaleform, 'v' .. gVersion, "$font5", "HUD_COLOUR_WHITE")
			
			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_SINGLE_LINE")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_CREDIT_BLOCK")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.5)
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			AUDIO.PLAY_SOUND_FROM_ENTITY(-1, "SPAWN", PLAYER.PLAYER_PED_ID(), "BARRY_01_SOUNDSET", true, 20)
			state = 3
			sTime = cTime()
		end

		if cTime() - sTime >= 4000 and state == 3 then
			HIDE(scaleform)
			state = 4
			sTime = cTime()
		end
		if cTime() - sTime >= 3000 and state == 4 then
			gShowingIntro = false
			return false
		end

		GRAPHICS.DRAW_SCALEFORM_MOVIE_FULLSCREEN(scaleform, 255, 255, 255, 255, 0)
		return true
	end)
end
	
---------------------
---------------------
-- SETTINGS
---------------------
---------------------

local settings = menu.list(menu.my_root(), "设置", {"settings"}, "")
menu.divider(settings, "设置")

menu.action(settings, menuname("Settings", "保存设置"), {}, "", function()
	ini.save(configFile, gConfig)
	notification.normal("配置已保存")
end)

-- language settings
local languageSettings = menu.list(settings, "语言")
menu.divider(languageSettings, "语言")


menu.action(languageSettings, "创建新的翻译", {}, "创建一个文件，你可以用来制作一个新的WiriScript翻译", function()
	local file = wiriDir .. "new translation.json"
	local content = json.stringify(features, nil, 4)
	file = io.open(file,'w')
	file:write(content)
	file:close()
	notification.normal("文件：新的translation.json已经创建")
end)

if gConfig.general.language ~= "english" then
	menu.action(languageSettings, "更新翻译", {}, "创建一个更新的翻译文件", function()
		local t = swapValues(features, menunames)
		local file = wiriDir .. gConfig.general.language .. " (update).json"
		local content = json.stringify(t, nil, 4)
		file = io.open(file, 'w')
		file:write(content)
		file:close()
		notification.normal("文件: " .. gConfig.general.language .. " (update).json，被创建")
	end)
end

menu.divider(languageSettings, "-----")

if gConfig.general.language ~= "english" then
	local actionId
	actionId = menu.action(languageSettings, "English", {}, "", function()
		gConfig.general.language = "english"
		ini.save(configFile, gConfig)
		menu.show_warning(actionId, CLICK_MENU, "你想现在重新启动脚本以应用语言设置吗？", function()
			util.stop_script()
		end)
	end)
end

for _, path in ipairs(filesystem.list_files(languageDir)) do
	local filename, ext = string.match(path, '^.+\\(.+)%.(.+)$')
	if ext == "json" and gConfig.general.language ~= filename then
		local actionId
		actionId = menu.action(languageSettings, capitalize(filename), {}, "", function()
			gConfig.general.language = filename
			ini.save(configFile, gConfig)
            menu.show_warning(actionId, CLICK_MENU, "你想现在重新启动脚本以应用语言设置吗？", function()
                util.stop_script()
            end)
		end)
	end
end

-- display health text
menu.toggle(settings, menuname("Settings", "显示生命值文本"), {"displayhealth"}, "如果在使用时要显示生命值状况", function(toggle)
	gConfig.general.displayhealth = toggle
end, gConfig.general.displayhealth)

-- health text position
local healthtxt = menu.list(settings, menuname("Settings", "生命值文本的位置"), {}, "")
local _x, _y =  directx.get_client_size()

menu.slider(healthtxt, 'X', {"healthx"}, "", 0, _x, round(_x * gConfig.healthtxtpos.x) , 1, function(x)
	gConfig.healthtxtpos.x = round(x /_x, 4)
end)

menu.slider(healthtxt, 'Y', {"healthy"}, "", 0, _y, round(_y * gConfig.healthtxtpos.y), 1, function(y)
	gConfig.healthtxtpos.y = round(y /_y, 4)
end)

-- stand notifications
menu.toggle(settings, menuname("Settings", "Stand 通知"), {"standnotifications"}, "转变为Stand的通知外观", function(toggle)
	gConfig.general.standnotifications = toggle
end, gConfig.general.standnotifications)

menu.toggle(settings, menuname("Settings", "显示加入"), {}, "", function(toggle)
	gConfig.general.showintro = toggle
end, gConfig.general.showintro)

-- busted features settings
menu.toggle(settings, menuname("Settings", "删除的功能"), {}, "允许你使用一些以前删除的功能。需要保存设置并重新启动", function(toggle)
	gConfig.general.bustedfeatures = toggle
	if gConfig.general.bustedfeatures then
		notification.help("请保存设置并重新启动脚本")
	end
end, gConfig.general.bustedfeatures)

-- constrols settings
local controlSettings = menu.list(settings, menuname("Settings", "按键设置") , {}, "")
menu.divider(controlSettings, menuname("Settings", "按键设置"))

local airstrikePlaneControl = menu.list(controlSettings, menuname("Settings - Controls", "空袭飞机"), {}, "")

for name, control in pairs(gImputs) do
	local keyboard, controller = control[1]:match('^(.+)%s?;%s?(.+)$')
	local strg = "键盘: ".. keyboard .. ", 控制器: " .. controller
	menu.action(airstrikePlaneControl, strg, {}, "", function()
		gConfig.controls.airstrikeaircraft = control[2]
		util.show_corner_help("按下 " .. ('~%s~ '):format(name) .. "使用空袭飞机")
	end)
end

local vehicleWeaponsControl = menu.list(controlSettings, menuname("Settings - Controls", "车载武器"), {}, "")

for name, control in pairs(gImputs) do
	local keyboard, controller = control[1]:match('^(.+)%s?;%s?(.+)$')
	local strg = "键盘: ".. keyboard .. ", 控制器: " .. controller
	menu.action(vehicleWeaponsControl, strg, {}, "", function()
		gConfig.controls.vehicleweapons = control[2]
		util.show_corner_help("按下 " .. ('~%s~ '):format(name) .. "使用车载武器")
	end)
end

-- UFO setttings
local ufoSettings = menu.list(settings, menuname("Settings", "UFO 设置"), {}, "")

menu.toggle(ufoSettings, menuname("UFO settings", "禁用玩家箱子"), {}, "", function(toggle)
	gConfig.ufo.disableboxes = toggle
end, gConfig.ufo.disableboxes)

menu.toggle(ufoSettings, menuname("UFO settings", "只针对玩家的车辆"), {}, "使得飞碟光束无视非玩家驾驶的车辆", function(toggle)
	gConfig.ufo.targetplayer = toggle
end, gConfig.ufo.targetplayer)


local vehicleGunSettings = menu.list(settings, menuname("Settings", "车辆发射枪"))
-- vehicle gun preview
menu.toggle(vehicleGunSettings, menuname("Settings", "禁用车辆枪预览"), {}, "", function(toggle)
	gConfig.vehiclegun.disablepreview = toggle
end, gConfig.vehiclegun.disablepreview)


-- handling editor settings
local handlingEditorSettings = menu.list(settings, menuname("Settings", "载具信息编辑器"), {}, "")
menu.divider(handlingEditorSettings, menuname("Settings", "载具信息编辑器"))

local onfocuscolour = Colour.normalize(gConfig.onfocuscolour)
menu.colour(handlingEditorSettings, menuname("Settings - Handling Editor", "聚焦的文本颜色"), {"onfocuscolour"}, "", onfocuscolour, false, function(new)
	onfocuscolour = new
	gConfig.onfocuscolour = Colour.toInt(new)
end)

local highlightcolour = Colour.normalize(gConfig.highlightcolour)
menu.colour(handlingEditorSettings, menuname("Settings - Handling Editor", "突出显示的颜色"), {"highlightcolour"}, "", highlightcolour, false, function(new)
	highlightcolour = new
	gConfig.highlightcolour = Colour.toInt(new)
end)

local buttonscolour = Colour.normalize(gConfig.buttonscolour)
menu.colour(handlingEditorSettings, menuname("Settings - Handling Editor", "按钮颜色"), {"buttonscolour"}, "", buttonscolour, false, function(new)
	buttonscolour = new
	gConfig.buttonscolour = Colour.toInt(new)
end)

-------------------------------------
-- SPOOFING PROFILE
-------------------------------------

local recycleBin = 0
local profilesArray = {}
local profilesRoot = menu.list(menu.my_root(), menuname("Spoofing Profile", "虚假资料"), {"profiles"}, "")

function add_profile(profile, name)
	local spoofName = true
	local spoofRid = true
	local spoofCrew = false
	local name = name or profile.name
	local rid = profile.rid
	local profileActions = menu.list(profilesRoot, name, {"概况" .. name}, "")

	menu.divider(profileActions, name)

	menu.action(profileActions, menuname("Spoofing Profile - Profile", "启用虚假配置文件"), {"enable" .. name}, "", function()
		if spoofName then
			menu.trigger_commands("spoofedname " .. profile.name)
			menu.trigger_commands("spoofname on")
		end		
		if spoofRid then
			menu.trigger_commands("spoofedrid " .. rid)
			menu.trigger_commands("spoofrid hard")
		end		
		if spoofCrew and profile.crew and not equals(profile.crew, {}) then
			menu.trigger_commands("crewid " 		.. profile.crew.icon)
			menu.trigger_commands("crewtag " 		.. profile.crew.tag)
			menu.trigger_commands("crewname " 		.. profile.crew.name)
			menu.trigger_commands("crewmotto " 		.. profile.crew.motto)
			menu.trigger_commands("crewaltbadge " 	.. string.lower( profile.crew.alt_badge ))
			menu.trigger_commands("crew on")
		end
		gUsingProfile = true 
	end)

	menu.action(profileActions, menuname("Spoofing Profile - Profile", "删除"), {}, "", function()
		os.remove(wiriDir .. "profiles\\" .. name .. ".json")
		local restore_profile
		restore_profile = menu.action(recycleBin, name, {}, "点击恢复", function()
			save_profile(profile)
			menu.delete(restore_profile)
		end)
		profilesArray[ getKey(profilesArray, profile) ] = nil
		menu.delete(profileActions)
		notification.normal("配置文件被移至回收站")
	end)

	-- name spoofing toggle
	menu.toggle(profileActions, menuname("Spoofing Profile - Profile", "名称"), {}, "", function(toggle)
		spoofName = toggle
	end, spoofName)

	-- RID spoofing toggle
	menu.toggle(profileActions, menuname("Spoofing Profile - Profile", "SCID") .. ' ' .. rid, {}, "", function(toggle)
		spoofRid = toggle
	end, spoofRid)

	if profile.crew and not equals(profile.crew, {}) and profile.crew.icon ~= 0 then	
		-- crew spoofing toggle
		menu.toggle(profileActions, menuname("Spoofing Profile - Profile", "虚假帮会"), {}, "", function(toggle)
			spoofCrew = toggle
		end, spoofCrew)
		-- crew information
		local crewinfo = menu.list(profileActions, menuname("Spoofing Profile - Profile", "帮会"))
		for k, value in pairsByKeys(profile.crew) do
			local name = k:gsub('_', ' ')
			name = capEachWord(name)
			menu.action(crewinfo, name .. ": " .. value, {}, "点击复制到剪贴板", function()
				util.copy_to_clipboard(v)
			end)
		end
	elseif profile.crew and not equals(profile.crew, {}) and profile.crew.icon == 0 then
		spoofCrew = true
		menu.toggle(profileActions, menuname("Spoofing Profile - Profile", "帮会恶搞"), {}, "", function(toggle)
			spoofCrew = toggle
		end, true)
		menu.action(profileActions, menuname("Spoofing Profile - Profile", "帮会") .. ": " .. "None", {}, "", function()end)
	end
end


function save_profile(profile)
	local key = profile.name 
	if includes(profilesArray, profile) then
		notification.help("这个虚假资料已经存在", HudColour.red)
		return
	elseif profilesArray[ profile.name ] ~= nil then
		local n = 0
		for k in pairs(profilesArray) do
			if k:match(profile.name) then
				n = n + 1
			end
		end
		key = profile.name .. " (" .. (n + 1) .. ')' 
	end
	profilesArray[ key ] =  profile
	local file = io.open(wiriDir .. "overview\\" .. key .. ".json", 'w')
	local content = json.stringify(profile, nil, 4)
	file:write(content)
	file:close()
	add_profile(profile, key)
	notification.normal("创建虚假资料")
end


menu.action(profilesRoot, menuname("Spoofing Profile", "禁用虚假配置文件"), {"disableprofile"}, "", function()
	if gUsingProfile then
		menu.trigger_commands("spoofname off; spoofrid off; crew off")
		gUsingProfile = false
	else
		notification.help("你没有使用任何虚假配置文件", HudColour.red)
	end
end)

-- add spoofing profile
local newName = ""
local newRid = 0
local newprofile = menu.list(profilesRoot, menuname("Spoofing Profile", "添加资料"), {"addprofile"}, "手动创建一个新的虚假配置文件")
menu.divider(newprofile, menuname("Spoofing Profile", "添加资料") )

menu.text_input(newprofile, menuname("Spoofing Profile - Add Profile", "名称"), {"profilename"}, "输入配置文件的名称", function(name)
	newName = name
end)

menu.text_input(newprofile, menuname("Spoofing Profile - Add Profile", "SCID"), {"profilerid"}, "输入配置文件的SCID", function(rid)
	if not tonumber(rid) then
		notification.help("SCID必须是数字", HudColour.red)
	else
		newRid = tonumber(rid)
	end
end)

menu.action(newprofile, menuname("Spoofing Profile - Add Profile", "保存虚假配置文件"), {"saveprofile"}, "", function()
	if not newName or not newRid then
		notification.help("名称和SCID是必填的", HudColour.red)
		return
	end
	local profile = {name = newName, rid = newRid}
	save_profile(profile)
end)

recycleBin = menu.list(profilesRoot, menuname("Spoofing Profile", "回收站"), {}, "暂时存储已删除的配置文件。当脚本停止时，配置文件将被彻底删除")
menu.divider(profilesRoot, menuname("Spoofing Profile", "虚假配置文件") )

local function isProfileCrewValid(crewTable)
	if crewTable == nil then
		return true
	end
	if type(crewTable) ~= "table" then
		return false
	end
	if not equals(crewTable, {}) then
		if (
			type(crewTable.icon) 		~= "number" or
			type(crewTable.name) 		~= "string" or
			type(crewTable.tag) 		~= "string" or
			type(crewTable.rank)		~= "string"	or
			type(crewTable.motto) 		~= "string"	or
			type(crewTable.alt_badge) 	~= "string"
		) then
			return false
		end
	end
	return true
end

for _, path in ipairs(filesystem.list_files(wiriDir .. "profiles")) do
	local filename, ext = string.match(path, '^.+\\(.+)%.(.+)$')
	if ext == "json" then
		local profile = parseJsonFile(path, false)
		local isProfileValid = true
		
		if not profile then
			isProfileValid = false
		elseif not tonumber(profile.rid) or not profile.name then
			isProfileValid = false
		elseif not isProfileCrewValid(profile.crew) then
			isProfileValid = false
		end

		if isProfileValid then
			profile.rid = tonumber(profile.rid)
			profilesArray[ filename ] = profile
			add_profile(profile, filename)
		else
			notification.help(filename .. ".json是一个无效的虚假配置文件.", HudColour.red)
		end
	else 
		os.remove(path) 
	end
end


generate_features = function(pId)
	menu.divider(menu.player_root(pId), "WiriScript")		
	
	developer(menu.action, menu.player_root(pId), "CPed", {}, "", function()
		local addr = entities.handle_to_pointer(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		util.copy_to_clipboard(string.format('%X', addr))
	end)

	-------------------------------------
	-- CREATE SPOOFING PROFILE
	-------------------------------------

	menu.action(menu.player_root(pId), menuname("Player", "创建虚假档案"), {}, "", function()
		local profile = {name = PLAYER.GET_PLAYER_NAME(pId), rid = players.get_rockstar_id(pId), crew = getPlayerClan(pId)}
		save_profile(profile)
	end)

	---------------------
	---------------------
	-- TROLLING 
	---------------------
	---------------------

	local trollingOpt = menu.list(menu.player_root(pId), menuname("Player", "恶搞选项"), {}, "")	

	-------------------------------------
	-- EXPLOSIONS
	-------------------------------------
	
	local customExplosion = menu.list(trollingOpt, menuname("Trolling", "自定义爆炸"), {}, "")
	local explosions = {
		audible = true,
		speed = 300,
		owned = false,
		type = 0,
		invisible = false
	}
	function explosions:explode_player(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		pos.z = pos.z - 1.0
		if not self.owned then
			FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, self.type, 1.0, self.audible, self.invisible, 0, false)
		else
			FIRE.ADD_OWNED_EXPLOSION(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z, self.type, 1.0, self.audible, self.invisible, 0, true)
		end
	end
	
	menu.divider(customExplosion, menuname("Trolling", "自定义爆炸"))

	menu.slider(customExplosion, menuname("Trolling - Custom Explosion", "爆炸类型"), {"explosion"},"", 0, 72, 0, 1, function(value)
		explosions.type = value
	end)

	menu.toggle(customExplosion, menuname("Trolling - Custom Explosion", "不可见"), {}, "", function(toggle)
		explosions.invisible = toggle
	end)
	
	menu. toggle(customExplosion, menuname("Trolling - Custom Explosion", "声音"), {}, "", function(toggle)
		explosions.audible = toggle
	end, true)
	
	menu.toggle(customExplosion, menuname("Trolling - Custom Explosion", "自己的爆炸"), {}, "", function(toggle)
		explosions.owned = toggle
	end)
	
	menu.action(customExplosion, menuname("Trolling - Custom Explosion", "爆炸"), {"customexplode"}, "", function()
		explosions:explode_player(pId)
	end)
	
	menu.slider(customExplosion, menuname("Trolling - Custom Explosion", "循环速度"), {"speed"}, "", 50, 1000, 300, 10, function(value) --changes the speed of loop
		explosions.speed = value
	end)
	
	menu.toggle_loop(customExplosion, menuname("Trolling - Custom Explosion", "爆炸循环"), {"customloop"}, "", function()
		explosions:explode_player(pId)
		wait(explosions.speed)
	end)
	
	menu.toggle_loop(trollingOpt, menuname("Trolling", "水循环"), {"waterloop"}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		pos.z = pos.z - 1.0
		FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 13, 1.0, true, false, 0, false)
	end)

	menu.toggle_loop(trollingOpt, menuname("Trolling", "火循环"), {"flameloop"}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		pos.z = pos.z - 1.0
		FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 12, 1.0, true, false, 0, false)
	end)

	-------------------------------------
	-- KILL AS THE ORBITAL CANNON
	-------------------------------------

	menu.action(trollingOpt, menuname("Trolling", "使用天基炮击杀玩家"), {"orbital"}, "", function()
		if players.is_in_interior(pId) then
			notification.help("玩家在室内", HudColour.red)
			return
		end
		
		if gUsingOrbitalCannon then
			CAM.DO_SCREEN_FADE_OUT(500)
			wait(1000)
			gCannonTarget = pId
			CAM.DO_SCREEN_FADE_IN(500)
			return
		end
		
		gUsingOrbitalCannon = true
		gCannonTarget = pId
		local height
		local cam
		local zoom = 0.0
		local lastZoom
		local scaleform
		local maxFov = 110
		local minFov = 25
		local fov = maxFov
		
		local set_cannon_cam_zoom = function ()
			if not PAD._IS_USING_KEYBOARD(2) then
				return
			end
			if PAD.IS_CONTROL_JUST_PRESSED(2, 241) then
				if zoom < 1.0 then
					zoom = zoom + 0.25
				end
			end
			if PAD.IS_CONTROL_JUST_PRESSED(2, 242) then
				if zoom > 0.0 then
					zoom = zoom - 0.25
				end
			end
	
			local fovLimit = minFov + (maxFov - minFov) * (1 - zoom)
			fov = increment(fov, 1.0, fovLimit)		
			if zoom ~= lastZoom then
				gSound.zoomOut:play()
			
				GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SET_ZOOM_LEVEL")
				GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(zoom)
				GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
				lastZoom = zoom
			end
		
			if fov ~= fovLimit then
				CAM.SET_CAM_FOV(cam, fov)
			else
				gSound.zoomOut:stop()
			end
		end

		AUDIO.REQUEST_SCRIPT_AUDIO_BANK("DLC_CHRISTMAS2017/XM_ION_CANNON", false, -1)
		AUDIO.START_AUDIO_SCENE("dlc_xm_orbital_cannon_camera_active_scene")
		gSound.activating:play()
		
		CAM.DO_SCREEN_FADE_OUT(500)
		wait(1000)
		CAM.DESTROY_ALL_CAMS(true)
		cam = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", false)
		CAM.SET_CAM_ROT(cam, -90.0, 0.0, 0.0, 2)
		CAM.SET_CAM_FOV(cam, fov)
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(gCannonTarget))
		height = pos.z + 150
		CAM.SET_CAM_COORD(cam, pos.x, pos.y, height)
		CAM.SET_CAM_ACTIVE(cam, true)
		CAM.RENDER_SCRIPT_CAMS(true, false, 3000, true, false, 0)
		GRAPHICS.ANIMPOSTFX_PLAY("MP_OrbitalCannon", 0, true)
		
		ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), true)
		STREAMING.SET_FOCUS_POS_AND_VEL(pos.x, pos.y, pos.z, 5.0, 0.0, 0.0)
		menu.trigger_commands("becomeorbitalcannon on")
		wait(1000)
		CAM.DO_SCREEN_FADE_IN(500)

		scaleform = GRAPHICS.REQUEST_SCALEFORM_MOVIE("ORBITAL_CANNON_CAM")
		while not GRAPHICS.HAS_SCALEFORM_MOVIE_LOADED(scaleform) do
			wait()
		end

		GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SET_ZOOM_LEVEL")
		GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(1.0)
		GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

		gSound.activating:stop()
		gSound.backgroundLoop:play()
		AUDIO.PLAY_SOUND_FRONTEND(-1, "cannon_active", "dlc_xm_orbital_cannon_sounds", true);
		
		local countdown = 3 -- seconds
		local counting = false
		local sTime
		local state = 0
		local chargeLvl = 1.0
		local targetCamHeight = height

		while true do
			wait()
			PAD.DISABLE_CONTROL_ACTION(2, 75, true)

			local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(gCannonTarget)
			local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
			STREAMING.SET_FOCUS_POS_AND_VEL(pos.x, pos.y, pos.z, 5.0, 0.0, 0.0)
			CAM.SET_CAM_COORD(cam, pos.x, pos.y, pos.z + 150)
			HUD.DISPLAY_RADAR(false)
			disablePhone()

			local hudColour = ENTITY.IS_ENTITY_DEAD(targetPed) and HudColour.greyDrak or HudColour.red
			drawLockonSprite(targetPed, hudColour)

			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SET_STATE")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_INT(3)
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			if state == 0 then
				if PAD.IS_DISABLED_CONTROL_PRESSED(0, 69) then
					if not counting then
						startTime = cTime()
						gSound.fireLoop:play()
						counting = true
					end
					if coutdown ~= 0 then
						if (cTime() - startTime) >= 1000 then
							countdown = countdown - 1
							startTime = cTime()
						end

						GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SET_COUNTDOWN")
						GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_INT(countdown)
						GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
					end
				else
					AUDIO.SET_VARIABLE_ON_SOUND(gSound.fireLoop.Id, "Firing", 0.0);
					gSound.fireLoop:stop()
					counting = false
					countdown = 3
				end

				set_cannon_cam_zoom()
				if countdown == 0 then
					gSound.fireLoop:stop()
					state = 1
				end
			elseif state == 1 then
				chargeLvl = 0.0
				local effect = Effect.new("scr_xm_orbital", "scr_xm_orbital_blast")
				STREAMING.REQUEST_NAMED_PTFX_ASSET(effect.asset)
				while not STREAMING.HAS_NAMED_PTFX_ASSET_LOADED(effect.asset) do
					wait()
				end

				FIRE.ADD_OWNED_EXPLOSION(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z, 59, 1.0, true, false, 1.0)
				GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
				GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD(
					effect.name, 
					pos.x,
					pos.y,
					pos.z, 
					0.0, 
					0.0, 
					0.0,
					1.0, 
					false, false, false, true
				)
				AUDIO.PLAY_SOUND_FROM_COORD(-1, "DLC_XM_Explosions_Orbital_Cannon", pos.x, pos.y, pos.z, 0, true, 0, false)
				CAM.SHAKE_CAM(cam, "GAMEPLAY_EXPLOSION_SHAKE", 1.5)
				
				sTime = cTime()
				state = 2
			elseif state == 2 and (cTime() - sTime) > 1000 then
				CAM.DO_SCREEN_FADE_OUT(500)
				sTime = cTime()
				state = 3
			elseif state == 3 and (cTime() - sTime) > 600 then
				break
			end
			
			-- terminates the loop when
			-- 1) the target leaves session
			-- 2) F button is just pressed
			if not NETWORK.NETWORK_IS_PLAYER_CONNECTED(gCannonTarget) or PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, 75) then
				sTime = cTime()
				state = 2
			end
			
			if instructional:begin() then
				instructional.add_control(75, "BB_LC_EXIT")
				instructional.add_control(69, "ORB_CAN_FIRE")
				if PAD._IS_USING_KEYBOARD(0) then
					instructional.add_control_group(29, "ORB_CAN_ZOOM")
				end
        		instructional:set_background_colour(0, 0, 0, 80)
        		instructional:draw()
			end

			PAD.DISABLE_CONTROL_ACTION(2, 85, true)
			HUD._HUD_WEAPON_WHEEL_IGNORE_SELECTION()

			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SET_CHARGING_LEVEL")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(chargeLvl)
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()

			GRAPHICS.SET_SCRIPT_GFX_DRAW_ORDER(0)
			GRAPHICS.DRAW_SCALEFORM_MOVIE_FULLSCREEN(scaleform, 255, 255, 255, 255, 0)
			GRAPHICS.RESET_SCRIPT_GFX_ALIGN()
		end
		
		gSound.backgroundLoop:stop()
		ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), false)
		PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_ID(), false)
		menu.trigger_commands("becomeorbitalcannon off")

		GRAPHICS.ANIMPOSTFX_STOP("MP_OrbitalCannon")
		AUDIO.STOP_AUDIO_SCENE("dlc_xm_orbital_cannon_camera_active_scene")
		AUDIO.RELEASE_NAMED_SCRIPT_AUDIO_BANK("DLC_CHRISTMAS2017/XM_ION_CANNON")
		
		CAM.RENDER_SCRIPT_CAMS(false, false, 0, true, false, 0)
		CAM.SET_CAM_ACTIVE(cam, false)
		CAM.DESTROY_CAM(cam, false)
		HUD.DISPLAY_RADAR(true)
		STREAMING.CLEAR_FOCUS()
		wait(800)
		CAM.DO_SCREEN_FADE_IN(500)
		
		gUsingOrbitalCannon = false
	end)

	-------------------------------------
	-- SHAKE CAMERA
	-------------------------------------

	menu.toggle_loop(trollingOpt, menuname("Trolling", "镜头摇动"), {"shake"}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		FIRE.ADD_OWNED_EXPLOSION(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z, 0, 0, false, true, 80)
		wait(150)
	end)

	-------------------------------------
	-- ATTACKER OPTIONS
	-------------------------------------

	local attacker = {
		spawned 	= {},
		stationary 	= false,
		godmode 	= false
	}

	local attackerOpt = menu.list(trollingOpt, menuname("Trolling", "攻击者选项"), {}, "")
	menu.divider(attackerOpt, menuname("Trolling", "攻击者选项"))

	menu.click_slider(attackerOpt, menuname("Trolling - Attacker Options", "发送攻击者"), {"attacker"}, "", 1, 15, 1, 1, function(quantity)
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		
		for i = 1, quantity do
			local weapon = attacker.weapon or getRandomValue(gWeapons)
			local model = attacker.model or getRandomValue(gPedModels)
			local modelHash = util.joaat(model)
			local weaponHash = util.joaat(weapon)
			local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
			pos.x = pos.x + math.random(-3,3)
			pos.y = pos.y + math.random(-3,3)
			pos.z = pos.z - 1.0
			
			requestModels(modelHash)
			local ped = entities.create_ped(0, modelHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
			insertOnce(attacker.spawned, modelHash)
			NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NETWORK.PED_TO_NET(ped), true)
			setEntityFaceEntity(ped, targetPed)
			WEAPON.GIVE_WEAPON_TO_PED(ped, weaponHash, -1, true, true)
			WEAPON.SET_CURRENT_PED_WEAPON(ped, weaponHash, false)
			ENTITY.SET_ENTITY_INVINCIBLE(ped, attacker.godmode)
			PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
			TASK.TASK_COMBAT_PED(ped, targetPed, 0, 16)
			PED.SET_PED_AS_ENEMY(ped, true)
			
			if attacker.stationary then 
				PED.SET_PED_COMBAT_MOVEMENT(ped, 0) 
			end
			
			PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, 1)
			PED.SET_PED_CONFIG_FLAG(ped, 208, true)
			relationship:hostile(ped)
			STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(modelHash)

			wait(100)
		end
	end)

	local attackerModelList = menu.list(attackerOpt, menuname("Trolling - Attacker Options", "设置模型") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "")
	menu.divider(attackerModelList, menuname("Trolling - Attacker Options", "攻击者模型列表"))
	
	menu.action(attackerModelList, HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "", function()
		attacker.model = nil
		menu.set_menu_name(attackerModelList, menuname("Trolling - Attacker Options", "设置模型") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"))
		menu.focus(attackerModelList)
	end)

	-- creates the attacker appearance list
	for k, model in pairsByKeys(gPedModels) do 
		menu.action(attackerModelList, menuname("Ped Models", k), {}, "", function()
			attacker.model = model
			menu.set_menu_name(attackerModelList, menuname("Trolling - Attacker Options", "设置模型") .. ": " .. menuname("Ped Models", k))
			menu.focus(attackerModelList)
		end)
	end

	menu.click_slider(attackerOpt, menuname("Trolling - Attacker Options", "克隆玩家"), {"enemyclone"}, "", 1, 15, 1, 1, function(quantity)
		local weapon = attacker.weapon or getRandomValue(gWeapons)
		local weaponHash = util.joaat(weapon)
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		for i = 1, quantity do
			pos.x = pos.x + math.random(-3,3)
			pos.y = pos.y + math.random(-3,3)
			pos.z = pos.z - 1.0
			local clone = PED.CLONE_PED(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), 1, 1, 1)
			insertOnce(attacker.spawned, ENTITY.GET_ENTITY_MODEL(clone))
			WEAPON.GIVE_WEAPON_TO_PED(clone, weaponHash, -1, true, true)
			WEAPON.SET_CURRENT_PED_WEAPON(clone, weaponHash, false)
			ENTITY.SET_ENTITY_COORDS(clone, pos.x, pos.y, pos.z)
			ENTITY.SET_ENTITY_INVINCIBLE(clone, attacker.godmode)
			PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(clone, true)
			TASK.TASK_COMBAT_PED(clone, PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), 0, 16)
			PED.SET_PED_COMBAT_ATTRIBUTES(clone, 46, 1)
			PED.SET_PED_CONFIG_FLAG(clone, 208, true)
			relationship:hostile(clone)

			if attacker.stationary then	
				PED.SET_PED_COMBAT_MOVEMENT(clone, 0) 
			end
			wait(100)
		end
	end)

	local attackerWeaponList = menu.list(attackerOpt, menuname("Trolling - Attacker Options", "设置武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "")	
	menu.divider(attackerWeaponList, HUD._GET_LABEL_TEXT("PM_WEAPONS"))
	
	local attackerMeleeList = menu.list(attackerWeaponList, HUD._GET_LABEL_TEXT("VAULT_WMENUI_8"), {}, "")
	menu.divider(attackerMeleeList, HUD._GET_LABEL_TEXT("VAULT_WMENUI_8"))
	
	-- creates the attacker melee weapon list
	for label, weapon in pairsByKeys(gMeleeWeapons) do
		local strg = HUD._GET_LABEL_TEXT(label)
		menu.action(attackerMeleeList,  strg, {}, "", function()
			attacker.weapon = weapon
			menu.set_menu_name(attackerWeaponList, menuname("Trolling - Attacker Options", "设置武器") .. ": " .. strg, {}, "")	
			menu.focus(attackerWeaponList)
		end)
	end

	menu.action(attackerWeaponList, HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "", function()
		attacker.weapon = nil
		menu.set_menu_name(attackerWeaponList, menuname("Trolling - Attacker Options", "设置武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "")	
		menu.focus(attackerWeaponList)
	end)

	-- creates the attacker weapon list
	for label, weapon in pairsByKeys(gWeapons) do
		local weaponName = HUD._GET_LABEL_TEXT(label)
		menu.action(attackerWeaponList, weaponName, {}, "", function()
			attacker.weapon = weapon
			menu.set_menu_name(attackerWeaponList, menuname("Trolling - Attacker Options", "设置武器") .. ": " .. weaponName)
			menu.focus(attackerWeaponList)
		end)
	end


	menu.toggle(attackerOpt, menuname("Trolling - Attacker Options", "冻结"), {}, "", function(toggle)
		attacker.stationary = toggle
	end)

	-------------------------------------
	-- ENEMY CHOP
	-------------------------------------

	menu.action(attackerOpt, menuname("Trolling - Attacker Options", "敌人的狗"), {"sendchop"}, "", function()
		local pedHash = util.joaat("a_c_chop")
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		pos.x = pos.x + math.random(-3,3)
		pos.y = pos.y + math.random(-3,3)
		pos.z = pos.z - 1.0
		
		requestModels(pedHash)
		local ped = entities.create_ped(28, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
		insertOnce(attacker.spawned, pedHash)
		ENTITY.SET_ENTITY_INVINCIBLE(ped, attacker.godmode)
		PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true)
		TASK.TASK_COMBAT_PED(ped, targetPed, 0, 16)
		PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, 1)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
		relationship:hostile(ped)
	end)

	-------------------------------------
	-- SEND POLICE CAR
	-------------------------------------

	menu.action(attackerOpt, menuname("Trolling - Attacker Options", "发送警车"), {"sendpolicecar"}, "", function()
		local vehicleHash = util.joaat("police3")
		local pedHash = util.joaat("s_m_y_cop_01")
		requestModels(vehicleHash, pedHash)
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		local vehicle = entities.create_vehicle(vehicleHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
		if not ENTITY.DOES_ENTITY_EXIST(vehicle) then
			return
		end

		local offset = getOffsetFromEntityGivenDistance(vehicle, 50.0)
		local outCoords = v3.new()
		local outHeading = memory.alloc()

		if PATHFIND.GET_CLOSEST_VEHICLE_NODE_WITH_HEADING(offset.x, offset.y, offset.z, outCoords, outHeading, 1, 3.0, 0) then
			ENTITY.SET_ENTITY_COORDS(vehicle, v3.getX(outCoords), v3.getY(outCoords), v3.getZ(outCoords))
			ENTITY.SET_ENTITY_HEADING(vehicle, memory.read_float(outHeading))
			VEHICLE.SET_VEHICLE_SIREN(vehicle, true)
			AUDIO.BLIP_SIREN(vehicle)
			VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
			ENTITY.SET_ENTITY_INVINCIBLE(vehicle, attacker.godmode)
			for seat = -1, 0 do
				local cop = entities.create_ped(5, pedHash, outCoords, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
				PED.SET_PED_INTO_VEHICLE(cop, vehicle, seat)
				PED.SET_PED_RANDOM_COMPONENT_VARIATION(cop, 0)
				local weapon = (seat == -1) and "weapon_pistol" or "weapon_pumpshotgun"
				WEAPON.GIVE_WEAPON_TO_PED(cop, util.joaat(weapon), -1, false, true)
				PED.SET_PED_NEVER_LEAVES_GROUP(cop, true)
				PED.SET_PED_COMBAT_ATTRIBUTES(cop, 1, true)
				PED.SET_PED_AS_COP(cop, true)
				ENTITY.SET_ENTITY_INVINCIBLE(cop, attacker.godmode)
				TASK.TASK_COMBAT_PED(cop, targetPed, 0, 16)
				PED.SET_PED_KEEP_TASK(cop, true)
				util.create_tick_handler(function()
					if TASK.GET_SCRIPT_TASK_STATUS(cop, 0x2E85A751) == 7 then
						TASK.CLEAR_PED_TASKS(cop)
						TASK.TASK_SMART_FLEE_PED(cop, PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), 1000.0, -1, false, false)
						PED.SET_PED_KEEP_TASK(cop, true)
						return false
					end
					return true
				end)
			end			
			AUDIO.PLAY_POLICE_REPORT("SCRIPTED_SCANNER_REPORT_FRANLIN_0_KIDNAP", 0.0)
		end

		v3.free(outCoords)
		memory.free(outHeading)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(vehicleHash)
	end)

	menu.toggle(attackerOpt, menuname("Trolling - Attacker Options", "无敌的攻击者"), {}, "", function(toggle)
		attacker.godmode = toggle
	end)

	menu.action(attackerOpt, menuname("Trolling - Attacker Options", "删除攻击者"), {}, "", function()
		for _, modelHash in ipairs(attacker.spawned) do
			deletePedsWithModelHash(modelHash)
		end
		attacker.spawned = {}
	end)

	-------------------------------------
	-- CAGE OPTIONS
	-------------------------------------

	local cage_options = menu.list(trollingOpt, menuname("Trolling", "笼子"), {}, "")
	menu.divider(cage_options, menuname("Trolling", "笼子"))

	local function trapcage(pId) -- small
		local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(p)
		local objHash = util.joaat("prop_gold_cont_01")
		requestModels(objHash)
		local obj = OBJECT.CREATE_OBJECT(objHash, pos.x, pos.y, pos.z - 1.0, true, false, false)
		ENTITY.FREEZE_ENTITY_POSITION(obj, true)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(objHash)
	end	
	
	local function trapcage_2(pId) -- tall
		local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(p)
		local objHash = util.joaat("prop_rub_cage01a")
		requestModels(objHash)
		local obj1 = OBJECT.CREATE_OBJECT(objHash, pos.x, pos.y, pos.z - 1.0, true, false, false)
		local obj2 = OBJECT.CREATE_OBJECT(objHash, pos.x, pos.y, pos.z + 1.2, true, false, false)
		ENTITY.SET_ENTITY_ROTATION(obj2, -180.0, ENTITY.GET_ENTITY_ROTATION(obj2).y, 90.0, 1, true)
		ENTITY.FREEZE_ENTITY_POSITION(obj1, true)
		ENTITY.FREEZE_ENTITY_POSITION(obj2, true)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
	end

	menu.action(cage_options, menuname("Trolling - Cage", "小笼子"), {"smallcage"}, "", function()
		local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		TASK.CLEAR_PED_TASKS_IMMEDIATELY(p)
		if PED.IS_PED_IN_ANY_VEHICLE(p) then return end
		trapcage(pId)
	end) 
	
	menu.action(cage_options, menuname("Trolling - Cage", "高笼子"), {"tallcage"}, "", function()
		local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		TASK.CLEAR_PED_TASKS_IMMEDIATELY(p)
		if PED.IS_PED_IN_ANY_VEHICLE(p) then return end
		trapcage_2(pId)
	end)

	-------------------------------------
	-- AUTOMATIC
	-------------------------------------

	-- 1) traps the player in cage
	-- 2) gets the position of the cage
	-- 3) if the current player position is 4 m away from the cage, another one is created.
	local autoCage
	menu.toggle(cage_options, menuname("Trolling - Cage", "自动"), {"autocage"}, "", function(toggle)
		autoCage = toggle
		local a
		while autoCage and NETWORK.NETWORK_IS_PLAYER_CONNECTED(pId) do
			local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
			local b = ENTITY.GET_ENTITY_COORDS(p)
			if not a or vect.dist2(a, b) >= 16.0 then
				TASK.CLEAR_PED_TASKS_IMMEDIATELY(p)
				if PED.IS_PED_IN_ANY_VEHICLE(p, false) then return end
				a = b
				trapcage(pId)
				
				local playerName = PLAYER.GET_PLAYER_NAME(pId)
				if playerName ~= "**Invalid**" then
					notification.normal("<C>" .. playerName .. "</C> " .. "was out of the cage.")
				end
			end
			wait(1000)
		end
	end)

	-------------------------------------
	-- FENCE
	-------------------------------------

	menu.action(cage_options, menuname("Trolling - Cage", "栏杆"), {"fence"}, "", function()
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		local objHash = util.joaat("prop_fnclink_03e")
		pos.z = pos.z - 1.0
		requestModels(objHash)
		local object = {}
		object[1] = OBJECT.CREATE_OBJECT(objHash, pos.x - 1.5, pos.y + 1.5, pos.z, true, true, true) 																			
		object[2] = OBJECT.CREATE_OBJECT(objHash, pos.x - 1.5, pos.y - 1.5, pos.z, true, true, true)
		
		object[3] = OBJECT.CREATE_OBJECT(objHash, pos.x + 1.5, pos.y + 1.5, pos.z, true, true, true) 	
		local rot_3  = ENTITY.GET_ENTITY_ROTATION(object[3])
		rot_3.z = -90
		ENTITY.SET_ENTITY_ROTATION(object[3], rot_3.x, rot_3.y, rot_3.z, 1, true)
		
		object[4] = OBJECT.CREATE_OBJECT(objHash, pos.x - 1.5, pos.y + 1.5, pos.z, true, true, true) 	
		local rot_4  = ENTITY.GET_ENTITY_ROTATION(object[4])
		rot_4.z = -90
		ENTITY.SET_ENTITY_ROTATION(object[4], rot_4.x, rot_4.y, rot_4.z, 1, true)
		
		for key, obj in pairs(object) do
			ENTITY.FREEZE_ENTITY_POSITION(obj, true)
		end
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(objHash)
	end)

	-------------------------------------
	-- STUNT TUBE
	-------------------------------------

	menu.action(cage_options, menuname("Trolling - Cage", "特技管"), {"stunttube"}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("stt_prop_stunt_tube_s")
		requestModels(hash)
		local obj = OBJECT.CREATE_OBJECT(hash, pos.x, pos.y, pos.z, true, true, false)
		local rot = ENTITY.GET_ENTITY_ROTATION(obj)
		ENTITY.SET_ENTITY_ROTATION(obj, rot.x, 90.0, rot.z, 1, true)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(hash)
	end)

	-------------------------------------
	-- RAPE
	-------------------------------------

	busted(menu.toggle, trollingOpt, menuname("Trolling", "强暴"), {}, "被删除的功能", function(toggle)
		gUsingRape = toggle
		-- otherwise the game would crash
		if pId == PLAYER.PLAYER_ID() then 
			return
		end		
		if gUsingRape then
			gUsingPiggyback = false
			local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
			local pos = ENTITY.GET_ENTITY_COORDS(p, false)
			STREAMING.REQUEST_ANIM_DICT("rcmpaparazzo_2")
			while not STREAMING.HAS_ANIM_DICT_LOADED("rcmpaparazzo_2") do
				wait()
			end
			TASK.TASK_PLAY_ANIM(PLAYER.PLAYER_PED_ID(), "rcmpaparazzo_2", "shag_loop_a", 8, -8, -1, 1, 0, false, false, false)
			ENTITY.ATTACH_ENTITY_TO_ENTITY(PLAYER.PLAYER_PED_ID(), p, 0, 0, -0.3, 0, 0, 0, 0, false, true, false, false, 0, true)
			while gUsingRape do
				wait()
				if not NETWORK.NETWORK_IS_PLAYER_CONNECTED(pId) then
					gUsingRape = false
				end
			end
			TASK.CLEAR_PED_TASKS_IMMEDIATELY(PLAYER.PLAYER_PED_ID())
			ENTITY.DETACH_ENTITY(PLAYER.PLAYER_PED_ID(), true, false)
		end
	end)

	-------------------------------------
	-- ENEMY VEHICLES
	-------------------------------------
	
	local minitanks = {
		godmode = false
	}

	local modIndex =
	{
		WT_V_PLRBUL 	= - 1,
		MINITANK_WEAP2 	=   1,
		MINITANK_WEAP3 	=   2
	}

	local enemyVehiclesOpt = menu.list(trollingOpt, menuname("Trolling", "敌对车辆"), {}, "")
	menu.divider(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "迷你坦克"))

	menu.click_slider(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "发送迷你坦克"), {"sendminitank"}, "", 1, 25, 1, 1, function(quantity)
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local vehicleHash = util.joaat("minitank")
		local pedHash = util.joaat("s_m_y_blackops_01")
		requestModels(vehicleHash, pedHash)
		
		for i = 1, quantity do
			local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
			local vehicle = VEHICLE.CREATE_VEHICLE(vehicleHash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, false)
			if not ENTITY.DOES_ENTITY_EXIST(vehicle) then
				goto continue
			end
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(vehicle), false)
			
			local offset = getOffsetFromEntityGivenDistance(vehicle, 50)
			local outCoords = v3.new()
			local outHeading = memory.alloc()

			if PATHFIND.GET_CLOSEST_VEHICLE_NODE_WITH_HEADING(offset.x, offset.y, offset.z, outCoords, outHeading, 1, 3.0, 0) then
				local driver = entities.create_ped(5, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
				PED.SET_PED_INTO_VEHICLE(driver, vehicle, -1)

				ENTITY.SET_ENTITY_COORDS(vehicle, v3.getX(outCoords), v3.getY(outCoords), v3.getZ(outCoords))
				ENTITY.SET_ENTITY_HEADING(vehicle, memory.read_float(outHeading))
				ENTITY.SET_ENTITY_INVINCIBLE(vehicle, minitanks.godmode)
				VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
				local weapon = minitanks.weapon or getRandomValue(modIndex)
				VEHICLE.SET_VEHICLE_MOD(vehicle, 10, weapon, false)
				VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
				addBlipForEntity(vehicle, 742, 4)

				PED.SET_PED_RELATIONSHIP_GROUP_HASH(driver, util.joaat("ARMY"))
				PED.SET_RELATIONSHIP_BETWEEN_GROUPS(0, util.joaat("ARMY"), util.joaat("ARMY"))
				PED.SET_PED_COMBAT_ATTRIBUTES(driver, 1, true)
				PED.SET_PED_COMBAT_ATTRIBUTES(driver, 3, false)
				PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driver, true)
				TASK.TASK_COMBAT_PED(driver, targetPed, 0, 0)
				PED.SET_PED_KEEP_TASK(driver, true)
				util.create_tick_handler(function()
					if TASK.GET_SCRIPT_TASK_STATUS(driver, 0x2E85A751) == 7 then
						TASK.CLEAR_PED_TASKS(driver)
						TASK.TASK_COMBAT_PED(driver, PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), 0, 0)
						PED.SET_PED_KEEP_TASK(driver, true)
					end
					return (not ENTITY.IS_ENTITY_DEAD(vehicle))
				end)
			end

			v3.free(outCoords)
			memory.free(outHeading)
			wait(150)
			::continue::
		end
		
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(vehicleHash)
	end)

	menu.toggle(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "无敌"), {}, "", function(toggle)
		minitanks.godmode = toggle
	end)

	-------------------------------------
	-- MINITANK WEAPON
	-------------------------------------

	local minitankWeaponList = menu.list(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "迷你坦克武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "")
	menu.divider(minitankWeaponList, HUD._GET_LABEL_TEXT("PM_WEAPONS"))

	menu.action(minitankWeaponList, HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "", function()
		minitanks.weapon = nil
		menu.set_menu_name(minitankWeaponList, menuname("Trolling - Enemy Vehicles", "迷你坦克武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"))
		menu.focus(minitankWeaponList)
	end)

	for label, weapon in pairsByKeys(modIndex) do
		local strg = HUD._GET_LABEL_TEXT(label)
		menu.action(minitankWeaponList, strg, {}, "", function()
			minitanks.weapon = weapon
			menu.set_menu_name(minitankWeaponList, menuname("Trolling - Enemy Vehicles", "迷你坦克武器") .. ": " .. strg)
			menu.focus(minitankWeaponList)
		end)
	end

	menu.action(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "删除迷你坦克"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), false)
		deleteNearbyVehicles(pos, "minitank", 1000.0)
	end)

	-------------------------------------
	-- ENEMY BUZZARD
	-------------------------------------

	local buzzard = 
	{
		visible = true,
		godmode = false,
		gunnerWeapon = "weapon_mg"
	}
	
	menu.divider(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "秃鹰直升机"))

	menu.click_slider(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "发送秃鹰直升机"), {"sendbuzzard"}, "", 1, 5, 1, 1, function(quantity)
		local vehicleHash = util.joaat("buzzard2")
		local pedHash = util.joaat("s_m_y_blackops_01")
		local targetPed =  PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		local playerGroupHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(targetPed)

		requestModels(pedHash, vehicleHash)		
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, util.joaat("ARMY"), playerGroupHash)
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(5, playerGroupHash, util.joaat("ARMY"))
		PED.SET_RELATIONSHIP_BETWEEN_GROUPS(0, util.joaat("ARMY"), util.joaat("ARMY"))

		for i = 1, quantity do
			local heli = VEHICLE.CREATE_VEHICLE(vehicleHash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, false)
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(heli), false)

			if ENTITY.DOES_ENTITY_EXIST(heli) then
				local pilot = entities.create_ped(29, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
				PED.SET_PED_INTO_VEHICLE(pilot, heli, -1)

				pos.x = pos.x + math.random(-20,20)
				pos.y = pos.y + math.random(-20,20)
				pos.z = pos.z + 30
				
				ENTITY.SET_ENTITY_COORDS(heli, pos.x, pos.y, pos.z)
				NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(heli), false)
				ENTITY.SET_ENTITY_INVINCIBLE(heli, buzzard.godmode)
				ENTITY.SET_ENTITY_VISIBLE(heli, buzzard.visible, 0)	
				VEHICLE.SET_VEHICLE_ENGINE_ON(heli, true, true, true)
				VEHICLE.SET_HELI_BLADES_FULL_SPEED(heli)
				addBlipForEntity(heli, 422, 4)

				PED.SET_PED_MAX_HEALTH(pilot, 500)
				ENTITY.SET_ENTITY_HEALTH(pilot, 500)
				ENTITY.SET_ENTITY_INVINCIBLE(pilot, buzzard.godmode)
				ENTITY.SET_ENTITY_VISIBLE(pilot, buzzard.visible, 0)
				PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(pilot, true)
				TASK.TASK_HELI_MISSION(pilot, heli, 0, targetPed, 0.0, 0.0, 0.0, 23, 40.0, 40.0, -1.0, 0, 10, -1.0, 0)
				PED.SET_PED_KEEP_TASK(pilot, true)
				
				for seat = 1, 2 do 
					local ped = entities.create_ped(29, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
					PED.SET_PED_INTO_VEHICLE(ped, heli, seat)
					WEAPON.GIVE_WEAPON_TO_PED(ped, util.joaat(buzzard.gunnerWeapon), -1, false, true)
					PED.SET_PED_COMBAT_ATTRIBUTES(ped, 20, true)
					PED.SET_PED_MAX_HEALTH(ped, 500)
					ENTITY.SET_ENTITY_HEALTH(ped, 500)
					ENTITY.SET_ENTITY_INVINCIBLE(ped, buzzard.godmode)
					ENTITY.SET_ENTITY_VISIBLE(ped, buzzard.visible, 0)
					PED.SET_PED_SHOOT_RATE(ped, 1000)
					PED.SET_PED_RELATIONSHIP_GROUP_HASH(ped, util.joaat("ARMY"))
					TASK.TASK_COMBAT_HATED_TARGETS_AROUND_PED(ped, 1000, 0)
				end
				
				wait(100)
			end
		end
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(vehicleHash)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
	end)
	
	menu.toggle(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "无敌"), {}, "", function(toggle)
		buzzard.godmode = toggle
	end)

	local gunnerWeaponList = menu.list(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "炮手武器") .. ": " .. HUD._GET_LABEL_TEXT("WT_MG"))
	menu.divider(gunnerWeaponList, HUD._GET_LABEL_TEXT("PM_WEAPONS"))

	-- these are the buzzard's gunner weapons
	local gunnerWeapons = {
		WT_MG 	= "weapon_mg",
		WT_RPG 	= "weapon_rpg"
	}

	for label, weapon in pairsByKeys(gunnerWeapons) do
		local strg = HUD._GET_LABEL_TEXT(label)
		menu.action(gunnerWeaponList, strg, {}, "", function()
			buzzard.gunnerWeapon = weapon
			menu.set_menu_name(gunnerWeaponList, "枪手的武器: " .. strg)
			menu.focus(gunnerWeaponList)
		end)
	end

	menu.toggle(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "可见的"), {}, "你不应该这么恶毒来关闭这个选项", function(toggle)
		buzzard.visible = toggle
	end, true)
	
	-------------------------------------
	-- HOSTILE JET
	-------------------------------------

	menu.divider(enemyVehiclesOpt, "天煞")

	local jetGodmode = false
	menu.click_slider(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "发送天煞"), {"sendlazer"}, "", 1, 15, 1, 1, function(quantity)
		local jet_hash = util.joaat("lazer")
		local pedHash = util.joaat("s_m_y_blackops_01")
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		requestModels(jet_hash, pedHash)
		
		for i = 1, quantity do
			local jet = VEHICLE.CREATE_VEHICLE(jet_hash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, false)
			NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(jet), false)

			if ENTITY.DOES_ENTITY_EXIST(jet) then
				local pilot = entities.create_ped(5, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
				PED.SET_PED_INTO_VEHICLE(pilot, jet, -1)

				pos.x = pos.x + math.random(-80,80)
				pos.y = pos.y + math.random(-80,80)
				pos.z = pos.z + 500

				ENTITY.SET_ENTITY_COORDS(jet, pos.x, pos.y, pos.z)
				setEntityFaceEntity(jet, targetPed)
				addBlipForEntity(jet, 16, 4)
				VEHICLE._SET_VEHICLE_JET_ENGINE_ON(jet, true)
				VEHICLE.SET_VEHICLE_FORWARD_SPEED(jet, 60)
				VEHICLE.CONTROL_LANDING_GEAR(jet, 3)
				ENTITY.SET_ENTITY_INVINCIBLE(jet, jetGodmode)
				VEHICLE.SET_VEHICLE_FORCE_AFTERBURNER(jet, true)
				
				TASK.TASK_PLANE_MISSION(pilot, jet, 0, targetPed, 0, 0, 0, 6, 100, 0, 0, 80, 50)
				PED.SET_PED_COMBAT_ATTRIBUTES(pilot, 1, true)
				relationship:hostile(pilot)
				wait(150)
			end
		end
		
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(jet_hash)
	end)

	menu.toggle(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "无敌"), {}, "", function(toggle)
		jetGodmode = toggle
	end, jetGodmode)

	menu.action(enemyVehiclesOpt, menuname("Trolling - Enemy Vehicles", "删除天煞"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), false)
		deleteNearbyVehicles(pos, "lazer", 1000.0)
	end)

	-------------------------------------
	-- DAMAGE
	-------------------------------------

	local damageOpt = menu.list(trollingOpt, menuname("Trolling", "伤害"), {}, "选择武器，无论你在天涯海角，都可以射杀玩家")
	menu.divider(damageOpt, menuname("Trolling", "伤害"))
	
	menu.action(damageOpt, menuname("Trolling - Damage", "重型狙击枪射击"), {}, "", function()
		local hash = util.joaat("weapon_heavysniper")
		local a = CAM.GET_GAMEPLAY_CAM_COORD()
		local b = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), false)
		requestWeaponAsset(hash)
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(a.x, a.y, a.z, b.x , b.y, b.z, 200, 0, hash, PLAYER.PLAYER_PED_ID(), true, false, 2500.0)
	end)

	menu.action(damageOpt, menuname("Trolling - Damage", "烟花"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("weapon_firework")
		requestWeaponAsset(hash)
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos.x, pos.y, pos.z + 3.0, pos.x , pos.y, pos.z - 2.0, 200, 0, hash, 0, true, false, 2500.0)
	end)

	menu.action(damageOpt, menuname("Trolling - Damage", "原子能枪射击"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("weapon_raypistol")
		requestWeaponAsset(hash)
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos.x, pos.y, pos.z + 3.0, pos.x , pos.y, pos.z - 2.0, 200, 0, hash, 0, true, false, 2500.0)
	end)

	menu.action(damageOpt, menuname("Trolling - Damage", "燃烧瓶"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("weapon_molotov")
		requestWeaponAsset(hash)
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos.x, pos.y, pos.z, pos.x , pos.y, pos.z - 2.0, 200, 0, hash, 0, true, false, 2500.0)
	end)

	menu.action(damageOpt, menuname("Trolling - Damage", "EMP载具"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("weapon_emplauncher")
		requestWeaponAsset(hash)
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos.x, pos.y, pos.z, pos.x , pos.y, pos.z - 2.0, 200, 0, hash, 0, true, false, 2500.0)
	end)

	-------------------------------------
	-- HOSTILE PEDS
	-------------------------------------

	menu.action(trollingOpt, menuname("Trolling", "敌对的行人"), {"hostilepeds"}, "所有行人都会攻击玩家", function()
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		for _, ped in ipairs(getNearbyPeds(pId, 90.0)) do
			if not PED.IS_PED_IN_ANY_VEHICLE(ped, false) and not PED.IS_PED_A_PLAYER(ped) then
				local weapon = getRandomValue(gWeapons)
				requestControlLoop(ped)
				TASK.CLEAR_PED_TASKS_IMMEDIATELY(ped)
				PED.SET_PED_COMBAT_ATTRIBUTES(ped, 46, true)
				PED.SET_PED_MAX_HEALTH(ped, 300)
				ENTITY.SET_ENTITY_HEALTH(ped, 300)
				WEAPON.GIVE_WEAPON_TO_PED(ped, util.joaat(weapon), -1, false, true)
				TASK.TASK_COMBAT_PED(ped, targetPed, 0, 0)
				WEAPON.SET_PED_DROPS_WEAPONS_WHEN_DEAD(ped, false)
				relationship:hostile(ped)
			end
		end
	end)

	-------------------------------------
	-- HOSTILE TRAFFIC
	-------------------------------------

	menu.action(trollingOpt, menuname("Trolling", "敌对的载具"), {"hostiletraffic"}, "", function()
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		for _, vehicle in ipairs(getNearbyVehicles(pId, 250)) do	
			if not VEHICLE.IS_VEHICLE_SEAT_FREE(vehicle, -1) then
				local driver = VEHICLE.GET_PED_IN_VEHICLE_SEAT(vehicle, -1)
				if not PED.IS_PED_A_PLAYER(driver) then 
					requestControlLoop(driver)
					PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driver, true)
					PED.SET_PED_MAX_HEALTH(driver, 300)
					ENTITY.SET_ENTITY_HEALTH(driver, 300)
					TASK.CLEAR_PED_TASKS_IMMEDIATELY(driver)
					PED.SET_PED_INTO_VEHICLE(driver, vehicle, -1)
					TASK.TASK_VEHICLE_MISSION_PED_TARGET(driver, vehicle, targetPed, 6, 100, 0, 0, 0, true)
				end
			end
		end
	end)

	-------------------------------------
	-- TROLLY BANDITO
	-------------------------------------

	local banditos = {
		godmode = false, 
		explosive_bandito_exists = false
	}
	local trolly_vehicles = menu.list(trollingOpt, menuname("Trolling", "无人载具"), {}, "")

	local function spawn_trolly_vehicle(pId, vehicleHash, pedHash)
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(targetPed)
		local driver = NULL
		local vehicle = VEHICLE.CREATE_VEHICLE(vehicleHash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, false)
		NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(vehicle), false)
		VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
		for i = 0, 50 do
			VEHICLE.SET_VEHICLE_MOD(vehicle, i, VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, i) - 1, false)
		end
		
		local offset = getOffsetFromEntityGivenDistance(vehicle, 25)
		local outCoords = v3.new()
		local outHeading = memory.alloc()

		if PATHFIND.GET_CLOSEST_VEHICLE_NODE_WITH_HEADING(offset.x, offset.y, offset.z, outCoords, outHeading, 1, 3.0, 0) then
			driver = entities.create_ped(5, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
			PED.SET_PED_INTO_VEHICLE(driver, vehicle, -1)

			ENTITY.SET_ENTITY_COORDS(vehicle, v3.getX(outCoords), v3.getY(outCoords), v3.getZ(outCoords))
			ENTITY.SET_ENTITY_HEADING(vehicle, memory.read_float(outHeading))
			VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
			VEHICLE.SET_VEHICLE_DOORS_LOCKED_FOR_ALL_PLAYERS(vehicle, true)
			VEHICLE.SET_VEHICLE_IS_CONSIDERED_BY_PLAYER(vehicle, false)
			
			PED.SET_PED_COMBAT_ATTRIBUTES(driver, 1, true)
			PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driver, true)
			TASK.TASK_VEHICLE_MISSION_PED_TARGET(driver, vehicle, targetPed, 6, 500.0, 786988, 0.0, 0.0, true)
			PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(driver, 1)
			STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash); STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(vehicleHash)	
		end

		v3.free(outCoords)
		memory.free(outHeading)
		return vehicle, driver
	end

	menu.divider(trolly_vehicles, "RC匪徒")

	menu.click_slider(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "发送RC匪徒"), {"sendbandito"}, "", 1,25,1,1, function(quantity)
		local vehicleHash = util.joaat("rcbandito")
		local pedHash = util.joaat("mp_m_freemode_01")
		requestModels(vehicleHash, pedHash)
		for i = 1, quantity do
			local vehicle, driver = spawn_trolly_vehicle(pId, vehicleHash, pedHash)
			addBlipForEntity(vehicle, 646, 4)
			ENTITY.SET_ENTITY_INVINCIBLE(vehicle, banditos.godmode)
			ENTITY.SET_ENTITY_VISIBLE(driver, false, 0)
			wait(150)
		end
	end)

	menu.toggle(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "无敌"), {}, "", function(toggle)
		banditos.godmode = toggle
	end)

	menu.action(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "发送爆炸RC匪徒"), {"explobandito"}, "", function()
		local vehicleHash = util.joaat("rcbandito")
		local pedHash = util.joaat("mp_m_freemode_01")
		requestModels(vehicleHash, pedHash)
		
		if banditos.explosive_bandito_exists then
			notification.help("已经发送的爆炸RC匪徒", HudColour.red)
			return
		end
		banditos.explosive_bandito_exists = true
		local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local bandito = spawn_trolly_vehicle(pId, vehicleHash, pedHash)
		VEHICLE.SET_VEHICLE_MOD(bandito, 5, 3, false)
		VEHICLE.SET_VEHICLE_MOD(bandito, 48, 5, false)
		VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(bandito, 128, 0, 128)
		VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(bandito, 128, 0, 128)
		addBlipForEntity(bandito, 646, 27)
		VEHICLE.ADD_VEHICLE_PHONE_EXPLOSIVE_DEVICE(bandito)

		while not ENTITY.IS_ENTITY_DEAD(bandito) do
			wait()
			local a = ENTITY.GET_ENTITY_COORDS(p)
			local b = ENTITY.GET_ENTITY_COORDS(bandito)
			if vect.dist2(a,b) < 9.0 then
				VEHICLE.DETONATE_VEHICLE_PHONE_EXPLOSIVE_DEVICE()
			end
		end

		banditos.explosive_bandito_exists = false
	end)

	menu.action(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "删除RC匪徒"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), false)
		deleteNearbyVehicles(pos, "rcbandito", 1000.0)
	end)
	
	-------------------------------------
	-- GO KART
	-------------------------------------

	local gokartGodmode = false
	menu.divider(trolly_vehicles, "卡丁 微托现代版")

	menu.click_slider(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "发送卡丁车"), {"sendgokart"}, "",1, 15, 1, 1, function(quantity)
		local vehicleHash = util.joaat("veto2")
		local pedHash = util.joaat("mp_m_freemode_01")
		requestModels(vehicleHash, pedHash)
		
		for i = 1, quantity do
			local gokart, driver = spawn_trolly_vehicle(pId, vehicleHash, pedHash)
			addBlipForEntity(gokart, 748, 5)
			ENTITY.SET_ENTITY_INVINCIBLE(gokart, gokartGodmode)
			VEHICLE.SET_VEHICLE_COLOURS(gokart, 89, 0)
			VEHICLE.TOGGLE_VEHICLE_MOD(gokart, 18, true)
			ENTITY.SET_ENTITY_INVINCIBLE(driver, gokartGodmode)
			PED.SET_PED_COMPONENT_VARIATION(driver, 3, 111, 13, 2)
			PED.SET_PED_COMPONENT_VARIATION(driver, 4, 67, 5, 2)
			PED.SET_PED_COMPONENT_VARIATION(driver, 6, 101, 1, 2)
			PED.SET_PED_COMPONENT_VARIATION(driver, 8, -1, -1, 2)
			PED.SET_PED_COMPONENT_VARIATION(driver, 11, 148, 5, 2)
			PED.SET_PED_PROP_INDEX(driver, 0, 91, 0, true)
			wait(150)
		end
	
	end)

	menu.toggle(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "无敌"), {}, "", function(toggle)
		gokartGodmode = toggle
	end)

	menu.action(trolly_vehicles, menuname("Trolling - Trolly Vehicles", "删除卡丁车"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId), false)
		deleteNearbyVehicles(pos, "veto2", 1000.0)
	end)

	-------------------------------------
	-- RAM PLAYER
	-------------------------------------

	menu.click_slider(trollingOpt, menuname("Trolling", "冲撞玩家"), {"ram"}, "", 1, 3, 1, 1, function(value)
		local vehicles = {"insurgent2", "phantom2", "adder"}
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local vehicleHash = util.joaat(vehicles[value])
		requestModels(vehicleHash)
		local coord = getOffsetFromEntityGivenDistance(targetPed, 12.0)
		local vehicle = entities.create_vehicle(vehicleHash, coord, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
		setEntityFaceEntity(vehicle, targetPed)
		VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, 2)
		ENTITY.SET_ENTITY_LOAD_COLLISION_FLAG(vehicle, true)
		VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicle, 100)
	end)


	-------------------------------------
	-- PIGGY BACK
	-------------------------------------

	busted(menu.toggle, trollingOpt, menuname("Trolling", "背"), {}, "删除的功能", function(toggle)
		if pId == players.user() then return end
		gUsingPiggyback = toggle
		if gUsingPiggyback then
			gUsingRape = false
			local p = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
			STREAMING.REQUEST_ANIM_DICT("rcmjosh2")
			while not STREAMING.HAS_ANIM_DICT_LOADED("rcmjosh2") do
				wait()
			end
			ENTITY.ATTACH_ENTITY_TO_ENTITY(PLAYER.PLAYER_PED_ID(), p, PED.GET_PED_BONE_INDEX(p, 0xDD1C), 0, -0.2, 0.65, 0, 0, 180, false, true, false, false, 0, true)
			TASK.TASK_PLAY_ANIM(PLAYER.PLAYER_PED_ID(), "rcmjosh2", "josh_sitting_loop", 8, -8, -1, 1, 0, false, false, false)
			while gUsingPiggyback do
				wait()
				if not NETWORK.NETWORK_IS_PLAYER_CONNECTED(pId) then
					gUsingPiggyback = false
				end
			end
			TASK.CLEAR_PED_TASKS_IMMEDIATELY(PLAYER.PLAYER_PED_ID())
			ENTITY.DETACH_ENTITY(PLAYER.PLAYER_PED_ID(), true, false)
		end
	end)
	
	-------------------------------------
	-- RAIN ROCKETS
	-------------------------------------

	local function rain_rockets(pId, owned)
		local localPed = PLAYER.PLAYER_PED_ID()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
		local hash = util.joaat("weapon_airstrike_rocket")
		if not WEAPON.HAS_WEAPON_ASSET_LOADED(hash) then
			WEAPON.REQUEST_WEAPON_ASSET(hash, 31, 0)
		end
		pos.x = pos.x + math.random(-6, 6)
		pos.y = pos.y + math.random(-6, 6)
		pos.z = pos.z - 10.0
		
		local owner = owned and localPed or 0
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos.x, pos.y, pos.z + 50, pos.x, pos.y, pos.z, 200, true, hash, owner, true, false, 2500.0)
	end

	menu.toggle_loop(trollingOpt, menuname("Trolling", "火箭轰炸(自身名义)"), {"ownedrockets"}, "", function()
		rain_rockets(pId, true)
		wait(500)
	end)

	menu.toggle_loop(trollingOpt, menuname("Trolling", "火箭轰炸(匿名)"), {"rockets"}, "", function()
		rain_rockets(pId, false)
		wait(500)
	end)

	-------------------------------------
	-- NET FORCEFIELD
	-------------------------------------

	local forcefieldOpt = {"停用", "推开", "摧毁"}
	local currentForcefield
	local forcefieldRoot = menu.list(trollingOpt, menuname("Forcefield", "立场") .. ": " .. menuname("Forcefield", forcefieldOpt[ 1 ]) ) 

	for i, option in ipairs(forcefieldOpt) do
		menu.action(forcefieldRoot, menuname("Forcefield", option), {}, "", function()
			currentForcefield = i
			menu.set_menu_name(forcefieldRoot, menuname("Forcefield", "立场") .. ": " .. menuname("Forcefield", option) )
			menu.focus(forcefieldRoot)
		end)
	end

	util.create_tick_handler(function()
		if currentForcefield == 1 then -- disable
			return true
		elseif currentForcefield == 2 then -- push out
			local pos1 = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
			local entities = getNearbyEntities(pId, 10)

			for _, entity in ipairs(entities) do
				local pos2 = ENTITY.GET_ENTITY_COORDS(entity)
				local force = vect.norm(vect.subtract(pos2, pos1))
				if ENTITY.IS_ENTITY_A_PED(entity)  then
					if not PED.IS_PED_A_PLAYER(entity) and not PED.IS_PED_IN_ANY_VEHICLE(entity, true) then
						requestControl(entity)
						PED.SET_PED_TO_RAGDOLL(entity, 1000, 1000, 0, 0, 0, 0)
						ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, force.x, force.y, force.z, 0, 0, 0.5, 0, false, false, true)
					end
				else
					requestControl(entity)
					ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, force.x, force.y, force.z, 0, 0, 0.5, 0, false, false, true)
				end
			end

		elseif currentForcefield == 3 then -- destroy
			local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))
			FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 29, 5.0, false, true, 0.0, true)
		end
		return true
	end)

	-------------------------------------
	-- KAMIKASE
	-------------------------------------

	menu.click_slider(trollingOpt, menuname("Trolling", "神风特攻队"), {"kamikaze"}, "", 1, 3, 1, 1, function(value)
		local planes = {"lazer", "mammatus", "cuban800"}
		local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = getOffsetFromEntityGivenDistance(targetPed, 20.0)
		pos.z = pos.z + 30.0
		local hash = util.joaat(planes[ value ])
		requestModels(hash)
		local plane = entities.create_vehicle(hash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
		setEntityFaceEntity(plane, targetPed, true)
		ENTITY.SET_ENTITY_LOAD_COLLISION_FLAG(plane, true)
		VEHICLE.SET_VEHICLE_FORWARD_SPEED(plane, 150)
		VEHICLE.CONTROL_LANDING_GEAR(plane, 3)
	end)

	-------------------------------------
	-- CREEPER CLOWN
	-------------------------------------

	menu.action(trollingOpt, menuname("Trolling", "自爆小丑"), {}, "", function()
		local hash = util.joaat("s_m_y_clown_01")
		local explosion = Effect.new("scr_rcbarry2", "scr_exp_clown")
		local appears = Effect.new("scr_rcbarry2",  "scr_clown_appears")

		AUDIO.REQUEST_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_A", false, -1)
		AUDIO.REQUEST_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_B", false, -1)
		AUDIO.REQUEST_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_C", false, -1)

		requestModels(hash)
		local player = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local pos = ENTITY.GET_ENTITY_COORDS(player)
		local coord = getOffsetFromEntityGivenDistance(player, 7.0)
		local ped = entities.create_ped(0, hash, coord, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
	
		requestPtfxAsset(appears.asset)
		GRAPHICS.USE_PARTICLE_FX_ASSET(appears.asset)
		GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY(appears.name, ped, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.5, false, false, false, false)
		setEntityFaceEntity(ped, player)
		PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(ped, true) 
		
		TASK.TASK_GO_TO_COORD_ANY_MEANS(ped, pos.x, pos.y, pos.z, 5.0, 0, 0, 0, 0)
		local dest = pos
		PED.SET_PED_KEEP_TASK(ped, true)
		AUDIO.STOP_PED_SPEAKING(ped, true)
		AUDIO.SET_AMBIENT_VOICE_NAME(ped, "CLOWNS")
		
		util.create_tick_handler(function()
			local pos = ENTITY.GET_ENTITY_COORDS(ped)
			local targetPos = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId))

			if vect.dist2(pos, targetPos) < 9.0 then
				requestPtfxAsset(explosion.asset)
				GRAPHICS.USE_PARTICLE_FX_ASSET(explosion.asset)
				GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD(
					explosion.name, 
					pos.x, 
					pos.y, 
					pos.z, 
					0.0, 
					0.0, 
					0.0, 
					1.0, 
					false, false, false, false
				)
				FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 0, 1.0, true, true, 1.0)
				ENTITY.SET_ENTITY_VISIBLE(ped, false, 0)
				return false
			elseif vect.dist2(targetPos, dest) > 9.0 then
				dest = targetPos
				TASK.TASK_GO_TO_COORD_ANY_MEANS(ped, targetPos.x, targetPos.y, targetPos.z, 5.0, 0, 0, 0, 0)
			end
			return true
		end)

		AUDIO.RELEASE_NAMED_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_A")
		AUDIO.RELEASE_NAMED_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_B")
		AUDIO.RELEASE_NAMED_SCRIPT_AUDIO_BANK("BARRY_02_CLOWN_C")
	end)
	---------------------
	---------------------
	-- NET VEHICLE OPT
	---------------------
	---------------------

	local vehicleOpt = menu.list(menu.player_root(pId), menuname("Player - Vehicle", "车辆"), {}, "")
	menu.divider(vehicleOpt, menuname("Player - Vehicle", "车辆"))
	
	-------------------------------------
	-- TELEPORT
	-------------------------------------

	local tpVehicleOpt = menu.list(vehicleOpt, menuname("Player - Vehicle", "传送载具"))
	menu.divider(tpVehicleOpt, menuname("Player - Vehicle", "传送载具"))


	local function teleport_player_vehicle(player, pos)
		local vehicle = getVehiclePlayerIsIn(player)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		ENTITY.SET_ENTITY_COORDS(vehicle, pos.x, pos.y, pos.z, false, false, false)
	end

	
	menu.action(tpVehicleOpt, menuname("Vehicle - Teleport", "传送到我"), {}, "", function()
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID(), false)
		teleport_player_vehicle(pId, pos)
	end)


	menu.action(tpVehicleOpt, menuname("Vehicle - Teleport", "传送到海洋"), {}, "", function()
		local pos = vect.new(-4809.93, -2521.67, 250.0)
		teleport_player_vehicle(pId, pos)
	end)

	
	menu.action(tpVehicleOpt, menuname("Vehicle - Teleport", "传送到监狱"), {}, "", function()
		local pos = vect.new(1680.11, 2512.89, 45.56)
		teleport_player_vehicle(pId, pos)
	end)

	
	menu.action(tpVehicleOpt, menuname("Vehicle - Teleport", "传送到桑库多堡垒"), {}, "", function()
		local pos = vect.new(-2219.0, 3213.0, 32.81)
		teleport_player_vehicle(pId, pos)
	end)

	
	menu.action(tpVehicleOpt, menuname("Vehicle - Teleport", "传送到航点"), {}, "", function()
		local pos = getWaypointCoords()
		if pos then
			teleport_player_vehicle(pId, pos)
		else 
			notification.help("No waypoint found", HudColour.red)
		end
	end)

	-------------------------------------
	-- ACROBATICS
	-------------------------------------

	local acrobatics = menu.list(vehicleOpt, menuname("Player - Vehicle", "载具动作"), {}, "")
	menu.divider(acrobatics, menuname("Player - Vehicle", "载具动作"))


	menu.action(acrobatics, menuname("Vehicle - Acrobatics", "跳跃"), {"ollie"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle ~= NULL and VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(vehicle) then
			requestControlLoop(vehicle)
			ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0.0, 0.0, 10.0, 0.0, 0.0, 0.0, 1, false, true, true, true, true)
		end
	end)
	
	menu.action(acrobatics, menuname("Vehicle - Acrobatics", "左侧空翻"), {"kickflip"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(vehicle) then
			requestControlLoop(vehicle)
			ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0.0, 0.0, 10.71, 5.0, 0.0, 0.0, 1, false, true, true, true, true)
		end
	end)

	menu.action(acrobatics, menuname("Vehicle - Acrobatics", "超级侧空翻"), {}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle ~= NULL and VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(vehicle) then
			requestControlLoop(vehicle)
			ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0.0, 0.0, 21.43, 20.0, 0.0, 0.0, 1, false, true, true, true, true)
		end
	end)

	menu.action(acrobatics, menuname("Vehicle - Acrobatics", "右侧空翻"), {}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle ~= NULL and VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(vehicle) then
			requestControlLoop(vehicle)
			ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0.0, 0.0, 10.71, -5.0, 0.0, 0.0, 1, false, true, true, true, true)
		end
	end)

	-------------------------------------
	-- KILL ENGINE
	-------------------------------------
	
	menu.action(vehicleOpt, menuname("Player - Vehicle", "关闭引擎"), {"killengine"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		VEHICLE.SET_VEHICLE_ENGINE_HEALTH(vehicle, -4000)
	end)

	-------------------------------------
	-- CLEAN
	-------------------------------------
	
	menu.action(vehicleOpt, menuname("Player - Vehicle", "清洁载具"), {"cleanveh"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicle, 0.0)
	end)

	-------------------------------------
	-- REPAIR
	-------------------------------------

	menu.action(vehicleOpt, menuname("Player - Vehicle", "修理载具"), {"repairveh"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		VEHICLE.SET_VEHICLE_FIXED(vehicle)
		VEHICLE.SET_VEHICLE_DEFORMATION_FIXED(vehicle)
		VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicle, 0.0)
	end)

	-------------------------------------
	-- KICK
	-------------------------------------

	menu.action(vehicleOpt, menuname("Player - Vehicle", "踢出载具"), {}, "", function()
		local param = {578856274, PLAYER.PLAYER_ID(), 0, 0, 0, 0, 1, PLAYER.PLAYER_ID(), MISC.GET_FRAME_COUNT()}
		util.trigger_script_event(1 << pId, param)
	end)
	
	-------------------------------------
	-- UPGRADE
	-------------------------------------

	menu.action(vehicleOpt, menuname("Player - Vehicle", "升级载具"), {"upgradeveh"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		VEHICLE.SET_VEHICLE_MOD_KIT(vehicle, 0)
		for i = 0, 50 do
			VEHICLE.SET_VEHICLE_MOD(vehicle, i, VEHICLE.GET_NUM_VEHICLE_MODS(vehicle, i) - 1, false)
		end
	end)
	
	-------------------------------------
	-- CUSTOM PAINT
	-------------------------------------

	menu.action(vehicleOpt, menuname("Player - Vehicle", "载具喷色"), {"randompaint"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		local primary, secundary = Colour.random(), Colour.random()
		VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(vehicle, unpack(primary))
		VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(vehicle, unpack(secundary))
	end)
	
	-------------------------------------
	-- BURST TIRES
	-------------------------------------
	
	menu.action(vehicleOpt, menuname("Player - Vehicle", "爆胎"), {}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, true)
		for wheelId = 0, 7 do
			VEHICLE.SET_VEHICLE_TYRE_BURST(vehicle, wheelId, true, 1000.0)
		end
	end)

	-------------------------------------
	-- CATAPULT
	-------------------------------------
	
	menu.action(vehicleOpt, menuname("Player - Vehicle", "载具弹射"), {"catapult"}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle ~= NULL and VEHICLE.IS_VEHICLE_ON_ALL_WHEELS(vehicle) then
			requestControlLoop(vehicle)
			ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0.0, 0.0, 9999, 0.0, 0.0, 0.0, 1, false, true, true, true, true)
		end	
	end)

	-------------------------------------
	-- BOOST FORWARD
	-------------------------------------
	
	menu.action(vehicleOpt, menuname("Player - Vehicle", "向前加速"), {}, "", function()
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		local unitv = ENTITY.GET_ENTITY_FORWARD_VECTOR(vehicle)
		local force = vect.mult(unitv, 40)
		AUDIO.SET_VEHICLE_BOOST_ACTIVE(vehicle, true)
		ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, force.x, force.y, force.z, 0.0, 0.0, 0.0, 1, false, true, true, true, true)
		AUDIO.SET_VEHICLE_BOOST_ACTIVE(vehicle, false)
	end)

	-------------------------------------
	-- LICENSE PLATE
	-------------------------------------

	--[[
	menu.text_input(vehicleOpt, menuname("Player - Vehicle", "设置车牌号"), {"setplatetxt"}, "最大8个字符", function(strg)
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL or strg == "" then return end
		requestControlLoop(vehicle)
		while #strg > 8 do -- reduces the length of string till it's 8 characters long
			wait()
			strg = string.gsub(strg, '.$', "")
		end
		VEHICLE.SET_VEHICLE_NUMBER_PLATE_TEXT(vehicle, strg)
	end)
	]]

	-------------------------------------
	-- GOD MODE
	-------------------------------------
	
	menu.toggle(vehicleOpt, menuname("Player - Vehicle", "载具无敌"), {"vehgodmode"}, "", function(toggle)
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		if toggle then
			VEHICLE.SET_VEHICLE_ENVEFF_SCALE(vehicle, 0.0)
			VEHICLE.SET_VEHICLE_BODY_HEALTH(vehicle, 1000.0)
			VEHICLE.SET_VEHICLE_ENGINE_HEALTH(vehicle, 1000.0)
			VEHICLE.SET_VEHICLE_FIXED(vehicle)
			VEHICLE.SET_VEHICLE_DEFORMATION_FIXED(vehicle)
			VEHICLE.SET_VEHICLE_PETROL_TANK_HEALTH(vehicle, 1000.0)
			VEHICLE.SET_VEHICLE_DIRT_LEVEL(vehicle, 0.0)
			for i = 0, 10 do
				VEHICLE.SET_VEHICLE_TYRE_FIXED(vehicle, i)
			end
		end
		ENTITY.SET_ENTITY_INVINCIBLE(vehicle, toggle)
		ENTITY.SET_ENTITY_PROOFS(vehicle, toggle, toggle, toggle, toggle, toggle, toggle, 1, toggle)
		VEHICLE.SET_DISABLE_VEHICLE_PETROL_TANK_DAMAGE(vehicle, toggle)
		VEHICLE.SET_DISABLE_VEHICLE_PETROL_TANK_FIRES(vehicle, toggle)
		VEHICLE.SET_VEHICLE_CAN_BE_VISIBLY_DAMAGED(vehicle, not toggle)
		VEHICLE.SET_VEHICLE_CAN_BREAK(vehicle, not toggle)
		VEHICLE.SET_VEHICLE_ENGINE_CAN_DEGRADE(vehicle, not toggle)
		VEHICLE.SET_VEHICLE_EXPLODES_ON_HIGH_EXPLOSION_DAMAGE(vehicle, not toggle)
		VEHICLE.SET_VEHICLE_TYRES_CAN_BURST(vehicle, not toggle)
		VEHICLE.SET_VEHICLE_WHEELS_CAN_BREAK(vehicle, not toggle)
	end)

	-------------------------------------
	-- INVISIBLE
	-------------------------------------

	menu.toggle(vehicleOpt, menuname("Player - Vehicle", "载具隐身"), {"invisibleveh"}, "", function(toggle)
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		ENTITY.SET_ENTITY_VISIBLE(vehicle, not toggle, false)
	end)

	-------------------------------------
	-- FREEZE
	-------------------------------------

	menu.toggle(vehicleOpt, menuname("Player - Vehicle", "冻结载具"), {"freezeveh"}, "", function(toggle)
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		ENTITY.FREEZE_ENTITY_POSITION(vehicle, toggle)
	end)

	-------------------------------------
	-- LOCK DOORS
	-------------------------------------

	menu.toggle(vehicleOpt, menuname("Player - Vehicle", "车门锁"), {"lockveh"}, "", function(toggle)
		local vehicle = getVehiclePlayerIsIn(pId)
		if vehicle == NULL then return end
		requestControlLoop(vehicle)
		if toggle then
			VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, 4)
		else
			VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, 1)
		end
	end)

	---------------------
	---------------------
	-- FRIENDLY
	---------------------
	---------------------

	local friendlyOpt = menu.list(menu.player_root(pId), menuname("Player", "友好选项"), {}, "")
	menu.divider(friendlyOpt, menuname("Player", "友好选项"))

	-------------------------------------
	-- KILL KILLERS
	-------------------------------------

	local explodeKiller = false

	menu.toggle_loop(friendlyOpt, menuname("Friendly Options", "击杀击杀者"), {"explokillers"}, "爆炸击杀杀死玩家的人", function(toggle)
		local playerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
		local sourceOfDeath = PED.GET_PED_SOURCE_OF_DEATH(playerPed)
		
		if explodeKiller and ENTITY.DOES_ENTITY_EXIST(sourceOfDeath) then
			if sourceOfDeath == playerPed then
				return
			end
			local pos = ENTITY.GET_ENTITY_COORDS(sourceOfDeath, false)
			FIRE.ADD_OWNED_EXPLOSION(playerPed, pos.x, pos.y, pos.z - 1.0, 1, 1.0, true, false, 1.0)
			explodeKiller = false
		elseif not ENTITY.IS_ENTITY_DEAD(playerPed) then
			explodeKiller = true
		end
	end)

-- end of generate_features
end

---------------------
---------------------
-- SELF
---------------------
---------------------

local selfOpt = menu.list(menu.my_root(), menuname("Self", "自我"), {"selfoptions"}, "")

-------------------------------------
-- HEALTH OPTIONS
-------------------------------------

local defaultHealth = ENTITY.GET_ENTITY_MAX_HEALTH(PLAYER.PLAYER_PED_ID())
local moddedHealth = defaultHealth
local moddedHealthSlider

menu.toggle(selfOpt, menuname("Self", "最大生命值"), {"modhealth"}, "改变你的最大生命值。一些菜单会将你标记为作弊者。当它被禁用时，它会返回到默认的最大生命值。", function(toggle)
	gUsingModHealth  = toggle

	local localPed = PLAYER.PLAYER_PED_ID()
	if gUsingModHealth then
		PED.SET_PED_MAX_HEALTH(localPed,  moddedHealth)
		ENTITY.SET_ENTITY_HEALTH(localPed, moddedHealth)
	else
		PED.SET_PED_MAX_HEALTH(localPed, defaultHealth)
		menu.trigger_command(moddedHealthSlider, defaultHealth) -- just if you want the slider to go to default value when mod health is off
		if ENTITY.GET_ENTITY_HEALTH(localPed) > defaultHealth then 
			ENTITY.SET_ENTITY_HEALTH(localPed, defaultHealth)
		end
	end
	util.create_tick_handler(function()
		if PED.GET_PED_MAX_HEALTH(PLAYER.PLAYER_PED_ID()) ~= moddedHealth  then
			PED.SET_PED_MAX_HEALTH(PLAYER.PLAYER_PED_ID(), moddedHealth)
			ENTITY.SET_ENTITY_HEALTH(PLAYER.PLAYER_PED_ID(), moddedHealth)	
		end
		if gConfig.general.displayhealth then
			local strg = "~b~" .. "HEALTH " .. "~w~" .. tostring(ENTITY.GET_ENTITY_HEALTH(PLAYER.PLAYER_PED_ID()))
			drawString(strg, gConfig.healthtxtpos.x, gConfig.healthtxtpos.y, 0.6, 4)	
		end
		return gUsingModHealth
	end)
end)


moddedHealthSlider = menu.slider(selfOpt, menuname("Self", "设置最大生命值"), {"moddedhealth"}, "生命值将被修改为指定的数值", 100, 9000, defaultHealth, 50, function(value)
	moddedHealth = value
end)


menu.action(selfOpt, menuname("Self", "恢复生命值"), {"maxhealth"}, "", function()
	ENTITY.SET_ENTITY_HEALTH(PLAYER.PLAYER_PED_ID(), PED.GET_PED_MAX_HEALTH(PLAYER.PLAYER_PED_ID()))
end)


menu.action(selfOpt, menuname("Self", "恢复护甲值"), {"maxarmour"}, "", function()
	if util.is_session_started() then
		PED.SET_PED_ARMOUR(PLAYER.PLAYER_PED_ID(), 50)
	else
		PED.SET_PED_ARMOUR(PLAYER.PLAYER_PED_ID(), 100)
	end
end)


local function set_health_recharge_limit_and_mult(limit, mult)
	PLAYER._SET_PLAYER_HEALTH_RECHARGE_LIMIT(PLAYER.PLAYER_ID(), limit)
	PLAYER.SET_PLAYER_HEALTH_RECHARGE_MULTIPLIER(PLAYER.PLAYER_ID(), mult)
end


menu.toggle(selfOpt, menuname("Self", "逐渐恢复生命值"), {"healincover"}, "", function(toggle)
	gUsingRefillInCover = toggle
	
	while gUsingRefillInCover do
		if PED.IS_PED_IN_COVER(PLAYER.PLAYER_PED_ID()) then
			set_health_recharge_limit_and_mult(1, 15)
		else
			set_health_recharge_limit_and_mult(0.5, 1.0)
		end
		wait()
	end

	if not gUsingRefillInCover then
		set_health_recharge_limit_and_mult(0.25, 1.0)
	end
end)


menu.action(selfOpt, menuname("Self", "获得牛鲨睾酮"), {}, "对于那些喜欢非拨动式选项的人", function()
	write_global.int(2703656 + 3590, 1)
end)

-------------------------------------
-- FORCEFIELD
-------------------------------------

local forcefieldOpt = {"停用", "推开", "摧毁"}
local currentForcefield = 1
local forcefieldList = menu.list(selfOpt, menuname("Forcefield", "立场") .. ": " .. menuname("Forcefield", forcefieldOpt[ 1 ]) ) 

for i, item in ipairs(forcefieldOpt) do
	menu.action(forcefieldList, menuname("Forcefield", item), {}, "", function()
		currentForcefield = i
		menu.set_menu_name(forcefieldList, menuname("Forcefield", "立场") .. ": " .. menuname("Forcefield", item) )
		menu.focus(forcefieldList)
	end)
end

util.create_tick_handler(function()
	if currentForcefield == 1 then
		return true
	elseif currentForcefield == 2 then
		local pos1 = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		local entities = getNearbyEntities(PLAYER.PLAYER_ID(), 10)
		for k, entity in pairs(entities) do
			local pos2 = ENTITY.GET_ENTITY_COORDS(entity)
			local force = vect.norm(vect.subtract(pos2, pos1))
			if ENTITY.IS_ENTITY_A_PED(entity)  then
				if not PED.IS_PED_A_PLAYER(entity) and not PED.IS_PED_IN_ANY_VEHICLE(entity, true) then
					requestControl(entity)
					PED.SET_PED_TO_RAGDOLL(entity, 1000, 1000, 0, 0, 0, 0)
					ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, force.x, force.y, force.z, 0, 0, 0.5, 0, false, false, true)
				end
			else
				requestControl(entity)
				ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, force.x, force.y, force.z, 0, 0, 0.5, 0, false, false, true)
			end
		end
	elseif currentForcefield == 3 then
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		gProofs.explosion = true
		FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 29, 5.0, false, true, 0.0, true)
	end
	return true
end)

-------------------------------------
-- FORCE
-------------------------------------

menu.toggle(selfOpt, menuname("Self", "推动周围载具"), {"jedimode"}, "推动附近的车辆", function(toggle)
	gUsingForce = toggle
	if not gUsingForce then
		return
	end
	notification.help(
		"按下 ~INPUT_VEH_FLY_SELECT_TARGET_RIGHT~ 或 ~INPUT_VEH_FLY_ROLL_RIGHT_ONLY~ 以使用推动附近的车辆")
	local localPed = PLAYER.PLAYER_PED_ID()
	local pos = ENTITY.GET_ENTITY_COORDS(localPed)
	local effect = Effect.new("scr_ie_tw", "scr_impexp_tw_take_zone")
	local colour = Colour.new(0.5, 0, 0.5, 1.0)
	
	requestPtfxAsset(effect.asset)
	GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
	GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR(colour.r, colour.g, colour.b)
	GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY(
		effect.name, 
		localPed, 
		0.0, 
		0.0, 
		-0.9, 
		0.0, 
		0.0, 
		0.0, 
		1.0, 
		false, false, false
	)
	while gUsingForce do
		wait()
		local entities = getNearbyVehicles(players.user(), 50)
		if PAD.IS_CONTROL_PRESSED(0, 118) then
			for k, entity in pairs(entities) do
				requestControl(entity)
				ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, 0, 0, 0.5, 0, 0, 0, 0, false, false, true)
			end
		end
		if PAD.IS_CONTROL_PRESSED(0, 109) then
			for k, entity in pairs(entities) do
				requestControl(entity)
				ENTITY.APPLY_FORCE_TO_ENTITY(entity, 1, 0, 0, -70, 0, 0, 0, 0, false, false, true)
			end
		end
	end
end)

-------------------------------------
-- CARPET RIDE
-------------------------------------

local object
menu.toggle(selfOpt, menuname("Self", "飞毯"), {"carpetride"}, "", function(toggle)
	gUsingCarpetRide = toggle
	local hSpeed = 0.2
	local vSpeed = 0.2
	local localPed = PLAYER.PLAYER_PED_ID()
	local pos = ENTITY.GET_ENTITY_COORDS(localPed)
	local objHash = util.joaat("p_cs_beachtowel_01_s")
	
	if gUsingCarpetRide then
		STREAMING.REQUEST_ANIM_DICT("rcmcollect_paperleadinout@")
		requestModels(objHash)
		TASK.CLEAR_PED_TASKS_IMMEDIATELY(localPed)
		object = OBJECT.CREATE_OBJECT(objHash, pos.x, pos.y, pos.z, true, true, true)
		ENTITY.ATTACH_ENTITY_TO_ENTITY(localPed, object, 0, 0, -0.2, 1.0, 0, 0, 0, false, true, false, false, 0, true)
		ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(object, false, false)

		TASK.TASK_PLAY_ANIM(localPed, "rcmcollect_paperleadinout@", "meditiate_idle", 8, -8, -1, 1, 0, false, false, false)
		notification.help(
			"按下 " .. "~INPUT_MOVE_UP_ONLY~ " .. "~INPUT_MOVE_DOWN_ONLY~ " .. "~INPUT_VEH_JUMP~ " .. "~INPUT_DUCK~ " .. "来使用飞毯\n" ..
			"按下 " .. "~INPUT_VEH_MOVE_UP_ONLY~ " .. "以更快的速度前进"
		)
		local height = ENTITY.GET_ENTITY_COORDS(object, false).z
		
		while gUsingCarpetRide do
			wait()
			HUD.DISPLAY_SNIPER_SCOPE_THIS_FRAME()
			local objPos = ENTITY.GET_ENTITY_COORDS(object)
			local camrot = CAM.GET_GAMEPLAY_CAM_ROT(0)
			ENTITY.SET_ENTITY_ROTATION(object, 0, 0, camrot.z, 0, true)
			local forward = ENTITY.GET_ENTITY_FORWARD_VECTOR(localPed)
			if PAD.IS_CONTROL_PRESSED(0, 32) then
				if PAD.IS_CONTROL_PRESSED(0, 102) then 
					height = height + vSpeed 
				end
				if PAD.IS_CONTROL_PRESSED(0, 36) then 
					height = height - vSpeed 
				end
				ENTITY.SET_ENTITY_COORDS(object, objPos.x + forward.x * hSpeed, objPos.y + forward.y * hSpeed, height, false, false, false, false)
			elseif PAD.IS_CONTROL_PRESSED(0, 130) then
				  ENTITY.SET_ENTITY_COORDS(object, objPos.x - forward.x * hSpeed, objPos.y - forward.y * hSpeed, height, false, false, false, false)
			else
				 if PAD.IS_CONTROL_PRESSED(0, 102) then
					ENTITY.SET_ENTITY_COORDS(object, objPos.x, objPos.y, height, false, false, false, false)
					height = height + vSpeed
				elseif PAD.IS_CONTROL_PRESSED(0, 36) then
					ENTITY.SET_ENTITY_COORDS(object, objPos.x, objPos.y, height, false, false, false, false)
					height = height - vSpeed
				end
			end
			   if PAD.IS_CONTROL_PRESSED(0, 61) then
				hSpeed, vSpeed = 1.5, 1.5
			else
				hSpeed, vSpeed = 0.2, 0.2
			end
		end
	else
		TASK.CLEAR_PED_TASKS_IMMEDIATELY(localPed)
		ENTITY.DETACH_ENTITY(localPed, true, false)
		ENTITY.SET_ENTITY_VISIBLE(object, false)
		entities.delete_by_handle(object)
	end
end)

-------------------------------------
-- UNDEAD OFFRADAR
-------------------------------------

menu.toggle(selfOpt, menuname("Self", "'亡灵'小地图"), {"undeadoffradar"}, "", function(toggle)
	gUsingUndead = toggle
	local localPed = PLAYER.PLAYER_PED_ID()
	local defaultHealth = ENTITY.GET_ENTITY_MAX_HEALTH(localPed)
	
	if gUsingUndead then 
		ENTITY.SET_ENTITY_MAX_HEALTH(localPed, 0)
	end
	
	while gUsingUndead do
		wait()
		if ENTITY.GET_ENTITY_MAX_HEALTH(localPed) ~= 0 then
			ENTITY.SET_ENTITY_MAX_HEALTH(localPed, 0)
		end
	end
	ENTITY.SET_ENTITY_MAX_HEALTH(localPed, defaultHealth)
end)

-------------------------------------
-- TRAILS
-------------------------------------

local bones = {
	0x49D9,	-- left hand
	0xDEAD,	-- right hand
	0x3779,	-- left foot
	0xCC4D	-- right foot
}
local trailsColour = Colour.new(1.0, 0, 1.0, 1.0)
local trailsOpt = menu.list(selfOpt, menuname("Self", "移动尾迹"))

menu.toggle(trailsOpt, menuname("Self - Trails", "移动尾迹"), {"trails"}, "", function(toggle)
	gUsingTrails = toggle
	local effect = Effect.new("scr_rcpaparazzo1", "scr_mich4_firework_sparkle_spawn")
	local effects = {}
	requestPtfxAsset(effect.asset)
	
	util.create_tick_handler(function()	
		local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
		if vehicle == NULL then
			for _, boneId in ipairs(bones) do
				GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
				local fx = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY_BONE(
					effect.name, 
					PLAYER.PLAYER_PED_ID(), 
					0.0, 
					0.0, 
					0.0, 
					0.0, 
					0.0, 
					0.0, 
					PED.GET_PED_BONE_INDEX(PLAYER.PLAYER_PED_ID(), boneId),
					0.7, --scale
					false, false, false
				)
				GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(
					fx, 
					trailsColour.r, 
					trailsColour.g, 
					trailsColour.b, 
					0
				)
				table.insert(effects, fx)
			end
		else
			local minimum = v3.new()
			local maximum = v3.new()
			MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(vehicle), minimum, maximum)

			local offsets = {
				vect.new(v3.getX(minimum), v3.getY(minimum)), -- BACK & LEFT
				vect.new(v3.getX(maximum), v3.getY(minimum)) -- BACK & RIGHT
			}
			v3.free(minimum)
			v3.free(maximum)
			for _, offset in pairs(offsets) do
				GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
				local fx = GRAPHICS.START_NETWORKED_PARTICLE_FX_LOOPED_ON_ENTITY(
					effect.name,
				 	vehicle, 
					offset.x, 
					offset.y, 
					0.0, 
					0.0, 0.0, 0.0, 
					1.0, -- scale
					false, false, false
				)
				GRAPHICS.SET_PARTICLE_FX_LOOPED_COLOUR(
					fx, 
					trailsColour.r, 
					trailsColour.g, 
					trailsColour.b, 
					0
				)
				table.insert(effects, fx)
			end
		end
		return gUsingTrails
	end)
	
	local sTime = os.time()
	while gUsingTrails do
		if os.time() - sTime == 1 then
			for i = 1, #effects do
				GRAPHICS.STOP_PARTICLE_FX_LOOPED(effects[i], 0)
				GRAPHICS.REMOVE_PARTICLE_FX(effects[i], 0)
				effects[i] = nil
			end
			sTime = os.time()
		end
		wait()
	end
	
	for k, effect in pairs(effects) do
		GRAPHICS.STOP_PARTICLE_FX_LOOPED(effect, 0)
		GRAPHICS.REMOVE_PARTICLE_FX(effect, 0)
	end
end)

menu.rainbow(menu.colour(trailsOpt, menuname("Self - Trails", "颜色"), {"trailcolour"}, "", Colour.new(1.0, 0, 1.0, 1.0), false, function(colour)
	trailsColour = colour
end))

-------------------------------------
-- COMBUSTION MAN
-------------------------------------

menu.toggle(selfOpt, menuname("Self", "人形机炮"), {"combustionman"}, "不用武器就能发射爆炸性弹药。如果你认为MK2很烦人，那么你还没有用过这个功能", function(toggle)
	gUsingCombMan = toggle
	if gUsingCombMan then
		notification.help("按下 " .. "~INPUT_ATTACK~ " .. "来使用移动的机炮")
		util.create_tick_handler(function()
			PAD.DISABLE_CONTROL_ACTION(2, 106, true) -- INPUT_VEH_MOUSE_CONTROL_OVERRIDE
			PAD.DISABLE_CONTROL_ACTION(2, 122, true) -- INPUT_VEH_FLY_MOUSE_CONTROL_OVERRIDE
			PAD.DISABLE_CONTROL_ACTION(2, 135, true) -- INPUT_VEH_SUB_MOUSE_CONTROL_OVERRIDE

			local a = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			local b = getOffsetFromCam(80)
			local hash = util.joaat("VEHICLE_WEAPON_PLAYER_LAZER")
			HUD.DISPLAY_SNIPER_SCOPE_THIS_FRAME()
			
			if not WEAPON.HAS_WEAPON_ASSET_LOADED(hash) then
				WEAPON.REQUEST_WEAPON_ASSET(hash, 31, 26)
				while not WEAPON.HAS_WEAPON_ASSET_LOADED(hash) do
					wait()
				end
			end
			
			if PAD.IS_DISABLED_CONTROL_PRESSED(2, 24) then
				MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(
					a.x, a.y, a.z,
					b.x, b.y, b.z,
					200,
					true,
					hash,
					PLAYER.PLAYER_PED_ID(),
					true, true, -1.0
				)
			end

			if not PED.IS_PED_IN_ANY_VEHICLE(PLAYER.PLAYER_PED_ID(), true) then
				PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), true)
			end
			return gUsingCombMan
		end)
	end
end)

-------------------------------------
-- PROOFS
-------------------------------------

local localPedProofs = menu.list(selfOpt, menuname("Self", "防护"), {}, "")
menu.divider(localPedProofs, menuname("Self", "防护"))

for proof, bool in pairsByKeys(gProofs) do
	menu.toggle(localPedProofs, menuname("Self - Proofs", capitalize(proof)), {proof .. "proof"}, "", function(toggle)
		gProofs[ proof ] = toggle
		ENTITY.SET_ENTITY_PROOFS(PLAYER.PLAYER_PED_ID(), gProofs.bullet, gProofs.fire, gProofs.explosion, gProofs.collision, gProofs.melee, gProofs.steam, 1, gProofs.drown)
	end)
end

util.create_tick_handler(function()
	if includes(gProofs, true) then
		ENTITY.SET_ENTITY_PROOFS(PLAYER.PLAYER_PED_ID(), gProofs.bullet, gProofs.fire, gProofs.explosion, gProofs.collision, gProofs.melee, gProofs.steam, 1, gProofs.drown)
	end
	return true
end)

-------------------------------------
-- PROOFS
-------------------------------------

local is_player_pointing = function ()
	return read_global.int(4516656 + 930) == 3
end

menu.toggle_loop(selfOpt, menuname("Self", "上帝之指"), {"forcepush"}, "在你指向实体的同时，使用力将其推开。按B键使用上帝之指。", function()
    if is_player_pointing() then
		local raycastResult = getRaycastResult(300.0, TraceFlag.peds + TraceFlag.vehicles + TraceFlag.objects)
		write_global.int(4516656 + 935, NETWORK.GET_NETWORK_TIME()) -- to avoid the animation to stop
		if raycastResult.didHit and raycastResult.hitEntity ~= NULL then
			drawBoxEsp(raycastResult.hitEntity)
        	ENTITY.SET_ENTITY_PROOFS(PLAYER.PLAYER_PED_ID(), false, false, true --[[explosion proof]], false, false, false, 1, false)
        	local pos = raycastResult.endCoords
			FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 29, 25.0, false, true, 0.0, true)
		end
    end
end)

---------------------
---------------------
-- WEAPON
---------------------
---------------------

local weaponOpt = menu.list(menu.my_root(), menuname("Weapon", "武器"), {"weaponoptions"}, "")
menu.divider(weaponOpt, menuname("Weapon", "武器"))

-------------------------------------
-- VEHICLE PAINT GUN
-------------------------------------

menu.toggle_loop(weaponOpt, menuname("Weapon", "载具喷色枪"), {"paintgun"}, "将车辆应用随机的颜色", function(toggle)
	if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) then
		local entity = getEntityPlayerIsAimingAt(players.user())
		if entity ~= NULL and ENTITY.IS_ENTITY_A_VEHICLE(entity) then
			requestControlLoop(entity)
			local primary, secundary = Colour.random(), Colour.random()
			VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(entity, unpack(secundary))
			VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(entity, unpack(primary))
		end
	end
end)

-------------------------------------
-- SHOOTING EFFECT
-------------------------------------

local ShootEffect = {scale = 0, rotation = {}}
ShootEffect.__index = ShootEffect
setmetatable(ShootEffect, Effect)

function ShootEffect.new(asset, name, scale, rotation)
	inst = setmetatable({}, ShootEffect)
	inst.name = name
	inst.asset = asset
	inst.scale = scale or 1.0
	inst.rotation = rotation or vect.new()
	return inst
end

local shootingEffects = {
	ShootEffect.new("scr_rcbarry2", "scr_clown_bul", 0.3, vect.new(180.0, 0.0, 0.0)), 	-- Clown Flowers	
	ShootEffect.new("scr_rcbarry2", "muz_clown", 0.8)									-- Clown Muz
}
local currentEffect = 1
local shootingEffectOpt = {"停用", "小丑花", "动画枪"}
local shootingEffectList = menu.list(weaponOpt, menuname("Shooting Effect", "射击效果") .. ": " .. menuname("Shooting Effect", shootingEffectOpt[1]) )

for i, option in ipairs(shootingEffectOpt) do
	menu.action(shootingEffectList, menuname("Shooting Effect", option), {}, "", function()
		currentEffect = i	
		menu.set_menu_name(shootingEffectList, menuname("Shooting Effect", "镜头特效") .. ": " .. menuname("Shooting Effect", option) )
		menu.focus(shootingEffectList)
	end)
end

util.create_tick_handler(function()
	if currentEffect == 1 then
		return true
	else
		local effect = shootingEffects[ currentEffect - 1 ]
		if STREAMING.HAS_NAMED_PTFX_ASSET_LOADED(effect.asset) then
			if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) then
				local weapon = WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX(PLAYER.PLAYER_PED_ID(), false)
				GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
				GRAPHICS._START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY_BONE(
					effect.name,
					weapon,
					0.0,
					0.0,
					0.0,
					effect.rotation.x,
					effect.rotation.y,
					effect.rotation.z,
					ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(weapon, "gun_muzzle"),
					effect.scale,
					false, false, false
				)
			end
		else
			STREAMING.REQUEST_NAMED_PTFX_ASSET(effect.asset)
		end
	end
	return true
end)

-------------------------------------
-- MAGNET GUN
-------------------------------------

local magnetGunOptions = {"停用", "平滑模式", "混乱模式"}
local currentMagnetGun
local sphereColour = Colour.new(0, 255, 255, 255)
local magnetGunList = menu.list(weaponOpt, menuname("Weapon", "磁力枪") .. ": " .. menuname("Weapon - Magnet Gun", magnetGunOptions[1]))

for i, option in ipairs(magnetGunOptions) do
	menu.action(magnetGunList, menuname("Weapon - Magnet Gun", option), {}, "", function()
		currentMagnetGun = i
		menu.set_menu_name(magnetGunList, menuname("Weapon", "磁力枪") .. ": " .. menuname("Weapon - Magnet Gun", option) )
		menu.focus(magnetGunList)
	end)
end

util.create_tick_handler(function()
	if currentMagnetGun == 1 then
		return true -- basically doing nothing
	elseif (currentMagnetGun == 2 or currentMagnetGun == 3) and PLAYER.IS_PLAYER_FREE_AIMING(PLAYER.PLAYER_ID()) then
		local vehiclesArray = {}
		local offset = getOffsetFromCam(30)
		for _, vehicle in ipairs(entities.get_all_vehicles_as_handles()) do
			if vehicle == PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false) then
				goto continue
			end
			local vpos = ENTITY.GET_ENTITY_COORDS(vehicle)
			if vect.dist2(offset, vpos) < 4900.0 and requestControl(vehicle) and #vehiclesArray < 20 then
				insertOnce(vehiclesArray, vehicle)
				local unitv = vect.norm(vect.subtract(offset, vpos))
				local dist = vect.dist(offset, vpos)
				-- smooth magnetgun				
				if currentMagnetGun == 2 then 
					local vel = vect.mult(unitv, dist)
					ENTITY.SET_ENTITY_VELOCITY(vehicle, vel.x, vel.y, vel.z)
				-- caos mode
				elseif currentMagnetGun == 3 then
					local mult = 15 * (1 - 2^(-dist))
					local force = vect.mult(unitv, mult)
					ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, force.x, force.y, force.z, 0, 0, 0.5, 0, false, false, true)
				end
			end
			::continue::
		end
		GRAPHICS._DRAW_SPHERE(offset.x, offset.y, offset.z, 0.5, sphereColour.r, sphereColour.g, sphereColour.b, 0.5)
		Colour.rainbow(sphereColour)
	end
	return true
end)

-------------------------------------
-- AIRSTRIKE GUN
-------------------------------------

menu.toggle_loop(weaponOpt, menuname("Weapon", "空袭枪"), {}, "", function(toggle)
	local hash = util.joaat("weapon_airstrike_rocket")
	if not WEAPON.HAS_WEAPON_ASSET_LOADED(hash) then
		WEAPON.REQUEST_WEAPON_ASSET(hash, 31, 0)
	end
	local raycastResult = getRaycastResult(1000.0)
	if raycastResult.didHit and PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) then
		local coords = raycastResult.endCoords
		MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(
			coords.x, coords.y, coords.z + 35,
			coords.x, coords.y, coords.z,
			200 --[[damage]], true, hash --[[weapon]], PLAYER.PLAYER_PED_ID() --[[owner]], true, false, 2500.0 --[[speed]])
	end
end)

-------------------------------------
-- BULLET CHANGER
-------------------------------------

local ammo_ptrs = --belongs to ammo type 4
{
	WT_FLAREGUN		= {hash = 0x47757124},
	WT_GL			= {hash = 0xA284510B},
	WT_GNADE 		= {hash = 0x93E220BD},
	WT_MOLOTOV		= {hash = 0x24B17070},
	WT_GNADE_SMK	= {hash = 0xFDBC8A50},
	WT_SNWBALL		= {hash = 0x0787F0BB}
}

local weaponModelList = {
	WT_A_RPG		= "weapon_rpg",
	WT_FWRKLNCHR	= "weapon_firework",
	WT_RAYPISTOL	= "weapon_raypistol"
}

local bullet 			= 0xB1CA77B1
local fromMemory 		= false
local defaultBulletType = {}


function getCurrentWeaponAmmoType() --returns 4 if OBJECT (rocket, grenade, etc.), and 2 if INSTANT HIT
	local offsets = {0x08, 0x10D8, 0x20, 0x54}
	local addr = addressFromPointerChain(gWorldPtr, offsets)
	if addr ~= NULL then
		return memory.read_byte(addr), addr
	end
	return -1, NULL
end

function getCurrentWeaponAmmoPtr()
	local offsets = {0x08, 0x10D8, 0x20, 0x60}
	local addr = addressFromPointerChain(gWorldPtr, offsets)
	if addr ~= NULL then
		return memory.read_long(addr), addr
	end
	return -1, NULL
end

function setBulletToDefault()
	for weapon, data in pairs(defaultBulletType) do
		local atype, aptr = data.ammoType, data.ammoPtr
		memory.write_byte(atype.addr, atype.value)
		memory.write_long(aptr.addr, aptr.value)
	end
end

local bulletTypeToggle = menu.toggle(weaponOpt, menuname("Weapon", "修改子弹类型") .. ": " .. HUD._GET_LABEL_TEXT("WT_A_RPG"), {"bulletchanger"}, "", function(toggle)
	gUsingBulletChanger = toggle
	
	while gUsingBulletChanger do
		if not fromMemory then
			setBulletToDefault()
			local localPed = PLAYER.PLAYER_PED_ID()			
			if PED.IS_PED_SHOOTING(localPed) and getCurrentWeaponAmmoType() ~= 4 then
				local currentWeapon = WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX(localPed, false)
				local pos1 = ENTITY._GET_ENTITY_BONE_POSITION_2(currentWeapon, ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(currentWeapon, "gun_muzzle"))
				local pos2 = getOffsetFromCam(30.0)
				MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, 200, true, bullet, localPed, true, false, 2000.0)
			end
		else
			local weaponPtr = memory.alloc_int()
			WEAPON.GET_CURRENT_PED_WEAPON(PLAYER.PLAYER_PED_ID(), weaponPtr, true)
			local weaponHash = memory.read_int(weaponPtr)
			memory.free(weaponPtr)
			local ammoType, ammoTypeAddr = getCurrentWeaponAmmoType()
			local ammoPtr, ammoPtrAddr 	 = getCurrentWeaponAmmoPtr()
			if ammoTypeAddr ~= NULL and ammoPtrAddr ~= NULL then
				if not doesKeyExist(defaultBulletType, weaponHash) then				
					defaultBulletType[ weaponHash ] = 
					{
						ammoType 	= {addr = ammoTypeAddr, value = ammoType},
						ammoPtr 	= {addr = ammoPtrAddr,  value = ammoPtr}
					}
					memory.write_byte(ammoTypeAddr, 4)
					memory.write_long(ammoPtrAddr, bullet)
				else
					memory.write_byte(ammoTypeAddr, 4)
					memory.write_long(ammoPtrAddr, bullet)
				end
			end
		end
		wait()
	end

	setBulletToDefault()
end)

local bulletTypeList = menu.list(weaponOpt, menuname("Weapon", "设置武器子弹"))
menu.divider(bulletTypeList, menuname("Weapon", "设置子弹类型"))

local throwablesList = menu.list(bulletTypeList, HUD._GET_LABEL_TEXT("AT_THROW"), {}, "其他玩家只能看到爆炸")
menu.divider(throwablesList, HUD._GET_LABEL_TEXT("AT_THROW"))

for label, modelName in pairsByKeys(weaponModelList) do
	local strg = HUD._GET_LABEL_TEXT(label)
	menu.action(bulletTypeList, strg, {}, "", function()
		bullet = util.joaat(modelName)
		menu.set_menu_name(bulletTypeToggle, menuname("Weapon", "修改子弹类型") .. ": " .. strg)
		menu.focus(bulletTypeList)
		fromMemory = false
	end)
end

for label, data in pairsByKeys(ammo_ptrs) do
	local strg = HUD._GET_LABEL_TEXT(label)
	menu.action(throwablesList, strg, {}, "", function()
		local weaponPtr = memory.alloc(12)
		WEAPON.GET_CURRENT_PED_WEAPON(PLAYER.PLAYER_PED_ID(), weaponPtr)
		local currentWeapon = memory.read_int(weaponPtr)
		memory.free(weaponPtr)

		if data.ammoPtr == nil then
			WEAPON.GIVE_WEAPON_TO_PED(PLAYER.PLAYER_PED_ID(), data.hash, -1, false, false)
			WEAPON.SET_CURRENT_PED_WEAPON(PLAYER.PLAYER_PED_ID(), data.hash, false)
			data.ammoPtr = getCurrentWeaponAmmoPtr()
			WEAPON.SET_CURRENT_PED_WEAPON(PLAYER.PLAYER_PED_ID(), currentWeapon, false)
		end
		
		bullet = data.ammoPtr
    	menu.set_menu_name(bulletTypeToggle, menuname("Weapon", "修改子弹类型") .. ": " .. strg)
		menu.focus(bulletTypeList)
		fromMemory = true
  	end)
end

-------------------------------------
-- HIT EFFECT
-------------------------------------

local HitEffect = {colorCanChange = false}
HitEffect.__index = HitEffect
setmetatable(HitEffect, Effect)

function HitEffect.new(asset, name, colorCanChange)
	local inst = setmetatable({}, HitEffect)
	inst.name = name
	inst.asset = asset
	inst.colorCanChange = colorCanChange or false
	return inst
end

local hitEffects = {
	["小丑爆炸"] 		= HitEffect.new("scr_rcbarry2", "scr_exp_clown"),
	["小丑出现"] 			= HitEffect.new("scr_rcbarry2", "scr_clown_appears"),
	["星星枪"] 			= HitEffect.new("scr_rcpaparazzo1", "scr_mich4_firework_trailburst_spawn", true),
	["星星烟花"] 			= HitEffect.new("scr_indep_fireworks", "scr_indep_firework_starburst", true),
	["星星水"] 			= HitEffect.new("scr_indep_fireworks", "scr_indep_firework_fountain", true),
	["外星人消失"] 	= HitEffect.new("scr_rcbarry1", "scr_alien_disintegrate"),
	["小丑花"] 			= HitEffect.new("scr_rcbarry2", "scr_clown_bul"),
	["地面爆炸"] 		= HitEffect.new("proj_indep_firework", "scr_indep_firework_grd_burst")
}
local currentEffect = hitEffects["小丑爆炸"]
local effectColour = Colour.new(0.5, 0.0, 0.5, 1.0)

local hitEffectRoot = menu.list(weaponOpt, menuname("Hit Effect", "子弹效果"))
menu.divider(hitEffectRoot, menuname("Hit Effect", "子弹效果"))

local hitEffectToggle = menu.toggle_loop(hitEffectRoot,  menuname("Hit Effect", "子弹效果") .. ": " .. menuname("Hit Effect", "小丑爆炸"), {}, "", function(toggle)
	if STREAMING.HAS_NAMED_PTFX_ASSET_LOADED(currentEffect.asset) then
		local hitCoordsInst = v3.new()
		if WEAPON.GET_PED_LAST_WEAPON_IMPACT_COORD(PLAYER.PLAYER_PED_ID(), hitCoordsInst) then
			local hitCoords = vect.new(v3.get(hitCoordsInst))
			local camCoords = CAM.GET_FINAL_RENDERED_CAM_COORD()
			local direction = vect.norm(vect.subtract(hitCoords, camCoords))
			local raycastResult = getRaycastResult(1000.0)
			local rot = toRotation(raycastResult.surfaceNormal)
			
			GRAPHICS.USE_PARTICLE_FX_ASSET(currentEffect.asset)
			if currentEffect.colorCanChange then
				local colour = effectColour
				GRAPHICS.SET_PARTICLE_FX_NON_LOOPED_COLOUR(colour.r, colour.g, colour.b)
			end
			GRAPHICS.START_NETWORKED_PARTICLE_FX_NON_LOOPED_AT_COORD(
				currentEffect.name, 
				hitCoords.x,
				hitCoords.y,
				hitCoords.z,
				rot.x - 90.,
				rot.y,
				rot.z,
				1.0,
				false, false, false, false
			)
		end
		v3.free(hitCoordsInst)
	else
		STREAMING.REQUEST_NAMED_PTFX_ASSET(currentEffect.asset)
	end
end)

local hitEffectList = menu.list(hitEffectRoot,  menuname("Hit Effect", "设置效果") )
for name, effect in pairs(hitEffects) do
	local helpText = ""
	if effect.colorCanChange then
		helpText = "Colour can be changed."
	end
	menu.action(hitEffectList, menuname("Hit Effect", name), {}, helpText, function()
		currentEffect = effect
		menu.set_menu_name(hitEffectToggle, menuname("Hit Effect", "设置效果") .. ": " .. menuname("Hit Effect", name) )
		menu.focus(hitEffectList)
	end)
end

menu.rainbow(menu.colour(hitEffectRoot, menuname("Hit Effect", "颜色"), {"effectcolour"}, "只在某些效果上起作用.",  Colour.new(0.5, 0, 0.5, 1.0), false, function(colour)
	effectColour = colour
end))

-------------------------------------
-- VEHICLE GUN
-------------------------------------

local vehicleModelList = {
	["天煞"] 			= "lazer",
	["叛乱分子"] 		= "insurgent2",
	["乔氏 尖锥魅影"] 	= "phantom2",
	["Adder"] 			= "adder"
}
local vehicleHash = vehicleModelList.Adder
local setIntoVehicle = false
local vehiclePreview
local offset = 25.0
local maxOffset = 100.0
local minOffset = 15.0
local offsetMult = 0.0

local vehicleGunRoot = menu.list(weaponOpt, menuname("Weapon", "载具枪"), {"vehiclegun"}, "")
menu.divider(vehicleGunRoot, menuname("Weapon", "载具枪"))

local vehicleGunToggle = menu.toggle_loop(vehicleGunRoot, menuname("Weapon", "载具枪") .. ": 特卢菲 灵蛇", {"togglevehiclegun"}, "", function()
	local vehicleHash = util.joaat(vehicleHash)
	local rot = CAM.GET_GAMEPLAY_CAM_ROT(0)
	requestModels(vehicleHash)
	local raycastResult = getRaycastResult(offset + 5.0, TraceFlag.world)
	local coords = raycastResult.endCoords

	if not gConfig.general.disablepreview then 
		local offsetLimit = minOffset + offsetMult * (maxOffset - minOffset)
		offset = increment(offset, 0.5, offsetLimit)
		if PAD.IS_CONTROL_JUST_PRESSED(2, 241) and PAD.IS_CONTROL_PRESSED(2, 241) then
			if offsetMult < 1.0 then offsetMult = offsetMult + 0.25 end
		end		
		if PAD.IS_CONTROL_JUST_PRESSED(2, 242) and PAD.IS_CONTROL_PRESSED(2, 242) then
			if offsetMult > 0.0 then offsetMult = offsetMult - 0.25 end
		end
	end

	if not raycastResult.didHit then 
		coords = getOffsetFromCam(offset) 
	end
	if PLAYER.IS_PLAYER_FREE_AIMING(PLAYER.PLAYER_ID()) then
		if not gConfig.general.disablepreview then
			if not ENTITY.DOES_ENTITY_EXIST(vehiclePreview) then
				vehiclePreview = VEHICLE.CREATE_VEHICLE(vehicleHash, coords.x, coords.y, coords.z, rot.z, false, false)
				ENTITY.SET_ENTITY_ALPHA(vehiclePreview, 153, true)
				ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(vehiclePreview, false, false)
			end
			ENTITY.SET_ENTITY_COORDS_NO_OFFSET(vehiclePreview, coords.x, coords.y, coords.z, false, false, false)
			if raycastResult.didHit then
				VEHICLE.SET_VEHICLE_ON_GROUND_PROPERLY(vehiclePreview, 1.0)
			end
			ENTITY.SET_ENTITY_ROTATION(vehiclePreview, rot.x, rot.y, rot.z, 0, true)
			-- instructional buttons
			if instructional:begin() then
				instructional.add_control_group(29, "FM_AE_SORT_2")
				instructional:set_background_colour(0, 0, 0, 80)
				instructional:draw()
			end	
		end
		-- preview management
		if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) then
			if ENTITY.DOES_ENTITY_EXIST(vehiclePreview) then
				entities.delete_by_handle(vehiclePreview)
			end
			local vehicle = entities.create_vehicle(vehicleHash, coords, rot.z)
			ENTITY.SET_ENTITY_ROTATION(vehicle, rot.x, rot.y, rot.z, 0, true) 
			if setIntoVehicle then
				VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
				PED.SET_PED_INTO_VEHICLE(PLAYER.PLAYER_PED_ID(), vehicle, -1)
			else 
				VEHICLE.SET_VEHICLE_DOORS_LOCKED(vehicle, 2)
			end
			ENTITY.SET_ENTITY_LOAD_COLLISION_FLAG(vehicle, true)
			VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicle, 200)
			ENTITY._SET_ENTITY_CLEANUP_BY_ENGINE(vehicle, true)
		end
	else
		if ENTITY.DOES_ENTITY_EXIST(vehiclePreview) then
			entities.delete_by_handle(vehiclePreview)
		end
	end
end)

local vehicleGunList = menu.list(vehicleGunRoot, menuname("Weapon - Vehicle Gun", "设置载具"))
for name, vehicle in pairsByKeys(vehicleModelList) do
	menu.action(vehicleGunList, name, {}, "", function()
		vehicleHash = vehicleModelList[ name ]
		menu.set_menu_name(vehicleGunToggle, "载具枪: " .. name)
		menu.focus(vehicleGunList)
	end)
end

menu.text_input(vehicleGunRoot, menuname("Weapon - Vehicle Gun", "自定义车辆"), {"customvehgun"}, "", function(vehicle)
	local modelHash = util.joaat(vehicle)
	local name = HUD._GET_LABEL_TEXT(VEHICLE.GET_DISPLAY_NAME_FROM_VEHICLE_MODEL(modelHash))
	if STREAMING.IS_MODEL_A_VEHICLE(modelHash) then
		vehicleHash = vehicle
		menu.set_menu_name(vehicleGunToggle, "载具枪: " .. name)
	else
		notification.help("该模型不是载具", HudColour.red) 
		return
	end
end)

menu.toggle(vehicleGunRoot, menuname("Weapon - Vehicle Gun", "传送到载具里"), {}, "", function(toggle)
	setIntoVehicle = toggle
end)

-------------------------------------
-- TELEPORT GUN
-------------------------------------


local function writeVector3(address, vector)
	memory.write_float(address + 0x0, vector.x)
	memory.write_float(address + 0x4, vector.y)
	memory.write_float(address + 0x8, vector.z)
end

local function setEntityCoords(entity, coords) 
	local fwEntity = entities.handle_to_pointer(entity)
	local CNavigation = memory.read_long(fwEntity + 0x30)
	if CNavigation ~= 0 then
		writeVector3(CNavigation + 0x50, coords)
		writeVector3(fwEntity + 0x90, coords)
	end
	
	
	--[[
	memory.write_float(CNavigation + 0x50, coords.x)
	memory.write_float(CNavigation + 0x54, coords.y)
	memory.write_float(CNavigation + 0x58, coords.z)
	memory.write_float(fwEntity + 0x90, coords.x)
	memory.write_float(fwEntity + 0x94, coords.y)
	memory.write_float(fwEntity + 0x98, coords.z)
	]]
	
end

menu.toggle_loop(weaponOpt, menuname("Weapon", "传送枪"), {"tpgun"}, "", function(toggle)
	local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
	local raycastResult = getRaycastResult(1000.0)
	if raycastResult.didHit and PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) then
		local coords = raycastResult.endCoords	
		if vehicle == NULL then
			coords.z = coords.z + 1.0
			setEntityCoords(PLAYER.PLAYER_PED_ID(), coords)
		else
			local speed = ENTITY.GET_ENTITY_SPEED(vehicle)
			ENTITY.SET_ENTITY_COORDS(vehicle, coords.x, coords.y, coords.z, false, false, false, false)
			ENTITY.SET_ENTITY_HEADING(vehicle, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
			VEHICLE.SET_VEHICLE_FORWARD_SPEED(vehicle, speed + 2.5)
		end
	end
end)

-------------------------------------
-- BULLET SPEED MULT
-------------------------------------

local defaultBulletSpeed = {}
gBulletSpeedMult = 1

function SET_AMMO_SPEED_MULT(mult)
	local CPed = entities.handle_to_pointer(PLAYER.PLAYER_PED_ID())
	local CPedWeaponManager = memory.read_long(CPed + 0x10D8)
	local CWeaponInfo = memory.read_long(CPedWeaponManager + 0x20)
	local CAmmoInfo = memory.read_long(CWeaponInfo + 0x60)
	local speedPtr = CAmmoInfo + 0x58

	if CAmmoInfo == NULL then
		return 
	end

	local speed = memory.read_float(speedPtr)
	if not doesKeyExist(defaultBulletSpeed, speedPtr) then
		defaultBulletSpeed[ speedPtr ] = speed
		memory.write_float(speedPtr, mult * speed)
	elseif speed ~= mult * defaultBulletSpeed[ speedPtr ] then
		memory.write_float(speedPtr, mult * defaultBulletSpeed[ speedPtr ])
	end
end

menu.click_slider(weaponOpt, menuname("Weapon", "子弹速度"), {"bulletspeedmult"},  "允许你改变非即时命中的子弹（火箭、烟花、手榴弹等）的速度。", 100, 3500, 100, 50, function(mult)
	gBulletSpeedMult = mult / 100
	if gBulletSpeedMult == 1 then
		for addr,  value in pairs(defaultBulletSpeed) do
			memory.write_float(addr, value)
			defaultBulletSpeed[addr] = nil
		end
	end
end)

-------------------------------------
-- MAGNET ENTITIES
-------------------------------------

local apply_force_to_entity = function(ent, flag, force)
	if ENTITY.IS_ENTITY_A_PED(ent) then
		if not PED.IS_PED_A_PLAYER(ent) then
			requestControl(ent)
			PED.SET_PED_TO_RAGDOLL(ent, 1000, 1000, 0, 0, 0, 0)
			ENTITY.APPLY_FORCE_TO_ENTITY(ent, flag, force.x, force.y, force.z, 0.0, 0.0, 0.0, 0, false, false, true)
		end
	else
		requestControl(ent)
		ENTITY.APPLY_FORCE_TO_ENTITY(ent, flag, force.x, force.y, force.z, 0.0, 0.0, 0.0, 0, false, false, true)
	end
end


menu.toggle(weaponOpt, menuname("Weapon", "实体磁铁枪"), {}, "", function(toggle)
	gUsingMagnetEnt = toggle
	if not gUsingMagnetEnt then 
		return
	end	
	notification.help(
		"实体磁铁枪可以对两个特定实体施加吸引力。 " ..
		"射击选定的实体（车辆，物体或行人）以相互吸引它们"
	)
	local entArray = {}
	local entities = {}
	local ent_counter = 0

	while gUsingMagnetEnt do
		wait()
		local ent = getEntityPlayerIsAimingAt(players.user())
		if ent ~= NULL and ENTITY.DOES_ENTITY_EXIST(ent) then
			drawBoxEsp(ent, Colour.new(255, 0, 0, 255))
			if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) and not (entities[1] ~= nil and entities[1] == ent) then
				ent_counter = ent_counter + 1
				entities[ent_counter] = ent
			end
			if ent_counter == 2 then
				entArray[#entArray + 1] = entities;
				ent_counter = 0
				entities = {}
			end			
		end
		for i = 1, #entArray do
			if entArray[i] then
				local ent1, ent2 = entArray[i][1], entArray[i][2]
				if ENTITY.DOES_ENTITY_EXIST(ent1) and ENTITY.DOES_ENTITY_EXIST(ent2) then
					local pos1 = ENTITY.GET_ENTITY_COORDS(ent1)
					local pos2 = ENTITY.GET_ENTITY_COORDS(ent2)
					local dist = vect.dist2(pos1, pos2)
					local force = vect.mult(vect.norm(vect.subtract(pos2, pos1)), dist / 400)							
					apply_force_to_entity(ent1, 1, force)
					apply_force_to_entity(ent2, 1, vect.mult(force, -1))
				else
					table.remove(entArray, i)
				end	
			end					
		end
	end
end)

-------------------------------------
-- VALKYIRE ROCKET
-------------------------------------

menu.toggle(weaponOpt, menuname("Weapon", "女武神火箭"), {"valkrocket"}, "", function(toggle)
	gUsingValkRocket = toggle
	if gUsingValkRocket then
		local rocket
		local cam
		local blip
		local init
		local draw_rect = function(x, y, z, w)
			GRAPHICS.DRAW_RECT(x, y, z, w, 255, 255, 255, 255)
		end

		while gUsingValkRocket do
			if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) and not init then
				init = true 
				sTime = cTime()
			elseif init then
				if not ENTITY.DOES_ENTITY_EXIST(rocket) then
					local weapon = WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX(PLAYER.PLAYER_PED_ID())
					local offset = getOffsetFromCam(10)
			
					rocket = OBJECT.CREATE_OBJECT_NO_OFFSET(util.joaat("w_lr_rpg_rocket"), offset.x, offset.y, offset.z, true, false, true)
					ENTITY.SET_ENTITY_INVINCIBLE(rocket, true)
					ENTITY._SET_ENTITY_CLEANUP_BY_ENGINE(rocket, true)
					ENTITY.SET_ENTITY_LOAD_COLLISION_FLAG(rocket, true, 1)
					NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NETWORK.OBJ_TO_NET(rocket), true);
					NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.OBJ_TO_NET(rocket), false)
					ENTITY.SET_ENTITY_RECORDS_COLLISIONS(rocket, true)
					ENTITY.SET_ENTITY_HAS_GRAVITY(rocket, false)
				
					CAM.DESTROY_ALL_CAMS(true)
					cam = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", true)
					CAM.SET_CAM_NEAR_CLIP(cam, 0.01)
					CAM.SET_CAM_NEAR_DOF(cam, 0.01)
					GRAPHICS.CLEAR_TIMECYCLE_MODIFIER()
					GRAPHICS.SET_TIMECYCLE_MODIFIER("CAMERA_secuirity")
					ATTACH_CAM_TO_ENTITY_WITH_FIXED_DIRECTION(cam, rocket, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1)
					CAM.SET_CAM_ACTIVE(cam, true)
					CAM.RENDER_SCRIPT_CAMS(true, false, 0, true, true, 0)

					PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), true)
					ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), true)
				else
					local rot = CAM.GET_GAMEPLAY_CAM_ROT(0)
					local direction = toDirection(CAM.GET_GAMEPLAY_CAM_ROT(0))
					local coords = ENTITY.GET_ENTITY_COORDS(rocket)
					local groundZ = getGroundZ(coords)
					local altitude = math.abs(coords.z - groundZ)
					local force = vect.mult(direction, 40)
					ENTITY.SET_ENTITY_ROTATION(rocket, rot.x, rot.y, rot.z, 0, 1)
					STREAMING.SET_FOCUS_POS_AND_VEL(coords.x, coords.y, coords.z, rot.z, rot.y, rot.z)
					
					ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(rocket, 1, force.x, force.y, force.z, false, false, false, false)

					HUD.HIDE_HUD_AND_RADAR_THIS_FRAME()
					PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), true)
					ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), true)
					HUD._HUD_WEAPON_WHEEL_IGNORE_SELECTION()
					
					draw_rect(0.5, 0.5 - 0.025, 0.050, 0.002)
					draw_rect(0.5, 0.5 + 0.025, 0.050, 0.002)
					draw_rect(0.5 - 0.025, 0.5, 0.002, 0.052)
					draw_rect(0.5 + 0.025, 0.5, 0.002, 0.052)
					draw_rect(0.5 + 0.050, 0.5, 0.050, 0.002)
					draw_rect(0.5 - 0.050, 0.5, 0.050, 0.002)
					draw_rect(0.5, 0.500 + 0.05, 0.002, 0.05)
					draw_rect(0.5, 0.500 - 0.05, 0.002, 0.05)
					
					local maxTime = 7000 -- ms
					local length = 0.5 - 0.5 * (cTime()-sTime) / maxTime -- timer length
					local perc = length / 0.5
					local color = getBlendedColour(perc) -- timer color
					GRAPHICS.DRAW_RECT(0.25, 0.5, 0.03, 0.5, 255, 255, 255, 120)
					GRAPHICS.DRAW_RECT(0.25, 0.75 - length / 2, 0.03, length, color.r, color.g, color.b, color.a)

					if ENTITY.HAS_ENTITY_COLLIDED_WITH_ANYTHING(rocket) or length <= 0 then
						local impactCoord = ENTITY.GET_ENTITY_COORDS(rocket)
						FIRE.ADD_EXPLOSION(impactCoord.x, impactCoord.y, impactCoord.z, 32, 1.0, true, false, 0.4)
						entities.delete_by_handle(rocket)
						PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), false)
						CAM.RENDER_SCRIPT_CAMS(false, false, 3000, true, false, 0)
						GRAPHICS.SET_TIMECYCLE_MODIFIER("DEFAULT")
						STREAMING.CLEAR_FOCUS()
						CAM.DESTROY_CAM(cam, 1)
						PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), false)
						ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), false)					
						rocket = 0
						init = false
					end	
				end
			end
			wait()
		end
		
		if rocket and ENTITY.DOES_ENTITY_EXIST(rocket) then
			local impactCoord = ENTITY.GET_ENTITY_COORDS(rocket)
			FIRE.ADD_EXPLOSION(impactCoord.x, impactCoord.y, impactCoord.z, 32, 1.0, true, false, 0.4)
			entities.delete_by_handle(rocket)
			STREAMING.CLEAR_FOCUS()
			CAM.RENDER_SCRIPT_CAMS(false, false, 3000, true, false, 0)
			CAM.DESTROY_CAM(cam, 1)
			GRAPHICS.SET_TIMECYCLE_MODIFIER("DEFAULT")
			ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), false)
			PLAYER.DISABLE_PLAYER_FIRING(PLAYER.PLAYER_PED_ID(), false)
			if HUD.DOES_BLIP_EXIST(blip) then
				util.remove_blip(blip)
			end
			HUD.UNLOCK_MINIMAP_ANGLE()
			HUD.UNLOCK_MINIMAP_POSITION()
		end
	end
end)

-------------------------------------
-- GUIDED MISSILE
-------------------------------------

menu.action(weaponOpt, menuname("Weapon", "发射制导导弹"), {"missile"}, "", function()
	if not ufo.exists() then 
		guidedMissile.create()
	end
end)

-------------------------------------
-- SUPERPUNCH
-------------------------------------

local function setExplosionProof(toggle)
	ENTITY.SET_ENTITY_PROOFS(PLAYER.PLAYER_PED_ID(), false, false, toggle, false, false, 0, 0, false)
end

menu.toggle_loop(weaponOpt, '一拳超人', {'superpunch'}, '', function()
	local localPed = PLAYER.PLAYER_PED_ID()
	local ptr = memory.alloc()
	WEAPON.GET_CURRENT_PED_WEAPON(localPed, ptr, 1)
	local weaponHash = memory.read_int(ptr)
	memory.free(ptr)

	if WEAPON.IS_PED_ARMED(localPed, 1) or weaponHash == util.joaat("weapon_unarmed") then
		local ptr = memory.alloc()
		if WEAPON.GET_PED_LAST_WEAPON_IMPACT_COORD(localPed, ptr) then
			setExplosionProof(true)
			local pos = ENTITY.GET_ENTITY_COORDS(localPed, false)
			memory.free(ptr)
			FIRE.ADD_EXPLOSION(pos.x, pos.y, pos.z, 29, 5.0, false, true, 0.3, true)
		end
	end
	
	local pos = ENTITY.GET_ENTITY_COORDS(localPed, false)
	setExplosionProof(
		FIRE.IS_EXPLOSION_IN_SPHERE(29, pos.x, pos.y, pos.z, 2.0)
	)
end)

---------------------
---------------------
-- VEHICLE
---------------------
---------------------

local vehicleOptions = menu.list(menu.my_root(), menuname("Vehicle", "载具"), {}, "")
menu.divider(vehicleOptions, menuname("Vehicle", "载具"))

-------------------------------------
-- AIRSTRIKE AIRCRAFT
-------------------------------------

local vehicleWeaponRoot = menu.list(vehicleOptions, menuname("Vehicle", "车载武器"), {"vehicleweapons"}, "允许你在任何车辆上添加武器")
menu.divider(vehicleWeaponRoot, menuname("Vehicle", "车载武器"))

local strikePlanesRoot =  menu.toggle(vehicleOptions, menuname("Vehicle", "空袭飞机"), {"airstrikeplane"}, "使用任何飞机或直升机来进行空袭。", function(toggle)
	gUsingAirstrikePlane = toggle
	
	if not gUsingAirstrikePlane then 
		return 
	end	
	for name, control in pairs(gImputs) do
		if control[2] == gConfig.controls.airstrikeaircraft then
			util.show_corner_help("按下 " .. ('~%s~'):format(name) .. " 使用空袭飞机")
			notification.help("空袭飞机可以在飞机或直升机上使用")
			break
		end
	end	
	while gUsingAirstrikePlane do
		local control = gConfig.controls.airstrikeaircraft
		if isPedInAnyAircraft(PLAYER.PLAYER_PED_ID()) and PAD.IS_CONTROL_PRESSED(2, control) then
			local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID())
			local pos = ENTITY.GET_ENTITY_COORDS(vehicle)
			local startTime = os.time() 
			util.create_tick_handler(function()
				wait(500)
				local groundz = getGroundZ(pos)
				pos.x = pos.x + math.random(-3, 3)
				pos.y = pos.y + math.random(-3, 3)
				if ( pos.z - groundz > 10 ) then
					MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS(
						pos.x, pos.y, pos.z - 3, 
						pos.x, pos.y, groundz, 200, true, util.joaat("weapon_airstrike_rocket"), PLAYER.PLAYER_PED_ID(), true, false, 2500.0)
				end
				return ( os.time() - startTime <= 5 )
			end)
		end
		wait(200)
	end
end)

-------------------------------------
-- VEHICLE WEAPONS
-------------------------------------

function draw_line_from_vehicle(vehicle, startpoint)
	local minimum = v3.new()
	local maximum = v3.new()

	MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(vehicle), minimum, maximum)
	local startcoords = 
	{
		fl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(maximum), 0), --FRONT & LEFT
		fr = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(maximum), 0)  --FRONT & RIGHT
	}	
	local endcoords = 
	{
		fl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(maximum) + 25.0, 0),
		fr = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(maximum) + 25.0, 0)
	}
	local coord1, coord2 = startcoords[ startpoint ], endcoords[ startpoint ]
	GRAPHICS.DRAW_LINE(coord1.x, coord1.y, coord1.z, coord2.x, coord2.y, coord2.z, 255, 0, 0, 150)
	v3.free(minimum)
	v3.free(maximum)
end


function shoot_bullet_from_vehicle(vehicle, weaponName, startpoint)
	local weaponHash = util.joaat(weaponName)
	local minimum = v3.new()
	local maximum = v3.new()

	if not WEAPON.HAS_WEAPON_ASSET_LOADED(weaponHash) then
		WEAPON.REQUEST_WEAPON_ASSET(weaponHash, 31, 26)
		while not WEAPON.HAS_WEAPON_ASSET_LOADED(weaponHash) do
			wait()
		end
	end
	MISC.GET_MODEL_DIMENSIONS(ENTITY.GET_ENTITY_MODEL(vehicle), minimum, maximum)

	local startcoords = 
	{
		fl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(maximum) + 0.25, 0.3), 	-- front-left
		fr = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(maximum) + 0.25, 0.3), 	-- front-right
		bl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(minimum), 0.3), 			-- back-left
		br = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(minimum), 0.3) 			-- back-right
	}	
	local endcoords = 
	{
		fl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(maximum) + 50, 0.0),
		fr = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(maximum) + 50, 0.0),
		bl = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(minimum), v3.getY(minimum) - 50, 0.0),
		br = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(vehicle, v3.getX(maximum), v3.getY(minimum) - 50, 0.0)
	}
	local coord1 = startcoords[ startpoint ]
	local coord2 = endcoords[ startpoint ]
	v3.free(minimum)
	v3.free(maximum)
	MISC.SHOOT_SINGLE_BULLET_BETWEEN_COORDS_IGNORE_ENTITY_NEW(
		coord1.x, coord1.y, coord1.z, 
		coord2.x, coord2.y, coord2.z, 200, true, weaponHash, PLAYER.PLAYER_PED_ID(), true, false, 2000.0, vehicle, false, 0, 1, 0);
end

-------------------------------------
-- VEHICLE LASER
-------------------------------------

menu.toggle(vehicleWeaponRoot, menuname("Vehicle - Vehicle Weapons", "激光器瞄准线"), {"vehiclelasers"},"", function(toggle)
	gUsingVehicleLaser = toggle
	
	if gUsingVehicleLaser and gUsingAirstrikePlane then
		menu.trigger_command(strikePlanesRoot, "off")
	end	
	while gUsingVehicleLaser do
		local vehicle = getVehiclePlayerIsIn(PLAYER.PLAYER_ID())
		if vehicle ~= NULL then
			draw_line_from_vehicle(vehicle, "fl")
			draw_line_from_vehicle(vehicle, "fr")
		end
		wait()
	end
end)

-------------------------------------
-- VEHICLE WEAPONS
-------------------------------------

local vehicleWeapons = {
	{"weapon_vehicle_rocket", "WT_V_SPACERKT", PAD.IS_CONTROL_JUST_PRESSED},
	{"weapon_raypistol", "WT_RAYPISTOL", PAD.IS_CONTROL_PRESSED},
	{"weapon_firework", "WT_FWRKLNCHR", PAD.IS_CONTROL_JUST_PRESSED},
	{"vehicle_weapon_tank", "WT_V_TANK", PAD.IS_CONTROL_JUST_PRESSED},
	{"vehicle_weapon_player_lazer", "WT_V_PLRBUL", PAD.IS_CONTROL_PRESSED}
}
local selected = 1

local vehicleWeaponsToggle = menu.toggle(vehicleWeaponRoot, menuname("Vehicle - Vehicle Weapons", "车载武器") .. ": " .. HUD._GET_LABEL_TEXT("WT_V_SPACERKT"), {}, "", function(toggle)
	gUsingVehicleRockets = toggle
	
	if not gUsingVehicleRockets then 
		return 
	end	
	for name, control in pairs(gImputs) do
		if control[2] == gConfig.controls.vehicleweapons then
			util.show_corner_help("按下 " .. ('~%s~'):format(name) .. " 以使用车载武器")
			break
		end
	end
	
	while gUsingVehicleRockets do
		local control = gConfig.controls.vehicleweapons
		local vehicle = getVehiclePlayerIsIn(PLAYER.PLAYER_ID())
		if vehicle ~= NULL and vehicleWeapons[ selected ][ 3 ](2, control) then
			if not PAD.IS_CONTROL_PRESSED(0, 79) then
				shoot_bullet_from_vehicle(vehicle, vehicleWeapons[ selected ][1], "fl")
				shoot_bullet_from_vehicle(vehicle, vehicleWeapons[ selected ][1], "fr")
			else
				shoot_bullet_from_vehicle(vehicle, vehicleWeapons[ selected ][1], "bl")
				shoot_bullet_from_vehicle(vehicle, vehicleWeapons[ selected ][1], "br")
			end
		end
		wait()
	end
end)

local vehicleWeaponList = menu.list(vehicleWeaponRoot, menuname("Vehicle - Vehicle Weapons", "设置车载武器"))
menu.divider(vehicleWeaponList, HUD._GET_LABEL_TEXT("PM_WEAPONS"))

for i, table in pairsByKeys(vehicleWeapons) do
	local strg = HUD._GET_LABEL_TEXT( table[2] )
	menu.action(vehicleWeaponList, strg, {strg}, "", function()
		selected = i
		menu.set_menu_name(vehicleWeaponsToggle, menuname("Vehicle - Vehicle Weapons", "设置车载武器") .. ": " .. strg)
		menu.focus(vehicleWeaponList)
	end)
end

-------------------------------------
-- VEHICLE HANDLING EDITOR
-------------------------------------

local handling_editor = menu.list(vehicleOptions, menuname("Vehicle", "载具信息编辑器"), {}, "", function()
	handling.display_handling = true
end, function()
	handling.display_handling = false
	if handling.cursor_mode then
		handling.cursor_mode = false
		UI.toggle_cursor_mode(false)
	end
end)


handling = {
	cursor_mode = false,
	window_x = 0.02,
	window_y = 0.08,
	inviewport = {},
	display_handling = false,
	flying = {},
	boat = {},
	offsets = 
	{
		-- handling
		{    
			{"质量", 0xC},
			{"初始阻力系数", 0x10},
			{"下压力修改器", 0x14},
			{"重心偏移 X", 0x20},
			{"重心偏移 Y", 0x24},
			{"重心偏移 Z", 0x28},
			{"慣性数值 X", 0x30},
			{"慣性数值 Y", 0x34},
			{"慣性数值 Z", 0x38},
			{"潜水淹没百分比", 0x40},
			{"淹没率", 0x44},
			{"前驱偏差", 0x48},
			{"加速度", 0x4C},
			{"行驶慣性", 0x54},
			{"升档", 0x58},
			{"降档", 0x5C},
			{"初始驱动动力力量", 0x60},
			{"驱动最大水平速度", 0x64},
			{"初始驱动最大水平速度", 0x68},
			{"制动力", 0x6C},
			{"前制动偏压", 0x74},
			{"后轮刹车效率比", 0x78},
			{"手刹制动力", 0x7C},
			{"转向锁", 0x80},
			{"转向锁定率", 0x84},
			{"最大牵引曲线", 0x88},
			{"最大牵引曲线率", 0x8C},
			{"最小牵引曲线", 0x90},
			{"最小牵引曲线率", 0x94},
			{"侧向牵引曲线", 0x98},
			{"侧向牵引曲线率", 0x9C},
			{"牵引弹簧最大增量", 0xA0},
			{"牵引弹簧最大增量率", 0xA4},
			{"低速下牵引倍增器", 0xA8},
			{"外倾刚度", 0xAC},
			{"牵引偏前", 0xB0},
			{"牵引偏后", 0xB4},
			{"牵引损失乘数", 0xB8},
			{"悬挂力", 0xBC},
			{"悬架补偿阻尼", 0xC0},
			{"悬挂反弹阻尼", 0xC4},
			{"悬架下限", 0xC8},
			{"悬架上限", 0xCC},
			{"悬架提升", 0xD0},
			{"悬架垂直偏压", 0xD4},
			{"悬架后方偏压", 0xD8},
			{"防倾杆力", 0xDC},
			{"前防倾杆偏置", 0xE0},
			{"后防倾杆偏置", 0xE4},
			{"前侧倾中心高度", 0xE8},
			--{"前侧倾中心高度", 0xEC},
			{"碰撞伤害数值", 0xF0},
			{"武器伤害数值", 0xF4},
			--{"武器伤害数值", 0xF8},
			{"发动机损坏数值", 0xFC},
			{"油箱容量", 0x100},
			{"油量", 0x104},
			{"座椅偏移距离 X", 0x10C},
			{"座椅偏移距离 Y", 0x110},
			{"座椅偏移距离 Z", 0x114},
			{"加速", 0x120}
		},
		-- flying
		{
			{"推力", 0x338},
			{"下降推力", 0x33C},
			{"推力向量", 0x340},
			{"偏航倍数", 0x34C},
			{"偏航稳定器", 0x350},
			{"侧滑移倍数", 0x354},
			{"转动倍数", 0x35C},
			{"侧倾稳定器", 0x360},
			{"螺距倍数", 0x368},
			{"俯仰稳定器", 0x36C},
			{"升降速率", 0x374},
			{"攻击力倍数", 0x378},
			{"水下攻击力倍数", 0x37C},
			{"降档阻力", 0x380},
			{"降档提升倍数", 0x384},
			{"风力倍数", 0x388},
			{"移动速率", 0x38C},
			{"转动分辨率 X", 0x390},
			{"转动分辨率 Y", 0x394},
			{"转动分辨率 Z", 0x398},
			{"速度分辨率 X", 0x3A0},
			{"速度分辨率 Y", 0x3A4},
			{"速度分辨率 Z", 0x3A8},
			{"前齿轮门开合度", 0x3B0},
			{"后齿轮门开合度", 0x3B4},
			{"后齿轮门开合度2", 0x3B8},
			{"后齿轮门超频开合", 0x3BC},
			{"湍流幅度最大值", 0x3C0},
			{"前湍流力", 0x3C4},
			{"湍流滚动扭矩", 0x3C8},
			{"湍流节距扭矩", 0x3CC},
			{"身体伤害控制倍数", 0x3D0},
			{"难度驾驶灵敏度", 0x3D4},
			{"偏航助力速度峰值", 0x3D8},
			{"偏航助力速度上限", 0x3DC},
			{"引擎关闭滑行", 0x3E0},
			{"力增强燃烧效应半径", 0x3E4},
			{"力增强燃烧效应距离", 0x3E8},
			{"力增强燃烧效应", 0x3EC},
			{"直升机下水", 0x3F0},
			{"滚动额外提升", 0x3F4},
		},		
		--boat
		{
    		{"前箱倍数", 0x338},
    		{"后箱倍数", 0x33C},
    		{"侧边箱倍数", 0x340},
    		{"顶部", 0x344},
    		{"底部", 0x348},
    		{"底部测试纠正", 0x34C},
    		{"水平力度", 0x350},
    		{"水下推动水倍数", 0x354},
    		{"水下推动水流速", 0x358},
    		{"水下推动水喷出", 0x35C},
    		{"舵力", 0x360},
    		{"舵偏潜", 0x364},
    		{"方向舵偏移力", 0x368},
    		{"方向舵偏移力 Z 倍数", 0x36C},
    		{"波音倍数", 0x370},
    		{"左右凸轮高度", 0x3A0},
    		{"阻力系数", 0x3A4},
    		{"龙骨尺寸", 0x3A8},
    		{"支撑半径", 0x3AC},
    		{"低位偏移", 0x3B0},
    		{"低位吃水补偿", 0x3B4},
    		{"叶轮偏移", 0x3B8},
    		{"叶轮力倍数", 0x3BC},
    		{"救生艇浮标结构", 0x3C0},
    		{"船头抬起倍数", 0x3C4},
    		{"深水浮力倍数", 0x3C8},
    		{"传输倍数", 0x3CC},
    		{"牵引力倍数", 0x3D0}
		}
	}
}


function handling:load()
	local file = wiriDir .."handling\\" .. self.vehicle_name .. ".json"
	
	if not PED.IS_PED_IN_ANY_VEHICLE(PLAYER.PLAYER_PED_ID(), false) then 
		return
	elseif not filesystem.exists(file) then 
		return notification.help("未找到文件", HudColour.red)
	end

	local parsed = parseJsonFile(file, false)

	if parsed then
		local function sethandling (offsets, s)
			for _, a in ipairs(offsets) do
				local addr = addressFromPointerChain(gWorldPtr, {0x08, 0xD30, 0x938, a[2]})
				if addr ~= NULL then
					memory.write_float(addr, parsed[s][a[1]])
				else 
					notification.help("在试图写入 " .. a[2] .. " 时得到一个空指针", HudColour.red) 
				end
			end
		end
		
		sethandling(self.offsets[1], "handling")		
		if parsed.flying ~= nil then 
			sethandling(self.offsets[2], "flying") 
		end
		if parsed.boat ~= nil then 
			sethandling(self.offsets[3], "boat") 
		end
		
		notification.normal(capitalize(self.vehicle_name) .. " 处理加载的数据")
	end
end


function handling:save()
	if not PED.IS_PED_IN_ANY_VEHICLE(PLAYER.PLAYER_PED_ID(), false) then 
		return
	end
	local table = {}
	local model = getUserVehicleModel(true)
	local file = wiriDir .."handling\\" .. self.vehicle_name .. ".json"
	local gethandling = function(offsets)
		local s = {}
		for _, a in ipairs(offsets) do
			local addr = addressFromPointerChain(gWorldPtr, {0x08, 0xD30, 0x938, a[2]})
			if addr ~= NULL then
				local value = memory.read_float(addr)
				s[ a[1] ] = round(value, 4)
			else
				notification.help("在试图写入 " .. a[2] .. " 时得到一个空指针", HudColour.red)
			end
		end
		return s
	end
	table.handling = gethandling(self.offsets[1])
	if isModelAnAircraft(model) then
		table.flying = gethandling(self.offsets[2])
	end
	if VEHICLE.IS_THIS_MODEL_A_BOAT(model) then
		table.boat = gethandling(self.offsets[3])
	end
	file = io.open(file, 'w')
	file:write(json.stringify(table, nil, 4))
	file:close()
	notification.normal(capitalize(self.vehicle_name) .. " 处理加载的数据")
end


function handling:create_actions(offsets, s)
	local t = {}
	table.insert(t, menu.divider(handling_editor, capitalize(s)))
	table.sort(offsets, function(a, b) return a[2] < b[2] end)
	
	for _, a in ipairs(offsets) do
		local action = menu.action(handling_editor, a[1], {}, "", function()
			local addr = addressFromPointerChain(gWorldPtr, {0x08, 0xD30, 0x938, a[2]})
			if addr == NULL then return end
			local value = round(memory.read_float(addr), 4)
			local nvalue = displayOnScreenKeyword("BS_WB_VAL", 7, value)
			if nvalue == "" then return end
			if tonumber(nvalue) == nil then
				return notification.help("无效输入", HudColour.red)
			elseif tonumber(nvalue) ~= value then
				memory.write_float(addr, tonumber(nvalue))
			end 
		end)
		
		menu.on_tick_in_viewport(action, function()
			self.inviewport[s] = self.inviewport[s] or {}
			if not includes(self.inviewport[s], a[1]) then
			   table.insert(self.inviewport[s], a)
			end
		end)
		  
		menu.on_focus(action, function()
			self.onfocus = a[1]
		end)		
		table.insert(t, action)
	end
	return t
end

handling:create_actions(handling.offsets[1], "处理")

-------------------------------------
-- VEHICLE DOORS
-------------------------------------

local doors = {
	"左前门",
	"右前门",
	"左后门",
	"右后门",
	"引擎盖",
	"后备箱"
}
local doors_list = menu.list(vehicleOptions, menuname("Vehicle", "车辆门"), {}, "")
menu.divider(doors_list, menuname("Vehicle", "车辆门"))

for i, door in ipairs(doors) do
	menu.toggle(doors_list, menuname("Vehicle - Vehicle Doors", door), {}, "", function(toggle)
		local vehicle = entities.get_user_vehicle_as_handle()
		if toggle then
			VEHICLE.SET_VEHICLE_DOOR_OPEN(vehicle, (i-1), false, false)
		else
			VEHICLE.SET_VEHICLE_DOOR_SHUT(vehicle, (i-1), false)
		end
	end)
end

menu.toggle(doors_list, menuname("Vehicle - Vehicle Doors", "全部"), {}, "", function(toggle)
	local vehicle = entities.get_user_vehicle_as_handle()
	for i, door in ipairs(doors) do
		if toggle then
			VEHICLE.SET_VEHICLE_DOOR_OPEN(vehicle, (i-1), false, false)
		else
			VEHICLE.SET_VEHICLE_DOOR_SHUT(vehicle, (i-1), false)
		end
	end
end)

-------------------------------------
-- UFO
-------------------------------------

menu.action(vehicleOptions, menuname("Vehicle", "UFO"), {"ufo"}, "驾驶UFO，并使用其飞碟光束和大炮", function(toggle)
	if not guidedMissile.exists() then
		ufo.create()
	end
end)

-------------------------------------
-- VEHICLE INSTANT LOCK ON
-------------------------------------

menu.toggle(vehicleOptions, menuname("Vehicle", "载具即时锁定"), {}, "", function(toggle)
	gUsingVehInstLockon = toggle
	local default = {}
	local offsets = {0x08, 0x10D8, 0x70, 0x60, 0x178}

	while gUsingVehInstLockon do
		wait()
		local ptr = memory.alloc()
		local addr = addressFromPointerChain(gWorldPtr, offsets)
		if addr ~= NULL then
			local value = memory.read_float(addr)
			if value ~= 0.0 then
				table.insert(default, {addr, value})
				memory.write_float(addr, 0.0)
			end
		end
	end

	if #default > 0 then
		for _, data in ipairs(default) do
			memory.write_float(table.unpack(data))
		end
	end
end)

-------------------------------------
-- VEHICLE EFFECTS
-------------------------------------

local VehicleEffect = {scale = 0.0, loopSpeed = 0.0}
VehicleEffect.__index = VehicleEffect
setmetatable(VehicleEffect, Effect)

function VehicleEffect.new(asset, name, scale, loopSpeed)
	local inst = setmetatable({}, VehicleEffect)
	inst.asset = asset
	inst.name = name
	inst.scale = scale
	inst.loopSpeed = loopSpeed
	return inst
end

local effects = 
{	
	VehicleEffect.new("scr_rcbarry2", "scr_clown_appears", 0.3, 500.0), 	-- clown appears
	VehicleEffect.new("scr_rcbarry1", "scr_alien_impact_bul", 1.0, 50.0), 	-- alien impact
	VehicleEffect.new("core", "ent_dst_elec_fire_sp", 0.8, 25.0) 			-- electic fire
}
local vehicleEffectOpt = {"停用", "小丑出现", "外星人冲击", "电光火石"}
local wheelBones = {"wheel_lf", "wheel_lr", "wheel_rf", "wheel_rr"}
local currentEffect = 1
local vehicleEffectRoot = menu.list(vehicleOptions, menuname("Vehicle Effects", "载具效果") .. ": " .. menuname("Vehicle Effects", vehicleEffectOpt[1]) )

for i, option in ipairs(vehicleEffectOpt) do
	menu.action(vehicleEffectRoot, menuname("Vehicle Effects", option), {}, "", function()
		currentEffect = i
		menu.set_menu_name(vehicleEffectRoot, menuname("Vehicle Effects", "载具效果") .. ": " .. menuname("Vehicle Effects", option) )
		menu.focus(vehicleEffectRoot)
	end)
end

util.create_tick_handler(function()
	if currentEffect == 1 then
		return true
	elseif currentEffect ~= nil then
		local effect = effects[ currentEffect - 1 ]
		local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
		if vehicle == NULL then return true end
		requestPtfxAsset(effect.asset)
		for k, bone in pairs(wheelBones) do
			GRAPHICS.USE_PARTICLE_FX_ASSET(effect.asset)
			GRAPHICS._START_NETWORKED_PARTICLE_FX_NON_LOOPED_ON_ENTITY_BONE(
				effect.name,
				vehicle,
				0.0,	-- offsetX
				0.0,	-- offsetY
				0.0,	-- offsetZ
				0.0,	-- rotX
				0.0,	-- rotY
				0.0,	-- rotZ
				ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(vehicle, bone),
				effect.scale, 	-- scale
				false, false, false
			)
		end
		wait(effect.speed)
	end
	return true
end)

-------------------------------------
-- AUTOPILOT
-------------------------------------

local autopilotRoot = menu.list(vehicleOptions, menuname("Vehicle - Autopilot", "自动驾驶") )
menu.divider(autopilotRoot, menuname("Vehicle - Autopilot", "自动驾驶") )

local drivingStyle = 786988
menu.toggle(autopilotRoot, menuname("Vehicle - Autopilot", "自动驾驶"), {"autopilot"}, "", function(toggle)
	gUsingAutopilot = toggle
	
	if gUsingAutopilot then
		local lastblip
		local lastdrivstyle
		local lastspeed
		local drive_to_waypoint =  function()
			local vehicle = entities.get_user_vehicle_as_handle()
			
			if vehicle == NULL then
				return 
			end

			local ptr = memory.alloc()
			local coord = getWaypointCoords()
			if not coord then
				notification.normal("Set a waypoint to start driving")
			else
				PED.SET_DRIVER_ABILITY(PLAYER.PLAYER_PED_ID(), 0.5);
				TASK.OPEN_SEQUENCE_TASK(ptr)
				TASK.TASK_VEHICLE_DRIVE_TO_COORD_LONGRANGE(0, vehicle, coord.x, coord.y, coord.z, autopilotSpeed or 25.0, drivingStyle, 45.0);
				TASK.TASK_VEHICLE_PARK(0, vehicle, coord.x, coord.y, coord.z, ENTITY.GET_ENTITY_HEADING(vehicle), 7, 60.0, true);
				TASK.CLOSE_SEQUENCE_TASK(memory.read_int(ptr));
				TASK.TASK_PERFORM_SEQUENCE(PLAYER.PLAYER_PED_ID(), memory.read_int(ptr))
				TASK.CLEAR_SEQUENCE_TASK(ptr)

				lastspeed = autopilotSpeed or 25.0
				lastblip = HUD.GET_FIRST_BLIP_INFO_ID(8)
				lastdrivstyle = drivingStyle
				return coord
			end
		end
		local lastcoord = drive_to_waypoint()
		while gUsingAutopilot do
			wait()
			local blip = HUD.GET_FIRST_BLIP_INFO_ID(8)
			if drivingStyle ~= lastdrivstyle  then
				lastcoord = drive_to_waypoint()
				lastdrivstyle = drivingStyle
			end
			if blip ~= lastblip then
				lastcoord = drive_to_waypoint()
				lastblip = blip
			end
			if lastspeed ~= autopilotSpeed then
				lastcoord = drive_to_waypoint()
				lastspeed = autopilotSpeed
			end
		end
	else
		TASK.CLEAR_PED_TASKS(PLAYER.PLAYER_PED_ID())
	end
end)

local drivingStyleList = menu.list(autopilotRoot, menuname("Vehicle - Autopilot", "驾驶风格"), {}, "")
menu.divider(drivingStyleList, menuname("Vehicle - Autopilot", "驾驶风格"))
menu.divider(drivingStyleList, menuname("Autopilot - Driving Style", "预设"))

local drivingStylePresets = {
	{
		"正常", 
		"在车辆和行人面前停车，避开空车和物体，在交通灯前停车",
		786603
	},
	{
	  	"忽略灯光",
	  	"在车辆前停车，避开车辆和物体", 
	  	2883621
	},
	{
	  	"避开交通",
	  	"避开车辆和物体", 
	  	786468
	},
	{
	  	"匆促",
	  	"在车辆前停车，避开车辆，避开物体", 
	  	1074528293
	},
	{
	  	"默认",
	  	"避开车辆、空车和物体，允许走错路，走最短的路径", 
	  	786988
	}
}

for _, style in ipairs(drivingStylePresets) do
	menu.action(drivingStyleList, menuname("Autopilot - Driving Style", style[ 1 ]), {}, style[ 2 ], function()
		drivingStyle = style[ 3 ]
	end)
end

menu.divider(drivingStyleList, menuname("Autopilot - Driving Style", "自定义"))

local drivingStyleFlag = {
	["在车辆前停车"] 	= 1,
	["停在行人面前"] 		= 2,
	["避开车辆"] 			= 4,
	["避开空的载具"] 	= 8,
	["避开行人"] 				= 16,
	["避开物体"]			= 32,
	["在交通灯下停车"] 	= 128,
	["逆向行驶"] 			= 1024,
	["走最短路径"] 		= 262144,
	["忽略道路"] 			= 4194304,
	["忽略所有路径"] 		= 16777216
}
local selectedFlags = {}

for name, flag in pairs(drivingStyleFlag) do
	menu.toggle(drivingStyleList, menuname("Autopilot - Driving Style", name), {}, "", function(toggle)
		if toggle then
			table.insert(selectedFlags, flag)
		else 
			selectedFlags[ name ] = nil
		end
	end)
end

menu.action(drivingStyleList, menuname("Autopilot - Driving Style", "设置自定义驾驶风格"), {}, "", function()
	local style = 0
	for k, v in pairs(selectedFlags) do
		style = style + v
	end
	drivingStyle = style
end)

menu.slider(autopilotRoot, menuname("Vehicle - Autopilot", "速度"), {"autopilotspeed"}, "", 5, 200, 20, 1, function(speed)
	autopilotSpeed = speed
end)

-------------------------------------
-- ENGINE ALWAYS ON
-------------------------------------

menu.toggle_loop(vehicleOptions, menuname("Vehicle", "发动机常开"), {"alwayson"}, "", function()
	local vehicle = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), false)
	if ENTITY.DOES_ENTITY_EXIST(vehicle) then
		VEHICLE.SET_VEHICLE_ENGINE_ON(vehicle, true, true, true)
		VEHICLE.SET_VEHICLE_LIGHTS(vehicle, 0)
		VEHICLE._SET_VEHICLE_LIGHTS_MODE(vehicle, 2)
	end
end)

-------------------------------------
-- TARGET PASSANGERS
-------------------------------------

menu.toggle_loop(vehicleOptions, menuname("Vehicle", "目标乘客"), {}, "", function()
	local localPed = PLAYER.PLAYER_PED_ID()
	local vehicle = PED.GET_VEHICLE_PED_IS_IN(localPed, false)
	if not ENTITY.DOES_ENTITY_EXIST(vehicle) then
		return
	end
	local numberOfSeats = VEHICLE.GET_VEHICLE_MODEL_NUMBER_OF_SEATS(ENTITY.GET_ENTITY_MODEL(vehicle))
	for seat = -1, (numberOfSeats - 2), 1 do
		local ped = VEHICLE.GET_PED_IN_VEHICLE_SEAT(vehicle, seat, 0)
		if ENTITY.DOES_ENTITY_EXIST(ped) and ped ~= localPed and PED.IS_PED_A_PLAYER(ped) then
			local playerGroupHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(ped)
			local myGroupHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(localPed)
			PED.SET_RELATIONSHIP_BETWEEN_GROUPS(4, playerGroupHash, myGroupHash)
		end
	end
end)

---------------------
---------------------
-- BODYGUARD
---------------------
---------------------

local bodyguardRoot = menu.list(menu.my_root(), menuname("Bodyguard Menu", "保镖菜单"), {"bodyguardmenu"}, "")
menu.divider(bodyguardRoot, menuname("Bodyguard Menu", "保镖菜单"))

local Formation = 
{
	freedomToMove = 0,
	circleAroundLeader = 1,
	line = 3,
	arrow = 4,
}

local bodyguard = {
	godmode 		= false,
	ignoreplayers 	= false,
	spawned 		= {},
	backup_godmode 	= false,
	formation 		= Formation.freedomToMove
}

-- returns the local ped group or -1
local function getGroupSize()
	local size
	local unkPtr, sizePtr = memory.alloc(8), memory.alloc(8)
	if PED.IS_PED_IN_GROUP(PLAYER.PLAYER_PED_ID()) then		
		local group = PED.GET_PED_GROUP_INDEX(PLAYER.PLAYER_PED_ID())
		PED.GET_GROUP_SIZE(group, unkPtr, sizePtr)
		size = memory.read_int(sizePtr); memory.free(unkPtr); memory.free(sizePtr)
		return size
	end
	return -1 -- if the local ped is not in any group
end


local function makeBodyguard(ped, weaponHash)
	PED.SET_PED_HIGHLY_PERCEPTIVE(ped, true)
	PED.SET_PED_SEEING_RANGE(ped, 100.0)
	PED.SET_PED_CONFIG_FLAG(ped, 208, true)
	WEAPON.GIVE_WEAPON_TO_PED(ped, weaponHash, -1, false, true)
	WEAPON.SET_CURRENT_PED_WEAPON(ped, weaponHash, false)
	PED.SET_PED_FIRING_PATTERN(ped, 0xC6EE6B4C)
	PED.SET_PED_SHOOT_RATE(ped, 100.0)
	ENTITY.SET_ENTITY_INVINCIBLE(ped, bodyguard.godmode)
	ENTITY.SET_ENTITY_PROOFS(
		ped, bodyguard.godmode --[[bullet]], bodyguard.godmode --[[fire]], bodyguard.godmode --[[explosion]], bodyguard.godmode, --[[collision]] 
		bodyguard.godmode --[[melee]], bodyguard.godmode --[[steam]], 1 --[[unk]], bodyguard.godmode --[[drown]]
	)

	local group
	if PED.IS_PED_IN_GROUP(PLAYER.PLAYER_PED_ID()) then
		group = PED.GET_PED_GROUP_INDEX(PLAYER.PLAYER_PED_ID())
	else
		group = PED.CREATE_GROUP(0)
		PED.SET_PED_AS_GROUP_LEADER(PLAYER.PLAYER_PED_ID(), group)
	end
	PED.SET_PED_AS_GROUP_MEMBER(ped, group)
	PED.SET_GROUP_FORMATION_SPACING(group, 1.0, 0.9, 3.0)
	PED.SET_GROUP_SEPARATION_RANGE(group, 200.0)
	PED.SET_GROUP_FORMATION(group, bodyguard.formation)
	-- makes the bodyguards ignore players
	if bodyguard.ignoreplayers then
		PED.SET_PED_RELATIONSHIP_GROUP_HASH(ped, PED.GET_PED_RELATIONSHIP_GROUP_HASH(PLAYER.PLAYER_PED_ID()))
	end
end

-- clone player as bodyguard
menu.action(bodyguardRoot, menuname("Bodyguard Menu", "生成保镖(最多7人)"), {"spawnbodyguard"}, "", function()
	if getGroupSize() >= 7 then
		notification.help("保镖已达最大数量", NOT_COLOR_RED);
		return
	end
	local pedModel = bodyguard.model or getRandomValue(gPedModels)
	local pedHash = util.joaat(pedModel)
	local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(
		PLAYER.PLAYER_PED_ID(), math.random(-3.0, 3.0), math.random(-3.0, 3.0), -1.0
	)	
	requestModels(pedHash)
	local ped = entities.create_ped(29, pedHash, pos, 0.0)
	insertOnce(bodyguard.spawned, pedHash)
	NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NETWORK.PED_TO_NET(ped), true)
	setEntityFaceEntity(ped, PLAYER.PLAYER_PED_ID())
	
	local weaponModel= bodyguard.weapon or getRandomValue(gWeapons)
	makeBodyguard(ped, util.joaat(weaponModel))
end)

-- bodyguard models
local bodyguardModelList = menu.list(bodyguardRoot, menuname("Bodyguard Menu", "设置模型") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "")
menu.divider(bodyguardModelList, "保镖模型列表")

menu.action(bodyguardModelList, HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "", function()
	bodyguard.model = nil
	menu.set_menu_name(bodyguardModelList, menuname("Bodyguard Menu", "设置模型") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"))
	menu.focus(bodyguardModelList)
end)

for name, model in pairsByKeys(gPedModels) do
	menu.action(bodyguardModelList, menuname("Ped Models", name), {}, "", function()
		bodyguard.model = model
		menu.set_menu_name(bodyguardModelList, menuname("Bodyguard Menu", "设置模型") .. ": " .. name)
		menu.focus(bodyguardModelList)
	end)
end

-- clone player as bodyguard
menu.action(bodyguardRoot, menuname("Bodyguard Menu", "克隆玩家"), {"clonebodyguard"}, "", function()
	if getGroupSize() >= 7 then
		notification.help("保镖已达最大数量", HudColour.red)
		return
	end
	local pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(
		PLAYER.PLAYER_PED_ID(), math.random(-3.0, 3.0), math.random(-3.0, 3.0), -1.0
	)	
	local clone = PED.CLONE_PED(PLAYER.PLAYER_PED_ID(), 1, 1, 1)
	insertOnce(bodyguard.spawned, ENTITY.GET_ENTITY_MODEL(clone))
	NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(NETWORK.PED_TO_NET(clone), true)
	ENTITY.SET_ENTITY_COORDS(clone, pos.x, pos.y, pos.z)
	setEntityFaceEntity(clone, PLAYER.PLAYER_PED_ID())
	
	local weaponModel = bodyguard.weapon or getRandomValue(gWeapons)
	makeBodyguard(clone, util.joaat(weaponModel))
end)

-- bodyguards weapons
local weaponsList = menu.list(bodyguardRoot, menuname("Bodyguard Menu", "设置武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"))
menu.divider(weaponsList, HUD._GET_LABEL_TEXT("PM_WEAPONS"))

local meleeList = menu.list(weaponsList, HUD._GET_LABEL_TEXT("VAULT_WMENUI_8"))
menu.divider(meleeList, HUD._GET_LABEL_TEXT("VAULT_WMENUI_8"))

for label, weapon in pairsByKeys(gMeleeWeapons) do
	local strg = HUD._GET_LABEL_TEXT(label)
	menu.action(meleeList, strg, {}, "", function()
		bodyguard.weapon = weapon
		menu.set_menu_name(weaponsList, menuname("Bodyguard Menu", "设置武器") .. ": " .. strg)
		menu.focus(weaponsList)
	end)
end

menu.action(weaponsList, HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"), {}, "", function()
	bodyguard.weapon = nil
	menu.set_menu_name(weaponsList, menuname("Bodyguard Menu", "设置武器") .. ": " .. HUD._GET_LABEL_TEXT("SR_GUN_RANDOM"))
	menu.focus(weaponsList)
end)

for label, weapon in pairsByKeys(gWeapons) do
	local strg = HUD._GET_LABEL_TEXT(label)
	menu.action(weaponsList, strg, {}, "", function()
		bodyguard.weapon = weapon
		menu.set_menu_name(weaponsList, menuname("Bodyguard Menu", "设置武器") .. ": " .. strg)
		menu.focus(weaponsList)
	end)
end

menu.toggle(bodyguardRoot, menuname("Bodyguard Menu", "保镖无敌"), {"bodyguardsgodmode"}, "", function(toggle)
	bodyguard.godmode = toggle
end)

menu.toggle(bodyguardRoot, menuname("Bodyguard Menu", "无视玩家"), {}, "", function(toggle)
	bodyguard.ignoreplayers = toggle
end)

-- group formation
local formations = {
	{"自由移动", Formation.freedomToMove},
	{"圆行", Formation.circleAroundLeader},
	{"线形", Formation.line},
	{"箭头形", Formation.arrow},
}

local formation = menu.list(bodyguardRoot, menuname("Bodyguard Menu", "队形") .. ": " .. menuname("Bodyguard Menu - Group Formation", formations[1][1] ), {}, "")
for _, value in ipairs(formations) do
	menu.action(formation, menuname("Bodyguard Menu - Group Formation", value[1]) , {}, "", function()
		bodyguard.formation = value[2]
		local group = PED.GET_PED_GROUP_INDEX(PLAYER.PLAYER_PED_ID())
		PED.SET_GROUP_FORMATION(group, bodyguard.formation)
		menu.set_menu_name(formation, menuname("Bodyguard Menu", "队形") .. ": " .. menuname("Bodyguard Menu - Group Formation", value[1]) )
		menu.focus(formation)
	end)
end

menu.action(bodyguardRoot, menuname("Bodyguard Menu", "删除保镖"), {}, "", function()
	for _, modelHash in ipairs(bodyguard.spawned) do
		deletePedsWithModelHash(modelHash)
	end
	bodyguard.spawned = {}
end)

-------------------------------------
-- BACKUP HELICOPTER
-------------------------------------

local backupHeliOptions = menu.list(bodyguardRoot,  menuname("Bodyguard Menu", "保镖直升机"))
menu.divider(backupHeliOptions, menuname("Bodyguard Menu", "保镖直升机"))


menu.action(backupHeliOptions, menuname("Bodyguard Menu - Backup Helicopter", "生成保镖直升机"), {"backupheli"}, "", function()
	local heliHash = util.joaat("buzzard2")
	local pedHash = util.joaat("s_m_y_blackops_01")
	local localPed = PLAYER.PLAYER_PED_ID()
	local pos = ENTITY.GET_ENTITY_COORDS(localPed)
	pos.x = pos.x + math.random(-20, 20)
	pos.y = pos.y + math.random(-20, 20)
	pos.z = pos.z + 30
	
	requestModels(pedHash, heliHash)
	relationship:friendly(localPed)
	local heli = entities.create_vehicle(heliHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
	
	if not ENTITY.DOES_ENTITY_EXIST(heli) then 
		notification.help("Failed to create vehicle. Please try again", HudColour.red)
		return
	else
		local heliNetId = NETWORK.VEH_TO_NET(heli)
		if NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(NETWORK.NET_TO_PED(heliNetId)) then
			NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(heliNetId, true)
		end
		NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(heliNetId, players.user(), true)
		ENTITY.SET_ENTITY_INVINCIBLE(heli, godmode)
		VEHICLE.SET_VEHICLE_ENGINE_ON(heli, true, true, true)
		VEHICLE.SET_HELI_BLADES_FULL_SPEED(heli)
		VEHICLE.SET_VEHICLE_SEARCHLIGHT(heli, true, true)
		ENTITY.SET_ENTITY_INVINCIBLE(heli, bodyguard.backup_godmode)
		addBlipForEntity(heli, 422, 26)
	end

	local pilot = entities.create_ped(29, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
	PED.SET_PED_INTO_VEHICLE(pilot, heli, -1)
	PED.SET_PED_MAX_HEALTH(pilot, 500)
	ENTITY.SET_ENTITY_HEALTH(pilot, 500)
	ENTITY.SET_ENTITY_INVINCIBLE(pilot, bodyguard.backup_godmode)
	PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(pilot, true)
	TASK.TASK_HELI_MISSION(pilot, heli, 0, localPed, 0.0, 0.0, 0.0, 23, 40.0, 40.0, -1.0, 0, 10, -1.0, 0)
	PED.SET_PED_KEEP_TASK(pilot, true)
	
	for seat = 1, 2 do
		local ped = entities.create_ped(29, pedHash, pos, CAM.GET_GAMEPLAY_CAM_ROT(0).z)
		local pedNetId = NETWORK.PED_TO_NET(ped)
		
		if NETWORK.NETWORK_GET_ENTITY_IS_NETWORKED(ped) then
			NETWORK.SET_NETWORK_ID_EXISTS_ON_ALL_MACHINES(pedNetId, true)
		end
		
		NETWORK.SET_NETWORK_ID_ALWAYS_EXISTS_FOR_PLAYER(pedNetId, players.user(), true)
		PED.SET_PED_INTO_VEHICLE(ped, heli, seat)
		WEAPON.GIVE_WEAPON_TO_PED(ped, util.joaat("weapon_mg"), -1, false, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(ped, 5, true)
		PED.SET_PED_COMBAT_ATTRIBUTES(ped, 3, false)
		PED.SET_PED_COMBAT_MOVEMENT(ped, 2)
		PED.SET_PED_COMBAT_ABILITY(ped, 2)
		PED.SET_PED_COMBAT_RANGE(ped, 2)
		PED.SET_PED_SEEING_RANGE(ped, 100.0)
		PED.SET_PED_TARGET_LOSS_RESPONSE(ped, 1)
		PED.SET_PED_HIGHLY_PERCEPTIVE(ped, true)
		PED.SET_PED_VISUAL_FIELD_PERIPHERAL_RANGE(ped, 400.0)
		PED.SET_COMBAT_FLOAT(ped, 10, 400.0)
		PED.SET_PED_MAX_HEALTH(ped, 500)
		ENTITY.SET_ENTITY_HEALTH(ped, 500)
		ENTITY.SET_ENTITY_INVINCIBLE(ped, bodyguard.backup_godmode)
		
		if bodyguard.ignoreplayers then
			local relHash = PED.GET_PED_RELATIONSHIP_GROUP_HASH(PLAYER.PLAYER_PED_ID())
			PED.SET_PED_RELATIONSHIP_GROUP_HASH(ped, relHash)
		else
			relationship:friendly(ped)
		end
	end
	
	STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(heliHash)
	STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(pedHash)
end)

menu.toggle(backupHeliOptions, menuname("Bodyguard Menu - Backup Helicopter", "无敌的保镖"), {"backupgodmode"}, "", function(toggle)
	bodyguard.backup_godmode = toggle
end)

---------------------
---------------------
-- WORLD
---------------------
---------------------

local worldOptions = menu.list(menu.my_root(), menuname("World", "世界"), {}, "")
menu.divider(worldOptions, menuname("World", "世界"))

-------------------------------------
-- JUMPING CARS
-------------------------------------

menu.toggle_loop(worldOptions, menuname("World", "跳跳车"), {}, "", function(toggle)
	local entities = getNearbyVehicles(PLAYER.PLAYER_ID(), 150)
	for _, vehicle in ipairs(entities) do
		requestControl(vehicle)
		ENTITY.APPLY_FORCE_TO_ENTITY(vehicle, 1, 0, 0, 6.5, 0, 0, 0, 0, false, false, true)
	end
	wait(1500)
end)

-------------------------------------
-- KILL ENEMIES
-------------------------------------

menu.action(worldOptions, menuname("World", "击杀敌人"), {"killenemies"}, "", function()
	local peds = getNearbyPeds(PLAYER.PLAYER_ID(), 500)
	for _, ped in ipairs(peds) do
		local rel = PED.GET_RELATIONSHIP_BETWEEN_PEDS(PLAYER.PLAYER_PED_ID(), ped)
		if not ENTITY.IS_ENTITY_DEAD(ped) and ( (rel == 4 or rel == 5) or PED.IS_PED_IN_COMBAT(ped, PLAYER.PLAYER_PED_ID()) ) then
			local pos = ENTITY.GET_ENTITY_COORDS(ped)
			FIRE.ADD_OWNED_EXPLOSION(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z, 1, 1.0, true, false, 0.0)
		end
	end
end)

menu.toggle_loop(worldOptions, menuname("World", "自动击杀敌人"), {"autokillenemies"}, "", function()
	local peds = getNearbyPeds(players.user(), 500)
	for _, ped in ipairs(peds) do
		local rel = PED.GET_RELATIONSHIP_BETWEEN_PEDS(PLAYER.PLAYER_PED_ID(), ped)
		if not ENTITY.IS_ENTITY_DEAD(ped) and ( (rel == 4 or rel == 5) or PED.IS_PED_IN_COMBAT(ped, PLAYER.PLAYER_PED_ID()) ) then
			local pos = ENTITY.GET_ENTITY_COORDS(ped)
			FIRE.ADD_OWNED_EXPLOSION(PLAYER.PLAYER_PED_ID(), pos.x, pos.y, pos.z, 1, 1.0, true, false, 0.0)
		end
	end
end)


-------------------------------------
--ANGRY PLANES
-------------------------------------

-- some big planes are not included
local planes = {
	"besra",
	"dodo",
	"avenger",
	"microlight",
	"molotok",
	"bombushka",
	"howard",
	"duster",
	"luxor2",
	"lazer",
	"nimbus",
	"shamal",
	"stunt",
	"titan",
	"velum2",
	"miljet",
	"mammatus",
	"besra",
	"cuban800",
	"seabreeze",
	"alphaz1",
	"mogul",
	"nokota",
	"strikeforce",
	"vestra",
	"tula",
	"rogue"
}
local spawned = {}

menu.toggle(worldOptions, menuname("World", "生气的飞机"), {}, "", function(toggle)
	gUsingAngryPlanes = toggle
	
	if not gUsingAngryPlanes then
		for index, value in ipairs(spawned) do
			entities.delete_by_handle(value [1])
			entities.delete_by_handle(value [2])
			spawned [index] = nil
		end
		return 
	end

	local pedHash = util.joaat("s_m_y_blackops_01")
	requestModels(pedHash)

	while gUsingAngryPlanes do
		if #spawned < 50 then
			local planeHash = util.joaat(getRandomValue(planes))
			requestModels(planeHash)
			local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
			local plane = VEHICLE.CREATE_VEHICLE(planeHash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, false)
			
			if ENTITY.DOES_ENTITY_EXIST(plane) then
				NETWORK.SET_NETWORK_ID_CAN_MIGRATE(NETWORK.VEH_TO_NET(plane), false)
				ENTITY._SET_ENTITY_CLEANUP_BY_ENGINE(plane, true)
				local pilot = PED.CREATE_PED(26, pedHash, pos.x, pos.y, pos.z, CAM.GET_GAMEPLAY_CAM_ROT(0).z, true, true)
				spawned [1 + #spawned] = {plane, pilot}
				PED.SET_PED_INTO_VEHICLE(pilot, plane, -1)
				local radius = math.random(50, 150)
				pos = getOffsetFromEntityGivenDistance(PLAYER.PLAYER_PED_ID(), radius)
				pos.z = pos.z + 75.0
				VEHICLE._SET_VEHICLE_JET_ENGINE_ON(plane, true)
				ENTITY.SET_ENTITY_COORDS(plane, pos.x, pos.y, pos.z)
				local theta = (math.random() + math.random(0, 1)) * math.pi
				ENTITY.SET_ENTITY_HEADING(plane, math.deg(theta))
				VEHICLE.SET_VEHICLE_FORWARD_SPEED(plane, 60)
				VEHICLE.SET_HELI_BLADES_FULL_SPEED(plane)
				VEHICLE.CONTROL_LANDING_GEAR(plane, 3)
				VEHICLE.SET_VEHICLE_FORCE_AFTERBURNER(plane, true)
				TASK.TASK_PLANE_MISSION(pilot, plane, 0, PLAYER.PLAYER_PED_ID(), 0, 0, 0, 6, 100, 0, 0, 80, 50)
			end
		end
		wait(500)
	end
end)

-------------------------------------
-- HEALTH BAR
-------------------------------------

local function draw_health_on_ped(ped, maxDistance)
	if ENTITY.DOES_ENTITY_EXIST(ped) and ENTITY.IS_ENTITY_ON_SCREEN(ped) then
		if ped == NULL then
			return
		end
		-- by default a ped dies when it's healh is below the injured level (commonly 100)
		-- so here we subtract 100 so health is 0 when the ped dies
		local health = ENTITY.GET_ENTITY_HEALTH(ped)
		health = health > 0 and (health - 100) or 0
		
		local maxHealth = PED.GET_PED_MAX_HEALTH(ped)
		maxHealth = maxHealth > 0 and (maxHealth - 100) or 0

		local armour = PED.GET_PED_ARMOUR(ped)
		local myCoords = ENTITY.GET_ENTITY_COORDS(ped)
		local targetCoords = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		local distance = vect.dist(targetCoords, myCoords)
		local distPerc = 1 - (distance / maxDistance)
		local armorPerc = armour / 100.
		

		local healthPerc = 0
		if maxHealth > 0 then
			local perc = health/maxHealth
			if perc > 1.0 then
				perc = 1.0
			end
			healthPerc = perc
		end

		if distance > maxDistance then
			distPerc = 0
		elseif distPerc > 1.0 then
			distPerc = 1.0
		end

		-- the max armour a player can have in gta online is 50 but it's 100 in single player
		-- so a 50% of the armour bar in gta online means it's full, more than that triggers a moder detection
		if armorPerc > 1.0 then
			armorPerc = 1.0 
		end
		
		local totalBarLength = 0.05 * distPerc ^ 3
		local width = 0.008 * distPerc ^ 1.5
		local pos = PED.GET_PED_BONE_COORDS(ped, 0x322C --[[head]], 0.35, 0., 0.)
		GRAPHICS.SET_DRAW_ORIGIN(pos.x, pos.y, pos.z, 0)
		-- health bar
		local healthBarLength = interpolate(0, totalBarLength, healthPerc)
		local healthBarColour = getBlendedColour(healthPerc) -- colour of the health bar (goes from green to red) and depends on the ped's health
		GRAPHICS.DRAW_RECT(0, 0, totalBarLength, width, healthBarColour.r, healthBarColour.g, healthBarColour.b, 120)
		GRAPHICS.DRAW_RECT(0, 0, totalBarLength + 0.002, width + 0.002, 0, 0, 0, 120)
		GRAPHICS.DRAW_RECT(-totalBarLength/2 + healthBarLength/2, 0, healthBarLength, width, healthBarColour.r, healthBarColour.g, healthBarColour.b, 255)
		
		-- armour bar
		local armourBarLength = interpolate(0, totalBarLength, armorPerc)
		local armourBarColour = getHudColour(HudColour.radarArmour)
		GRAPHICS.DRAW_RECT(0, 1.5 * width, totalBarLength, width, armourBarColour.r, armourBarColour.g, armourBarColour.b, 120)
		GRAPHICS.DRAW_RECT(0, 1.5 * width, totalBarLength + 0.002, width + 0.002, 0, 0, 0, 120)
		GRAPHICS.DRAW_RECT(-totalBarLength/2 + armourBarLength/2, 1.5 * width, armourBarLength, width, armourBarColour.r, armourBarColour.g, armourBarColour.b, 255)
		GRAPHICS.CLEAR_DRAW_ORIGIN()
	end
end

local healthBarOpt = {"停用", "玩家", "行人", "玩家与行人", "瞄准的NPC"}
local currentHealthBar = 1
local healthBarList = menu.list(worldOptions, menuname("World", "绘制生命值") .. ": " .. menuname("World - Draw Health Bar", healthBarOpt[1]))

for i, option in ipairs(healthBarOpt) do
	menu.action(healthBarList, menuname("World - Draw Health Bar", option), {}, "", function()
		currentHealthBar = i
		menu.set_menu_name(healthBarList, menuname("World", "绘制生命值") .. ": " .. menuname("World - Draw Health Bar", option))
		menu.focus(healthBarList)
	end)
end

local aimedPed = NULL

util.create_tick_handler(function()
	if currentHealthBar == 1 then
		return true
	end
	-- players
	if	currentHealthBar == 2 or currentHealthBar == 4 then
		for _, pId in ipairs(players.list(false)) do
			local ped = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(pId)
			draw_health_on_ped(ped, 250)
		end
	end	
	-- peds
	if currentHealthBar == 3 or currentHealthBar == 4 then
		local peds = getNearbyPeds(PLAYER.PLAYER_ID(), 300)
		for _, ped in ipairs(peds) do
			if not PED.IS_PED_A_PLAYER(ped) and ENTITY.HAS_ENTITY_CLEAR_LOS_TO_ENTITY(PLAYER.PLAYER_PED_ID(), ped, 1) then
				draw_health_on_ped(ped, 250)
			end
		end
	end	
	-- aimed ped
	if currentHealthBar == 5 then
		if PLAYER.IS_PLAYER_FREE_AIMING(PLAYER.PLAYER_ID()) then
			local ptr = memory.alloc_int()
			if PLAYER.GET_ENTITY_PLAYER_IS_FREE_AIMING_AT(PLAYER.PLAYER_ID(), ptr) then
				local entity = memory.read_int(ptr)
				if ENTITY.IS_ENTITY_A_PED(entity) then
					aimedPed = entity
				end
			end
			memory.free(ptr)
			draw_health_on_ped(aimedPed, 500.0)
		else
			aimedPed = 0
		end
	end
	return true
end)

---------------------
---------------------
-- WIRISCRIPT
---------------------
---------------------

local script = menu.list(menu.my_root(), "WiriScript", {}, "")
menu.divider(script, "汉化: VnBurner")

menu.action(script, menuname("WiriScript", "显示制作人员"), {}, "", function()
	if gShowingIntro then 
		return 
	end	
	local state = 0
	local sTime = cTime()
	local i = 1
	local delay = 0
	local ty = {
		{"Chinese: VnBurner", "HUD_COLOUR_ORANGE"},
		"DeF3c",
		"Hollywood Collins",
		"Murten",
		"QuickNET",
		"komt",
		"vsus/Ren",
		"ICYPhoenix",
		"Koda",
		"jayphen",
		"Fwishky",
		"Polygon",
		"Sainan",
		"NONECKED",
		{"wiriscript", "HUD_COLOUR_BLUE"}
	}

	AUDIO.SET_MOBILE_RADIO_ENABLED_DURING_GAMEPLAY(true)
	AUDIO.SET_MOBILE_PHONE_RADIO_STATE(true)
	AUDIO.SET_RADIO_TO_STATION_NAME("RADIO_01_CLASS_ROCK")
	AUDIO.SET_CUSTOM_RADIO_TRACK_LIST("RADIO_01_CLASS_ROCK", "END_CREDITS_SAVE_MICHAEL_TREVOR", true)

	util.create_tick_handler(function()
		local scaleform = GRAPHICS.REQUEST_SCALEFORM_MOVIE("OPENING_CREDITS")
		
		while not GRAPHICS.HAS_SCALEFORM_MOVIE_LOADED(scaleform) do
			wait()
		end
	
		if cTime() - sTime >= delay and state == 0 then
			SETUP_SINGLE_LINE(scaleform)
			ADD_TEXT_TO_SINGLE_LINE(scaleform, ty[i][1] or ty[i], "$font2", ty[i][2] or "HUD_COLOUR_WHITE")
			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_SINGLE_LINE")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
		
			GRAPHICS.BEGIN_SCALEFORM_MOVIE_METHOD(scaleform, "SHOW_CREDIT_BLOCK")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_TEXTURE_NAME_STRING("presents")
			GRAPHICS.SCALEFORM_MOVIE_METHOD_ADD_PARAM_FLOAT(0.5)
			GRAPHICS.END_SCALEFORM_MOVIE_METHOD()
		
			state = 1
			i = i + 1
			delay = 4000
			sTime = cTime()
		end
	
		if cTime() - sTime >= 4000 and state == 1 then
			HIDE(scaleform)
			state = 0
			sTime = cTime()
		end
	
		if state == 1 and i == #ty + 1 then
			state = 2
			sTime = cTime()
		end

		if cTime() - sTime >= 3000 and state == 2 then
			AUDIO.START_AUDIO_SCENE("CAR_MOD_RADIO_MUTE_SCENE")
			wait(5000)
			AUDIO.SET_MOBILE_RADIO_ENABLED_DURING_GAMEPLAY(false)
			AUDIO.SET_MOBILE_PHONE_RADIO_STATE(false)
			AUDIO.CLEAR_CUSTOM_RADIO_TRACK_LIST("RADIO_01_CLASS_ROCK")
			AUDIO.SKIP_RADIO_FORWARD()
			AUDIO.STOP_AUDIO_SCENE("CAR_MOD_RADIO_MUTE_SCENE")
			return false
		end

		if PAD.IS_CONTROL_JUST_PRESSED(2, 194)  then
			state = 2
			sTime = cTime()
		elseif state ~= 2 then		
			if instructional:begin() then
				instructional.add_control(194, "REPLAY_SKIP_S")
				instructional:set_background_colour(0, 0, 0, 80)
				instructional:draw()
			end
		end

		HUD.HIDE_HUD_AND_RADAR_THIS_FRAME()
		HUD._HUD_WEAPON_WHEEL_IGNORE_SELECTION()
		GRAPHICS.DRAW_SCALEFORM_MOVIE_FULLSCREEN(scaleform, 255, 255, 255, 255, 0)
		return true
	end)
end)


developer(menu.toggle_loop, menu.my_root(), "Address Picker", {}, "Developer", function()
	if PLAYER.IS_PLAYER_FREE_AIMING(PLAYER.PLAYER_ID()) then
		local ptr = memory.alloc(32)
		if PLAYER.GET_ENTITY_PLAYER_IS_FREE_AIMING_AT(PLAYER.PLAYER_ID(), ptr) then
			entity = memory.read_int(ptr)
		end
		memory.free(ptr)
		if entity and entity ~= NULL then
			if ENTITY.IS_ENTITY_A_PED(entity) and PED.IS_PED_IN_ANY_VEHICLE(entity, false) then
				local vehicle  = PED.GET_VEHICLE_PED_IS_IN(entity, false)
				entity = vehicle
			end			
			local strg
			local ptrX = memory.alloc()
			local ptrY = memory.alloc()
			drawBoxEsp(entity, Colour.new(255, 0, 0, 255))
			local pos = ENTITY.GET_ENTITY_COORDS(entity)
			GRAPHICS.GET_SCREEN_COORD_FROM_WORLD_COORD(pos.x, pos.y, pos.z, ptrX, ptrY)
			local posX = memory.read_float(ptrX); memory.free(ptrX)
			local posY = memory.read_float(ptrY); memory.free(ptrY)
			local addr = entities.handle_to_pointer(entity)
			
			if addr ~= NULL then
				strg = string.format("%X", addr)
			else 
				strg = "NULL" 
			end

			local lenX, lenY = directx.get_text_size(strg, 0.5)
			GRAPHICS.DRAW_RECT(posX, posY, lenX, lenY, 0, 0, 0, 120)
			directx.draw_text(posX, posY, strg, ALIGN_CENTRE, 0.5, Colour.new(1.0, 1.0, 1.0, 1.0))
			if PED.IS_PED_SHOOTING(PLAYER.PLAYER_PED_ID()) and addr ~= NULL then
				util.copy_to_clipboard(strg)
			end
		end
	end
end)


developer(menu.action, menu.my_root(), "CPedFactory", {}, "", function()
	util.copy_to_clipboard(string.format('%X', gWorldPtr))
end)

menu.hyperlink(menu.my_root(), menuname("WiriScript", "加入WiriScript粉丝俱乐部"), "https://cutt.ly/wiriscript-fanclub", "加入我们的粉丝俱乐部，由komt创建")

for pId = 0, 32 do
	if players.exists(pId) then
		generate_features(pId)
	end
end
players.on_join(generate_features)

-------------------------------------
--ON STOP
-------------------------------------

util.on_stop(function()
	if handling.cursor_mode then
		UI.toggle_cursor_mode(false)
	end
	if gUsingBulletChanger then
		setBulletToDefault()
	end
	if gBulletSpeedMult ~= 1.0 then
		SET_AMMO_SPEED_MULT(1.0)
	end

	ufo.on_stop()
	guidedMissile.on_stop()

	if gUsingProfile then
		menu.trigger_commands("spoofname off")
		menu.trigger_commands("spoofrid off")
		menu.trigger_commands("crew off")
	end

	if gUsingCarpetRide then
		local m_objHash = util.joaat("p_cs_beachtowel_01_s")
		local pos = ENTITY.GET_ENTITY_COORDS(PLAYER.PLAYER_PED_ID())
		local obj = OBJECT.GET_CLOSEST_OBJECT_OF_TYPE(pos.x, pos.y, pos.z, 10.0, m_objHash, false, 0, 0)
		if ENTITY.DOES_ENTITY_EXIST(obj) and ENTITY.IS_ENTITY_ATTACHED_TO_ENTITY(PLAYER.PLAYER_PED_ID(), obj) then
			TASK.CLEAR_PED_TASKS_IMMEDIATELY(PLAYER.PLAYER_PED_ID())
			ENTITY.DETACH_ENTITY(PLAYER.PLAYER_PED_ID(), true, false)
			ENTITY.SET_ENTITY_VISIBLE(obj, false)
			entities.delete_by_handle(obj)
		end
	end

	if gUsingAutopilot then
		TASK.CLEAR_PED_TASKS(PLAYER.PLAYER_PED_ID())
	end

	if gUsingOrbitalCannon then
		ENTITY.FREEZE_ENTITY_POSITION(PLAYER.PLAYER_PED_ID(), false)
		menu.trigger_commands("becomeorbitalcannon off")
		GRAPHICS.ANIMPOSTFX_STOP("MP_OrbitalCannon")
		
		HUD.DISPLAY_RADAR(true)
		CAM.RENDER_SCRIPT_CAMS(false, false, 0, true, false, 0)
		STREAMING.CLEAR_FOCUS()
		CAM.DESTROY_ALL_CAMS(true)
		CAM.DO_SCREEN_FADE_IN(0)

		AUDIO.STOP_AUDIO_SCENE("dlc_xm_orbital_cannon_camera_active_scene")
		gSound.activating:stop()
		gSound.backgroundLoop:stop()
		gSound.fireLoop:stop()
		gSound.zoomOut:stop()
	end
end)


while true do
	wait()

	--local name = read_global.string(1893548 + ((PLAYER.PLAYER_ID() * 600) + 1) + 11 + 105)
	--local name = read_global.int(1893548 + ((PLAYER.PLAYER_ID() * 600) + 1) + 11 + 104)

	guidedMissile.main_loop()
	ufo.main_loop()

	if gBulletSpeedMult ~= 1.0 then
		SET_AMMO_SPEED_MULT(gBulletSpeedMult)
	end

-------------------------------------
--HANDLING DISPLAY
-------------------------------------

	if handling.display_handling then
		handling.vehicle_name = getUserVehicleName()
		handling.vehicle_model = getUserVehicleModel(true)

		if PAD.IS_CONTROL_JUST_PRESSED(2, 323) or PAD.IS_DISABLED_CONTROL_JUST_PRESSED(2, 323) then
			UI.toggle_cursor_mode()
			handling.cursor_mode = not handling.cursor_mode
		end

		UI.set_highlight_colour(highlightcolour.r, highlightcolour.g, highlightcolour.b)
		UI.begin("载具信息编辑器", handling.window_x, handling.window_y)
		
		UI.label("当前车辆\t", handling.vehicle_name)

		for s, l in pairs(handling.inviewport) do
			if #s > 0 then
				local subhead = capitalize(s)
				UI.subhead(subhead)
				for _, a in ipairs(l) do
					local addr = addressFromPointerChain(gWorldPtr, {0x08, 0xD30, 0x938, a[2]})
					local value
					
					if addr == NULL then
						value = "???"
					else
						value = round(memory.read_float(addr), 3)
					end
					
					if a[1] == handling.onfocus then
						UI.label(a[1] .. ":\t", value, onfocuscolour, onfocuscolour)
					else
						UI.label(a[1] .. ":\t", value)
					end
				end
			end
		end

		if menu.is_open() then 
			handling.inviewport = {}
			if isModelAnAircraft(handling.vehicle_model) and #handling.flying == 0 then
				handling.flying = handling:create_actions(handling.offsets[2], "flying")
			end
			
			if not isModelAnAircraft(handling.vehicle_model) and #handling.flying > 0 then
				for i, Id in ipairs(handling.flying) do
					menu.delete(Id)
				end
				handling.flying = {}
			end
			
			if VEHICLE.IS_THIS_MODEL_A_BOAT(handling.vehicle_model) and #handling.boat == 0 then
				handling.boat = handling:create_actions(handling.offsets[3], "boat")
			end
			
			if not VEHICLE.IS_THIS_MODEL_A_BOAT(handling.vehicle_model) and #handling.boat > 0 then
				for i, Id in ipairs(handling.boat) do
					menu.delete(Id)		
				end
				handling.boat = {}
			end
		end

		UI.divider()
		UI.start_horizontal()		   
		if UI.button("保存处理", buttonscolour, Colour.mult(buttonscolour, 0.6)) then
			handling:save()
		end
		if UI.button("加载处理", buttonscolour, Colour.mult(buttonscolour, 0.6)) then
			handling:load()
		end		
		UI.end_horizontal()
		handling.window_x, handling.window_y = UI.finish()

		if instructional:begin() then
			instructional.add_control(323, "Cursor mode")
			instructional:set_background_colour(0, 0, 0, 80)
			instructional:draw()
		end

	end
end
