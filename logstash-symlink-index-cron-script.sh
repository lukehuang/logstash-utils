#!/bin/sh

CONF_ES_USER="elasticsearch"

log_stderr() {
  echo "$*" >&2
}

die() {
  log_stderr "$*"
  exit 1
}

# Stop logstash-indexer and elasticsearch
service logstash-indexer stop || die "Could not stop logstash-indexer, aborting."
service elasticsearch stop || {
  log_stderr "Stopped logstash-indexer successfully but cannot stop elasticsearch. Starting logstash-indexer again."
  service logstash-indexer start || die "Could not start logstash-indexer, giving up."
}

# Do the work. Parameters are in the config files.
sudo -u${CONF_ES_USER} logstash-symlink-index -c/etc/logstash-symlink-index.conf --do-it $(sudo -u${CONF_ES_USER} logstash-list-indices -c/etc/logstash-list-indices.conf) 

# Start elasticsearch first, then logstash-indexer
service elasticsearch start || {
  die "Could not start elasticsearch, giving up."
}
service logstash-indexer start || {
  die "Could not start logstash-indexer, giving up."
}

# All is well...
exit 0

# vim: set ts=2 sw=2 et cc=80:
