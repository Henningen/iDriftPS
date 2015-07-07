function global:New-GPP-PrintersXML{
<#

            .SYNOPSIS

            This Cmdlet Creates a Group Policy Preferences Printers.xml file.

 

            .DESCRIPTION

            This Cmdlet Creates a Group Policy Preferences Printers.xml file. This can be used to replace an existing one in group policy, to increase speed when initially creating the GPP policy. 


            .EXAMPLE

            New-GPP-PrintersXML -ShareName "Print01"

	    Creates Printers.xml for the single shared printer "Print01". Since no other parameters are given it will assume defaults for the rest.
	    Share is assumed to be on current computer, adgroup is assumed "Domain Users".
	    Output file will be written to the users temporary folder.
 

            .EXAMPLE

            New-GPP-PrintersXML -Outfile ".\Printers.xml" -ShareName "Print01" -ComputerName "SUPERSERVER" -ADGroup "printmaps" 

	    Creates Printers.xml for the single printer "Print01", it belongs to the server "SUPERSERVER" so "\\superserver\Print01" will be the UNC.
	    The Active-Directory Group "diskmaps" will be used to filter who gets the disk mapped.s
 

            .EXAMPLE

            $diskarray = @( 
			[pscustomobject]@{ShareName="Print01";SystemName="SUPERSERVER";ADGroup="printmaps"},
			[pscustomobject]@{ShareName="Print02";SystemName="SUPERSERVER";ADGroup="printmaps"},
			[pscustomobject]@{ShareName="Print03";SystemName="SUPERSERVER";ADGroup="printmaps"})
	    $diskarray | New-GPP-PrintersXML

	    Creates Printers.xml for the three shares in the array of custom objects. Can also use .csv files or simular as input in the same manner.



            .EXAMPLE

            Get-WmiObject win32_printer -ComputerName "SUPERSERVER" | where-object { $_e -ne $null } | New-GPP-PrintersXML
 		
	    One liner to create printer maps of all shared printers except. 
	    It's possible to combine the example to export to csv and add custom adgroups etc for more flexibility.

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

	    Opens the output file in notepad after execution.

	    .PARAMETER ADGroup

	    Active Directory group to filter the Printer Map by

	    .PARAMETER ComputerName

	    Server name where the share lives

	    .PARAMETER ShareName

	    Share name

	    .PARAMETER Default

	    Specifies if the printer should be set as default printer ($true).
	    If not specified the value defaults to false.

#>

[CmdletBinding()]
param(
[string]$Outfile = "$env:temp\Printers.xml",

[switch]$openInNotepad,

[parameter(ValueFromPipelineByPropertyName=$True)]
[string[]]$ADGroup = "Domain Users",

[parameter(ValueFromPipeline=$True,
ValueFromPipelineByPropertyName=$True)]
[Alias("SystemName","CN","MachineName")]
[string[]]$ComputerName = "$env:computername",

[parameter(ValueFromPipelineByPropertyName=$True)]
[ValidateSet("Create","Delete","Replace","Update")]
[string[]]$Action = "Update",

[parameter(ValueFromPipelineByPropertyName=$True)]
[boolean[]]$Default = $false,

[parameter(ValueFromPipeline=$True,
ValueFromPipelineByPropertyName=$True)]
[Alias("SN")]
[string[]]$ShareName = ""
)

begin{
#set encoding
$encoding = [System.Text.Encoding]::UTF8

# get an XMLTextWriter to create the XML
#$XmlWriter = New-Object System.XMl.XmlTextWriter($Outfile,$Null) 
$XmlWriter = New-Object System.XMl.XmlTextWriter($Outfile,$encoding) 

# choose a pretty formatting:
$xmlWriter.Formatting = 'Indented'
$xmlWriter.Indentation = 1
$XmlWriter.IndentChar = "`t"
 
# write the header
$xmlWriter.WriteStartDocument()
 
# set XSL statements
#$xmlWriter.WriteProcessingInstruction("xml-stylesheet", "type='text/xsl' href='style.xsl'")
 
# create root element "machines" and add some attributes to it
$printersclsid="{1F577D12-3D1B-471e-A1B7-060317597B9C}"
$sharedprinterclsid="{9A5E9697-9095-436d-A0EE-4D128FDFBCE5}"
$xmlWriter.WriteStartElement('Printers')
$XmlWriter.WriteAttributeString('clsid', $printersclsid) 
$domain=${env:userdomain}
}

process
{
    $domaingroup = Get-adgroup -Identity "$ADGroup"
    $guid = [System.GUID]::NewGuid().ToString()
    $changed=get-date -format "yyyy-MM-dd HH:mm:ss"
 
    # each data set is called "shareprinter", add a random attribute to it:
    $xmlWriter.WriteStartElement('SharedPrinter')
    $XmlWriter.WriteAttributeString('clsid', $sharedprinterclsid)
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
    $XmlWriter.WriteAttributeString('status',$ShareName )
    $XmlWriter.WriteAttributeString('name', $ShareName)  

    $xmlWriter.WriteStartElement('Properties')
    $XmlWriter.WriteAttributeString('port', '')  
    $XmlWriter.WriteAttributeString('deleteMaps', '0')  
    $XmlWriter.WriteAttributeString('persistent', '0')  
    $XmlWriter.WriteAttributeString('deleteAll', '0')
    $XmlWriter.WriteAttributeString('skipLocal', '0')
    if ($Default) {
    	$XmlWriter.WriteAttributeString('default', '1')
    }else{
	$XmlWriter.WriteAttributeString('default', '0')
    }
    $XmlWriter.WriteAttributeString('location', '')  
    $XmlWriter.WriteAttributeString('path', ("\\"+$ComputerName+"\"+$ShareName) ) 
    $XmlWriter.WriteAttributeString('comment', '')
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

    # close the "sharedprinter" node:
    $xmlWriter.WriteEndElement()
}
end{ 
# close the "printers" node:
$xmlWriter.WriteEndElement()
 
# finalize the document:
$xmlWriter.WriteEndDocument()
$xmlWriter.Flush()
$xmlWriter.Close()
if ($openInNotepad) { notepad $Outfile }
}
}