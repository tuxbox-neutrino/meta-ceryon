inherit image_types

IMAGE_FSTYPES += "tar.bz2"
IMAGE_ROOTFS = "${WORKDIR}/rootfs/linuxrootfs1"
IMAGE_ROOTFS_MAXSIZE = "1044480"

do_image_hd_emmc[depends] = " \
	e2fsprogs-native:do_populate_sysroot \
	parted-native:do_populate_sysroot \
	dosfstools-native:do_populate_sysroot \
	mtools-native:do_populate_sysroot \
	zip-native:do_populate_sysroot \
	virtual/kernel:do_populate_sysroot \
"

EMMC_IMAGE = "${IMGDEPLOYDIR}/${IMAGE_NAME}.emmc.img"
BLOCK_SIZE = "512"
BLOCK_SECTOR = "2"
IMAGE_ROOTFS_ALIGNMENT = "1024"
BOOT_PARTITION_SIZE = "3072"
KERNEL_PARTITION_SIZE = "8192"
ROOTFS_PARTITION_SIZE = "1048576"
EMMC_IMAGE_SIZE = "3817472"

KERNEL_PARTITION_OFFSET = "$(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_PARTITION_SIZE})"
ROOTFS_PARTITION_OFFSET = "$(expr ${KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})"
SECOND_KERNEL_PARTITION_OFFSET = "$(expr ${ROOTFS_PARTITION_OFFSET} \+ ${ROOTFS_PARTITION_SIZE})"
THRID_KERNEL_PARTITION_OFFSET = "$(expr ${SECOND_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})"
FOURTH_KERNEL_PARTITION_OFFSET = "$(expr ${THRID_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})"
MULTI_ROOTFS_PARTITION_OFFSET = "$(expr ${FOURTH_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})"

