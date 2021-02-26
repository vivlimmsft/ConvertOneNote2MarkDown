Function Remove-InvalidFileNameChars {
  param(
    [Parameter(Mandatory = $true,
      Position = 0,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true)]
    [String]$Name
  )
  $newName = $Name.Split([IO.Path]::GetInvalidFileNameChars()) -join '_'
  return ($newName.Replace(" ", "_"))
}

# ask for the Notes root path
$notesdestpath = Read-Host -Prompt "Enter the (preferably empty!) folder path (without trailing backslash!) that will contain your resulting Notes structure. ex. 'c:\temp\notes'"

if (Test-Path -Path $notesdestpath) {
  # open OneNote hierarchy
  $OneNote = New-Object -ComObject OneNote.Application
  [xml]$Hierarchy = ""
  $totalerr = ""
  $OneNote.GetHierarchy("", [Microsoft.Office.InterOp.OneNote.HierarchyScope]::hsPages, [ref]$Hierarchy)

  foreach ($notebook in $Hierarchy.Notebooks.Notebook) {
    if ($notebook.Name -eq "NOTEBOOK NAME TO EXPORT") {
      " "
      $notebook.Name
      $notebookFileName = "$($notebook.Name)" | Remove-InvalidFileNameChars
      New-Item -Path "$($notesdestpath)\" -Name "$($notebookFileName)" -ItemType "directory" -ErrorAction SilentlyContinue
      "=============="

      foreach ($sectiongroup in $notebook.SectionGroup) {
        if ($sectiongroup.isRecycleBin -ne 'true') {
          "## " + $sectiongroup.Name
        }
      }
      foreach ($section in $notebook.Section) {
        if ($section.Name -eq "SECTION NAME TO EXPORT") {
          "--------------"
          "### " + $section.Name
          $sectionFileName = "$($section.Name)" | Remove-InvalidFileNameChars
          New-Item -Path "$($notesdestpath)\$($notebookFileName)" -Name "$($sectionFileName)" -ItemType "directory" -ErrorAction SilentlyContinue
          [int]$previouspagelevel = 1
          [string]$previouspagenamelevel1 = ""
          [string]$previouspagenamelevel2 = ""
          [string]$pageexportdirsuffix = ""
          foreach ($page in $section.Page) {
            "#### " + $page.name
            #if ($page.name -eq "Documentatie") {
              # set page variables
              $recurrence = 1
              $pagelevel = $page.pagelevel
              $pagelevel = $pagelevel -as [int]
              $pageid = ""
              $pageid = $page.ID
              $pagename = ""
              $pagename = $page.name | Remove-InvalidFileNameChars
              $fullexportdirpath = ""
              $fullexportdirpath = "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)"
              $fullexportpathwithoutextension = ""
              $fullexportpathwithoutextension = "$($fullexportdirpath)\$($pagename)"
              $fullexportpath = ""
              $fullexportpath = "$($fullexportpathwithoutextension).docx"

              # make sure there is no existing Word file
              if ([System.IO.File]::Exists($fullexportpath)) {
                try {
                  Remove-Item -path $fullexportpath -Force -ErrorAction SilentlyContinue
                }
                catch {
                  Write-Host "Error removing intermediary '$($page.name)' docx file: $($Error[0].ToString())" -ForegroundColor Red
                  $totalerr += "Error removing intermediary '$($page.name)' docx file: $($Error[0].ToString())`r`n"
                }
              }

              # in case multiple pages with the same name exist in a section, postfix the filename
              if ([System.IO.File]::Exists("$($fullexportpathwithoutextension).md")) {
                $pagename = "$($pagename)_duplicate$recurrence"
                $recurrence++
              }

              # determine right name prefix based on pagelevel
              if ($pagelevel -eq 1) {
                $pageexportdirsuffix = ""
                $previouspagenamelevel1 = $pagename
                $previouspagenamelevel2 = ""
                $previouspagelevel = 1
              }
              elseif ($pagelevel -gt $previouspagelevel) {
                if ($pagelevel -eq 2) {
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)" -Name "$($previouspagenamelevel1)" -ItemType "directory" -ErrorAction SilentlyContinue
                  $pageexportdirsuffix = "$($previouspagenamelevel1)"
                  $previouspagenamelevel2 = $pagename
                  $previouspagelevel = 2
                }
                if ($pagelevel -eq 3) {
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)" -Name "$($previouspagenamelevel1)" -ItemType "directory" -ErrorAction SilentlyContinue
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)\$($previouspagenamelevel1)" -Name "$($previouspagenamelevel2)" -ItemType "directory" -ErrorAction SilentlyContinue
                  $pageexportdirsuffix = "$($previouspagenamelevel1)\$($previouspagenamelevel2)"
                  $previouspagelevel = 3
                }
              }
              elseif ($pagelevel -eq $previouspagelevel -and $pagelevel -ne 1) {
                if ($pagelevel -eq 2) {
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)" -Name "$($previouspagenamelevel1)" -ItemType "directory" -ErrorAction SilentlyContinue
                  $pageexportdirsuffix = "$($previouspagenamelevel1)"
                  $previouspagenamelevel2 = $pagename
                }
                if ($pagelevel -eq 3) {
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)" -Name "$($previouspagenamelevel1)" -ItemType "directory" -ErrorAction SilentlyContinue
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)\$($previouspagenamelevel1)" -Name "$($previouspagenamelevel2)" -ItemType "directory" -ErrorAction SilentlyContinue
                  $pageexportdirsuffix = "$($previouspagenamelevel1)\$($previouspagenamelevel2)"
                }
              }
              elseif ($pagelevel -lt $previouspagelevel -and $pagelevel -ne 1) {
                if ($pagelevel -eq 2) {
                  New-Item -Path "$($notesdestpath)\$($notebookFileName)\$($sectionFileName)" -Name "$($previouspagenamelevel1)" -ItemType "directory" -ErrorAction SilentlyContinue
                  $pageexportdirsuffix = "$($previouspagenamelevel1)"
                  $previouspagenamelevel2 = $pagename
                  $previouspagelevel = 2
                }
              }
              if ($pageexportdirsuffix) {
                $fullexportdirpath = "$($fullexportdirpath)\$($pageexportdirsuffix)"
              }
              $fullexportpathwithoutextension = "$($fullexportdirpath)\$($pagename)"

              # publish OneNote page to Word
              try {
                $OneNote.Publish($pageid, $fullexportpath, "pfWord", "")
              }
              catch {
                Write-Host "Error while publishing file '$($page.name)' to docx: $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error while publishing file '$($page.name)' to docx: $($Error[0].ToString())`r`n"
              }

              pushd "$($fullexportdirpath)"
              # convert Word to Markdown
              # https://gist.github.com/heardk/ded40b72056cee33abb18f3724e0a580
              try {
                pandoc.exe -f docx -t gfm -i $fullexportpath -o "$($fullexportpathwithoutextension).md" --wrap=none --atx-headers --extract-media="$($fullexportdirpath)"
              }
              catch {
                Write-Host "Error while converting file '$($page.name)' to md: $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error while converting file '$($page.name)' to md: $($Error[0].ToString())`r`n"
              }

              # export inserted file objects
              [xml]$pagexml = ""
              $OneNote.GetPageContent($pageid, [ref]$pagexml, 7)

              $pageinsertedfiles = $pagexml.Page.Outline.OEChildren.OE | Where-Object { $_.InsertedFile }
              foreach ($pageinsertedfile in $pageinsertedfiles) {
                $destfilename = ""
                try {
                  $destfilename = $pageinsertedfile.InsertedFile.preferredName | Remove-InvalidFileNameChars
                  Copy-Item -Path "$($pageinsertedfile.InsertedFile.pathCache)" -Destination "$($fullexportdirpath)\$($destfilename)" -Force
                }
                catch {
                  Write-Host "Error while copying file object '$($pageinsertedfile.InsertedFile.preferredName)' for page '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                  $totalerr += "Error while copying file object '$($pageinsertedfile.InsertedFile.preferredName)' for page '$($page.name)': $($Error[0].ToString())`r`n"
                }
                # Change MD file Object Name References
                try {
                  ((Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw).Replace("$($pageinsertedfile.InsertedFile.preferredName)", "[$($destfilename)](./$($destfilename))")) | Set-Content -LiteralPath "$($fullexportpathwithoutextension).md"
                }
                catch {
                  Write-Host "Error while renaming file object name references to '$($pageinsertedfile.InsertedFile.preferredName)' for file '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                  $totalerr += "Error while renaming file object name references to '$($pageinsertedfile.InsertedFile.preferredName)' for file '$($page.name)': $($Error[0].ToString())`r`n"
                }
              }

              # rename images
              $timeStamp = (Get-Date -Format o).ToString()
              $timeStamp = $timeStamp.replace(':', '')
              $re = [regex]"\d{4}-\d{2}-\d{2}T"
              $images = Get-ChildItem -Path "$($fullexportdirpath)/media" -Include "*.png", "*.gif", "*.jpg", "*.jpeg" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $re }
              foreach ($image in $images) {
                $newimageName = "$($pagename)_$($image.BaseName)_$($timeStamp)$($image.Extension)"
                # Rename Image
                try {
                  Rename-Item -Path "$($image.FullName)" -NewName $newimageName -ErrorAction SilentlyContinue
                }
                catch {
                  Write-Host "Error while renaming image '$($image.FullName)' for page '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                  $totalerr += "Error while renaming image '$($image.FullName)' for page '$($page.name)': $($Error[0].ToString())`r`n"
                }
                # Change MD file Image Name References
                try {
                  ((Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw).Replace("$($image.Name)", "$($newimageName)")) | Set-Content -LiteralPath "$($fullexportpathwithoutextension).md"
                }
                catch {
                  Write-Host "Error while renaming image file name references to '$($image.Name)' for file '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                  $totalerr += "Error while renaming image file name references to '$($image.Name)' for file '$($page.name)': $($Error[0].ToString())`r`n"
                }
              }

              # change MD file Image Path References
              try {
                # Change MD file Image Path References in Markdown
                ((Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw).Replace("$($fullexportdirpath.Replace("\","\\"))/", "")) | Set-Content -LiteralPath "$($fullexportpathwithoutextension).md"
                # Change MD file Image Path References in HTML
                ((Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw).Replace("$($fullexportdirpath)/", "")) | Set-Content -LiteralPath "$($fullexportpathwithoutextension).md"
              }
              catch {
                Write-Host "Error while renaming image file path references for file '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error while renaming image file path references for file '$($page.name)': $($Error[0].ToString())`r`n"
              }


              # Build a header to prepend to the page
              [string]$headerToAdd = "";
              # Add link to original OneNote page to the header
              try {
                [string]$link = "";
                $OneNote.GetWebHyperlinkToObject($page.ID, "", [ref]$link);

                # skip if $link is empty (local book)
                if ($link) {
                    Write-Host $link;
                    $headerToAdd = "*This page was automatically imported from OneNote. [View source OneNote page]($link)*`n$headerToAdd"
                }
              }
              catch {
                Write-Host "Error while getting hyperlink for '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error while getting hyperlink for '$($page.name)': $($Error[0].ToString())`r`n"
              }

              # Add warning about links to other onenote pages if it has any
              try {
                $content = (Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw)
                if ($content -like '*(onenote:*'){
                    Write-Host "Page contains links to other OneNote pages"
                    $headerToAdd = "*This page may contain links to other OneNote pages. Please clean those and then remove this line.*`n$headerToAdd"
                }

              }
              catch {
                Write-Host "Error checking for inter-page links for '$($page.name)': $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error checking for inter-page links for '$($page.name)': $($Error[0].ToString())`r`n"
              }

              if ($headerToAdd) {
                "$headerToAdd`n$(Get-Content -LiteralPath "$($fullexportpathwithoutextension).md" -Raw)" | Set-Content -LiteralPath "$($fullexportpathwithoutextension).md"
              }

              popd

              # Cleanup Word files
              try {
                Remove-Item -path "$fullexportpath" -Force -ErrorAction SilentlyContinue
              }
              catch {
                Write-Host "Error removing intermediary '$($page.name)' docx file: $($Error[0].ToString())" -ForegroundColor Red
                $totalerr += "Error removing intermediary '$($page.name)' docx file: $($Error[0].ToString())`r`n"
              }

              # try to clean the markdown file if markdownlint-cli is installed from npm
              if (Get-Command markdownlint -errorAction SilentlyContinue)
              {
                markdownlint -f "$($fullexportpathwithoutextension).md" | Out-Null

              }

            #}
          }
        }
      }
    }
  }
  # release OneNote hierarchy
  [System.Runtime.Interopservices.Marshal]::ReleaseComObject($OneNote)
  Remove-Variable OneNote
  $totalerr
}
else {
  Write-Host "This path is NOT valid"
}
