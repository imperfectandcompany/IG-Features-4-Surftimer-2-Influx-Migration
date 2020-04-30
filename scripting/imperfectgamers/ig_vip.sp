#include <colorvariables>
#include <smlib/strings>
#include <cstrike>
#include <sourcecomms>

#pragma semicolon 1

Handle g_hDb = null;


#define MAX_TITLE_LENGTH 128
#define MAX_TITLES 32
#define MAX_RAWTITLE_LENGTH 1024

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

char g_szTitle[MAXPLAYERS + 1][MAX_TITLE_LENGTH];
char g_szTitlePlain[MAXPLAYERS + 1][MAX_TITLE_LENGTH];


char g_szCustomTitleRaw[MAXPLAYERS + 1][MAX_RAWTITLE_LENGTH];
bool g_bDbCustomTitleInUse[MAXPLAYERS + 1] = false;
// 0 = name, 1 = text;
int g_iCustomColours[MAXPLAYERS + 1][2];
bool g_bUpdatingColours[MAXPLAYERS + 1];

bool g_bLoaded[MAXPLAYERS + 1];

void VIP_OnPluginStart() {
	
	PrintToServer("LOADING IG VIP");
	/* for (int i = 0; i < 10; i++) {
		PrintToServer("ig_vip----");
	} */
	
	RegConsoleCmd("sm_vip", Command_Vip, "[ImperfectGamers] [vip] Displays the VIP menu to client");
	RegConsoleCmd("sm_vmute", Command_Vmute, "[ImperfectGamers] [vip] Toggle vmute on a player");
	RegAdminCmd("sm_givetitle", Command_GiveTitle, ADMFLAG_ROOT, "[ImperfectGamers] Grants a title to a player");
	RegAdminCmd("sm_removetitle", Command_RemoveTitle, ADMFLAG_ROOT, "[ImperfectGamers] Removes a title from a player");
	RegAdminCmd("sm_listtitles", Command_ListTitles, ADMFLAG_ROOT, "[ImperfectGamers] Lists titles for a player");
	RegAdminCmd("sm_nexttitle", Command_NextTitle, ADMFLAG_ROOT, "[ImperfectGamers] Forced a player to use their next available title");
	RegConsoleCmd("sm_mytitle", Command_PlayerTitle, "[ImperfectGamers] [vip] Displays a menu to the player showing their custom title and allowing them to change their colours");
	RegConsoleCmd("sm_title", Command_PlayerTitle, "[ImperfectGamers] [vip] Displays a menu to the player showing their custom title and allowing them to change their colours");
	RegConsoleCmd("sm_namecolour", Command_SetDbNameColour, "[ImperfectGamers] [vip] VIPs can set their own custom name colour into the db");
	RegConsoleCmd("sm_textcolour", Command_SetDbTextColour, "[ImperfectGamers] [vip] VIPs can set their own custom text colour into the db");
	RegConsoleCmd("sm_ve", Command_VoteExtend, "[ImperfectGamers] [vip] Vote to extend the map");
	RegConsoleCmd("sm_colours", Command_ListColours, "[ImperfectGamers] Lists available colours for sm_mytitle and sm_namecolour");
	
	char szError[255];
	g_hDb = SQL_Connect("surftimer", false, szError, 255);

	if (g_hDb == null)
	{
		SetFailState("[ImperfectGamers VIP] Unable to connect to database (%s)", szError);
		return;
	}

	SQL_SetCharset(g_hDb, "utf8mb4");
}

void VIP_OnClientPutInServer(int client) {
	g_bLoaded[client] = false;
	g_szTitle[client] = "LOADING";
	g_szTitlePlain[client] = "LOADING";
	
	g_bDbCustomTitleInUse[client] = false;
	g_szCustomTitleRaw[client] = "";
	
	g_iCustomColours[client][0] = 0;
	g_iCustomColours[client][1] = 0;
	
	g_bUpdatingColours[client] = false;
	
	db_refreshCustomTitles(client);
}

void db_refreshCustomTitles(int client) {
	char sSteamID[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true)) {
			return;
	}
	
	char szQuery[1024] = "SELECT `title`, `namecolour`, `textcolour` FROM ck_vipadmins WHERE steamid = '%s';";
	
	Format(szQuery, sizeof(szQuery), szQuery, sSteamID);
	
	SQL_TQuery(g_hDb, db_refreshCustomTitlesCb, szQuery, client);
}

