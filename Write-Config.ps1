$pcname = Read-Host "PC名を入力(未入力の場合はConfig.jsonのデフォルト値を参照します)"

if ( $pcname -ne "") {

	Write-Host "PC名を $($pcname) として処理を続行します" -ForeGroundColor yellow
	$config = @{pcname = $pcname }
	$config | ConvertTo-Json | Out-File C:\Config.json -Encoding UTF8

}
else {

	Write-Host "PC名が指定されなかったためデフォルト値で処理を続行します" -ForeGroundColor yellow

}
