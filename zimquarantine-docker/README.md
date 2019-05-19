ZIM Quarantine Docker
=====================

ZIM Quarantine Docker allow to monitor a directory containing zim files to check.

Each minute, `zimcheck` is running on all zim files found in a zim directory and 
it sub-directories (recursively search).

If a zim is valid, it moved to the directory of valid zim.

If a zim is invalid, it moved to a quarantine directory. Yon can read the output 
of `zimcheck` in log writed in log directory.

Volumes
-------

You should define several volumes when you run the container :

- The zim dir to check : `-v <YOUR_ZIM_DIRECTORY_TO_CHECK>:/zim_to_check`
- The validate zim dir : `-v <YOUR_ZIM_DIRECTORY>:/zim`
- The quarantine dir : `-v <YOUR_ZIM_QUARANTINE_DIRECTORY>:/zim_quarantine`
- The log dir : `-v <YOUR_LOG_DIRECTORY>:/zim_log`

Author
------

Florent Kaisser <florent.pro@kaisser.name>
