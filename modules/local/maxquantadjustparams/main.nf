process MAXQUANT_ADJUST_PARAMS {
    tag "$meta.id"
    label 'process_low'
    label 'maxquant_image'

    // TODO nf-core: See section in main README for further information regarding finding and adding container addresses to the section below.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/YOUR-TOOL-HERE':
        'biocontainers/YOUR-TOOL-HERE' }"

    input:
    tuple val(meta), path(spectra_file), path(fasta), path(maxquant_params)
    val precursor_tol_ppm

    output:
    tuple val(meta), path(spectra_file), path(fasta), path("*_final.xml"), emit: params
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    
    // Extract file type from metadata (original file extension)
    def file_type = meta.ext ?: 'mzml'
    
    // Set instrument-specific parameters based on file type
    def is_bruker = file_type == 'd'
    def maxquant_quantmode = is_bruker ? 2 : 1
    def maxquant_msinstrument = is_bruker ? 4 : 0
    def maxquant_usems1centroids = is_bruker ? 'False' : 'True'
    def maxquant_usems2centroids = is_bruker ? 'False' : 'True'
    def maxquant_intensitydetermination = is_bruker ? 1 : 0
    def maxquant_advancedpeaksplitting = is_bruker ? 'True' : 'False'
    def maxquant_intensitythresholds1dda = is_bruker ? 35 : 0
    def maxquant_lcmsruntype = is_bruker ? 'TIMS-DDA' : 'Standard'
    def maxquant_lfqmode = is_bruker ? 1 : 0
    def maxquant_mainsearchtol = is_bruker ? 10 : 4.5
    def maxquant_isotopematchtol = is_bruker ? 0.005 : 2
    def maxquant_isotopematchtolinppm = is_bruker ? 'False' : 'True'
    def maxquant_checkmassdeficit = is_bruker ? 'False' : 'True'
    def maxquant_intensitydependentcalibration = is_bruker ? 'True' : 'False'
    def maxquant_minscoreforcalibration = is_bruker ? 40 : 70
    def maxquant_timshalfwidth = is_bruker ? 10 : 0
    def maxquant_timsstep = is_bruker ? 3 : 0
    def maxquant_timsresolution = is_bruker ? 35000 : 0
    def maxquant_timsminmsmsintensity = is_bruker ? 1.5 : 0
    def maxquant_lfqtopncorrelatingpeptides = is_bruker ? 100 : 3
    def maxquant_lfqpeptidecorrelation = is_bruker ? 0 : 3

    """
    cp ${maxquant_params} ${prefix}.xml

    # Set FASTA file path
    sed -i "s;<fastaFilePath>[^<]*</fastaFilePath>;<fastaFilePath>${fasta}</fastaFilePath>;" ${prefix}.xml

    # Set spectra file path
    sed -i "s;<string>CHANGEME_FILE_PATH</string>;<string>${spectra_file}</string>;" ${prefix}.xml

    # Set instrument-specific parameters
    sed -i "s;<quantMode>[^<]*</quantMode>;<quantMode>${maxquant_quantmode}</quantMode>;" ${prefix}.xml
    sed -i "s;<numThreads>[^<]*</numThreads>;<numThreads>${task.cpus}</numThreads>;" ${prefix}.xml
    sed -i "s;<msInstrument>[^<]*</msInstrument>;<msInstrument>${maxquant_msinstrument}</msInstrument>;" ${prefix}.xml
    sed -i "s;<useMs1Centroids>[^<]*</useMs1Centroids>;<useMs1Centroids>${maxquant_usems1centroids}</useMs1Centroids>;" ${prefix}.xml
    sed -i "s;<useMs2Centroids>[^<]*</useMs2Centroids>;<useMs2Centroids>${maxquant_usems2centroids}</useMs2Centroids>;" ${prefix}.xml
    sed -i "s;<intensityDetermination>[^<]*</intensityDetermination>;<intensityDetermination>${maxquant_intensitydetermination}</intensityDetermination>;" ${prefix}.xml
    sed -i "s;<advancedPeakSplitting>[^<]*</advancedPeakSplitting>;<advancedPeakSplitting>${maxquant_advancedpeaksplitting}</advancedPeakSplitting>;" ${prefix}.xml
    sed -i "s;<intensityThresholdMs1Dda>[^<]*</intensityThresholdMs1Dda>;<intensityThresholdMs1Dda>${maxquant_intensitythresholds1dda}</intensityThresholdMs1Dda>;" ${prefix}.xml
    sed -i "s;<lcmsRunType>[^<]*</lcmsRunType>;<lcmsRunType>${maxquant_lcmsruntype}</lcmsRunType>;" ${prefix}.xml
    sed -i "s;<lfqMode>[^<]*</lfqMode>;<lfqMode>${maxquant_lfqmode}</lfqMode>;" ${prefix}.xml

    # Set mass tolerance parameters
    sed -i "s;<firstSearchTol>[^<]*</firstSearchTol>;<firstSearchTol>${precursor_tol_ppm}</firstSearchTol>;" ${prefix}.xml
    sed -i "s;<mainSearchTol>[^<]*</mainSearchTol>;<mainSearchTol>${maxquant_mainsearchtol}</mainSearchTol>;" ${prefix}.xml
    sed -i "s;<searchTolInPpm>[^<]*</searchTolInPpm>;<searchTolInPpm>True</searchTolInPpm>;" ${prefix}.xml
    sed -i "s;<isotopeMatchTol>[^<]*</isotopeMatchTol>;<isotopeMatchTol>${maxquant_isotopematchtol}</isotopeMatchTol>;" ${prefix}.xml
    sed -i "s;<isotopeMatchTolInPpm>[^<]*</isotopeMatchTolInPpm>;<isotopeMatchTolInPpm>${maxquant_isotopematchtolinppm}</isotopeMatchTolInPpm>;" ${prefix}.xml
    sed -i "s;<checkMassDeficit>[^<]*</checkMassDeficit>;<checkMassDeficit>${maxquant_checkmassdeficit}</checkMassDeficit>;" ${prefix}.xml
    sed -i "s;<intensityDependentCalibration>[^<]*</intensityDependentCalibration>;<intensityDependentCalibration>${maxquant_intensitydependentcalibration}</intensityDependentCalibration>;" ${prefix}.xml
    sed -i "s;<minScoreForCalibration>[^<]*</minScoreForCalibration>;<minScoreForCalibration>${maxquant_minscoreforcalibration}</minScoreForCalibration>;" ${prefix}.xml

    # Set TIMS-specific parameters
    sed -i "s;<timsHalfWidth>[^<]*</timsHalfWidth>;<timsHalfWidth>${maxquant_timshalfwidth}</timsHalfWidth>;" ${prefix}.xml
    sed -i "s;<timsStep>[^<]*</timsStep>;<timsStep>${maxquant_timsstep}</timsStep>;" ${prefix}.xml
    sed -i "s;<timsResolution>[^<]*</timsResolution>;<timsResolution>${maxquant_timsresolution}</timsResolution>;" ${prefix}.xml
    sed -i "s;<timsMinMsmsIntensity>[^<]*</timsMinMsmsIntensity>;<timsMinMsmsIntensity>${maxquant_timsminmsmsintensity}</timsMinMsmsIntensity>;" ${prefix}.xml

    # Set LFQ parameters
    sed -i "s;<lfqTopNCorrelatingPeptides>[^<]*</lfqTopNCorrelatingPeptides>;<lfqTopNCorrelatingPeptides>${maxquant_lfqtopncorrelatingpeptides}</lfqTopNCorrelatingPeptides>;" ${prefix}.xml
    sed -i "s;<lfqPeptideCorrelation>[^<]*</lfqPeptideCorrelation>;<lfqPeptideCorrelation>${maxquant_lfqpeptidecorrelation}</lfqPeptideCorrelation>;" ${prefix}.xml
    $args

    # Use changeFolder to adjust all paths to absolute paths
    # Note: Do NOT set fixedSearchFolder - let MaxQuant create output in current directory
    dotnet /opt/MaxQuant/bin/MaxQuantCmd.dll ${prefix}.xml --changeFolder ${prefix}_final.xml ./ ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | head -n 1 | sed 's/sed (GNU sed) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_final.xml
    touch versions.yml
    
    touch ${prefix}.bam
    """
}
