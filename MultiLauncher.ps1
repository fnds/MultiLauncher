Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$configFile = "$env:USERPROFILE\multi_launcher_profiles.json"

$profiles = @{}

if (Test-Path $configFile) {
    try {
        $raw = Get-Content $configFile -Raw | ConvertFrom-Json

        if ($raw) {
            $raw.PSObject.Properties | ForEach-Object {
                $profiles[$_.Name] = $_.Value
            }
        }
    } catch {
        $profiles = @{}
    }
}

function Save-Profiles {
    $profiles | ConvertTo-Json -Depth 10 | Set-Content $configFile
}

$script:launchedProcesses = @()
$script:selectedItem = $null

$form = New-Object Windows.Forms.Form
$form.Text = "Multi Launcher"
$form.Size = '750,640'

$profileDropdown = New-Object Windows.Forms.ComboBox
$profileDropdown.Location = '20,20'
$profileDropdown.Size = '200,25'
[void]$profileDropdown.Items.AddRange(@($profiles.Keys))

$listView = New-Object Windows.Forms.ListView
$listView.Location = '20,60'
$listView.Size = '700,220'
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.CheckBoxes = $true

[void]$listView.Columns.Add("Path", 340)
[void]$listView.Columns.Add("Arguments", 200)
[void]$listView.Columns.Add("Delay", 80)

$pathBox = New-Object Windows.Forms.TextBox
$pathBox.Location = '20,300'
$pathBox.Size = '300,25'

$argsBox = New-Object Windows.Forms.TextBox
$argsBox.Location = '330,300'
$argsBox.Size = '200,25'

$delayBox = New-Object Windows.Forms.TextBox
$delayBox.Location = '540,300'
$delayBox.Size = '60,25'
$delayBox.Text = "0"

$logBox = New-Object Windows.Forms.TextBox
$logBox.Location = '20,450'
$logBox.Size = '700,120'
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true

