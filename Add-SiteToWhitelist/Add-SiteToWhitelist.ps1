$GPOName = 'TestMKS-Override'
$WhitelistPath = 'C:\GPO\Whitelist.csv'


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

# Add links to bookmarks bar
$GPOItem = Get-GPO -Name $GPOName

# Get contents from Shortcuts.xml in the GPO specified in variable $GPOName
[xml]$GPO = Get-Content "\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences\Shortcuts\Shortcuts.xml"

# First, remove any old values from the XML in Shortcuts element 
$ChildNodes = $GPO.SelectNodes('//Shortcuts/Shortcut')
foreach ($Child in $ChildNodes) {
    [void]$Child.ParentNode.RemoveChild($Child)
}

# Add each bookmark to XML in Shortcuts element
$Websites = Import-Csv -Path $WhitelistPath -Delimiter ';'
foreach ($Website in $Websites) {
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $NodeId = ([guid]::NewGuid()).Guid
    
    # Create new XML element 'Shortcut'
    $NewShortcut = $GPO.CreateElement("Shortcut")
    $NewShortcut.SetAttribute('clsid',"{4F2F7C55-2790-433e-8127-0739D1CFA327}")
    $NewShortcut.SetAttribute('name',"$($Website.Name)")
    $NewShortcut.SetAttribute('status',"$($Website.Name)")
    $NewShortcut.SetAttribute('image','1')
    $NewShortcut.SetAttribute('changed',"$Timestamp")
    $NewShortcut.SetAttribute('uid',"{$NodeId}")
    $NewShortcut.SetAttribute('removePolicy','1')
    $NewShortcut.SetAttribute('userContext','1')
    $NewShortcut.SetAttribute('bypassErrors','1')
    
    # Create new XML element 'Properties'
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
    $NewProperty.SetAttribute('window','')
    $NewProperty.SetAttribute('shortcutPath',"%FavoritesDir%\Links\$($Website.Name)")
    
    # Append new XML child element 'Shortcut' to element 'Shortcuts'
    $GPO.Shortcuts.AppendChild($NewShortcut)

    # Append new XML child element 'Properties' to element where 'Shortcut' uid matches $NodeID
    @($GPO.Shortcuts.Shortcut).Where({$_.uid -like "*$NodeID*"}).AppendChild($NewProperty)
}

# Save changes to Shortcuts.xml in the GPO specified in variable $GPOName
$GPO.Save("\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences\Shortcuts\Shortcuts.xml")