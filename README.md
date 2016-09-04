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

[1]: http://android.stackexchange.com/a/156520

Flashing the ZIP requires a custom recovery or root access and a tool
like *FlashFire*.

### Usage

Place the `.apk` files in a directory and, from that directory, run the
script:

    $ edgar.sh

The output of the script is a file `edgar.zip` in the same directory.

### Issues

Some applications don't perform properly when not installed on `/data`.
Most notable in this respect is *FlashFire*.

### History

This work follows a [learning exercise][2] to understand the structure of
a flashable ZIP and builds upon the ideas presented in [this example][3]
which is where the original script name, `edgar.sh` comes from.

[2]: http://android.stackexchange.com/questions/156336
[3]: http://android.stackexchange.com/questions/143304
