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

### Prerequisites

The ZIP can be prepared either on a rooted Android device or by any user
on Linux (root is not required on Linux). In both cases, the `zip` and 
`aapt` (*Android Application Packaging Tool*) commands are required.

The `aapt` is part of the *Android Development Toolkit* (ADT). It can,
however, be obtained without the overhead of the full ADT. See [this
post][1] for more information. In summary, for *Arch Linux*:

    $ sudo pacman -S lib32-{glibc,gcc-libs,zlib}
    $ curl -J -O https://android.izzysoft.de/downloads.php?file=adb-binaries-linux-1.0.32.tar.gz
    $ tar xf adb-binaries-linux-1.0.32.tar.gz

This assumes that the _multilib_ repository must be enabled in `/etc/pacman.conf`. It installs 32-bit versions of `aapt`, `adb` and `fastboot`.

Alternatively, there is the AUR package [android-sdk-platform-tools][2].

[1]: http://android.stackexchange.com/a/156520
[2]: https://aur.archlinux.org/packages/android-sdk-platform-tools

Flashing the ZIP requires a custom recovery or root access and a tool
like *FlashFire*.

### Usage

Place the `.apk` files in a directory and, from that directory, run the
script:

    $ edgar.sh

If the `aadb` tool is installed to the local directory start it with an
augmented path:

    $ PATH=".:$PATH" ./edgar.sh

The output of the script is a file `edgar.zip` in the same directory.

#### Worked Example

First create a new, empty working directory and enter it:

    $ mkdir edgar_workingcopy && cd edgar_workingcopy

Obtain the `edgar.sh` script

    $ curl -J -O 'http://git/?p=android_apkzip.git;a=blob_plain;f=edgar.sh;hb=HEAD'
    $ chmod +x edgar.sh

Obtain prerequisites

    $ curl -J https://android.izzysoft.de/downloads.php?file=adb-binaries-linux-1.0.32.tar.gz | tar xzf -

Verify the directory contents:

    $ ls
    aapt  adb  fastboot  lib

Copy the desired `.apk` files into the working directory alongside `aapt`.

Then run the script:

    $ PATH=".:$PATH" ./edgar.sh

Upload the produced `edgar.zip` to an Android device:

    $ adb push edgar.zip /storage/sdcard0/Download

Apply it using `FlashFire` or another ZIP-flashing method.

### Issues

Some applications don't perform properly when not installed on `/data`.
Most notable in this respect is *FlashFire*.

### Extras

The following extra utilities are included:

* `get_apk` downloads `.apk` files from remote file server into current directory,
  expected to be the working directory from where `edgar.sh` will be run.
* `pull_apk` downloads `.apk` files from `/data/app` (requires `adb`).
* `install_apk` installs `.apk` files into `/data/app`. The given pacakges are
  downloaed from a remote file server into a local cache (requires `adb`).

### History

This work follows a [learning exercise][3] to understand the structure of
a flashable ZIP and builds upon the ideas presented in [this example][4]
which is where the original script name, `edgar.sh` comes from.

[3]: http://android.stackexchange.com/questions/156336
[4]: http://android.stackexchange.com/questions/143304
