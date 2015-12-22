#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <jwp>
#include <emitsoundany>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define ITEM "healthkit"

ConVar g_CvarHK_Limit, g_CvarHK_Wait, g_CvarHK_Life, g_CvarHK_Team, g_CvarHK_Hp, g_CvarHK_LimitHp, g_CvarHK_Model;

int g_iHKits[MAXPLAYERS+1];
char g_cHKModel[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "[JWP] Health Kit",
	description = "Warden can drop health kit",
	author = "White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	g_CvarHK_Limit = CreateConVar("jwp_healthkit_limit", "3", "Сколько аптечек может создать командир. 0 - без ограничений", FCVAR_PLUGIN, true, 0.0);
	g_CvarHK_Wait = CreateConVar("jwp_healthkit_wait", "3", "Аптечку можно создавать 1 раз в 'x' сек", FCVAR_PLUGIN, true, 1.0);
	g_CvarHK_Life = CreateConVar("jwp_healthkit_life", "9", "Если аптечку не подняли, удалить ее через 'x' сек (0 = не удалять)", FCVAR_PLUGIN, true, 0.0);
	g_CvarHK_Team = CreateConVar("jwp_healthkit_team", "1", "Кому аптечка добавляет HP: 1 = Всем; 2 = T; 3 = CT", FCVAR_PLUGIN, true, 1.0, true, 3.0);
	g_CvarHK_LimitHp = CreateConVar("jwp_healthkit_limit_hp", "100", "Лимит HP (аптечка). 0 = без лимита.", FCVAR_PLUGIN, true, 0.0);
	g_CvarHK_Hp = CreateConVar("jwp_healthkit_hp", "50", "Сколько HP добавляет аптечка", FCVAR_PLUGIN, true, 1.0);
	g_CvarHK_Model = CreateConVar("jwp_healthkit_model", "models/gibs/hgibs.mdl", "Модель аптечки", FCVAR_PLUGIN);
	
	g_CvarHK_Limit.AddChangeHook(OnCvarChange);
	g_CvarHK_Wait.AddChangeHook(OnCvarChange);
	g_CvarHK_Life.AddChangeHook(OnCvarChange);
	g_CvarHK_Team.AddChangeHook(OnCvarChange);
	g_CvarHK_LimitHp.AddChangeHook(OnCvarChange);
	g_CvarHK_Hp.AddChangeHook(OnCvarChange);
	g_CvarHK_Model.AddChangeHook(OnCvarChange);
	
	
	HookEvent("round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
	if (JWP_IsStarted()) JWC_Started();
}

public void OnMapStart()
{
	g_CvarHK_Model.GetString(g_cHKModel, sizeof(g_cHKModel));
	PrecacheModel(g_cHKModel, true);
	PrecacheSoundAny("sound/ambient/machines/zap2.wav");
}

public void OnCvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_CvarHK_Limit) g_CvarHK_Limit.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_Wait) g_CvarHK_Wait.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_Life) g_CvarHK_Life.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_Team) g_CvarHK_Team.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_LimitHp) g_CvarHK_LimitHp.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_Hp) g_CvarHK_Hp.SetInt(StringToInt(newValue));
	else if (cvar == g_CvarHK_Model)
	{
		strcopy(g_cHKModel, sizeof(g_cHKModel), newValue);
		g_CvarHK_Model.SetString(newValue);
		PrecacheModel(g_cHKModel, true);
	}
}

public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
		g_iHKits[i] = 0;
}

public int JWC_Started()
{
	JWP_AddToMainMenu(ITEM, OnFuncDisplay, OnFuncSelect);
}

public void OnPluginEnd()
{
	JWP_RemoveFromMainMenu(ITEM, OnFuncDisplay, OnFuncSelect);
}

public bool OnFuncDisplay(int client, char[] buffer, int maxlength, int style)
{
	if (g_CvarHK_Limit.IntValue)
	{
		if (g_iHKits[client] >= 3) style = ITEMDRAW_DISABLED;
		else style = ITEMDRAW_DEFAULT;
		Format(buffer, maxlength, "Создать аптечку (%d/%d)", g_iHKits[client], g_CvarHK_Limit.IntValue);	
	}
	else
		strcopy(buffer, maxlength, "Создать аптечку");
	return true;
}

public bool OnFuncSelect(int client)
{
	char buffer[64];
	Format(buffer, sizeof(buffer), "Создать аптечку (%d/%d)", g_iHKits[client]+1, g_CvarHK_Limit.IntValue);
	if (TrySpawnHealthKit(client)) JWP_RefreshMenuItem(ITEM, buffer);
	JWP_ShowMainMenu(client);
	return true;
}

