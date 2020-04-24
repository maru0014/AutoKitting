
# ログ出力開始
Start-Transcript "$PSScriptRoot/Kitting.log" -append

Write-Host @"
*********************************************************
*
* Windows10 Auto Kitting Script / Main.ps1
* バージョン : 1.02
* 最終更新日 : 2020/04/24
*
"@ -ForeGroundColor green

Write-Host "$(Date -Format g) 実行中のユーザ : " $env:USERNAME

# 設定ファイルの読み込み
Write-Host "$(Date -Format g) 設定ファイル読み込み : $($PSScriptRoot)/Config.json"
$config = Get-Content "$PSScriptRoot/Config.json" -Encoding UTF8 | ConvertFrom-Json

# 関数の読み込み
Write-Host "$(Date -Format g) 関数ファイル読み込み : $($PSScriptRoot)/Functions.ps1"
. $PSScriptRoot/Functions.ps1

# PC名定義（Get-Files.batによってPC名が設定された場合はC:/pcname.txtの名前を使用）
if (Test-Path "C:/Config.json") {
  $pcname = (Get-Content "$PSScriptRoot/Config.json" -Encoding UTF8 | ConvertFrom-Json).pcname
}
else {
  $pcname = $config.pcname
}


# 設定値の最終確認
Write-Host "`r`n********************** 設定値確認 ***********************" -ForeGroundColor green
Write-Host @"
コンピュータ名　　　: $($pcname)
セットアップユーザ　: $($config.setupuser.name)
ドメイン参加　　　　: $($config.joinDomain)
Administrator有効化 : $($config.enableAdministrator)
BitLocker有効化 　　: $($config.bitLocker.flag)
RDP有効化 　　　　　: $($config.enableRemoteDesktop)
Defender無効化　　　: $($config.disableWinDefender)
スリープ無効化　　　: $($config.desableSleep)
休止状態無効化　　　: $($config.desableHibernate)
IPアドレス固定　　　: $($config.network.staticIP.flag)
SNP無効化 　　　　　: $($config.network.desableSnp)
IPv6無効化　　　　　: $($config.network.disableIPv6)

インストールするアプリケーション :
"@ -ForeGroundColor Yellow

foreach ($app in $config.apps) {
  Write-Host $app.name -ForeGroundColor yellow
}


Write-Host "`r`n******************* システム情報の変更 *******************" -ForeGroundColor green

# 自動ログオン未設定の場合は設定する
Enable-AutoLogon $config.setupuser.name $config.setupuser.pass

# タスクが未登録ならスケジューラにログオンスクリプトを登録
Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $config.setupuser.name $config.setupuser.pass

# コンピュータ名が設定値と異なる場合は変更
if ($Env:COMPUTERNAME -ne $pcname) {
  Write-Host "$(Date -Format g) コンピュータ名を変更して再起動します"
  Rename-Computer -NewName $pcname -Force -Restart
  Exit
}
else {
  Write-Host "$(Date -Format g) コンピュータ名は変更済みです" -ForeGroundColor yellow
  Write-Host "$(Date -Format g) コンピュータ名 : " $Env:COMPUTERNAME -ForeGroundColor yellow
}


# 1度だけ実行
if (-Not (Test-Path "$PSScriptRoot/onlyOnce1")) {

	New-Item "$PSScriptRoot/onlyOnce1"

	# リモートデスクトップ有効/無効
	$remoteDesktopStatus = Get-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections"
	if ($config.enableRemoteDesktop -and ($remoteDesktopStatus -ne 0)) {
	  Write-Host "$(Date -Format g) リモートデスクトップ有効化"
	  Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 0
	}
	elseif($remoteDesktopStatus -ne 1){
	  Write-Host "$(Date -Format g) リモートデスクトップ無効化"
	  Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 1
	}

	# Windows Defender無効化
	$DefenderStatus = Get-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"
	if ($config.desableDefender -and ($DefenderStatus -ne 1)) {
	  Write-Host "$(Date -Format g) Windows Defender無効化"
	  Set-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" "DWord" 1
	}

	# SNP無効化
	((Get-NetTCPSetting).AutoTuningLevelLocal).Contains("Disabled")
	if ($config.network.desableSnp) {
	  Write-Host "$(Date -Format g) SNP無効化"
	  Set-NetTCPSetting -AutoTuningLevelLocal Disabled
	}

	# スリープ無効化
	if ($config.desableSleep) {
	  Write-Host "$(Date -Format g) スリープ無効化"
	  powercfg /x /standby-timeout-ac 0
	}

	# 休止状態無効化
	if ($config.desableHibernate) {
	  Write-Host "$(Date -Format g) 休止状態無効化"
	  powercfg /x /hibernate-timeout-ac 0
	}

  # # Windows Update から .NET Framework 3.5 の機能ファイルをインストール
  # dism /online /Enable-Feature /FeatureName:NetFx3
}

if ($config.upgradeWindows) {
  $winver = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
  if ($winver -ne "1909") {
    # Win10 1909をインストール
    Write-Host "$(Date -Format g) Windows10 $($winver) → 1909アップグレード実行"
    Start-Process -FilePath ($PSScriptRoot + "/Applications/1909/setup.exe") -argumentList "/Auto Upgrade" -Wait
  }
}

Write-Host "`r`n***************** 最新までWindows Update *****************" -ForeGroundColor green
Run-WindowsUpdate


Write-Host "`r`n************* アプリケーションのインストール *************" -ForeGroundColor green

# Configのapps以下配列を順にチェックしてインストール
foreach ($app in $config.apps) {
  if (-not(Test-Path $app.checkFilePath)) {
    Write-Host "$(Date -Format g) $($app.name)をインストール" -NoNewLine

    # 引数あり/なし で分岐してインストーラを実行
    if ($app.Argument -eq "") {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }
    else {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -argumentList $app.Argument -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }

    # インストール完了を待機（タイムアウト設定時間に達したら待たずに進む）
    Wait-Process -InputObject $installing -Timeout $app.timeout
    Start-Sleep -s 30

    # インストール完了をチェック
    if (Test-Path $app.checkFilePath) {
      Write-Host "...完了"
    }else{
      Write-Host "...失敗"
      # チャットでインストール失敗を通知
      Send-Chat "[$($config.pcname)] $($app.name)のインストールに失敗しました" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken
    }

    # onlyOnce(1回だけ実行する) が true の場合は フラグファイルを作成する
    # 2回目以降をスキップするためにはConfig.jsonのcheckFilePathをフラグファイルの名前にする必要あり
    if (($app.onlyOnce) -And (-Not (Test-Path "$PSScriptRoot/$($app.name)"))) {
      New-Item "$PSScriptRoot/$($app.name)"
    }
  } else {
    Write-Host "$(Date -Format g) $($app.name)はインストール済みです"
  }
}


# 1度だけ実行
if (-Not (Test-Path "$PSScriptRoot/onlyOnce2")) {

	New-Item "$PSScriptRoot/onlyOnce2"

	if ($config.defaultDesktop) {
		Write-Host "`r`n*********** Defaultユーザのデスクトップを設定 ************" -ForeGroundColor green
		cmd /C xcopy "$($PSScriptRoot)\Desktop" "C:\Users\Default\Desktop\" /D /Y /E
	}

	if ($config.defaultAppAssoc) {
		Write-Host "`r`n****************** 既定のアプリを設定 *******************" -ForeGroundColor green
		Dism.exe /Online /Import-DefaultAppAssociations:$PSScriptRoot\AppAssoc.xml
	}


	Write-Host "`r`n******************** ネットワーク設定 ********************" -ForeGroundColor green

	# 固定IPアドレス
	if ($config.network.staticIP.flag) {
	  Write-Host "$(Date -Format g) 固定IPアドレスを設定"
	  Get-NetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $config.network.staticIP.address -PrefixLength $config.network.staticIP.prefixLength -DefaultGateway $config.network.staticIP.gateway
	}

	# IPv6無効化
	if ($config.network.disableIPv6) {
	  Write-Host "$(Date -Format g) IPv6を無効化"
	  Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6
	  Get-NetAdapter | Get-NetAdapterBinding -ComponentID ms_tcpip6
	}

	# DNS設定
	if ($config.network.dns -ne "") {
	  Write-Host "$(Date -Format g) DNS設定"
	  Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $config.network.dns
	}

	# DNSサフィックス設定
	if ($config.network.dnsSuffix.Count -gt 0) {
	  Write-Host "$(Date -Format g) DNSサフィックス設定"
	  $suffixlist = $adapter.DNSDomainSuffix.SearchOrder
	  if ($suffix -eq "") {
	    $suffixlist = $config.network.dnsSuffix
	  }
	  else {
	    $suffixlist += ",$($config.network.dnsSuffix)"
	  }
	  Invoke-WmiMethod -class win32_networkadapterconfiguration -Name SetDNSSuffixSearchOrder -ArgumentList @($suffixlist) , $null
	}
	# 有効なアダプターごとの設定値を出力
  Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled = 'true'"


  # 不要なアプリの削除
	if ($config.runUninstallApps) {
		Write-Host "`r`n******** 不要なアプリケーションのアンインストール ********" -ForeGroundColor green
		. $PSScriptRoot\Uninstall-Apps.ps1
	}
}


