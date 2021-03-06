#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
# to build this kernel you need to be ROOT and to have bash as script loader  #
# do this:                                                                    #
# cd /bin                                                                     #
# rm -f sh                                                                    #
# ln -s bash sh                                                               #
# now go back to kernel folder and run:                                       # 
#                                                         		      #
# sh clean_kernel.sh                                                          #
#                                                                             #
# Now you can build my kernel.                                                #
# using bash will make your life easy. so it's best that way.                 #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

# Time of build startup
res1=$(date +%s.%N)

echo "${bldcya}***** Setting up Environment *****${txtrst}";

. ./env_setup.sh ${1} || exit 1;


# Generate Ramdisk
echo "${bldcya}***** Generating Ramdisk *****${txtrst}"
echo "0" > $TMPFILE;

(

	# remove previous initramfs files
	if [ -d $INITRAMFS_TMP ]; then
		echo "${bldcya}***** Removing old temp initramfs_source *****${txtrst}";
		rm -rf $INITRAMFS_TMP;
	fi;

	mkdir -p $INITRAMFS_TMP;
	cp -ax $INITRAMFS_SOURCE/* $INITRAMFS_TMP;
	# clear git repository from tmp-initramfs
	if [ -d $INITRAMFS_TMP/.git ]; then
		rm -rf $INITRAMFS_TMP/.git;
	fi;
	
	# clear mercurial repository from tmp-initramfs
	if [ -d $INITRAMFS_TMP/.hg ]; then
		rm -rf $INITRAMFS_TMP/.hg;
	fi;

	# remove empty directory placeholders from tmp-initramfs
	find $INITRAMFS_TMP -name EMPTY_DIRECTORY | parallel rm -rf {};

	# remove more from from tmp-initramfs ...
	rm -f $INITRAMFS_TMP/update* >> /dev/null;

	./utilities/mkbootfs $INITRAMFS_TMP | gzip > ramdisk.gz

	echo "1" > $TMPFILE;
	echo "${bldcya}***** Ramdisk Generation Completed Successfully *****${txtrst}"
)&

if [ ! -f $KERNELDIR/.config ]; then
	echo "${bldcya}***** Writing Config *****${txtrst}";
	cp $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG .config;
	make $KERNEL_CONFIG;
fi;

. $KERNELDIR/.config

# remove previous zImage files
if [ -e $KERNELDIR/zImage ]; then
	rm $KERNELDIR/zImage;
	rm $KERNELDIR/boot.img;
fi;
if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	rm $KERNELDIR/arch/arm/boot/zImage;
fi;

# remove previous initramfs files
rm -rf $KERNELDIR/out/system/lib/modules >> /dev/null;
rm -rf $KERNELDIR/out/tmp_modules >> /dev/null;
rm -rf $KERNELDIR/out/temp >> /dev/null;

# clean initramfs old compile data
rm -f $KERNELDIR/usr/initramfs_data.cpio >> /dev/null;
rm -f $KERNELDIR/usr/initramfs_data.o >> /dev/null;

# remove all old modules before compile
find $KERNELDIR -name "*.ko" | parallel rm -rf {};

# wait for the successful ramdisk generation
while [ $(cat ${TMPFILE}) == 0 ]; do
	sleep 2;
	echo "${bldblu}Waiting for Ramdisk generation completion.${txtrst}";
done;

# make zImage
echo "${bldcya}***** Compiling kernel *****${txtrst}"
if [ $USER != "root" ]; then
#	make CONFIG_NO_ERROR_ON_MISMATCH=y -j5 zImage
	make CONFIG_DEBUG_SECTION_MISMATCH=y -j5 zImage
else
	nice -n -15 make -j5 zImage
fi;

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	echo "${bldcya}***** Final Touch for Kernel *****${txtrst}"
	cp $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/zImage;
	stat $KERNELDIR/zImage || exit 1;
	
	echo "--- Creating boot.img ---"
	# copy all needed to out kernel folder
#	./utilities/mkbootimg --kernel zImage --ramdisk ramdisk.gz --cmdline --base 0x10000000 --name SYSMAGIC000K --page_size 2048 --kernel_offset 0x00008000 --ramdisk_offset 0x01000000 --tags_offset 0x00000100 --dt_size 1083392 --output boot.img
        ./utilities/mkbootimg --kernel zImage --dt $KERNELDIR/utilities/dt.img --ramdisk ramdisk.gz --base 0x10000000 --kernel_offset 0x10000000 --ramdisk_offset 0x10008000 --tags_offset 0x10000100 --pagesize 2048 -o boot.img
	GETVER=`grep 'halaszk-*V' .config | sed 's/.*".//g' | sed 's/-S.*//g'`
	cp ${KERNELDIR}/.config ${KERNELDIR}/arch/arm/configs/${KERNEL_CONFIG}
	cp ${KERNELDIR}/.config ${KERNELDIR}/READY/
	stat ${KERNELDIR}/boot.img
	cp ${KERNELDIR}/boot.img /${KERNELDIR}/READY/boot/
	cd ${KERNELDIR}/READY/
	zip -r Kernel_${GETVER}-`date +"[%H-%M]-[%d-%m]-SM-G850-PWR-CORE"`.zip .
	rm ${KERNELDIR}/boot.img
	rm ${KERNELDIR}/READY/boot/boot.img
	rm ${KERNELDIR}/READY/.config
	echo "${bldcya}***** Ready *****${txtrst}";
	# finished? get elapsed time
	res2=$(date +%s.%N)
	echo "${bldgrn}Total time elapsed: ${txtrst}${grn}$(echo "($res2 - $res1) / 60"|bc ) minutes ($(echo "$res2 - $res1"|bc ) seconds) ${txtrst}";	
	while [ "$push_ok" != "y" ] && [ "$push_ok" != "n" ] && [ "$push_ok" != "Y" ] && [ "$push_ok" != "N" ]
	do
	      read -p "${bldblu}Do you want to push the kernel to the public FTP szerver?${txtrst}${blu} (y/n)${txtrst}" push_ok;
		sleep 1;
	done
	if [ "$push_ok" == "y" ] || [ "$push_ok" == "Y" ]; then
#	read -p "push kernel verion update to ftp and synapse (y/n)?"
#        if [ "$REPLY" == "y" ]; then
#                echo "${GETVER}" > ${KERNELDIR}/N910C/latest_version.txt;
#        fi;
		echo "Uploading kernel to FTP server";
		mv ${KERNELDIR}/READY/Kernel_* ${KERNELDIR}/G850/
		ncftpput -f /home/dev/login.cfg -V -R / ${KERNELDIR}/G850/
#		rm ${KERNELDIR}/N910C/Kernel_*
		echo "Uploading kernel to FTP server DONE";
	fi;
	exit 0;
else
	echo "${bldred}Kernel STUCK in BUILD!${txtrst}"
fi;