bool TrySpawnHealthKit(int client)
{
	if (g_CvarHK_Limit.IntValue && g_iHKits[client] >= g_CvarHK_Limit.IntValue)
	{
		JWP_RefreshMenuItem(ITEM, _, ITEMDRAW_DISABLED);
		return false;
	}
	
	if (JWP_IsFlood(client))
	{
		JWP_ActionMsg(client, "Не флудите аптечкой.");
		return false;
	}
	
	float origin[3];
	int entity = GetAimInfo(client, origin);
	if (!IsValidEntity(entity) || (0 < entity <= MaxClients))
	{
		PrintCenterText(client, "Уберите прицел с игрока");
		return false;
	}
	
	int kit_ent = CreateEntityByName("prop_dynamic_override");
	if (!IsValidEdict(kit_ent))
	{
		LogError("Could not create entity 'prop_dynamic_override'");
		return false;
	}
	
	DispatchKeyValue(kit_ent, "physdamagescale", "0.0");
	DispatchKeyValue(kit_ent, "solid", "6");
	origin[2] += 5.0;
	
	DispatchKeyValueVector(kit_ent, "origin", origin);
	char kitname[36];
	Format(kitname, sizeof(kitname), "kit_%d", kit_ent);
	DispatchKeyValue(kit_ent, "targetname", kitname);
	SetEntityModel(kit_ent, g_cHKModel);
	DispatchSpawn(kit_ent);
	SetEntityMoveType(kit_ent, MOVETYPE_VPHYSICS);
	SDKHook(kit_ent, SDKHook_StartTouchPost, OnKitTouch);
	
	if (g_CvarHK_Life.IntValue && IsValidEdict(kit_ent))
	{
		char info[24];
		Format(info, sizeof(info), "OnUser1 !self:kill::%f:1", g_CvarHK_Life.FloatValue);
		SetVariantString(info);
		AcceptEntityInput(kit_ent, "AddOutput");
		AcceptEntityInput(kit_ent, "FireUser1"); 
	}
	
	int ent = CreateEntityByName("env_sprite");
	if (IsValidEdict(ent))
	{
		DispatchKeyValueVector(ent, "origin", origin);
		DispatchKeyValue(ent, "model", "sprites/glow01.spr");
		DispatchKeyValue(ent, "rendermode", "5");
		DispatchKeyValue(ent, "renderfx", "16");
		DispatchKeyValue(ent, "scale", "1");
		DispatchKeyValue(ent, "renderamt", "255");
		DispatchKeyValue(ent, "rendercolor", "0 255 0");
		DispatchSpawn(ent);
		SetVariantString(kitname);
		AcceptEntityInput(ent, "SetParent");
		AcceptEntityInput(ent, "ShowSprite");
	}
	
	TE_SetupSparks(origin, origin, 2, 1);
	TE_SendToAll();
	EmitAmbientSound("ambient/machines/zap2.wav", origin);
	
	g_iHKits[client]++;
	return true;
}

public void OnKitTouch(int entity, int other)
{
	if (other < 1 || other > MaxClients || !IsClientInGame(other) || !IsPlayerAlive(other))
		return;
	// Check client team
	if (g_CvarHK_Team.IntValue != 1 && g_CvarHK_Team.IntValue != GetClientTeam(other)) return;
	// Check max health
	int hp = GetClientHealth(other);
	if (g_CvarHK_LimitHp.IntValue && hp >= g_CvarHK_LimitHp.IntValue) return;
	AcceptEntityInput(entity, "Kill");
	
	// Set new health
	hp += g_CvarHK_Hp.IntValue;
	if (g_CvarHK_LimitHp.IntValue && hp > g_CvarHK_LimitHp.IntValue)
		hp = g_CvarHK_LimitHp.IntValue;
	SetEntityHealth(other, hp);
}

int GetAimInfo(int client, float end_origin[3])
{
	float origin[3], angles[3];
	
	GetClientEyePosition(client, origin);
	GetClientEyeAngles(client, angles);
	
	TR_TraceRayFilter(origin, angles, MASK_SHOT, RayType_Infinite, TraceFilter_Callback, client);
	if (TR_DidHit())
	{
		TR_GetEndPosition(end_origin);
		return TR_GetEntityIndex();
	}
	return -1;
}

public bool TraceFilter_Callback(int ent, int mask, any something)
{
	return something != ent;
}