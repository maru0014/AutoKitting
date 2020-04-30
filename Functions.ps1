

################################################
# ドメインに参加
################################################
function Join-Domain($domainName, $userName, $userPass, $ouPath) {
    Write-Host "ドメイン : $($domainName)" -ForeGroundColor Yellow
    Write-Host "ユーザー : $($userName)" -ForeGroundColor Yellow
    # ドメイン参加
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
# ユーザの存在チェック
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
# 自動ログオン有効化
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
        Write-Host "$(Date -Format g) ユーザー$($LogonUser)の自動ログオンを有効化"
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
# 自動ログオン無効化
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
# タスクの存在チェック
################################################
function Test-Task($TaskName) {
    <#
    .SYNOPSIS
    タスクの存在チェック

    .DESCRIPTION
    タスク名を受け取ってタスクスケジューラ内に存在するかチェック
    存在する場合は%true、存在しない場合は$falseを返します

    .EXAMPLE
    Test-Task "自動ログオン"

    .PARAMETER TaskName
    String型でタスクの名前を指定

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
# タスクスケジューラ登録
################################################
function Register-Task($TaskName, $exePath, $TaskExecuteUser, $TaskExecutePass, $visble) {
    if (-not (Test-Task $TaskName)) {
        Write-Host "$(Date -Format g) タスクスケジューラに登録:$($TaskName)"
        $trigger = New-ScheduledTaskTrigger -AtLogon
        $action = New-ScheduledTaskAction -Execute $exePath
        $principal = New-ScheduledTaskPrincipal -UserID $TaskExecuteUser -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances Parallel
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal
    }
}


################################################
# タスクスケジューラ削除
################################################
function Remove-Task($TaskName) {

    if ((Get-WmiObject Win32_OperatingSystem).version -eq "6.1.7601") {
        schtasks /delete /tn $TaskName
    }
    else {
        Get-ScheduledTask | Where-Object { $_.TaskName -match $TaskName } | Unregister-ScheduledTask -Confirm:$false
    }

    Write-Output "$(Date -Format g) $($TaskName)をタスクスケジューラから削除"

}


################################################
# 自動でWindowsアップデートを最新まで実行
################################################
function Run-WindowsUpdate() {
    $errorMsg = ""
    $errorCount = 0
    $updates = Start-WUScan -SearchCriteria "IsInstalled=0 AND IsHidden=0 AND IsAssigned=1"

    # 利用可能な更新プログラムが0件になるまで繰り返す
    while (($updates.Count -ne 0) -And ($errorCount -lt 2)) {
    Write-Host "$(Date -Format g) $($updates.Count)件の更新プログラムが利用可能"

    foreach ($update in $updates) {
        Write-Host "$(Date -Format g) $($update.Title)"
        try {
            Install-WUUpdates -Updates $update -ErrorAction Stop
        }
        catch {
            $errorCount++
            Write-Error $_.Exception
            Write-Host "$(Date -Format g) [Error $($errorCount)] $($update.Title)" -ForegroundColor Yellow
            $errorMsg = $errorMsg + "$(Date -Format g) [更新プログラムのインストールに失敗] $($update.Title)`r`n"
        }
    }

    if (Get-WUIsPendingReboot) {
        # 再起動が必要な場合は再起動
        Write-Host "$(Date -Format g) 更新を完了するため再起動します"
        Restart-Computer -Force
        Exit
    }

    Write-Host "$(Date -Format g) 更新プログラムを再チェック"
    $updates = Start-WUScan

    }

    if ($errorCount -eq 2) {
        return $errorMsg
    }else {
        return "Windows Update 完了"
    }

}


################################################
# チャット送信
################################################
function Send-Chat($msg, $chat, $url, $token) {
    $enc = [System.Text.Encoding]::GetEncoding('ISO-8859-1')
    $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)

    if ($chat -eq "slack") {
        $notificationPayload = @{text = $enc.GetString($utf8Bytes)}
        Invoke-RestMethod -Uri $url -Method Post -Body (ConvertTo-Json $notificationPayload)
    }
    elseif ($chat -eq "chatwork") {
        $body = $enc.GetString($utf8Bytes)
        Invoke-RestMethod -Uri $url -Method POST -Headers @{"X-ChatWorkToken" = $token } -Body "body=$body"
    }
    elseif ($chat -eq "teams") {
        $body = ConvertTo-JSON @{text = $msg}
        $postBody = [Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $postBody
    }
    elseif ($chat -eq "hangouts") {
        $notificationPayload = @{text = $msg}
        Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json; charset=UTF-8' -Body (ConvertTo-Json $notificationPayload)
    }
}


################################################
# レジストリを参照
################################################
function Get-Registry( $RegPath, $RegKey ) {
    # レジストリそのものの有無確認
    if ( -not (Test-Path $RegPath )) {
        Write-Host  "$RegPath not found."
        return $null
    }

    # Key有無確認
    $Result = Get-ItemProperty $RegPath -name $RegKey -ErrorAction SilentlyContinue

    # キーがあった時
    if ( $Result -ne $null ) {
        return $Result.$RegKey
    }
    # キーが無かった時
    else {
        return $null
    }
}


################################################
# レジストリを追加/更新
################################################
function Set-Registry( $Path, $Key, $Type, $Value ) {
    # レジストリそのものの有無確認
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
            Write-Output "$(Date -Format g) [Add Registry] : $Path"
            mkdir $Path
        }
    }

    # Key有無確認
    $Result = Get-ItemProperty $Path -name $Key -ErrorAction SilentlyContinue
    # キーがあった時
    if ( $null -ne $Result ) {
        Write-Host "$(Date -Format g) [Update Registry Value] $Path $Key $Value"
        Set-ItemProperty $Path -name $Key -Value $Value
    }
    # キーが無かった時
    else {
        # キーを追加する
        Write-Host "$(Date -Format g) [Add Registry Value] $Path $Key $Value"
        New-ItemProperty $Path -name $Key -PropertyType $Type -Value $Value
    }
    Get-ItemProperty $Path -name $Key
}