IMAGE_CMD_hd-emmc () {
    eval local COUNT=\"0\"
    eval local MIN_COUNT=\"60\"
    if [ $ROOTFS_SIZE -lt $MIN_COUNT ]; then
        eval COUNT=\"$MIN_COUNT\"
    fi
    dd if=/dev/zero of=${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.ext4 seek=${ROOTFS_SIZE} count=$COUNT bs=1024
    mkfs.ext4 -F -i 4096 ${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.ext4 -d ${WORKDIR}/rootfs
    ln -sf ${IMAGE_NAME}.rootfs.ext4 ${IMGDEPLOYDIR}/${IMAGE_LINK}.rootfs.ext4
    dd if=/dev/zero of=${EMMC_IMAGE} bs=${BLOCK_SIZE} count=0 seek=$(expr ${EMMC_IMAGE_SIZE} \* ${BLOCK_SECTOR})
    parted -s ${EMMC_IMAGE} mklabel gpt
    parted -s ${EMMC_IMAGE} unit KiB mkpart boot fat16 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${IMAGE_ROOTFS_ALIGNMENT} \+ ${BOOT_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart linuxkernel ${KERNEL_PARTITION_OFFSET} $(expr ${KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart linuxrootfs ext4 ${ROOTFS_PARTITION_OFFSET} $(expr ${ROOTFS_PARTITION_OFFSET} \+ ${ROOTFS_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart linuxkernel2 ${SECOND_KERNEL_PARTITION_OFFSET} $(expr ${SECOND_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart linuxkernel3 ${THRID_KERNEL_PARTITION_OFFSET} $(expr ${THRID_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart linuxkernel4 ${FOURTH_KERNEL_PARTITION_OFFSET} $(expr ${FOURTH_KERNEL_PARTITION_OFFSET} \+ ${KERNEL_PARTITION_SIZE})
    parted -s ${EMMC_IMAGE} unit KiB mkpart userdata ext4 ${MULTI_ROOTFS_PARTITION_OFFSET} 100%
    dd if=/dev/zero of=${WORKDIR}/boot.img bs=${BLOCK_SIZE} count=$(expr ${BOOT_PARTITION_SIZE} \* ${BLOCK_SECTOR})
    mkfs.msdos -S 512 ${WORKDIR}/boot.img
    echo "boot emmcflash0.linuxkernel 'root=/dev/mmcblk0p3 rootsubdir=linuxrootfs1 rw rootwait ${MACHINE}_4.boxmode=1'" > ${WORKDIR}/STARTUP
    echo "boot emmcflash0.linuxkernel 'root=/dev/mmcblk0p3 rootsubdir=linuxrootfs1 rw rootwait ${MACHINE}_4.boxmode=1'" > ${WORKDIR}/STARTUP_1
    echo "boot emmcflash0.linuxkernel2 'root=/dev/mmcblk0p7 rootsubdir=linuxrootfs2 rw rootwait ${MACHINE}_4.boxmode=1'" > ${WORKDIR}/STARTUP_2
    echo "boot emmcflash0.linuxkernel3 'root=/dev/mmcblk0p7 rootsubdir=linuxrootfs3 rw rootwait ${MACHINE}_4.boxmode=1'" > ${WORKDIR}/STARTUP_3
    echo "boot emmcflash0.linuxkernel4 'root=/dev/mmcblk0p7 rootsubdir=linuxrootfs4 rw rootwait ${MACHINE}_4.boxmode=1'" > ${WORKDIR}/STARTUP_4
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/STARTUP ::
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/STARTUP_1 ::
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/STARTUP_2 ::
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/STARTUP_3 ::
    mcopy -i ${WORKDIR}/boot.img -v ${WORKDIR}/STARTUP_4 ::
    dd conv=notrunc if=${WORKDIR}/boot.img of=${EMMC_IMAGE} bs=${BLOCK_SIZE} seek=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* ${BLOCK_SECTOR})
    dd conv=notrunc if=${DEPLOY_DIR_IMAGE}/zImage of=${EMMC_IMAGE} bs=${BLOCK_SIZE} seek=$(expr ${KERNEL_PARTITION_OFFSET} \* ${BLOCK_SECTOR})
    dd if=${IMGDEPLOYDIR}/${IMAGE_LINK}.rootfs.ext4 of=${EMMC_IMAGE} bs=${BLOCK_SIZE} seek=$(expr ${ROOTFS_PARTITION_OFFSET} \* ${BLOCK_SECTOR})
}

image_packaging() {
    cd ${DEPLOY_DIR_IMAGE}
    mkdir -p ${MACHINE}
    cp ${IMGDEPLOYDIR}/${IMAGE_NAME}.rootfs.tar.bz2 ${MACHINE}/rootfs.tar.bz2
    cp zImage ${MACHINE}/${KERNEL_FILE}
    echo ${IMAGE_NAME} > ${MACHINE}/imageversion
    zip ${IMAGE_NAME}_flavour_${FLAVOUR}_ofgwrite.zip ${MACHINE}/*
    ln -sf ${IMAGE_NAME}_flavour_${FLAVOUR}_ofgwrite.zip ${IMAGENAME}_ofgwrite.zip
    rm -Rf ${MACHINE}
    
    cd ${DEPLOY_DIR_IMAGE}
    mkdir -p ${MACHINE}
    cp -f ${IMGDEPLOYDIR}/${IMAGE_NAME}.emmc.img ${MACHINE}/disk.img
    echo ${IMAGE_NAME} > ${MACHINE}/imageversion
    echo ${IMAGE_NAME} > ${DEPLOY_DIR_IMAGE}/imageversion
    zip ${IMAGE_NAME}_flavour_${FLAVOUR}_usb.zip ${MACHINE}/*
    ln -sf ${IMAGE_NAME}_flavour_${FLAVOUR}_usb.zip ${IMAGENAME}_usb.zip
    rm -f ${DEPLOY_DIR_IMAGE}/*.tar
    rm -f ${DEPLOY_DIR_IMAGE}/*.ext4
    rm -f ${DEPLOY_DIR_IMAGE}/*.manifest
    rm -f ${DEPLOY_DIR_IMAGE}/*.json
    rm -f ${DEPLOY_DIR_IMAGE}/*.img
    rm -Rf ${MACHINE}
}

IMAGE_POSTPROCESS_COMMAND += "image_packaging; "
