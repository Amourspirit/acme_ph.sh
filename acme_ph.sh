#!/bin/bash

# MIT License
#
# Copyright (c) 2020 Paul Moss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Generates a SSL certificate and installs it into domain while first replacing the current
# conf file with a stand in conf file. Onece SSL is installed the original conf file is restored.
#
# Author: Paul Moss
# Created 2020-06-26
# Github: https://github.com/Amourspirit/acme_ph.sh
# File Name: acme_ph.sh
# acme.sh must be installed https://github.com/Neilpang/acme.sh
# see also: https://github.com/Neilpang/acme.sh/wiki/Deploy-ssl-certs-to-apache-server
VER='1.0.0'


# function: trim
# Param 1: the variable to trim whitespace from
# Usage:
#   while read line; do
#       if [[ "$line" =~ ^[^#]*= ]]; then
#           setting_name=$(_trim "${line%%=*}");
#           setting_value=$(_trim "${line#*=}");
#           SCRIPT_CONF[$setting_name]=$setting_value
#       fi
#   done < "$TMP_CONFIG_COMMON_FILE"
function _trim () {
	local var=$1;
	var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
	var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
	echo -n "$var";
}

# Case sensitive test for a string that starts with a substring
# Usage:
# if [[ $(_startswith "${MY_STRING}" "${MY_SUB_STRING}") ]]; then
#   echo 'found'
# else
#   echo 'not found'
# fi
function _startswith() {
  local _str="$1"
  local _sub="$2"
  _result=$(echo "${_str}" | grep "^${_sub}")
  if ! [[ -z ${_result} ]]; then
	echo 1
  fi
}

# Case sensitive test for a string that ends with a substring
# Usage:
# if [[ $(_endswith "${MY_STRING}" "${MY_SUB_STRING}") ]]; then
#   echo 'found'
# else
#   echo 'not found'
# fi
function _endswith() {
  local _str="$1"
  local _sub="$2"
  local _result=$( echo "${_str}" | grep -- "${_sub}$")
  if ! [[ -z ${_result} ]]; then
	echo 1
  fi
}
# Appends a forward slash on end of string when it doen not end with forward slash
# Requires: _endswith function
# Usage:
# echo $(_appendfs "${SOME_PATH}")
function _appendfs() {
  local _str="$1"
  if ! [[ $(_endswith "${_str}" '/') ]]; then
	_str="${_str}/"
  fi
  echo "${_str}"
}
# Gets the file name from a path
# Usage:
# echo $(_path_file '/this/is/my/path/file')
function _path_file () {
  echo $(basename $1)
}
# Change input from .conf file to .dummy.conf
# Usage:
# echo $(_getdummyfile 'myfile.conf')
# echo $(_getdummyfile 'myfile')
function _getdummyfile () {
  local _in="$1"
  local _out="$(basename --suffix='.conf' -a ${_in})"
  _out="${_out}.dummy.conf"
  echo "${_out}"
}
# Normalizes a path and removes trailing slashes
# Back slahses will are converted to forward slashes and double slashes are removed
# Usage:
# echo $(_path_normalize '/this/is/my/path/file/')
function _path_normalize () {
  local _in="$1"
  local _out="${_in//'\'/'/'}"
  _out="${_out//'//'/'/'}"
  if [[ $(_endswith "${_in}" '/') ]]; then
	_out="${_out%/*}"
  fi
  echo "${_out}"
}

# Deletes a system Linked file 
# Returns 0 if the link no longer exit
# Returns 2 if the file exist and is not a system linked file
# Returns 1 if the file still exits and it is a system link
# Usage:
# RESULT=$(_remove_syslink "${DUMMY_FILE_LINK}")
#
#   _create_syslink "${real_file}" "${link_file}"
# if [[ $? -ne 0 ]]; then
#   echo 'an error occured'
# fi
function _remove_syslink() {
    local _file_link="$1"
    
    if [[ -e "${_file_link}" ]] && ! [[ -L "${_file_link}" ]]; then
        # file exit and is not a link
        # will not remove a file if it is not a linked value
        return 2
    fi
    if [[ -L "${_file_link}" ]]; then
        rm -f "${_file_link}"
        sleep 1
    else
        return 0
    fi
    if [[ -L "${_file_link}" ]]; then
        #link file still exit. failed to remove
        return 1
    else
        # link file no longer exist
        return 0
    fi
}
# Creates a system link. Remove old system link first if it exist
# @param 1 real file
# @param 2 link name
# Returns
#   Returns 0 if System Link was succesfuly created
#   Returns 1 if System link previously existed and was not able to be replaced
#   Returns 2 if Source file does not exist
# Remarks:
#   If link already exist it will be deleted and recreated
# Depends _remove_syslink()
# Usage:
#   _create_syslink "${real_file}" "${link_file}"
# if [[ $? -ne 0 ]]; then
#   echo 'an error occured'
# fi
function _create_syslink() {
  local _file_real="$1"
  local _file_link="$2"
  if ! [[ -e "${_file_real}" ]]; then
    echo "${_file_real}" 'does not exit'
    # real file does not exsit. will not be able to make link
    return 2
  fi
   # look to remove he system link just in case it still exist
  _remove_syslink "${_file_link}"
  if [[ $? -ne 0 ]]; then
    # was not able to remove system link. Still existing
    return 1
  fi
  ln -s "${_file_real}" "${_file_link}"
  sleep 1
  if [[ -L "${_file_link}" ]]; then
      # system link file exist
      return 0
  else
      # System Link file does not exits
      return 1
  fi
}

