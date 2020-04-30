#include <discord>

ConVar g_hReportBugsDiscord = null;
ConVar g_hCalladminDiscord = null;




int g_iWaitingForResponse[MAXPLAYERS + 1];

char g_sBugType[MAXPLAYERS + 1][32];

void Reports_OnPluginStart() {
	g_hCalladminDiscord = CreateConVar("ig_reports_webhook_calladmin", "", "Web hook link to allow players to call admin to discord, keep empty to disable");
	g_hReportBugsDiscord = CreateConVar("ig_reports_webhook_bugs", "", "Web hook link to report bugs to discord, keep empty to disable");



	/* AddCommandListener(Say_Hook, "say");
	AddCommandListener(Say_Hook, "say_team"); */

	RegConsoleCmd("sm_bug", Command_Bug, "[surftimer] report a bug to our discord");
	RegConsoleCmd("sm_calladmin", Command_Calladmin, "[surftimer] sends a message to the staff");
}

void Reports_OnMapStart() {
	//
}

void Reports_OnClientPutInServer(int client) {
	g_iWaitingForResponse[client] = -1;
}

public void SendBugReport(int client, char[] sText)
{
	char webhook[1024];
	GetConVarString(g_hReportBugsDiscord, webhook, 1024);
	if (StrEqual(webhook, ""))
		return;

	// Send Discord Announcement
	DiscordWebHook hook = new DiscordWebHook(webhook);
	hook.SlackMode = true;

	hook.SetUsername("ImperfectGamers Bugtracker");

	MessageEmbed Embed = new MessageEmbed();

	char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));

	// Format Title
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "Bug Type: %s | Server: %s | Map: %s", g_sBugType[client], g_sServerName, sMapName);
	Embed.SetTitle(sTitle);

	// Format Player
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	char sSteamID[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true)) {
			sSteamID= "";
	}

	// Format msg
	char sMessage[512];
	Format(sMessage, sizeof(sMessage), "%s (%s): %s", sName, sSteamID, sText);
	Embed.AddField("", sMessage, true);

	hook.Embed(Embed);
	hook.Send();
	delete hook;

	CPrintToChat(client, "%t", "ig_reports_sent_bug", g_szChatPrefix);
}

public void CallAdmin(int client, char[] sText)
{
	char webhook[1024];
	GetConVarString(g_hCalladminDiscord, webhook, 1024);
	if (StrEqual(webhook, ""))
		return;

	// Send Discord Announcement
	DiscordWebHook hook = new DiscordWebHook(webhook);
	hook.SlackMode = true;

	hook.SetUsername("ImperfectGamers Calladmin");

	MessageEmbed Embed = new MessageEmbed();
	
	char sMapName[128];
	GetCurrentMap(sMapName, sizeof(sMapName));

	// Format title
	char sTitle[256];
	Format(sTitle, sizeof(sTitle), "Server: %s | Map: %s", g_sServerName, sMapName);
	Embed.SetTitle(sTitle);

	// Format player
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));
	
	char sSteamID[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID), true)) {
			sSteamID= "";
	}

	// Format msg
	char sMessage[512];
	Format(sMessage, sizeof(sMessage), "%s (%s): %s", sName, sSteamID, sText);
	Embed.AddField("", sMessage, true);

	hook.Embed(Embed);
	hook.Send();
	delete hook;

	CPrintToChat(client, "%t", "ig_reports_sent_calladmin", g_szChatPrefix);
}

public Action Command_Bug(int client, int args)
{
	ReportBugMenu(client);
	return Plugin_Handled;
}

public void ReportBugMenu(int client)
{
	Menu menu = CreateMenu(ReportBugHandler);
	SetMenuTitle(menu, "Choose a bug type");
	AddMenuItem(menu, "Map Bug", "Map Bug");
	AddMenuItem(menu, "Timer Bug", "Timer Bug");
	AddMenuItem(menu, "Server Bug", "Server Bug");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ReportBugHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, g_sBugType[param1], 32);
		g_iWaitingForResponse[param1] = 1;
		CPrintToChat(param1, "%t", "ig_reports_prompt", g_szChatPrefix);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
}

public Action Command_Calladmin(int client, int args)
{
	g_iWaitingForResponse[client] = 2;
	CPrintToChat(client, "%t", "ig_reports_prompt", g_szChatPrefix);
	return Plugin_Handled;
}
