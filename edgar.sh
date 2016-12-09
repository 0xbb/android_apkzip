#!/bin/sh
#!/system/bin/sh
# Swap the above two lines as appropriate: Linux: /bin/sh; Android: /system/bin/sh
#http://android.stackexchange.com/questions/143304

#This variable is used to calculate the time took by the various operations
#Altering it will result in badly calculated elapsed time
SECONDS=0

#This variable saves the path where the script resides
#DO NOT ALTER IT, or the whole script will fail with unpredictable errors
scriptDir="$(dirname "$(readlink -f "$0")")"

# This defines the name of the created ZIP
ZIPFILE="$scriptDir/edgar.zip"

# This defines the name of the temporary directory where
# the ZIP structure will be built
ZIPDIR="$ZIPFILE.dir"

# This defines the name of an optional file containing custom commands
# If present, the contents of this file is appended to the install
# script before it unmounts the system partition
CUSTOMFILE="$scriptDir/custom.sh"

rm -rf "$ZIPDIR" "$ZIPFILE" # Uncomment to automatically remove pre-existing ZIP

#This defines the path to the update-binary within the ZIPDIR
UPDATE_BINARY="$ZIPDIR/META-INF/com/google/android/update-binary"

#Helper function to abort: prints fatal error message and exits
abort() { echo '[FATAL] '$*; exit 1; }

#Aborts unless listed dependencies are satisfied
depend() {
  for dep in "$@"
  do
    which "${dep}" &> /dev/null || \
      abort 'Missing dependency '${dep}' (required: '$@')'
  done
}

#This function relies on aapt, and is meant to retrieve the app's name from the given APK
#///Beginning of function "appNameRetriever"///
#Sets globals $displayedName to the app name with whitespace intact
#             $appName to the app name with whitespace removed
#             $apkFile to the path passed in as $1
function appNameRetriever {
 echo "[INFO] Retrieving app name from $1..."
 apkFile="$1"
 appName="$(aapt d badging "$apkFile")"
 appName="${appName#*application-label:\'}"
 appName="${appName//app*/}"
 appName="${appName%\'*}"
 displayedName=$appName
 appName="$(printf "%s" $appName)"
}
#///End of function "appNameRetriever"///

#This function creates the directory structure required inside ZIP
init() {
  [[ -e "$1" ]] && abort "Cannot initialize '$1'; already exists"
  echo "[INFO] Initializing ZIP structure..."
  mkdir -p "$ZIPDIR/META-INF/com/google/android"
}
#///End of function "folderTreeCreator"///

add_apk() {
 echo "[INFO] Adding $appName..."
 mkdir -p "$ZIPDIR/$appName"
 cp "$apkFile" "$ZIPDIR/$appName/$appName.apk"
}

#This function creates a dummy updater-script, which serves mainly for aesthetical purposes
#///Beginning of function "updaterScriptCreator"///
function updaterScriptCreator {
 echo "[INFO] Creating dummy updater-script..."
 echo -n "#This is a dummy file. The magic is in the update-binary, which is a shell script." > "$ZIPDIR/META-INF/com/google/android/updater-script"
}
#///End of function "updaterScriptCreator"///

#=== BEGINNING OF "update-binary" WRITING SECTION ===
#From now on, the functions whose name begins with "sectionWriter", are used to assemble the update-binary

#This function writes the function and variables used for outputting things when flashing, to update-binary
#Thanks to Chainfire @ XDA, which seems to have been the first to implement them
#///Beginning of function "sectionWriter_header"///
function sectionWriter_header {
 echo "[INFO] Writing variables and function prototypes to update-binary..."
 cat <<-EOF > "$ZIPDIR/META-INF/com/google/android/update-binary"
#!/sbin/sh

OUTFD=\$2
ZIP=\$3

ui_print() {
 echo -ne "ui_print \$1\n" > /proc/self/fd/\$OUTFD
 echo -ne "ui_print\n" > /proc/self/fd/\$OUTFD
}

get_buildprop() {
 prop=\$(grep "\${1//./\\.}=" /system/build.prop)
 echo "\${prop#*=}"
}

ui_print ""
ui_print "******************************"
ui_print " APK Flashable ZIP "
ui_print " made by EDGAR, written by "
ui_print " Death Mask Salesman "
ui_print "******************************"
ui_print ""
EOF
}
#///End of function "sectionWriter_header"///

#This function writes the title of the app (which contains the human-readable app name of the APK), to update-binary
#///Beginning of function "sectionWriter_zipName"///
function sectionWriter_appName {
 echo "[INFO] Writing script title to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
ui_print ""
ui_print "******************************"

EOF
}
#///End of function "sectionWriter_zipName"///

#This function writes the instructions necessary to mount the system partition in read-write mode, to update-binary
#///Beginning of function "sectionWriter_systemRwMount"///
function sectionWriter_systemRwMount {
 echo "[INFO] Writing mount instructions to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
ui_print "~ Mounting /system in read-write mode..."
mount /system
mount -o remount,rw /system
ui_print ""

EOF
}
#///End of function "sectionWriter_systemRwMount"///

