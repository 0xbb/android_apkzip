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

#This function verifies if there's at least an APK in the script's folder
#///Beginning of function "apkChecker"///
function apkChecker {
 echo "[INFO] Checking if at least an APK file is present..."
 if [ "$(ls "$scriptDir" | grep "\.apk$")" != "$(cat /dev/null)" ]; then
  echo "[INFO] At least one APK file has been found."
 else
  echo "[FATAL] No APK file found. Aborting."
  exit
 fi
}
#///End of function "apkChecker"///

#This function checks if the required tools (aapt and zip) are installed
#///Beginning of function "depencenciesChecker"///
function dependenciesChecker {
 echo "[INFO] Checking if both the aapt and zip utilities are installed..."

 which aapt &> /dev/null
 isAaptAbsent="$(echo $?)"

 which zip &> /dev/null
 isZipAbsent="$(echo $?)"

 case "$isAaptAbsent" in
  0)
   case "$isZipAbsent" in
    0)
     echo "[INFO] Both aapt and zip have been found."
     unset "isAaptAbsent" "isZipAbsent"
     ;;
    *)
     echo "[FATAL] zip cannot be found. Aborting."
     exit
     ;;
   esac
   ;;
  *)
   case "$isZipAbsent" in
    0)
     echo "[FATAL] aapt cannot be found. Aborting."
     exit
     ;;
    *)
     echo "[FATAL] Neither aapt nor zip can be found. Aborting."
     exit
     ;;
   esac
   ;;
 esac
}
#///End of function "dependenciesChecker"///

#This function relies on aapt, and is meant to retrieve the app's name from the given APK
#Notice that only the first APK in a list gets picked
#///Beginning of function "appNameRetriever"///
function appNameRetriever {
 echo "[INFO] Retrieving app name from the provided APK..."
 apkFile="$(ls "$scriptDir" | grep "\.apk$" | head -n 1)"
 appName="$(aapt d badging "$scriptDir"/"$apkFile")"
 appName="${appName#*application-label:\'}"
 appName="${appName//app*/}"
 appName="${appName%\'*}"
 displayedName=$appName
 appName="$(printf "%s" $appName)"
}
#///End of function "appNameRetriever"///

#This function creates the tree used by the ZIP (namely, the META-INF/com/google/android and appName folders)
#It also copies the previously picked APK to the appName folder, renaming it in the process
#///Beginning of function "folderTreeCreator"///
function folderTreeCreator {
 echo "[INFO] Creating ZIP folder tree and placing the APK to be flashed inside it..."
 mkdir -p ""$scriptDir"/$appName/META-INF/com/google/android"
 mkdir -p ""$scriptDir"/$appName/$appName"
 cp ""$scriptDir"/""$apkFile""" ""$scriptDir"/$appName/$appName/$appName.apk"
}
#///End of function "folderTreeCreator"///

#This function creates a dummy updater-script, which server mainly for aesthetical purposes
#///Beginning of function "updaterScriptCreator"///
function updaterScriptCreator {
 echo "[INFO] Creating dummy updater-script..."
 echo -n "#This is a dummy file. The magic is in the update-binary, which is a shell script." > ""$scriptDir"/$appName/META-INF/com/google/android/updater-script"
}
#///End of function "updaterScriptCreator"///

#=== BEGINNING OF "update-binary" WRITING SECTION ===
#From now on, the functions whose name begins with "sectionWriter", are used to assemble the update-binary

#This function writes the function and variables used for outputting things when flashing, to update-binary
#Thanks to Chainfire @ XDA, which seems to have been the first to implement them
#///Beginning of function "sectionWriter_header"///
function sectionWriter_header {
 echo "[INFO] Writing variables and functions prototypes to update-binary..."
 cat <<-EOF > ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
#!/sbin/sh

OUTFD=\$2
ZIP=\$3

ui_print() {
 echo -ne "ui_print \$1\n" > /proc/self/fd/\$OUTFD
 echo -ne "ui_print\n" > /proc/self/fd/\$OUTFD
}

EOF
}
#///End of function "sectionWriter_header"///

#This function writes the title of the ZIP (which contains the human-readable app name of the APK), to update-binary
#///Beginning of function "sectionWriter_zipName"///
function sectionWriter_zipName {
 echo "[INFO] Writing script title to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
ui_print ""
ui_print "******************************"
ui_print " $displayedName Flashable ZIP "
ui_print " made by EDGAR, written by "
ui_print " Death Mask Salesman "
ui_print "******************************"
ui_print ""

EOF
}
#///End of function "sectionWriter_zipName"///

