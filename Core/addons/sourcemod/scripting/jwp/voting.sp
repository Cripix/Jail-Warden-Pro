int g_iVoteResult[MAXPLAYERS+1];
int g_iVotsMax, g_iVots, g_iVoteSec;
Handle g_VoteTimer;
bool g_bVoteFinished;

Menu g_VoteMenu;

void JWP_StartVote()
{
	int tt_count, ct_count;
	int[] tt_list = new int[MaxClients];
	int[] ct_list = new int[MaxClients];
	int i = 1;
	while (i <= MaxClients)
	{
		g_iVoteResult[i] = 0;
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == CS_TEAM_T)
			{
				tt_list[tt_count] = i;
				tt_count++;
			}
			else
			{
				ct_list[ct_count] = i;
				ct_count++;
			}
		}
		i++;
	}
	
	if (!tt_count || !ct_count) return;
	else if (ct_count == 1)
	{
		BecomeCmd(ct_list[0]);
		return;
	}
	g_iVotsMax = tt_count;
	g_iVots = 0;
	if (g_VoteMenu != null)
	{
		g_VoteMenu.Close();
		g_VoteMenu = null;
	}
	g_VoteMenu = new Menu(g_VoteMenu_Callback);
	g_VoteMenu.SetTitle("Кто будет командиром?\n \n");
	char id[4], nick[MAX_NAME_LENGTH];
	i = 0;
	while (i < ct_count)
	{
		IntToString(ct_list[i], id, sizeof(id));
		GetClientName(ct_list[i], nick, sizeof(nick));
		if (g_VoteMenu.AddItem(id, nick))
			i++;
	}
	i = 0;
	while (i < tt_count)
	{
		g_VoteMenu.Display(tt_list[i], MENU_TIME_FOREVER);
		i++;
	}
	g_iVoteSec = g_CvarVoteTime.IntValue;
	g_VoteTimer = CreateTimer(1.0, g_VoteTimer_Callback, _, TIMER_REPEAT);
	PrintHintTextToAll("Кто будет командиром?\n%d", g_iVoteSec);
}

public int g_VoteMenu_Callback(Menu menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		// case MenuAction_End: menu.Close();
		case MenuAction_Select:
		{
			if (g_VoteTimer != null && GetClientTeam(client) == CS_TEAM_T)
			{
				char id[4];
				menu.GetItem(slot, id, sizeof(id));
				int target = StringToInt(id);
				if (!target || GetClientTeam(target) == CS_TEAM_CT || !IsPlayerAlive(target))
				{
					if (menu.RemoveItem(slot) && menu.ItemCount > 0)
					{
						PrintCenterText(client, "Игрок не найден. Выберите другого.");
						g_VoteMenu.Display(client, MENU_TIME_FOREVER);
					}
					else
						PrintHintText(client, "Игрок не найден");
				}
				else
				{
					g_iVoteResult[target]++;
					g_iVots++;
					if (g_iVots >= g_iVotsMax)
					{
						if (g_VoteTimer != null)
						{
							KillTimer(g_VoteTimer);
							g_VoteTimer = null;
						}
						CheckVoteWinner();
					}
				}
			}
		}
	}
}

public Action g_VoteTimer_Callback(Handle timer)
{
	if (g_iWarden || !JWP_GetTeamClient(CS_TEAM_T, true) || !JWP_GetTeamClient(CS_TEAM_CT, true))
	{
		PrintToChatAll("\x04Голосование за выбор командира остановлено.");
		PrintHintTextToAll("ГОЛОСОВАНИЕ ОСТАНОВЛЕНО");
		g_VoteTimer = null;
		return Plugin_Stop;
	}
	else if (g_iVoteSec-- > 0)
	{
		if (g_iVots > 0)
		{
			char best3ct[152];
			if (JWP_LastBest3Ct(best3ct))
				PrintHintTextToAll("Кто будет командиром?\n%d\n \n%s", g_iVoteSec, best3ct);
			else
			{
				g_iVots = 0;
				PrintHintTextToAll("Кто будет командиром?\n%d", g_iVoteSec);
			}
		}
		else
			PrintHintTextToAll("Кто будет командиром?\n%d", g_iVoteSec);
		return Plugin_Continue;
	}
	CheckVoteWinner();
	g_VoteTimer = null;
	g_bVoteFinished = true;
	return Plugin_Stop;
}

bool JWP_LastBest3Ct(char Info[152])
{
	int ct1 = JWP_GetBestCt(0, 0);
	if (ct1 > 0)
	{
		Format(Info, sizeof(Info), "1. %N (%d)", ct1, g_iVoteResult[ct1]);
		int ct2 = JWP_GetBestCt(ct1, 0);
		if (ct2 > 0)
		{
			Format(Info, sizeof(Info), "%s\n2. %N (%d)", Info, ct2, g_iVoteResult[ct2]);
			int ct3 = JWP_GetBestCt(ct1, ct2);
			if (ct3 > 0)
			{
				Format(Info, sizeof(Info), "%s\n3. %N (%d)", Info, ct3, g_iVoteResult[ct3]);
			}
		}
	}
	
	return (ct1 > 0);
}

int JWP_GetBestCt(int p1, int p2)
{
	int best_ct, vots, i = 1;
	while (i <= MaxClients)
	{
		if (g_iVoteResult[i] > vots && p1 != i && p2 != i && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
		{
			vots = g_iVoteResult[i];
			best_ct = i;
		}
	}
	return best_ct;
}

void CheckVoteWinner()
{
	int ct, vots, i = 1;
	while (i <= MaxClients)
	{
		if (g_iVoteResult[i] > vots && IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT && IsPlayerAlive(i))
		{
			vots = g_iVoteResult[i];
			ct = i;
		}
		i++;
	}
	
	if (ct > 0) BecomeCmd(ct);
	else PrintHintTextToAll("Командир не выбран");
	g_bVoteFinished = true;
}