#This function writes the instructions to check for the Android version, to update-binary
#Notice that only JB, KK, LP and MM are supported, for now. That means a vast plethora of devices
#///Beginning of function "sectionWriter_osVersionChecker"///
function sectionWriter_osVersionChecker {
 echo "[INFO] Writing OS checking instructions to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
ui_print "~ Checking Android version..."
androidVersion="\$(get_buildprop 'ro.build.version.release')"

case "\$androidVersion" in
 4.1*|4.1.*|4.2*|4.2.*|4.3*|4.3.*)
  ui_print "~ Android Jelly Bean (\$androidVersion) detected: proceeding."
  ;;
 4.4*|4.4.*)
  ui_print "~ Android KitKat (\$androidVersion) detected: proceeding."
  ;;
 5*|5.*|5.*.*)
  ui_print "~ Android Lollipop (\$androidVersion) detected: proceeding."
  ;;
 6*|6.*|6.*.*)
  ui_print "~ Android Marshmallow (\$androidVersion) detected: proceeding."
  ;;
 *)
  ui_print "~ Your Android version (\$androidVersion) is either obsolete or still unsupported."
  ui_print "~ Unmounting /system and aborting."
  umount /system
  exit
  ;;
esac

EOF
}
#///End of function "sectionWriter_osVersionChecker"///

#This function gets the list of supported ABI versions (CPU Architecture)
#in increasing order of preference
#///Beginning of function "sectionWriter_getAbiList
function sectionWriter_getAbiList {
  echo "[INFO] Writing getAbi instructions to update-binary..."
  cat << EOF >> "$UPDATE_BINARY"
ui_print "~ Getting supported ABIs..."

reverse() {
  if [ "\$#" -gt 0 ]; then
    local arg=\$1
    shift
    reverse "\$@"
    echo -n "\$arg "
  fi
}

androidAbiList="\$(get_buildprop 'ro.product.cpu.abilist')"
androidAbiList="\${androidAbiList//,/ }"
if [[ -n "\$androidAbiList" ]]
then
  androidAbiList="\$(reverse \$androidAbiList)"
else
  androidAbi="\$(get_buildprop 'ro.product.cpu.abi')"
  androidAbi2="\$(get_buildprop 'ro.product.cpu.abi2')"
  androidAbiList="\$androidAbi2 \$androidAbi"
fi

ui_print "~ Supported ABIs: \$androidAbiList"

EOF
}
#///End of function "sectionWriter_osVersionChecker"///

#This function writes the bunch of instructions necessary to install the app as system, to update-binary
#As can be seen from the case-esac, almost each Android release has its specific install location
#///Beginning of function "sectionWriter_apkInstaller"///
function sectionWriter_apkInstaller {
 echo "[INFO] Writing APK installation instructions to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
ui_print "~ Installing $displayedName..."

case "\$androidVersion" in
 4.1*|4.1.*|4.2*|4.2.*|4.3*|4.3.*)
  unzip -qo "\$ZIP" '$appName/$appName.apk' -d '/system/app/'
  ;;
 4.4*|4.4.*)
  unzip -qo "\$ZIP" '$appName/$appName.apk' -d '/system/priv-app/'
  ;;
 5*|5.*|5.*.*|6*|6.*|6.*.*)
  unzip -qo "\$ZIP" '$appName/*' -d '/system/priv-app'
  ;;
esac

ui_print "~ $displayedName has been installed."
ui_print ""

EOF
}
#///End of function "sectionWriter_apkInstaller"///

#This function writes instructions to update-binary to install any libs in the apk
#As can be seen from the case-esac, almost each Android release has its specific install location
#///Beginning of function "sectionWriter_libInstaller"///
function sectionWriter_libInstaller {
 echo "[INFO] Writing library installation instructions to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
ui_print "~ Installing $displayedName libraries..."

case "\$androidVersion" in
 4.1*|4.1.*|4.2*|4.2.*|4.3*|4.3.*|4.4*|4.4.*)
  apkFile='/system/app/$appName/$appName.apk'
  ;;
 5*|5.*|5.*.*|6*|6.*|6.*.*)
  apkFile='/system/priv-app/$appName/$appName.apk'
  ;;
esac

