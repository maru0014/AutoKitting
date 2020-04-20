@echo off
openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo 管理者権限で実行されていません
	pause

) else (

	echo 管理者権限で実行されていることを確認しました
	echo PowerShellスクリプトを実行します
	powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Main.ps1 -verb runas

)
