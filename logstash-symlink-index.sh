#!/bin/sh

# The default configuration
CONF_DEBUG=""
CONF_DEST_DIR=""
CONF_DRY_RUN=""
CONF_FILE=""
CONF_HELP=""
CONF_INDEX_NAMES=""
CONF_SOURCE_DIR=""

log() {
  echo "$*"
}

log_stderr() {
  echo "$*" >&2
}

log_warning() {
  log_stderr "[Warning] $*"
}

log_error() {
  log_stderr "[ERROR]   $*"
}

log_debug() {
  [ -n "$CONF_DEBUG" ] && log_stderr "[debug]   $*"
}

die() {
  log_stderr "$*"
  exit 1
}

# Run the specified command (or not, depending on CONF_DRY_RUN).
run() {
  [ -z "$*" ] && {
    log_warning "Nothing to execute."
    return 0
  }

  local command="$*"
  if [ -n "$CONF_DRY_RUN" ] ; then
    echo "Would run '$command', however the CONF_DRY_RUN flag is set. Doing nothing."
    return 0
  else
    eval $command
    return $?
  fi
}

check_CONF_DEBUG() {
  log_debug "Running in debug mode."
  echo 0
  return 0
}

check_CONF_DRY_RUN() {
  [ -n "$CONF_DRY_RUN" ] && {
    log_warning "Running with CONF_DRY_RUN enabled. Not doing anything, just reporting what would be done."
  }
  echo 0
  return 0
}

check_CONF_DEST_DIR() {
  local errors=0
  if [ -z "$CONF_DEST_DIR" ]; then
    log_error "No destination directory given."
    errors=$(( $errors + 1 ))
  elif [ ! -e "$CONF_DEST_DIR" ]; then
    log_error "Destination '$CONF_DEST_DIR' does not exist."
    errors=$(( $errors + 1 ))
  elif [ ! -w "$CONF_DEST_DIR" ]; then
    log_error "Destination '$CONF_DEST_DIR' is not writable."
    errors=$(( $errors + 1 ))
  elif [ ! -d "$CONF_DEST_DIR" ]; then
    log_error "Destination '$CONF_DEST_DIR' is not a directory, aborting."
    errors=$(( $errors + 1 ))
  fi
  echo $errors
  return $errors
}

check_CONF_INDEX_NAMES() {
  local errors=0
  [ -z "$CONF_INDEX_NAMES" ] && {
    log_error "No index name given."
    errors=$(( $errors + 1 ))
  }
  echo $errors
  return $errors
}

check_CONF_SOURCE_DIR() {
  local errors=0
  if [ -z "$CONF_SOURCE_DIR" ]; then
    log_error "No source directory given."
    errors=$(( $errors + 1 ))
  elif [ ! -e "$CONF_SOURCE_DIR" ]; then
    log_error "Source directory '$CONF_SOURCE_DIR' does not exist."
    errors=$(( $errors + 1 ))
  elif [ ! -d "$CONF_SOURCE_DIR" ]; then
    log_error "Source directory '$CONF_SOURCE_DIR' is not a directory."
    errors=$(( $errors + 1 ))
  elif [ ! -r "$CONF_SOURCE_DIR" ]; then
    log_error "Source directory '$CONF_SOURCE_DIR' is not readable."
    errors=$(( $errors + 1 ))
  fi
  echo $errors
  return $errors
}

#check_CONF_SOURCE_PATH() {
  #local errors=0
  #if [ ! -e "$CONF_SOURCE_PATH" ]; then
    #log_error "Source index path '$CONF_SOURCE_PATH' does not exist."
    #errors=$(( $errors + 1 ))
  #elif [ ! -r "$CONF_SOURCE_PATH" ]; then
    #log_error "Source index path '$CONF_SOURCE_PATH' is not readable."
    #errors=$(( $errors + 1 ))
  #elif [ ! -d "$CONF_SOURCE_PATH" ]; then
    #log_error "Source index path '$CONF_SOURCE_PATH' is not a directory. This is unusual."
    #errors=$(( $errors + 1 ))
  #elif [ -L "$CONF_SOURCE_PATH" ]; then
    #log_error "Source index path '$CONF_SOURCE_PATH' is a symlink. This index has probably already been moved."
    #errors=$(( $errors + 1 ))
  #fi
  #echo $errors
  #return $errors
