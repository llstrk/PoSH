$Websites = Import-Csv -Path C:\GPO\Whitelist.csv -Delimiter ';'
$GPOName = 'TestMKS-Override'


# Remove previous values from ProxyOverride
$params = @{
    'Name'="$GPOName";
    'Context'='User';
    'Key'='HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    'ValueName'='ProxyOverride';
}
Remove-GPPrefRegistryValue @params

# Add new values to ProxyOverride
$params = @{
    'Name'="$GPOName";
    'Action'='Replace';
    'Context'='User';
    'Key'='HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    'Type'='String';
    'ValueName'='ProxyOverride';
    'Value'=$($Websites.Url) -join ';'
}
Set-GPPrefRegistryValue @params


## Add links to bookmarks bar ##

$GPOItem = Get-GPO -Name $GPOName
[xml]$GPO = Get-Content "\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences\Shortcuts\Shortcuts.xml"

# First, remove the old values
$ChildNodes = $GPO.SelectNodes('//Shortcuts/Shortcut')
foreach ($Child in $ChildNodes) {
    [void]$Child.ParentNode.RemoveChild($Child)
}

# Add each link to bookmarks bar
$ShortcutClsid = ([guid]::NewGuid()).Guid

foreach ($Website in $Websites) {
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $NodeId = ([guid]::NewGuid()).Guid
    
    # Create XML element Shortcut
    $NewShortcut = $GPO.CreateElement("Shortcut")
    $NewShortcut.SetAttribute('clsid',"{$ShortcutClsid}")
    $NewShortcut.SetAttribute('name',"$($Website.Name)")
    $NewShortcut.SetAttribute('status',"$($Website.Name)")
    $NewShortcut.SetAttribute('image','1')
    $NewShortcut.SetAttribute('removePolicy','1')
    $NewShortcut.SetAttribute('userContext','1')
    $NewShortcut.SetAttribute('bypassErrors','1')
    $NewShortcut.SetAttribute('changed',"$Timestamp")
    $NewShortcut.SetAttribute('uid',"{$NodeId}")
    
    # Create XML element Properties
    $NewProperty = $GPO.CreateElement("Properties")
    $NewProperty.SetAttribute('pidl','')
    $NewProperty.SetAttribute('targetType','URL')
    $NewProperty.SetAttribute('action','R')
    $NewProperty.SetAttribute('comment','')
    $NewProperty.SetAttribute('shortcutKey','0')
    $NewProperty.SetAttribute('startIn','')
    $NewProperty.SetAttribute('arguments','')
    $NewProperty.SetAttribute('iconIndex','0')
    $NewProperty.SetAttribute('targetPath',$($Website.Url))
    $NewProperty.SetAttribute('iconPath','')
    $NewProperty.SetAttribute('windows','')
    $NewProperty.SetAttribute('shortcutPath',"%FavoritesDir%\Links\$($Website.Name)")
    
    $GPO.Shortcuts.AppendChild($NewShortcut)
    $GPO.Shortcuts.Shortcut.Where({$_.uid -like "*$NodeID*"}).AppendChild($NewProperty)
}

$GPO.Save("\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences\Shortcuts\Shortcuts.xml")