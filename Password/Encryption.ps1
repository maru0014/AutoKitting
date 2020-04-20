#パスワード入力
$Password = Read-Host "暗号化するパスワードを入力" -AsSecureString

#8*24で192bitのバイト配列を作成
$EncryptedKey = New-Object Byte[] 24

#RNGCryptoServiceProviderクラスをcreateしてGetBytesメソッドでバイト配列をランダムなデータで埋める
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptedKey)

#作成されたランダムな配列をエクスポート
$EncryptedKey | Out-File "$PSScriptRoot/key.txt"

#セキュアストリングを暗号化された標準文字列に変換
$encrypted = ConvertFrom-SecureString -SecureString $Password -key $EncryptedKey

#暗号化された標準文字列を出力
$encrypted | Out-File "$PSScriptRoot/encrypted.txt"
Write-Host "パスワードを暗号化しました"