################################################
# アカウント新規作成
################################################
function Create-User( $UserID, $Password ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $NewUser = $Computer.Create("User", $UserID)
    $NewUser.SetPassword( $Password )
    $NewUser.SetInfo()
}


################################################
# パスワード無期限設定
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
# パスワード更新
################################################
function Update-Password( $UserID, $Password ) {
    $hostname = hostname
    [ADSI]$UpdateUser = "WinNT://$HostName/$UserID,User"
    $UpdateUser.SetPassword( $Password )
    $UpdateUser.SetInfo()
}


################################################
# ローカルユーザーが存在するか
################################################
function Test-LocalUser( $UserID ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Users = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "User" } | Select-Object -expand Name
    return ($Users -contains $UserID)
}


################################################
# ドメインユーザーが存在するか
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
# ドメインユーザー/ドメイングループのローカルグループ参加
###########################################################
function Join-ADUser2Group( $DomainName, $DomainUser, $LocalGroup ) {
    $HostName = hostname
    $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
    $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroup")
    $LocalGroup.Add($ADUser.ADsPath)
}


################################################
# ローカルユーザーのグループ離脱
################################################
function Defection-LocalAccunt( $UserID, $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $GroupName)
    $User = $Computer.GetObject("user", $UserID)
    $Group.Remove($User.ADsPath)
}


#############################################################
# ドメインユーザー/ドメイングループのグループ離脱
#############################################################
function Defection-DomainAccunt( $DomainName, $DomainUser, $LocalGroup ) {
    $HostName = hostname
    $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
    $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroup")
    $LocalGroup.Remove($ADUser.ADsPath)
}


