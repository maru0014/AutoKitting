#�p�X���[�h����
$Password = Read-Host "�Í�������p�X���[�h�����" -AsSecureString

#8*24��192bit�̃o�C�g�z����쐬
$EncryptedKey = New-Object Byte[] 24

#RNGCryptoServiceProvider�N���X��create����GetBytes���\�b�h�Ńo�C�g�z��������_���ȃf�[�^�Ŗ��߂�
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($EncryptedKey)

#�쐬���ꂽ�����_���Ȕz����G�N�X�|�[�g
$EncryptedKey | Out-File "$PSScriptRoot/key.txt"

#�Z�L���A�X�g�����O���Í������ꂽ�W��������ɕϊ�
$encrypted = ConvertFrom-SecureString -SecureString $Password -key $EncryptedKey

#�Í������ꂽ�W����������o��
$encrypted | Out-File "$PSScriptRoot/encrypted.txt"
Write-Host "�p�X���[�h���Í������܂���"