void db_refreshCustomTitlesCb(Handle hDriver, Handle hResult, const char[] error, any client) {
	if (hResult == null) {
		LogError("[ImperfectGamers VIP] SQL Error (db_refreshCustomTitlesCb): %s ", error);
		return;
	}

	if (SQL_HasResultSet(hResult) && SQL_FetchRow(hResult)) {
		SQL_FetchString(hResult, 0, g_szCustomTitleRaw[client], sizeof(g_szCustomTitleRaw[]));
		g_iCustomColours[client][0] = SQL_FetchInt(hResult, 1);
		g_iCustomColours[client][1] = SQL_FetchInt(hResult, 2);
	} else {
		g_szCustomTitleRaw[client] = "";
		g_iCustomColours[client][0] = 0;
		g_iCustomColours[client][1] = 0;
	}

	char formatted[32];
	FormatTitle(client, g_szCustomTitleRaw[client], formatted, sizeof(formatted));

	if (!StrEqual(formatted, "")) {
		strcopy(g_szTitle[client], sizeof(g_szTitle[]), formatted);
		strcopy(g_szTitlePlain[client], sizeof(g_szTitlePlain[]), formatted);
		RemoveColorsFromString(g_szTitlePlain[client], sizeof(g_szTitlePlain[]));
		g_bDbCustomTitleInUse[client] = true;
	} else {
		g_szTitle[client] = "";
		g_szTitlePlain[client] = "";
		g_bDbCustomTitleInUse[client] = false;
	}

	if (g_bUpdatingColours[client])
		CustomTitleMenu(client);

	g_bUpdatingColours[client] = false;
	
	g_bLoaded[client] = true;
}

bool IsPlayerLoaded(int client)
{
	return g_bLoaded[client];
}

bool IsPlayerVip(int client, bool admin = true, bool reply = true)
{
	if (admin)
	{
		if (CheckCommandAccess(client, "", ADMFLAG_ROOT))
			return true;
	}

	if (!CheckCommandAccess(client, "", ADMFLAG_CUSTOM1))
	{
		if (reply)
		{
			CPrintToChat(client, "%t", "ig_vip_restricted", g_szChatPrefix);
			PrintToConsole(client, "ImperfectGamers | This is a VIP feature");
		}
		return false;
	}

	return true;
}

void FormatTitle(int client, char[] raw, char[] out, int size) {
		char parts[32][32];
		char colored[32] = "";
		int numParts = ExplodeString(raw, "`", parts, sizeof(parts), sizeof(parts[]));
		if (numParts >= 1) {
				int num = StringToInt(parts[0]);
				if (num == 0) {
						if (StrEqual(parts[0], "vip")) {
								if (IsPlayerVip(client, true, false)) {
										colored = "{green}VIP";
								}
						} else if (StrEqual(parts[0], "admin")) {
								if (CheckCommandAccess(client, "", ADMFLAG_ROOT)) {
										colored = "{red}ADMIN";
								}
						} else if (StrEqual(parts[0], "mod")) {
								if (CheckCommandAccess(client, "", ADMFLAG_KICK)) {
										colored = "{yellow}MOD";
								}
						}
				} else if (num > 0 && num < numParts) {
						strcopy(colored, sizeof(colored), parts[num]);
				}
		}
		FormatTitleSlug(colored, out, size);
}
void FormatTitleSlug(const char[] raw, char[] out, int size) {
		strcopy(out, size, raw);
		char rawNoColor[32];
		strcopy(rawNoColor, sizeof(rawNoColor), raw);
		String_ToLower(rawNoColor, rawNoColor, sizeof(rawNoColor));

		if (StrEqual(rawNoColor, "rapper")) strcopy(out, size, "{yellow}RAPPER");
		if (StrEqual(rawNoColor, "beat")) strcopy(out, size, "{yellow}BEATBOXER");
		if (StrEqual(rawNoColor, "dj")) strcopy(out, size, "{yellow}DJ");
		ReplaceString(out, size, "{red}", "{lightred}", false);
		ReplaceString(out, size, "{limegreen}", "{lime}", false);
		ReplaceString(out, size, "{white}", "{default}", false);
}


public Action Command_Vip(int client, int args)
{
	return Plugin_Handled;
}


