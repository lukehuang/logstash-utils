#!/bin/sh

# The default configuration#{{{
CONF_DEBUG=""
CONF_DEST_DIR=""
CONF_DRY_RUN=""
CONF_FILE=""
CONF_HELP=""
CONF_INDEX_NAMES=""
CONF_PRINT=""
CONF_SOURCE_DIR="/var/lib/elasticsearch/logstash/nodes/0/indices"
#}}}
# Various logging functions#{{{
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

log_dryrun() {
  [ -n "$CONF_DRY_RUN" ] && log "[dry-run] $*"
}
#}}}
# Misc functions#{{{
#
# Die gracefully
#
die() {
  log_stderr "$*"
  exit 1
}

#
# Run the specified command (or not, depending on CONF_DRY_RUN).
#
run() {
  [ -z "$*" ] && {
    log_warning "Nothing to execute."
    return 0
  }

  local command="$*"
  [ -n "$CONF_DRY_RUN" ] && {
    log_dryrun "Would run '$command'."
    return 0
  }
  eval $command
  local retval=$?
  [ "$retval" -gt 0 ] && log_error "Failed: $run"
  return $retval
}

#
# Parse the command line arguments and build a running configuration from them.
#
# Note that this function should be called like this:
#   parse_args "@"

# ... and *NOT* like this:
#   parse_args $@
#
# The second variant will work but it will cause havoc if the arguments contain
# spaces!
#
parse_args() {
  local short_args="c:,d,f:,h,n,t:"
  local long_args="config:,debug,dry-run,from-dir:,help,print-config,to-dir:"
  local g; g=$(getopt -o "$short_args" -l "$long_args" -- "$@") || die "Could not parse arguments, aborting."
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

    # Help.
    elif [ "$a" = "--print-config" ] ; then
      CONF_PRINT="true"

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

print_help() {
  cat <<HERE
This shell script rsyncs a Logstash/elasticsearch index from source to 
destination, removes the source and replaces it with a symlink to destination.
See https://github.com/shkitch/logstash-symlink-index for details.

Usage: logstash-symlink-index [options] <index_name> ... 

Options are:
  -f, --from-dir : source directory where indices are stored. Symlinks are created
                   here, too.
  -t, --to-dir   : Destination directory.

  -c, --config       : Path to config file.
      --print-config : Print the current configuration, then exit.
  -d, --debug        : Enable debug output.
  -n, --dry-run      : Don't do anyhing, just report what would be done.
  -h, --help         : This text
HERE
}

#
# Print the current configuration. 
# 
# NOTE: This could be done more clevery in bash instead of dash but this would
# make the script shell-specific.
#
print_config() {
  log "CONF_DEBUG='$CONF_DEBUG'"
  log "CONF_DEST_DIR='$CONF_DEST_DIR'"
  log "CONF_DRY_RUN='$CONF_DRY_RUN'"
  log "CONF_FILE='$CONF_FILE'"
  log "CONF_HELP='$CONF_HELP'"
  log "CONF_INDEX_NAMES='$CONF_INDEX_NAMES'"
  log "CONF_PRINT='$CONF_PRINT'"
  log "CONF_SOURCE_DIR='$CONF_SOURCE_DIR'"
}

#
# Build a running configuration from the configuration file.
#
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
    # Fix the dash(1) stupidity when sourcing files in the current directory
    [ "$(dirname $fn)" = "." ] && fn="./$fn"

    # Do the stuff
    . $fn || { 
      log_error "Could not load configfile '$fn'."
      errors=$(( $errors + 1 ))
    }
  fi
  return $errors
}
#}}}
# Checker functions#{{{
check_CONF_DEBUG() {
  log_debug "Running in debug mode."
  return 0
}

check_CONF_DRY_RUN() {
  [ -n "$CONF_DRY_RUN" ] && {
    log_warning "Running with CONF_DRY_RUN enabled. Not doing anything, just reporting what would be done."
  }
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
  return $errors
}

