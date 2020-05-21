@echo off

set Root=%~dp0
set Source="\\NAS\share\AutoKitting"

echo *********************注意事項*********************
echo ・管理者権限が必要です
echo ・BIOSパスワードやHDDパスワードは事前に解除してください
echo ・C:\AutoKittingフォルダ取得済みの場合は Start-AutoKitting.bat を直接実行してください
echo **************************************************

set USRNAME=
set /P USERNAME="ネットワークドライブ接続用ユーザ名を入力： "
net use %Source% /use:%USERNAME%

openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo 管理者権限で実行されていません
	pause

) else (

	echo 管理者権限で実行されていることを確認
	echo キッティングに必要なファイルを取得します
	mkdir C:\AutoKitting
	cd C:\AutoKitting

	COPY /y %Source%\Write-Config.ps1 C:\AutoKitting
	if not exist C:\Config.json powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas

	ROBOCOPY %Source% C:\AutoKitting /S /XO /R:2 /W:0

	echo ファイルの取得を完了
	start C:\AutoKitting\Run-PS.bat

)