unzip -qo "\$apkFile" 'lib/*'
for abi in \$androidAbiList
do
  if [[ -d "lib/\$abi" ]]
  then
    ui_print "~ \$abi..."
    mv lib/\$abi/* '/system/vendor/lib'
  fi
done
rm -rf lib

ui_print "~ $displayedName libs have been installed."
ui_print ""

EOF
}
#///End of function "sectionWriter_libInstaller"///

#This function writes the instructions to change ownership, permissions and eventual SELinux context, to update-binary
#As for now, the script determines if SELinux is present by looking for the setenforce binary
#I'll probably base the check on the presence of "/sys/fs/selinux", but that has to be done in a next version 
#///Beginning of function "sectionWriter_validateApp"///
function sectionWriter_validateApp {
 echo "[INFO] Writing APK ownership, permission and context change instructions to update-binary..."
 cat << EOF >> "$ZIPDIR/META-INF/com/google/android/update-binary"
case "\$androidVersion" in
 4.1*|4.2*|4.3*)
  ui_print "~ Setting ownership and permissions..."
  chown 0.0 "/system/app/$appName.apk"
  chmod 644 "/system/app/$appName.apk"
  if [ -e "/system/bin/setenforce" ]; then
   ui_print "~ Setting SELinux appropriate context..."
   chcon u:object_r:system_file:s0 "/system/app/$appName.apk"
  fi
  ;;
 4.4*)
  ui_print "~ Setting ownership and permissions..."
  chown 0.0 "/system/priv-app/$appName.apk"
  chmod 644 "/system/priv-app/$appName.apk"
  if [ -e "/system/bin/setenforce" ]; then
   ui_print "~ Setting SELinux appropriate context..."
   chcon u:object_r:system_file:s0 "/system/priv-app/$appName.apk"
  fi
  ;;
 5*|6*)
  ui_print "~ Setting ownership and permissions..."
  chown 0.0 "/system/priv-app/$appName"
  chmod 755 "/system/priv-app/$appName"
  chown 0.0 "/system/priv-app/$appName/$appName.apk"
  chmod 644 "/system/priv-app/$appName/$appName.apk"
  if [ -e "/system/bin/setenforce" ]; then
   ui_print "~ Setting SELinux appropriate context..."
   chcon u:object_r:system_file:s0 "/system/priv-app/$appName"
   chcon u:object_r:system_file:s0 "/system/priv-app/$appName/$appName.apk"
  fi
  ;;
esac
ui_print ""

EOF
}
#///End of function "sectionWriter_validateApp"///

#This function writes any custom commands to update-binary
#///Beginning of function "sectionWriter_customCommands"///
function sectionWriter_customCommands {
 if [ -f "$CUSTOMFILE" ]; then
   echo "[INFO] Writing custom commands to update-binary..."
   cat "$CUSTOMFILE" >> "$UPDATE_BINARY"
 fi
}
#///End of function "sectionWriter_systemUnmount"///

#This function writes the instructions to unmount the system partition, to update-binary
#///Beginning of function "sectionWriter_systemUnmount"///
function sectionWriter_systemUnmount {
 echo "[INFO] Writing unmount instructions to update-binary..."
 cat << EOF >> "$UPDATE_BINARY"
ui_print "~ Unmounting /system..."
umount /system
ui_print ""

EOF
}
#///End of function "sectionWriter_systemUnmount"///

#This function writes something as a termination/goodbye message, to update-binary
#///Beginning of function "sectionWriter_goodbyeString"///
function sectionWriter_goodbyeString {
 echo "[INFO] Writing goodbye message to update-binary..."
 echo "ui_print \"Installation completed! Have a great day!\"" >> "$UPDATE_BINARY"
}
#///End of function "sectionWriter_goodbyeString"///

#=== END OF "update-binary" WRITING SECTION ===

#This function packs the prepared ZIP directory and
#removes it, leaving behind the flashable ZIP
#DO NOT set a compression level of "0", or the produced ZIP will be corrupted
#///Beginning of function "zipPacker"///
function zipPacker {
 echo "[INFO] Packing the ZIP..."

 OLDPWD=$(pwd)
 cd "$ZIPDIR"
 zip -qr9 "$ZIPFILE" .
 cd "$OLDPWD"
 rm -rf "$ZIPDIR"
}
#///End of function "zipPacker"///

#This is the core of the EDGAR tool
#Here, all of the previously defined functions are called in the correct order
#To add a function, and thus extend EDGAR's versatility, simply define it above, and call it below
#///Beginning of EDGAR's core///
echo "**************************************"
echo " EDGAR - Flashable ZIP creator script "
echo "    by    Death    Mask    Salesman   "
echo "**************************************"
echo ""

depend aapt zip find
echo ""

init "$ZIPDIR"
echo ""

updaterScriptCreator
echo ""

sectionWriter_header
sectionWriter_systemRwMount
sectionWriter_osVersionChecker
sectionWriter_getAbiList

for appName in $( find "$scriptDir" -maxdepth 1 -type f -name '*.apk' )
do
  appNameRetriever "$appName"
  sectionWriter_appName
  add_apk
  sectionWriter_apkInstaller
  sectionWriter_libInstaller
  sectionWriter_validateApp
done

sectionWriter_customCommands
sectionWriter_systemUnmount
sectionWriter_goodbyeString
echo ""

zipPacker
echo ""

echo "[INFO] Operations took "$(((SECONDS/60)/60))" hours, "$(((SECONDS/60)%60))" minutes and "$((SECONDS%60))" seconds."
echo "[INFO] All done!"
#///End of EDGAR's core///
