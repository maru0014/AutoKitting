

################################################
# �h���C���ɎQ��
################################################
function Join-Domain($domainName, $userName, $userPass, $ouPath) {
    Write-Host "�h���C�� : $($domainName)" -ForeGroundColor Yellow
    Write-Host "���[�U�[ : $($userName)" -ForeGroundColor Yellow
    # �h���C���Q��
    $pwd = ConvertTo-SecureString -AsPlainText -Force $userPass
    $cred = New-Object System.Management.Automation.PSCredential($userName, $pwd)

    if ($ouPath -ne "") {
        Write-Host "OU : $($ouPath)" -ForeGroundColor Yellow
        return (Add-Computer -DomainName $domainName -OUPath $ouPath -Credential $cred -ErrorAction stop)
    }
    else {
        return (Add-Computer -DomainName $domainName -Credential $cred -ErrorAction stop)
    }
}


################################################
# ���[�U�̑��݃`�F�b�N
################################################
function Test-User($username) {
    $localusers = Get-WmiObject Win32_UserAccount | Where-Object { $_.LocalAccount -eq $true }

    foreach ($user in $localusers) {
        if ($user.name -eq $username) {
            return $true
        }
    }
    return $false
}


################################################
# �������O�I���L����
################################################
function Enable-AutoLogon($LogonUser, $LogonPass, $LogonDomain) {
    <#
    .SYNOPSIS
    Enable AutoLogon
    .DESCRIPTION

    #>
    $AutoAdminLogon = Get-Registry "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "AutoAdminLogon"
    $DefaultUsername = Get-Registry "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" "DefaultUsername"
    if (($AutoAdminLogon -ne 1) -Or ($DefaultUsername -ne $LogonUser)) {
        Write-Host "$(Get-Date -Format g) ���[�U�[$($LogonUser)�̎������O�I����L����"
        $RegLogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -path $RegLogonKey -name "AutoAdminLogon" -value 1
        Set-ItemProperty -path $RegLogonKey -name "DefaultUsername" -value $LogonUser
        Set-ItemProperty -path $RegLogonKey -name "DefaultPassword" -value $LogonPass
        if ($LogonDomain -ne "") {
            Set-ItemProperty -path $RegLogonKey -name "DefaultDomainName" -value $LogonDomain
        }
    }
}


################################################
# �������O�I��������
################################################
function Disable-AutoLogon() {
    <#
    .SYNOPSIS
    Disable AutoLogon
    .DESCRIPTION

    #>
    $RegLogonKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    Set-ItemProperty -path $RegLogonKey -name "AutoAdminLogon" -value 0
    Set-ItemProperty -path $RegLogonKey -name "DefaultUsername" -value ""
    Set-ItemProperty -path $RegLogonKey -name "DefaultPassword" -value ""

}


################################################
# �^�X�N�̑��݃`�F�b�N
################################################
function Test-Task($TaskName) {
    <#
    .SYNOPSIS
    �^�X�N�̑��݃`�F�b�N    .DESCRIPTION
    �^�X�N�����󂯎���ă^�X�N�X�P�W���[�����ɑ��݂��邩�`�F�b�N
    ���݂���ꍇ��$true�A���݂��Ȃ��ꍇ��$false��Ԃ��܂�

    .EXAMPLE
    Test-Task "�������O�I��"

    .PARAMETER TaskName
    String�^�Ń^�X�N�̖��O���w��

    #>

    $Task = $null
    if ((Get-WmiObject Win32_OperatingSystem).version -eq "6.1.7601") {
        $Task = schtasks /query /fo csv | ConvertFrom-Csv | Where-Object { $_."Taskname" -eq $TaskName }
    }
    else {
        $Task = Get-ScheduledTask | Where-Object { $_.TaskName -match $TaskName }
    }

    if ($Task) {
        return $true
    }
    else {
        return $false
    }

}