public Action Command_GiveTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 2) {
		CReplyToCommand(client, "Usage: <name> <title> - title can be rapper, dj, beat, or something custom (if paid)");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH], szBuffer[MAX_TITLE_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	GetCmdArg(2, szBuffer, sizeof(szBuffer));
	int target = FindTarget(client, targetStr, true, false);
	GiveTitle(client, target, szBuffer);
	return Plugin_Handled;
}
public void GiveTitle(int client, int target, const char[] title) {
		if (target < 0) {
				CReplyToCommand(client, "Target player not found");
				return;
		}
		if (!IsPlayerLoaded(target)) {
				CReplyToCommand(client, "Player not yet loaded");
				return;
		}
		char newTitle[MAX_RAWTITLE_LENGTH];
		if (StrEqual(g_szCustomTitleRaw[target], "")) {
				Format(newTitle, sizeof(newTitle), "0`%s", title);
		} else {
				Format(newTitle, sizeof(newTitle), "%s`%s", g_szCustomTitleRaw[target], title);
		}

		SaveRawTitle(target, newTitle);

		char targetNamed[MAX_NAME_LENGTH];
		GetClientName(target, targetNamed, sizeof(targetNamed));
		char pretty[MAX_TITLE_LENGTH];
		FormatTitleSlug(title, pretty, sizeof(pretty));
		CPrintToChatAll("%s was granted the title: %s", targetNamed, pretty);
}

