@echo off
set SAVESTAMP=%DATE:/=-%_%TIME::=-%
set SAVESTAMP=%SAVESTAMP: =%
set SAVESTAMP=cmd_%SAVESTAMP:,=.%.log
set SAVESTAMP=logs/%SAVESTAMP%
echo Log will be saved to %SAVESTAMP%
echo Loading Application...
cd utilities
QuickEditOff.exe
cd ..
matlab -batch "startapp('logoptions', struct('logfile', '%SAVESTAMP%'), 'uiwait', true);"