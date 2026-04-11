@echo off
set "DEVECO_SDK_HOME=E:\DevEco Studio\sdk"
set "DEVECO_JBR_HOME=E:\DevEco Studio\jbr"
if exist "%DEVECO_JBR_HOME%\bin\java.exe" (
  set "JAVA_HOME=%DEVECO_JBR_HOME%"
  set "PATH=%DEVECO_JBR_HOME%\bin;%PATH%"
)
set "JAVA_OPTS=-Xmx4096m"
call "E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" %*
