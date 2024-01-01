A small demonstrator for integrating QEMU, Tiny Core Linux &  your own filesystem and then run a script which can display on startup

This script does the following
1. Checks if you have qemu installed.
2. Downloads the kernel & rootfs from tiny core linux site.
3. Creates a fileystem using losetup, this is your code/data. Also adds in a sample hello.sh file.
4. Unpacks the rootfs using cpio and adds in the mount for your filesystem. Also adds in the call to the sample hello.sh in the .profile of the roor. As this will be the last file executed, you will be able to see the display.
5. Repacks the rootfs using cpio.
6. Finally runs qemu with the tiny core kernel, the amended rootfs and your filesystem mounted as a drive.
