# �Q�lURL�F http://mitsushima.work/archives/20534104.html

#�uMicrosoft Edge�v�^�X�N�o�[����s�����߂��O��
$AppName = "Microsoft Edge"
$wshell = (New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object {$_.Name -eq $AppName}
$wshell.Verbs() | Where-Object {$_.Name -like "*�^�X�N �o�[����s�����߂��O��*"} | ForEach-Object{$_.DoIt()}

#�uMicrosoft Store�v�^�X�N�o�[����s�����߂��O��
$AppName = "Microsoft Store"
$wshell = (New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object {$_.Name -eq $AppName}
$wshell.Verbs() | Where-Object {$_.Name -like "*�^�X�N �o�[����s�����߂��O��*"} | ForEach-Object{$_.DoIt()}

#�u���[���v�^�X�N�o�[����s�����߂��O��
$AppName = "���[��"
$wshell = (New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object {$_.Name -eq $AppName}
$wshell.Verbs() | Where-Object {$_.Name -like "*�^�X�N �o�[����s�����߂��O��*"} | ForEach-Object{$_.DoIt()}