# Test apache configuration
function _test_http_conf() {
    local _httpd="$1"
    if [[ -z _httpd ]]; then
        _httpd=0
    fi
    if [[ "${_httpd}" -ne 0 ]]; then
        httpd -t
    else
        if ! [[ $(which configtest) ]]; then
            apachectl configtest
        else
            apache2 -t
        fi
    fi
    return $?
}

typeset -A SCRIPT_CONF # init array
SCRIPT_CONF=( # set default values in config array
	[SITES_AVAILABLE]='/etc/apache2/sites-available'
	[SITES_ENABLED]='/etc/apache2/sites-enabled'
	[ACME_SCRIPT]="$HOME/.acme.sh/acme.sh"
	[HTTPD]=0
)
if [[ -f "${HOME}/.acme_ph.cfg" ]]; then
	# make tmp file to hold section of config.ini style section in
	TMP_CONFIG_COMMON_FILE=$(mktemp)
	# SECTION_NAME is a var to hold which section of config you want to read
	SECTION_NAME="APACHE"
	# sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
	sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.acme_ph.cfg" > $TMP_CONFIG_COMMON_FILE
	while read line; do
        if [[ "$line" =~ ^[^#]*= ]]; then
            setting_name=$(_trim "${line%%=*}");
            setting_value=$(_trim "${line#*=}");
            SCRIPT_CONF[$setting_name]=$setting_value
        fi
    done < "$TMP_CONFIG_COMMON_FILE"

    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_COMMON_FILE

	# make tmp file to hold section of config.ini style section in
	TMP_CONFIG_COMMON_FILE=$(mktemp)
	# SECTION_NAME is a var to hold which section of config you want to read
	SECTION_NAME="ACME"
	# sed in this case takes the value of SECTION_NAME and reads the setion from ~/config.ini
	sed -n '0,/'"$SECTION_NAME"'/d;/\[/,$d;/^$/d;p' "$HOME/.acme_ph.cfg" > $TMP_CONFIG_COMMON_FILE
	while read line; do
        if [[ "$line" =~ ^[^#]*= ]]; then
            setting_name=$(_trim "${line%%=*}");
            setting_value=$(_trim "${line#*=}");
            SCRIPT_CONF[$setting_name]=$setting_value
        fi
    done < "$TMP_CONFIG_COMMON_FILE"

    # release the tmp file that is contains the current section values
    unlink $TMP_CONFIG_COMMON_FILE
fi

SITES_AVAILABLE=$(eval echo ${SCRIPT_CONF[SITES_AVAILABLE]})
SITES_ENABLED=$(eval echo ${SCRIPT_CONF[SITES_ENABLED]})
ACME_SCRIPT=$(eval echo ${SCRIPT_CONF[ACME_SCRIPT]})
HTTPD=${SCRIPT_CONF[HTTPD]}

# done with config array so lets free up the memory
unset SCRIPT_CONF

usage() { echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'; exit 0; }
while getopts "hvd:r:p:c:f:t:s:a:e:i:" arg; do
  case $arg in
  d) # Required: Specify -d the domain name if -c is ommited then the conf file name will be inferred from this parameter
        DOMAIN_NAME="${OPTARG}"
        ;;
  r) # Required: Specify -r the root directory of the site such as /home/mysite
        SITE_ROOT="${OPTARG}"
        ;;
  p) # Optional: Specify -p the public folder for the site. If ommited then then -r + /public_html will be infered such as /home/mysite/public_html
        SITE_PUBLIC="${OPTARG}"
        ;;
  c) # Optional: Specify -c the name of the site configuration file. This is the same value that a2ensite would use such as domain.tld
        REAL_FILE="${OPTARG}"
        ;;
  f) # Optional: Specify -f the place holder conf file that will be enabled to allow letsencrypt to update site.
        DUMMY_FILE="${OPTARG}"
        ;;
  t) # Optional: Specify -t if set to 1 will uses httpd; Otherwise, By default apache2 will be used
        HTTPD="${OPTARG}"
        ;;
  s) # Optional: Specify -s the full path to acme.sh file. Default: ~/.acme.sh/acme.sh
        ACME_SCRIPT="${OPTARG}"
        ;;
  a) # Optional: Specify -a to use a path to configuration file. default is /etc/apache2/sites-available
        SITES_AVAILABLE="${OPTARG}"
        ;;
  e) # Optional: Specify -e to use a path to configuration file. default is /etc/apache2/sites-enabled
        SITES_ENABLED="${OPTARG}"
        ;;
  i) # Optional: Specify -i the configuration file locations to use that contains default options
        CURRENT_CONFIG="${OPTARG}"
        ;;
  v) # -v Display version info
        echo "$(basename $0) version: ${VER}"
        exit 0
        ;;
  h) # -h Display help.
        echo 'This script disables the site passed in with the -c option and enables a dummy site to allow lets encrypt to work.'
		echo 'Once lets encrypt is run via acme.sh the orginal site is restored'
        usage
        exit 0
        ;;
  esac
