Android APKZIP
==============

This is an expermental utility to create a flashable ZIP containing
a number of Android application packages (`.apk` files) with the
intention that the ZIP can be flashed in addition to a custom ROM 
to augment the available _system_ applications.

The rationale for this is two-fold:

* to help automate installation of a bespoke application collection
* to consume free space on the `/system` partition rather than `/data` so
  that end-user space isn't wasted.

The MIT License applies to this work; please refer to the LICENSE file.

### Prerequisites

The ZIP can be prepared either on a rooted Android device or by any user
on Linux (root is not required on Linux). In both cases, the `zip` and 
`aapt` (*Android Application Packaging Tool*) commands are required.

The `aapt` is part of the *Android Development Toolkit* (ADT). It can,
however, be obtained without the overhead of the full ADT. See [this
post][1] for more information. In summary, for *Arch Linux*:

    $ sudo pacman -S lib32-{glibc,gcc-libs,zlib}
    $ curl -J -O 'https://raw.githubusercontent.com/johnlane/android_apkzip/master/adb-binaries-linux-1.0.32.tar.gz'
    $ tar xf adb-binaries-linux-1.0.32.tar.gz

This assumes that the _multilib_ repository must be enabled in `/etc/pacman.conf`. It installs 32-bit versions of `aapt`, `adb` and `fastboot`.

Alternatively, there is the AUR package [android-sdk-platform-tools][2].

[1]: http://android.stackexchange.com/a/156520
[2]: https://aur.archlinux.org/packages/android-sdk-platform-tools

Flashing the ZIP requires a custom recovery or root access and a tool
like *FlashFire*.

### Usage

The script can be used on either Linux or Android. However, if using Android,
consider the following points:

* Ensure the filesystem is not mounted `noexec` (e.g. use `/data/local/tmp`).
* Should `curl`, used in the following examples, terminate with a *SSL
  certificate verification* error, try adding a `-k` option.
* The location of the `sh` shell differs between Linux and Android. The script
  contains two *shebang* lines - the first for Linux and the second for Android.
  On Android, remove the Linux shebang so that the Android one will be used.
  One way to do this is `sed -i -n -e '2,$p' edgar.sh`.
* The shell tries to write temporary files to `/data/local` which requires
  root privileges. For this reason only the script must be run as `root`. This
  is discussed at http://android.stackexchange.com/questions/156719. A remedy
  would be welcome!

Create a working directory and place the `.apk` files in subdirectories
as follows:

* apks placed into an `app` subdirectory will install into `/system/app`
* apks placed into a `priv-app` subdirectory will be installed into
  `/system/priv-app` on Android versions 4.4 and above (`app` will be
  used on earlier versions)

Then, from the working directory, run the script:

    $ ./edgar.sh

If the `aadb` tool is installed to the same working directory then start it
with an augmented path:

    $ PATH=".:$PATH" ./edgar.sh

To run with `root` privileges (e.g. on Android):

    $ su -c ./edgar.sh

The output of the script is a file `edgar.zip` in the same directory.

#### Worked Example

First create a new, empty working directory structure and enter it:

    $ mkdir -p edgar_workingcopy/{,priv-}app && cd edgar_workingcopy

Obtain the `edgar.sh` script

    $ curl -J -O 'https://raw.githubusercontent.com/johnlane/android_apkzip/master/edgar.sh'
    $ chmod 700 edgar.sh

Obtain prerequisites

    $ curl -J 'https://raw.githubusercontent.com/johnlane/android_apkzip/master/adb-binaries-linux-1.0.32.tar.gz' | tar xzf -

Verify the directory contents:

    $ ls
    aapt  adb  app edgar.sh fastboot  lib priv-app

Copy the desired `.apk` files into the `app` and/or `priv-app` subdirectories
as appropriate. Then run the script:

    $ PATH=".:$PATH" ./edgar.sh

Upload the produced `edgar.zip` to an Android device:

    $ adb push edgar.zip /storage/sdcard0/Download

Apply it using `FlashFire` or another ZIP-flashing method.

### Custom scripts

Custom scripts can be provided as `custom_preinstall.sh` and `custom_postinstall.sh`
which are applied before and after the apk installation. An example script is given
as `examples/custom_preinstall.sh` which deletes some stock applications before 
alternatives are installed. The optional custom scripts, if required, should be
supplied in the root of the working directory.

### Issues

Some applications don't perform properly when not installed on `/data`.
Most notable in this respect is *FlashFire*.

### Extras

The following extra utilities are included:

* `get_apk` downloads `.apk` files from remote file server into current directory,
  expected to be the relevant `app` or `priv-app` subdirectory of the working
  directory where `edgar.sh` will be run.
* `pull_apk` downloads `.apk` files from `/data/app` (requires `adb`).
* `install_apk` installs `.apk` files into `/data/app`. The given pacakges are
  downloaed from a remote file server into a local cache (requires `adb`).

The `get_apk` can be used to populate the `app` or `priv-app` directories. Given
a file, `apk_list`, containing the apk names in the relevant `app` directory:

    (cd app; ../get_apk < apk_list)

An example is provided in `examples/apk_list`. Empty lines, whitespace and
comments (any text beginning with `#` through to the end of the line) are
ignored.

### History

This work follows a [learning exercise][3] to understand the structure of
a flashable ZIP and builds upon the ideas presented in [this example][4]
which is where the original script name, `edgar.sh` comes from.

[3]: http://android.stackexchange.com/questions/156336
[4]: http://android.stackexchange.com/questions/143304

The original source of the adb binaries package is:

    https://android.izzysoft.de/downloads.php?file=adb-binaries-linux-1.0.32.tar.gz
