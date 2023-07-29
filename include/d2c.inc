#if defined _d2c_helpers
 #endinput
#endif
#define _d2c_helpers

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <steamworks>
#include <json>



enum GameMode 
{ 
	GameMode_Ranked = 0,
	GameMode_Unranked = 1,
	GameMode_Solomid = 2,
	GameMode_Diretide = 3,
	GameMode_Greeviling = 4,
	GameMode_AbilityDraft = 5,
}

public GetIntProperty(index, String:prop[]){
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, prop, 4, index)
}

public GetFloatProperty(index, String:prop[]){
	return GetEntPropFloat(GetPlayerResourceEntity(), Prop_Send, prop, index)
}


public GetDuration(){
	new non_game_time = RoundFloat(GameRules_GetPropFloat("m_flGameStartTime"))
	PrintToServer("%d", non_game_time)
	new total_time = RoundFloat(GameRules_GetPropFloat("m_fGameTime"))
	return total_time - non_game_time;
}


public GetXPM(index){
	new totalEarned = GetIntProperty(index, "m_iTotalEarnedXP")
	return totalEarned / RoundFloat((GameRules_GetPropFloat("m_fGameTime") + 1) / 60)
}

public GetGPM(index){
	new totalEarned = GetIntProperty(index, "m_iTotalEarnedGold")
	return totalEarned / RoundFloat((GameRules_GetPropFloat("m_fGameTime") + 1) / 60)
}

// SPECTATOR:
// Member: m_hPrimaryRune (offset 956) (type integer) (bits 21) (Unsigned)
// Member: m_hSecondaryRune (offset 960) (type integer) (bits 21) (Unsigned)


public GetDenies(index){
	return GetIntProperty(index, "m_iDenyCount");
}

public GetLasthits(index){
	return GetIntProperty(index, "m_iLastHitCount");
}

public GetLevel(index){
	return GetIntProperty(index, "m_iLevel");
}


public void GetPosition(int i, float vec[3]){
	GetEntPropVector(i, PropType:0, "m_vecOrigin", vec, 0);
}



public int GetNetWorth(int index){
//	return GetIntProperty(index, "m_iNetWorth");
	return GetEntProp(FindEntityByClassname(-1, "dota_data_spectator"), Prop_Send, "m_iNetWorth", 4, index)
}

public GetTeam(index){
	return GetIntProperty(index, "m_iPlayerTeams");
}

public GetKills(index){
	return GetIntProperty(index, "m_iKills");
}

public int GetHealing(int index){
	return RoundFloat(GetFloatProperty(index, "m_fHealing"));
}

public GetDeaths(index){
	return GetIntProperty(index, "m_iDeaths");
}

public GetAssists(index){
	return GetIntProperty(index, "m_iAssists");
}

public GetHero(index, String:buffer[40]){
	new heroEntity = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);
	GetEntityClassname(heroEntity, buffer, sizeof(buffer));
}

public bool GetDidRandom(int index){
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_bHasRandomed", _, index);
}

public bool GetSteamid(index, String:buffer[20]){
	new offset = FindSendPropInfo("CDOTA_PlayerResource", "m_iPlayerSteamIDs");
	new sid = GetEntData(GetPlayerResourceEntity(), offset + index * 8, 4);
	if(sid == 0) return false
	
	Format(buffer, sizeof(buffer), "[U:1:%d]", sid)
	return true
}

public int GetPlayerID(const char[] steamid){
	new heroCount = 0;
	
	for (new i = 0; i <= 10; i++){
		char _steamid[20];
		bool hasPlayer = GetSteamid(i, _steamid)
		
		if(StrEqual(_steamid, steamid)) {
			return i;
		}
	} 
	
	return -1;
}

public GetPlayersCount(){
	new heroCount = 0;
	
	for (new i = 0; i <= 10; i++){
		new String:steamid[20]
		new hasPlayer = GetSteamid(i, steamid)
		
		if(hasPlayer){
			heroCount++;
		}
	} 
	
	return heroCount;
}

public SetPlayersToStart(int toStart)
{
    ServerCommand("dota_wait_for_players_to_load_count %d", toStart);
    PrintToServer("Server command executed(wait for load count)");
}

public JSON_Array GetItems(int index)
{
	int hero = GetEntPropEnt(GetPlayerResourceEntity(), Prop_Send, "m_hSelectedHero", index);
	JSON_Array items = new JSON_Array();
	for (int i = 0; i < 6; ++i)
	{
		int	 item = GetEntPropEnt(hero, Prop_Send, "m_hItems", i);
		
		char classname[200];
		if (!IsValidEntity(item))
		{
			classname = "item_emptyitembg"
		}
		else {
			GetEdictClassname(item, classname, sizeof(classname));
		}
		items.PushString(classname);
	}
	return items;
}


public JSON_Object LoadMatchConfigJSON(){
	char path[500];
	BuildPath(Path_SM, path, sizeof(path), "configs/match.json")
	Handle file = OpenFile(path, "r+");
	if (!file)
	{
		PrintToServer("Can't read file... :( %s", path);
		return 0;
	}
	char line[10000];
	
	ReadFileString(file, line, sizeof(line))
	
	CloseHandle(file);
	
	return view_as<JSON_Object>(json_decode(line));
}