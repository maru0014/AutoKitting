@echo off


echo *********************���ӎ���*********************
echo �E�Ǘ��Ҍ������K�v�ł�
echo �EBIOS�p�X���[�h��HDD�p�X���[�h�͎��O�ɉ������Ă�������
echo **************************************************


openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��܂���
	pause

) else (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��邱�Ƃ��m�F���܂���

	powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas
	if not exist C:\Config.json powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas

	start C:\AutoKitting\Run-PS.bat

)