# Administrator 有効化
if ($config.enableAdministrator -and (-Not(Get-LocalUser Administrator).Enabled)) {

  Write-Host "`r`n******************** Administrator設定 ********************" -ForeGroundColor green
  $Password = Decryption-Password "$($PSScriptRoot)/Password/key.txt" "$($PSScriptRoot)/Password/encrypted.txt"
  cmd /C net user administrator $StringPassword /active:yes

}


# ローカルユーザが設定されていて、存在しない場合作成
if(($config.localUser.name -ne "") -And (-not(Test-User $config.localUser.name))) {

  Write-Host "`r`n*************** 利用者ローカルユーザの作成 ***************" -ForeGroundColor green
  # ユーザ作成
  if ($config.localUser.pass -eq "****") {
    $localUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-01.txt" "$($PSScriptRoot)/Password/encrypted-01.txt"
  }else {
    $localUserPass = $config.localUser.pass
  }
  Create-User $config.localUser.name $localUserPass

  # パスワード無期限設定
  if ($config.localUser.dontExpirePassword) {
    DontExpire-Password $config.localUser.name
  }

  # ローカルグループに追加
  foreach ($Group in $config.localUser.localGroup) {
    Write-Host "$(Date -Format g) ユーザー$($config.localUser.name) をローカルグループに追加$($Group)"
    Add-LocalGroupMember -Group $Group -Member $config.localUser.name
  }
}


# ドメイン参加:true & ドメイン未参加 の場合は実行
if ($config.joinDomain -And ($config.domain.address -ne (Get-WmiObject Win32_ComputerSystem).domain) ) {

  Write-Host "`r`n*************** 利用者ユーザでドメイン参加 ***************" -ForeGroundColor green
  try {
    if ($config.domainUser.pass -eq "****") {
      $domainUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-02.txt" "$($PSScriptRoot)/Password/encrypted-02.txt"
    }else {
      $domainUserPass = $config.domainUser.pass
    }
    $result = Join-Domain $config.domain.name $config.domainUser.name $domainUserPass $config.domainUser.ouPath
  }
  catch {
    # ドメイン参加失敗を通知
    Send-Chat "[$($config.pcname)] ドメイン参加に失敗しました。Config.jsonを修正して再起動してください。$($result)" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken
    Write-Host "$(Date -Format g) ドメイン参加に失敗しました。Config.jsonを修正して再起動してください。"
    Pause
    Exit
  }
    # 利用者ユーザをローカルグループに追加
    foreach ($Group in $config.domainUser.localGroup) {
      Write-Host "`r`n************** 利用者ユーザをグループに追加 **************" -ForeGroundColor green
      if (-Not(Test-MemberDomainAccunt $config.domain.name $config.domainUser.name $Group)) {
        Write-Host "$(Date -Format g) ユーザー$($config.domainUser.name)をローカルグループに追加$($Group)"
        net localgroup $Group "$($config.domain.name)\$($config.domainUser.name)" /ADD
        # Join-ADUser2Group $config.domain.name $config.domainUser.name $Group
      }
    }
    # ドメインユーザを一時的にAdministratorsに追加
    if (-Not(Test-MemberDomainAccunt $config.domain.name $userName "Administrators")) {
      net localgroup "Administrators" "$($config.domain.name)\$($config.domainUser.name)" /ADD
    }
    # Write-Host "$(Date -Format g) 再起動"
    # Restart-Computer -Force
    # Exit

}


# 作成したユーザで自動ログオン設定
if ($env:USERNAME -eq $config.setupuser.name) {
  Write-Host "`r`n************* 利用者ユーザで自動ログオン設定 *************" -ForeGroundColor green
  Write-Host "$(Date -Format g) セットアップユーザのログオンスクリプトを解除"
  Remove-Task "AutoKitting"

  Write-Host "$(Date -Format g) 利用者ユーザのログオンスクリプトを設定"
  if ($config.joinDomain) {
    if ($config.domainUser.pass -eq "****") {
      $domainUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-02.txt" "$($PSScriptRoot)/Password/encrypted-02.txt"
    }else {
      $domainUserPass = $config.domainUser.pass
    }
    Enable-AutoLogon $config.domainUser.name $config.domainUser.pass $config.domain.name
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" "$($config.domain.name)\$($config.domainUser.name)" $domainUserPass
  }
  else {
    if ($config.localUser.pass -eq "****") {
      $localUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-01.txt" "$($PSScriptRoot)/Password/encrypted-01.txt"
    }else {
      $localUserPass = $config.localUser.pass
    }
    Enable-AutoLogon $config.localUser.name $localUserPass
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $config.localUser.name $localUserPass
  }

  Write-Host "$(Date -Format g) 再起動"
  Restart-Computer -Force
  Exit
}


if ($config.deleteTaskbarUWPApps) {
  Write-Host "`r`n******** タスクバーの Edge/Store/メール を削除 ********" -ForeGroundColor green
  # タスクバーの Edge/Store/メール を削除
  . $PSScriptRoot\Delete-TaskbarUWPApps.ps1
}

