task BwaMem {
    String? preCommand
    File inputR1
    File? inputR2
    String referenceFasta
    Array[File] indexFiles # These indexFiles need to be added, otherwise cromwell will not find them.
    String outputPath
    String? readgroup

    Int? threads
    Int? memory

    command {
        set -e -o pipefail
        mkdir -p $(dirname ${outputPath})
        ${preCommand}
        bwa mem ${"-t " + threads} \
        ${"-R '" + readgroup + "'"} \
        ${referenceFasta} ${inputR1} ${inputR2} | samtools sort --output-fmt BAM - > ${outputPath}
    }

    output {
        File bamFile = outputPath
    }
    runtime{
        cpu: if defined(threads) then threads else 1
        memory: if defined(memory) then memory else 8
    }
}

task index {
    File fasta
    String? preCommand
    String? constructionAlgorithm
    Int? blockSize
    String? outputDir
    String fastaFilename = basename(fasta)
    String outputFile = if (defined(outputDir)) then outputDir + "/" + fastaFilename else fasta

    command {
        set -e -o pipefail
        ${"mkdir -p " + outputDir}
        ${preCommand}
        if [[ ! '${outputDir}' =  '' ]]
        then
            ln -sf ${fasta} ${outputDir + "/"}${fastaFilename}
        fi
        bwa index \
        ${"-a " + constructionAlgorithm} \
        ${"-b" + blockSize} \
        ${outputFile}
    }

    output {
        File indexedFasta = outputFile
        Array[File] indexFiles = [indexBase + ".bwt",indexBase + ".pac",indexBase + ".sa",indexBase + ".amb",indexBase + ".ann"]
    }
    parameter_meta {
        fasta: "Fasta file to be indexed"
        constructionAlgorithm: "-a STR    BWT construction algorithm: bwtsw, is or rb2 [auto]"
        blockSize: "-b INT    block size for the bwtsw algorithm (effective with -a bwtsw) [10000000]"
        outputDir: "index will be created in this output directory"
    }
}