#}

# Parse the command line arguments and build a running configuration from them.
parse_args() {
  local args; args="$@"
  local short_args="c:,d,f:,n,t:"
  local long_args="config:,debug,dry-run,from-dir:,help,to-dir:"
  local g; g=$(getopt -o "$short_args" -l "$long_args" -- $args) || die "Could not parse arguments, aborting."
  log_debug "args: $args, getopt: $g"

  eval set -- $g
  while true; do
    local a; a="$1"

    # These are index names.
    if [ "$a" = "--" ] ; then
      shift
      CONF_INDEX_NAMES="$@"
      return 0

    # This is the config file.
    elif [ "$a" = "-c" -o "$a" = "--config" ] ; then
      shift
      CONF_FILE="$1"

    # The debug switch.
    elif [ "$a" = "-d" -o "$a" = "--debug" ] ; then
      CONF_DEBUG="true"

    # The dry-run switch.
    elif [ "$a" = "-n" -o "$a" = "--dry-run" ] ; then
      CONF_DRY_RUN="true"

    # The source directory. 
    elif [ "$a" = "-f" -o "$a" = "--from-dir" ] ; then
      shift
      CONF_SOURCE_DIR="$1"

    # Help.
    elif [ "$a" = "-h" -o "$a" = "--help" ] ; then
      CONF_HELP="true"

    # Destination directory.
    elif [ "$a" = "-t" -o "$a" = "--to-dir" ] ; then
      shift
      CONF_DEST_DIR="$1"

    # Dazed and confused...
    else
      die "I know about the '$a' argument, but I don't know what to do with it, aborting."
    fi

    shift
  done

  return 0
}

# Build a running configuration from the configuration file.
load_conffile() {
  local errors=0 fn="$1"
  if [ -z "$fn" ]; then
    return 0
  elif [ ! -e "$fn" ]; then
    log_error "Configuration file '$fn' does not exist."
    errors=$(( $errors + 1 ))
  elif [ ! -f "$fn" ]; then
    log_error "Configuration file '$fn' is not a file."
    errors=$(( $errors + 1 ))
  elif [ ! -r "$fn" ]; then
    log_error "Configuration file '$fn' is not readable."
    errors=$(( $errors + 1 ))
  else 
    . $fn || { 
      log_error "Could not load configfile '$fn'."
      errors=$(( $errors + 1 ))
    }
  fi
  return $errors
}

#
# Do the whole command line arguments / configuration file lambada.
# 
# First, parse the command line arguments to see if the user has given us a
# configuration file. If so, load it. Then, parse the arguments again because
# by convention they should override the configuration file.
parse_args $@
[ -n "$CONF_FILE" ] && load_conffile "$CONF_FILE" && parse_args $@
#
# We apparently have some configuration now, let's check its sanity.
errors=0
errors=$(( $errors + $(check_CONF_DEBUG) ))
errors=$(( $errors + $(check_CONF_DRY_RUN) ))
errors=$(( $errors + $(check_CONF_INDEX_NAMES) ))
errors=$(( $errors + $(check_CONF_SOURCE_DIR) ))
errors=$(( $errors + $(check_CONF_DEST_DIR) ))
[ "$errors" -gt 0 ] && die "$errors error(s) found, aborting."
unset errors

## Build the source path and check the sanity, too.
#CONF_SOURCE_PATH="$CONF_SOURCE_DIR/$CONF_INDEX_NAMES"
#errors=0
#errors=$(( $errors + $(check_CONF_SOURCE_PATH) ))
#[ "$errors" -gt 0 ] && die "$errors error(s) found, aborting."
#unset errors

# rsync source index to the destination
run "rsync -a $CONF_SOURCE_PATH $CONF_DEST_DIR" || die "Oops, something went wrong."

# Remove the source index
run "rm -r $CONF_SOURCE_PATH" || die "Oops, something went wrong."

# Create the symlink in place of the source index
DST_IDX_PATH="$CONF_DEST_DIR/$CONF_INDEX_NAMES"
run "ln -s $DST_IDX_PATH $CONF_SOURCE_DIR" || die "Oops, something went wrong."

# exit with no errors
exit 0

# vim: set ts=2 sw=2 et cc=80:
