# 概要

PowerShell によって Windows10 のキッティングに必要な全工程を自動的に完了。

再起動が必要な場合も自動ログオンとタスクスケジューラ登録によって起動後も処理を継続可能です。

- PC 名の変更
- Windows Update
- ドメイン参加
- Administrator の有効化
- IPv6 無効化
- 固定 IP の設定
- DNS の設定
- ネットワークドライブの割り当て
- MAC アドレスのチャット通知
- 端末シリアルナンバーのチャット通知
- BitLocker の設定
- BitLocker リカバリ ID/回復パスワードのチャット通知
- 不要なソフトウェアのアンインストール
- アプリケーションの自動インストール
  - Office のインストール
  - Google Chrome / Firefox のインストール
  - Google 日本語入力 のインストール
  - Sakura Editor のインストール
  - Slack のインストール
  - 7-Zip / Lhaplus のインストール
  - Adobe Acrobat Reader / CubePDF / PDF X-Viewer のインストール
  - Lanscope Cat MR のインストール
  - Global Protect のインストール
  - ESET Internet Security / Sophos Endpoint Protection のインストール
- 設定用ユーザプロファイルのクリーンアップ
- 設定用ファイルのクリーンアップ

<br>

# 事前準備

## Application フォルダに各種インストーラを配置

