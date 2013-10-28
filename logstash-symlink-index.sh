#!/bin/sh

DRY_RUN=""
DST_DIR="/export/logstash-indices"
IDX_NAME="$1"
SRC_DIR="/var/lib/elasticsearch/logstash/nodes/0/indices"

log() {
  echo "$*"
}

log_stderr() {
  echo "$*" >&2
}

log_warning() {
  echo "Warning: $*" >&2
}

log_error() {
  echo "ERROR: $*" >&2
}

die() {
  log_error "$*"
  exit 1
}

run() {
  [ -z "$*" ] && {
    log_warning "Nothing to execute."
    return 0
  }

  local command="$*"
  if [ -n "$DRY_RUN" ] ; then
    echo "Would run '$command', however the DRY_RUN flag is set. Doing nothing."
    return 0
  else
    eval $command
    return $?
  fi
}

# Do some sanity checks about the paths
[ -z "$IDX_NAME" ] && {
  log_stderr "Usage: $0 <index_name>"
  die "Index name not given, aborting."
}
[ ! -r "$SRC_DIR" ] && die "Source directory '$SRC_DIR' is not readable, aborting."
[ ! -w "$DST_DIR" ] && die "Destination '$DST_DIR' is not writable, aborting."
[ ! -d "$DST_DIR" ] && die "Destination '$DST_DIR' is not a directory, aborting."

# Do some sanity checks about the index
SRC_IDX_PATH="$SRC_DIR/$IDX_NAME"
[ ! -r "$SRC_IDX_PATH" ] && die "Source index path '$SRC_IDX_PATH' is not readable, aborting."
[ ! -d "$SRC_IDX_PATH" ] && die "Source index path '$SRC_IDX_PATH' is not a directory. This is unusual, aborting."
[ -L "$SRC_IDX_PATH" ] && die "Source index path '$SRC_IDX_PATH' is a symlink. This is unusual, aborting."

# rsync source index to the destination
run "rsync -a $SRC_IDX_PATH $DST_DIR" || die "Oops, something went wrong."

# Remove the source index
run "rm -r $SRC_IDX_PATH" || die "Oops, something went wrong."

# Create the symlink in place of the source index
DST_IDX_PATH="$DST_DIR/$IDX_NAME"
run "ln -s $DST_IDX_PATH $SRC_DIR" || die "Oops, something went wrong."

# exit with no errors
exit 0

# vim: set ts=2 sw=2 et cc=80:
