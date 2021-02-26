#if defined _CNST_INCLUDED
  #endinput
#endif
#define _CNST_INCLUDED


/**
 * Check if a player connected from Steam China
 *
 * @param client     Client to check.
 * @return         True when a player connect from Steam China, otherwise false.
 */
native bool CNST_CheckPlayer(client);