done
shift $((OPTIND-1))

if [ -z "${DOMAIN_NAME}" ] || [ -z "${SITE_ROOT}" ]; then
    usage
fi
SITE_ROOT=$(_path_normalize "${SITE_ROOT}")
# SITE_PUBLIC
if [[ -z "${SITE_PUBLIC}" ]]; then
	SITE_PUBLIC="${SITE_ROOT}/public_html"
else
	SITE_PUBLIC=$(_path_normalize "${SITE_PUBLIC}")
fi

SITES_AVAILABLE=$(_path_normalize "${SITES_AVAILABLE}")
SITES_ENABLED=$(_path_normalize "${SITES_ENABLED}")
if [ -z "${REAL_FILE}" ]; then
    REAL_FILE="${DOMAIN_NAME}"
fi

REAL_FILE=$(_path_file ${REAL_FILE})
if ! [[ $(_endswith "${REAL_FILE}" '.conf') ]]; then
	REAL_FILE="${REAL_FILE}.conf"
fi

REAL_FILE_PATH="${SITES_AVAILABLE}/${REAL_FILE}"
REAL_FILE_LINK="${SITES_ENABLED}/${REAL_FILE}"
# REAL_FILE_LINK="${SITES_ENABLED}${REAL_FILE_LINK}"
#set up dummy file
# DUMMY_FILE
if [[ -z  "${DUMMY_FILE}" ]]; then
	DUMMY_FILE=$(_getdummyfile "${REAL_FILE}")
else
	if ! [[ $(_endswith "${DUMMY_FILE}" '.conf') ]]; then
		DUMMY_FILE="${DUMMY_FILE}.conf"
	fi
fi
DUMMY_FILE_PATH="${SITES_AVAILABLE}/${DUMMY_FILE}"
DUMMY_FILE_LINK="${SITES_ENABLED}/${DUMMY_FILE}"
# echo "Site Root:        ${SITE_ROOT}"
# echo "Site Public:      ${SITE_PUBLIC}"
# echo "Sites Available:  ${SITES_AVAILABLE}"
# echo "Sites Enabled:    ${SITES_ENABLED}"
# echo "Acme Script:      ${ACME_SCRIPT}"
# echo "Real File:        ${REAL_FILE}"
# echo "Real File Path:   ${REAL_FILE_PATH}"
# echo "Real File Link:   ${REAL_FILE_LINK}"
# echo "Dummy File:       ${DUMMY_FILE}"
# echo "Dummy File Path:  ${DUMMY_FILE_PATH}"
# echo "Dummy File Link:  ${DUMMY_FILE_LINK}"

test -d "${SITE_ROOT}"
if [[ $? -ne 0 ]]; then
	echo -n "'${SITE_ROOT}'"
	echo ' does not exist or is not a directory. Required directory!'
	exit 1
fi

test -d "${SITE_PUBLIC}"
if [[ $? -ne 0 ]]; then
	echo -n "'${SITE_PUBLIC}'"
	echo ' does not exist or is not a directory. Required directory!'
	exit 1