public Action Command_RemoveTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 2) {
		CReplyToCommand(client, "Usage: <name> <title>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH], szBuffer[MAX_TITLE_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	GetCmdArg(2, szBuffer, sizeof(szBuffer));
	int target = FindTarget(client, targetStr, true, false);
	RemoveTitle(client, target, szBuffer);
	return Plugin_Handled;
}
public void RemoveTitle(int client, int target, const char[] title) {
		if (!IsPlayerLoaded(target)) {
				CReplyToCommand(client, "Player not yet loaded");
				return;
		}
		char newTitle[MAX_RAWTITLE_LENGTH] = "";
		if (!StrEqual(title, "all")) {
				char parts[MAX_TITLES][MAX_TITLE_LENGTH];
				int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
				for (int i = 0; i < numParts; i++) {
						if (i == 0 || !StrEqual(parts[i], title, false)) {
								if (i != 0) {
										StrCat(newTitle, sizeof(newTitle), "`");
								}
								StrCat(newTitle, sizeof(newTitle), parts[i]);
						}
				}
		}
		SaveRawTitle(target, newTitle);

		char targetNamed[MAX_NAME_LENGTH];
		GetClientName(target, targetNamed, sizeof(targetNamed));
		char pretty[MAX_TITLE_LENGTH];
		FormatTitleSlug(title, pretty, sizeof(pretty));
		CPrintToChatAll("%s was stripped of title: %s", targetNamed, pretty);
}

public Action Command_ListTitles(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 1) {
		CReplyToCommand(client, "Usage: <name>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	int target = FindTarget(client, targetStr, true, false);
	ListTitles(client, target);
	return Plugin_Handled;
}
public void ListTitles(int client, int target) {
		if (!IsPlayerLoaded(target)) {
				CReplyToCommand(client, "Player not yet loaded");
				return;
		}
		char parts[MAX_TITLES][MAX_TITLE_LENGTH];
		char out[MAX_RAWTITLE_LENGTH];
		if (client == target) {
				out = "You have these titles: ";
		} else {
				char targetNamed[MAX_NAME_LENGTH];
				GetClientName(target, targetNamed, sizeof(targetNamed));
				Format(out, sizeof(out), "%s has these titles: ", targetNamed);
		}
		int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
		for (int i = 1; i < numParts; i++) {
				StrCat(out, sizeof(out), parts[i]);
				if (i != numParts-1) {
						StrCat(out, sizeof(out), ", ");
				}
		}
		PrintToChat(client, out);
}

public Action Command_NextTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 1) {
		CReplyToCommand(client, "Usage: <name>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	int target = FindTarget(client, targetStr, true, false);
	NextTitle(client, target);
	return Plugin_Handled;
}
public void NextTitle(int client, int target) {
		if (!IsPlayerLoaded(target)) {
				CReplyToCommand(client, "Player not yet loaded");
				return;
		}

		char parts[MAX_TITLES][MAX_TITLE_LENGTH];
		char newStr[MAX_RAWTITLE_LENGTH];
		int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
		if (numParts >= 1) {
				for (int attempt = 0; attempt < 10; attempt++) {
						if (StrEqual(parts[0], "vip")) parts[0] = "mod";
						else if (StrEqual(parts[0], "mod")) parts[0] = "admin";
						else if (StrEqual(parts[0], "admin")) parts[0] = "0";
						else {
								int num = StringToInt(parts[0]);
								num++;
								if (num >= numParts) {
										parts[0] = "vip";
								} else {
										Format(parts[0], sizeof(parts[]), "%d", num);
								}
						}
						ImplodeStrings(parts, numParts, "`", newStr, sizeof(newStr));
						char formatted[MAX_TITLE_LENGTH];
						FormatTitle(target, newStr, formatted, sizeof(formatted));
						if (StrEqual(parts[0], "0")) {
								formatted = "<default>";
						}
						if (!StrEqual(formatted, "")) {
								SaveRawTitle(target, newStr);
								char out[1024];
								if (client == target) {
										Format(out, sizeof(out), "You have changed your title to %s", formatted);
								} else {
										char targetNamed[MAX_NAME_LENGTH];
										GetClientName(target, targetNamed, sizeof(targetNamed));
										Format(out, sizeof(out), "You have changed the title of %s to %s", targetNamed, formatted);
								}
								CPrintToChat(client, out);
								return;
						}
				}
		}
}

public void SaveRawTitle(int client, char[] raw) {
	char rawEx[MAX_RAWTITLE_LENGTH*2+1];
	SQL_EscapeString(g_hDb, raw, rawEx, sizeof(rawEx));
	
	char sSteamID[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true)) {
			return;
	}

	char szQuery[MAX_RAWTITLE_LENGTH*4+100];
	Format(szQuery, sizeof(szQuery), " \
			INSERT INTO ck_vipadmins \
			SET steamid='%s', title='%s' \
			ON DUPLICATE KEY UPDATE title='%s' \
		", sSteamID, rawEx, rawEx);
	SQL_TQuery(g_hDb, SaveRawTitle2, szQuery, client);
}
public void SaveRawTitle2(Handle hDriver, Handle hResult, const char[] error, any client) {
	PrintToServer("Successfully updated custom title.");
	db_refreshCustomTitles(client);
}

public Action Command_Vmute(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerVip(client))
		return Plugin_Handled;

	if (args < 1)
	{
		CReplyToCommand(client, "Usage: <name> - mutes / unmutes the given player (30 minutes)");
		return Plugin_Handled;
	}

	char clientName[MAX_NAME_LENGTH];
	GetClientName(client, clientName, sizeof(clientName));
	char reason[128];
	Format(reason, sizeof(reason), "vmute by %s", clientName);

	char target[128];
	GetCmdArg(1, target, sizeof(target));

	int targetId = FindTarget(client, target, true, false);
	if (targetId < 0) {
			CReplyToCommand(client, "Target player not found");
			return Plugin_Handled;
	}

	char targetNamed[128];
	GetClientName(targetId, targetNamed, sizeof(targetNamed));

	bType isMuted = SourceComms_GetClientMuteType(targetId);
	if (isMuted == bNot) {
			SourceComms_SetClientMute(targetId, true, 30, true, reason);
			CPrintToChatAll("VIP %s muted %s for 30 minutes", clientName, targetNamed);
	} else if (isMuted == bPerm) {
			CReplyToCommand(client, "Cannot unmute a permanately muted player using vmute.");
	} else {
			SourceComms_SetClientMute(targetId, false, -1, false, reason);
			CPrintToChatAll("VIP %s unmuted %s temporarily", clientName, targetNamed);
	}

	return Plugin_Handled;
}