################################################
# �^�X�N�X�P�W���[���o�^
################################################
function Register-Task($TaskName, $exePath, $TaskExecuteUser, $TaskExecutePass, $visble) {
    if (-not (Test-Task $TaskName)) {
        Write-Host "$(Get-Date -Format g) �^�X�N�X�P�W���[���ɓo�^:$($TaskName)"
        $trigger = New-ScheduledTaskTrigger -AtLogon
        $action = New-ScheduledTaskAction -Execute $exePath
        $principal = New-ScheduledTaskPrincipal -UserID $TaskExecuteUser -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances Parallel
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal
    }
}


################################################
# �^�X�N�X�P�W���[���폜
################################################
function Remove-Task($TaskName) {

    if ((Get-WmiObject Win32_OperatingSystem).version -eq "6.1.7601") {
        schtasks /delete /tn $TaskName
    }
    else {
        Get-ScheduledTask | Where-Object { $_.TaskName -match $TaskName } | Unregister-ScheduledTask -Confirm:$false
    }

    Write-Output "$(Get-Date -Format g) $($TaskName)���^�X�N�X�P�W���[������폜"

}


################################################
# ������Windows�A�b�v�f�[�g���ŐV�܂Ŏ��s
################################################
function Start-WindowsUpdate() {
    $errorMsg = ""
    $errorCount = 0
    $updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"

    # ���p�\�ȍX�V�v���O������0���ɂȂ�܂ŌJ��Ԃ�
    while (($updates.Count -ne 0) -And ($errorCount -lt 2)) {
        Write-Host "$(Get-Date -Format g) $($updates.Count)���̍X�V�v���O���������p�\"

        foreach ($update in $updates) {
            Write-Host "$(Get-Date -Format g) $($update.Title)"
            try {
                Install-WUUpdates -Updates $update -ErrorAction Stop
            }
            catch {
                $errorCount++
                Write-Error $_.Exception
                Write-Host "$(Get-Date -Format g) [Error $($errorCount)] $($update.Title)" -ForegroundColor Yellow
                $errorMsg = $errorMsg + "$(Get-Date -Format g) [�X�V�v���O�����̃C���X�g�[���Ɏ��s] $($update.Title)`r`n"
            }
        }

        if (Get-WUIsPendingReboot) {
            # �ċN�����K�v�ȏꍇ�͍ċN��
            Write-Host "$(Get-Date -Format g) �X�V���������邽�ߍċN�����܂�"
            Restart-Computer -Force
            Exit
        }

        Write-Host "$(Get-Date -Format g) �X�V�v���O�������ă`�F�b�N"
        $updates = Start-WUScan

    }

    if ($errorCount -eq 2) {
        return $errorMsg
    }
    else {
        return "Windows Update ����"
    }

}


