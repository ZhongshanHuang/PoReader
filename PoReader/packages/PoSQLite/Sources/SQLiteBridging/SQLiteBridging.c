//
//  SQLite_Bridging.c
//  

#include "SQLiteBridging.h"

/// Enable multi-threaded mode.  In this mode, SQLite is safe to use by multiple
/// threads as long as no two threads use the same database connection at the same
/// time (which we guarantee in the SQLite database wrappers).
int sqlite3_config_multithread(void)
{
    return sqlite3_config(SQLITE_CONFIG_MULTITHREAD);
}

int sqlite3_config_memstatus(int a)
{
    return sqlite3_config(SQLITE_CONFIG_MEMSTATUS, a);
}

int sqlite3_config_log(sqlite3_global_log a, void *b)
{
    return sqlite3_config(SQLITE_CONFIG_LOG, a, b);
}