public Action Command_SetDbNameColour(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerVip(client))
		return Plugin_Handled;

	char arg[128], authSteamId[MAXPLAYERS + 1];
	GetClientAuthId(client, AuthId_Steam2, authSteamId, MAX_NAME_LENGTH, true);

	if (args == 0)
	{
			ReplyToCommand(client, "Usage: sm_namecolour {colour}");
	}
	else
	{
		GetCmdArg(1, arg, 128);
		char upperArg[128];
		upperArg = arg;
		StringToUpper(upperArg);
		if (StrContains(upperArg, "{DEFAULT}", false)!=-1 || StrContains(upperArg, "{WHITE}")!=-1)
		{
			arg = "0";
		}
		else if (StrContains(upperArg, "{DARKRED}", false)!=-1)
		{
			arg = "1";
		}
		else if (StrContains(upperArg, "{GREEN}", false)!=-1)
		{
			arg = "2";
		}
		else if (StrContains(upperArg, "{LIMEGREEN}", false)!=-1 || StrContains(upperArg, "{LIME}")!=-1)
		{
			arg = "3";
		}
		else if (StrContains(upperArg, "{BLUE}", false)!=-1)
		{
			arg = "4";
		}
		else if (StrContains(upperArg, "{LIGHTGREEN}", false)!=-1)
		{
			arg = "5";
		}
		else if (StrContains(upperArg, "{RED}", false)!=-1)
		{
			arg = "6";
		}
		else if (StrContains(upperArg, "{GREY}", false)!=-1 || StrContains(upperArg, "{GRAY}")!=-1)
		{
			arg = "7";
		}
		else if (StrContains(upperArg, "{YELLOW}", false)!=-1)
		{
			arg = "8";
		}
		else if (StrContains(upperArg, "{LIGHTBLUE}", false)!=-1)
		{
			arg = "9";
		}
		else if (StrContains(upperArg, "{DARKBLUE}", false)!=-1)
		{
			arg = "10";
		}
		else if (StrContains(upperArg, "{PINK}", false)!=-1)
		{
			arg = "11";
		}
		else if (StrContains(upperArg, "{LIGHTRED}", false)!=-1)
		{
			arg = "12";
		}
		else if (StrContains(upperArg, "{PURPLE}", false)!=-1)
		{
			arg = "13";
		}
		else if (StrContains(upperArg, "{DARKGREY}", false)!=-1 || StrContains(upperArg, "{DARKGRAY}")!=-1)
		{
			arg = "14";
		}
		else if (StrContains(upperArg, "{ORANGE}", false)!=-1)
		{
			arg = "15";
		}
		else
		{
			arg = "0";
		}

		db_checkCustomPlayerNameColour(client, authSteamId, arg);
	}

	return Plugin_Handled;
}

public Action Command_SetDbTextColour(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerVip(client))
		return Plugin_Handled;

	char arg[128], authSteamId[MAXPLAYERS + 1];
	GetClientAuthId(client, AuthId_Steam2, authSteamId, MAX_NAME_LENGTH, true);

	if (args == 0)
	{
		CPrintToChat(client, "%t", "ig_command_usage_textcolour", g_szChatPrefix);
	}
	else
	{
		GetCmdArg(1, arg, 128);
		char upperArg[128];
		upperArg = arg;
		StringToUpper(upperArg);
		if (StrContains(upperArg, "{DEFAULT}", false)!=-1 || StrContains(upperArg, "{WHITE}")!=-1)
		{
			arg = "0";
		}
		else if (StrContains(upperArg, "{DARKRED}", false)!=-1)
		{
			arg = "1";
		}
		else if (StrContains(upperArg, "{GREEN}", false)!=-1)
		{
			arg = "2";
		}
		else if (StrContains(upperArg, "{LIMEGREEN}", false)!=-1 || StrContains(upperArg, "{LIME}", false)!=-1)
		{
			arg = "3";
		}
		else if (StrContains(upperArg, "{BLUE}", false)!=-1)
		{
			arg = "4";
		}
		else if (StrContains(upperArg, "{LIGHTGREEN}", false)!=-1 || StrContains(upperArg, "{OLIVE}", false)!=-1)
		{
			arg = "5";
		}
		else if (StrContains(upperArg, "{RED}", false)!=-1)
		{
			arg = "6";
		}
		else if (StrContains(upperArg, "{GREY}", false)!=-1 || StrContains(upperArg, "{GRAY}")!=-1)
		{
			arg = "7";
		}
		else if (StrContains(upperArg, "{YELLOW}", false)!=-1)
		{
			arg = "8";
		}
		else if (StrContains(upperArg, "{LIGHTBLUE}", false)!=-1)
		{
			arg = "9";
		}
		else if (StrContains(upperArg, "{DARKBLUE}", false)!=-1)
		{
			arg = "10";
		}
		else if (StrContains(upperArg, "{PINK}", false)!=-1)
		{
			arg = "11";
		}
		else if (StrContains(upperArg, "{LIGHTRED}", false)!=-1)
		{
			arg = "12";
		}
		else if (StrContains(upperArg, "{PURPLE}", false)!=-1)
		{
			arg = "13";
		}
		else if (StrContains(upperArg, "{DARKGREY}", false)!=-1 || StrContains(upperArg, "{DARKGRAY}")!=-1)
		{
			arg = "14";
		}
		else if (StrContains(upperArg, "{ORANGE}", false)!=-1)
		{
			arg = "15";
		}
		else
		{
			arg = "0";
		}

		db_checkCustomPlayerTextColour(client, authSteamId, arg);
	}

	return Plugin_Handled;
}

