$pcname = Read-Host "PC�������(�����͂̏ꍇ��Config.json�̃f�t�H���g�l���Q�Ƃ��܂�)"

if ( $pcname -ne "") {

	Write-Host "PC���� $($pcname) �Ƃ��ď����𑱍s���܂�" -ForeGroundColor yellow
	$config = @{pcname = $pcname }
	$config | ConvertTo-Json | Out-File C:\Config.json -Encoding UTF8

}
else {

	Write-Host "PC�����w�肳��Ȃ��������߃f�t�H���g�l�ŏ����𑱍s���܂�" -ForeGroundColor yellow

}