![image](https://user-images.githubusercontent.com/15005576/79337483-8d27b880-7f60-11ea-8278-beacbcafb2b9.png)

**分かりづらいスタンドアロンインストーラの入手先**

[Google Chrome Windows（64 ビット）版 Chrome MSI](https://cloud.google.com/chrome-enterprise/browser/download?hl=ja#chrome-browser-download)

[FireFox 64bit](https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=ja)

[Adobe Acrobat Reader DC](https://get.adobe.com/jp/reader/enterprise/)

### Administrator のパスワードは事前に暗号化

※Administrator を有効化する場合のみ必要

1. Password フォルダ内「Run-Encryption.bat」を実行
2. パスワード入力を求められるので入力
3. 同フォルダ内に「encrypted.txt」「key.txt」が生成されたことを確認

![image](https://user-images.githubusercontent.com/15005576/77046926-2e295f00-6a07-11ea-822d-105de103a843.png)

## Get-Files.bat の設定

※各種ファイルをネットワーク経由で配布する場合のみ必要
変数「Source」にネットワークドライブ上のキッティングフォルダパスを指定

```bash
set Source="\\NAS\share\AutoKitting"
```

## Uninstall-Apps.ps1 の設定

不要なデフォルトアプリケーションを削除できます。

※Config.json 内の runUninstallApps が true の場合のみ有効

削除しないものは # でコメントアウトしてください。

```powershell
# Get-AppxPackage Microsoft.Microsoft3DViewer | Remove-AppxPackage             # 3Dビューアー(1809以降)
Get-AppxPackage king.com.CandyCrushFriends | Remove-AppxPackage              # Candy Crush Friends
Get-AppxPackage king.com.FarmHeroesSaga | Remove-AppxPackage                 # Farm Heroes Saga
Get-AppxPackage Microsoft.ZuneMusic | Remove-AppxPackage                     # Groove ミュージック
Get-AppxPackage Microsoft.MicrosoftSolitaireCollection | Remove-AppxPackage  # Microsoft Solitaire Collection
Get-AppxPackage Microsoft.MixedReality.Portal | Remove-AppxPackage           # Mixed Realityポータル
Get-AppxPackage Microsoft.MicrosoftOfficeHub | Remove-AppxPackage            # Office
Get-AppxPackage Microsoft.Office.OneNote | Remove-AppxPackage                # OneNote
Get-AppxPackage Microsoft.People | Remove-AppxPackage                        # People
...
```

## AppAssoc.xml の設定

既定のアプリ設定用ファイル

マスタ PC の cmd で`Dism /Online /Export-DefaultAppAssociations:"F:\AppAssociations.xml"`を実行して各設定値を確認可能。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".pdf" ProgId="AcroExch.Document.DC" ApplicationName="Adobe Acrobat Reader DC" />
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".website" ProgId="IE.AssocFile.WEBSITE" ApplicationName="Internet Explorer" />
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
</DefaultAssociations>

```

## Config.json の設定

PC 名、セットアップに利用するアカウント情報、ネットワーク設定、アプリのインストール設定などを指定する。

```json
[
  {
    "pcname": "N2020-001", //PC名
    "joinDomain": true, //ドメイン参加する
    "enableAdministrator": true, //Administratorを有効化
    "enableRemoteDesktop": true, //リモートデスクトップを有効化
    "disableWinDefender": true, //Windows Defenderを無効化
    "desableSleep": true, //スリープを無効化する
    "desableHibernate": true, //休止状態を無効化する
    "defaultDesktop": true, //Defaultユーザのデスクトップにコピー
    "defaultAppAssoc": true, //既定のアプリを設定
    "deleteTaskbarUWPApps": false, //タスクバーのアイコンを削除
    "runUninstallApps": true, //不要なアプリをアンインストール
    "upgradeWindows": true, //バージョン1909にアップグレード
    "domain": {
      "name": "codelife", //ドメイン名
      "address": "codelife.cafe" //DCアドレス
    },
    "bitLocker": {
      "flag": true, //BitLocker を有効化
      "password": "Setup1234", //BitLockerの拡張pin
      "saveRecoveryPassInAD": true //回復パスワードをADに保管する（AD側に管理機能を追加する必要あり）
    },
    "network": {
      "desableSnp": true, //SNPを無効化する
      "disableIPv6": true, //IPv6を無効化する
      "staticIP": {
        "flag": false, //固定IPの設定
        "address": "", //IPアドレス
        "gateway": "", //デフォルトゲートウェイ
        "prefixLength": 24 //サブネットマスク
      },
      "dns": ["192.168.1.100", "192.168.1.1", "8.8.8.8", "8.8.4.4"], //1つ目：優先、2つ目：代替、3つ目移行は詳細設定内にセットされる
      "dnsSuffix": ["dc.codelife.cafe"], //DNSサフィックス設定（カンマ区切りで複数可）
      "drive": [
        //マウントするネットワークドライブ設定（カンマ区切りで複数可）
        {
          "name": "Z", //ドライブレター
          "path": "\\\\na\\share", //ネットワークドライブパス（\はエスケープする必要あり）
          "user": "su", //認証不要の場合は空欄
          "pass": "Setup1234" //認証不要の場合の場合は空欄
        }
      ]
    },
    "setupUser": {
      //セットアップ用ユーザ（OOBE時に設定したもの）
      "name": "setup", //セットアップ用ユーザ名
      "pass": "Setup1234", //セットアップ用ユーザパスワード（なしの場合は "" ）
      "delete": true //キッティング完了後にセットアップ用ユーザを削除する
    },
    "domainUser": {
      "name": "joindomain", //ドメインユーザ名（ドメイン名は不要）
      "pass": "Welcome123", //ドメインユーザパスワード
      "ouPath": "", //OUの指定（リプレイスの場合は空欄）
      "localGroup": ["Administrators"] //ドメインユーザをローカルグループに追加（カンマ区切りで複数可）
    },
    "localUser": {
      //ローカルユーザを作成する場合に設定
      "name": "", //ユーザ名
      "pass": "", //ユーザパスワード
      "dontExpirePassword": false, //ユーザのパスワードを無期限にする
      "localGroup": [] //ユーザをローカルグループに追加（カンマ区切りで複数可）
    },
    "notifier": {
      "chat": "slack", //slack or teams or chatwork
      "url": "https://hooks.slack.com/services/XXXXXXXXX/XXXXXXXXXXX/XXXXXXXXXXXXXXXXXXXXXXX", //Webhook URL
      "slackUser": "Win10 Kitting Bot", //Slack 投稿ユーザ名
      "cwToken": "" //ChatWork投稿用トークン
    },
    "apps": [
      {
        "name": "Google Chrome", //ログに出力するアプリ名
        "installerType": "msi", //exe または msi
        "installerPath": "/Applications/googlechromestandaloneenterprise64.msi", //インストーラの相対パス
        "argument": "", //インストーラ実行時に付与する引数
        "workingDirectory": "/Applications", //インストーラを実行するフォルダパス
        "checkFilePath": "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe", //インストールが完了したかチェックするパス
        "timeOut": 600, //タイムアウト秒数
        "onlyOnce": false //trueとした場合は1度だけ実行される（checkFilePathでチェックできない場合に利用）
      },
      {
        "name": "Google日本語入力",
        "installerType": "exe",
        "installerPath": "/Applications/GoogleJapaneseInputSetup.exe",
        "argument": "/silent /install",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files (x86)/Google/Google Japanese Input",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Google Drive File Stream",
        "installerType": "exe",
        "installerPath": "/Applications/GoogleDriveFSSetup.exe",
        "argument": "--silent --desktop_shortcut --gsuite_shortcuts=false",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files/Google/Drive File Stream",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Firefox",
        "installerType": "msi",
        "installerPath": "/Applications/Firefox Setup 73.0.1.msi",
        "argument": "/quiet /norestart",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files/Mozilla Firefox/firefox.exe",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Sakura Editor",
        "installerType": "exe",
        "installerPath": "/Applications/sakura_install2-2-0-1.exe",
        "argument": "/SP- /VERYSILENT",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files (x86)/sakura",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Lhaplus",
        "installerType": "exe",
        "installerPath": "/Applications/lpls174.exe",
        "argument": "/SILENT /NORESTART",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files (x86)/Lhaplus",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Adobe Acrobat Reader DC",
        "installerType": "exe",
        "installerPath": "/Applications/AcroRdrDC2000620034_ja_JP.exe",
        "argument": "/sPB /rs /l",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files (x86)/Adobe/Acrobat Reader DC",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "PDF-XChange Viewer",
        "installerType": "exe",
        "installerPath": "/Applications/PDFXVwer.exe",
        "argument": "/SP- /SILENT /norestart",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files/Tracker Software",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "CubePDF",
        "installerType": "exe",
        "installerPath": "/Applications/cubepdf-1.0.1-x64.exe",
        "argument": "/lang=japanese /verysilent /sp- /nocancel /norestart /suppressmsgboxes /nolaunch",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files/CubePDF",
        "timeOut": 600,
        "onlyOnce": false
      },
      {
        "name": "Slack",
        "installerType": "msi",
        "installerPath": "/Applications/SlackSetup.msi",
        "argument": "",
        "workingDirectory": "/Applications",
        "checkFilePath": "C:/Program Files/Slack Deployment",
        "timeOut": 900,
        "onlyOnce": false
      },
      {
        "name": "Office 365",
        "installerType": "exe",
        "installerPath": "/Applications/O365/setup.exe",
        "argument": "/configure installOfficeBusRet64.xml",
        "workingDirectory": "/Applications/O365/",
        "checkFilePath": "C:/Program Files/Microsoft Office",
        "timeOut": 600,
        "onlyOnce": false
      }
    ]
  }
]
```

<br>

# 実行手順

**ネットワークドライブ経由で各種ファイルを配信する場合**

1. キッティング対象 PC の C ドライブ直下に「Get-Files.bat」を配置
2. 「Get-Files.bat」を管理者権限で実行する
3. ネットワークドライブに接続するための ID/PASS を入力して、ファイルの転送が開始されたことを確認
4. 放置

**USB メモリから実行する場合**

1. USB メモリに各種ファイルを配置
2. C ドライブ直下に FullAutoKitting フォルダをコピー
3. 「Run-PS.bat」を管理者権限で実行
4. 放置