################################################
# ������Windows�A�b�v�f�[�g���ŐV�܂Ŏ��s(���K�V�[)
################################################
function Run-LegacyWindowsUpdate($Option) {

    # �ő�K�p�X�V��
    $G_MaxUpdateNumber = 100

    Write-Host "$(Get-Date -Format g) --- Running Windows Update ---"
    Write-Host "$(Get-Date -Format g) �X�V�v���O�������m�F..."
    $updateSession = new-object -com "Microsoft.Update.Session"
    $updateSearcher = $updateSession.CreateupdateSearcher()

    # �A�b�v�f�[�g�^�C�v�R���g���[��
    if ( $Option -match "ful" ) {
        Write-Host "$(Get-Date -Format g) Type: Full Update"
        $Option = "Full"
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
    }
    else {
        Write-Host "$(Get-Date -Format g) Type: Minimum Update"
        $Option = "Minimum"
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and AutoSelectOnWebSites=1")
    }


    Write-Host "$(Get-Date -Format g) ���p�\�ȍX�V�v���O����:"
    if ($searchResult.Updates.Count -eq 0) {
        Write-Host "$(Get-Date -Format g) ���p�\�ȍX�V�v���O�����͂���܂���"
        Write-Host "$(Get-Date -Format g) Windows Update ����"
    }
    else {
        $downloadReq = $False
        $i = 0
        foreach ($update in $searchResult.Updates) {
            $i++
            if ( $update.IsDownloaded ) {
                $UpdateTitol = $update.Title
                Write-Host "$(Get-Date -Format g) $i : $UpdateTitol (downloaded)"
            }
            else {
                $downloadReq = $true
                $UpdateTitol = $update.Title
                Write-Host "$(Get-Date -Format g) $i : $UpdateTitol (not downloaded)"
            }
        }
        if ( $downloadReq ) {
            Write-Host "$(Get-Date -Format g) �_�E�����[�h���X�g���쐬..."
            $updatesToDownload = new-object -com "Microsoft.Update.UpdateColl"
            foreach ($update in $searchResult.Updates) {
                $updatesToDownload.Add($update) | out-null
            }
            Write-Host "$(Get-Date -Format g) �_�E�����[�h..."
            $downloader = $updateSession.CreateUpdateDownloader()
            $downloader.Updates = $updatesToDownload
            $downloader.Download()
            Write-Host "$(Get-Date -Format g) �_�E�����[�h�ς�:"
            $i = 0
            foreach ($update in $searchResult.Updates) {
                $i++
                if ( $update.IsDownloaded ) {
                    $UpdateTitol = $update.Title
                    Write-Host "$(Get-Date -Format g) $i : $UpdateTitol (downloaded)"
                }
                else {
                    $UpdateTitol = $update.Title
                    Write-Host "$(Get-Date -Format g) $i : $UpdateTitol (not downloaded)"
                }
            }
        }
        else {
            Write-Host "$(Get-Date -Format g) �S�Ă̍X�V�v���O�������_�E�����[�h���܂���"
        }
        $updatesToInstall = new-object -com "Microsoft.Update.UpdateColl"
        Write-Host "$(Get-Date -Format g) �C���X�g�[�����X�g���쐬..."
        $i = 0
        foreach ($update in $searchResult.Updates) {
            if ( $update.IsDownloaded ) {
                $updatesToInstall.Add($update) | out-null
                $i++
                $UpdateTitol = $update.Title
                Write-Host "$(Get-Date -Format g) $i / $G_MaxUpdateNumber : $UpdateTitol (Install)"
                if ( $i -ge $G_MaxUpdateNumber ) {
                    Write-Host "$(Get-Date -Format g) �X�V���̏���F $G_MaxUpdateNumber"
                    break
                }
            }
        }
        if ( $updatesToInstall.Count -eq 0 ) {
            Write-Host "$(Get-Date -Format g) �C���X�g�[���̏������ł��Ă��܂���"
            Write-Host "$(Get-Date -Format g) �ُ�I��"
        }
        else {
            $InstallCount = $updatesToInstall.Count
            Write-Host "$(Get-Date -Format g) $InstallCount ���̃A�b�v�f�[�g..."
            $installer = $updateSession.CreateUpdateInstaller()
            $installer.Updates = $updatesToInstall
            $installationResult = $installer.Install()
            if ( $installationResult.ResultCode -eq 2 ) {
                Write-Host "$(Get-Date -Format g) �S�Ă̍X�V�v���O�������C���X�g�[������"
            }
            else {
                Write-Host "$(Get-Date -Format g) �ꕔ�̍X�V�v���O�������C���X�g�[���o���܂���ł���"
            }
            if ( $installationResult.RebootRequired ) {
                Write-Host "$(Get-Date -Format g) ��ȏ�̃A�b�v�f�[�g�ōċN�����K�v�ł� 10�b��ɍċN�����܂�"
                Start-Sleep 10
                Restart-Computer -Force
            }
            else {
                Write-Host "$(Get-Date -Format g) Windows Update ���������܂����B�ċN���͕K�v����܂���B"
                Write-Host "$(Get-Date -Format g) =-=-=-=-=- Windows Update finished -=-=-=-=-="
            }
        }
    }


}


