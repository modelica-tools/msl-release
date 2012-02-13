#!/usr/bin/env bash
tag=${1:?}
currDir=`pwd`
releaseDir="Modelica ${tag:1}"
mkdir -p /tmp/MSLrelease
cd /tmp/MSLrelease
# Export out a given release from the svn server
svn export "https://svn.modelica.org/projects/Modelica/tags/$tag" "$releaseDir"
# let's call Dymola to generate the HTML documentation
cd "$releaseDir"
mkdir Modelica/Resources/help # not yet created by Dymola (bug)
dymola "$currDir/generateHTML.mos"
zip -r "../ModelicaStandardLibrary_${tag}.zip" .