public Action Command_ListColours(int client, int args)
{
	CPrintToChat(client, "%t", "Commands44", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Command_PlayerTitle(int client, int args)
{
	if (IsValidClient(client))
		CustomTitleMenu(client);
	return Plugin_Handled;
}

public Action Command_VoteExtend(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerVip(client))
		return Plugin_Handled;

	VoteExtend(client);
	return Plugin_Handled;
}

public void VoteExtend(int client)
{
	int timeleft;
	GetMapTimeLeft(timeleft);

	if (timeleft > 300)
	{
		CPrintToChat(client, "%t", "ig_vip_extend_early", g_szChatPrefix);
		return;
	}

	if (IsVoteInProgress())
	{
		CPrintToChat(client, "%t", "ig_vip_extend_in_vote", g_szChatPrefix);
		return;
	}

	char szPlayerName[MAX_NAME_LENGTH];
	GetClientName(client, szPlayerName, MAX_NAME_LENGTH);

	Menu hMenu = CreateMenu(Handle_VoteMenuExtend);
	SetMenuTitle(hMenu, "Extend the map by 10 minutes?");
	AddMenuItem(hMenu, "###yes###", "Yes");
	AddMenuItem(hMenu, "###no###", "No");
	SetMenuExitButton(hMenu, false);
	VoteMenuToAll(hMenu, 20);
	CPrintToChatAll("%t", "ig_vip_extend_vote_initiated", g_szChatPrefix, szPlayerName);

	return;
}

public int Handle_VoteMenuExtend(Menu hMenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		/* This is called after VoteEnd */
		CloseHandle(hMenu);
	} else if (action == MenuAction_VoteEnd) {
		char item[64], display[64];
		float percent, limit;
		int votes, totalVotes;

		hMenu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));
		GetMenuVoteInfo(param2, votes, totalVotes);

		if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
		votes = totalVotes - votes;

		percent = float(votes) / float(totalVotes);

		/* 0=yes, 1=no */
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1)) {
			CPrintToChatAll("%t", "ig_vote_failed", g_szChatPrefix, RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
		} else {
			CPrintToChatAll("%t", "ig_vote_successful", g_szChatPrefix, RoundToNearest(100.0*percent), totalVotes);
			CPrintToChatAll("%t", "ig_vip_extend_result", g_szChatPrefix);
			ExtendMapTimeLimit(600);
		}
	}
}

