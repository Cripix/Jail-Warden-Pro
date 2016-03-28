#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jwp>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define FDGIVE "freeday_give"
#define FDTAKE "freeday_take"

ConVar g_CvarRGBA;

int g_iColor[4] = {0, 255, 0, 255};

public Plugin myinfo = 
{
	name = "[JWP] Freeday",
	description = "Give/Take freeday",
	author = "White Wolf",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	g_CvarRGBA = CreateConVar("jwp_freeday_rgba", "0 255 0 255", "Цвет скина у заключенного, который получил freeday (rgba)", FCVAR_PLUGIN);
	
	g_CvarRGBA.AddChangeHook(OnCvarChange);
	if (JWP_IsStarted()) JWC_Started();
	
	AutoExecConfig(true, "freeday", "jwp");
	
	LoadTranslations("jwp_modules.phrases");
}

public int JWC_Started()
{
	JWP_AddToMainMenu(FDGIVE, OnFuncFDGiveDisplay, OnFuncFDGiveSelect);
	JWP_AddToMainMenu(FDTAKE, OnFuncFDTakeDisplay, OnFuncFDTakeSelect);
}

public void OnConfigsExecuted()
{
	char buffer[48];
	g_CvarRGBA.GetString(buffer, sizeof(buffer));
	JWP_ConvertToColor(buffer, g_iColor);
}

public void OnCvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_CvarRGBA)
	{
		char buffer[48];
		g_CvarRGBA.SetString(newValue);
		strcopy(buffer, sizeof(buffer), newValue);
		JWP_ConvertToColor(buffer, g_iColor);
	}
}

public void OnPluginEnd()
{
	JWP_RemoveFromMainMenu(FDGIVE, OnFuncFDGiveDisplay, OnFuncFDGiveSelect);
	JWP_RemoveFromMainMenu(FDTAKE, OnFuncFDTakeDisplay, OnFuncFDTakeSelect);
}
public bool OnFuncFDGiveDisplay(int client, char[] buffer, int maxlength, int style)
{
	FormatEx(buffer, maxlength, "%T", "Freeday_Menu_Give", LANG_SERVER);
	return true;
}

public bool OnFuncFDGiveSelect(int client)
{
	ShowFreedayMenu(client, false);
	return true;
}

public bool OnFuncFDTakeDisplay(int client, char[] buffer, int maxlength, int style)
{
	FormatEx(buffer, maxlength, "%T", "Freeday_Menu_Take", LANG_SERVER);
	return true;
}

public bool OnFuncFDTakeSelect(int client)
{
	ShowFreedayMenu(client, true);
	return true;
}

void ShowFreedayMenu(int client, bool fd_players)
{
	char id[4], name[MAX_NAME_LENGTH], langphrases[48];
	Menu PList = new Menu(PList_Callback);
	if (fd_players)
	{
		Format(langphrases, sizeof(langphrases), "%T \n", "Freeday_Players_TakeFD_Title", LANG_SERVER);
		PList.SetTitle(langphrases);
	}
	else
	{
		Format(langphrases, sizeof(langphrases), "%T \n", "Freeday_Players_GiveFD_Title", LANG_SERVER);
		PList.SetTitle(langphrases);
	}
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (CheckClient(i))
		{
			GetClientName(i, name, sizeof(name))
			if (fd_players && JWP_PrisonerHasFreeday(i))
			{
				IntToString(i, id, sizeof(id));
				PList.AddItem(id, name);
			}
			else if (!fd_players && !JWP_PrisonerHasFreeday(i))
			{
				IntToString(i, id, sizeof(id));
				PList.AddItem(id, name);
			}
		}
	}
	if (!PList.ItemCount)
	{
		Format(langphrases, sizeof(langphrases), "%T", "General_No_Prisoners", LANG_SERVER);
		PList.AddItem("", langphrases, ITEMDRAW_DISABLED);
	}
	PList.ExitBackButton = true;
	PList.Display(client, MENU_TIME_FOREVER);
}

public int PList_Callback(Menu menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_End: menu.Close();
		case MenuAction_Cancel:
		{
			if (slot == MenuCancel_ExitBack)
				JWP_ShowMainMenu(client);
		}
		case MenuAction_Select:
		{
			char info[4];
			menu.GetItem(slot, info, sizeof(info));
			
			int target = StringToInt(info);
			bool state = JWP_PrisonerHasFreeday(target);
			
			bool b = state;
			if (target && CheckClient(target))
			{
				state = !state;
				
				JWP_PrisonerSetFreeday(target, state);
				
				SetEntityRenderMode(target, RENDER_TRANSCOLOR);
				SetEntityRenderColor(target, (state) ? g_iColor[0] : 255,
											(state) ? g_iColor[1] : 255,
											(state) ? g_iColor[2] : 255,
											(state) ? g_iColor[3] : 255);
				JWP_ActionMsgAll("%T", (state) ? "Freeday_ActionMessage_Gived" : "Freeday_ActionMessage_Taken", LANG_SERVER, client, target);
			}
			menu.RemoveItem(slot);
			
			ShowFreedayMenu(client, b);
		}
	}
}

bool CheckClient(int client)
{
	return (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == CS_TEAM_T && IsPlayerAlive(client));
}