################################################
# �`���b�g���M
################################################
function Send-Chat($msg, $chat, $url, $token) {
    $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)

    if ($chat -eq "slack") {
        $notificationPayload = @{text = $enc.GetString($utf8Bytes) }
        Invoke-RestMethod -Uri $url -Method Post -Body (ConvertTo-Json $notificationPayload)
    }
    elseif ($chat -eq "chatwork") {
        $body = $enc.GetString($utf8Bytes)
        Invoke-RestMethod -Uri $url -Method POST -Headers @{"X-ChatWorkToken" = $token } -Body "body=$body"
    }
    elseif ($chat -eq "teams") {
        $body = ConvertTo-JSON @{text = $msg }
        $postBody = [Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $postBody
    }
    elseif ($chat -eq "hangouts") {
        $notificationPayload = @{text = $msg }
        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json; charset=UTF-8' -Body (ConvertTo-Json $notificationPayload)
    }
}


################################################
# ���W�X�g�����Q��
################################################
function Get-Registry( $RegPath, $RegKey ) {
    # ���W�X�g�����̂��̗̂L���m�F
    if ( -not (Test-Path $RegPath )) {
        Write-Host  "$RegPath not found."
        return $null
    }

    # Key�L���m�F
    $Result = Get-ItemProperty $RegPath -name $RegKey -ErrorAction SilentlyContinue

    # �L�[����������
    if ( $null -ne $Result ) {
        return $Result.$RegKey
    }
    # �L�[������������
    else {
        return $null
    }
}


################################################
# ���W�X�g����ǉ�/�X�V
################################################
function Set-Registry( $Path, $Key, $Type, $Value ) {
    # ���W�X�g�����̂��̗̂L���m�F
    $Elements = $Path -split "\\"
    $Path = ""
    $FirstLoop = $True
    foreach ($Element in $Elements ) {
        if ($FirstLoop) {
            $FirstLoop = $False
        }
        else {
            $Path += "\"
        }
        $Path += $Element
        if ( -not (test-path $Path) ) {
            Write-Output "$(Get-Date -Format g) [Add Registry] : $Path"
            mkdir $Path
        }
    }

    # Key�L���m�F
    $Result = Get-ItemProperty $Path -name $Key -ErrorAction SilentlyContinue
    # �L�[����������
    if ( $null -ne $Result ) {
        Write-Host "$(Get-Date -Format g) [Update Registry Value] $Path $Key $Value"
        Set-ItemProperty $Path -name $Key -Value $Value
    }
    # �L�[������������
    else {
        # �L�[��ǉ�����
        Write-Host "$(Get-Date -Format g) [Add Registry Value] $Path $Key $Value"
        New-ItemProperty $Path -name $Key -PropertyType $Type -Value $Value
    }
    Get-ItemProperty $Path -name $Key
}


################################################
# �A�J�E���g�V�K�쐬
################################################
function Create-User( $UserID, $Password ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $NewUser = $Computer.Create("User", $UserID)
    $NewUser.SetPassword( $Password )
    $NewUser.SetInfo()
}


################################################
# �p�X���[�h�������ݒ�
################################################
function DontExpire-Password( $UserID ) {
    $hostname = hostname
    [ADSI]$UpdateUser = "WinNT://$HostName/$UserID,User"
    $UserFlags = $UpdateUser.Get("UserFlags")
    $UserFlags = $UserFlags -bor 0x10000
    $UpdateUser.Put("UserFlags", $UserFlags)
    $UpdateUser.SetInfo()
}


################################################
# �p�X���[�h�X�V
################################################
function Update-Password( $UserID, $Password ) {
    $hostname = hostname
    [ADSI]$UpdateUser = "WinNT://$HostName/$UserID,User"
    $UpdateUser.SetPassword( $Password )
    $UpdateUser.SetInfo()
}


################################################
# ���[�J�����[�U�[�����݂��邩
################################################
function Test-LocalUser( $UserID ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Users = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "User" } | Select-Object -expand Name
    return ($Users -contains $UserID)
}


################################################
# �h���C�����[�U�[�����݂��邩
################################################
function Test-ADUserAccount( $DomainName, $DomainUser ) {
    $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
    if ( $ADUser.ADsPath -ne $null ) {
        return $true
    }
    else {
        return $false
    }
}


###########################################################
# �h���C�����[�U�[/�h���C���O���[�v�̃��[�J���O���[�v�Q��
###########################################################
function Join-ADUser2Group( $DomainName, $DomainUser, $LocalGroup ) {
    $HostName = hostname
    $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
    $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroup")
    $LocalGroup.Add($ADUser.ADsPath)
}


