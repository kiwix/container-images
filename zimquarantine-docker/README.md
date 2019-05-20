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

- The ZIMs dir to check : `-v <YOUR_ZIM_DIRECTORY_TO_CHECK>:/zim_to_check`
- The valids ZIMs dir : `-v <YOUR_ZIM_DIRECTORY>:/zim`
- The quarantine dir : `-v <YOUR_ZIM_QUARANTINE_DIRECTORY>:/zim_quarantine`
- The log dir : `-v <YOUR_LOG_DIRECTORY>:/zim_log`

Options
-------

You can pass options to `zimcheck` by define `ZIMCHECK_OPTION` env var : `-e ZIMCHECK_OPTION=-A` The options are the same as `zimcheck` :

```
-A , --all             run all tests. Default if no flags are given.
-C , --checksum        Internal CheckSum Test
-M , --metadata        MetaData Entries
-F , --favicon         Favicon
-P , --main            Main page
-R , --redundant       Redundant data check
-U , --url_internal    URL check - Internal URLs
-X , --url_external    URL check - Internal URLs
-E , --mime            MIME checks
-D , --details         Details of error
-B , --progress        Print progress report
```


Author
------

Florent Kaisser <florent.pro@kaisser.name>
