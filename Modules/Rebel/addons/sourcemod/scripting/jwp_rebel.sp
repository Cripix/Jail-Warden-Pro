#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <jwp>

// Force 1.7 syntax
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

bool g_bIsRebel[MAXPLAYERS+1];
bool g_bColor;

ConVar g_CvarRebelColor, g_CvarRebelTime;
int g_iRebelColor[4];

Handle g_TimerColor[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[JWP] Rebel",
	description = "Prisoners that perform damage notified as rebels",
	author = "White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	g_CvarRebelColor = CreateConVar("jwp_rebel_color", "120 0 0 255", "Цвет бунтовщика в RGBA", FCVAR_PLUGIN);
	g_CvarRebelTime = CreateConVar("jwp_rebel_sec", "5", "Если T ранил CT, сколько секунд T будет бунтующим? (0 = бунт откл)", FCVAR_PLUGIN, true, 0.0);
	
	g_CvarRebelColor.AddChangeHook(OnCvarChange);
	g_CvarRebelTime.AddChangeHook(OnCvarChange);
	
	ReadCfg();
	AutoExecConfig(true, "rebel", "jwp");
}

public void OnConfigsExecuted()
{
	ReadCfg();
}

public void OnCvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_CvarRebelColor)
	{
		char buffer[48];
		g_CvarRebelColor.SetString(newValue);
		strcopy(buffer, sizeof(buffer), newValue);
		g_bColor = JWP_ConvertToColor(buffer, g_iRebelColor);
	}
}

public void OnClientPutInServer(int client)
{
	if (client && IsClientInGame(client))
		SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	if (g_TimerColor[client] != null)
	{
		KillTimer(g_TimerColor[client]);
		g_TimerColor[client] = null;
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (attacker && (attacker <= MaxClients) && attacker != victim && IsClientInGame(attacker) && GetClientTeam(attacker) == CS_TEAM_T && !JWP_PrisonerHasFreeday(attacker))
	{
		if (!g_bIsRebel[attacker])
		{
			if (g_bColor)
			{
				SetEntityRenderMode(attacker, RENDER_TRANSCOLOR);
				SetEntityRenderColor(attacker, 120, 0, 0, 255);
			}
			PrintToChatAll("\x01\x06Заключенный %N \x02бунтует", attacker);
			if (g_CvarRebelTime.IntValue)
				g_TimerColor[attacker] = CreateTimer(g_CvarRebelTime.FloatValue, g_TimerColor_Callback, attacker);
			g_bIsRebel[attacker] = true;
		}
	}
	return Plugin_Continue;
}

public Action g_TimerColor_Callback(Handle timer, any client)
{
	if (g_bColor && client && IsClientInGame(client) && !JWP_PrisonerHasFreeday(client))
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
	
	g_bIsRebel[client] = false;
	g_TimerColor[client] = null;
}

void ReadCfg()
{
	char buffer[48];
	g_CvarRebelColor.GetString(buffer, sizeof(buffer));
	g_bColor = JWP_ConvertToColor(buffer, g_iRebelColor);
}