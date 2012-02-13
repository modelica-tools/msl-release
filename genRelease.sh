#!/bin/sh
tag=${1:?}
currDir=`pwd`
mkdir -p /tmp/MSLrelease
cd /tmp/MSLrelease
# Export out a given release from the svn server
svn export "https://svn.modelica.org/projects/Modelica/tags/$tag"
cd "$tag"
# let's call Dymola to generate the HTML documentation
dymola $currDir/generateHTML.mos
zip -r "../ModelicaStandardLibrary_$tag.zip" .