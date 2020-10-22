
# ���O�o�͊J�n
Start-Transcript "$PSScriptRoot/Kitting.log" -append

Write-Host @"
*********************************************************
*
* Windows10 Auto Kitting Script / Main.ps1
* �o�[�W���� : 1.20
* �ŏI�X�V�� : 2020/10/22
*
"@ -ForeGroundColor green

Write-Host "$(Get-Date -Format g) ���s���̃��[�U : " $env:USERNAME

# �ݒ�t�@�C���̓ǂݍ���
Write-Host "$(Get-Date -Format g) �ݒ�t�@�C���ǂݍ��� : $($PSScriptRoot)/Config.json"
$config = Get-Content "$PSScriptRoot/Config.json" -Encoding UTF8 | ConvertFrom-Json

# �֐��̓ǂݍ���
Write-Host "$(Get-Date -Format g) �֐��t�@�C���ǂݍ��� : $($PSScriptRoot)/Functions.ps1"
. $PSScriptRoot/Functions.ps1

# PC����`�iGet-Files.bat�ɂ����PC�����ݒ肳�ꂽ�ꍇ��C:/pcname.txt�̖��O���g�p�j
if (Test-Path "C:/Config.json") {
  $pcname = (Get-Content "C:/Config.json" -Encoding UTF8 | ConvertFrom-Json).pcname
}
else {
  $pcname = $config.pcname
}


# �ݒ�l�̍ŏI�m�F
Write-Host "`r`n********************** �ݒ�l�m�F ***********************" -ForeGroundColor green
Write-Host @"
�R���s���[�^���@�@�@: $($pcname)
�Z�b�g�A�b�v���[�U�@: $($config.setupuser.name)
�h���C���Q���@�@�@�@: $($config.joinDomain)
Administrator�L���� : $($config.enableAdministrator)
BitLocker�L���� �@�@: $($config.bitLocker.flag)
RDP�L���� �@�@�@�@�@: $($config.enableRemoteDesktop)
Defender�������@�@�@: $($config.disableWinDefender)
�X���[�v�������@�@�@: $($config.desableSleep)
�x�~��Ԗ������@�@�@: $($config.desableHibernate)
IP�A�h���X�Œ�@�@�@: $($config.network.staticIP.flag)
SNP������ �@�@�@�@�@: $($config.network.desableSnp)
IPv6�������@�@�@�@�@: $($config.network.disableIPv6)

�C���X�g�[������A�v���P�[�V���� :
"@ -ForeGroundColor Yellow

foreach ($app in $config.apps) {
  Write-Host $app.name -ForeGroundColor yellow
}


Write-Host "`r`n******************* �V�X�e�����̕ύX *******************" -ForeGroundColor green

# �������O�I�����ݒ�̏ꍇ�͐ݒ肷��
Enable-AutoLogon $config.setupuser.name $config.setupuser.pass

# �^�X�N�����o�^�Ȃ�X�P�W���[���Ƀ��O�I���X�N���v�g��o�^
Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $config.setupuser.name $config.setupuser.pass

# �R���s���[�^�����ݒ�l�ƈقȂ�ꍇ�͕ύX
if ($Env:COMPUTERNAME -ne $pcname) {
  Write-Host "$(Get-Date -Format g) �R���s���[�^����ύX���čċN�����܂�"
  Rename-Computer -NewName $pcname -Force -Restart
  Exit
}
else {
  Write-Host "$(Get-Date -Format g) �R���s���[�^���͕ύX�ς݂ł�" -ForeGroundColor yellow
  Write-Host "$(Get-Date -Format g) �R���s���[�^�� : " $Env:COMPUTERNAME -ForeGroundColor yellow
}


# 1�x�������s
if (-Not (Test-Path "$PSScriptRoot/onlyOnce1")) {

  New-Item "$PSScriptRoot/onlyOnce1"

  # �����[�g�f�X�N�g�b�v�L��/����
  $remoteDesktopStatus = Get-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections"
  if ($config.enableRemoteDesktop -and ($remoteDesktopStatus -ne 0)) {
    Write-Host "$(Get-Date -Format g) �����[�g�f�X�N�g�b�v�L����"
    Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 0
  }
  elseif (-Not($config.enableRemoteDesktop) -and $remoteDesktopStatus -ne 1) {
    Write-Host "$(Get-Date -Format g) �����[�g�f�X�N�g�b�v������"
    Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 1
  }

  # Windows Defender������
  $DefenderStatus = Get-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"
  if ($config.desableDefender -and ($DefenderStatus -ne 1)) {
    Write-Host "$(Get-Date -Format g) Windows Defender������"
    Set-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" "DWord" 1
  }

  # SNP������
  ((Get-NetTCPSetting).AutoTuningLevelLocal).Contains("Disabled")
  if ($config.network.desableSnp) {
    Write-Host "$(Get-Date -Format g) SNP������"
    Set-NetTCPSetting -AutoTuningLevelLocal Disabled
  }

  # �d���ݒ�t�@�C���̃C���|�[�g
  if ($config.importPowFile -ne "") {
    Write-Host "�d���ݒ�t�@�C�����C���|�[�g�F $($PSScriptRoot)$($config.importPowFile)"
    $powercfgResult = cmd /C powercfg /import "$($PSScriptRoot)$($config.importPowFile)"
    Write-Host $powercfgResult
    $guid = $powercfgResult -replace '.+: ', ''
    Write-Host $guid
    cmd /C powercfg /setactive $guid
  }

  # �X���[�v������
  if ($config.desableSleep) {
    Write-Host "$(Get-Date -Format g) �X���[�v������"
    powercfg /x /standby-timeout-ac 0
  }

  # �x�~��Ԗ�����
  if ($config.desableHibernate) {
    Write-Host "$(Get-Date -Format g) �x�~��Ԗ�����"
    powercfg /x /hibernate-timeout-ac 0
  }

  # # Windows Update ���� .NET Framework 3.5 �̋@�\�t�@�C�����C���X�g�[��
  # dism /online /Enable-Feature /FeatureName:NetFx3
}

if ($config.upgradeWindows.flag) {
  $winver = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
  if ($config.upgradeWindows.ver -gt $winver) {
    Write-Host "`r`n***************** Windows 10 �X�V�A�V�X�^���g���s *****************" -ForeGroundColor green
    $dir = 'C:\AutoWinUpdate\_Windows_FU\packages'
    if (-not (Test-Path $dir)) {
      # ��Ɨp�t�H���_�쐬
      mkdir $dir

      # Window10�X�V�A�V�X�^���g���_�E�����[�h
      $webClient = New-Object System.Net.WebClient
      $url = 'https://go.microsoft.com/fwlink/?LinkID=799445'
      $file = "$($dir)\Win10Upgrade.exe"
      $webClient.DownloadFile($url, $file)

      # �T�C�����g�C���X�g�[��
      Start-Process -FilePath $file -ArgumentList '/skipeula /auto upgrade /UninstallUponUpgrade' -Wait
      Exit
    }
  }
}

Write-Host "`r`n***************** �ŐV�܂�Windows Update *****************" -ForeGroundColor green
if(-not (Get-Module -ListAvailable -Name PSWindowsUpdate)){
  Install-PackageProvider -Name NuGet -Force
  Install-Module -Name PSWindowsUpdate -Force
}
Import-Module -Name PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot


Write-Host "`r`n************* �A�v���P�[�V�����̃C���X�g�[�� *************" -ForeGroundColor green

# Config��apps�ȉ��z������Ƀ`�F�b�N���ăC���X�g�[��
foreach ($app in $config.apps) {
  if (-not(Test-Path $app.checkFilePath)) {
    Write-Host "$(Get-Date -Format g) $($app.name)���C���X�g�[��" -NoNewLine

    # ��������/�Ȃ� �ŕ��򂵂ăC���X�g�[�������s
    if ($app.Argument -eq "") {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }
    else {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -argumentList $app.Argument -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }

    # �C���X�g�[��������ҋ@�i�^�C���A�E�g�ݒ莞�ԂɒB������҂����ɐi�ށj
    Wait-Process -InputObject $installing -Timeout $app.timeout
    Start-Sleep -s 30

    # �C���X�g�[���������`�F�b�N
    if (Test-Path $app.checkFilePath) {
      Write-Host "...����"
    }
    else {
      Write-Host "...���s"
      # �`���b�g�ŃC���X�g�[�����s��ʒm
      Send-Chat "[$($pcname)] $($app.name)�̃C���X�g�[���Ɏ��s���܂���" $config.notifier.chat $config.notifier.url $config.notifier.token
    }

    # onlyOnce(1�񂾂����s����) �� true �̏ꍇ�� �t���O�t�@�C�����쐬����
    # 2��ڈȍ~���X�L�b�v���邽�߂ɂ�Config.json��checkFilePath���t���O�t�@�C���̖��O�ɂ���K�v����
    if (($app.onlyOnce) -And (-Not (Test-Path "$PSScriptRoot/$($app.name)"))) {
      New-Item "$PSScriptRoot/$($app.name)"
    }
  }
  else {
    Write-Host "$(Get-Date -Format g) $($app.name)�̓C���X�g�[���ς݂ł�"
  }
}


# 1�x�������s
if (-Not (Test-Path "$PSScriptRoot/onlyOnce2")) {

  New-Item "$PSScriptRoot/onlyOnce2"

  if ($config.defaultDesktop) {
    Write-Host "`r`n*********** Default���[�U�̃f�X�N�g�b�v��ݒ� ************" -ForeGroundColor green
    cmd /C xcopy "$($PSScriptRoot)\Desktop" "C:\Users\Default\Desktop\" /D /Y /E
  }

  if ($config.defaultAppAssoc) {
    Write-Host "`r`n****************** ����̃A�v����ݒ� *******************" -ForeGroundColor green
    Dism.exe /Online /Import-DefaultAppAssociations:$PSScriptRoot\AppAssoc.xml
  }


  Write-Host "`r`n******************** �l�b�g���[�N�ݒ� ********************" -ForeGroundColor green

  # �Œ�IP�A�h���X
  if ($config.network.staticIP.flag) {
    Write-Host "$(Get-Date -Format g) �Œ�IP�A�h���X��ݒ�"
    Get-NetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $config.network.staticIP.address -PrefixLength $config.network.staticIP.prefixLength -DefaultGateway $config.network.staticIP.gateway
  }

  # IPv6������
  if ($config.network.disableIPv6) {
    Write-Host "$(Get-Date -Format g) IPv6�𖳌���"
    Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6
    Get-NetAdapter | Get-NetAdapterBinding -ComponentID ms_tcpip6
  }

  # DNS�ݒ�
  if ($config.network.dns -ne "") {
    Write-Host "$(Get-Date -Format g) DNS�ݒ�"
    Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $config.network.dns
  }

  # DNS�T�t�B�b�N�X�ݒ�
  if ($config.network.dnsSuffix.Count -gt 0) {
    Write-Host "$(Get-Date -Format g) DNS�T�t�B�b�N�X�ݒ�"
    $suffixlist = $adapter.DNSDomainSuffix.SearchOrder
    if ($suffix -eq "") {
      $suffixlist = $config.network.dnsSuffix
    }
    else {
      $suffixlist += ",$($config.network.dnsSuffix)"
    }
    Invoke-WmiMethod -class win32_networkadapterconfiguration -Name SetDNSSuffixSearchOrder -ArgumentList @($suffixlist) , $null
  }
  # �L���ȃA�_�v�^�[���Ƃ̐ݒ�l���o��
  Get-WmiObject Win32_NetworkAdapterConfiguration -filter "ipenabled = 'true'"


  # �s�v�ȃA�v���̍폜
  if ($config.runUninstallApps) {
    Write-Host "`r`n******** �s�v�ȃA�v���P�[�V�����̃A���C���X�g�[�� ********" -ForeGroundColor green
    . $PSScriptRoot\Uninstall-Apps.ps1
  }
}


# Administrator �L����
if ($config.enableAdministrator -and (-Not(Get-LocalUser Administrator).Enabled)) {

  Write-Host "`r`n******************** Administrator�ݒ� ********************" -ForeGroundColor green
  $StringPassword = Decryption-Password "$($PSScriptRoot)/Password/key.txt" "$($PSScriptRoot)/Password/encrypted.txt"
  cmd /C net user administrator $StringPassword /active:yes

}


# ���[�J�����[�U���ݒ肳��Ă��āA���݂��Ȃ��ꍇ�쐬
if (($config.localUser.name -ne "") -And (-not(Test-User $config.localUser.name))) {

  Write-Host "`r`n*************** ���p�҃��[�J�����[�U�̍쐬 ***************" -ForeGroundColor green
  # ���[�U�쐬
  if ($config.localUser.pass -eq "****") {
    $localUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-01.txt" "$($PSScriptRoot)/Password/encrypted-01.txt"
  }
  else {
    $localUserPass = $config.localUser.pass
  }
  Create-User $config.localUser.name $localUserPass

  # �p�X���[�h�������ݒ�
  if ($config.localUser.dontExpirePassword) {
    DontExpire-Password $config.localUser.name
  }

  # ���[�J���O���[�v�ɒǉ�
  foreach ($Group in $config.localUser.localGroup) {
    Write-Host "$(Get-Date -Format g) ���[�U�[$($config.localUser.name) �����[�J���O���[�v�ɒǉ�$($Group)"
    Add-LocalGroupMember -Group $Group -Member $config.localUser.name
  }
}


# �h���C���Q��:true & �h���C�����Q�� �̏ꍇ�͎��s
if ($config.joinDomain -And ($config.domain.address -ne (Get-WmiObject Win32_ComputerSystem).domain) ) {

  Write-Host "`r`n*************** ���p�҃��[�U�Ńh���C���Q�� ***************" -ForeGroundColor green
  try {
    if ($config.domainUser.pass -eq "****") {
      $domainUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-02.txt" "$($PSScriptRoot)/Password/encrypted-02.txt"
    }
    else {
      $domainUserPass = $config.domainUser.pass
    }
    $result = Join-Domain $config.domain.name $config.domainUser.name $domainUserPass $config.domainUser.ouPath
  }
  catch {
    # �h���C���Q�����s��ʒm
    Send-Chat "[$($pcname)] �h���C���Q���Ɏ��s���܂����BConfig.json���C�����čċN�����Ă��������B$($result)" $config.notifier.chat $config.notifier.url $config.notifier.token
    Write-Host "$(Get-Date -Format g) �h���C���Q���Ɏ��s���܂����BConfig.json���C�����čċN�����Ă��������B"
    Pause
    Exit
  }
  # ���p�҃��[�U�����[�J���O���[�v�ɒǉ�
  foreach ($Group in $config.domainUser.localGroup) {
    Write-Host "`r`n************** ���p�҃��[�U���O���[�v�ɒǉ� **************" -ForeGroundColor green
    if (-Not(Test-MemberDomainAccunt $config.domain.name $config.domainUser.name $Group)) {
      Write-Host "$(Get-Date -Format g) ���[�U�[$($config.domainUser.name)�����[�J���O���[�v�ɒǉ�$($Group)"
      net localgroup $Group "$($config.domain.name)\$($config.domainUser.name)" /ADD
      # Join-ADUser2Group $config.domain.name $config.domainUser.name $Group
    }
  }
  # �h���C�����[�U���ꎞ�I��Administrators�ɒǉ�
  if (-Not(Test-MemberDomainAccunt $config.domain.name $userName "Administrators")) {
    net localgroup "Administrators" "$($config.domain.name)\$($config.domainUser.name)" /ADD
  }
  # Write-Host "$(Get-Date -Format g) �ċN��"
  # Restart-Computer -Force
  # Exit

}


# �쐬�������[�U�Ŏ������O�I���ݒ�
if ($env:USERNAME -eq $config.setupuser.name) {
  Write-Host "`r`n************* ���p�҃��[�U�Ŏ������O�I���ݒ� *************" -ForeGroundColor green
  Write-Host "$(Get-Date -Format g) �Z�b�g�A�b�v���[�U�̃��O�I���X�N���v�g������"
  Remove-Task "AutoKitting"

  Write-Host "$(Get-Date -Format g) ���p�҃��[�U�̃��O�I���X�N���v�g��ݒ�"
  if ($config.joinDomain) {
    if ($config.domainUser.pass -eq "****") {
      $domainUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-02.txt" "$($PSScriptRoot)/Password/encrypted-02.txt"
    }
    else {
      $domainUserPass = $config.domainUser.pass
    }
    Enable-AutoLogon $config.domainUser.name $config.domainUser.pass $config.domain.name
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" "$($config.domain.name)\$($config.domainUser.name)" $domainUserPass
  }
  else {
    if ($config.localUser.pass -eq "****") {
      $localUserPass = Decryption-Password "$($PSScriptRoot)/Password/key-01.txt" "$($PSScriptRoot)/Password/encrypted-01.txt"
    }
    else {
      $localUserPass = $config.localUser.pass
    }
    Enable-AutoLogon $config.localUser.name $localUserPass
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $config.localUser.name $localUserPass
  }

  Write-Host "$(Get-Date -Format g) �ċN��"
  Restart-Computer -Force
  Exit
}


if ($config.deleteTaskbarUWPApps) {
  Write-Host "`r`n******** �^�X�N�o�[�� Edge/Store/���[�� ���폜 ********" -ForeGroundColor green
  # �^�X�N�o�[�� Edge/Store/���[�� ���폜
  . $PSScriptRoot\Delete-TaskbarUWPApps.ps1
}

if ($config.network.drive -ne "") {
  Write-Host "`r`n************* �l�b�g���[�N�h���C�u�̊��蓖�� *************" -ForeGroundColor green
  foreach ($drive in $config.network.drive) {
    Add-NetworkDrive $drive.name $drive.path $drive.user $drive.pass
  }
}

# BitLocker��L��������ݒ肩�Í�������Ă��Ȃ��ꍇ�͎��s
$BLV = Get-BitLockerVolume -MountPoint "C:"
$EncryptedFlag = $BLV.ProtectionStatus -eq "off"

if ($config.bitlocker.flag -And $EncryptedFlag) {
  Write-Host "`r`n******************** Bitlocker�̗L���� ********************" -ForeGroundColor green

  # ������KeyProtector���폜
  foreach ($KP in $BLV.KeyProtector) {
    if ($KP.KeyProtectorType -eq "RecoveryPassword") {
      Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KP.KeyProtectorId
    }
  }

  # �񕜃p�X���[�h��ݒ�
  Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector

  # TpmProtector�����݂��Ȃ��ꍇ�͍쐬
  $TpmKP = $BLV.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'Tpm' }
  if (-Not $TpmKP) {
    Add-BitLockerKeyProtector -MountPoint "C:" -TpmProtector
  }

  if ($config.bitLocker.saveRecoveryPassInAD) {

    # AD�ւ̉񕜃p�X���[�h�ۑ���L����
    Enable-SaveRecoveryPassInAD

    $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId

    # AD�ɉ񕜃p�X���[�h��ۑ�
    Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $kpid
  }

  # Password�ݒ肪�L�� �ꍇ�͎��s
  if ($config.bitLocker.password -ne "") {
    # �X�^�[�g�A�b�v�� �g��PIN�ɂ��F�؂�ݒ�
    Enable-StartupPin

    # �p�X���[�h��SecureString�ɕϊ�
    $bitLockerPass = ConvertTo-SecureString $config.bitLocker.password -AsPlainText -Force

    if ((Get-Tpm).TpmPresent) {
      # �g��PIN��ݒ肵��BitLocker��L����
      Enable-BitLocker -MountPoint "C:" -TpmAndPinProtector $bitLockerPass -UsedSpaceOnly -skiphardwaretest
    }
    else {
      # �L����TPM���Ȃ��ꍇ��PasswordProtector�ŗL����
      Enable-BitLocker -MountPoint "C:" -PasswordProtector $bitLockerPass -UsedSpaceOnly -skiphardwaretest
    }

  }
  else {
    # �X�^�[�g�A�b�v����PIN���͂Ȃ��ŗL����
    manage-bde -on C: -skiphardwaretest
  }

  # �`���b�g�Ńv���e�N�^ID�Ɖ񕜃p�X���[�h��ʒm
  $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId | Out-String
  $rp = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword | Out-String
  Send-Chat "[$($pcname)] BitLocker`r`n�v���e�N�^ID�F $($kpid)`r`n�񕜃p�X���[�h�F $($rp)" $config.notifier.chat $config.notifier.url $config.notifier.token

}

# �h���C�����[�U��Administrators����폜
if (-Not ($config.domainUser.localGroup).Contains("Administrators")) {
  if (-Not (Test-MemberDomainAccunt $config.domain.name $userName "Administrators")) {
    net localgroup "Administrators" "$($config.domain.name)\$($config.domainUser.name)" /DELETE
  }
}

if ($config.setupUser.delete) {
  Write-Host "`r`n**************** �Z�b�g�A�b�v���[�U�̍폜 ****************" -ForeGroundColor green

  # ���[�U�폜
  Write-Host "$(Get-Date -Format g) $($config.setupuser.name)���폜"
  Remove-LocalUser -Name $config.setupuser.name

  # ���[�U�v���t�@�C���폜
  $GetUserQuery = 'select * from win32_userprofile where LocalPath="C:\\Users\\' + $config.setupuser.name + '"'
  Get-WmiObject -Query $GetUserQuery | Remove-WmiObject
}

# Task���폜
if (Test-Task "AutoKitting") {
  Remove-Task "AutoKitting"
  Write-Host "$(Get-Date -Format g) ���O�I���X�N���v�g������"
}

# �������O�I��������
Disable-AutoLogon

# kitting.log �ȊO�� AutoKitting�t�H���_�z�����폜
Remove-Item C:\AutoKitting\* -Exclude kitting.log -Recurse
Write-Host "$(Get-Date -Format g) C:\AutoKitting\�t�H���_���폜"
if (Test-Path "C:\Get-Files.bat") {
  Remove-Item "C:\Get-Files.bat" -Recurse
}
if (Test-Path "C:\Config.json") {
  Remove-Item "C:\Config.json" -Recurse
}

# kitting.log ���J��
Invoke-Item "C:\AutoKitting\kitting.log"

# �V���A���擾
$serialNo = (Get-WmiObject Win32_ComputerSystemProduct).IdentifyingNumber | Out-String

# MAC�A�h���X�擾
$macAddress = Get-NetAdapter | ForEach-Object { "`r`n$($_.Name) : $($_.MacAddress)" }

$compliteMsg = @"
[$($pcname)] �L�b�e�B���O�����I
�V���A���ԍ��F $($serialNo)
MAC�A�h���X�F $($macAddress)
�ڍ׃��O�͑Ώ�PC�� C:\AutoKitting\Kitting.log �����m�F��������
"@

# �L�b�e�B���O�������`���b�g�ɒʒm
Send-Chat $compliteMsg $config.notifier.chat $config.notifier.url $config.notifier.token

# ���O�o�͏I��
Stop-Transcript
