#!/usr/bin/env bash

# In case of git you should have defined the $MODELICALIBRARIES location
# either system wide or just right here:
#MODELICALIBRARIES=/path/to/git-repo

# Which HTML generator should we use, [omc|dymola|no]:
genHTML=omc

# for syntax check only set genIcons to false
# (icon generation is very time consuming)
export genIcons=true

tag=${1:?}
currDir=`pwd`
releaseDir="Modelica_${tag:1}"
export releaseVersion="`echo ${tag:1} |cut -d+ -f1`"
export MODELICAPATH="/tmp/MSLrelease/$releaseDir"
export outDir="$currDir/out"
# relative sub folder for the HTML files:
export htmlDir="/Resources/helpOM/"
# Clean up of previous script runs
rm -rf "/tmp/MSLrelease"

mkdir -p "$MODELICAPATH"
echo "Exporting archive using Git (with keyword expansion and filtering)..."
# Export using git
git archive --remote=$MODELICALIBRARIES $tag | tar -x -C "$MODELICAPATH"
    echo "...finished."

# Creating directory structure with release numbers
mv "$MODELICAPATH/Modelica" "$MODELICAPATH/Modelica $releaseVersion"
mv "$MODELICAPATH/ModelicaServices" "$MODELICAPATH/ModelicaServices $releaseVersion"
mv "$MODELICAPATH/ModelicaReference" "$MODELICAPATH/ModelicaReference $releaseVersion"

if [ "$genHTML" = "omc" ]; then
    echo "Calling OpenModelica to generate the HTML documentation..."
    # omc +showErrorMessages +d=failtrace "$currDir/genDocOMC.mos"
    mkdir -p "$outDir"
    cd "$outDir"
    omc "$currDir/genDocOMC.mos"
elif [ "$genHTML" = "dymola" ]; then
    echo "Calling Dymola to generate HTML documentaion (NOT WORKING YET)..."
    # mkdir -p Modelica/Resources/help # not yet created by Dymola (bug)
    # dymola "$currDir/genDocDymola.mos"
    echo "NO HTML documentation generated!"
else
    echo "Running without HTML generation"
fi

# Remove stuff that should not be part of the release:
cd "$MODELICAPATH"
rm -rf "$MODELICAPATH/ModelicaTest"
rm -rf "$MODELICAPATH/ModelicaTestOverdetermined.mo"
mv "$MODELICAPATH/Modelica ${releaseVersion}${htmlDir}MissingFiles.log" "$outDir"

# Create the release zip file
echo "Generating the zip file..."
zip -qrFS "$outDir/ModelicaStandardLibrary_${tag}.zip" .
echo "...finished."
