#/bin/bash

RPI4VERSION=arpi-12
DATE=`date +%Y%m%d`
IMGNAME=$RPI4VERSION-$DATE-rpi4.img
IMGSIZE=7
OUTDIR=${ANDROID_PRODUCT_OUT:="./out/target/product/rpi4"}
KERNEL_OUT_DIR="../android-kernel/out/arpi-5.10/dist"

if [ `id -u` != 0 ]; then
	echo "Must be root to run script!"
	exit
fi

if [ -f $IMGNAME ]; then
	echo "File $IMGNAME already exists!"
else
	echo "Creating image file $IMGNAME..."
	dd if=/dev/zero of=$IMGNAME bs=1M count=$(echo "$IMGSIZE*1024" | bc)
	sync
	echo "Creating partitions..."
	(
	echo o
	echo n
	echo p
	echo 1
	echo
	echo +128M
	echo n
	echo p
	echo 2
	echo
	echo +1536M
	echo n
	echo p
	echo 3
	echo
	echo +256M
	echo n
	echo p
	echo
	echo
	echo t
	echo 1
	echo c
	echo a
	echo 1
	echo w
	) | fdisk $IMGNAME
	sync
	LOOPDEV=`kpartx -av $IMGNAME | awk 'NR==1{ sub(/p[0-9]$/, "", $3); print $3 }'`
	sync
	if [ -z "$LOOPDEV" ]; then
		echo "Unable to find loop device!"
		kpartx -d $IMGNAME
		exit
	fi
	echo "Image mounted as $LOOPDEV"
	sleep 5
	mkfs.fat -F 32 /dev/mapper/${LOOPDEV}p1 -n boot
	mkfs.ext4 /dev/mapper/${LOOPDEV}p2 -L system
	mkfs.ext4 /dev/mapper/${LOOPDEV}p3 -L vendor
	mkfs.ext4 /dev/mapper/${LOOPDEV}p4 -L userdata
	resize2fs /dev/mapper/${LOOPDEV}p4 1343228
	echo "Copying system..."
	dd if=$OUTDIR/system.img of=/dev/mapper/${LOOPDEV}p2 bs=1M
	echo "Copying vendor..."
	dd if=$OUTDIR/vendor.img of=/dev/mapper/${LOOPDEV}p3 bs=1M
	echo "Copying boot..."
	mkdir -p sdcard/boot
	sync
	mount /dev/mapper/${LOOPDEV}p1 sdcard/boot
	sync
	mkdir -p sdcard/boot/overlays
  cp device/arpi/rpi4/boot/*  sdcard/boot
	cp $OUTDIR/ramdisk.img sdcard/boot
	cp $KERNEL_OUT_DIR/Image.gz sdcard/boot
	cp $KERNEL_OUT_DIR/bcm2711-rpi-*.dtb sdcard/boot
	cp $KERNEL_OUT_DIR/vc4-kms-v3d-pi4.dtbo sdcard/boot/overlays

	sync
	umount /dev/mapper/${LOOPDEV}p1
	rm -rf sdcard
	kpartx -d $IMGNAME
	sync
	echo "Done, created $IMGNAME!"
fi