check_CONF_INDEX_NAMES() {
  local errors=0
  [ -z "$CONF_INDEX_NAMES" ] && {
    log_error "No index name given."
    errors=$(( $errors + 1 ))
  }
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
  return $errors
}
#}}}
# Do tha work functions#{{{

symlink_index() {
  local index_name="$1"
  [ -z "$index_name" ] && {
    log_warning "No index name given."
    return 0
  }
  
  local index_path; index_path="$CONF_SOURCE_DIR/$index_name"
  
  if [ ! -e "$index_path" ]; then
    log_error "Source index path '$index_path' does not exist. Could not symlink index."
    return 1
  elif [ ! -r "$index_path" ]; then
    log_error "Source index path '$index_path' is not readable. Could not symlink index."
    return 1
  elif [ ! -d "$index_path" ]; then
    log_error "Source index path '$index_path' is not a directory. This is unusual. Could not symlink index."
    return 1
  elif [ -L "$index_path" ]; then
    log_warning "Source index path '$index_path' is a symlink. This index has probably already been moved. Could not symlink index."
    return 1
  fi

  # rsync source index to the destination
  run "rsync -a $index_path $CONF_DEST_DIR" || {
    log_error ": $run"
    return 1
  }

  # Remove the source index
  run "rm -r $index_path" || {
    log_error "Oops, something went wrong."
    return 1
  }

  # Create the symlink in place of the source index
  local symlink_path="$CONF_DEST_DIR/$index_name"
  run "ln -s $symlink_path $CONF_SOURCE_DIR" || {
    log_error "Oops, something went wrong."
  }
  
  return 0
}

symlink_indices() {
  local index_names; index_names=$@
  [ -z "$index_names" ] && {
    log_warning "No index names given, nothing to do."
    return 0
  }

  local index_name result errors=0 start_at stop_at duration
  for index_name in $index_names; do
    start_at="$(date +%s)"
    symlink_index "$index_name"
    result="$?"
    stop_at="$(date +%s)"
    if [ "$result" -gt 0 ] ; then
      errors=$(( $errors + 1 ))
    else
      local duration; duration="$(( $stop_at - $start_at ))"
      log "Symlinked index '$index_name' in $duration seconds."
    fi
  done
  return $errors
}
#}}}
#
# Do the whole command line arguments / configuration file / help lambada in the
# proper order.
#
# First, parse the command line arguments. to see if the user has given us a
# configuration file.
parse_args "$@"

# Do the help thing if the user so wishes.
[ -n "$CONF_HELP" ] && {
  print_help
  exit 0
}

# Check if we've got a configuration file via the command-line switches. If so,
# load it. Then, parse the arguments *again* because by convention they should
# override the stuff given in the configuration file.
[ -n "$CONF_FILE" ] && load_conffile "$CONF_FILE" && parse_args "$@"

# We apparently have some configuration now, let's check its sanity.
errors=0
check_CONF_DEBUG; errors=$(( $errors + $? ))
check_CONF_DRY_RUN; errors=$(( $errors + $? ))
check_CONF_INDEX_NAMES; errors=$(( $errors + $? ))
check_CONF_SOURCE_DIR; errors=$(( $errors + $? ))
check_CONF_DEST_DIR; errors=$(( $errors + $? ))

# Print the config if so inclined.
[ -n "$CONF_PRINT" ] && {
  print_config
  exit 0
}

# Stop if there are any errors in the configuration.
[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
unset errors

# Do the actual work
symlink_indices $CONF_INDEX_NAMES
errors=$?
if [ "$errors" -gt 0 ]; then
  log_warning "Could not symlink $errors indices."
  return 1
else
  return 0
fi

# vim: set tabstop=2 shiftwidth=0 expandtab colorcolumn=80 foldmethod=marker foldcolumn=3 foldlevel=0:
