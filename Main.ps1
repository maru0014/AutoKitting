
# ���O�o�͊J�n
Start-Transcript "$PSScriptRoot/Kitting.log" -append

Write-Host @"
*********************************************************
*
* Windows10 Auto Kitting Script / Main.ps1
* �o�[�W���� : 1.00
* �ŏI�X�V�� : 2020/04/15
*
"@ -ForeGroundColor green

Write-Host "$(Date -Format g) ���s���̃��[�U : " $env:USERNAME

# �ݒ�t�@�C���̓ǂݍ���
Write-Host "$(Date -Format g) �ݒ�t�@�C���ǂݍ��� : $($PSScriptRoot)/Config.json"
$config = Get-Content "$PSScriptRoot/Config.json" -Encoding UTF8 | ConvertFrom-Json

# �֐��̓ǂݍ���
Write-Host "$(Date -Format g) �֐��t�@�C���ǂݍ��� : $($PSScriptRoot)/Functions.ps1"
. $PSScriptRoot/Functions.ps1

# PC����`�iGet-Files.bat�ɂ����PC�����ݒ肳�ꂽ�ꍇ��C:/pcname.txt�̖��O���g�p�j
if (Test-Path "C:/Config.json") {
  $pcname = (Get-Content "$PSScriptRoot/Config.json" -Encoding UTF8 | ConvertFrom-Json).pcname
}
else {
  $pcname = $config.pcname
}

# ���[�U�ϐ���`
$setupUserName = $config.setupuser.name
$setupUserPass = $config.setupuser.pass
if ($config.joinDomain) {
  $userName = $config.domainUser.name
  $userPass = $config.domainUser.pass
}
else {
  $userName = $config.localUser.name
  $userPass = $config.localUser.pass
}


# �ݒ�l�̍ŏI�m�F
Write-Host "`r`n********************** �ݒ�l�m�F ***********************" -ForeGroundColor green
Write-Host @"
�R���s���[�^���@�@�@: $($pcname)
�Z�b�g�A�b�v���[�U�@: $($setupUserName)
���p�҃��[�U�@�@�@�@: $($userName)
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
Enable-AutoLogon $setupUserName $setupUserPass

# �^�X�N�����o�^�Ȃ�X�P�W���[���Ƀ��O�I���X�N���v�g��o�^
Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $setupUserName $setupUserPass

# �R���s���[�^�����ݒ�l�ƈقȂ�ꍇ�͕ύX
if ($Env:COMPUTERNAME -ne $pcname) {
  Write-Host "$(Date -Format g) �R���s���[�^����ύX���čċN�����܂�"
  Rename-Computer -NewName $pcname -Force -Restart
  Exit
}
else {
  Write-Host "$(Date -Format g) �R���s���[�^���͕ύX�ς݂ł�" -ForeGroundColor yellow
  Write-Host "$(Date -Format g) �R���s���[�^�� : " $Env:COMPUTERNAME -ForeGroundColor yellow
}


# 1�x�������s
if (-Not (Test-Path "$PSScriptRoot/onlyOnce1")) {

	New-Item "$PSScriptRoot/onlyOnce1"

	# �����[�g�f�X�N�g�b�v�L��/����
	$remoteDesktopStatus = Get-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections"
	if ($config.enableRemoteDesktop -and ($remoteDesktopStatus -ne 0)) {
	  Write-Host "$(Date -Format g) �����[�g�f�X�N�g�b�v�L����"
	  Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 0
	}
	elseif($remoteDesktopStatus -ne 1){
	  Write-Host "$(Date -Format g) �����[�g�f�X�N�g�b�v������"
	  Set-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" "fDenyTSConnections" "DWord" 1
	}

	# Windows Defender������
	$DefenderStatus = Get-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"
	if ($config.desableDefender -and ($DefenderStatus -ne 1)) {
	  Write-Host "$(Date -Format g) Windows Defender������"
	  Set-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware" "DWord" 1
	}

	# SNP������
	((Get-NetTCPSetting).AutoTuningLevelLocal).Contains("Disabled")
	if ($config.network.desableSnp) {
	  Write-Host "$(Date -Format g) SNP������"
	  Set-NetTCPSetting -AutoTuningLevelLocal Disabled
	}

	# �X���[�v������
	if ($config.desableSleep) {
	  Write-Host "$(Date -Format g) �X���[�v������"
	  powercfg /x /standby-timeout-ac 0
	}

	# �x�~��Ԗ�����
	if ($config.desableHibernate) {
	  Write-Host "$(Date -Format g) �x�~��Ԗ�����"
	  powercfg /x /hibernate-timeout-ac 0
	}

}

if ($config.upgradeWindows) {
  $winver = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ReleaseId).ReleaseId
  if ($winver -ne "1909") {
    # Win10 1909���C���X�g�[��
    Write-Host "$(Date -Format g) Windows10 $($winver) �� 1909�A�b�v�O���[�h���s"
    Start-Process -FilePath ($PSScriptRoot + "/Applications/1909/setup.exe") -argumentList "/Auto Upgrade" -Wait
  }else {
    Write-Host "$(Date -Format g) Windows10 $($winver)"
  }
}

Write-Host "`r`n***************** �ŐV�܂�Windows Update *****************" -ForeGroundColor green
Run-WindowsUpdate


Write-Host "`r`n************* �A�v���P�[�V�����̃C���X�g�[�� *************" -ForeGroundColor green

# Config��apps�ȉ��z������Ƀ`�F�b�N���ăC���X�g�[��
foreach ($app in $config.apps) {
  if (-not(Test-Path $app.checkFilePath)) {
    Write-Host "$(Date -Format g) $($app.name)���C���X�g�[��" -NoNewLine

    # ��������/�Ȃ� �ŕ��򂵂ăC���X�g�[�������s
    if ($app.Argument -eq "") {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }
    else {
      $installing = Start-Process -FilePath ($PSScriptRoot + $app.installerPath) -argumentList $app.Argument -WorkingDirectory ($PSScriptRoot + $app.workingDirectory) -PassThru
    }

    # �C���X�g�[��������ҋ@�i�^�C���A�E�g�ݒ莞�ԂɒB������҂����ɐi�ށj
    Wait-Process -InputObject $installing -Timeout $app.timeout

    # �C���X�g�[���������`�F�b�N
    if (Test-Path $app.checkFilePath) {
      Write-Host "...����"
    }else{
      Write-Host "...���s"
      # �`���b�g�ŃC���X�g�[�����s��ʒm
      Send-Chat "[$($config.pcname)] $($app.name)�̃C���X�g�[���Ɏ��s���܂���" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken
    }

    # onlyOnce(1�񂾂����s����) �� true �̏ꍇ�� �t���O�t�@�C�����쐬����
    # 2��ڈȍ~���X�L�b�v���邽�߂ɂ�Config.json��checkFilePath���t���O�t�@�C���̖��O�ɂ���K�v����
    if (($app.onlyOnce) -And (-Not (Test-Path "$PSScriptRoot/$($app.name)"))) {
      New-Item "$PSScriptRoot/$($app.name)"
    }
  } else {
    Write-Host "$(Date -Format g) $($app.name)�̓C���X�g�[���ς݂ł�"
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
	  Write-Host "$(Date -Format g) �Œ�IP�A�h���X��ݒ�"
	  Get-NetAdapter | New-NetIPAddress -AddressFamily IPv4 -IPAddress $config.network.staticIP.address -PrefixLength $config.network.staticIP.prefixLength -DefaultGateway $config.network.staticIP.gateway
	}

	# IPv6������
	if ($config.network.disableIPv6) {
	  Write-Host "$(Date -Format g) IPv6�𖳌���"
	  Get-NetAdapter | Disable-NetAdapterBinding -ComponentID ms_tcpip6
	  Get-NetAdapter | Get-NetAdapterBinding -ComponentID ms_tcpip6
	}

	# DNS�ݒ�
	if ($config.network.dns -ne "") {
	  Write-Host "$(Date -Format g) DNS�ݒ�"
	  Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $config.network.dns
	}

	# DNS�T�t�B�b�N�X�ݒ�
	if ($config.network.dnsSuffix.Count -gt 0) {
	  Write-Host "$(Date -Format g) DNS�T�t�B�b�N�X�ݒ�"
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
  $Password = Decryption-Password "$($PSScriptRoot)/Password/key.txt" "$($PSScriptRoot)/Password/encrypted.txt"
  cmd /C net user administrator $StringPassword /active:yes

}


# ���[�J�����[�U���ݒ肳��Ă��āA���݂��Ȃ��ꍇ�쐬
if(($config.localUser.name -ne "") -And (-not(Test-User $config.localUser.name))) {

  Write-Host "`r`n*************** ���p�҃��[�J�����[�U�̍쐬 ***************" -ForeGroundColor green
  # ���[�U�쐬
  Create-User $config.localUser.name $config.localUser.pass

  # �p�X���[�h�������ݒ�
  if ($config.localUser.dontExpirePassword) {
    DontExpire-Password $userName
  }

  # ���[�J���O���[�v�ɒǉ�
  foreach ($Group in $config.localUser.localGroup) {
    Write-Host "$(Date -Format g) ���[�U�[$($config.localUser.name) �����[�J���O���[�v�ɒǉ�$($Group)"
    Add-LocalGroupMember -Group $Group -Member $config.localUser.name
  }
}


# �h���C���Q��:true & �h���C�����Q�� �̏ꍇ�͎��s
if ($config.joinDomain -And ($config.domain.address -ne (Get-WmiObject Win32_ComputerSystem).domain) ) {

  Write-Host "`r`n*************** ���p�҃��[�U�Ńh���C���Q�� ***************" -ForeGroundColor green
  try {
    $result = Join-Domain $config.domain.name $config.domainUser.name $config.domainUser.pass $config.domainUser.ouPath
  }
  catch {
    # �h���C���Q�����s��ʒm
    Send-Chat "[$($config.pcname)] �h���C���Q���Ɏ��s���܂����BConfig.json���C�����čċN�����Ă��������B$($result)" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken
    Write-Host "$(Date -Format g) �h���C���Q���Ɏ��s���܂����BConfig.json���C�����čċN�����Ă��������B"
    Pause
    Exit
  }
    # ���p�҃��[�U�����[�J���O���[�v�ɒǉ�
    foreach ($Group in $config.domainUser.localGroup) {
      Write-Host "`r`n************** ���p�҃��[�U���O���[�v�ɒǉ� **************" -ForeGroundColor green
      if (-Not(Test-MemberDomainAccunt $config.domain.name $userName $Group)) {
        Write-Host "$(Date -Format g) ���[�U�[$($userName)�����[�J���O���[�v�ɒǉ�$($Group)"
        net localgroup $Group "$($config.domain.name)\$($config.domainUser.name)" /ADD
        # Join-ADUser2Group $config.domain.name $config.domainUser.name $Group
      }
    }

    Write-Host "$(Date -Format g) �ċN��"
    Restart-Computer -Force
    Exit

}


# �쐬�������[�U�Ŏ������O�I���ݒ�
if ($env:USERNAME -ne $userName) {
  Write-Host "`r`n************* ���p�҃��[�U�Ŏ������O�I���ݒ� *************" -ForeGroundColor green
  Write-Host "$(Date -Format g) �Z�b�g�A�b�v���[�U�̃��O�I���X�N���v�g������"
  Remove-Task "AutoKitting"

  Write-Host "$(Date -Format g) ���p�҃��[�U�̃��O�I���X�N���v�g��ݒ�"
  if ($config.joinDomain) {
    Enable-AutoLogon $userName $userPass $config.domain.name
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" "$($config.domain.name)\$($userName)" $userPass
  }
  else {
    Enable-AutoLogon $userName $userPass
    Register-Task "AutoKitting" "$PSScriptRoot\Run-PS.bat" $userName $userPass
  }

  Write-Host "$(Date -Format g) �ċN��"
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
  foreach($KP in $BLV.KeyProtector){
    if ($BLV.KeyProtectorType -eq "RecoveryPassword") {
      Remove-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $KP.KeyProtectorId
    }
  }

  if ($config.bitLocker.saveRecoveryPassInAD) {
    # AD�ւ̉񕜃p�X���[�h�ۑ���L����
    Enable-SaveRecoveryPassInAD

    # �񕜃p�X���[�h��ݒ�
    Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
    $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).KeyProtectorId

    # AD�ɉ񕜃p�X���[�h��ۑ�
    Backup-BitLockerKeyProtector -MountPoint "C:" -KeyProtectorId $kpid
  }

  # Password�ݒ肪�L�� �ꍇ�͎��s
  if ($config.bitLocker.password ) {
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

  }else{
    manage-bde -on C:
  }

    # �`���b�g�Ńv���e�N�^ID�Ɖ񕜃p�X���[�h��ʒm
    $kpid = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).KeyProtectorId | Out-String
    $rp = ((Get-BitLockerVolume -MountPoint "C:").keyProtector | Where-Object {$_.KeyProtectorType -eq 'RecoveryPassword'}).RecoveryPassword | Out-String
    Send-Chat "[$($config.pcname)] BitLocker`r`n�v���e�N�^ID�F $($kpid)`r`n�񕜃p�X���[�h�F $($rp)" $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken

}


if ($config.setupUser.delete) {
  Write-Host "`r`n**************** �Z�b�g�A�b�v���[�U�̍폜 ****************" -ForeGroundColor green

  # ���[�U�폜
  Write-Host "$(Date -Format g) $($setupUserName)���폜"
  Remove-LocalUser -Name $setupUserName

  # ���[�U�v���t�@�C���폜
  $GetUserQuery = 'select * from win32_userprofile where LocalPath="C:\\Users\\' + $setupUserName + '"'
  Get-WmiObject -Query $GetUserQuery | Remove-WmiObject
}

# Task���폜
if (Test-Task "AutoKitting") {
  Remove-Task "AutoKitting"
  Write-Host "$(Date -Format g) ���O�I���X�N���v�g������"
}

# �������O�I��������
Disable-AutoLogon

# kitting.log �ȊO�� AutoKitting�t�H���_�z�����폜
Remove-Item C:\AutoKitting\* -Exclude kitting.log -Recurse
Write-Host "$(Date -Format g) C:\AutoKitting\�t�H���_���폜"
if (Test-Path "C:\Get-Files.bat") {
  Remove-Item "C:\Get-Files.bat" -Recurse
}
if (Test-Path "C:\pcname.txt") {
  Remove-Item "C:\pcname.txt" -Recurse
}


# �V���A���擾
$serialNo = (Get-WmiObject Win32_ComputerSystemProduct).IdentifyingNumber | Out-String

# MAC�A�h���X�擾
$macAddress =  Get-NetAdapter | ForEach-Object{"`r`n$($_.Name) : $($_.MacAddress)"}

$compliteMsg = @"
[$($config.pcname)] �L�b�e�B���O�����I
�V���A���ԍ��F $($serialNo)
MAC�A�h���X�F $($macAddress)
�ڍ׃��O�͑Ώ�PC�� C:\AutoKitting\Kitting.log �����m�F��������
"@

# �L�b�e�B���O�������`���b�g�ɒʒm
Send-Chat $compliteMsg $config.notifier.chat $config.notifier.url $config.notifier.slackUser $config.notifier.cwToken

# ���O�o�͏I��
Stop-Transcript
