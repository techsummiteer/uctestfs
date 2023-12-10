#!/bin/bash

# Check if QEMU is installed, install it if not
if ! command -v qemu-system-x86_64 &> /dev/null; then
    sudo apt-get update
    if [ $? -ne 0 ]; then
        echo "Failed to update package list"
        exit 1
    fi
    sudo apt-get install qemu qemu-kvm
    if [ $? -ne 0 ]; then
        echo "Failed to install QEMU"
        exit 1
    fi
    echo "QEMU has been installed"
fi

# Download the Tiny Linux filesystem and kernel
fsurl="http://tinycorelinux.net/14.x/x86/release/distribution_files/core.gz"
fsoutput="core.gz"
vmurl="http://tinycorelinux.net/14.x/x86/release/distribution_files/vmlinuz"
vmoutput="vmlinuz"
# Downloading core.gz
if [ ! -f "${fsoutput}" ]; then
    wget -O "${fsoutput}" "${fsurl}"
    if [ $? -ne 0 ]; then
        echo "Download of ${fsoutput} failed"
        exit 1
    fi
fi
# Downloading vmlinuz
if [ ! -f "${vmoutput}" ]; then
    wget -O "${vmoutput}" "${vmurl}"
    if [ $? -ne 0 ]; then
        echo "Download of ${vmoutput} failed"
        exit 1
    fi
fi
echo "Downloaded ${fsoutput} and ${vmoutput}"

#Store the current dir into tmp
wdir=$(pwd)
#
# Start to create the filesystem with a hello world script
#
sudo rm -f ./amd64fs.img
dd if=/dev/zero of=./amd64fs.img bs=1M count=10
if [ $? -ne 0 ]; then
    echo "Failed to create amd64fs.img"
    exit 1
fi
#Make the file a block device
sudo losetup -fP ./amd64fs.img
#Find the name of the block device created
loopdev=$(losetup -j ./amd64fs.img | awk '{print $1}' | sed 's/://')
if [ -z "${loopdev}" ]; then
    echo "Failed to setup loop device"
    exit 1
fi
#Create the ext4 filesystem on the block device
sudo mkfs.ext4 ${loopdev}

#Create the mount point
if [ -d amd64fs ]; then
    # Try to unmount the directory
    sudo umount amd64fs 2> /dev/null || true
fi
mkdir -p ./amd64fs

#Mount the block on the mount point
sudo mount ${loopdev} ./amd64fs
if [ $? -ne 0 ]; then
    echo "Failed to mount amd64fs"
    exit 1
fi
#Create the hello.sh file in the amd64fs
cd amd64fs
echo -e '#!/bin/sh\necho "hello world"' | sudo tee hello.sh > /dev/null
sudo chmod +x hello.sh
#Return to working dir
cd ${wdir}
#Unmount the block device
sudo umount amd64fs

#
# Update the initramfs to mount the file system and call hello.sh
#
mkdir -p initramfs
if [ $? -ne 0 ]; then
    echo "Failed to create initramfs directory."
    exit 1
fi
sudo rm -rf ./initramfs/*
cd initramfs
zcat "${wdir}/core.gz" | sudo cpio -id
if [ $? -ne 0 ]; then
    echo "Failed to unpack core.gz."
    exit 1
fi
#Mount the amd64fs block device for a later call
echo -e 'mount /dev/sda /mnt/sda' | sudo tee -a opt/bootsync.sh > /dev/null

#Assignment requirement ( to see the hello world after the boot)
sudo rm -f root/.profile
echo -e '#!/bin/sh\n/mnt/sda/hello.sh' | sudo tee root/.profile > /dev/null

# Recreate the core.gz as core2.gz
find . | sudo cpio -o -H newc > "${wdir}/core2.gz"
if [ $? -ne 0 ]; then
    echo "Failed to create core2.gz."
    exit 1
fi
#Go back to working dir
cd ${wdir}

#
#Now call the QEMU with the kernel, patched initrd, the amd64 filesystem as /dev/sda
#
qemu-system-x86_64 -kernel vmlinuz -initrd core2.gz -drive file=./amd64fs.img,format=raw -append "root=/dev/sda quiet superuser nodhcp"

echo "QEMU started in its own graphic"