fi
test -r "${ACME_SCRIPT}"
if [[ $? -ne 0 ]]; then
	echo -n "'${ACME_SCRIPT}'"
	echo ' can not be found.'
	echo 'acme.sh can be found at: https://github.com/acmesh-official/acme.sh'
	echo 'acme.sh can be downloaded directly with the following command: wget https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh'
	exit 1
fi

test -r "${REAL_FILE_PATH}"
if [[ $? -ne 0 ]]; then
	echo -n "'${REAL_FILE_PATH}'"
	echo ' does not exist or no read access. Required file!'
	echo 'Site no longer seems to exist!'
	exit 1
fi
test -r "${DUMMY_FILE_PATH}"
if [[ $? -ne 0 ]]; then
	echo -n "'${DUMMY_FILE_PATH}'"
	echo ' does not exist or no read access. Required file!'
	echo 'Dummy site no longer seems to exist!'
	exit 1
fi

# upgrade .acme.sh if needed
bash "${ACME_SCRIPT}" --upgrade

#check if the enabled site is a file and delete if so.
test -L "${REAL_FILE_LINK}"
if [[ $? -eq 0 ]]; then
	# disable real site
	echo "${REAL_FILE}" 'site is enabled'
	rm "${REAL_FILE_LINK}"
	echo "${REAL_FILE}" 'site is now disabled'
else
	test -e "${REAL_FILE_LINK}"
	if [[ $? -eq 0 ]]; then
		# file exist and is not a link will not continue
		echo "${REAL_FILE}" 'is not a system linked file. Can not continue'
		exit 1
	else
		echo "${REAL_FILE}" 'site is not currently enabled'
	fi
fi

test -L "${DUMMY_FILE_LINK}"
if [[ $? -ne 0 ]]; then
	# enable dummy site
	ln -s "${DUMMY_FILE_PATH}" "${DUMMY_FILE_LINK}"
	echo 'Enabled site:' "${DUMMY_FILE}"
fi

# test configuration
if [[ $(_test_http_conf "${HTTPD}") -ne 0 ]]; then
    echo 'There is configuration error. Unable to continue!'
	exit 1
fi

RELOAD_CMD='systemctl force-reload apache2'
if [[ "${HTTPD}" -ne 0 ]]; then
	RELOAD_CMD='systemctl force-reload httpd'
fi
$(eval "${RELOAD_CMD}")


# webroot mode
bash "${ACME_SCRIPT}" --issue --force -d "${DOMAIN_NAME}" -w "${SITE_PUBLIC}"
# check and see if acme had an error
if [[ $? -ne 0 ]]; then
    echo 'acme.sh had a error. Attempting retore of' "${DOMAIN_NAME}"
    # restore normal file
    _remove_syslink "${DUMMY_FILE_LINK}"
    if [[ $? -eq 1 ]]; then
        echo "${DUMMY_FILE_LINK}" 'still exist even though attempt was made to remove. Halting!'
        exit 1
    fi
    # enable real site
    _create_syslink "${REAL_FILE_PATH}" "${REAL_FILE_LINK}"
    if [[ $? -eq 0 ]]; then
        echo "${DOMAIN_NAME}" 'Has been restored'
    else
        echo 'Unable to restore"' "${DOMAIN_NAME}"
    fi
    
    #restart apache
    _test_http_conf "${HTTPD}"
    if [[ $? -eq 0 ]]; then
        echo 'Restarting Apache'
        $(eval "${RELOAD_CMD}")
        exit 1
    else
        echo 'There is configuration error. Unable to continue!'
	    exit 1
    fi
    
fi

# install the Cert
bash "${ACME_SCRIPT}" --install-cert -d "${DOMAIN_NAME}" \
--cert-file      "${SITE_ROOT}/ssl.cert"  \
--key-file       "${SITE_ROOT}/ssl.key"  \
--fullchain-file "${SITE_ROOT}/ssl.ca" \
--force
# --reloadcmd     "${RELOAD_CMD}"

# disable dummy site
rm -f "${DUMMY_FILE_LINK}"
sleep 1
test -L "${DUMMY_FILE_LINK}"
if [[ $? -eq 0 ]]; then
	echo "${DUMMY_FILE_LINK}" 'still exist even though attempt was made to remove. Halting!'
	exit 1
fi
# enable real site
_create_syslink "${REAL_FILE_PATH}" "${REAL_FILE_LINK}"

#restart apache
_test_http_conf "${HTTPD}"
if [[ $? -eq 0 ]]; then
    echo 'Restarting Apache'
    $(eval "${RELOAD_CMD}")
fi
