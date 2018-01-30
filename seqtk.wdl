task sample {
    File sequenceFile
    File? outFilePath = "subsampledReads"
    String? preCommand
    Int? seed
    Boolean? twoPassMode
    Float? fraction
    Int? number
    Boolean? zip

    command {
    set -e -o pipefail
    ${preCommand}
    seqtk sample \
    ${"-s " + seed} \
    ${true="-2 " false="" twoPassMode} \
    ${sequenceFile} \
    ${number} ${fraction} \
    ${true="| gzip" false="" zip} \
    ${"> " + outFilePath}
    }
    output {
        File subsampledReads=select_first([outFilePath])
    }
}