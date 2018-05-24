#!/usr/bin/env bash
#
# Script for retriving all repositories in all projects in BitBucket
#
# Example use: # ./allrepos.sh --parse --host bitbucket.example.com --username xxxxx
#

#TODO  better help argument
#TODO option to output to stdout or file

declare B_PROTOCOL='https' B_HOST='' B_PORT=443 B_BASEURL='' B_USER='' B_PASS=''
declare CURL_VERBOSE='-s' PARSE=0

# Get all Bitbucket projects
function _get_all_projects () {
  local path='rest/api/1.0/projects'
  local param="limit=1000"
  local url="${B_BASEURL}/${path}?${param}"
  local projects=$(curl ${CURL_VERBOSE} -u ${B_USER}:${B_PASS} ${url} | jq -r '.values[] .key')
  echo "${projects}"
}

# Get all Bitbucket project repositories
function _get_all_project_repos () {
  local path="rest/api/1.0/projects/${1}/repos"
  local param="limit=1000"
  local url="${B_BASEURL}/${path}?${param}"
  local repositories=$(curl ${CURL_VERBOSE} -u ${B_USER}:${B_PASS} ${url} | jq -r '.values[] .slug')
  echo "${repositories}"
}

# Generate list
function parse_projects () {
  local projects=( $(_get_all_projects) )
  for i in "${projects[@]}"
  do :
    local repositories=( $(_get_all_project_repos "${i}") )
    for j in "${repositories[@]}"
    do :
      printf "%s://%s@%s:%s/%s/%s.git\n" ${B_PROTOCOL} ${B_USER} ${B_HOST} ${B_PORT} ${i} ${j} >> repolist.txt
    done
  done
}

# Parse script arguments
GETOPT=$(getopt -n "$0"  -o '' --long "protocol:,host:,port:,username:,password:,help,parse"  -- "$@")
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
    --help)
      echo "usage $0 --help --parse --protocol --host --port --username --password"; shift;;
    --parse)
      PARSE=1; shift;;
    --)
      shift
      break;;
  esac
done

if [ "${B_HOST}" == "" ]; then echo "No host provided."; exit 1; fi
if [ "${B_USER}" == "" ]; then echo "No username provided."; exit 1; fi
if [ "${B_PASS}" == "" ]; then read -s -p "Password: " B_PASS; echo; fi
B_BASEURL="${B_PROTOCOL}://${B_HOST}:${B_PORT}"
if [ "${PARSE}" == "1" ]; then parse_projects; fi