################################################
# ���[�J�����[�U�[�̃O���[�v���E
################################################
function Defection-LocalAccunt( $UserID, $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $GroupName)
    $User = $Computer.GetObject("user", $UserID)
    $Group.Remove($User.ADsPath)
}


#############################################################
# �h���C�����[�U�[/�h���C���O���[�v�̃O���[�v���E
#############################################################
function Defection-DomainAccunt( $DomainName, $DomainUser, $LocalGroup ) {
    $HostName = hostname
    $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
    $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroup")
    $LocalGroup.Remove($ADUser.ADsPath)
}


################################################
# ���[�J�����[�U�[�������o�[�ɂȂ��Ă��邩
################################################
function Test-MemberLocalAccunt( $UserID, $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $GroupName)
    $User = $Computer.GetObject("user", $UserID)
    return $Group.IsMember($User.ADsPath)
}


################################################
# �h���C�����[�U�[�������o�[�ɂȂ��Ă��邩
################################################
function Test-MemberDomainAccunt( $DomainName, $DomainUser, $LocalGroupName ) {
    if ( Test-Group $LocalGroupName ) {
        $HostName = hostname
        $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
        $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroupName")
        return $LocalGroup.IsMember($ADUser.ADsPath)
    }
    else {
        Write-Host "$(Get-Date -Format g) ���[�J���O���[�v $LocalGroupName ��������܂���"
        return $false
    }
}


################################################
# ���[�J���O���[�v�����o�[�擾
################################################
function Get-ListLocalGroupMember( $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $GroupName)
    $MemberNames = @()
    $Members = $Group.psbase.Invoke("members")
    $Members | % { $MemberNames += $_.GetType().InvokeMember("Name", "GetProperty", $null, $_, $null) }
    return $MemberNames
}


################################################
# �A�J�E���g����
################################################
function Disable-Account( $UserID ) {
    $hostname = hostname
    [ADSI]$UpdateUser = "WinNT://$HostName/$UserID,User"
    $UserFlags = $UpdateUser.Get("UserFlags")
    $UserFlags = $UserFlags -bor 0x0202
    $UpdateUser.Put("UserFlags", $UserFlags)
    $UpdateUser.SetInfo()
}


################################################
# �A�J�E���g�L��
################################################
function Enable-Account( $UserID ) {
    $hostname = hostname
    [ADSI]$UpdateUser = "WinNT://$HostName/$UserID,User"
    $UserFlags = $UpdateUser.Get("UserFlags")
    $SaveUserFlags = $UserFlags
    $UserFlags = $UserFlags -bor 0x0202
    $UserFlags = $UserFlags -bxor 0x0202
    $UpdateUser.Put("UserFlags", $UserFlags)
    $UpdateUser.SetInfo()
}


################################################
# ���[�J���O���[�v�V�K�쐬
################################################
function Create-Group( $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $NewGroup = $Computer.Create("Group", $GroupName)
    $NewGroup.SetInfo()
}


################################################
# ���[�J���O���[�v�擾
################################################
function Get-LocalGroups() {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Groups = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "Group" } | Select-Object -expand Name
    return $Groups
}

################################################
# ���[�J���O���[�v�����݂��邩
################################################
function Test-Group( $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Groups = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "Group" } | Select-Object -expand Name
    return ($Groups -contains $GroupName)
}


################################################
# �O���[�v�֎Q��
################################################
function Join-Group( $UserID, $JoinGroup ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $JoinGroup)
    $Group.Add("WinNT://$hostname/$UserID")
}


########################################################################################
# �O���[�v�֎Q��
#  IIS APPPOOL\xx �Ƃ��̈�ʓI�ȃ��[�U�[�ł͂Ȃ��A�J�E���g�ƃ��[�J���O���[�v�ǉ��Ή�
########################################################################################
function Join-Group2( $UserID, $JoinGroup ) {
    $hostname = hostname
    $Group = [ADSI]"WinNT://$hostname/$JoinGroup,group"
    $NTAccount = New-Object System.Security.Principal.NTAccount($UserID)
    $SID = $NTAccount.Translate([System.Security.Principal.SecurityIdentifier])
    $User = [ADSI]"WinNT://$SID"
    $Group.Add($User.Path)
}


