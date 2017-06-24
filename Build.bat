@rem ----------- SET DEFAULT JAVA PATH HERE ------------------
@IF "%JAVA_HOME%"=="" SET JAVA_HOME=..\..\..\Java\JRE81

@IF EXIST "%JAVA_HOME%\bin\java.exe" GOTO HAVEJAVA
@echo Java not found in JAVA_HOME environment variable.
@echo Set the environment variable or edit this batch file to set it directly.
goto DONE

:HAVEJAVA
"%JAVA_HOME%\bin\java.exe" -Xmx384m -Dsun.io.useCanonCaches=false -Djava.util.Arrays.useLegacyMergeSort=true -jar Flex\mxmlc.jar +flexlib=Flex -define=CONFIG::interactive,true -o SWFAutomationPreload_Interactive.swf SWFAutomationPreload.as
"%JAVA_HOME%\bin\java.exe" -Xmx384m -Dsun.io.useCanonCaches=false -Djava.util.Arrays.useLegacyMergeSort=true -jar Flex\mxmlc.jar +flexlib=Flex -define=CONFIG::interactive,false -o SWFAutomationPreload.swf SWFAutomationPreload.as

:DONE
pause
