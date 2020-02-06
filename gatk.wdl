version 1.0

# Copyright (c) 2018 Leiden University Medical Center
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

task AnnotateIntervals {
    input {
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        String annotatedIntervalsPath = "intervals.annotated.tsv"
        File intervals
        String intervalMergingRule = "OVERLAPPING_ONLY"
        File? mappabilityTrack
        File? segmentalDuplicationTrack
        Int featureQueryLookahead = 1000000

        String memory = "10G"
        String javaXmx = "2G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{annotatedIntervalsPath})"
        gatk --java-options -Xmx~{javaXmx} \
        AnnotateIntervals \
        -R ~{referenceFasta} \
        -L ~{intervals} \
        ~{"--mappability-track  " + mappabilityTrack} \
        ~{"--segmental-duplication-track " + segmentalDuplicationTrack} \
        --feature-query-lookahead ~{featureQueryLookahead} \
        --interval-merging-rule ~{intervalMergingRule} \
        -O ~{annotatedIntervalsPath}
    }

    output {
        File annotatedIntervals = annotatedIntervalsPath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFasta: {description: "The reference fasta file.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        annotatedIntervalsPath: {description: "The location the output should be written to.", category: "advanced"}
        intervals: {description: "An interval list describinig the intervals to annotate.", category: "required"}
        intervalMergingRule: {description: "Equivalent to gatk AnnotateIntervals' `--interval-merging-rule` option.", category: "advanced"}
        mappabilityTrack: {description: "Equivalent to gatk AnnotateIntervals' `--mappability-track` option.", category: "common"}
        segmentalDuplicationTrack: {description: "Equivalent to gatk AnnotateIntervals' `--segmenta-duplicarion-track` option.", category: "common"}
        featureQueryLookahead: {description: "Equivalent to gatk AnnotateIntervals' `--feature-query-lookahead` option", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

# Apply Base Quality Score Recalibration (BQSR) model
task ApplyBQSR {
    input {
        File inputBam
        File inputBamIndex
        String outputBamPath
        File recalibrationReport
        Array[File] sequenceGroupInterval = []
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai

        String memory = "12G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputBamPath})"
        gatk --java-options -Xmx~{javaXmx} \
        ApplyBQSR \
        --create-output-bam-md5 \
        --add-output-sam-program-record \
        -R ~{referenceFasta} \
        -I ~{inputBam} \
        --use-original-qualities \
        -O ~{outputBamPath} \
        -bqsr ~{recalibrationReport} \
        --static-quantized-quals 10 \
        --static-quantized-quals 20 \
        --static-quantized-quals 30 \
        ~{true="-L" false="" length(sequenceGroupInterval) > 0} ~{sep=' -L ' sequenceGroupInterval}
    }

    output {
        File recalibratedBam = outputBamPath
        File recalibratedBamIndex = sub(outputBamPath, "\.bam$", ".bai")
        File recalibratedBamMd5 = outputBamPath + ".md5"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBam: {description: "The BAM file which should be recalibrated.", category: "required"}
        inputBamIndex: {description: "The input BAM file's index.", category: "required"}
        outputBamPath: {description: "The location the resulting BAM file should be written.", category: "required"}
        recalibrationReport: {description: "The BQSR report the be used for recalibration.", category: "required"}
        sequenceGroupInterval: {description: "Bed files describing the regions to operate on.", category: "advanced"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

# Generate Base Quality Score Recalibration (BQSR) model
task BaseRecalibrator {
    input {
        File inputBam
        File inputBamIndex
        String recalibrationReportPath
        Array[File] sequenceGroupInterval = []
        Array[File] knownIndelsSitesVCFs = []
        Array[File] knownIndelsSitesVCFIndexes = []
        File? dbsnpVCF
        File? dbsnpVCFIndex
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai

        String memory = "12G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{recalibrationReportPath})"
        gatk --java-options -Xmx~{javaXmx} \
        BaseRecalibrator \
        -R ~{referenceFasta} \
        -I ~{inputBam} \
        --use-original-qualities \
        -O ~{recalibrationReportPath} \
        ~{true="--known-sites" false="" length(knownIndelsSitesVCFs) > 0} ~{sep=" --known-sites " knownIndelsSitesVCFs} \
        ~{"--known-sites " + dbsnpVCF} \
        ~{true="-L" false="" length(sequenceGroupInterval) > 0} ~{sep=' -L ' sequenceGroupInterval}
    }

    output {
        File recalibrationReport = recalibrationReportPath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBam: {description: "The BAM file to generate a BQSR report for.", category: "required"}
        inputBamIndex: {description: "The index of the input BAM file.", category: "required"}
        recalibrationReportPath: {description: "The location to write the BQSR report to.", category: "required"}
        sequenceGroupInterval: {description: "Bed files describing the regions to operate on.", category: "advanced"}
        knownIndelsSitesVCFs: {description: "VCF files with known indels.", category: "advanced"}
        knownIndelsSitesVCFIndexes: {description: "The indexed for the known variant VCFs.", category: "advanced"}
        dbsnpVCF: {description: "A dbSNP VCF.", category: "common"}
        dbsnpVCFIndex: {description: "The index for the dbSNP VCF.", category: "common"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CalculateContamination {
    input {
        File tumorPileups
        File? normalPileups

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.2.0--1"
    }

    command {
        set -e
        gatk --java-options -Xmx~{javaXmx} \
        CalculateContamination \
        -I ~{tumorPileups} \
        ~{"-matched " + normalPileups} \
        -O "contamination.table" \
        --tumor-segmentation "segments.table"
    }

    output {
        File contaminationTable = "contamination.table"
        File mafTumorSegments = "segments.table"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        tumorPileups: {description: "The pileup summary of a tumor/case sample.", category: "required"}
        normalPileups: {description: "The pileup summary of the normal/control sample.", category: "common"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CallCopyRatioSegments {
    input {
        String outputPrefix
        File copyRatioSegments

        String memory = "21G"
        String javaXmx = "6G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPrefix})"
        gatk --java-options -Xmx~{javaXmx} \
        CallCopyRatioSegments \
        -I ~{copyRatioSegments} \
        -O ~{outputPrefix}.called.seg
    }

    output {
        File calledSegments = outputPrefix + ".called.seg"
        File calledSegmentsIgv = outputPrefix + ".called.igv.seg"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        outputPrefix: {description: "The prefix for the output files.", category: "required"}
        copyRatioSegments: {description: "The copy ratios file generated by gatk ModelSegments.", category: "required"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CollectAllelicCounts {
    input {
        String allelicCountsPath = "allelic_counts.tsv"
        File commonVariantSites
        File? commonVariantSitesIndex
        File inputBam
        File inputBamIndex
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        String memory = "90G"
        String javaXmx = "30G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{allelicCountsPath})"
        gatk --java-options -Xmx~{javaXmx} \
        CollectAllelicCounts \
        -L ~{commonVariantSites} \
        -I ~{inputBam} \
        -R ~{referenceFasta} \
        -O ~{allelicCountsPath}
    }

    output {
        File allelicCounts = allelicCountsPath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        allelicCountsPath: {description: "The path the output should be written to.", category: "advanced"}
        commonVariantSites: {description: "Interval list or vcf of common variant sites (to retrieve the allelic counts for).", category: "required"}
        commonVariantSitesIndex: {description: "The index for commonVariantSites.", category: "common"}
        inputBam: {description: "The BAM file to generate counts for.", category: "required"}
        inputBamIndex: {description: "The index of the input BAM file.", category: "required"}
        referenceFasta: {description: "The reference fasta file.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CollectReadCounts {
    input {
        String countsPath = "readcounts.hdf5"
        File intervals
        File inputBam
        File inputBamIndex
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        String intervalMergingRule = "OVERLAPPING_ONLY"

        String memory = "35G"
        String javaXmx = "7G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{countsPath})"
        gatk --java-options -Xmx~{javaXmx} \
        CollectReadCounts \
        -L ~{intervals} \
        -I ~{inputBam} \
        -R ~{referenceFasta} \
        --format HDF5 \
        --interval-merging-rule ~{intervalMergingRule} \
        -O ~{countsPath}
    }

    output {
        File counts = countsPath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        countsPath: {description: "The location the output should be written to.", category: "advanced"}
        intervals: {description: "The intervals to collect counts for.", category: "required"}
        inputBam: {description: "The BAM file to determine the coverage for.", category: "required"}
        inputBamIndex: {description: "The input BAM file's index.", category: "required"}
        referenceFasta: {description: "The reference fasta file.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        intervalMergingRule: {description: "Equivalent to gatk CollectReadCounts' `--interval-merging-rule` option.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CombineGVCFs {
    input {
        Array[File]+ gvcfFiles
        Array[File]+ gvcfFilesIndex
        Array[File] intervals = []
        String outputPath
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPath})"
        gatk --java-options -Xmx~{javaXmx} \
        CombineGVCFs \
        -R ~{referenceFasta} \
        -O ~{outputPath} \
        -V ~{sep=' -V ' gvcfFiles} \
        ~{true='-L' false='' length(intervals) > 0} ~{sep=' -L ' intervals}
    }

    output {
        File outputVcf = outputPath
        File outputVcfIndex = outputPath + ".tbi"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        gvcfFiles: {description: "The GVCF files to be combined.", category: "required"}
        gvcfFilesIndex: {description: "The indexes for the GVCF files.", caregory: "required"}
        intervals: {description: "Bed files or interval lists describing the regions to operate on.", category: "advanced"}
        outputPath: {description: "The location the combined GVCF should be written to.", category: "required"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CombineVariants {
    input {
        File referenceFasta
        File referenceFastaFai
        File referenceFastaDict
        String genotypeMergeOption = "UNIQUIFY"
        String filteredRecordsMergeType = "KEEP_IF_ANY_UNFILTERED"
        Array[String]+ identifiers
        Array[File]+ variantVcfs # follow "identifiers" array order
        Array[File]+ variantIndexes
        String outputPath

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command <<<
        set -e
        mkdir -p "$(dirname ~{outputPath})"

        # build "-V:<ID> <file.vcf>" arguments according to IDs and VCFs to merge
        # Make sure commands are run in bash
        V_args=$(bash -c '
        set -eu
        ids=(~{sep=" " identifiers})
        vars=(~{sep=" " variantVcfs})
        for (( i = 0; i < ${#ids[@]}; ++i ))
          do
            printf -- "-V:%s %s " "${ids[i]}" "${vars[i]}"
          done
        ')
        java -Xmx~{javaXmx} -jar /usr/GenomeAnalysisTK.jar \
        -T CombineVariants \
        -R ~{referenceFasta} \
        --genotypemergeoption ~{genotypeMergeOption} \
        --filteredrecordsmergetype ~{filteredRecordsMergeType} \
        --out ~{outputPath} \
        $V_args
    >>>

    output {
        File combinedVcf = outputPath
        File combinedVcfIndex = outputPath + ".tbi"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFasta: {description: "The reference fasta file which was also used for mapping.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        genotypeMergeOption: {description: "Equivalent to CombineVariants' `--genotypemergeoption` option.", category: "advanced"}
        filteredRecordsMergeType: {description: "Equivalent to CombineVariants' `--filteredrecordsmergetype` option.", category: "advanced"}
        identifiers: {description: "The sample identifiers in the same order as variantVcfs.", category: "required"}
        variantVcfs: {description: "The input VCF files in the same order as identifiers.", category: "required"}
        variantIndexes: {description: "The indexes of the input VCF files.", category: "required"}
        outputPath: {description: "The location the output should be written to", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task CreateReadCountPanelOfNormals {
    input {
        String PONpath = "PON.hdf5"
        Array[File]+ readCountsFiles
        File? annotatedIntervals

        String memory = "21G"
        String javaXmx = "7G"
        String dockerImage = "broadinstitute/gatk:4.1.4.0" # The biocontainer causes a spark related error for some reason...
    }

    command {
        set -e
        mkdir -p "$(dirname ~{PONpath})"
        gatk --java-options -Xmx~{javaXmx} \
        CreateReadCountPanelOfNormals \
        -I ~{sep=" -I " readCountsFiles} \
        ~{"--annotated-intervals " + annotatedIntervals} \
        -O ~{PONpath}
    }

    output {
        File PON = PONpath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        PONpath: {description: "The location the PON should be written to.", category: "common"}
        readCountsFiles: {description: "The read counts files as generated by CollectReadCounts.", category: "required"}
        annotatedIntervals: {description: "An annotation set of intervals as generated by AnnotateIntervals. If provided, explicit GC correction will be performed.",
                             category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task DenoiseReadCounts {
    input {
        File? PON
        File? annotatedIntervals
        File readCounts
        String outputPrefix

        String memory = "39G"
        String javaXmx = "13G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPrefix})"
        gatk --java-options -Xmx~{javaXmx} \
        DenoiseReadCounts \
        -I ~{readCounts} \
        ~{"--count-panel-of-normals " + PON} \
        ~{"--annotated-intervals " + annotatedIntervals} \
        --standardized-copy-ratios ~{outputPrefix}.standardizedCR.tsv \
        --denoised-copy-ratios ~{outputPrefix}.denoisedCR.tsv
    }

    output {
        File standardizedCopyRatios = outputPrefix + ".standardizedCR.tsv"
        File denoisedCopyRatios = outputPrefix + ".denoisedCR.tsv"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        PON: {description: "A panel of normals as generated by CreateReadCountPanelOfNormals.", category: "advanced"}
        annotatedIntervals: {description: "An annotated set of intervals as generated by AnnotateIntervals. Will be ignored if PON is provided.",
                             category: "advanced"}
        readCounts: {description: "The read counts file as generated by CollectReadCounts.", category: "required"}
        outputPrefix: {description: "The prefix for the output files.", category: "required"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task FilterMutectCalls {
    input {
        File referenceFasta
        File referenceFastaFai
        File referenceFastaDict
        File unfilteredVcf
        File unfilteredVcfIndex
        String outputVcf
        File? contaminationTable
        File? mafTumorSegments
        File? artifactPriors
        Int uniqueAltReadCount = 4
        File mutect2Stats

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.2.0--1"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputVcf})"
        gatk --java-options -Xmx~{javaXmx} \
        FilterMutectCalls \
        -R ~{referenceFasta} \
        -V ~{unfilteredVcf} \
        -O ~{outputVcf} \
        ~{"--contamination-table " + contaminationTable} \
        ~{"--tumor-segmentation " + mafTumorSegments} \
        ~{"--ob-priors " + artifactPriors} \
        ~{"--unique-alt-read-count " + uniqueAltReadCount} \
        ~{"-stats " + mutect2Stats} \
        --filtering-stats "filtering.stats" \
        --showHidden
    }

    output {
        File filteredVcf = outputVcf
        File filteredVcfIndex = outputVcf + ".tbi"
        File filteringStats = "filtering.stats"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFasta: {description: "The reference fasta file which was also used for mapping.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        unfilteredVcf: {description: "An unfiltered VCF file as produced by Mutect2.", category: "required"}
        unfilteredVcfIndex: {description: "The index of the unfiltered VCF file.", category: "required"}
        outputVcf: {description: "The location the filtered VCF file should be written.", category: "required"}
        contaminationTable: {description: "Equivalent to FilterMutectCalls' `--contamination-table` option.", category: "advanced"}
        mafTumorSegments: {description: "Equivalent to FilterMutectCalls' `--tumor-segmentation` option.", category: "advanced"}
        artifactPriors: {description: "Equivalent to FilterMutectCalls' `--ob-priors` option.", category: "advanced"}
        uniqueAltReadCount: {description: "Equivalent to FilterMutectCalls' `--unique-alt-read-count` option.", category: "advanced"}
        mutect2Stats: {description: "Equivalent to FilterMutectCalls' `-stats` option.", category: "advanced"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

# Combine multiple recalibration tables from scattered BaseRecalibrator runs
task GatherBqsrReports {
    input {
        Array[File] inputBQSRreports
        String outputReportPath

        String memory = "12G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputReportPath})"
        gatk --java-options -Xmx~{javaXmx} \
        GatherBQSRReports \
        -I ~{sep=' -I ' inputBQSRreports} \
        -O ~{outputReportPath}
    }

    output {
        File outputBQSRreport = outputReportPath
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBQSRreports: {description: "The BQSR reports to be merged.", category: "required"}
        outputReportPath: {description: "The location of the combined BQSR report.", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task GenomicsDBImport {
    input {
        Array[File] gvcfFiles
        Array[File] gvcfFilesIndex
        Array[File]+ intervals
        String genomicsDBWorkspacePath = "genomics_db"
        String genomicsDBTarFile = "genomics_db.tar.gz"
        String? tmpDir
        String memory = "12G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{genomicsDBWorkspacePath})"
        gatk --java-options -Xmx~{javaXmx} \
        GenomicsDBImport \
        -V ~{sep=" -V " gvcfFiles} \
        --genomicsdb-workspace-path ~{genomicsDBWorkspacePath} \
        ~{"--tmp-dir " + tmpDir} \
        -L ~{sep=" -L " intervals}
        bash -c 'tar -cvzf ~{genomicsDBTarFile} ~{genomicsDBWorkspacePath}/*'
    }

    output {
        File genomicsDbTarArchive = genomicsDBTarFile
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        gvcfFiles: {description: "The gvcfFiles to be merged.", category: "required"}
        gvcfFilesIndex: {description: "Indexes for the gvcfFiles.", category: "required"}
        intervals: {description: "intervals over which to operate.", category: "required"}
        genomicsDBWorkspacePath: {description: "Where the genomicsDB files should be stored", category: "advanced"}
        genomicsDBTarFile: {description: "Where the .tar file containing the genomicsDB should be stored", category: "advanced"}
        tmpDir: {description: "Alternate temporary directory in case there is not enough space. Must be mounted when using containers",
        category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task GenotypeGVCFs {
    input {
        File gvcfFile
        File gvcfFileIndex
        Array[File]+ intervals
        String outputPath
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        Array[String] annotationGroups = ["StandardAnnotation"]
        File? dbsnpVCF
        File? dbsnpVCFIndex

        String memory = "18G"
        String javaXmx = "6G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPath})"
        gatk --java-options -Xmx~{javaXmx} \
        GenotypeGVCFs \
        -R ~{referenceFasta} \
        -O ~{outputPath} \
        ~{"-D " + dbsnpVCF} \
        ~{true="-G" false="" length(annotationGroups) > 0} ~{sep=" -G " annotationGroups} \
        --only-output-calls-starting-in-intervals \
        -V ~{gvcfFile} \
        -L ~{sep=' -L ' intervals}
    }

    output {
        File outputVCF = outputPath
        File outputVCFIndex = outputPath + ".tbi"

    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        gvcfFile: {description: "The GVCF file to be genotyped.", category: "required"}
        gvcfFileIndex: {description: "The index of the input GVCF file.", category: "required"}
        intervals: {description: "Bed files or interval lists describing the regions to operate on.", category: "required"}
        outputPath: {description: "The location to write the output VCF file to.", category: "required"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        annotationGroups: {description: "Which annotation groups will be used for the annotation", category: "advanced"}
        dbsnpVCF: {description: "A dbSNP VCF.", category: "common"}
        dbsnpVCFIndex: {description: "The index for the dbSNP VCF.", category: "common"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task GetPileupSummaries {
    input {
        File sampleBam
        File sampleBamIndex
        File variantsForContamination
        File variantsForContaminationIndex
        File sitesForContamination
        File sitesForContaminationIndex
        String outputPrefix

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.2.0--1"
    }

    command {
        set -e
        gatk --java-options -Xmx~{javaXmx} \
        GetPileupSummaries \
        -I ~{sampleBam} \
        -V ~{variantsForContamination} \
        -L ~{sitesForContamination} \
        -O ~{outputPrefix + "-pileups.table"}
    }

    output {
        File pileups = outputPrefix + "-pileups.table"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        sampleBam: {description: "A BAM file for which a pileup should be created.", category: "required"}
        sampleBamIndex: {description: "The index of the input BAM file.", category: "required"}
        variantsForContamination: {description: "A VCF file with common variants.", category: "required"}
        variantsForContaminationIndex: {description: "The index for the common variants VCF file.", category: "required"}
        sitesForContamination: {description: "A bed file describing regions to operate on.", category: "required"}
        sitesForContaminationIndex: {description: "The index for the bed file.", category: "required"}
        outputPrefix: {description: "The prefix for the ouput.", category: "required"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

# Call variants on a single sample with HaplotypeCaller to produce a GVCF
task HaplotypeCaller {
    input {
        Array[File]+ inputBams
        Array[File]+ inputBamsIndex
        Array[File]+? intervalList
        Array[File]+? excludeIntervalList
        String outputPath
        File referenceFasta
        File referenceFastaIndex
        File referenceFastaDict
        Float? contamination
        File? dbsnpVCF
        File? dbsnpVCFIndex
        File? pedigree
        Int? ploidy
        Boolean gvcf = false

        String memory = "12G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPath})"
        gatk --java-options -Xmx~{javaXmx} \
        HaplotypeCaller \
        -R ~{referenceFasta} \
        -O ~{outputPath} \
        -I ~{sep=" -I " inputBams} \
        ~{"--sample-ploidy " + ploidy} \
        ~{true="-L" false="" defined(intervalList)} ~{sep=' -L ' intervalList} \
        ~{true="-XL" false="" defined(excludeIntervalList)} ~{sep=' -XL ' excludeIntervalList} \
        ~{"-D " + dbsnpVCF} \
        ~{"--pedigree " + pedigree} \
        ~{"--contamination-fraction-per-sample-file " + contamination} \
        ~{true="-ERC GVCF" false="" gvcf}
    }

    output {
        File outputVCF = outputPath
        File outputVCFIndex = outputPath + ".tbi"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBams: {description: "The BAM files on which to perform variant calling.", category: "required"}
        inputBamsIndex: {description: "The indexes for the input BAM files.", category: "required"}
        intervalList: {description: "Bed files or interval lists describing the regions to operate on.", category: "common"}
        excludeIntervalList: {description: "Bed files or interval lists describing the regions to NOT operate on.", category: "common"}
        outputPath: {description: "The location to write the output to.", category: "required"}
        ploidy: {description: "The ploidy with which the variants should be called.", category: "common"}
        gvcf: {description: "Whether the output should be a gvcf", category: "common"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaIndex: {description: "The index for the reference fasta file.", category: "required"}
        contamination: {description: "Equivalent to HaplotypeCaller's `-contamination` option.", category: "advanced"}
        dbsnpVCF: {description: "A dbSNP VCF.", category: "common"}
        dbsnpVCFIndex: {description: "The index for the dbSNP VCF.", category: "common"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}


task LearnReadOrientationModel {
    input {
        Array[File]+ f1r2TarGz

        String memory = "24G"
        String javaXmx = "12G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.2.0--1"
    }

    command {
        set -e
        gatk --java-options -Xmx~{javaXmx} \
        LearnReadOrientationModel \
        -I ~{sep=" -I " f1r2TarGz} \
        -O "artifact-priors.tar.gz"
    }

    output {
        File artifactPriorsTable = "artifact-priors.tar.gz"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        f1r2TarGz: {description: "A f1r2TarGz file outputed by mutect2.", category: "required"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task MergeStats {
    input {
        Array[File]+ stats

        String memory = "28G"
        String javaXmx = "14G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        gatk --java-options -Xmx~{javaXmx} \
        MergeMutectStats \
        -stats ~{sep=" -stats " stats} \
        -O "merged.stats"
    }

    output {
        File mergedStats = "merged.stats"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        stats: {description: "Statistics files to be merged.", category: "required"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task ModelSegments {
    input {
        String outputDir = "."
        String outputPrefix
        File denoisedCopyRatios
        File allelicCounts
        File? normalAllelicCounts
        Int minimumTotalAlleleCountCase = if defined(normalAllelicCounts)
            then 0
            else 30
        Int maximumNumberOfSmoothingIterations = 10

        String memory = "64G"
        String javaXmx = "10G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p ~{outputDir}
        gatk --java-options -Xmx~{javaXmx} \
        ModelSegments \
        --denoised-copy-ratios ~{denoisedCopyRatios} \
        --allelic-counts ~{allelicCounts} \
        ~{"--normal-allelic-counts " + normalAllelicCounts} \
        --minimum-total-allele-count-case ~{minimumTotalAlleleCountCase} \
        --maximum-number-of-smoothing-iterations ~{maximumNumberOfSmoothingIterations} \
        --output ~{outputDir} \
        --output-prefix ~{outputPrefix}
    }

    output {
        File hetrozygousAllelicCounts = outputDir + "/" + outputPrefix + ".hets.tsv"
        File? normalHetrozygousAllelicCounts = outputDir + "/" + outputPrefix + ".hets.normal.tsv"
        File copyRatioSegments = outputDir + "/" + outputPrefix + ".cr.seg"
        File copyRatioCBS = outputDir + "/" + outputPrefix + ".cr.igv.seg"
        File alleleFractionCBS = outputDir + "/" + outputPrefix + ".af.igv.seg"
        File unsmoothedModeledSegments = outputDir + "/" + outputPrefix + ".modelBegin.seg"
        File unsmoothedCopyRatioParameters = outputDir + "/" + outputPrefix + ".modelBegin.cr.param"
        File unsmoothedAlleleFractionParameters = outputDir + "/" + outputPrefix + ".modelBegin.af.param"
        File modeledSegments = outputDir + "/" + outputPrefix + ".modelFinal.seg"
        File copyRatioParameters = outputDir + "/" + outputPrefix + ".modelFinal.cr.param"
        File alleleFractionParameters = outputDir + "/" + outputPrefix + ".modelFinal.af.param"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        outputDir: {description: "The directory to write the ouput to.", category: "common"}
        outputPrefix: {description: "The prefix of the output files. Should not include directories.", category: "required"}
        denoisedCopyRatios: {description: "The denoised copy ratios as generated by DenoiseReadCounts.", category: "required"}
        allelicCounts: {description: "The allelicCounts as generate by CollectAllelicCounts.", category: "required" }
        normalAllelicCounts: {description: "The allelicCounts as generate by CollectAllelicCounts for a matched normal.", category: "common"}
        minimumTotalAlleleCountCase: {description: "Equivalent to gatk ModelSeqments' `--minimum-total-allele-count-case` option.", category: "advanced"}
        maximumNumberOfSmoothingIterations: {description: "Equivalent to gatk ModelSeqments' `--maximum-number-of-smoothing-iterations` option.", category: "advanced"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task MuTect2 {
    input {
        Array[File]+ inputBams
        Array[File]+ inputBamsIndex
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        String outputVcf
        String tumorSample
        String? normalSample
        File? germlineResource
        File? germlineResourceIndex
        File? panelOfNormals
        File? panelOfNormalsIndex
        String f1r2TarGz = "f1r2.tar.gz"
        Array[File]+ intervals
        String outputStats = outputVcf + ".stats"

        String memory = "16G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputVcf})"
        gatk --java-options -Xmx~{javaXmx} \
        Mutect2 \
        -R ~{referenceFasta} \
        -I ~{sep=" -I " inputBams} \
        -tumor ~{tumorSample} \
        ~{"-normal " + normalSample} \
        ~{"--germline-resource " + germlineResource} \
        ~{"--panel-of-normals " + panelOfNormals} \
        ~{"--f1r2-tar-gz " + f1r2TarGz} \
        -O ~{outputVcf} \
        -L ~{sep=" -L " intervals}
    }

    output {
        File vcfFile = outputVcf
        File vcfFileIndex = outputVcf + ".tbi"
        File f1r2File = f1r2TarGz
        File stats = outputStats
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBams: {description: "The BAM files on which to perform variant calling.", category: "required"}
        inputBamsIndex: {description: "The indexes for the input BAM files.", category: "required"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        outputVcf: {description: "The location to write the output VCF file to.", category: "required"}
        tumorSample: {description: "The name of the tumor/case sample.", category: "required"}
        normalSample: {description: "The name of the normal/control sample.", category: "common"}
        germlineResource: {description: "Equivalent to Mutect2's `--germline-resource` option.", category: "advanced"}
        germlineResourceIndex: {description: "The index for the germline resource.", category: "advanced"}
        panelOfNormals: {description: "Equivalent to Mutect2's `--panel-of-normals` option.", category: "advanced"}
        panelOfNormalsIndex: {description: "The index for the panel of normals.", category: "advanced"}
        f1r2TarGz: {description: "Equivalent to Mutect2's `--f1r2-tar-gz` option.", category: "advanced"}
        intervals: {description: "Bed files describing the regiosn to operate on.", category: "required"}
        outputStats: {description: "The location the output statistics should be written to.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task PlotDenoisedCopyRatios {
    input {
        File referenceFastaDict
        String outputDir = "."
        String outputPrefix
        File standardizedCopyRatios
        File denoisedCopyRatios
        Int? minimumContigLength

        String memory = "32G"
        String javaXmx = "7G"
        String dockerImage = "broadinstitute/gatk:4.1.4.0" # The biocontainer doesn't seem to contain R.
    }

    command {
        set -e
        mkdir -p ~{outputDir}
        gatk --java-options -Xmx~{javaXmx} \
        PlotDenoisedCopyRatios \
        --standardized-copy-ratios ~{standardizedCopyRatios} \
        --denoised-copy-ratios ~{denoisedCopyRatios} \
        --sequence-dictionary ~{referenceFastaDict} \
        ~{"--minimum-contig-length " + minimumContigLength} \
        --output ~{outputDir} \
        --output-prefix ~{outputPrefix}
    }

    output {
        File denoisedCopyRatiosPlot = outputDir + "/" + outputPrefix + ".denoised.png"
        File denoisedCopyRatiosLimitedPlot = outputDir + "/" + outputPrefix + ".denoisedLimit4.png"
        File standardizedMedianAbsoluteDeviation = outputDir + "/" + outputPrefix + ".standardizedMAD.txt"
        File denoisedMedianAbsoluteDeviation = outputDir + "/" + outputPrefix + ".denoisedMAD.txt"
        File deltaMedianAbsoluteDeviation = outputDir + "/" + outputPrefix + ".deltaMAD.txt"
        File deltaScaledMedianAbsoluteDeviation = outputDir + "/" + outputPrefix + ".scaledDeltaMAD.txt"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file used for the analyses.", category: "required"}
        outputDir: {description: "The directory to write the ouput to.", category: "common"}
        outputPrefix: {description: "The prefix of the output files. Should not include directories.", category: "required"}
        denoisedCopyRatios: {description: "The denoised copy ratios as generated by DenoiseReadCounts.", category: "required"}
        standardizedCopyRatios: {description: "The standardized copy ratios as generated by DenoiseReadCounts.", category: "required"}
        minimumContigLength: {description: "The minimum length for a contig to be included in the plots.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task PlotModeledSegments {
    input {
        File referenceFastaDict
        String outputDir = "."
        String outputPrefix
        File denoisedCopyRatios
        File segments
        File allelicCounts
        Int? minimumContigLength

        String memory = "21G"
        String javaXmx = "7G"
        String dockerImage = "broadinstitute/gatk:4.1.4.0" # The biocontainer doesn't seem to contain R.
    }

    command {
        set -e
        mkdir -p ~{outputDir}
        gatk --java-options -Xmx~{javaXmx} \
        PlotModeledSegments \
        --denoised-copy-ratios ~{denoisedCopyRatios} \
        --allelic-counts ~{allelicCounts} \
        --segments ~{segments} \
        --sequence-dictionary ~{referenceFastaDict} \
        ~{"--minimum-contig-length " + minimumContigLength} \
        --output ~{outputDir} \
        --output-prefix ~{outputPrefix}
    }

    output {
        File modeledSegmentsPlot = outputDir + "/" + outputPrefix + ".modeled.png"
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file used for the analyses.", category: "required"}
        outputDir: {description: "The directory to write the ouput to.", category: "common"}
        outputPrefix: {description: "The prefix of the output files. Should not include directories.", category: "required"}
        denoisedCopyRatios: {description: "The denoised copy ratios as generated by DenoiseReadCounts.", category: "required"}
        segments: {description: "The modeled segments as generated by ModelSegments.", category: "required"}
        allelicCounts: {description: "The hetrozygous allelic counts as generated by ModelSegments.", category: "required"}
        minimumContigLength: {description: "The minimum length for a contig to be included in the plots.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task PreprocessIntervals {
    input {
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        File? intervals
        String outputIntervalList = "bins.interval_list"
        Int binLength = if defined(intervals) then 0 else 1000
        Int padding = if defined(intervals) then 250 else 0
        String intervalMergingRule = "OVERLAPPING_ONLY"

        String memory = "10G"
        String javaXmx = "2G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputIntervalList})"
        gatk --java-options -Xmx~{javaXmx} \
        PreprocessIntervals \
        -R ~{referenceFasta} \
        --sequence-dictionary ~{referenceFastaDict} \
        --bin-length ~{binLength} \
        --padding ~{padding} \
        ~{"-L " + intervals} \
        --interval-merging-rule ~{intervalMergingRule} \
        -O ~{outputIntervalList}
    }

    output {
        File intervalList = outputIntervalList
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        referenceFasta: {description: "The reference fasta file..", category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.", category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        intervals: {description: "Bed files describing the regiosn to operate on.", category: "common"}
        outputIntervalList: {description: "The location the output should be written to.", category: "advanced"}
        binLength: {description: "The size of the bins to be created. Should be 0 for targeted/exome sequencing.", category: "advanced"}
        padding: {description: "The padding to be added to the bins. Should be 0 if contiguos binning is used, eg with WGS.", category: "advanced"}
        intervalMergingRule: {description: "Equivalent to gatk PreprocessIntervals' `--interval-merging-rule` option.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task SplitNCigarReads {
    input {
        File inputBam
        File inputBamIndex
        File referenceFasta
        File referenceFastaDict
        File referenceFastaFai
        String outputBam
        Array[File] intervals = []

        String memory = "16G"
        String javaXmx = "4G"
        String dockerImage = "quay.io/biocontainers/gatk4:4.1.0.0--0"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputBam})"
        gatk --java-options -Xmx~{javaXmx} \
        SplitNCigarReads \
        -I ~{inputBam} \
        -R ~{referenceFasta} \
        -O ~{outputBam} \
        ~{true="-L" false="" length(intervals) > 0} ~{sep=' -L ' intervals}
    }

    output {
        File bam = outputBam
        File bamIndex = sub(outputBam, "\.bam$", ".bai")
    }

    runtime {
        docker: dockerImage
        memory: memory
    }

    parameter_meta {
        inputBam: {description: "The BAM file for which spliced reads should be split.", category: "required"}
        inputBamIndex: {description: "The input BAM file's index.", category: "required"}
        referenceFasta: {description: "The reference fasta file which was also used for mapping.",
                         category: "required"}
        referenceFastaDict: {description: "The sequence dictionary associated with the reference fasta file.",
                             category: "required"}
        referenceFastaFai: {description: "The index for the reference fasta file.", category: "required"}
        outputBam: {description: "The location the output BAM file should be written.", category: "required"}
        intervals: {description: "Bed files or interval lists describing the regions to operate on.", category: "advanced"}

        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        javaXmx: {description: "The maximum memory available to the program. Should be lower than `memory` to accommodate JVM overhead.",
                  category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}
