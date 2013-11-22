#!/bin/sh

# The default configuration#{{{
#
CONF_DATE_FROM=""
CONF_DATE_TO=""
CONF_DEBUG=""
CONF_FILE=""
CONF_HELP=""
CONF_INDEX_NAME_PREFIX="logstash-"
CONF_PRINT=""
CONF_SOURCE_DIR="/var/lib/elasticsearch/logstash/nodes/0/indices"

#}}}
# Various logging functions#{{{
#
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

#}}}
# Misc functions#{{{
#
# Die gracefully.
die() {
  log_stderr "$*"
  exit 1
}

# Run the specified command
#
run() {
  [ -z "$*" ] && {
    log_warning "Nothing to execute."
    return 0
  }

  local command="$*"
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
  local short_args="a:,c:,d,f:,h,s:,t:"
  local long_args="age:,config:,debug,from:,help,index-name-prefix:,print-config,source-dir:,to:"
  local g; g=$(getopt -n logstash-list-indices -o $short_args -l $long_args -- "$@") || die "Could not parse arguments, aborting."
  log_debug "args: $args, getopt: $g"

  eval set -- "$g"
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

    # The source directory. 
    elif [ "$a" = "-s" -o "$a" = "--source-dir" ] ; then
      shift
      CONF_SOURCE_DIR="$1"

    # Help.
    elif [ "$a" = "-h" -o "$a" = "--help" ] ; then
      CONF_HELP="true"

    # From date.
    elif [ "$a" = "-f" -o "$a" = "--from" ] ; then
      shift
      CONF_DATE_FROM="$1"

    # To date.
    elif [ "$a" = "-t" -o "$a" = "--to" ] ; then
      shift
      CONF_DATE_TO="$1"

    # Print the current configuration switch.
    elif [ "$a" = "--print-config" ] ; then
      CONF_PRINT="true"

    # Index name prefix switch.
    elif [ "$a" = "--index-name-prefix" ] ; then
      shift
      CONF_INDEX_NAME_PREFIX="$1"

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
  -f, --from       : List indices from this date forward. Accepts date(1)
                     formatting or dates in yyyy.mm.dd format.
  -s, --source-dir : source directory where indices are stored, default is
                     '/var/lib/elasticsearch/logstash/nodes/0/indices'
  -t, --to         : List indices up to this date. Accepts date(1) formatting or
                     dates in yyyy.mm.dd format.

      --index-name-prefix : Indices have this prefix, default is 'logstash-'

  -c, --config       : Path to config file.
  -d, --debug        : Enable debug output.
  -h, --help         : This text
      --print-config : Print the current configuration, then exit.

NOTE: if you use date(1) formats in --from or --to, be sure to quote the 
arguments. E.g.: use "logstash-list-indices --from '1 week ago'", and not
"logstash-list-indices --from 1 week ago". 
HERE
}

#
# Print the current configuration. 
# 
# NOTE: This could be done more clevery in bash instead of dash but this would
# make the script shell-specific. For example, using the ${!CONF_*} expansion.
#
print_config() {
  log "CONF_DATE_FROM='$CONF_DATE_FROM'"
  log "CONF_DATE_TO='$CONF_DATE_TO'"
  log "CONF_DEBUG='$CONF_DEBUG'"
  log "CONF_FILE='$CONF_FILE'"
  log "CONF_HELP='$CONF_HELP'"
  log "CONF_INDEX_NAME_PREFIX='$CONF_INDEX_NAME_PREFIX'"
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

#}}}
# Date functions#{{{
#
# Check if the given date is in the yyyy.mm.dd format.
#
is_date_absolute() {
  local d="$1"
  [ -z "$d" ] && {
    log_error "No date given."
    return 1
  }
  echo "$d" | grep -P '^\d{4}.\d{2}.\d{2}$' 2>&1 > /dev/null
  return $?
}

#
# Convert given date in date(1) format to absolute date in yyyy.mm.dd format.
#
get_absolute_date() {
  local d="$@"
  [ -z "$d" ] && {
    log_error "No date given."
    return 1
  }
  
  local a
  a=$(date +%Y.%m.%d --date="$d") || {
    log_error "could not convert date '$d' to absolute date."
    return 1
  }

  echo "$a"
  return 0
}

#}}}
# Checker functions#{{{

check_CONF_DEBUG() {
  log_debug "Running in debug mode."
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
  return $errors
}

check_CONF_DATE_FROM() {
  # It is a-ok if no date is given.
  [ -z "$CONF_DATE_FROM" ] && {
    return 0
  }

  # If the given date is not absolute, make it so.
  is_date_absolute "$CONF_DATE_FROM" || CONF_DATE_FROM="$(get_absolute_date "$CONF_DATE_FROM")" || return 1
  return 0
}

check_CONF_DATE_TO() {
  # If no date is given, make today the default.
  [ -z "$CONF_DATE_TO" ] && {
    CONF_DATE_TO="$(date +%Y.%m.%d)"
    return 0
  }

  # If the given date is not absolute, make it so.
  is_date_absolute "$CONF_DATE_TO" || CONF_DATE_TO="$(get_absolute_date "$CONF_DATE_TO")" || return 1
  return 0
}

#}}}
# Do the actual work functions#{{{

get_index_list() {
  local r; r="ls -d $CONF_SOURCE_DIR/logstash-????.??.??"
  local indices; indices="$(run $r)"
  [ $? -ne 0 ] && {
    log_error "Oops, something went wrong."
    return 1
  }

  indices="$( echo $indices | sed s+$CONF_SOURCE_DIR/++g )" 
  [ -n "$indices" ] && echo $indices
  return 0
}

prune_index_list() {
  local f; f="${CONF_INDEX_NAME_PREFIX}${CONF_DATE_FROM}"
  local t; t="${CONF_INDEX_NAME_PREFIX}${CONF_DATE_TO}"
  while [ -n "$1" ]; do
    local i="$1"
    if [ "$i" \> "$f" -a "$i" \< "$t" -o "$i" = "$f" -o "$i" = "$t" ]; then
      echo $i
    fi
    shift
  done
}

#}}}
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
check_CONF_DATE_FROM; errors=$(( $errors + $? ))
check_CONF_DATE_TO; errors=$(( $errors + $? ))
check_CONF_DEBUG; errors=$(( $errors + $? ))
check_CONF_SOURCE_DIR; errors=$(( $errors + $? ))

# Print the config if so inclined.
[ -n "$CONF_PRINT" ] && {
  print_config
  exit 0
}

# Stop if there are any errors in the configuration.
[ "$errors" -gt 0 ] && die "$errors error(s) found in the configuration, aborting."
unset errors

# Do the actual work
log_debug "Listing indices from date $CONF_DATE_FROM to date $CONF_DATE_TO"
INDICES="$(get_index_list)"
log_debug "Considering the following indices for output: '$INDICES'"
prune_index_list $INDICES

# vim: set tabstop=2 shiftwidth=0 expandtab colorcolumn=80 foldmethod=marker foldcolumn=3 foldlevel=0:
