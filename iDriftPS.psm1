(get-childitem $PSScriptRoot\*.PS1) | foreach-object {
	. $_
}
