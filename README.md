logstash-symlink-index
======================

A simple shell script that copies and symlinks a Logstash/elasticsearch index
across different filesystems.

Why?
----
This script comes in handy when your Logstash/elasticsearch host has both a
solid-state drive and a spinning (e.g. classical) hard drive. While the SSDs are
superfast compared to the spinning drives, they do not hold as much data. So,
wouldn't it be nice if elasticsearch could:

* build the current daily Logstash index on the SSD,
* serve the daily index from the SSD as this index will probably see much
usage,
* serve some more recent indices from the SSD, too (space permitting),
* serve many older indices from that big fat hard drive.

How?
----
Ultimately, all it takes to do this is a rsync(1), an ln(1) and a restart of the
elasticsearch process (to release the filehandles). If you choose to automate,
this better be wrapped up in nice scripts. So, here it is for your convenience.

logstash-list-indices
=====================

Another shell script. By default, it lists all available Logstash indices. Some
criteria can be added, so that you can list indices that are (for example) older
than a week.

Why?
----
This script is the companion to logstash-symlink-index. By combining them in a 
shell oneliner (or a cronjob) you can do wonderful things.

# vim: set ts=4 sw=4 et cc=80 tw=80:
