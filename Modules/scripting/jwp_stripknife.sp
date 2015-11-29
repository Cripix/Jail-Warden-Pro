#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <jwp>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define ITEM "stripknife"

bool g_bHaveKnife[MAXPLAYERS+1] = {true, ...};

public Plugin myinfo = 
{
	name = "[JWP] Strip Knife",
	description = "Warden can strip knife from terrorist",
	author = "White Wolf (HLModders LLC)",
	version = PLUGIN_VERSION,
	url = "http://hlmod.ru"
};

public void OnPluginStart()
{
	if (JWP_IsStarted()) JWC_Started();
}

public int JWC_Started()
{
	JWP_AddToMainMenu(ITEM, OnFuncDisplay, OnFuncSelect);
}

public void OnPluginEnd()
{
	JWP_RemoveFromMainMenu(ITEM, OnFuncDisplay, OnFuncSelect);
}

public bool OnFuncDisplay(int client, char[] buffer, int maxlength)
{
	FormatEx(buffer, maxlength, "Дать/Забрать заточку");
	return true;
}

public bool OnFuncSelect(int client)
{
	Menu StripMenu = new Menu(StripMenu_Callback);
	StripMenu.SetTitle("+/- Заточка:");
	char id[4], name[MAX_NAME_LENGTH];
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (CheckClient(i))
		{
			Format(name, sizeof(name), "[%s]%N", (g_bHaveKnife[i]) ? "+" : "-", i);
			IntToString(i, id, sizeof(id));
			StripMenu.AddItem(id, name);
		}
	}
	if (!StripMenu.ItemCount)
		StripMenu.AddItem("", "Нет живых зеков", ITEMDRAW_DISABLED);
	StripMenu.Display(client, MENU_TIME_FOREVER);
	return true;
}

public int StripMenu_Callback(Menu menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_End: menu.Close();
		case MenuAction_Cancel: JWP_ShowMainMenu(client);
		case MenuAction_Select:
		{
			char info[4];
			menu.GetItem(slot, info, sizeof(info));
			
			int target = StringToInt(info, sizeof(info));
			if (CheckClient(target))
			{
				if (g_bHaveKnife[target])
				{
					int weapon = GetPlayerWeaponSlot(target, 2);
					if (IsValidEdict(weapon))
						AcceptEntityInput(weapon, "Kill");
				}
				else
					GivePlayerItem(client, "weapon_knife");
				g_bHaveKnife = !g_bHaveKnife;
				JWP_ActionMsgAll("%N: %s заточку %N", client, (g_bHaveKnife[target]) ? "дал" : "забрал", target);
			}
			else
				JWP_ActionMsg(client, "Не удалось выполнить действие");
			JWP_ShowMainMenu(client);
		}
	}
}

bool CheckClient(int client)
{
	return (IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client) && GetClientTeam(client) == CS_TEAM_T && IsPlayerAlive(client));
}