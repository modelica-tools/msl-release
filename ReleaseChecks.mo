within ;
package ReleaseChecks
  extends Modelica.Icons.Package;

  function printExecutables
    extends Modelica.Icons.Function;
    import Modelica.Utilities.Streams.print;

    input String libraries[:] = {"Modelica", "ModelicaTest"}
      "Libraries that shall be inspected";
    input String fileNameSuccessful = "log_successful.txt"
      "File name where successful translating model/block names shall be stored";
    input String fileNameFailed = "log_failed.txt"
      "File name where model/block names shall be stored that fail translation";
  algorithm
    // Remove log files
    Modelica.Utilities.Files.removeFile(fileNameSuccessful);
    Modelica.Utilities.Files.removeFile(fileNameFailed);

    // Print heading
    print("The following models/blocks with StopTime annotation translate successfully:\n",
          fileNameSuccessful);
    print("The following models/blocks with StopTime annotation fail translation if pedantic=true:\n",
          fileNameFailed);

    // Set Dymola pedantic mode
    Advanced.PedanticModelica:=true;

    // Inspect packages
    for packageName in libraries loop
        Internal.inspectPackage(packageName, fileNameSuccessful, fileNameFailed);
    end for;
  end printExecutables;

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
    annotation (Documentation(info="<html>
Modified version of <a href=\"modelica://ModelManagement.Structure.AST.Examples.countModelsInPackage\">
countModelsInPackage</a> from ModelManagement library of Dymola</html>"));
  end countClassesInPackage;

  function genDoc "Export HTML documentation"
    extends Modelica.Icons.Function;

    input String name = "Modelica" "Name of Modelica model or package";
    input String directory = Modelica.Utilities.Files.loadResource("modelica://" + name + "/Resources/help") "Directory of exported HTML files";
  algorithm
    exportHTMLDirectory(name, directory);
    annotation (Documentation(info="<html>
Generate HTML documentation from Modelica model or package in Dymola</html>"));
  end genDoc;

  package Internal
    extends Modelica.Icons.InternalPackage;

    function inspectPackage
      extends Modelica.Icons.Function;

      import Modelica.Utilities.Streams.print;
      input String packageName "Package to be inspected";
      input String fileNameSuccessful = "log_successful.txt"
        "File name where successful translating model/block names shall be stored";
      input String fileNameFailed = "log_failed.txt"
        "File name where model/block names shall be stored that fail translation";
    protected
      String localClasses[:];
      String StopTime;
      Boolean OK;
    algorithm
      localClasses :=ModelManagement.Structure.AST.ClassesInPackage(packageName);
      for name in localClasses loop
         fullName :=packageName + "." + name;
         classAttributes :=ModelManagement.Structure.AST.GetClassAttributes(fullName);
         if classAttributes.restricted == "package" then
            inspectPackage(fullName, fileNameSuccessful, fileNameFailed);

         elseif classAttributes.restricted == "model" or
                classAttributes.restricted == "block" then
            StopTime :=ModelManagement.Structure.AST.GetAnnotation(fullName, "experiment.StopTime");
            if StopTime <> "" then
               OK :=translateModel(fullName);
               if OK then
                  print(fullName, fileNameSuccessful);
               else
                  print(fullName, fileNameFailed);
               end if;
            end if;
         end if;
      end for;
    end inspectPackage;

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
  annotation (uses(Modelica(version="3.2.3"), ModelManagement(version="1.1.7")));
end ReleaseChecks;
