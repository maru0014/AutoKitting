@echo off

set Root=%~dp0
set Source="\\NAS\share\AutoKitting"

echo *********************���ӎ���*********************
echo �E�Ǘ��Ҍ������K�v�ł�
echo �EBIOS�p�X���[�h��HDD�p�X���[�h�͎��O�ɉ������Ă�������
echo �EC:\AutoKitting�t�H���_�擾�ς݂̏ꍇ�� Run-PS.bat �𒼐ڎ��s���Ă�������
echo **************************************************

set USRNAME=
set /P USERNAME="�l�b�g���[�N�h���C�u�ڑ��p���[�U������́F "
net use %Source% /use:%USERNAME%

openfiles > NUL 2>&1
if NOT %ERRORLEVEL% EQU 0 (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��܂���
	pause

) else (

	echo �Ǘ��Ҍ����Ŏ��s����Ă��邱�Ƃ��m�F���܂���
	echo �L�b�e�B���O�ɕK�v�ȃt�@�C�����擾���܂�
	mkdir C:\AutoKitting
	cd C:\AutoKitting

	COPY /y %Source%\Write-Config.ps1 C:\AutoKitting
	if not exist C:\Config.json powershell -executionpolicy RemoteSigned -file C:\AutoKitting\Write-Config.ps1 -verb runas

	ROBOCOPY %Source% C:\AutoKitting /S /XO /R:2 /W:0

	echo �t�@�C���̎擾���������܂���
	start C:\AutoKitting\Run-PS.bat

)