public void CustomTitleMenu(int client)
{
	char szName[64], szSteamID[32], szColour[3][96], szTitle[256], szItem[128], szItem2[128];

	GetClientName(client, szName, 64);
	GetClientAuthId(client, AuthId_Steam2, szSteamID, sizeof(szSteamID));
	getColourName(client, szColour[0], 32, g_iCustomColours[client][0]);
	getColourName(client, szColour[1], 32, g_iCustomColours[client][1]);

	Format(szTitle, 256, "Custom Titles Menu: %s\nCustom Title: %s\n \n", szName, g_szTitlePlain[client]);
	Format(szItem, 128, "Name Colour [VIP]: %s", szColour[0]);
	Format(szItem2, 128, "Text Colour [VIP]: %s", szColour[1]);

	Menu hMenu = CreateMenu(CustomTitleMenuHandler);
	SetMenuTitle(hMenu, szTitle);

	AddMenuItem(hMenu, "name", szItem);
	AddMenuItem(hMenu, "text", szItem2);
	AddMenuItem(hMenu, "next", "Change Title");

	SetMenuOptionFlags(hMenu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int CustomTitleMenuHandler(Handle hMenu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
			int client = param1;
			char info[32];
			GetMenuItem(hMenu, param2, info, sizeof(info));
			if (StrEqual(info, "name")) {
				if (!IsPlayerVip(client)) return;
				ChangeColorsMenu(client, 0);
			} else if (StrEqual(info, "text")) {
				if (!IsPlayerVip(client)) return;
				ChangeColorsMenu(client, 1);
			} else if (StrEqual(info, "next")) {
				g_bUpdatingColours[client] = true;
				NextTitle(client, client);
			}
	}
	else if (action == MenuAction_End)
	CloseHandle(hMenu);
}

public void ChangeColorsMenu(int client, int type) {
		char szColour[32];
		getColourName(client, szColour, 32, g_iCustomColours[client][type]);

		// change title hMenu
		char szTitle[1024];
		char szType[32];
		switch (type)
		{
				case 0:
				{
						Format(szTitle, 1024, "Changing Name Colour (Current: %s):\n \n", szColour);
						Format(szType, 32, "name");
				}
				case 1:
				{
						Format(szTitle, 1024, "Changing Text Colour (Current: %s):\n \n", szColour);
						Format(szType, 32, "text");
				}
		}

		Menu changeColoursMenu = new Menu(changeColoursMenuHandler);

		changeColoursMenu.SetTitle(szTitle);

		changeColoursMenu.AddItem(szType, "White");
		changeColoursMenu.AddItem(szType, "Dark Red");
		changeColoursMenu.AddItem(szType, "Green");
		changeColoursMenu.AddItem(szType, "Lime Green");
		changeColoursMenu.AddItem(szType, "Blue");
		changeColoursMenu.AddItem(szType, "Moss Green");
		changeColoursMenu.AddItem(szType, "Red");
		changeColoursMenu.AddItem(szType, "Grey");
		changeColoursMenu.AddItem(szType, "Yellow");
		changeColoursMenu.AddItem(szType, "Light Blue");
		changeColoursMenu.AddItem(szType, "Dark Blue");
		changeColoursMenu.AddItem(szType, "Pink");
		changeColoursMenu.AddItem(szType, "Light Red");
		changeColoursMenu.AddItem(szType, "Purple");
		changeColoursMenu.AddItem(szType, "Dark Grey");
		changeColoursMenu.AddItem(szType, "Orange");

		changeColoursMenu.ExitButton = true;
		changeColoursMenu.Display(client, MENU_TIME_FOREVER);
}

public int changeColoursMenuHandler(Handle hMenu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char szType[32];
		int type;
		GetMenuItem(hMenu, item, szType, sizeof(szType));
		if (StrEqual(szType, "name"))
			type = 0;
		else if (StrEqual(szType, "text"))
			type = 1;
			
		char sSteamID[32];
		if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true)) {
				return;
		}

		switch (item)
		{
			case 0:db_updateColours(client, sSteamID, 0, type);
			case 1:db_updateColours(client, sSteamID, 1, type);
			case 2:db_updateColours(client, sSteamID, 2, type);
			case 3:db_updateColours(client, sSteamID, 3, type);
			case 4:db_updateColours(client, sSteamID, 4, type);
			case 5:db_updateColours(client, sSteamID, 5, type);
			case 6:db_updateColours(client, sSteamID, 6, type);
			case 7:db_updateColours(client, sSteamID, 7, type);
			case 8:db_updateColours(client, sSteamID, 8, type);
			case 9:db_updateColours(client, sSteamID, 9, type);
			case 10:db_updateColours(client, sSteamID, 10, type);
			case 11:db_updateColours(client, sSteamID, 11, type);
			case 12:db_updateColours(client, sSteamID, 12, type);
			case 13:db_updateColours(client, sSteamID, 13, type);
			case 14:db_updateColours(client, sSteamID, 14, type);
			case 15:db_updateColours(client, sSteamID, 15, type);
		}
	}
	else
	if (action == MenuAction_Cancel)
	{
		CustomTitleMenu(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(hMenu);
	}
}

public void StringToUpper(char[] input)
{
	for (int i = 0; ; i++)
	{
		if (input[i] == '\0')
			return;
		input[i] = CharToUpper(input[i]);
	}
}

public void db_checkCustomPlayerNameColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);
	WritePackString(pack, arg);

	char szQuery[512];
	Format(szQuery, 512, "SELECT `steamid` FROM `ck_vipadmins` WHERE `steamid` = '%s';", szSteamID);
	SQL_TQuery(g_hDb, SQL_checkCustomPlayerNameColourCallback, szQuery, pack);

}