function Add-Log($msg) {
    $t = (Get-Date).ToString("HH:mm:ss")
    $logBox.AppendText("[$t] $msg`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}

function Start-App($path, $args, $admin, $delay) {

    if (-not (Test-Path $path)) {
        Add-Log "NOT FOUND: $path"
        return
    }

    try {
        $delaySeconds = 0
        [void][int]::TryParse($delay, [ref]$delaySeconds)

        if ($delaySeconds -gt 0) {
            Add-Log "Waiting $delaySeconds seconds before starting: $path"
            Start-Sleep -Seconds $delaySeconds
        }

        $psi = @{
            FilePath    = $path
            ErrorAction = "Stop"
        }

        if (-not [string]::IsNullOrWhiteSpace($args)) {
            $psi["ArgumentList"] = $args
        }

        if ($admin -eq $true) {
            $psi["Verb"] = "RunAs"
        }

        $p = Start-Process @psi -PassThru

        if ($p) {
            $script:launchedProcesses += $p
            Add-Log "STARTED: $path (PID $($p.Id))"

            Add-Log "Waiting for app window..."

            $timeoutSeconds = 30
            $elapsed = 0

            while ($elapsed -lt $timeoutSeconds) {
                Start-Sleep -Seconds 1
                $elapsed++

                try {
                    $p.Refresh()

                    if ($p.HasExited) {
                        Add-Log "Process exited before showing a window."
                        break
                    }

                    if ($p.MainWindowHandle -ne 0) {
                        Add-Log "App window detected."
                        break
                    }
                } catch {
                    break
                }
            }

            if ($elapsed -ge $timeoutSeconds) {
                Add-Log "Window wait timed out after $timeoutSeconds seconds. Continuing..."
            }
        }

    } catch {
        Add-Log "FAILED: $path"
        Add-Log $_.Exception.Message
    }
}

$browse = New-Object Windows.Forms.Button
$browse.Text = "Browse"
$browse.Location = '20,340'

$browse.Add_Click({
    $d = New-Object Windows.Forms.OpenFileDialog
    if ($d.ShowDialog() -eq "OK") {
        $pathBox.Text = $d.FileName
    }
})

$add = New-Object Windows.Forms.Button
$add.Text = "Add"
$add.Location = '120,340'

$listView.Add_SelectedIndexChanged({
    if ($listView.SelectedItems.Count -gt 0) {
        $script:selectedItem = $listView.SelectedItems[0]

        $pathBox.Text = $script:selectedItem.Text
        $argsBox.Text = $script:selectedItem.SubItems[1].Text
        $delayBox.Text = $script:selectedItem.SubItems[2].Text

        $add.Text = "Update"
    } else {
        $script:selectedItem = $null
        $add.Text = "Add"
    }
})

$add.Add_Click({

    if (-not $pathBox.Text) { return }

    if ($script:selectedItem) {

        $script:selectedItem.Text = $pathBox.Text
        $script:selectedItem.SubItems[1].Text = $argsBox.Text
        $script:selectedItem.SubItems[2].Text = $delayBox.Text

    } else {

        $i = New-Object Windows.Forms.ListViewItem($pathBox.Text)
        [void]$i.SubItems.Add($argsBox.Text)
        [void]$i.SubItems.Add($delayBox.Text)

        $i.Checked = $false

        [void]$listView.Items.Add($i)
    }

    $script:selectedItem = $null
    $add.Text = "Add"

    $pathBox.Clear()
    $argsBox.Clear()
    $delayBox.Text = "0"
})

$remove = New-Object Windows.Forms.Button
$remove.Text = "Remove"
$remove.Location = '200,340'

$remove.Add_Click({
    foreach ($i in $listView.SelectedItems) {
        $listView.Items.Remove($i)
    }
})

$run = New-Object Windows.Forms.Button
$run.Text = "Run All"
$run.Location = '300,340'

$run.Add_Click({
    foreach ($i in $listView.Items) {
        Start-App $i.Text $i.SubItems[1].Text ($i.Checked -eq $true) $i.SubItems[2].Text
    }
})

$runSel = New-Object Windows.Forms.Button
$runSel.Text = "Run Selected"
$runSel.Location = '400,340'

$runSel.Add_Click({
    foreach ($i in $listView.SelectedItems) {
        Start-App $i.Text $i.SubItems[1].Text ($i.Checked -eq $true) $i.SubItems[2].Text
    }
})

$stop = New-Object Windows.Forms.Button
$stop.Text = "Stop All"
$stop.Location = '520,340'

$stop.Add_Click({
    foreach ($p in $script:launchedProcesses) {
        try {
            if ($p -and -not $p.HasExited) {
                Stop-Process -Id $p.Id -Force
                Add-Log "STOPPED PID $($p.Id)"
            }
        } catch {}
    }
    $script:launchedProcesses = @()
})

$save = New-Object Windows.Forms.Button
$save.Text = "Save Profile"
$save.Location = '620,340'

$save.Add_Click({

    $name = $profileDropdown.Text
    if (-not $name) { return }

    $arr = @()

    foreach ($i in $listView.Items) {
        $arr += @{
            Path  = $i.Text
            Args  = $i.SubItems[1].Text
            Delay = $i.SubItems[2].Text
            Admin = ($i.Checked -eq $true)
        }
    }

    $profiles[$name] = $arr
    Save-Profiles

    if (-not $profileDropdown.Items.Contains($name)) {
        [void]$profileDropdown.Items.Add($name)
    }

    Add-Log "Saved profile: $name"
})

$removeProfile = New-Object Windows.Forms.Button
$removeProfile.Text = "Remove Profile"
$removeProfile.Location = '620,380'
$removeProfile.Size = '100,25'

$removeProfile.Add_Click({

    $name = $profileDropdown.Text
    if (-not $name) { return }

    if (-not $profiles.ContainsKey($name)) {
        Add-Log "Profile not found: $name"
        return
    }

    $result = [System.Windows.Forms.MessageBox]::Show(
        "Delete profile '$name'?",
        "Confirm Delete",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    [void]$profiles.Remove($name)
    Save-Profiles

    $profileDropdown.Items.Remove($name)
    $profileDropdown.Text = ""
    $listView.Items.Clear()

    Add-Log "Removed profile: $name"
})

$profileDropdown.Add_SelectedIndexChanged({
    $listView.Items.Clear()

    $name = $profileDropdown.SelectedItem
    if ($profiles[$name]) {
        foreach ($e in $profiles[$name]) {
            $i = New-Object Windows.Forms.ListViewItem($e.Path)
            [void]$i.SubItems.Add($e.Args)
            [void]$i.SubItems.Add($e.Delay)

            $i.Checked = ($e.Admin -eq $true)

            [void]$listView.Items.Add($i)
        }
    }
})

$form.Controls.AddRange(@(
    $profileDropdown,
    $listView,
    $pathBox,
    $argsBox,
    $delayBox,
    $browse,
    $add,
    $remove,
    $run,
    $runSel,
    $stop,
    $save,
    $removeProfile,
    $logBox
))

[void]$form.ShowDialog()