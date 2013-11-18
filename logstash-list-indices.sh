#!/bin/sh

# The default configuration
CONF_DEBUG=""
CONF_DRY_RUN=""
CONF_FILE=""
CONF_FIND_AGE=""
CONF_FIND_NAME_MASK="logstash-????.??.??"
CONF_HELP=""
CONF_PRINT=""
CONF_SOURCE_DIR="/var/lib/elasticsearch/logstash/nodes/0/indices"

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
  [ -n "$CONF_DRY_RUN" ] && {
    log_dryrun "Would run '$command'."
    return 0
  }
  eval $command
  local retval=$?
  [ "$retval" -gt 0 ] && log_error "Failed: $run"
  return $retval
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

# Parse the command line arguments and build a running configuration from them.
parse_args() {
  local args; args="$@"
  local short_args="a:,c:,d,f:,h,n"
  local long_args="age:,config:,debug,dry-run,find-args:,from-dir:,help,print-config,to-dir:"
  local g; g=$(getopt -o "$short_args" -l "$long_args" -- $args) || die "Could not parse arguments, aborting."
  log_debug "args: $args, getopt: $g"

  eval set -- $g
  while true; do
    local a; a="$1"

    # This is the end of arguments
    if [ "$a" = "--" ] ; then
      shift
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

    # The find(1) additional arguments.
    elif [ "$a" = "-a" -o "$a" = "--age" ] ; then
      shift
      CONF_FIND_AGE="$1"

    # The source directory. 
    elif [ "$a" = "-s" -o "$a" = "--source-dir" ] ; then
      shift
      CONF_SOURCE_DIR="$1"

    # Help.
    elif [ "$a" = "-h" -o "$a" = "--help" ] ; then
      CONF_HELP="true"

    # Print the current configuration switch.
    elif [ "$a" = "--print-config" ] ; then
      CONF_PRINT="true"

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
This shell outputs the available Logstash indices.
See https://github.com/shkitch/logstash-list-indices for details.

Usage: logstash-list-indices [options] <index_name> ... 

Options are:
  -f, --from-dir : source directory where indices are stored.
  -a, --age      : age of the indices, this gets passed on as the '-mtime'
                   parameter to find(1)

  -c, --config       : Path to config file.
      --print-config : Print the current configuration, then exit.
  -d, --debug        : Enable debug output.
  -n, --dry-run      : Don't do anyhing, just report what would be done.
  -h, --help         : This text
HERE
}

# Print the current configuration. This could be done more clevery in bash 
# instead of dash but this would make the script shell-specific.
print_config() {
  log "CONF_DEBUG='$CONF_DEBUG'"
  log "CONF_DRY_RUN='$CONF_DRY_RUN'"
  log "CONF_FILE='$CONF_FILE'"
  log "CONF_HELP='$CONF_HELP'"
  log "CONF_PRINT='$CONF_PRINT'"
  log "CONF_SOURCE_DIR='$CONF_SOURCE_DIR'"
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

list_indices() {
  local a; [ ! -z "$CONF_FIND_AGE" ] && a="-daystart -mtime $CONF_FIND_AGE"
  local r; r="find $CONF_SOURCE_DIR -maxdepth 1 -iname 'logstash-????.??.??' $a | sort"
  local indices; indices="$(run $r)"
  [ $? -ne 0 ] && {
    log_error "Oops, something went wrong."
    return 1
  }

  indices="$( echo $indices | sed s+$CONF_SOURCE_DIR/++g )" 
  [ ! -z "$indices" ] && echo $indices
  return 0
}

# Do the whole command line arguments / configuration file / help lambada in the
# proper order.
# 
# First, parse the command line arguments. to see if the user has given us a
# configuration file.
parse_args $@
#
# Do the help thing if the user so wishes.
[ -n "$CONF_HELP" ] && {
  print_help
  exit 0
}
#
# Check if we've got a configuration file via the command-line switches. If so,
# load it. Then, parse the arguments *again* because by convention they should
# override the stuff given in the configuration file.
[ -n "$CONF_FILE" ] && load_conffile "$CONF_FILE" && parse_args $@
#
# Print the config if so inclined.
[ -n "$CONF_PRINT" ] && {
  print_config
  exit 0
}
#
# We apparently have some configuration now, let's check its sanity.
errors=0
errors=$(( $errors + $(check_CONF_DEBUG) ))
errors=$(( $errors + $(check_CONF_DRY_RUN) ))
errors=$(( $errors + $(check_CONF_SOURCE_DIR) ))
[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
unset errors

list_indices

# vim: set ts=2 sw=2 et cc=80:
