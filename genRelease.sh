#!/usr/bin/env bash

# Which version control system do we use, [git|svn]:
vcs=git
# In case of git you should have defined the $MODELICALIBRARIES location
# either system wide or just right here:
#MODELICALIBRARIES=/path/to/git-repo

# Which HTML generator should we use, [omc|dymola]:
gen=omc

tag=${1:?}
currDir=`pwd`
releaseDir="Modelica_${tag:1}"
export releaseVersion="`echo ${tag:1} |cut -d_ -f1`"
export MODELICAPATH="/tmp/MSLrelease/$releaseDir"
# Clean up of previous script runs
rm -rf "/tmp/MSLrelease"
mkdir -p "$MODELICAPATH"

if [ "$vcs" = "svn" ]; then
    echo Exporting archive using SVN...
    # Export of  a given release from the svn server (use this for keyword expansion)
    svn export "https://svn.modelica.org/projects/Modelica/tags/$tag" "$MODELICAPATH"
    echo "...finished."
else
    echo "Exporting archive using Git (for testing since no keyword expansion)..."
    # Export using git (for testing)
    git archive --remote=$MODELICALIBRARIES $tag | tar -x -C "$MODELICAPATH"
    echo "...finished."
fi
# Creating directory structure with release numbers
mv "$MODELICAPATH/Modelica" "$MODELICAPATH/Modelica $releaseVersion"
mv "$MODELICAPATH/ModelicaServices" "$MODELICAPATH/ModelicaServices $releaseVersion"
mv "$MODELICAPATH/ModelicaReference" "$MODELICAPATH/ModelicaReference $releaseVersion"

if [ "$gen" = "omc" ]; then
    echo "Calling OpenModelica to generate the HTML documentation..."
    # omc +showErrorMessages +d=failtrace "$currDir/genDocOMC.mos"
    omc "$currDir/genDocOMC.mos"
    echo "Generation of HTML documentation finished."
else
    echo "Calling Dymola to generate HTML documentaion (NOT WORKING YET)..."
    # mkdir -p Modelica/Resources/help # not yet created by Dymola (bug)
    # dymola "$currDir/genDocDymola.mos"
    echo "NO HTML documentation generated!"
fi

echo "Generating the zip file..."
# Remove stuff that should not be part of the release:
cd "$MODELICAPATH"
rm -rf "ModelicaTest"
# Create the release zip file
zip -qrFS "$currDir/ModelicaStandardLibrary_${tag}.zip" .
echo "...finished."
