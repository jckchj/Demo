#!/bin/sh
#
# InstallAzSecPack - attempt to install and configure azSecPack on Linux
#    platforms supported by Geneva.  
# Author: Jordan Boland <v-jobola@microsoft.com>
#
#    Functional Requirements:
#        * SuSE (?) [supported by AzSecPack, should probably just code it up to be done]
#  TODO:
#         * Update cron job generation to account for timezone (normalize to UTC)
#         * Uninstall
#         * Log Upload
#         * 
#
#    Possible additional enhancements:
#        * Validate service health / Check for errors
#           -> Requires a way to transport installation errors first
#
###############################################################################
#
# Organization of this script:  the multitude of functions included in this
# script are roughly categorized into the following buckets:
#   * Usage and output
#   * System conveniences and wrappers
#   * Keyvault, Azure Metadata service, and AzSecPack wrappers and conveniences
#   * Installation process
#
# Within each category, the functions are presented alphabetically.
#
###############################################################################
#
# Usage and output functions
#

# uploadTranscript - Upload transcript file to the metaconfig service
uploadTranscript()
{
  if [ ! -z "${LOGFILE}" ] && [ -f ${LOGFILE} ]; then
    echo "Uploading logfile: logType=installation, subscriptionID=$(SubscriptionID), VmID=$(VMID), resourceGroup=$(ResourceGroupName), logFile=${LOGFILE}, https://airaspmetadata.azure-api.net/v1/Log"
    curl -F "logType=installation" -F "subscriptionID=$(SubscriptionID)" -F "VmID=$(VMID)" -F "resourceGroup=$(ResourceGroupName)" -F "logFile=@${LOGFILE}" "https://airaspmetadata.azure-api.net/v1/Log"
  fi
}

# abort() - Write error message to stderr and exit
abort()
{
    err "::FATAL::$*::FATAL::"
    exit 1
}

# err() - Write to stderr, wrapped correctly
err()
{
    printf "$*\n" | fmt -t 1>&2
}

# say() - Write to stdout, wrapped correctly.  Not yet implemented: verbosity
#         Note:  Wraps correctly for certain values of "correct"
say()
{
    local __msg="$*\n"
    if [ $SIMULATE -eq 0 ]; then
        __msg="SIMULATE: ${__msg}"
    fi
    printf "${__msg}" | fmt -t
}

