@echo off
set JAVA_HOME=C:\Users\vcout\.bubblewrap\jdk\jdk-17.0.11+9
set ANDROID_HOME=C:\Users\vcout\.bubblewrap\android_sdk
set ANDROID_SDK_ROOT=C:\Users\vcout\.bubblewrap\android_sdk
cd /d "%~dp0"
call gradlew.bat assembleRelease --stacktrace
echo GRADLE_EXIT=%ERRORLEVEL%
