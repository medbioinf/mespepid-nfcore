// Original file: mspepid/src/identification/xtandem_identification.nf (create_xtandem_params_files_from_default)
process XTANDEM_ADJUST_PARAMS {
    tag "${meta.id}"
    label 'process_low'
    label 'python_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(mzml)
    path xtandem_config_file
    path fasta
    val precursor_tol_ppm
    val fragment_tol_da

    output:
    tuple val(meta), path("*.xtandem_input.xml"), path(mzml), emit: param_file
    path "xtandem_taxonomy.xml"                              , emit: taxonomy_file
    path "versions.yml"                                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def xtandem_threads = task.ext.xtandem_threads ?: task.cpus
    """
    # write the taxonomy file
    echo '<?xml version="1.0"?>
<bioml label="x! taxon-to-file matching list">
  <taxon label="sample_species">
    <file format="peptide" URL="${fasta}" />
  </taxon>
</bioml>' > xtandem_taxonomy.xml

    # adjust parameters in the default file
    cp ${xtandem_config_file} ${meta.id}.xtandem_input.xml

    sed -i 's;<note type="input" label="list path, taxonomy information">[^<]*</note>;<note type="input" label="list path, taxonomy information">xtandem_taxonomy.xml</note>;' ${meta.id}.xtandem_input.xml

    sed -i 's;<note type="input" label="spectrum, path">[^<]*</note>;<note type="input" label="spectrum, path">${mzml}</note>;' ${meta.id}.xtandem_input.xml
    sed -i 's;<note type="input" label="output, path">[^<]*</note>;<note type="input" label="output, path">${meta.id}.xtandem_identification.t.xml</note>;' ${meta.id}.xtandem_input.xml

    sed -i 's;<note type="input" label="spectrum, fragment monoisotopic mass error">[^<]*</note>;<note type="input" label="spectrum, fragment monoisotopic mass error">${fragment_tol_da}</note>;' ${meta.id}.xtandem_input.xml
    sed -i 's;<note type="input" label="spectrum, fragment monoisotopic mass error units">[^<]*</note>;<note type="input" label="spectrum, fragment monoisotopic mass error units">Daltons</note>;' ${meta.id}.xtandem_input.xml

    sed -i 's;<note type="input" label="spectrum, parent monoisotopic mass error minus">[^<]*</note>;<note type="input" label="spectrum, parent monoisotopic mass error minus">${precursor_tol_ppm}</note>;' ${meta.id}.xtandem_input.xml
    sed -i 's;<note type="input" label="spectrum, parent monoisotopic mass error plus">[^<]*</note>;<note type="input" label="spectrum, parent monoisotopic mass error plus">${precursor_tol_ppm}</note>;' ${meta.id}.xtandem_input.xml
    sed -i 's;<note type="input" label="spectrum, parent monoisotopic mass error units">[^<]*</note>;<note type="input" label="spectrum, parent monoisotopic mass error units">ppm</note>;' ${meta.id}.xtandem_input.xml

    sed -i 's;<note type="input" label="spectrum, threads">[^<]*</note>;<note type="input" label="spectrum, threads">${xtandem_threads}</note>;' ${meta.id}.xtandem_input.xml

    # rename absolute paths to current path, to allow for clean passing on in workflow
    workDir=\$(pwd)
    sed -i "s;\$workDir/;;g" ${meta.id}.xtandem_input.xml

    ${args}

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    sed: \$(sed --version 2>&1 | head -n 1 | sed 's/sed (GNU sed) //')
END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.xtandem_input.xml
    touch xtandem_taxonomy.xml

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    sed: \$(sed --version 2>&1 | head -n 1 | sed 's/sed (GNU sed) //')
END_VERSIONS
    """
}
