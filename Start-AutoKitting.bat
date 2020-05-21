@echo off


echo *********************注意事項*********************
echo ・管理者権限が必要です
echo ・BIOSパスワードやHDDパスワードは事前に解除してください
echo **************************************************


openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo 管理者権限で実行されていません
	pause

) else (

	echo 管理者権限で実行されていることを確認しました

	powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas
	if not exist C:\Config.json powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas

	start C:\AutoKitting\Run-PS.bat

)
