# VeilMyData
## Data concealing scripts
##
### How to use:
##
script on powershell for xoring any data with set password:
```powershell
PS > .\XorFile.ps1 "Source_File_Name" "Destination_File_Name" "Your_Secret_Password"
```
##
##
script on powershell for dividing the file into parts
```powershell
PS > .\SplitFile.ps1 "Source_File_Name" "Chunc_Size"
```
> where Chunc_Size consist of number and postfix [B | K | M | G | T]
>
> example: "1440K" or "1.44M"
##
##
script on powershell for combining parts of the file into a single file
```powershell
PS > .\MergeFile.ps1 "Source_First_File_Name"
```
> where Source_First_File_Name is name of first part with ".p001" extension
##
##
script on powershell for pack directory into one file
```powershell
PS > .\PackDir.ps1 "Source_Directory" ["Destination_File_Name"] [Is_Compress_Data] [Is_Compress_Names]
```
> where parameters in [] is optional
> 
> Is_Compress_Data and Is_Compress_Names is $true or $false (default $true)
##
##
script on powershell for unpack data from archive file to directory
```powershell
PS > .\UnpackDir.ps1 "Source_File_Name" ["Destination_Directory"]
```
> where parameters in [] is optional
