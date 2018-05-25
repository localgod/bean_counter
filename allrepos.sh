#!/usr/bin/env bash
#
# Script for retriving url to all repositories in projects in BitBucket
#
# Example use: # ./allrepos.sh --scan --host bitbucket.example.com --username xxxxx
#

declare B_PROTOCOL='https' B_HOST='' B_PORT=443 B_BASEURL='' B_USER='' B_PASS=''
declare CURL_VERBOSE='-s' LIMIT='' USE_HTTP=0 ACTION=0

# Parse script arguments
GETOPT=$(getopt -n "$0"  -o '' --long "protocol:,host:,port:,username:,password:,use-http,limit:,help,scan"  -- "$@")
if [ $? -ne 0 ]; then exit 1; fi
eval set -- "$GETOPT"

while true;
do
  case "$1" in
    --protocol)
      if [ -n "$2" ]; then B_PROTOCOL="$2"; fi; shift 2;;
    --host)
      if [ -n "$2" ]; then B_HOST="$2"; fi; shift 2;;
    --port)
      if [ -n "$2" ]; then B_PORT="$2"; fi; shift 2;;
    --username)
      if [ -n "$2" ]; then B_USER="$2"; fi; shift 2;;
    --password)
      if [ -n "$2" ]; then B_PASS="$2"; fi; shift 2;;
    --limit)
      if [ -n "$2" ]; then LIMIT="$2"; fi; shift 2;;
    --help)
      ACTION=0; shift;;
    --use-http)
      USE_HTTP=1; shift;;
    --scan)
      ACTION=1; shift;;
    --)
      shift
      break;;
  esac
done

# Get all Bitbucket projects
function _get_projects () {
  local path='rest/api/1.0/projects'
  local param="limit=${LIMIT}"
  local url="${B_BASEURL}/${path}?${param}"
  local projects=$(curl ${CURL_VERBOSE} -u ${B_USER}:${B_PASS} ${url} | jq -r '.values[] .key')
  echo "${projects}"
}

# Get all Bitbucket project repositories
function _get_project_repos () {
  local path="rest/api/1.0/projects/${1}/repos"
  local param="limit=1000"
  local url="${B_BASEURL}/${path}?${param}"
  local repositories=$(curl ${CURL_VERBOSE} -u ${B_USER}:${B_PASS} ${url} | jq -r '.values[] .slug')
  echo "${repositories}"
}

# Scan Bitbucket
function scan () {
  local projects=( $(_get_projects) )
  local output
  for i in "${projects[@]}"
  do :
    local repositories=( $(_get_project_repos "${i}") )
    for j in "${repositories[@]}"
    do :
      if [[ "${USE_HTTP}" == "1" ]] ; then
        output="${output}$(printf "%s://%s@%s:%s/scm/%s/%s.git" "${B_PROTOCOL}" "${B_USER}:${B_PASS}" "${B_HOST}" "${B_PORT}" "${i,,}" "${j}")\n"
      else
        output="${output}$(printf "%s://git@%s:%s/scm/%s/%s.git" "ssh" "${B_HOST}" "7999" "${i,,}" "${j}")\n"
      fi
    done
  done
  printf "${output}"
}

# Print usage screen
function usage () {
  local yellow='\033[0;33m'
  local nc='\033[0m'
  printf "\n%s:\n\n" "Valid arguments"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "protocol" "https" "Protocol to use."
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "host" "example.com" "Host to use (Required)"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "port" "443" "Port to use."
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "username" "" "Username (Required)"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "password" "" "Password (Required)"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "limit" "1000" "Limit projects to scan"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "use-http" "" "Use http(s) instead of ssh"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "help" "" "This help"
  printf " --%-10s ${yellow}%-15s${nc} %s\n" "scan" "" "Scan for repositories"
  printf "\n"
  exit 0
}

# Print error message
function print_error_message () {
  local red='\033[0;31m'
  local nc='\033[0m'
  printf "\n${red}${1}${nc}\n"
}

# Script entry point
function main () {
  if [ "${ACTION}" == "0" ]; then usage; fi
  if [ "${B_HOST}" == "" ]; then print_error_message "No host provided."; usage; exit 1; fi
  if [ "${B_USER}" == "" ]; then print_error_message "No username provided."; usage; exit 1; fi
  if [ "${B_PASS}" == "" ]; then read -s -p "Password: " B_PASS; echo; fi
  B_BASEURL="${B_PROTOCOL}://${B_HOST}:${B_PORT}"
  if [ "${ACTION}" == "1" ]; then scan; fi
}

main