################################################
# ローカルユーザーがメンバーになっているか
################################################
function Test-MemberLocalAccunt( $UserID, $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $GroupName)
    $User = $Computer.GetObject("user", $UserID)
    return $Group.IsMember($User.ADsPath)
}


################################################
# ドメインユーザーがメンバーになっているか
################################################
function Test-MemberDomainAccunt( $DomainName, $DomainUser, $LocalGroupName ) {
    if ( Test-Group $LocalGroupName ) {
        $HostName = hostname
        $ADUser = [ADSI]("WinNT://$DomainName/$DomainUser")
        $LocalGroup = [ADSI]("WinNT://$HostName/$LocalGroupName")
        return $LocalGroup.IsMember($ADUser.ADsPath)
    }
    else {
        Write-Host "$(Date -Format g) ローカルグループ $LocalGroupName が見つかりません"
        return $false
    }
}


################################################
# ローカルグループメンバー取得
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
# アカウント無効
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
# アカウント有効
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
# ローカルグループ新規作成
################################################
function Create-Group( $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $NewGroup = $Computer.Create("Group", $GroupName)
    $NewGroup.SetInfo()
}


################################################
# ローカルグループ取得
################################################
function Get-LocalGroups() {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Groups = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "Group" } | Select-Object -expand Name
    return $Groups
}

################################################
# ローカルグループが存在するか
################################################
function Test-Group( $GroupName ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Groups = $Computer.psbase.children | ? { $_.psBase.schemaClassName -eq "Group" } | Select-Object -expand Name
    return ($Groups -contains $GroupName)
}


################################################
# グループへ参加
################################################
function Join-Group( $UserID, $JoinGroup ) {
    $hostname = hostname
    [ADSI]$Computer = "WinNT://$hostname,computer"
    $Group = $Computer.GetObject("group", $JoinGroup)
    $Group.Add("WinNT://$hostname/$UserID")
}


########################################################################################
# グループへ参加
#  IIS APPPOOL\xx とかの一般的なユーザーではないアカウントとローカルグループ追加対応
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
# スタートアップ時の拡張PINを有効化
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
# スタートアップ時の拡張PINを有効化
################################################
function Enable-StartupPin {

    $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"

    # スタートアップ時に追加の認証を要求する
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

    # スタートアップの拡張 PIN を許可する
    if ((Get-Registry $RegPath "UseEnhancedPin") -ne 1) {
      Set-Registry $RegPath "UseEnhancedPin" "DWord" 1
    }
}


################################################
# ネットワークドライブの割り当て
################################################
function Add-NetworkDrive($driveLetter, $drivePath, $userName, $userPass) {
    if ($driveLetter -eq "") {
        return $false
    }
    if ($userName -ne "") {
        # 認証情報のインスタンスを生成する
        $securePass = ConvertTo-SecureString $userPass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential $userName, $securePass
        New-PSDrive -Persist -Name $driveLetter -PSProvider FileSystem -Root $drivePath -Credential $cred
    }
    else {
        # 認証情報不要で接続
        New-PSDrive -Persist -Name $driveLetter -PSProvider FileSystem -Root $drivePath
    }
}


################################################
# key.txt と encryptedtxt ファイルからパスワードを復号化
################################################
function Decryption-Password($keyFilePath, $encryptedFilePath ) {
  # 暗号化で使用したバイト配列を用意
  [byte[]] $EncryptedKey = Get-Content $keyFilePath

  # 暗号化された標準文字列をインポートしてSecureStringに変換
  $importSecureString = Get-Content $encryptedFilePath | ConvertTo-SecureString -key $EncryptedKey

  # SecureStringから文字列を取り出すおまじない
  $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($importSecureString)
  $StringPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  return $StringPassword
}


################################################
# Pause 機能追加
################################################
function Pause() {
  Write-Host "続行するには何かキーを押してください..." -NoNewLine
  [Console]::ReadKey() | Out-Null
}
