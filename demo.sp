#include <CNST>

public void OnClientConnected(int client)
{
	if(CNST_CheckPlayer(client))
		PrintToServer("yes");
}