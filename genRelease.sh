#!/usr/bin/env bash
tag=${1:?}
currDir=`pwd`
releaseDir="Modelica_${tag:1}"
export releaseVersion="`echo ${tag:1} |cut -d_ -f1`"
export MODELICAPATH="/tmp/MSLrelease/$releaseDir"
# Clean up of previous script runs
rm -rf "/tmp/MSLrelease"
mkdir -p "$MODELICAPATH"
## Export out a given release from the svn server (use this for keyword expansion)
svn export "https://svn.modelica.org/projects/Modelica/tags/$tag" "."
## Export using git (for testing)
##git archive --remote=$MODELICALIBRARIES $tag | tar -x -C "$MODELICAPATH"
mv "$MODELICAPATH/Modelica" "$MODELICAPATH/Modelica $releaseVersion"
## Call Dymola to generate the HTML documentation
## CURRENTLY NOT WORKING
##mkdir -p Modelica/Resources/help # not yet created by Dymola (bug)
##dymola "$currDir/generateHTML.mos"
#
# Call OpenModelica to generate the HTML help files
omc "$currDir/genDocOMC.mos"
# Remove stuff that should not be part of the release:
cd "$MODELICAPATH"
rm -rf "ModelicaTest"
# Let us only include the default ModelicaServices
mv "ModelicaServices-Variants/Default/ModelicaServices" "ModelicaServices"
rm -rf "ModelicaServices-Variants"
zip -qrFS "$currDir/ModelicaStandardLibrary_${tag}.zip" .