# usage() - Provide help to the user
usage()
{
    if [ $# -gt 0 ]; then
        err "$*\n"
    fi
    say "$(basename $0): Install AzSecPack on a Linux host.\n\n"                 \
    "   -h                 help: print this usage statement\n"                   \
    "   -s             simulate: Simulate, do not actually do\n"                 \
    "   -t            keep temp: Keep temporary directory\n"                     \
    "   -u            uninstall: Remove the AzSecPack and this instrumentation.\n"
    exit 0
}

###############################################################################
#
# System conveniences and wrappers
#

# Determine if something is an ancestor of ours 
IsAncestor()
{
  local _searchAncestor=$1
  local _ppid=0
  local _searchPid=$$
  while [ ${_searchPid} -ne 1 ]; do
    _ppid=$(cat /proc/${_searchPid}/stat | cut -d' ' -f 4)
    if [ -f /proc/${_ppid}/cmdline ]; then
      if grep -q ${_searchAncestor} /proc/${_ppid}/cmdline; then
        return 0
      fi
      _searchPid=${_ppid}
    else
      return 1
    fi
  done
  return 1
}

# Determine if we were launched from our "installed" location, or from the temporary folder
# by the Invoke-AzVmRunCommand cmdlet...
LaunchedFromInstalledLocation()
{
    if [ "$(dirname $(readlink -f $0))" = "/opt/microsoft/air-azsecpack" ]; then
        return 0
    else
        return 1
    fi
}

# According to the distribution type, add the package repository
addRepositories()
{
  say "AddRepositories: $*"
  if [ "$(getDistribution)" = "ubuntu" ]; then
    # Check first if we are already configured
    if [ ! -f /etc/apt/sources.list.d/azure.list ]; then
      say "Creating /etc/apt/sources.list.d/azure.list with content: 'deb [arch=amd64] http://packages.microsoft.com/repos/azurecore/ $(/usr/bin/lsb_release -sc) main'"
      if [ $SIMULATE -ne 0 ]; then
        # Duplicates are bad
        if ! cat /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | sed '/^\s*#/d' | sed '/^\s*$/d' | grep -q http://packages.microsoft.com/repos/azurecore/ ; then
          echo "deb [arch=amd64] http://packages.microsoft.com/repos/azurecore/ $(/usr/bin/lsb_release -sc) main" | tee /etc/apt/sources.list.d/azure.list
        fi
      fi
    fi
    # Check first if we already have the key installed
    ## For some reason, apt-key behaves strangely:
    ##   * When a key does not exists, prints a blank line and exits 0
    ##   * When a key does exist, prints the key and exits 130 (!)
    ##   * And, it complains when you pipeline the output (arg)
    if [ $(apt-key list 417A0893 2>/dev/null | wc -l) -eq 0 ]; then
      # We need this key - is the keyserver accessible?
      if nc -w 1 -z apt-mo.trafficmanager.net 11371 >/dev/null 2>&1; then
        say "Retrieving key 417A0893 from keysever packages.microsoft.com and adding to trusted repositories"
        if [ $SIMULATE -ne 0 ]; then
          apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
        fi
        else
          if [ $SIMULATE -eq 0 ]; then
            keyMissingCmd='say'
          else
            keyMissingCmd='abort'
          fi
          $keyMissingCmd "The MS repository key must be added, but the keyserver" \
          "is inaccessible.  Please confirm connectivity, and then try"  \
          "again.\n\nIf you know that this server will not have "        \
          "connectivity to the keyserver, you may manually install the " \
          "key.  To do this, complete the following steps from a machine"\
          "which has access to the keyserver:\n"                         \
          "   sudo apt-key adv -keyserver packages.microsoft.com --recv-keys 417A0893\n"\
          "   sudo apt-key export 417A0893 > apt-mo.gpg"                 \
          "\n\nThen, copy the apt-mo.gpg key file from that machine to"  \
          "this one, and import it:\n"                                   \
          "   sudo apt-key add apt-mo.gpg\n"
        fi
      fi
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    # Check first if we are already configured
    if [ ! -f /etc/yum.repos.d/azurecore.repo ]; then
      say "Creating /etc/yum.repos.d/azurecore.repo."
      if [ $SIMULATE -ne 0 ]; then
        cat << EOF > /etc/yum.repos.d/azurecore.repo
[packages-microsoft-com-azurecore] 
name=packages-microsoft-com-azurecore 
baseurl=https://packages.microsoft.com/yumrepos/azurecore/ 
enabled=1 
gpgcheck=0
EOF
      fi
    fi
    if ! queryPackage epel-release; then
      local __distributionMajorVersion=$(getDistributionMajorVersion)
      say "Downloading and installing epel-release-latest-${__distributionMajorVersion}.noarch.rpm"
      if [ $SIMULATE -ne 0 ]; then
        epelFile=$(mktemp --suffix=.rpm)
        # TODO: Convert to curl, and avoid needing to get another package....
        curl -f -o $epelFile -s https://dl.fedoraproject.org/pub/epel/epel-release-latest-${__distributionMajorVersion}.noarch.rpm
        # Suppress NOKEY warning
        rpm --nosignature -i $epelFile
        rm -f $epelFile
        updateRepositoryCache
      fi
    fi
  else
    abort "Unsupported distribution: $(getDistribution)"
  fi
  updateRepositoryCache
}

# Enables the specified service(s)
# Return value undefined (It would be fairly useless as-written)
enableService()
{
  say "enableService: $*"
  for serviceName in $*; do
    # All of our systems should be systemd, but just in case we will guard this
    if [ "$(getDistribution)" = "ubuntu" ] || [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
      if [ $SIMULATE -ne 0 ]; then
        systemctl enable ${serviceName}.service >/dev/null 2>&1
      fi
    fi
  done
}

disableService()
{
  say "disableService: $*"
  for serviceName in $*; do
    # All of our systems should be systemd, but just in case we will guard this
    if [ "$(getDistribution)" = "ubuntu" ] || [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
      if [ $SIMULATE -ne 0 ]; then
        systemctl disable ${serviceName}.service >/dev/null 2>&1
      fi
    fi
  done
}

# Poke around a bit, identify which distribution we are using
getDistribution()
{
  local __resultvar=$1
	if [ -z "${_DISTRIBUTION}" ]; then
    if [ ! -z "${__resultvar}" ]; then
      say "Determining distribution..."
    fi
    _DISTRIBUTION=""
    # /etc/os-release test
    # Works on CentOS and Ubuntu, should work on RedHat
    if [ -f /etc/os-release ]; then
      _DISTRIBUTION=$( ( . /etc/os-release ; echo $ID | tr '[A-Z]' '[a-z]' ) )
    fi
    # Test against LSB (probably superfluous)
    if [ -z "${_DISTRIBUTION}" ]; then
      # lsb_release is on Ubuntu, perhaps a few others, but missing from RedHat/CentOS...
      if [ -x /usr/bin/lsb_release ]; then
         _DISTRIBUTION=$(/usr/bin/lsb_release -si | tr '[A-Z]' '[a-z]')
      fi
    fi
    # Still no distribution?  Keep trying...  (probably superfluous, and less reliable)
    if [ -z "${_DISTRIBUTION}" ]; then
      if [ -e /etc/centos-release ]; then
        _DISTRIBUTION='centos'
      elif [ -e /etc/oracle-release ]; then
      _DISTRIBUTION='oracle'
    elif [ -e /etc/redhat-release ]; then
      _DISTRIBUTION='rhel'
    fi
  fi
  # Still no distribution?  Giving up...
  if [ -z "${_DISTRIBUTION}" ]; then
    _DISTRIBUTION='unknown'
  fi     
	fi
	if [ ! -z "${__resultvar}" ]; then
		eval $__resultvar="'${_DISTRIBUTION}'"
	else
		echo "${_DISTRIBUTION}"
	fi
}

# Identify which major version we are using
# RHEL Maipo (7.6) reports version "7.6", causing breakage when downloading epel. A little `sed` ensures that we get just the major version
getDistributionMajorVersion()
{
  local __resultvar=$1
  local __majorVersion="$(getDistributionVersion)"
  __majorVersion="$(echo ${__majorVersion} | sed 's/\..*//g')"
	if [ ! -z "${__resultvar}" ]; then
		eval $__resultvar="'${__majorVersion}'"
	else
		echo "${__majorVersion}"
	fi
}

# Identify which version we are using
getDistributionVersion()
{
  local __resultvar=$1
  if [ "$(getDistribution)" = "ubuntu" ] || [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    local __version="$( ( . /etc/os-release ; echo $VERSION_ID ) )"
  else
    local __version="unknown"
  fi
  if [ ! -z "${__resultvar}" ]; then
		eval $__resultvar="'${__version}'"
	else
		echo "${__version}"
	fi
}

# Depending on the distribution, install a package
installPackage()
{
  say "installPackage: $*"
  if [ "$(getDistribution)" = "ubuntu" ]; then
    # Force non-interactive and accept defaults, e.g. don't ask questions
    export DEBIAN_FRONTEND=noninteractive
    # Really, force dpkg to not ask any questions
    if [ $SIMULATE -ne 0 ]; then
      echo 'DPkg::options { "--force-confdef"; "--force-confnew"; }' > /etc/apt/apt.conf.d/99zzz-azsec-noninteractive
    fi
    if echo "$*" | grep -q '='; then
      # If we are trying to pin something, then allow us to go forwards or backwards...
      local __pkgCmd='apt-get -y --allow-downgrades install'
    else
      local __pkgCmd='apt-get -y install'
    fi
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    local __pkgCmd="yum -y install"
  else
    return 1
  fi
  for package in $*; do
    # If we are demanding a specific version, fix package name for RedHat-ish systems to use their anticipated syntax
    # e.g. "<package>=<version>" becomes "<package>-<version>"
    if [ "${__pkgCmd}" = "yum -y install" ]; then
      if echo "${package}" | grep -q '='; then
        package="$(echo '${package}' | sed 's/=/-/g')"
      fi
      fi
      say "Installing or upgrading package (if not already installed): ${__pkgCmd} ${package}"
      if [ $SIMULATE -ne 0 ]; then
        local __pkgResult=""
        __pkgResult=$($__pkgCmd ${package} 2>&1)
        # See what happened...
        if [ "${__pkgCmd}" = "yum -y install" ]; then
          if ! echo "${__pkgResult}" | grep -q "Nothing to do"; then
            # We installed or upgraded something
            RECYCLE_REQUIRED=0
          fi
          else
            if ! echo "${__pkgResult}" | grep -q "0 upgraded, 0 newly installed"; then
              # We installed or upgraded something
              RECYCLE_REQUIRED=0
            fi
          fi
          # And log...
          say "Installation log from executing: ${__pkgCmd} ${package}:"
          say "###############################################################################"
          echo "${__pkgResult}"
          say "###############################################################################"
      fi
  done
  if [ "$(getDistribution)" = "ubuntu" ]; then
    # Remove our dpkg configuration
    if [ $SIMULATE -ne 0 ]; then
      rm -f /etc/apt/apt.conf.d/99zzz-azsec-noninteractive
    fi
  fi
}

# Depending on the distribution, remove a package
removePackage()
{
  say "removePackage: $*"
  if [ "$(getDistribution)" = "ubuntu" ]; then
    # Force non-interactive and accept defaults, e.g. don't ask questions
    export DEBIAN_FRONTEND=noninteractive
    local __pkgCmd='apt-get -y purge'
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    local __pkgCmd="yum -y remove"
  else
    return 1
  fi
  for package in $*; do
    say "Removing package (if installed): ${__pkgCmd} ${package}"
    if [ $SIMULATE -ne 0 ]; then
      local __pkgResult=""
      __pkgResult=$($__pkgCmd ${package})
      # See what happened...
      if [ "${__pkgCmd}" = "yum -y remove" ]; then
        if ! echo "${__pkgResult}" | grep -q "No Packages marked for removal"; then
          # We did something
           RECYCLE_REQUIRED=0
        fi
      else
        if ! echo "${__pkgResult}" | grep -q "0 to remove"; then
          # We did something
          RECYCLE_REQUIRED=0
        fi
      fi
    fi
  done
  # Clean up any no-longer-needed packages
  if [ "${__pkgCmd}" = "yum -y remove" ]; then
    yum -y autoremove
  else
    apt-get -y autoremove
  fi
}

# Checks if a service is enabled or not - most useful checking one-at-a-time, but
# will provide a count of disabled/nonexistant services given a list of n items
serviceEnabled()
{
  say "serviceEnabled: $*"
  notEnabledCount=0
  for serviceName in $*; do
    # All of our systems should be systemd, but just in case we will guard this
    if [ "$(getDistribution)" = "ubuntu" ] || [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
      if [ "$(systemctl list-unit-files | grep ${serviceName}.service | tr -s ' ' | cut -d' ' -f 2)" != "enabled" ]; then
        notEnabledCount=$(expr $notEnabledCount + 1)
      fi
    else
      return 200
    fi
  done
  return $notEnabledCount
}

# Checks if a service is running or not
serviceRunning()
{
  say "serviceRunning: $*"
  # All of our systems should be systemd, but just in case we will guard this
  if [ "$(getDistribution)" = "ubuntu" ] || [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    systemctl status ${1}.service >/dev/null 2>&1
    return $?
  else
    return 200
  fi
}

startService()
{
  say "startService: $*"
  if [ $RECYCLE_REQUIRED -eq 0 ]; then
    say "Services are marked for recycle; stopping services"
    # Something has changed, we need to restart these things
    # Make sure we do this LIFO
    for serviceName in $(echo $* | tr " " "\n" | tac); do
      say "Stopping ${serviceName}"
      if [ $SIMULATE -ne 0 ]; then
        systemctl stop ${serviceName}.service >/dev/null 2>&1
        sleep ${SHORT_SLEEP}
      fi
    done
    sleep ${SHORT_SLEEP}
  fi
  say "Starting services (if not running)"
  for serviceName in $*; do
    say "Starting ${serviceName}"
    if [ $SIMULATE -ne 0 ]; then
      if ! serviceRunning ${serviceName}; then
        systemctl start ${serviceName}.service >/dev/null 2>&1
        sleep ${SHORT_SLEEP}
        # Ensure the service is still running (and didn't fail when starting)
        if ! serviceRunning ${serviceName}; then
          say "Failed to start service ${serviceName}"
          return 200
        fi
      fi
    fi
  done
}

# Checks if packages are installed or not - most useful checking one-at-a-time, but
# will provide a count of non-installed packages given a list of n items
queryPackage()
{
  notInstalledCount=0
  if [ "$(getDistribution)" = "ubuntu" ]; then
    pkgCmd="dpkg -s"
    for package in $*; do
      dpkg -s ${package} 1>/dev/null 2>&1
      notInstalledCount=$(expr $notInstalledCount + $?)
    done
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    for package in $*; do
      rpm -qa | grep -q ${package} 1>/dev/null 2>&1
      notInstalledCount=$(expr $notInstalledCount + $?)
    done
  else
    return 200
  fi
  return $notInstalledCount
}

# TODO: Add implementation for RedHat systems
queryPackageVersion()
{
  local _version
  queryPackage $1
  if [ $? -eq 0 ]; then
    if [ "$(getDistribution)" = "ubuntu" ]; then
      _version=$(dpkg -s $1 | grep '^Version:' | cut -d' ' -f2)
    fi
  fi
  echo $_version
}

# Check packages which are available for upgrade.  For troubleshooting
queryUpgradablePackages()
{
  say "queryUpgradablePackages: $*"
  if [ "$(getDistribution)" = "ubuntu" ]; then
    pkgCmd="apt list --upgradable"
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    pkgCmd="yum check-update"
  fi
  $pkgCmd
}

removePackagePin()
{
  say "removePackagePin: $*"
  local package="$1"

  if [ "$(getDistribution)" = "ubuntu" ]; then
    say "Removing version pin: /etc/apt/preferences.d/azsecpackpin-${pin}.pref"
    if [ $SIMULATE -ne 0 ]; then
      rm -f /etc/apt/preferences.d/azsecpackpin-${pin}.pref
      return $?
    fi
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    say "Removing version pin: ${pin}"
    if [ $SIMULATE -ne 0 ]; then
      #### TODO:  local cache, or searchable method for detection of our pins vs user?
      yum versionlock delete ${pin}
      if [ $? -ne 0 ]; then
        return 1
      fi
      rm -f /opt/microsoft/air-azsecpack/package-pins/${pin}
      return $?
    fi
  else
    return 1
  fi
}

# We need to query for not-sourceURL enabled packages (Linux only pulls from Package Manager)
addPackagePin()
{
  say "addPackagePin: $*"
  local package="$1"

  local pinVersionJSONQuery='{"select":"packages","where":[{"attribute":"platform","value":"%s"},{"attribute":"name","value":"%s"},{"absent":"sourceUrl"},{"present":"version"}],"attribute":"version"}'
  if [ "$(getDistribution)" = "ubuntu" ]; then
    # mixing quotes... :-(
    local pinnedVersion="$(MetaconfigurationValue $(printf ${pinVersionJSONQuery} linux-deb $package))"
    local _outputfile=""
    say "Adding or updating version pin: /etc/apt/preferences.d/azsecpackpin-${package}.pref"
    if [ $SIMULATE -ne 0 ]; then
      _outputFile="/etc/apt/preferences.d/"
    else
      _outputFile="${AZSC}/pinning/"
      mkdir -p $_outputFile
    fi
    cat << EOF > ${_outputFile}/azsecpackpin-${package}.pref
Package: ${package}
Pin: version ${pinnedVersion}
Pin-Priority: 700 # Arbitrary number - Seven hundred ought to be enough
EOF
    return $?
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    say "Updating yum versionlock configuration to pin ${package}-${pinnedVersion}"
    local pinnedVersion="$(MetaconfigurationValue $(printf ${pinVersionJSONQuery} linux-rpm $package))"
    if [ $SIMULATE -ne 0 ]; then
      yum versionlock ${pin}-${pinnedVersion}
      if [ $? -ne 0 ]; then
        return 1
      fi
      echo "${pinnedVersion}" > /opt/microsoft/air-azsecpack/package-pins/${package}
      return $?
    else
      mkdir -p ${AZSC}/pinning
      echo "${pinnedVersion}" > ${AZSC}/pinning/${package}
    fi
  else
    return 1
  fi
  local installedVersion="$(queryPackageVersion $1)"
  if [ "${installedVersion}" != "${pinnedVersion}" ]; then
    # Install the pinned-specific version of the package
    QueuePackageInstall ${package}=${pinnedVersion}
  fi
}

configurePackagePinning()
{
  say "configurePackagePinning: $*"
  local existingPins=""
  if [ "$(getDistribution)" = "ubuntu" ]; then
    local configuredPinsJSONQuery='{"select":"packages","where":[{"attribute":"platform","value":"linux-deb"},{"absent":"sourceUrl"},{"present":"version"}],"attribute":"name"}'
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    local configuredPinsJSONQuery='{"select":"packages","where":[{"attribute":"platform","value":"linux-rpm"},{"absent":"sourceUrl"},{"present":"version"}],"attribute":"name"}'
    # Confirm rpm-based distro has the yum-versionlock plugin (old Azure images do not)
    if ! queryPackage 'yum-versionlock'; then
      if ! installPackage 'yum-versionlock'; then
        say "Unable to install required package: yum-versionlock"
        return 1
      fi
    fi
    # Add package pinning directory
    mkdir -p /opt/microsoft/air-azsecpack/package-pins
  else
    # TODO: error condition?
    return 1
  fi
  local configuredPins="$(MetaconfigurationValue ${configuredPinsJSONQuery})"

  # Get the currently configured pins
  currentPackagePins existingPins
    
  # Remove any pins that are configured locally, but not in the upstream
  for pin in ${existingPins}; do
    if ! echo "${configuredPins}" | grep -q ${pin}; then
      removePackagePin ${pin}
      if [ $? -ne 0 ]; then
        say "Unable to remove pin: ${pin}"
        return 1
      fi
    fi
  done

  # Add or update any pins that are configured upstream
  for pin in ${configuredPins}; do
    addPackagePin ${pin}
    if [ $? -ne 0 ]; then
      say "Unable to add pin: ${pin}"
      return 1
    fi
  done
}

# currentPackagePins [PINS_LIST]
currentPackagePins()
{
  local __resultvar=$1
  local existingPins=""

  if [ "$(getDistribution)" = "ubuntu" ]; then
    existingPins="$(find /etc/apt/preferences.d/ -name 'azsecpackpin-*.pref' -exec basename -s .pref {} \; | cut -d'-' -f2-)"
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    existingPins="$(ls /opt/microsoft/air-azsecpack/package-pins 2>/dev/null)"
  fi
    
	if [ ! -z "${__resultvar}" ]; then
		eval $__resultvar="'${existingPins}'"
	else
		echo "${existingPins}"
	fi
}

updateRepositoryCache()
{
  say "updateRepositoryCache: $*"
  say "Clearing repository cache..."
  if [ $SIMULATE -ne 0 ]; then
    if [ "$(getDistribution)" = "ubuntu" ]; then
      apt-get update >/dev/null
    elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
      yum clean expire-cache >/dev/null
      yum check-update >/dev/null
    else
      say "Unsupported distribution: $(getDistribution)"
      return 0
    fi
  fi
}

# We don't need to worry ourselves about making sure the list is unique, the package manager will do it for us.
# Same for version pinning, if that is necessary it will be configured before we invoke...
QueuePackageInstall()
{
  say "QueuePackageInstall(): ${*}"
  PACKAGES="${PACKAGES} ${*}"
}

InstallPackages()
{
  local _packageResult=0
  for package in $PACKAGES; do
    if echo "${package}" | grep -q '='; then
      local packageName="$(echo '${package}' | cut -d'=' -f1)"
      local packageVersion="$(echo '${package}' | cut -d'=' -f2)"
      local installedPackageVersion=$(queryPackageVersion ${packageName})
      if [ "${packageVersion}" != "${installedPackageVersion}" ]; then
        installPackage ${package}
        _packageResult=$(expr ${_packageResult} + $?)
        continue
      fi
    fi
    if ! queryPackage $package; then
      installPackage ${package}
        _packageResult=$(expr ${_packageResult} + $?)
    fi
  done
  return $_packageResult
}

QueuePackagesForInstall()
{
  say "QueuePackagesForInstall()"
  if [ "$(getDistribution)" = "ubuntu" ]; then
    local packagesJSONQuery='{"select":"packages","where":[{"attribute":"platform","value":"linux-deb"},{"absent":"sourceUrl"}],"attribute":"name"}'
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    local packagesJSONQuery='{"select":"packages","where":[{"attribute":"platform","value":"linux-rpm"},{"absent":"sourceUrl"}],"attribute":"name"}'
  else
    # TODO: error condition?
    return 1
  fi
  local _packageList="$(MetaconfigurationValue ${packagesJSONQuery})"
  for package in ${_packageList}; do
    QueuePackageInstall ${package}
  done 
}

DownloadGenevaCertificate()
{
  local certificateJSONQuery='{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"certificateUrl"}'
  curl -f -s -o ${AZSC}/certificate.pfx "$(MetaconfigurationValue ${certificateJSONQuery})"
  if [ $? -ne 0 ]; then
    return 1
  fi
  openssl pkcs12 -in ${AZSC}/certificate.pfx -out ${AZSC}/gcstempcert.pem -clcerts -nokeys -passin pass: >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    return 1
  fi
  openssl pkcs12 -in ${AZSC}/certificate.pfx -out ${AZSC}/gcstempkey.pem -nocerts -nodes -passin pass: >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    return 1
  fi
  # Just check if the certificate is readable *at all*
  if openssl x509 -noout -modulus -in ${AZSC}/gcstempcert.pem >/dev/null 2>&1; then
    M1=$(openssl x509 -noout -modulus -in ${AZSC}/gcstempcert.pem 2>/dev/null | openssl md5)
    M2=$(openssl rsa -noout -modulus -in ${AZSC}/gcstempkey.pem 2>/dev/null | openssl md5)
    if [ "${M1}" = "${M2}" ]; then
      say "Retrieved certificate and key appear to have been correctly retrieved and converted to PEM..."
      return 0
    else
      say "Error retrieving certificate: certificate and key PEM files do not result in cooresponding moduli."
      return 1
    fi
  else
      say "Error retrieving certificate: resultant PEM file unreadable."
      return 1
  fi
}

RemoveGenevaConfig()
{
  if [ $SIMULATE -ne 0 ]; then
    if [ -f /etc/default/mdsd ]; then
      say "Removing geneva configuration"
      rm -f /etc/default/mdsd
    fi
    if [ -f /etc/mdsd.d/gcscert.pem ] || [ -f /etc/mdsd.d/gcskey.pem ]; then
      say "Removing GCS certificate"
      rm -f /etc/mdsd.d/gcscert.pem 2>/dev/null
      rm -f /etc/mdsd.d/gcskey.pem 2>/dev/null
    fi
  fi
}

InstallGenevaConfig()
{
  if ! diff -q /etc/default/mdsd ${AZSC}/mdsd_defaults >/dev/null 2>&1; then
    say "/etc/default/mdsd configuration changed, updating..."
    RECYCLE_REQUIRED=0
    if [ $SIMULATE -ne 0 ]; then
      cp ${AZSC}/mdsd_defaults /etc/default/mdsd
      chown root /etc/default/mdsd
      chmod 644 /etc/default/mdsd
    fi
  else
    say "/etc/default/mdsd configuration OK"
  fi
  if ! diff -q ${AZSC}/gcstempcert.pem /etc/mdsd.d/gcscert.pem >/dev/null 2>&1 || ! diff -q ${AZSC}/gcstempkey.pem /etc/mdsd.d/gcskey.pem >/dev/null 2>&1; then
    say "GCS Certificates changed, updating..."
    RECYCLE_REQUIRED=0
    if [ $SIMULATE -ne 0 ]; then
      cp ${AZSC}/gcstempcert.pem /etc/mdsd.d/gcscert.pem
      cp ${AZSC}/gcstempkey.pem /etc/mdsd.d/gcskey.pem
      for certificateFile in /etc/mdsd.d/gcscert.pem /etc/mdsd.d/gcskey.pem; do
        chown syslog ${certificateFile} 
        chmod 400 ${certificateFile}
      done
    fi
  else
    say "certificates OK"
  fi
}

configureSyslog()
{
  say "configureSyslog: $*"
  if queryPackage 'syslog-ng'; then
    if serviceEnabled 'syslog-ng'; then
      say "This system appears to be using syslog-ng: executing config-mdsd syslog -e syslog-ng..."
      if [ $SIMULATE -ne 0 ]; then
        # It is syslog-ng
        config-mdsd syslog -e syslog-ng
      fi
    fi
  fi
}

handleAgentReplacement()
{
  say "handleAgentReplacement: $*"
  if queryPackage 'syslog-ng'; then
    if serviceEnabled 'syslog-ng'; then
      abort "This system appears to be using syslog-ng: aborting upgrade (Will not install azure-mdsd)"
    fi
  fi
  if queryPackage 'azsec-mdsd'; then
    say "This system appears to be using azsec-mdsd: Replacing with azure-mdsd..."
    if [ $SIMULATE -ne 0 ]; then
      removePackage azsec-mdsd
    fi
  fi
}

###############################################################################
#
#

ExtractJSONHelper()
{
  if [ ! -f ${AZSC}/jsonHelper.py ]; then
    sed -e '1,/^___MAGIC_JSONHELPER_BASE64_START___/d' -e '/^___MAGIC_JSONHELPER_BASE64_END___/,$d' $0 | base64 -d > ${AZSC}/jsonHelper.py
    if [ $? -ne 0 ]; then
      return 1
    fi
    chmod +x ${AZSC}/jsonHelper.py
    return $?
  fi
}

# Fetch our instance metadata
FetchMetadata()
{
  if [ ! -f ${AZSC}/metadata.json ]; then
    curl -f -s "http://169.254.169.254/metadata/instance?${IMDS_API_VERSION}" -H Metadata:true -o ${AZSC}/metadata.json
  fi
  return $?
}

FetchMetaConfiguration()
{
  if [ ! -f ${AZSC}/metaconfig.json ]; then
    say "Retriving JSON MetaConfiguration: https://airaspmetadata.azure-api.net/v1/Configuration/Iaas?subscriptionId=$(SubscriptionID)&resourceGroup=$(ResourceGroupName)&vmId=$(VMID)"
    curl -f -s "https://airaspmetadata.azure-api.net/v1/Configuration/Iaas?subscriptionId=$(SubscriptionID)&resourceGroup=$(ResourceGroupName)&vmId=$(VMID)" -o ${AZSC}/metaconfig.json 2>/dev/null
  fi
  return $?
}

jsonValue()
{
  local _result
  local __resultvar=$3
  if [ -f ${AZSC}/${1} ]; then
    _result=$(cat ${AZSC}/${1} | python -c "import sys, json; sys.stdout.write(json.load(sys.stdin)${2})")
    if [ $? -eq 0 ]; then
      if [ ! -z "${__resultvar}" ]; then
        eval $__resultvar="'${_result}'"
      else
        echo -n "${_result}"
      fi
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

MetadataValue()
{
  local _result
  if [ ! -f ${AZSC}/metadata.json ]; then
    FetchMetadata
    if [ $? -ne 0 ]; then
      return 1
    fi
  fi
  jsonValue metadata.json ${1} ${2}
  return $?
}

ResourceGroupName()
{
  local __resultvar=$1
  if [ -z "${ResourceGroupName+UNSET}" ]; then
    MetadataValue "['compute']['resourceGroupName']" ResourceGroupName 
    if [ $? -eq 0 ]; then
      if [ ! -z "${__resultvar}" ]; then
        eval $__resultvar="'${ResourceGroupName}'"
      else
        echo -n "${ResourceGroupName}"
      fi
      return 0
    else
      return 1
    fi
  fi
  if [ ! -z "${__resultvar}" ]; then
    eval $__resultvar="'${ResourceGroupName}'"
  else
    echo -n "${ResourceGroupName}"
  fi
  return 0
}

InstanceRegion()
{
  local __resultvar=$1
  if [ -z "${InstanceRegion+UNSET}" ]; then
    MetadataValue "['compute']['location']" InstanceRegion 
    if [ $? -eq 0 ]; then
      if [ ! -z "${__resultvar}" ]; then
        eval $__resultvar="'${InstanceRegion}'"
      else
        echo -n "${InstanceRegion}"
      fi
      return 0
    else
      return 1
    fi
  fi
  if [ ! -z "${__resultvar}" ]; then
    eval $__resultvar="'${InstanceRegion}'"
  else
    echo -n "${InstanceRegion}"
  fi
  return 0
}

SubscriptionID()
{
  local __resultvar=$1
  if [ -z "${SubscriptionID+UNSET}" ]; then
    MetadataValue "['compute']['subscriptionId']" SubscriptionID
    if [ $? -eq 0 ]; then
      if [ ! -z "${__resultvar}" ]; then
        eval $__resultvar="'${SubscriptionID}'"
      else
        echo -n "${SubscriptionID}"
      fi
      return 0
    else
      return 1
    fi
  fi
  if [ ! -z "${__resultvar}" ]; then
    eval $__resultvar="'${SubscriptionID}'"
  else
    echo -n "${SubscriptionID}"
  fi
  return 0
}

VMID()
{
  local __resultvar=$1
  if [ -z "${VMID+UNSET}" ]; then
    MetadataValue "['compute']['vmId']" VMID
    if [ $? -eq 0 ]; then
      if [ ! -z "${__resultvar}" ]; then
        eval $__resultvar="'${VMID}'"
      else
        echo -n "${VMID}"
      fi
      return 0
    else
      return 1
    fi
  fi
  if [ ! -z "${__resultvar}" ]; then
    eval $__resultvar="'${VMID}'"
   else
    echo -n "${VMID}"
  fi
  return 0
}

MetaconfigurationValue()
{
  if ! ExtractJSONHelper; then
    say "Could not extract JSON helper"
    return 1
  fi
  if ! FetchMetaConfiguration; then
    say "Could not fetch metaconfiguration"
    return 1
  fi
  local __resultvar=$2
  local _result
  _result="$(${AZSC}/jsonHelper.py ${AZSC}/metaconfig.json $1 2>/dev/null)"
  if [ $? -eq 0 ]; then
    if [ ! -z "${__resultvar}" ]; then
      eval $__resultvar="'${_result}'"
    else
      echo -n "${_result}"
    fi
    return 0
  else
    return 1
  fi
}

ServiceID()
{
  MetaconfigurationValue '{"select":"serviceId"}' $1
  return $?
}

CollectLogs()
{
  MetaconfigurationValue '{"select":"collectLogs"}' $1
  return $?
}

GenevaNamespaceName()
{
  MetaconfigurationValue '{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"namespace"}' $1
  return $?
}

GenevaAccountName()
{
  MetaconfigurationValue '{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"accountName"}' $1
  return $? 
}

GenevaConfigurationVersion()
{
  MetaconfigurationValue '{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"genevaConfigurationVersion"}' $1
  return $?
}

GenevaTenant()
{
  local __resultvar=$1
  MetaconfigurationValue '{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"genevaTenant"}' _tenant
  if [ -z "${_tenant}" ]; then
    _tenant="$(ServiceID | cut -c 1-8)"
  fi
  # ServiceID() conceivably could have failed, ensure _role really got set, or error
  if [ -z "${_tenant}" ]; then
    return 1
  else
    if [ ! -z "${__resultvar}" ]; then
      eval $__resultvar="'${_tenant}'"
    else
      echo "${_tenant}"
    fi
    return 0
  fi
}

GenevaRole()
{
  local __resultvar=$1
  MetaconfigurationValue '{"select":"endpoints","where":[{"attribute":"platform","value":"linux"},{"attribute":"type","value":"WarmPath"}],"attribute":"genevaRole"}' _role
  if [ -z "${_role}" ]; then
    _role="$(SubscriptionID | cut -c 1-8)"
  fi
  # SubscriptionID() conceivably could have failed, ensure _role really got set, or error
  if [ -z "${_role}" ]; then
    return 1
  else
    if [ ! -z "${__resultvar}" ]; then
      eval $__resultvar="'${_role}'"
    else
      echo "${_role}"
    fi
    return 0
  fi
}

AutoUpdateEnabled()
{
  MetaconfigurationValue '{"select":"pollingWindow.startHour"}' configuredStartHour
  if [ $? -ne 0 ]; then
    return 1
  fi
  MetaconfigurationValue '{"select":"pollingWindow.endHour"}' configuredEndHour
  if [ $? -ne 0 ]; then
    return 1
  fi
  if [ $configuredStartHour -eq $configuredEndHour ]; then
    say "AutoUpdate is currently disabled"
    return 1
  else
    say "AutoUpdate is currently enabled"
    return 0
  fi
}

ConfigureCron()
{
  if ! cronOK; then
    WriteCronFile
    return $?
  else
    return 0
  fi
}

cronOK()
{
  # If it doesn't exist, always write...
  if [ ! -f /etc/cron.d/air-azsecpack ]; then
    return 1
  fi
  MetaconfigurationValue '{"select":"pollingWindow.startHour"}' configuredStartHour
  if [ $? -ne 0 ]; then
    say "Unable to retrieve polling Start Hour for cron configuration..."
    return 1
  fi
  MetaconfigurationValue '{"select":"pollingWindow.endHour"}' configuredEndHour
  if [ $? -ne 0 ]; then
    say "Unable to retrieve polling End Hour for cron configuration..."
    return 1
  fi
  
  currentPollHour=$(grep -v '^#' /etc/cron.d/air-azsecpack | grep '^[0-9]\{1,2\} [0-9]\{1,2\} \* \* \* /opt/microsoft/air-azsecpack/installAIRGeneva.sh' | cut -d' ' -f2)
  currentPollMinute=$(grep -v '^#' /etc/cron.d/air-azsecpack | grep '^[0-9]\{1,2\} [0-9]\{1,2\} \* \* \* /opt/microsoft/air-azsecpack/installAIRGeneva.sh' | cut -d' ' -f1)

  configuredLocalStart=""
  configuredLocalEnd=""
  halfHourOffset=""

  TranslateUTCToLocal $configuredStartHour configuredLocalStart halfHourOffset
  TranslateUTCToLocal $configuredEndHour configuredLocalEnd halfHourOffset

  correctTimeFlag=1

  # File unreadable
  if [ -z "${currentPollHour}" ] || [ -z "${currentPollMinute}" ]; then
    return 1
  fi

  # If we are in a weird timezone....
  if [ $halfHourOffset -eq 0 ]; then
    if [ $configuredStartHour -gt $configuredEndHour ]; then
      if [ $currentPollHour -gt $configuredLocalStart ] || [ $currentPollHour -lt $configuredLocalEnd ]; then
        # Spans midnight, in a middle hour 
        correctTimeFlag=0
      elif [ $currentPollHour -eq $configuredLocalStart ] && [ $currentPollMinute -ge 30 ]; then
        # In the first hour, after minute 30
        correctTimeFlag=0
      elif [ $currentPollHour -eq $configuredLocalEnd ] && [ $currentPollMinute -lt 30 ]; then
        # In the last hour, before minute 30
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    elif [ $configuredEndHour -gt $configuredStartHour ]; then
      if [ $currentPollHour -gt $configuredLocalStart ] && [ $currentPollHour -lt $configuredLocalEnd ]; then
        # Does not span midnight, in a middle hour 
        correctTimeFlag=0
      elif [ $currentPollHour -eq $configuredLocalStart ] && [ $currentPollMinute -ge 30 ]; then
        # In the first hour, after minute 30
        correctTimeFlag=0
      elif [ $currentPollHour -eq $configuredLocalEnd ] && [ $currentPollMinute -lt 30 ]; then
        # In the last hour, before minute 30
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    else
      # Start and end are the same 
      if [ $currentPollHour -eq $configuredLocalStart ] && [ $currentPollMinute -ge 30 ]; then
        # In the first hour, after minute 30
        correctTimeFlag=0
      elif [ $currentPollHour -eq $(expr $configuredLocalEnd + 1 ) ] && [ $currentPollMinute -lt 30 ]; then
        # In the last hour, before minute 30
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    fi
  else
    # Not weird time zone
    if [ $configuredStartHour -gt $configuredEndHour ]; then
      # Spans midnight
      if [ $currentPollHour -ge $configuredLocalStart ] || [ $currentPollHour -lt $configuredLocalEnd ]; then
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    elif [ $configuredEndHour -gt $configuredStartHour ]; then
      # Does not span midnight
      if [ $currentPollHour -ge $configuredLocalStart ] && [ $currentPollHour -lt $configuredLocalEnd ]; then
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    else
      # Start time and end time are equal, so we only check one
      if [ $currentPollHour -eq $configuredLocalStart ]; then
        correctTimeFlag=0
      else
        correctTimeFlag=1
      fi
    fi
  fi

  if ! AutoUpdateEnabled; then
    if [ $correctTimeFlag -eq 0 ]; then
      say "AutoUpdate is currently disabled, periodic recheck is configured correctly"
      return 0
    else
      say "AutoUpdate is currently disabled, but periodic check is not configured correctly"
      return 1
    fi
  else
    if [ $correctTimeFlag -eq 0 ]; then
      # Everything is good
      say "AutoUpdate is enabled, periodic check is configured correctly"
      return 0
    else
      say "AutoUpdate is enabled, but periodic check is not configured correctly"
      return 1
    fi
  fi
}

TranslateUTCToLocal()
{
  local requestedTime=$1
  local hourOut=$2
  # For timezones aligned to :30, set true
  local halfHourOffsetFlag=$3
  # Set reasonable assumptions
  eval $halfHourOffsetFlag=1
  local _mOffset=1

  # TranslateUTCToLocal 7 hour offset30
  local tzOffset=$(date +%::z | cut -d':' -f1 | tr -d +)
  local minuteOffset=$(date +%::z | cut -d':' -f2)

  # Fix half-hour offset if necessary
  if [ $minuteOffset != "00" ]; then
    eval $halfHourOffsetFlag=0
    _mOffset=0
    if [ ${tzOffset} -lt 0 ]; then
      # We need to increase the magnitude, to account for the extra 30 minutes we are subtracting....
      tzOffset=$(expr ${tzOffset} - 1)
    fi
  fi

  hourOffset=$(expr ${requestedTime} + ${tzOffset})
  if [ ${hourOffset} -ge 24 ]; then
    hourOffset=$(expr ${hourOffset} - 24)
  elif [ ${hourOffset} -lt 0 ]; then
    hourOffset=$(expr ${hourOffset} + 24)
  fi

  # Output our hour...
  eval $hourOut=$hourOffset
}

WriteCronFile()
{
  local outputDirectory
  if [ $SIMULATE -eq 0 ]; then
    outputDirectory="${AZSC}/"
  else
    outputDirectory="/etc/cron.d/"
  fi
  MetaconfigurationValue '{"select":"pollingWindow.startHour"}' configuredStartHour
  if [ $? -ne 0 ]; then
    say "WriteCronFile(): Unable to retrieve polling Start Hour for cron configuration...: ${configuredStartHour}"
    return 1
  fi
  MetaconfigurationValue '{"select":"pollingWindow.endHour"}' configuredEndHour
  if [ $? -ne 0 ]; then
    say "WriteCronFile(): Unable to retrieve polling End Hour for cron configuration..."
    return 1
  fi

  if ! AutoUpdateEnabled ; then
    say "AutoUpdate is currently disabled, configuring periodic re-check"
    local _pollHour=${configuredStartHour}
  else
    # We need to select a random hour between the desired start and end.  Two scenarios:  the times cross midnight, or they do not...
    if [ $configuredStartHour -gt $configuredEndHour ]; then
      # Crosses midnight
      local _duration=$(expr \( 24 - ${configuredStartHour} \) + ${configuredEndHour})
    else
      # Does not cross midnight
      local _duration=$(expr $configuredEndHour - $configuredStartHour)
    fi
    local _pollHour=$(expr \( $(od -An -N1 -i /dev/urandom) % ${_duration} \) + ${configuredStartHour})
  fi

  # Select a random minute during which the configuration should be re-polled.  The minutes at the
  # top of the hour (58, 59, 00, 01, 02, 03) will not be selected.
  local _randomMinute=$(expr \( $(od -An -N1 -i /dev/urandom) % 55 \) + 3)

  # Normalize to UTC time...
  local _utcHour
  _utcHalfHourOffset=""
  TranslateUTCToLocal $_pollHour _utcHour _utcHalfHourOffset
  # If we are in a weird timezone....
  if [ $_utcHalfHourOffset -eq 0 ]; then
    if [ $configuredStartHour -eq $configuredEndHour ]; then
      if [ $_randomMinute -lt 30 ]; then
        _utcHour=$(expr $_utcHour + 1)
      fi
    else
      # If the selected poll hour is the first one (before translation to UTC)
      if [ $_pollHour -eq $configuredStartHour ] && [ $_randomMinute -lt 30 ]; then
        _utcHour=$(expr $_utcHour + 1)
      # If the select poll hour is the last one (before translation to UTC)
      elif [ $_pollHour -eq $configuredEndHour ] && [ $_randomMinute -ge 30 ]; then
        _utcHour=$(expr $_utcHour - 1)
      fi
    fi
  fi

  # If we are into the next or previous morning...
  if [ $_utcHour -ge 24 ]; then
    _utcHour=$(expr $_utcHour - 24)
  elif [ $_utcHour -lt 0 ]; then
    _utcHour=$(expr $_utcHour + 24)
  fi

  say "Configuring Cron job for ${_utcHour}:${_randomMinute}"

  cat <<-EOF >${outputDirectory}/air-azsecpack
# This file is dynamically generated/maintained
# To update the polling time, contact AIR AzSecPack V-Team (airazsecpack@microsoft.com)
${_randomMinute} ${_utcHour} * * * /opt/microsoft/air-azsecpack/installAIRGeneva.sh >/dev/null 2>&1
EOF
return $?
}

InstallScript()
{
  if ! LaunchedFromInstalledLocation; then
    if [ $SIMULATE -ne 0 ]; then
      mkdir -p /opt/microsoft/air-azsecpack/
      cp $0 /opt/microsoft/air-azsecpack/installAIRGeneva.sh
      return $?
    else
      return 0
    fi
  else
    return 0
  fi
}

###############################################################################
#
#

GenevaConfiguration()
{
  local _GenevaAccountName
  local _InstanceRegion
  local _GenevaNamespaceName
  local _GenevaConfigurationVersion
  local _GenevaTenant
  local _GenevaRole

  GenevaAccountName _GenevaAccountName
  if [ $? -ne 0 ]; then
    say "GenevaAccountName failed: ${_GenevaAccountName}"
    return 1
  fi
  InstanceRegion _InstanceRegion
  if [ $? -ne 0 ]; then
    return 1
  fi
  GenevaNamespaceName _GenevaNamespaceName
  if [ $? -ne 0 ]; then
    return 1
  fi
  GenevaConfigurationVersion _GenevaConfigurationVersion
  if [ $? -ne 0 ]; then
    return 1
  fi
  GenevaTenant _GenevaTenant
  if [ $? -ne 0 ]; then
    return 1
  fi
  GenevaRole _GenevaRole
  if [ $? -ne 0 ]; then
    return 1
  fi

  cat <<-EOF >${AZSC}/mdsd_defaults
# Check 'mdsd -h' for details.

MDSD_ROLE_PREFIX=/var/run/mdsd/default

# MDSD_OPTIONS="-d -r \${MDSD_ROLE_PREFIX}"

MDSDLOG=/var/log

MDSD_OPTIONS="-A -c /etc/mdsd.d/mdsd.xml -d -r \$MDSD_ROLE_PREFIX -e \$MDSDLOG/mdsd.err -w \$MDSDLOG/mdsd.warn -o \$MDSDLOG/mdsd.info"

export SSL_CERT_DIR=/etc/ssl/certs

export MONITORING_GCS_ENVIRONMENT=DiagnosticsProd

export MONITORING_GCS_ACCOUNT=${_GenevaAccountName}

export MONITORING_GCS_REGION=${_InstanceRegion}

# or, pulling data from IMDS

# imdsURL="http://169.254.169.254/metadata/instance/compute/location?api-version=2017-04-02&format=text"

# export MONITORING_GCS_REGION="\$(curl -H Metadata:True --silent $imdsURL)"

# see https://jarvis.dc.ad.msft.net/?section=b7a73824-bbbf-49fc-8c3e-a97c27a7659e&page=documents&id=66b7e29f-ddd6-4ab9-ad0a-dcd3c2561090 

export MONITORING_GCS_CERT_CERTFILE=/etc/mdsd.d/gcscert.pem   # update for your cert on disk

export MONITORING_GCS_CERT_KEYFILE=/etc/mdsd.d/gcskey.pem     # update for your private key on disk

# Below are to enable GCS config download

export MONITORING_GCS_NAMESPACE=${_GenevaNamespaceName}

export MONITORING_CONFIG_VERSION=${_GenevaConfigurationVersion}

export MONITORING_TENANT=${_GenevaTenant}

export MONITORING_ROLE=${_GenevaRole}

export MONITORING_ROLE_INSTANCE=$(hostname | tr [a-z] [A-Z])
EOF
return $?
}

InstallationProcess()
{
  if ! FetchMetaConfiguration; then
    abort "Unable to retrieve Geneva meta-configuration"
  fi
  if ! GenevaConfiguration; then
    abort "Unable to synthesize Geneva MDSD configuration file"
  fi
  if ! DownloadGenevaCertificate; then
    abort "Unable to retrieve GCS authentication certificate"
  fi
  if ! handleAgentReplacement; then
    abort "Unable to replace azsec-mdsd"
  fi
  if ! configurePackagePinning; then
    abort "Unable to apply package pinning configuration"
  fi
  if ! QueuePackagesForInstall; then
    abort "Unable to queue necessary packages for installation"
  fi
  # Documentation specifies auditd as a first step, package name varies on distribution...
  if [ "$(getDistribution)" = "ubuntu" ]; then
      if ! queryPackage auditd; then
        installPackage auditd 
        if ! installPackage auditd; then
          abort "Unable to install required package: auditd"
        fi
      fi
  # Note: package name is 'audit', not 'auditd'
  elif [ "$(getDistribution)" = "rhel" ] || [ "$(getDistribution)" = "centos" ] || [ "$(getDistribution)" = "oracle" ]; then
    if ! queryPackage audit; then
      if ! installPackage audit; then
        abort "Unable to install required package: audit"
      fi
    fi
  fi
  # Add our repository so that we can get the Geneva packages
  addRepositories
  if ! InstallPackages; then
    abort "Unable to install Geneva and AzSecPack packages"
  fi
  if ! InstallGenevaConfig; then
    abort "Unable to install Geneva configuration and authentication certificate"
  fi
  if ! enableService mdsd azsecd; then
    abort "Unable to enable mdsd and/or azsecd services"
  fi
  if ! startService mdsd azsecd; then
    abort "Unable to start mdsd and/or azsecd services"
  fi
}

install()
{
  if [ $SIMULATE -eq 0 ]; then
    echo "Temporary Directory: ${AZSC}"
  fi

  # Make sure the cron configuration is correct, e.g. if an update was made
  # such as disabling auto-update
  if ! InstallScript; then
    abort "Unable to install script for periodic refresh of AzSecPack configuration"
  fi
  # Make sure the cron configuration is correct, e.g. if an update was made
  # such as disabling auto-update
  if ! ConfigureCron; then
    abort "Unable to configure cron job for periodic refresh of AzSecPack configuration"
  fi
  if IsAncestor 'cron'; then
    if AutoUpdateEnabled; then
      InstallationProcess
    fi
  else
    # We were not launched from a cron job, so run the install process
    InstallationProcess
  fi
  return 0
}

uninstall()
{
  if ! stopService mdsd azsecd; then
    abort "Unable to stop services mdsd and azsecd"
  fi
  if ! disableService mdsd azsecd ; then
    abort "Unable to disable services mdsd and azsecd"
  fi
  if ! removeGenevaConfig ; then
    abort "Unable to remove Geneva configuration"
  fi
}

###############################################################################
#
# Default Values and Magic Variables
#
SCRIPT_NAME="$(basename ${0})"
SCRIPT_DIR="$(dirname $(readlink -f ${0}))"
IMDS_API_VERSION="api-version=2019-06-04"
SIMULATE=1
SAVETMP=1
SHORT_SLEEP=5
LONG_SLEEP=60
RECYCLE_REQUIRED=1
UNINSTALL=1
###############################################################################
#
# Check if script is being run as root
#
if [ $(id -u) -ne 0 ]; then
  echo "Script must be run as root"
  exit 1
fi
#
# Generate a log file and upload it...
#
ORIGINAL_ARGUMENTS="$*"
while getopts ":d:hstu" OPT; do
  case "${OPT}" in
    d)
      AZSC=${OPTARG}
      ;;
    h)
      usage
      ;;
    s)
      SIMULATE=0
      ;;
    t)
      SAVETMP=0
      ;;
    u)
      UNINSTALL=0
      ;;
    *)
      usage "Unrecognized option: ${OPTARG}"
      ;;
  esac
done
shift $(($OPTIND-1))

if [ $# -gt 0 ]; then
  usage "Unrecognized argument(s): $*"
fi
if ! IsAncestor ${SCRIPT_NAME}; then
  echo "Spawning wrapped script instance to capture transcript"
  AZSC=$(mktemp -d)
  # Due to wrapped script, we need to preserve stdout and stderr separately if we want a transcript
  LOGFILE=${AZSC}/log
  OUTFILE=${AZSC}/log.out
  ERRFILE=${AZSC}/log.err
  ${0} ${ORIGINAL_ARGUMENTS} -d ${AZSC} > ${OUTFILE} 2> ${ERRFILE}
  # Merge output logs
  cat ${OUTFILE} ${ERRFILE} > ${LOGFILE}
  # Write messages to stdout
  cat ${OUTFILE}
  # Write errors to stderr
  err $(cat ${ERRFILE})
  RESULT=$?
  CollectLogs=$(CollectLogs)
  #if [ ${RESULT} -ne 0 ] || [ ${CollectLogs} = "true" ]; then 
    echo "Uploading transcript to AIR MetaConfig service"
    uploadTranscript
  #fi
  # Remove our temporary directory
  if [ -d $AZSC ]; then
    if [ $SAVETMP -ne 0 ]; then
      rm -rf $AZSC
    fi
  fi
else
  if [ $UNINSTALL -eq 0 ]; then
    uninstall
    RESULT=$?
  else
    install
    RESULT=$?
  fi
fi
exit $RESULT
# This base64-encoded string is a small python script to help with
# extracting values from JSON.  The base system isn't guaranteed to
# include a suitable JSONpath tool, and we want to avoid installing
# extra packages.  This is limited, but sufficient for our needs.
___MAGIC_JSONHELPER_BASE64_START___
IyEvdXNyL2Jpbi9lbnYgcHl0aG9uCgppbXBvcnQgc3lzCmltcG9ydCBqc29uCgpQWTIgPSBzeXMu
dmVyc2lvbl9pbmZvWzBdID09IDIKUFkzID0gc3lzLnZlcnNpb25faW5mb1swXSA9PSAzCgppZiBQ
WTM6CiAgc3RyaW5nX3R5cGUgPSBzdHIKZWxzZToKICBzdHJpbmdfdHlwZSA9IGJhc2VzdHJpbmcK
CmRlZiBzZWxlY3RSZXN1bHRWYWx1ZXMoanNvblRvU2VhcmNoLCBlbGVtZW50UGF0aCk6CiAgbWF0
Y2hlcyA9IFtdCiAgaWYgZWxlbWVudFBhdGhbMF0gaW4ganNvblRvU2VhcmNoOgogICAgaWYgbGVu
KGVsZW1lbnRQYXRoKT09MToKICAgICAgaWYgaXNpbnN0YW5jZShqc29uVG9TZWFyY2hbZWxlbWVu
dFBhdGhbMF1dLCBzdHJpbmdfdHlwZSk6CiAgICAgICAgbWF0Y2hlcy5hcHBlbmQoanNvblRvU2Vh
cmNoW2VsZW1lbnRQYXRoWzBdXSkKICAgICAgICByZXR1cm4gbWF0Y2hlcwogICAgICBlbHNlOgog
ICAgICAgIHJldHVybiBqc29uVG9TZWFyY2hbZWxlbWVudFBhdGhbMF1dIAogICAgZWxzZToKICAg
ICAgcmV0dXJuIHNlbGVjdFJlc3VsdFZhbHVlcyhqc29uVG9TZWFyY2hbZWxlbWVudFBhdGhbMF1d
LCBlbGVtZW50UGF0aFsxOl0pCiAgZWxzZToKICAgIHJhaXNlIEV4Y2VwdGlvbigiUmVxdWVzdGVk
IGVsZW1lbnQgc2V0IG5vdCBhdmFpbGFibGUgaW4gSlNPTiB0byBzZWFyY2giKQoKZGVmIGZpbHRl
clJlc3VsdFZhbHVlcyh2YWx1ZXNUb0ZpbHRlciwgZmlsdGVyRGVmcyk6CiAgZXh0YW50QXR0cmli
dXRlRmlsdGVyID0gRmFsc2UKICBzZWFyY2ggPSB2YWx1ZXNUb0ZpbHRlcgogIG1hdGNoZXMgPSBz
ZWFyY2ggCiAgZm9yIGZpbHRlckRlZiBpbiBmaWx0ZXJEZWZzOgogICAgaWYgJ2Fic2VudCcgaW4g
ZmlsdGVyRGVmOgogICAgICBleHRhbnRBdHRyaWJ1dGVGaWx0ZXIgPSBUcnVlCiAgICAgIGNvbnRp
bnVlCiAgICBpZiAncHJlc2VudCcgaW4gZmlsdGVyRGVmOgogICAgICBleHRhbnRBdHRyaWJ1dGVG
aWx0ZXIgPSBUcnVlCiAgICAgIGNvbnRpbnVlCiAgICBzZWFyY2ggPSBtYXRjaGVzCiAgICBtYXRj
aGVzID0gW10KICAgIGZvciB2IGluIHNlYXJjaDoKICAgICAgaWYgdltmaWx0ZXJEZWZbJ2F0dHJp
YnV0ZSddXSA9PSBmaWx0ZXJEZWZbJ3ZhbHVlJ106CiAgICAgICAgbWF0Y2hlcy5hcHBlbmQodikK
ICBpZiBleHRhbnRBdHRyaWJ1dGVGaWx0ZXIgPT0gVHJ1ZToKICAgIGZvciBmaWx0ZXJEZWYgaW4g
ZmlsdGVyRGVmczoKICAgICAgaWYgJ2Fic2VudCcgaW4gZmlsdGVyRGVmOgogICAgICAgIHNlYXJj
aCA9IG1hdGNoZXMKICAgICAgICBtYXRjaGVzID0gW10KICAgICAgICBmb3IgdiBpbiBzZWFyY2g6
CiAgICAgICAgICBpZiBub3QgZmlsdGVyRGVmWydhYnNlbnQnXSBpbiB2OgogICAgICAgICAgICBt
YXRjaGVzLmFwcGVuZCh2KQogICAgICBpZiAncHJlc2VudCcgaW4gZmlsdGVyRGVmOgogICAgICAg
IHNlYXJjaCA9IG1hdGNoZXMKICAgICAgICBtYXRjaGVzID0gW10KICAgICAgICBmb3IgdiBpbiBz
ZWFyY2g6CiAgICAgICAgICBpZiBmaWx0ZXJEZWZbJ3ByZXNlbnQnXSBpbiB2OgogICAgICAgICAg
ICBtYXRjaGVzLmFwcGVuZCh2KQogIHJldHVybiBtYXRjaGVzCgpkZWYgc2VsZWN0UmVzdWx0QXR0
cmlidXRlKHBvcHVsYXRpb25Ub1NlbGVjdCwgYXR0cmlidXRlKToKICBtYXRjaGVzID0gW10KICBm
b3IgaXRlbSBpbiBwb3B1bGF0aW9uVG9TZWxlY3Q6CiAgICBpZiBQWTM6CiAgICAgIGZvciBrLCB2
IGluIGl0ZW0uaXRlbXMoKToKICAgICAgICBpZiBrID09IGF0dHJpYnV0ZToKICAgICAgICAgIG1h
dGNoZXMuYXBwZW5kKHYpCiAgICBlbHNlOgogICAgICBmb3IgaywgdiBpbiBpdGVtLml0ZXJpdGVt
cygpOgogICAgICAgIGlmIGsgPT0gYXR0cmlidXRlOgogICAgICAgICAgbWF0Y2hlcy5hcHBlbmQo
dikKICByZXR1cm4gbWF0Y2hlcwoKIyBXZSBkb24ndCBuZWVkIG91ciBvd24gcGF0aC4uLgpzeXMu
YXJndi5wb3AoMCkKIyBGaXJzdCBhcmd1bWVudCBpcyB0aGUgcGF0aCB0byB0aGUganNvbiBmaWxl
Cmpzb25GaWxlUGF0aCA9IHN5cy5hcmd2LnBvcCgwKQoKd2l0aCBvcGVuKGpzb25GaWxlUGF0aCkg
YXMganNvbkZpbGU6CiAganNvbkRhdGEgPSBqc29uLmxvYWQoanNvbkZpbGUpCgpyZXN1bHRWYWx1
ZXMgPSBqc29uRGF0YSAKCmlmIGxlbihzeXMuYXJndikgIT0gMDoKICBzZWFyY2hEYXRhID0ganNv
bi5sb2FkcyhzeXMuYXJndi5wb3AoMCkpCiAgaWYgJ3NlbGVjdCcgaW4gc2VhcmNoRGF0YToKICAg
IHJlc3VsdFZhbHVlcyA9IHNlbGVjdFJlc3VsdFZhbHVlcyhyZXN1bHRWYWx1ZXMsIHNlYXJjaERh
dGFbJ3NlbGVjdCddLnNwbGl0KCIuIikpCiAgaWYgJ3doZXJlJyBpbiBzZWFyY2hEYXRhOgogICAg
cmVzdWx0VmFsdWVzID0gZmlsdGVyUmVzdWx0VmFsdWVzKHJlc3VsdFZhbHVlcywgc2VhcmNoRGF0
YVsnd2hlcmUnXSkKICBpZiAnYXR0cmlidXRlJyBpbiBzZWFyY2hEYXRhOgogICAgcmVzdWx0VmFs
dWVzID0gc2VsZWN0UmVzdWx0QXR0cmlidXRlKHJlc3VsdFZhbHVlcywgc2VhcmNoRGF0YVsnYXR0
cmlidXRlJ10pCgppZiBpc2luc3RhbmNlKHJlc3VsdFZhbHVlcywgc3RyaW5nX3R5cGUpIG9yIGlz
aW5zdGFuY2UocmVzdWx0VmFsdWVzLCBpbnQpOgogIHByaW50KHJlc3VsdFZhbHVlcykKZWxzZToK
ICBpZiBsZW4ocmVzdWx0VmFsdWVzKSA9PSAwOgogICAgc3lzLmV4aXQoMSkKICBlbHNlOgogICAg
Zm9yIHJlc3VsdCBpbiByZXN1bHRWYWx1ZXM6CiAgICAgIGlmIGlzaW5zdGFuY2UocmVzdWx0LCBz
dHJpbmdfdHlwZSkgb3IgaXNpbnN0YW5jZShyZXN1bHQsIGludCk6CiAgICAgICAgcHJpbnQocmVz
dWx0KQogICAgICBlbHNlOgogICAgICAgIGlmIG5vdCByZXN1bHQgaXMgTm9uZToKICAgICAgICAg
IHByaW50KGpzb24uZHVtcHMocmVzdWx0KSkK
___MAGIC_JSONHELPER_BASE64_END___