if ($config.network.drive -ne "") {
    Write-Host "`r`n************* ネットワークドライブの割り当て *************" -ForeGroundColor green
    foreach ($drive in $config.network.drive) {
      Add-NetworkDrive $drive.name $drive.path $drive.user $drive.pass
    }
}

# BitLockerを有効化する設定かつ暗号化されていない場合は実行
$BLV = Get-BitLockerVolume -MountPoint "C:"
$EncryptedFlag = $BLV.ProtectionStatus -eq "off"

if ($config.bitlocker.flag -And $EncryptedFlag) {
  Write-Host "`r`n******************** Bitlockerの有効化 ********************" -ForeGroundColor green

  # 既存のKeyProtectorを削除
  foreach($KP in $BLV.KeyProtector){
    if ($BLV.KeyProtectorType -eq "RecoveryPassword") {
      Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KP.KeyProtectorId
    }
  }

  if ($config.bitLocker.saveRecoveryPassInAD) {
    # ADへの回復パスワード保存を有効化
    Enable-SaveRecoveryPassInAD

    # 回復パスワードを設定
    Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
    $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).KeyProtectorId

    # ADに回復パスワードを保存
    Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $kpid
  }

  # Password設定が有効 場合は実行
  if ($config.bitLocker.password ) {
    # スタートアップ時 拡張PINによる認証を設定
    Enable-StartupPin

    # パスワードをSecureStringに変換
    $bitLockerPass = ConvertTo-SecureString $config.bitLocker.password -AsPlainText -Force

    if ((Get-Tpm).TpmPresent) {
      # 拡張PINを設定してBitLockerを有効化
      Enable-BitLocker -MountPoint "C:" -TpmAndPinProtector $bitLockerPass -UsedSpaceOnly -skiphardwaretest
    }
    else {
      # 有効なTPMがない場合はPasswordProtectorで有効化
      Enable-BitLocker -MountPoint "C:" -PasswordProtector $bitLockerPass -UsedSpaceOnly -skiphardwaretest
    }

  }else{
    manage-bde -on C:
  }

    # チャットでプロテクタIDと回復パスワードを通知
    $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).KeyProtectorId | Out-String
    $rp = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).RecoveryPassword | Out-String
    Send-Chat "[$($config.pcname)] BitLocker`r`nプロテクタID： $($kpid)`r`n回復パスワード： $($rp)" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken

}

# ドメインユーザをAdministratorsから削除
if (-Not ($config.domainUser.localGroup).Contains("Administrators")) {
  if (-Not (Test-MemberDomainAccunt $config.domain.name $userName "Administrators")) {
    net localgroup "Administrators" "$($config.domain.name)\$($config.domainUser.name)" /DELETE
  }
}

if ($config.setupUser.delete) {
  Write-Host "`r`n**************** セットアップユーザの削除 ****************" -ForeGroundColor green

  # ユーザ削除
  Write-Host "$(Date -Format g) $($config.setupuser.name)を削除"
  Remove-LocalUser -Name $config.setupuser.name

  # ユーザプロファイル削除
  $GetUserQuery = 'select * from win32_userprofile where LocalPath="C:\\Users\\' + $config.setupuser.name + '"'
  Get-WmiObject -Query $GetUserQuery | Remove-WmiObject
}

# Taskを削除
if (Test-Task "AutoKitting") {
  Remove-Task "AutoKitting"
  Write-Host "$(Date -Format g) ログオンスクリプトを解除"
}

# 自動ログオン無効化
Disable-AutoLogon

# kitting.log 以外の AutoKittingフォルダ配下を削除
Remove-Item C:\AutoKitting\* -Exclude kitting.log -Recurse
Write-Host "$(Date -Format g) C:\AutoKitting\フォルダを削除"
if (Test-Path "C:\Get-Files.bat") {
  Remove-Item "C:\Get-Files.bat" -Recurse
}
if (Test-Path "C:\Config.json") {
  Remove-Item "C:\Config.json" -Recurse
}


# シリアル取得
$serialNo = (Get-WmiObject Win32_ComputerSystemProduct).IdentifyingNumber | Out-String

# MACアドレス取得
$macAddress =  Get-NetAdapter | ForEach-Object{"`r`n$($_.Name) : $($_.MacAddress)"}

$compliteMsg = @"
[$($config.pcname)] キッティング完了！
シリアル番号： $($serialNo)
MACアドレス： $($macAddress)
詳細ログは対象PCの C:\AutoKitting\Kitting.log をご確認ください
"@

# キッティング完了をチャットに通知
Send-Chat $compliteMsg $config.notifier.chat $config.notifier.url $config.notifier.token

# ログ出力終了
Stop-Transcript
