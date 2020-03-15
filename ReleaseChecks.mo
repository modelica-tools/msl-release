within ;
package ReleaseChecks
  extends Modelica.Icons.Package;

  function printExecutables "Recursively translate blocks/models in pedantic mode"
    extends Modelica.Icons.Function;
    import Modelica.Utilities.Streams.print;

    input String libraries[:] = {"Modelica", "ModelicaTest"}
      "Libraries that shall be inspected";
    input String fileNameSuccessful = "log_successful.txt"
      "File name where successful translating model/block names shall be stored";
    input String fileNameFailed = "log_failed.txt"
      "File name where model/block names shall be stored that fail translation";
  protected
    String packageName;
  algorithm
    // Remove log files
    Modelica.Utilities.Files.removeFile(fileNameSuccessful);
    Modelica.Utilities.Files.removeFile(fileNameFailed);

    // Print heading
    print("The following models/blocks with StopTime annotation translate successfully:\n", fileNameSuccessful);
    print("The following models/blocks with StopTime annotation fail translation if pedantic=true:\n", fileNameFailed);

    // Inspect packages
    for packageName in libraries loop
      Internal.inspectPackage(packageName, fileNameSuccessful, fileNameFailed);
    end for;
    annotation (__Dymola_interactive=true, Documentation(info="<html><p>
Translate all executable (= having an <code>experiment.StopTime</code> annotation) blocks/models of the listed <code>libraries</code> in pedantic mode.</p></html>"));
  end printExecutables;

  function simulateExecutables "Recursively simulate blocks/models and generate CSV files for simulation results"
    extends Modelica.Icons.Function;

    import Modelica.Utilities.Files.loadResource;
    import Modelica.Utilities.Streams.print;

    input String libraries[:] = {"Modelica", "ModelicaTest"} "Libraries that shall be inspected";
    input String directories[size(libraries, 1)] = {"modelica://Modelica/Resources/Reference", "modelica://ModelicaTest/Resources/Reference"}
      "Directory structure containing the comparisonSignals.txt files and that also will be used as for the simulation outputs";
    input Boolean incrementalRun = true "= true, if only the failed models/blocks from a previous run are simulated, otherwise run all models/blocks";
    input Boolean keepResultFile = false "= true, if the MAT file containing the simulation result data is to be kept";
    input Integer numberOfIntervals = 5000 "Number of output points";
    input Real tolerance = 1e-6 "Solver tolerance";
    input String compiler = "vs" "Compiler type, for example, \"vs\"";
    input String compilerSettings[:] = {"MSVCDir=c:/Program Files (x86)/Microsoft Visual Studio/2017/Community/VC/Auxiliary/Build"} "Compiler settings in name=value pairs";
    input String gitURL = "https://github.com/modelica/ModelicaStandardLibrary.git" "Run command \"git config --get remote.origin.url\"";
    input String gitRevision = "" "Run command \"git rev-parse --short HEAD\"";
    input String gitStatus = "" "Run command \"git status --porcelain --untracked-files=no\" and pass as comma separated changes";
    input String description = "Reg test MSL v4.0.0-beta.1" "Description";

  protected
    String packageName;
    String directory "Directory structure containing the simulation data";
    Integer nr[3] "Number of failed {checks, translations, simulations} per package";
    String osver = Internal.command("ver") "OS version information";
    String hostname = Internal.command("hostname") "Host name";
    String user = Internal.command("echo %username%") "User name";
  algorithm

    // Inspect packages
    for i in 1:size(libraries, 1) loop
      packageName = libraries[i];
      directory := loadResource(directories[i]);
      nr := Internal.inspectPackageEx(packageName, directory, incrementalRun, keepResultFile, numberOfIntervals, tolerance, compiler, compilerSettings, osver, hostname, user, description, gitURL, gitRevision, gitStatus);
      print("Result for package \"" + packageName + "\": " + String(nr[1]) + " failed checks, " + String(nr[2]) + " failed translations, " + String(nr[3]) + " failed simulations");
    end for;
    annotation (__Dymola_interactive=true, Documentation(info="<html><p>
Simulate all executable (= having an <code>experiment.StopTime</code> annotation) blocks/models of the listed <code>libraries</code> and generate CSV for the simulation data according to the provided comparisonSignals.txt files.</p></html>"));
  end simulateExecutables;

  function countClassesInPackage "Recursively count public, non-partial, non-internal and non-obsolete classes in package"
    extends Modelica.Icons.Function;

    input String s = "Modelica" "Package name";
    output Integer nr[6] = zeros(6) "Number of {models, blocks, functions, types, packages, examples}";
  protected
    String localClasses[:] = ModelManagement.Structure.AST.ClassesInPackage(s);
    ModelManagement.Structure.AST.ClassAttributes attributes;
    Boolean isInternal;
    Boolean isExample;

  algorithm
    attributes := ModelManagement.Structure.AST.GetClassAttributes(s);
    isInternal := Internal.isInternalClass(s) or Internal.isObsoleteClass(s);
    if not attributes.isProtected and not attributes.isPartial and not isInternal then
      for i in 1:size(localClasses, 1) loop
        attributes := ModelManagement.Structure.AST.GetClassAttributes(s + "." + localClasses[i]);
        isInternal := Internal.isInternalClass(s + "." + localClasses[i]) or Internal.isObsoleteClass(s + "." + localClasses[i]);
        isExample := Internal.isExampleModel(s + "." + localClasses[i]);
        if attributes.isProtected or attributes.isPartial or isInternal then
        elseif attributes.restricted == "package" then
          nr := nr + countClassesInPackage(attributes.fullName);
          nr[5] := nr[5] + 1;
        elseif attributes.restricted == "model" then
          if isExample then
            nr[6] := nr[6] + 1;
          else
            nr[1] := nr[1] + 1;
          end if;
        elseif attributes.restricted == "block" then
          nr[2] := nr[2] + 1;
        elseif attributes.restricted == "function" then
          nr[3] := nr[3] + 1;
        elseif attributes.restricted == "type" then
          nr[4] := nr[4] + 1;
        end if;
      end for;
    end if;
    annotation (__Dymola_interactive=true, Documentation(info="<html><p>
Modified version of <a href=\"modelica://ModelManagement.Structure.AST.Examples.countModelsInPackage\">
countModelsInPackage</a> from ModelManagement library of Dymola</p></html>"));
  end countClassesInPackage;

  function genDoc "Export HTML documentation"
    extends Modelica.Icons.Function;

    input String name = "Modelica" "Name of Modelica model or package";
    input String directory = Modelica.Utilities.Files.loadResource("modelica://" + name + "/Resources/help") "Directory of exported HTML files";
  algorithm
    exportHTMLDirectory(name, directory);
    annotation (__Dymola_interactive=true, Documentation(info="<html><p>
Generate HTML documentation from Modelica model or package in Dymola</p></html>"));
  end genDoc;

  package Internal
    extends Modelica.Icons.InternalPackage;

    function inspectPackage "Check if all executable blocks/models of a package translate in pedantic mode"
      extends Modelica.Icons.Function;

      import Modelica.Utilities.Streams.print;
      import Modelica.Utilities.Strings.isEmpty;
      import Modelica.Utilities.Strings.findLast;
      import ModelManagement.Structure.AST;

      input String packageName "Package to be inspected";
      input String fileNameSuccessful = "log_successful.txt" "File name where successful translating model/block names shall be stored";
      input String fileNameFailed = "log_failed.txt" "File name where model/block names shall be stored that fail translation";
    protected
      String localClasses[:];
      String StopTime;
      Boolean OK;
      String logStat;
      String fullName;
      AST.ClassAttributes classAttributes;
    algorithm
      logStat := "";

      // Set Dymola pedantic mode
      Advanced.PedanticModelica := true;

      localClasses := AST.ClassesInPackage(packageName);
      for name in localClasses loop
        fullName := packageName + "." + name;
        classAttributes := AST.GetClassAttributes(fullName);
        if classAttributes.restricted == "package" then
          inspectPackage(fullName, fileNameSuccessful, fileNameFailed);

        elseif classAttributes.restricted == "model" or classAttributes.restricted == "block" then
          StopTime := AST.GetAnnotation(fullName, "experiment.StopTime");
          if not isEmpty(StopTime) then
            OK := translateModel(fullName);
            if OK then
              (logStat, , , ) := getLastError();
              OK := findLast(logStat, "Error: ERRORS have been issued.") == 0;
            end if;
            if OK then
              print(fullName, fileNameSuccessful);
            else
              print(fullName, fileNameFailed);
            end if;
          end if;
        end if;
      end for;
      annotation(__Dymola_interactive=true);
    end inspectPackage;

    function inspectPackageEx "Simulate all executables blocks/models of a package and generate simulation results"
      extends Modelica.Icons.Function;

      import Modelica.Utilities.Files.createDirectory;
      import Modelica.Utilities.Files.exist;
      import Modelica.Utilities.Files.fullPathName;
      import Modelica.Utilities.Files.move;
      import Modelica.Utilities.Files.removeFile;
      import Modelica.Utilities.Streams.print;
      import Modelica.Utilities.Streams.readFile;
      import Modelica.Utilities.Strings.isEmpty;
      import Modelica.Utilities.Strings.replace;
      import Modelica.Utilities.System.getTime;
      import ModelManagement.Structure.AST;

      input String packageName "Package to be inspected";
      input String directory "Directory structure containing the simulation data";
      input Boolean incrementalRun = true "= true, if only the failed models/blocks from a previous run are simulated, otherwise run all models/blocks";
      input Boolean keepResultFile = false "= true, if the MAT file containing the simulation result data is kept";
      input Integer numberOfIntervals = 5000 "Number of output points";
      input Real tolerance = 1e-6 "Solver tolerance";
      input String compiler "Compiler type, for example, \"vs\"";
      input String compilerSettings[:] "Compiler settings in name=value pairs";
      input String osver "OS version information";
      input String hostname "Host name";
      input String user "User name";
      input String description "Description";
      input String gitURL "Run command \"git config --get remote.origin.url\"";
      input String gitRevision "Run command \"git rev-parse --short HEAD\"";
      input String gitStatus = "" "Run command \"git status --porcelain --untracked-files=no\"";
      output Integer nr[3] = zeros(3) "Number of failed {checks, translations, simulations}";
    protected
      String localClasses[:];
      String StartTime;
      String StopTime;
      String Tolerance;
      String Interval;
      String modelDirectory;
      String logStat;
      String MATFileName;
      String CSVFileName;
      String varNames[:];
      String fullName;
      Boolean OK;
      Integer n;
      Real traj[:, :];
      Real traj_transposed[:, :];
      Real startTime;
      Real stopTime;
      Real interval;
      Real usedTolerance;
      Boolean isDefaultStartTime;
      Boolean isDefaultInterval;
      Boolean isDefaultTolerance;
      Integer sec, min, hour, day, mon, year;
      String timeString;
      AST.ClassAttributes classAttributes;
    algorithm
      localClasses := AST.ClassesInPackage(packageName);
      StartTime := "";
      StopTime := "";
      Tolerance := "";
      Interval := "";
      modelDirectory := "";
      logStat := "";
      MATFileName := "";
      CSVFileName := "";
      varNames := fill("", 0);
      n := 0;
      traj := fill(0, 0, 0);
      traj_transposed := fill(0, 0, 0);
      startTime := 0;
      stopTime := 1;
      interval := 0;
      isDefaultStartTime := false;
      isDefaultInterval := false;
      isDefaultTolerance := false;
      usedTolerance := tolerance;

      // Set Dymola non-pedantic mode
      Advanced.PedanticModelica := false;

      for name in localClasses loop
        fullName := packageName + "." + name;
        classAttributes := AST.GetClassAttributes(fullName);
        if classAttributes.restricted == "package" then
          nr := nr + inspectPackageEx(fullName, directory, incrementalRun, keepResultFile, numberOfIntervals, tolerance, compiler, compilerSettings, osver, hostname, user, description, gitURL, gitRevision, gitStatus);

        elseif classAttributes.restricted == "model" or classAttributes.restricted == "block" then
          StopTime := AST.GetAnnotation(fullName, "experiment.StopTime");
          if not isEmpty(StopTime) then
            (, stopTime) := scanReal(StopTime, 1.0);
            StartTime := AST.GetAnnotation(fullName, "experiment.StartTime");
            (isDefaultStartTime, startTime) := scanReal(StartTime, 0.0);
            Tolerance := AST.GetAnnotation(fullName, "experiment.Tolerance");
            (isDefaultTolerance, usedTolerance) := scanReal(Tolerance, tolerance);
            if not isDefaultTolerance and usedTolerance >= 2e-12 then
              usedTolerance := usedTolerance * 0.1;
            end if;
            Interval := AST.GetAnnotation(fullName, "experiment.Interval");
            (isDefaultInterval, interval) := scanReal(Interval, (stopTime - startTime)/numberOfIntervals);
            if not isDefaultInterval then
              interval := interval * 0.5;
            end if;
            modelDirectory := fullPathName(directory + "/" + replace(fullName, ".", "/"));
            createDirectory(modelDirectory);

            if not incrementalRun or not exist(fullPathName(modelDirectory + "/check_passed.log")) or not exist(fullPathName(modelDirectory + "/translate_passed.log")) or not exist(fullPathName(modelDirectory + "/simulate_passed.log")) then
              SetDymolaCompiler(compiler, compilerSettings);
              Evaluate := false;
              OutputCPUtime := false;

              // Remove log files
              removeFile(fullPathName(modelDirectory + "/check_passed.log"));
              removeFile(fullPathName(modelDirectory + "/check_failed.log"));
              removeFile(fullPathName(modelDirectory + "/translate_passed.log"));
              removeFile(fullPathName(modelDirectory + "/translate_failed.log"));
              removeFile(fullPathName(modelDirectory + "/simulate_passed.log"));
              removeFile(fullPathName(modelDirectory + "/simulate_failed.log"));
              removeFile(fullPathName(modelDirectory + "/compare_passed.log"));
              removeFile(fullPathName(modelDirectory + "/compare_failed.log"));
              removeFile(fullPathName(modelDirectory + "/creation.txt"));
              // Remove simulation data
              removeFile(fullPathName(modelDirectory + "/" + name + ".csv"));
              removeFile(fullPathName(modelDirectory + "/" + name + ".mat"));

              // Write meta data
              logStat = Internal.getCreation(name, fullName, startTime, stopTime, interval, usedTolerance, numberOfIntervals, isDefaultStartTime, isDefaultInterval, isDefaultTolerance, compiler, compilerSettings, osver, hostname, user, description, gitURL, gitRevision, gitStatus);
              print(logStat, fullPathName(modelDirectory + "/creation.txt"));

              // Check model
              OK := checkModel(fullName);
              (logStat, , , ) := getLastError();
              if OK then
                print(logStat, fullPathName(modelDirectory + "/check_passed.log"));

                // Translate model
                OK := translateModel(fullName);
                (logStat, , , ) := getLastError();
                if OK then
                  print(logStat, fullPathName(modelDirectory + "/translate_passed.log"));
                  Advanced.StoreProtectedVariables := true;
                  Advanced.EfficientMinorEvents := false;
                  Advanced.PlaceDymolaSourceFirst := 2; // See https://github.com/modelica/ModelicaStandardLibrary/pull/3453
                  OK := experimentSetupOutput(textual=false, doublePrecision=true, states=true, derivatives=true, inputs=true, outputs=true, auxiliaries=true, equidistant=true, events=true, debug=false);

                  // Simulate model
                  OK := simulateModel(problem=fullName, startTime=startTime, stopTime=stopTime, tolerance=usedTolerance, method="Dassl", outputInterval=interval, resultFile=name);
                  if OK then
                    move("dslog.txt", fullPathName(modelDirectory + "/simulate_passed.log"));

                    // Write result variables as CSV file
                    MATFileName := name + ".mat";
                    CSVFileName := fullPathName(modelDirectory + "/" + name + ".csv");
                    n := readTrajectorySize(MATFileName);
                    if exist(fullPathName(modelDirectory + "/comparisonSignals.txt")) then
                      varNames := removeLineComments(readFile(fullPathName(modelDirectory + "/comparisonSignals.txt")));
                      if varNames[1] == "time" then
                        varNames[1] := "Time";
                      end if;
                      traj := readTrajectory(MATFileName, varNames, n);
                      traj_transposed := transpose(traj);
                      if varNames[1] == "Time" then
                        varNames[1] := "time";
                      end if;
                      DataFiles.writeCSVmatrix(CSVFileName, varNames, traj_transposed, separator=",", quoteAllHeaders=true);
                    end if;

                    // Move or remove MAT file
                    if keepResultFile then
                      move(MATFileName,  fullPathName(modelDirectory + "/" + name + ".mat"));
                    else
                      removeFile(MATFileName);
                    end if;
                  else
                    nr[3] := nr[3] + 1;
                    move("dslog.txt", fullPathName(modelDirectory + "/simulate_failed.log"));
                  end if;
                else
                  nr[2] := nr[2] + 1;
                  print(logStat, fullPathName(modelDirectory + "/translate_failed.log"));
                end if;
              else
                nr[1] := nr[1] + 1;
                print(logStat, fullPathName(modelDirectory + "/check_failed.log"));
              end if;
            end if;
          end if;
        end if;
      end for;
      annotation(__Dymola_interactive=true);
    end inspectPackageEx;

    function scanReal "Scan Real value from string"
      extends Modelica.Icons.Function;
      input String str "String";
      input Real default "Default value if scan fails";
      output Boolean isDefaultUsed "= true, if default value is used";
      output Real val "Return value";
    protected
      Integer index;
    algorithm
      if Modelica.Utilities.Strings.isEmpty(str) then
        isDefaultUsed := true;
        val := default;
      else
        isDefaultUsed := false;
        index := Modelica.Utilities.Strings.find(str, "=");
        val := Modelica.Utilities.Strings.scanReal(str, index + 1);
      end if;
    end scanReal;

    function command "System command execution"
      extends Modelica.Icons.Function;
      input String commandString "Command string";
      output String returnString "Return string";
    protected
      String lines[:];
      Integer rc;
    algorithm
      rc := Modelica.Utilities.System.command(commandString + ">cmd.txt");
      lines := Modelica.Utilities.Streams.readFile("cmd.txt");
      returnString := "";
      for i in 1:size(lines, 1) loop
        returnString := returnString + lines[i];
      end for;
    end command;

    function removeLineComments "Remove commented strings from vector of strings"
      input String x[:] "Input string vector";
      input String lineComment = "//" "Line comment";
      output String y[:] "Output string vector";
    protected
      Integer pos;
    algorithm
      for i in 1:size(x, 1) loop
        pos := Modelica.Utilities.Strings.find(x[i], lineComment);
        if pos == 0 then
          y := cat(1, y, x[i:i]);
        end if;
      end for;
    end removeLineComments;

    impure function getCreation "Return creation meta data"
      extends Modelica.Icons.Function;
      input String modelIdent = "" "Model indent";
      input String modelName = "" "Model name";
      input Real startTime "Start time";
      input Real stopTime "Stop time";
      input Real interval "Interval";
      input Real tolerance "Solver tolerance";
      input Integer numberOfIntervals "Number of intervals";
      input Boolean isDefaultStartTime "= true, if start time is the default start time";
      input Boolean isDefaultInterval "= true, if start time is the default interval";
      input Boolean isDefaultTolerance "= true, if start time is the default solver tolerance";
      input String compiler "Compiler type, for example, \"vs\"";
      input String compilerSettings[:] "Compiler settings in name=value pairs";
      input String osver "OS version information";
      input String hostname "Host name";
      input String user "User name";
      input String description "Description";
      input String gitURL "Run command \"git config --get remote.origin.url\"";
      input String gitRevision "Run command \"git rev-parse --short HEAD\"";
      input String gitStatus "Run command \"git status --porcelain --untracked-files=no\"";
      output String s "Creation meta data";
    algorithm
      s := "[ResultCreationLog]\nmodelName=\"" + modelName + "\"\n";
      s := s + "\n// Test info\n";
      s := s + "generationTool=\"" + DymolaVersion() + "\"\n";
      s := s + "generationDateAndTime=\"" + command("getdatetime +\"%Y-%m-%dT%TZ\"") + "\"\n";
      s := s + "gitURL=\"" + gitURL + "\"\n";
      s := s + "gitRevision=" + gitRevision + "\n";
      if Modelica.Utilities.Strings.isEmpty(gitStatus) then
        s := s + "gitStatus=\n";
      else
        s := s + "gitStatus=\"" + gitStatus + "\"\n";
      end if;
      s := s + "testPC=\"" + hostname + "\"\n";
      s := s + "testOS=\"" + osver + "\"\n";
      s := s + "testUser=\"" + user + "\"\n";
      s := s + "testDescription=\"" + description + "\"\n";
      s := s + "\n// Experiment settings (standardized annotation)\n";
      s := s + "StartTime=" + String(startTime);
      if isDefaultStartTime then
        s := s + "\n";
      else
        s := s + " // from model\n";
      end if;
      s := s + "StopTime=" + String(stopTime) + " // from model\n";
      s := s + "Interval=" + String(interval);
      if isDefaultInterval then
        s := s + " // (stopTime-startTime)/" + String(numberOfIntervals) + "\n";
      else
        s := s + " // used annotation from model, multiplied by 0.5\n";
      end if;
      s := s + "Tolerance=" + String(tolerance);
      if tolerance < 2e-12 then
        s := s + " // used annotation from model, because attempt with tolerance of " + String(0.1*tolerance) + "\n";
      elseif isDefaultTolerance then
        s := s + " // used default, because no tolerance annotation in model\n";
      else
        s := s + " // used annotation from model, multiplied by 0.1\n";
      end if;
      s := s + "\n// Experiment settings (tool specific)\n";
      s := s + "// The following lines can be used as mos-script in Dymola\n";
      s := s + "Advanced.PedanticModelica := false;\n";
      s := s + "SetDymolaCompiler(\"" + compiler + "\", {\"";
      for i in 1:size(compilerSettings, 1) - 1 loop
        s := s + compilerSettings[i] + "\", \"";
      end for;
      s := s + compilerSettings[end] + "\"});\n";
      s := s + "Evaluate := false;\n";
      s := s + "OutputCPUtime := false;\n";
      s := s + "translateModel(\"" + modelName + "\");\n";
      s := s + "Advanced.StoreProtectedVariables := true;\n";
      s := s + "Advanced.EfficientMinorEvents := false;\n";
      s := s + "Advanced.PlaceDymolaSourceFirst := 2;\n";
      s := s + "experimentSetupOutput(\n";
      s := s + "  textual=false,\n";
      s := s + "  doublePrecision=true,\n";
      s := s + "  states=true,\n";
      s := s + "  derivatives=true,\n";
      s := s + "  inputs=true,\n";
      s := s + "  outputs=true,\n";
      s := s + "  auxiliaries=true,\n";
      s := s + "  equidistant=true,\n";
      s := s + "  events=true,\n";
      s := s + "  debug=false);\n";
      s := s + "simulateModel(\n";
      s := s + "  problem=\"" + modelName + "\",\n";
      s := s + "  startTime=" + String(startTime) + ",\n";
      s := s + "  stopTime=" + String(stopTime) + ",\n";
      s := s + "  outputInterval=" + String(interval) + ",\n";
      s := s + "  method=\"Dassl\",\n";
      s := s + "  tolerance=" + String(tolerance) + ",\n";
      s := s + "  resultFile=\"" + modelIdent + "\");";
    end getCreation;

    function isInternalClass "Simple check if a class is internal"
      extends Modelica.Icons.Function;

      input String s = "Modelica" "Class name";
      output Boolean isInternal "Internal flag";
    protected
      String extendsClasses[:] = ModelManagement.Structure.AST.ExtendsInClass(s);
    algorithm
      isInternal := false;
      for i in 1:size(extendsClasses, 1) loop
        if 0 < Modelica.Utilities.Strings.findLast(extendsClasses[i], "InternalPackage") then
          isInternal := true;
          break;
        end if;
      end for;
    end isInternalClass;

    function isObsoleteClass "Simple check if a class is obsolete"
      extends Modelica.Icons.Function;

      input String s = "Modelica" "Class name";
      output Boolean isObsolete "Obsolete flag";
    protected
      String obsoleteString = ModelManagement.Structure.AST.GetAnnotationString(s, "obsolete");
      String extendsClasses[:] = ModelManagement.Structure.AST.ExtendsInClass(s);
    algorithm
      isObsolete := not Modelica.Utilities.Strings.isEmpty(obsoleteString);
      if not isObsolete then
        for i in 1:size(extendsClasses, 1) loop
          if 0 < Modelica.Utilities.Strings.findLast(extendsClasses[i], "ObsoleteModel") then
            isObsolete := true;
            break;
          end if;
        end for;
      end if;
    end isObsoleteClass;

    function isExampleModel "Simple check if a class is an example model"
      extends Modelica.Icons.Function;

      input String s = "Modelica" "Class name";
      output Boolean isExample "Example flag";
    protected
      String extendsClasses[:] = ModelManagement.Structure.AST.ExtendsInClass(s);
      ModelManagement.Structure.AST.ClassAttributes attributes;
    algorithm
      isExample := false;
      attributes := ModelManagement.Structure.AST.GetClassAttributes(s);
      if attributes.restricted == "model" then
        for i in 1:size(extendsClasses, 1) loop
          if 0 < Modelica.Utilities.Strings.findLast(extendsClasses[i], "Example") then
            isExample := true;
            Modelica.Utilities.Streams.print(s);
            break;
          end if;
        end for;
      end if;
    end isExampleModel;
  end Internal;

  model TestModel
    Real x;
  equation
    der(x) = -x;
  end TestModel;
  annotation (uses(DataFiles(version="1.0.5"), ModelManagement(version="1.1.8"), Modelica(version="3.2.3")));
end ReleaseChecks;
