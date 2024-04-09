#!/bin/bash
# todo(ezalenski): make linux version an env var

sudo apt -y install build-essential autoconf flex bison qemu-system-x86 libncurses-dev libelf-dev libssl-dev

if ! [ -d linux-6.8.4 ]; then
  if ! [ -f linux-6.8.4.tar.xz ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.4.tar.xz
  fi
  tar xf linux-6.8.4.tar.xz
fi

if ! [ -f linux-6.8.4/arch/x86/boot/bzImage ]; then
  pushd linux-6.8.4
  apt build-dep linux
  if ! [ -f .config ]; then
    make defconfig
    scripts/config --disable SYSTEM_TRUSTED_KEYS
    scripts/config --disable SYSTEM_REVOCATION_KEYS
    scripts/config --enable PVH
  fi
  yes "" | make -j $(nproc)
  popd
fi

if ! [ -f busybox/initramfs.cpio.gz ]; then
  if ! [ -d busybox ]; then
    if ! [ -f busybox-snapshot.tar.bz2 ]; then
      wget https://www.busybox.net/downloads/busybox-snapshot.tar.bz2
    fi
    tar xf busybox-snapshot.tar.bz2
  fi
  pushd busybox
  if ! [ -f .config ]; then
    make defconfig
    # sed .config
  fi 
  LDFLAGS="--static" make -j $(nproc) && LDFLAGS="--static" make install
  cd _install
  echo "#!/bin/sh
echo \"hello world\"
exec /bin/sh" > init
  chmod +x init
  find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../initramfs.cpio.gz
  popd
fi 

qemu-system-x86_64 -kernel linux-6.8.4/arch/x86/boot/bzImage -initrd busybox/initramfs.cpio.gz