function global:Get-OEM-WindowsKey {
<#

            .SYNOPSIS

            This Cmdlet retrieves the windows product key from bios (for OEM licenses Windows 8 and newer).

 

            .DESCRIPTION

            This Cmdlet retrieves the windows product key from bios (for OEM licenses Windows 8 and newer).
	    It's basicly just an alias for the wmi query.

            .EXAMPLE

            Get-OEM-WindowsKey
	    XXXXX-YYYYY-XXXXX-YYYYY-XXXXX

            .LINK

            http://www.idrift.no


#>
[CmdletBinding()]
Param()
(Get-WmiObject -query ‘select * from SoftwareLicensingService’).OA3xOriginalProductKey
}