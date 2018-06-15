# msl-release

This is a collection of scripts for generating a release ZIP-file for the MSL.

Currently it contains two main parts:

## Generation of ZIP file of MSL

This is done by running the `genRelease.sh` which will call `omc` to run `genDocOMC.mos`.

### Usage

```sh
$ genRelease.sh v3.2.3
```

This will checkout the tag `v3.2.3` of the Modelica Standard Library, generating the HTML help files using OpenModelica including all Icons. It also generates a diagnostic file that reports HTML errors (see `out/tidy.filtered`).

Inside `genRelease.sh` are a couple of switches to adapt the generation to the system it is run on. Especially the icon generation is very time consuming and only necsessary for the final run.

### Dependencies

In order to run this script you need:

 - Linux OpenModelica nighlty build newer than 2018-06-15 (because of icon generation)
 - Python 2 with `OMPython`, `svgwrite`, `BeautifulSoup`  installed.

## Generate various library checks and reports

The Modelica library `ReleaseChecks.mo` conatains a collection of check and diagnostic functions which can be used for the MSL or any other library

### Dependencies

 - Dymola
