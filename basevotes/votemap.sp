/**
 * vim: set ts=4 :
 * =============================================================================
 * SourceMod Basevotes Plugin
 * Provides map functionality
 *
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

Menu g_MapList;
new g_mapCount;

new Handle:g_SelectedMaps;
new bool:g_VoteMapInUse;

DisplayVoteMapMenu(client, mapCount, String:maps[5][])
{
	LogAction(client, -1, "\"%L\" initiated a map vote.", client);
	ShowActivity2(client, "[SM] ", "%t", "Initiated Vote Map");
	
	g_voteType = voteType:map;
	
	g_hVoteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
	
	if (mapCount == 1)
	{
		GetMapDisplayName(maps[0], g_voteInfo[VOTE_NAME], sizeof(g_voteInfo[]));
			
		g_hVoteMenu.SetTitle("Change Map To");
		g_hVoteMenu.AddItem(maps[0], "Yes");
		g_hVoteMenu.AddItem(VOTE_NO, "No");
	}
	else
	{
		g_voteInfo[VOTE_NAME][0] = '\0';
		
		g_hVoteMenu.SetTitle("Map Vote");
		for (new i = 0; i < mapCount; i++)
		{
			decl String:displayName[PLATFORM_MAX_PATH];
			GetMapDisplayName(maps[i], displayName, sizeof(displayName));
			g_hVoteMenu.AddItem(maps[i], displayName);
		}	
	}
	
	g_hVoteMenu.ExitButton = false;
	g_hVoteMenu.DisplayVoteToAll(20);		
}

ResetMenu()
{
	g_VoteMapInUse = false;
	ClearArray(g_SelectedMaps);
}

ConfirmVote(client)
{
	Menu menu = CreateMenu(MenuHandler_Confirm);
	
	decl String:title[100];
	Format(title, sizeof(title), "%T:", "Confirm Vote", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	decl String:itemtext[256];
	Format(itemtext, sizeof(itemtext), "%T", "Start the Vote", client);
	menu.AddItem("Confirm", itemtext);
	
	menu.Display(client, MENU_TIME_FOREVER);	
}

public MenuHandler_Confirm(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
		g_VoteMapInUse = false;
	}
	else if (action == MenuAction_Cancel)
	{
		ResetMenu();
		
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:maps[5][PLATFORM_MAX_PATH];
		new selectedmaps = GetArraySize(g_SelectedMaps);
		
		for (new i = 0; i < selectedmaps; i++)
		{
			GetArrayString(g_SelectedMaps, i, maps[i], sizeof(maps[]));
		}
		
		DisplayVoteMapMenu(param1, selectedmaps, maps);
		
		ResetMenu();
	}
}

public MenuHandler_Map(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel)
	{		
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			ConfirmVote(param1);
		}
		else // no action was selected.
		{
			/* Re-enable the menu option */
			ResetMenu();
		}
	}
	else if (action == MenuAction_DrawItem)
	{
		decl String:info[32], String:name[32];
		
		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		
		if (FindStringInArray(g_SelectedMaps, info) != -1)
		{
			return ITEMDRAW_IGNORE;
		}
		else
		{
			return ITEMDRAW_DEFAULT;
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:info[32], String:name[32];
		
		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		
		PushArrayString(g_SelectedMaps, info);
		
		/* Redisplay the list */
		if (GetArraySize(g_SelectedMaps) < 5)
		{
			g_MapList.Display(param1, MENU_TIME_FOREVER);
		}
		else
		{
			ConfirmVote(param1);
		}
	}
	else if (action == MenuAction_Display)
	{
		decl String:title[128];
		Format(title, sizeof(title), "%T", "Please select a map", param1);
		SetPanelTitle(Handle:param2, title);
	}
	
	return 0;
}

public AdminMenu_VoteMap(Handle:topmenu, 
							  TopMenuAction:action,
							  TopMenuObject:object_id,
							  param,
							  String:buffer[],
							  maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "Map vote", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (!g_VoteMapInUse)
		{
			ResetMenu();
			g_VoteMapInUse = true;
			g_MapList.Display(param, MENU_TIME_FOREVER);
		}
		else 
		{
			PrintToChat(param, "[SM] %T", "Map Vote In Use", param);
		}
	}
	else if (action == TopMenuAction_DrawOption)
	{	
		/* disable this option if a vote is already running, theres no maps listed or someone else has already acessed this menu */
		buffer[0] = (!IsNewVoteAllowed() || g_mapCount < 1 || g_VoteMapInUse) ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT;
	}
}

public Action:Command_Votemap(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_votemap <mapname> [mapname2] ... [mapname5]");
		return Plugin_Handled;	
	}
	
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] %t", "Vote in Progress");
		return Plugin_Handled;
	}
		
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	decl String:text[256];
	GetCmdArgString(text, sizeof(text));

	decl String:maps[5][PLATFORM_MAX_PATH];
	new mapCount;	
	new len, pos;
	
	while (pos != -1 && mapCount < 5)
	{	
		pos = BreakString(text[len], maps[mapCount], sizeof(maps[]));
		
		if (!IsMapValid(maps[mapCount]))
		{
			ReplyToCommand(client, "[SM] %t", "Map was not found", maps[mapCount]);
			return Plugin_Handled;
		}		

		mapCount++;
		
		if (pos != -1)
		{
			len += pos;
		}	
	}

	DisplayVoteMapMenu(client, mapCount, maps);
	
	return Plugin_Handled;	
}

new Handle:g_map_array = null;
new g_map_serial = -1;

int LoadMapList(Menu menu)
{
	new Handle:map_array;
	
	if ((map_array = ReadMapList(g_map_array,
			g_map_serial,
			"sm_votemap menu",
			MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT|MAPLIST_FLAG_MAPSFOLDER))
		!= null)
	{
		g_map_array = map_array;
	}
	
	if (g_map_array == null)
	{
		return 0;
	}
	
	RemoveAllMenuItems(menu);
	
	char map_name[PLATFORM_MAX_PATH];
	new map_count = GetArraySize(g_map_array);
	
	for (new i = 0; i < map_count; i++)
	{
		decl String:displayName[PLATFORM_MAX_PATH];
		GetArrayString(g_map_array, i, map_name, sizeof(map_name));
		GetMapDisplayName(map_name, displayName, sizeof(displayName));
		menu.AddItem(map_name, displayName);
	}
	
	return map_count;
}