public void SQL_checkCustomPlayerNameColourCallback(Handle owner, Handle hndl, const char[] error, any pack)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[ImperfectGamers] SQL Error (SQL_checkCustomPlayerTitleCallback): %s", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	char arg[128];
	ReadPackString(pack, szSteamID, 32);
	ReadPackString(pack, arg, 128);
	CloseHandle(pack);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		db_updateCustomPlayerNameColour(client, szSteamID, arg);
	}
	else
	{
		CPrintToChat(client, "%t", "ig_vip_title_warning_name_colour", g_szChatPrefix);
	}
}

public void db_checkCustomPlayerTextColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);
	WritePackString(pack, arg);

	char szQuery[512];
	Format(szQuery, 512, "SELECT `steamid` FROM `ck_vipadmins` WHERE `steamid` = '%s';", szSteamID);
	SQL_TQuery(g_hDb, SQL_checkCustomPlayerTextColourCallback, szQuery, pack);

}

public void SQL_checkCustomPlayerTextColourCallback(Handle owner, Handle hndl, const char[] error, any pack)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[ImperfectGamers] SQL Error (SQL_checkCustomPlayerTextColourCallback): %s", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	char arg[128];
	ReadPackString(pack, szSteamID, 32);
	ReadPackString(pack, arg, 128);
	CloseHandle(pack);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		db_updateCustomPlayerTextColour(client, szSteamID, arg);
	}
	else
	{
		CPrintToChat(client, "%t", "ig_vip_title_warning_text_colour", g_szChatPrefix);
	}
}

public void db_updateCustomPlayerNameColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);

	char szQuery[512];
	Format(szQuery, 512, "UPDATE `ck_vipadmins` SET `namecolour` = '%s' WHERE `steamid` = '%s';", arg, szSteamID);
	SQL_TQuery(g_hDb, SQL_updateCustomPlayerNameColourCallback, szQuery, pack);
}

public void SQL_updateCustomPlayerNameColourCallback(Handle owner, Handle hndl, const char[] error, any pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	ReadPackString(pack, szSteamID, 32);
	CloseHandle(pack);

	PrintToServer("Successfully updated custom player colour");
	db_refreshCustomTitles(client);
}

public void db_updateCustomPlayerTextColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);

	char szQuery[512];
	Format(szQuery, 512, "UPDATE `ck_vipadmins` SET `textcolour` = '%s' WHERE `steamid` = '%s';", arg, szSteamID);
	SQL_TQuery(g_hDb, SQL_updateCustomPlayerTextColourCallback, szQuery, pack);
}

public void SQL_updateCustomPlayerTextColourCallback(Handle owner, Handle hndl, const char[] error, any pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	ReadPackString(pack, szSteamID, 32);
	CloseHandle(pack);

	PrintToServer("Successfully updated custom player text colour");
	db_refreshCustomTitles(client);
}

public void db_updateColours(int client, char szSteamId[32], int newColour, int type)
{
	char szQuery[512];
	switch (type)
	{
		case 0: Format(szQuery, 512, "UPDATE ck_vipadmins SET namecolour = %i WHERE steamid = '%s';", newColour, szSteamId);
		case 1: Format(szQuery, 512, "UPDATE ck_vipadmins SET textcolour = %i WHERE steamid = '%s';", newColour, szSteamId);
	}

	SQL_TQuery(g_hDb, SQL_UpdatePlayerColoursCallback, szQuery, client);
}

public void SQL_UpdatePlayerColoursCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[ImperfectGamers] SQL Error (SQL_UpdatePlayerColoursCallback): %s", error);
		return;
	}

	g_bUpdatingColours[client] = true;
	db_refreshCustomTitles(client);
}

public void getColourName(int client, char[] buffer, int length, int colour)
{
	switch (colour)
	{
		case 0: Format(buffer, length, "White");
		case 1: Format(buffer, length, "Dark Red");
		case 2: Format(buffer, length, "Green");
		case 3: Format(buffer, length, "Limegreen");
		case 4: Format(buffer, length, "Blue");
		case 5: Format(buffer, length, "Lightgreen");
		case 6: Format(buffer, length, "Red");
		case 7: Format(buffer, length, "Grey");
		case 8: Format(buffer, length, "Yellow");
		case 9: Format(buffer, length, "Lightblue");
		case 10: Format(buffer, length, "Darkblue");
		case 11: Format(buffer, length, "Pink");
		case 12: Format(buffer, length, "Light Red");
		case 13: Format(buffer, length, "Purple");
		case 14: Format(buffer, length, "Dark Grey");
		case 15: Format(buffer, length, "Orange");
	}

	return;
}
