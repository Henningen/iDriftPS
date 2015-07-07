function global:New-GPP-DriveMapXML{
<#

            .SYNOPSIS

            This Cmdlet Creates a Group Policy Preferences Drives.xml file.

 

            .DESCRIPTION

            This Cmdlet Creates a Group Policy Preferences Drives.xml file. This can be used to replace an existing one in group policy, to increase speed when initially creating the GPP policy. 


            .EXAMPLE

            New-GPP-DriveMapXML -Sharename "Share"

	    Creates Drives.xml for the single share "Share". Since no other parameters are given it will assume defaults for the rest.
	    Share is assumed to be on current computer, adgroup is assumed "Domain Users".
	    Output file will be writen to the users temporary folder.
 

            .EXAMPLE

            New-GPP-DriveMapXML -Outfile ".\Drives.xml" -ShareName "Share" -ComputerName "SUPERSERVER" -ADGroup "diskmaps" -letter "Y"

	    Creates Drives.xml for the single share "Share", it belongs to the server "SUPERSERVER" so "\\superserver\share" will be the UNC.
	    The disk map will be configured with the letter "Y", and the Active-Directory Group "diskmaps"
            will be used to filter who gets the disk mapped.s
 

            .EXAMPLE

            $diskarray = @( 
			[pscustomobject]@{ShareName="Marketing";ComputerName="SUPERSERVER";ADGroup="diskmaps";letter="X"},
			[pscustomobject]@{ShareName="Sales";ComputerName="SUPERSERVER";ADGroup="diskmaps";letter="Y"},
			[pscustomobject]@{ShareName="Technical";ComputerName="SUPERSERVER";ADGroup="diskmaps";letter="Z"})
	    $diskarray | New-GPP-DriveMapXml

	    Creates Drives.xml for the three shares in the array of custom objects. Can also use .csv files or simular as input in the same manner.



            .EXAMPLE
	  
	    Get-WmiObject win32_share -ComputerName SUPERSERVER | where-object { $_.type -eq 0 -and $_.name -notmatch '\$$' -and $_.name -ne "SYSVOL" -and $_.name -ne "NETLOGON" } | New-GPP-DriveMapXML
 		
	    One liner to create drive maps of all non-hidden shares except "SYSVOL" and "NETLOGON". All drive maps will be created with default letter X in this example.
	    It's possible to combine the example to export to csv and add custom letters etc for more flexibility.

            .NOTES

            AD group filtering only support single group, should ideally be made more flexible.
	    This is built for a standard task, and not made super-flexible from scratch.

            .COMPONENT

            Requires active directory powershell module for active directory group lookups.

            .LINK

            http://www.idrift.no

	    .PARAMETER Outfile

	    Output file path

	    .PARAMETER openInNotepad

	    Opens the output file in notepad after execution 

	    .PARAMETER ADGroup

	    Active Directory group to filter the Drive Map by

	    .PARAMETER ComputerName

	    Server name where the share lives

	    .PARAMETER ShareName

	    Share name

	    .PARAMETER Letter
	    Drive Letter for the Disk Mapping

	    .PARAMETER Action

	    Action to perform, can be either Create, Delete, Replace or Update
	    The default value is update.
#>
[CmdletBinding()]
param(
[parameter(HelpMessage='Output file path')]
[string]$Outfile = "$env:temp\Drives.xml",

[switch]$openInNotepad,

[parameter(ValueFromPipelineByPropertyName=$True)]
[string[]]$ADGroup = "Domain Users",

[parameter(ValueFromPipeline=$True,
ValueFromPipelineByPropertyName=$True)]
[Alias("PSComputerName","MachineName","CN")]
[string[]]$ComputerName = "$env:computername",

[parameter(ValueFromPipeline=$True,
ValueFromPipelineByPropertyName=$True)]
[Alias("Name","SN")]
[string[]]$ShareName = "",

[parameter(ValueFromPipelineByPropertyName=$True)]
[ValidateSet("Create","Delete","Replace","Update")]
[string[]]$Action = "Update",

[parameter(ValueFromPipelineByPropertyName=$True,
HelpMessage='Drive Letter for the Disk Mapping')]
[string[]]$Letter = "X"
)

begin{
#set encodings
$encoding = [System.Text.Encoding]::UTF8

# get an XMLTextWriter to create the XML
#$XmlWriter = New-Object System.XMl.XmlTextWriter($OutFile,$Null) 
$XmlWriter = New-Object System.XMl.XmlTextWriter($OutFile,$encoding) 

# choose a pretty formatting:
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t" 
# write the header
$xmlWriter.WriteStartDocument()
 
# set XSL statements
#$xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")
 
# create root element "machines" and add some attributes to it
$drivesclsid="{8FDDCC1A-0C3C-43cd-A6B4-71A6DF20DA8C}"
$driveclsid="{935D1B74-9CB8-4e3c-9914-7DD559B7A417}"
$xmlWriter.WriteStartElement('Drives')
$XmlWriter.WriteAttributeString('clsid', $drivesclsid) 
$domain=${env:userdomain}
}

process
{
    write-debug "ADGroup is $ADGroup, running get-adgroup to find attributes!"
    $domaingroup = get-ADgroup -identity "$ADGroup"
    
    $guid = [System.GUID]::NewGuid().ToString()
    $changed=get-date -format "yyyy-MM-dd HH:mm:ss"
 
    # each data set is called "drive", add a random attribute to it:
    $xmlWriter.WriteStartElement('Drive')
    $XmlWriter.WriteAttributeString('clsid', $driveclsid)
    $XmlWriter.WriteAttributeString('bypassErrors', '1')
    $XmlWriter.WriteAttributeString('userContext', '1')
    $XmlWriter.WriteAttributeString('uid', $guid)
    $XmlWriter.WriteAttributeString('changed', $changed)   
    switch ($action){
	"Create" { $XmlWriter.WriteAttributeString('image', '0') }
	"Replace" { $XmlWriter.WriteAttributeString('image', '1') }
        "Update" { $XmlWriter.WriteAttributeString('image', '2') }
        "Delete" { $XmlWriter.WriteAttributeString('image', '3') }
	default { $XmlWriter.WriteAttributeString('image', '2') }
    }    
    $XmlWriter.WriteAttributeString('status', ("$($letter):") )
    $XmlWriter.WriteAttributeString('name', ("$($letter):"))  

    $xmlWriter.WriteStartElement('Properties')
    $XmlWriter.WriteAttributeString('letter', $letter)  
    $XmlWriter.WriteAttributeString('useLetter', '1')  
    $XmlWriter.WriteAttributeString('persistent', '0')
    $XmlWriter.WriteAttributeString('label', $name)
    $XmlWriter.WriteAttributeString('path', ("\\"+$computername+"\"+$sharename) ) 
    $XmlWriter.WriteAttributeString('userName', '')
    $XmlWriter.WriteAttributeString('allDrives', 'NOCHANGE')
    $XmlWriter.WriteAttributeString('thisDrive', 'NOCHANGE')
    switch ($action){
	"Create" { $XmlWriter.WriteAttributeString('action', 'C')  }
	"Replace" { $XmlWriter.WriteAttributeString('action', 'R')  }
        "Update" { $XmlWriter.WriteAttributeString('action', 'U')  }
        "Delete" { $XmlWriter.WriteAttributeString('action', 'D')  }
	default { $XmlWriter.WriteAttributeString('action', 'U')  }
    }   
    # close the "properties" node:
    $xmlWriter.WriteEndElement()
  
    $xmlWriter.WriteStartElement('Filters')
    $xmlWriter.WriteStartElement('FilterGroup')
    $XmlWriter.WriteAttributeString('userContext', '1')
    $XmlWriter.WriteAttributeString('name', ($domain+"\"+$domaingroup.name) )
    $XmlWriter.WriteAttributeString('localGroup', '0')
    $XmlWriter.WriteAttributeString('primaryGroup', '0')
    $XmlWriter.WriteAttributeString('sid', $domaingroup.SID)
    $XmlWriter.WriteAttributeString('not', '0')
    $XmlWriter.WriteAttributeString('bool', 'AND')
    # close the "filterGroup" node:
    $xmlWriter.WriteEndElement()
    # close the "filters" node:
    $xmlWriter.WriteEndElement()

    # close the "drive" node:
    $xmlWriter.WriteEndElement()
}

end{ 
# close the "drives" node:
$xmlWriter.WriteEndElement()
 
# finalize the document:
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close() 
if ($openInNotepad) { notepad $Outfile }
}
}