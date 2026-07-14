DEPENDS:append = " tegra-helper-scripts-native"
PATH =. "${STAGING_BINDIR_NATIVE}/tegra-flash:"

mender_flash_layout_adjust() {
    local file=$1
    mv ${D}${datadir}/l4t-storage-layout/$file ${WORKDIR}/$file
    
    nvflashxmlparse -v --rewrite-contents-from=${WORKDIR}/UDA.xml \
        --output=${D}${datadir}/l4t-storage-layout/$file \
        ${WORKDIR}/$file
}

do_install:append() {
    cat <<EOF >${WORKDIR}/UDA.xml
<partition_layout>
    <device type="nvme" instance="0">
        <partition name="permanet_user_storage" id="17" type="data">
            <allocation_policy>sequential</allocation_policy>
            <filesystem_type>basic</filesystem_type>
            <size>419430400</size>
            <file_system_attribute>0</file_system_attribute>
            <allocation_attribute>0x808</allocation_attribute>
            <percent_reserved>0</percent_reserved>
            <align_boundary>16384</align_boundary>
            <filename>DATAFILE</filename>
            <description>Required. This partition is used to store permanent user and device data between A/B updates.</description>
        </partition>
    </device>
</partition_layout>
EOF

    mender_flash_layout_adjust "${PARTITION_LAYOUT_TEMPLATE}"
    mender_flash_layout_adjust "${PARTITION_LAYOUT_EXTERNAL}"
}