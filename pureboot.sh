#!/bin/sh
#
# this is an attempt to create a pure-illumos bootable image
#
# all it does is take a proto area and convert it into a bootable ramdisk
#
# Created by Peter Tribble
# Moddified by Samantha Nolastnameprovided

#
# where the iso should end up
#
ISO_NAME=$1

#
# *** CUSTOMIZE ***
# where your proto area is
#
PROTO_DIR=$2

#
# this is the size of the ramdisk we create and should match the size
# of the proto area (du should be reasonable)
# you can reduce it if you do any serious trimming of the image
#
MRSIZE=512M
NBPI=16384

#
# this is the temporary area where we dump stuff while building
#
DESTDIR=/tmp/purebuild.$$

#
# bail if something is already there
#
if [ -d $DESTDIR ]; then
    echo "ERROR: $DESTDIR already exists"
    exit 1
fi
if [ -f $DESTDIR ]; then
    echo "ERROR: $DESTDIR already exists (as a file)"
    exit 1
fi
#
# check we have a proto area to deal with
#
if [ ! -d $PROTO_DIR ]; then
    echo "ERROR: unable to find proto area $PROTO_DIR"
    exit 1
fi
#
# clean up and populate
#
mkdir -p ${DESTDIR}
cd ${PROTO_DIR}
tar cf - . | ( cd ${DESTDIR} ; tar xf -)

#
# *** CUSTOMIZE ***
# this is where you can remove any junk from the ISO that you don't want
#
cd ${DESTDIR}
## rm -fr opt

#
# illumos itself cannot run SMF, that needs libxml2, so just run a shell
# this is a script so (a) we can emit a message saying we're ready,
# and (b) it's extensible
#
cd ${DESTDIR}
cat > ${DESTDIR}/etc/pureboot.rc <<EOF
#!/sbin/sh
echo " *** Welcome to illumos pureboot ***" > /dev/console
/bin/ksh93 >/dev/console 2>&1 </dev/console
EOF
chmod a+x ${DESTDIR}/etc/pureboot.rc
#
# init has intimate coupling with smf, there must be an smf entry here
#
mv ${DESTDIR}/etc/inittab ${DESTDIR}/etc/inittab.tmp
cat ${DESTDIR}/etc/inittab.tmp | grep -v startd > ${DESTDIR}/etc/inittab
rm ${DESTDIR}/etc/inittab.tmp
cat >> ${DESTDIR}/etc/inittab << _EOF
smf::sysinit:/etc/pureboot.rc
_EOF

#
# add a grub menu
#
cat >> ${DESTDIR}/boot/grub/menu.lst << _EOF
title Illumarine
kernel\$ /platform/i86pc/kernel/\$ISADIR/unix
module\$ /platform/i86pc/boot_archive
title illumos pureboot (ttya)
kernel\$ /platform/i86pc/kernel/\$ISADIR/unix -B console=ttya,input-device=ttya,output-device=ttya
module\$ /platform/i86pc/boot_archive
title illumos pureboot debug
kernel\$ /platform/i86pc/kernel/\$ISADIR/unix -kv
module\$ /platform/i86pc/boot_archive
title Boot from hard disk
rootnoverify (hd0)
chainloader +1
_EOF
#
# https://blogs.oracle.com/darren/entry/sending_a_break_to_opensolaris
#
cat >> ${DESTDIR}/etc/system << _EOF
set pcplusmp:apic_kmdb_on_nmi=1
_EOF
#
# we don't need the splash images
#
rm -f ${DESTDIR}/boot/solaris.xpm
rm -f ${DESTDIR}/boot/splashimage.xpm
#
# paranoia, we don't want a boot archive inside the boot archive
#
rm -f ${DESTDIR}/platform/i86pc/amd64/boot_archive
rm -f ${DESTDIR}/platform/*/boot_archive
#
# so this is sort of stupid, the proto area contains blank versions
# of the critical kernel state files, so we need to add populated
# versions and we get those from the running system, because that's
# the only source I know of
#
for kfile in driver_classes minor_perm name_to_major driver_aliases
do
    cp /etc/${kfile} ${DESTDIR}/etc
done

#
# now we create a block device that will back a ufs file system
# that we will copy the constructed image to
#
mkfile ${MRSIZE} /tmp/${MRSIZE}
#
# gzip doesn't like the sticky bit
#
chmod o-t /tmp/${MRSIZE}
LOFIDEV=`lofiadm -a /tmp/${MRSIZE}`
LOFINUM=`echo $LOFIDEV|awk -F/ '{print $NF}'`
echo "y" | newfs -o space -m 0 -i $NBPI /dev/rlofi/$LOFINUM
BFS=/tmp/nb.$$
mkdir $BFS
mount -Fufs -o nologging $LOFIDEV $BFS
cd ${DESTDIR}
tar cf - . | ( cd $BFS ; tar xf -)
cd $BFS
/usr/bin/chown -hR root:root .
touch reconfigure
${DESTDIR}/usr/sbin/devfsadm -r ${BFS}
rm -f ${BFS}/dev/dsk/* ${BFS}/dev/rdsk/* ${BFS}/dev/usb/h*
rm -f ${BFS}/dev/removable-media/dsk/* ${BFS}/dev/removable-media/rdsk/*
#
# it's useful to know how much space we use, so we can adjust MRSIZE
# and NBPI to suit
#
cd /
DF=/usr/bin/df
if [ -x /usr/gnu/bin/df ]; then
    DF=/usr/gnu/bin/df
fi
$DF -h $BFS
$DF -i $BFS

#
# unmount, then compress the block device and copy it back
#
umount $BFS
lofiadm -d /dev/lofi/$LOFINUM
gzip /tmp/${MRSIZE}
cp /tmp/${MRSIZE}.gz ${DESTDIR}/platform/i86pc/boot_archive
rm /tmp/${MRSIZE}.gz
rmdir $BFS
#
# and tell the user how big it is
#
ls -lsh ${DESTDIR}/platform/i86pc/boot_archive

#
# all we need on the ISO is the platform and boot directories
#
cd ${DESTDIR}
rm bin
rm -fr dev devices etc export home kernel lib licenses mnt opt proc root sbin system tmp usr var

#
# now make the iso
# TODO: Move to mkiso.sh
#
/usr/bin/mkisofs -o ${ISO_NAME} -b boot/grub/stage2_eltorito \
	-c .catalog \
	-no-emul-boot -boot-load-size 4 -boot-info-table -N -l -R -U \
        -allow-multidot -no-iso-translate -cache-inodes -d -D \
	-V "Illumarine" ${DESTDIR}
ls -lsh $ISO_NAME

#
# and clean up
#
cd /
rm -fr ${DESTDIR}
