@echo off
openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��܂���
	pause

) else (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��邱�Ƃ��m�F���܂���
	echo PowerShell�X�N���v�g�����s���܂�
	powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Main.ps1 -verb runas

)
