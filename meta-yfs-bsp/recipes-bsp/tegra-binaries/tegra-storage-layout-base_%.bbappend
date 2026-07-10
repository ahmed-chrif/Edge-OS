DEPENDS:append = " tegra-helper-scripts-native"
PATH =. "${STAGING_BINDIR_NATIVE}/tegra-flash:"
IMAGE_FSTYPES += "dataimg"

mender_flash_layout_adjust() {
    local file=$1
    if [ -e "${D}${datadir}/l4t-storage-layout/$file" ]; then
        mv ${D}${datadir}/l4t-storage-layout/$file ${WORKDIR}/$file
        nvflashxmlparse -v --rewrite-contents-from=${WORKDIR}/UDA.xml \
            --output=${D}${datadir}/l4t-storage-layout/$file \
            ${WORKDIR}/$file
    fi
}

do_install:append() {
    # Define the minimal XML patch to hijack the existing UDA partition slot
    cat <<EOF >${WORKDIR}/UDA.xml
<partition_layout>
    <device>
        <partition name="UDA">
            <filename> DATAFILE </filename>
        </partition>
    </device>
</partition_layout>
EOF

    # Apply the patch to the active layouts
    mender_flash_layout_adjust "${PARTITION_LAYOUT_TEMPLATE}"
    if [ -n "${PARTITION_LAYOUT_EXTERNAL}" ]; then
        mender_flash_layout_adjust "${PARTITION_LAYOUT_EXTERNAL}"
    fi
}

# Apply boundary expansion specifically for the Jetson Orin Nano architecture
do_install:append:tegra234() {
    # Remove hardcoded start locations from upstream L4T partition layout files
    # to allow the UDA/data partition to dynamically expand and use all remaining NVMe space.
    sed -i -e 's#<start_location> [^<]* </start_location>##g' \
           ${D}${datadir}/l4t-storage-layout/${PARTITION_LAYOUT_TEMPLATE}
    
    if [ -n "${PARTITION_LAYOUT_EXTERNAL}" ] && [ -e "${D}${datadir}/l4t-storage-layout/${PARTITION_LAYOUT_EXTERNAL}" ]; then
        sed -i -e 's#<start_location> [^<]* </start_location>##g' \
               ${D}${datadir}/l4t-storage-layout/${PARTITION_LAYOUT_EXTERNAL}
    fi
}