@echo off
powershell -executionpolicy Bypass -file %~dp0\encryption.ps1 -verb runas
pause
