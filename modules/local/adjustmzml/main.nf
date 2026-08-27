/*
 * Append a "scan=" native ID alongside Bruker TDF's "index="-only native ID
 * (needed e.g. by Oktoberfest/MSAmanda), and re-serializing through msconvert.
 * Also allows to un-zip the spectra while doing so, if needed by the search
 * engine (e.g. X!Tandem).
 **/
process ADJUSTMZML {
    tag "${meta.id}"
    label 'process_medium'

    // Lives on Docker Hub, not quay.io (this pipeline's default registry)
    // No singularity/apptainer support for now.
    container "docker.io/proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses:3.0.26121-ed8dc8a"

    input:
    tuple val(meta), path(mzml)

    output:
    tuple val(meta), path("reindexed/${prefix}.mzML"), emit: mzml
    tuple val("${task.process}"), val('proteowizard'), eval('wine msconvert --help 2>&1 | grep "ProteoWizard release:" | sed -e "s;ProteoWizard release: \\(.*\\);\\1;"'), topic: versions, emit: versions_adjustmzml

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    // whether to fix the spectrum id string
    def needs_native_id_fix = meta.needs_native_id_fix ?: false
    // whether to decompress the binary data arrays (e.g. needed by X!Tandem), defaults to off
    def uncompress_arg = meta.uncompress ? '--zlib=off' : ''
    """
    # The currently used image bakes WINEPREFIX=/wineprefix64 owned by root, but nf-core runs
    # containers as the host user, so wine refuses to use it ("is not owned by you"). These
    # first lines give it a prefix it does own: symlink the big, read-only drive_c, and copy
    # only the small mutable registry state.
    export WINEPREFIX="\${PWD}/.wineprefix64"
    mkdir -p "\${WINEPREFIX}"
    ln -s /wineprefix64/drive_c "\${WINEPREFIX}/drive_c"
    cp -r /wineprefix64/dosdevices "\${WINEPREFIX}/dosdevices"
    cp /wineprefix64/system.reg /wineprefix64/user.reg /wineprefix64/userdef.reg "\${WINEPREFIX}/"

    if [ "${needs_native_id_fix}" = "true" ]; then
        # some tools need explicit "scan=" in the id of a scan (not there in
        # e.g. TimsTOF-converted mzML data) - append it alongside the existing "index="
        # rather than replacing it, so anything keying off "index=" elsewhere keeps working.
        sed -e 's/<spectrum\\(.*\\) id="index=\\([0-9]*\\)\\(.*\\)/<spectrum\\1 id="index=\\2 scan=\\2\\3/;s/spectrumRef="\\(.*\\)index=\\([0-9]*\\)\\(.*\\)"/spectrumRef="\\1index=\\2 scan=\\2\\3"/' ${mzml} > reindexed.mzML
    else
        cp ${mzml} reindexed.mzML
    fi

    # call msconvert to recompute the indexedmzML index/checksum
    # (stale after the text edit above)
    mkdir reindexed
    wine msconvert ${args} --mzML ${uncompress_arg} -o reindexed --outfile ${prefix}.mzML reindexed.mzML

    # remove this intermediate file to save space, since it's not needed anymore
    rm reindexed.mzML
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.mzML
    """
}
