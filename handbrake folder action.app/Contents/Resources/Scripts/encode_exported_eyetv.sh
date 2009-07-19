#!/bin/sh
# Copyright © 2009 Adam Cohen-Rose

function usage_and_exit() {
    echo "Usage: `basename $0` /path/to/HandBrakeCLI /path/to/preset_name/export.mpg /path/to/output_dir"
    echo "       creates /path/to/output_dir/export.mp4 encoded using preset_name"
    if [ $# -gt 0 ]; then
        echo 1>&2 "Error: $1"
    fi
    if [ $# -gt 1 ]; then
        exit $2
    else
        exit 1
    fi
}

if [ $# -lt 3 ]; then
    usage_and_exit "Not enough parameters provided to script: `basename $0` $*"
fi

export HANDBRAKECLI=$1
export inputpath=$2
export outputdir=$3
# remove any trailing slash from outputdir (for tidiness)
export outputdir=`echo "${outputdir}" | sed -E 's/\/$//'`


################
# SANITY CHECKS:

# check that inputpath is an existing file
if [ ! -f "${inputpath}" ]; then
    usage_and_exit "Input file \"${inputpath}\" does not exist"
fi
# check that inputpath ends with .mpg
inputpathext=`echo ${inputpath} | sed -E 's/.*(\.mpg)$/\1/'`
if [ "${inputpathext}" != '.mpg' ]; then
    usage_and_exit "Input file \"${inputpath}\" must end with .mpg"
fi
# check that outputpath is an existing directory
if [ ! -d "${outputdir}" ]; then
    usage_and_exit "Output directory \"${outputdir}\" must exist"
fi


##################################
# PREPARE THE HANDBRAKE PARAMETERS

export inputfilename=`basename "${inputpath}"`
export parentdir=`dirname "${inputpath}"`
export presetname=`basename "${parentdir}"`

# check that the preset exists
export presetparams=`$HANDBRAKECLI --preset-list | grep "+ ${presetname}:"`
if [ -z "${presetparams}" ]; then
    usage_and_exit "Encoding \"${inputfilename}\": Handbrake preset \"${presetname}\" is not a built-in preset"
fi
# find the output format for selected preset
export outputext=`echo ${presetparams} | sed -E 's/.*-f +([[:alnum:]]{3,4}).*/\1/'`
if [ ${#outputext} -lt 3 -o ${#outputext} -gt 4 ]; then
    usage_and_exit "Encoding \"${inputfilename}\": Could not find output type for preset \"${presetname}\"\n\
Preset is defined as:\n${presetparams}"
fi

# calculate the output filename (replace the extension)
export outputfilename=`echo "${inputfilename}" | sed -E 's/\.mpg$/'.${outputext}/`

# TODO: in future could check to see if the output path already exists, and if so add a numbered suffix

# prepare log file
export logfiledir="${HOME}/Library/Logs/HandbrakeFolderAction"
/bin/mkdir -p "${logfiledir}/"
if [ ! -d ${logfiledir} ]; then
    usage_and_exit "Encoding \"${inputfilename}\": Could not create log directory ${logfiledir}"
fi
export logfilepath="${logfiledir}/exporting_${inputfilename}.$$.log"
echo "$0 run at `date`" > ${logfilepath}
echo "Encoding \"${inputfilename}\" to \"${outputdir}/${outputfilename}\"" >> ${logfilepath}

# TODO: in future could compress/delete old logfiles
# might want to use lsof -t <filenames> to find which files are still in use

# run Handbrake
$HANDBRAKECLI -i "${inputpath}" -o "${outputdir}/${outputfilename}" --preset "${presetname}" >> ${logfilepath} 2>&1
handbrakeReturnValue=$?

# return information to calling applescript
if [ ${handbrakeReturnValue} -ne 0 ]; then
    usage_and_exit "Encoding \"${inputfilename}\" failed: Log available at ${logfilepath}"
else
    echo "Encoded \"${inputfilename}\": Log available at ${logfilepath}"
fi

exit 0