################################################
# �X�^�[�g�A�b�v���̊g��PIN��L����
################################################
function Enable-SaveRecoveryPassInAD {
    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
    if ((Get-Registry $RegPath "ActiveDirectoryBackup") -ne 1) {
        Set-Registry $RegPath "UseEnhancedPin" "DWord" 1
    }
    if ((Get-Registry $RegPath "ActiveDirectoryInfoToStore") -ne 1) {
        Set-Registry $RegPath "UseEnhancedPin" "DWord" 1
    }
    if ((Get-Registry $RegPath "RequireActiveDirectoryBackup") -ne 1) {
        Set-Registry $RegPath "UseEnhancedPin" "DWord" 1
    }
}


################################################
# �X�^�[�g�A�b�v���̊g��PIN��L����
################################################
function Enable-StartupPin {

    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

    # �X�^�[�g�A�b�v���ɒǉ��̔F�؂�v������
    if ((Get-Registry $RegPath "EnableBDEWithNoTPM") -ne 1) {
        Set-Registry $RegPath "EnableBDEWithNoTPM" "DWord" 1
    }
    if ((Get-Registry $RegPath "UseAdvancedStartup") -ne 1) {
        Set-Registry $RegPath "UseAdvancedStartup" "DWord" 1
    }
    if ((Get-Registry $RegPath "UseTPM") -ne 2) {
        Set-Registry $RegPath "UseTPM" "DWord" 2
    }
    if ((Get-Registry $RegPath "UseTPMKey") -ne 2) {
        Set-Registry $RegPath "UseTPMKey" "DWord" 2
    }
    if ((Get-Registry $RegPath "UseTPMKeyPIN") -ne 2) {
        Set-Registry $RegPath "UseTPMKeyPIN" "DWord" 2
    }
    if ((Get-Registry $RegPath "UseTPMPIN") -ne 2) {
        Set-Registry $RegPath "UseTPMPIN" "DWord" 2
    }

    # �X�^�[�g�A�b�v�̊g�� PIN ��������
    if ((Get-Registry $RegPath "UseEnhancedPin") -ne 1) {
        Set-Registry $RegPath "UseEnhancedPin" "DWord" 1
    }
}


################################################
# �l�b�g���[�N�h���C�u�̊��蓖��
################################################
function Add-NetworkDrive($driveLetter, $drivePath, $userName, $userPass) {
    if ($driveLetter -eq "") {
        return $false
    }
    if ($userName -ne "") {
        # �F�؏��̃C���X�^���X�𐶐�����
        $securePass = ConvertTo-SecureString $userPass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential $userName, $securePass
        New-PSDrive -Persist -Name $driveLetter -PSProvider FileSystem -Root $drivePath -Credential $cred
    }
    else {
        # �F�؏��s�v�Őڑ�
        New-PSDrive -Persist -Name $driveLetter -PSProvider FileSystem -Root $drivePath
    }
}


################################################
# key.txt �� encryptedtxt �t�@�C������p�X���[�h�𕜍���
################################################
function Decryption-Password($keyFilePath, $encryptedFilePath ) {
    # �Í����Ŏg�p�����o�C�g�z���p��
    [byte[]] $EncryptedKey = Get-Content $keyFilePath

    # �Í������ꂽ�W����������C���|�[�g����SecureString�ɕϊ�
    $importSecureString = Get-Content $encryptedFilePath | ConvertTo-SecureString -key $EncryptedKey

    # SecureString���當��������o�����܂��Ȃ�
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($importSecureString)
    $StringPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    return $StringPassword
}


################################################
# Pause �@�\�ǉ�
################################################
function Pause() {
    Write-Host "���s����ɂ͉����L�[�������Ă�������..." -NoNewLine
    [Console]::ReadKey() | Out-Null
}