#This function writes the instructions necessary to mount the system partition in read-write mode, to update-binary
#///Beginning of function "sectionWriter_systemRwMount"///
function sectionWriter_systemRwMount {
 echo "[INFO] Writing mount instructions to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
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
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
ui_print "~ Checking Android version..."
androidVersion="\$(cat /system/build.prop | grep 'ro\.build\.version\.release')"
androidVersion="\${androidVersion#*=}"

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

#This function writes the instructions needed to unpack the ZIP to a temporary location, to update-binary
#This procedure is needed to obtain the APK to be installed as system app
#///Beginning of function "sectionWriter_zipUnpacker"///
function sectionWriter_zipUnpacker {
 echo "[INFO] Writing ZIP unpacking instructions to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
ui_print "~ Extracting the ZIP to a temporary folder..."
mkdir -p "/tmp/$appName"
cd "/tmp/$appName"
unzip -o "\$ZIP"
ui_print ""

EOF
}
#///End of function "sectionWriter_zipUnpacker"///

#This function writes the bunch of instructions necessary to install the app as system, to update-binary
#As can be seen from the case-esac, almost each Android release has its specific install location
#///Beginning of function "sectionWriter_appInstaller"///
function sectionWriter_appInstaller {
 echo "[INFO] Writing APK installation instructions to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
ui_print "~ Installing $displayedName..."

case "\$androidVersion" in
 4.1*|4.1.*|4.2*|4.2.*|4.3*|4.3.*)
  cp "/tmp/$appName/$appName/$appName.apk" "/system/app/"
  ;;
 4.4*|4.4.*)
  cp "/tmp/$appName/$appName/$appName.apk" "/system/priv-app/"
  ;;
 5*|5.*|5.*.*|6*|6.*|6.*.*)
  mkdir -p "/system/priv-app/$appName"
  cp "/tmp/$appName/$appName/$appName.apk" "/system/priv-app/$appName/"
  ;;
esac

ui_print "~ $displayedName has been installed."
ui_print ""

EOF
}
#///End of function "sectionWriter_appInstaller"///

#This function writes the instructions to change ownership, permissions and eventual SELinux context, to update-binary
#As for now, the script determines if SELinux is present by looking for the setenforce binary
#I'll probably base the check on the presence of "/sys/fs/selinux", but that has to be done in a next version 
#///Beginning of function "sectionWriter_validateApp"///
function sectionWriter_validateApp {
 echo "[INFO] Writing APK ownership, permission and context change instructions to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
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

#This function writes the instructions to unmount the system partition, to update-binary
#///Beginning of function "sectionWriter_systemUnmount"///
function sectionWriter_systemUnmount {
 echo "[INFO] Writing unmount instructions to update-binary..."
 cat << EOF >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
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
 echo "ui_print \"Installation completed! Have a great day!\"" >> ""$scriptDir"/$appName/META-INF/com/google/android/update-binary"
}
#///End of function "sectionWriter_goodbyeString"///

#=== END OF "update-binary" WRITING SECTION ===

#This function packs the META-INF and appName folders, thus creating the flashable ZIP
#DO NOT set a compression level of "0", or the produced ZIP will be corrupted
#///Beginning of function "zipPacker"///
function zipPacker {
 echo "[INFO] Packing the ZIP..."

 cd ""$scriptDir"/$appName"
 zip -qr9 $appName.zip *
}
#///End of function "zipPacker"///

#This function moves the compressed ZIP to the same directory of the script, and wipes the directories created by "folderTreeCreator", along with their content
#///Beginning of function "cleanup"///
function cleanup {
 echo "[INFO] Moving the flashable ZIP to "$scriptDir"..."
 mv ""$scriptDir"/$appName/$appName.zip" "$scriptDir"

 echo "[INFO] Cleaning up the folders used as ZIP base..."
 rm -rf ""$scriptDir"/$appName"
}
#///End of function "cleanup"///

#This is the core of the EDGAR tool
#Here, all of the previously defined functions are called in the correct order
#To add a function, and thus extend EDGAR's versatility, simply define it above, and call it below
#///Beginning of EDGAR's core///
echo "**************************************"
echo " EDGAR - Flashable ZIP creator script "
echo "    by    Death    Mask    Salesman   "
echo "**************************************"
echo ""

apkChecker
echo ""

dependenciesChecker
echo ""

appNameRetriever
echo ""

folderTreeCreator
echo ""

updaterScriptCreator
echo ""

sectionWriter_header
sectionWriter_zipName
sectionWriter_systemRwMount
sectionWriter_osVersionChecker
sectionWriter_zipUnpacker
sectionWriter_appInstaller
sectionWriter_validateApp
sectionWriter_systemUnmount
sectionWriter_goodbyeString
echo ""

zipPacker
echo ""

cleanup
echo ""

echo "[INFO] Operations took "$(((SECONDS/60)/60))" hours, "$(((SECONDS/60)%60))" minutes and "$((SECONDS%60))" seconds."
echo "[INFO] All done!"
#///End of EDGAR's core///
