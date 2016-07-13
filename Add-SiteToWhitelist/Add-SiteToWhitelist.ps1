function RemoveProxyOverride {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$GPOName
    )
    # Remove previous values from ProxyOverride
    $params = @{
        'Name'="$GPOName";
        'Context'='User';
        'Key'='HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        'ValueName'='ProxyOverride';
    }
    Remove-GPPrefRegistryValue @params
}

function Set-GpoPreferenceProxyOverrideUrl {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [string[]]$Url
    )
    # Add new values to ProxyOverride
    $params = @{
        'Name'="$GPOName";
        'Action'='Replace';
        'Context'='User';
        'Key'='HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
        'Type'='String';
        'ValueName'='ProxyOverride';
        'Value'=$Url -join ';'
    }
    
    RemoveProxyOverride -GPOName $GPOName

    Set-GPPrefRegistryValue @params
}

function GetGpoPreferenceXmlFile {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [ValidateSet('Shortcut')]
        [string]$PreferenceType,

        [Parameter(Mandatory)]
        [ValidateSet('User','Computer')]
        [string]$Context
    )

    $GPOItem = Get-GPO -Name $GPOName

    $prefRoot = "\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences"
    
    switch ($PreferenceType) {
        'Shortcut' {
            $xmlFilePath = Join-Path $prefRoot 'Shortcuts\Shortcut.xml'
        }
    }

    [xml](Get-Content -Path $xmlFilePath)
}


function RemoveGpoPreferenceChildNodesFromXml {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [xml]$Xml
    )
    # First, remove the old values
    $ChildNodes = $Xml.SelectNodes('//Shortcuts/Shortcut')
    foreach ($Child in $ChildNodes) {
        [void]$Child.ParentNode.RemoveChild($Child)
    }
}

function Set-GpoPreferenceShortcut {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$GPOName,

        [Parameter(Mandatory)]
        [string[]]$Url
    )
    # Add each link to bookmarks bar

    $gpo = GetGpoPreferenceXmlFile -GPOName $GPOName -PreferenceType Shortcut -Context User

    RemoveGpoPreferenceChildNodesFromXml -Xml $gpo

    foreach ($Website in $Url) {
        $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $NodeId = ([guid]::NewGuid()).Guid
        
        # Create XML element Shortcut
        $NewShortcut = $gpo.CreateElement("Shortcut")
        $NewShortcut.SetAttribute('clsid',"{4F2F7C55-2790-433e-8127-0739D1CFA327}")
        $NewShortcut.SetAttribute('name',"$($Website.Name)")
        $NewShortcut.SetAttribute('status',"$($Website.Name)")
        $NewShortcut.SetAttribute('image','1')
        $NewShortcut.SetAttribute('changed',"$Timestamp")
        $NewShortcut.SetAttribute('uid',"{$NodeId}")
        $NewShortcut.SetAttribute('removePolicy','1')
        $NewShortcut.SetAttribute('userContext','1')
        $NewShortcut.SetAttribute('bypassErrors','1')
        
        # Create XML element Properties
        $NewProperty = $gpo.CreateElement("Properties")
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
        
        $gpo.Shortcuts.AppendChild($NewShortcut)
        @($gpo.Shortcuts.Shortcut).Where({$_.uid -like "*$NodeID*"}).AppendChild($NewProperty)
    }

    $gpo.Save("\\$Env:USERDOMAIN\SYSVOL\$Env:USERDNSDOMAIN\Policies\{$($GPOItem.Id.Guid)}\User\Preferences\Shortcuts\Shortcuts.xml")
}