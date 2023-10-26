################################################################################
#                                                                              #
#                          Duplicate Media Finder                              #
#                   Written By: MSgt Anthony V. Brechtel                       #
#                                                                              #
################################################################################
clear-host
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Set-Location $dir
################################################################################
######Load Assemblies###########################################################
Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'
Add-Type -AssemblyName 'PresentationFramework'
[System.Windows.Forms.Application]::EnableVisualStyles();

################################################################################
######Load Console Scaling Support##############################################
# Dummy WPF window (prevents auto scaling).
[xml]$Xaml = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="Window">
</Window>
"@
$Reader = (New-Object System.Xml.XmlNodeReader $Xaml)
$Window = [Windows.Markup.XamlReader]::Load($Reader)
################################################################################
######Global Variables##########################################################
$script:program_title = "Duplicate Media Finder"
$script:version = "2.1"
$script:settings = @{};


######Idle Timer
#Main system timer, most functions load through this timer
if(Test-Path variable:Script:Timer){$Script:Timer.Dispose();}
$Script:Timer = New-Object System.Windows.Forms.Timer                
$Script:Timer.Interval = 1000
$Script:CountDown = 1


$script:rename_tracker = "";
$script:snapshot       = "";

$script:lock = 0; #Prevents Multiple Link Clicks
#################################################################################
######Main#######################################################################
#Load Main Form GUI
function main
{
    ##################################################################################
    ###########Main Form
    $Form = New-Object System.Windows.Forms.Form
    $Form.Location = "200, 200"
    $Form.Font = "Copperplate Gothic,9.1"
    #$Form.FormBorderStyle = "FixedDialog"
    $Form.ForeColor = "Black"
    $Form.BackColor = "#434343"
    $Form.Text = "  " + $script:program_title
    $Form.Width = 1000 #1245
    $Form.Height = 590 #590

    $Form.Add_Resize({
        resize_ui
    })


    $script:editor = New-Object System.Windows.Forms.RichTextBox
    $submit_button = New-Object System.Windows.Forms.Button
    ##################################################################################
    ###########Title Main
    $y_pos = 15
    $title1            = New-Object System.Windows.Forms.Label   
    $title1.Font       = New-Object System.Drawing.Font("Copperplate Gothic Bold",21,[System.Drawing.FontStyle]::Regular)
    $title1.Text       = $script:program_title
    $title1.TextAlign  = "MiddleCenter"
    $title1.Width      = $Form.Width
    $title1.height     = 35
    $title1.ForeColor  = "white"
    $title1.Location   = New-Object System.Drawing.Size((($Form.Width / 2) - ($title1.width / 2)),$y_pos)
    $Form.Controls.Add($title1)


    ##################################################################################
    ###########Title Written By
    $y_pos = $y_pos + 30
    $title2            = New-Object System.Windows.Forms.Label
    $title2.Font       = New-Object System.Drawing.Font("Copperplate Gothic",7.5,[System.Drawing.FontStyle]::Regular)
    $title2.Text       = "Written by: Anthony Brechtel`nVer $script:version"
    $title2.TextAlign  = "MiddleCenter"
    $title2.ForeColor  = "darkgray"
    $title2.Width      = $Form.Width
    $title2.Height     = 40
    $title2.Location   = New-Object System.Drawing.Size((($Form.Width / 2) - ($title2.width / 2)),$y_pos)
    $Form.Controls.Add($title2)


    ##################################################################################
    ###########Scan Directory Input
    $y_pos = $y_pos + 50
    $target_box = New-Object System.Windows.Forms.TextBox
    $target_box.width = 400
    $target_box.Height = 40
    $target_box.font = 'Arial,11'
    $target_box.Location = New-Object System.Drawing.Point((($Form.Width / 2) - (($target_box.width / 2))),($y_pos))
    $target_box.Text = "Browse or Enter a folder path"
    $target_box.Add_Click({
        if($target_box.Text -eq "Browse or Enter a folder path")
        {
            $target_box.Text = ""
        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false} else {$submit_button.Enabled = $true}
    })
    $target_box.Add_TextChanged({
        $script:settings['scan_directory']  = $this.text
        if($script:settings['Continue_Dir'] -ne $script:settings['scan_directory'])
        {
            $script:settings['Continue_Dir']  = $script:settings['scan_directory']
            $script:settings['Continue']      = ""
            $script:settings['Log_Folder']    = ""
            $script:settings['Match_count']   = 0
            $script:editor.text =      "";
            update_settings
        }
        else
        {

        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    ####Load Variable
    if(($script:settings['scan_directory']  -eq "") -or ($script:settings['scan_directory'] -eq $null))
    {
    }
    elseif(!(Test-Path -literalpath $script:settings['scan_directory']  -PathType Container))
    {
    }
    else
    {
       $target_box.text = $script:settings['scan_directory']
    }
    $form.Controls.Add($target_box)
    $target_box.TabStop = $false

    ##################################################################################
    ###########Scan Directory Label
    $scan_directory_label = New-Object System.Windows.Forms.Label   
    $scan_directory_label.Size = "200,23"
    $scan_directory_label.Location = New-Object System.Drawing.Point(($target_box.location.x - $scan_directory_label.width - 5),($y_pos))
    $scan_directory_label.ForeColor = "White"
    $scan_directory_label.Text = "Scan Directory:   "
    $scan_directory_label.TextAlign  = "MiddleRight"
    $form.Controls.Add($scan_directory_label)

    ##################################################################################
    ###########Scan Directory Browse Button 
    $browse1_button = New-Object System.Windows.Forms.Button
    $browse1_button.Location= New-Object System.Drawing.Size(($target_box.Location.x + $target_box.width + 5),($y_pos - 2))
    $browse1_button.BackColor = "#606060"
    $browse1_button.ForeColor = "White"
    $browse1_button.Width=105
    $browse1_button.Height=25
    $browse1_button.Text='Browse'
    $browse1_button.Add_Click(
    {    
		$prompt_return = prompt_for_folder
        if(($prompt_return -ne $Null) -and ($prompt_return -ne "") -and ((Test-Path $prompt_return) -eq $True))
        {
            #write-host $prompt_return
            $target_box.Text="$prompt_return"
        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    $form.Controls.Add($browse1_button)


    ##################################################################################
    ###########Database Name Label
    $y_pos = $y_pos + 40
    $database_name_label = New-Object System.Windows.Forms.Label 
    $database_name_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos +2 ))
    $database_name_label.Size = "200,23"
    $database_name_label.ForeColor = "White"
    $database_name_label.Text = "Use Database Name:"
    $database_name_label.TextAlign  = "MiddleRight"
    $form.Controls.Add($database_name_label)


    ##################################################################################
    ###########Database Dropdown
    $database_dropdown       = New-Object System.Windows.Forms.ComboBox
    $database_dropdown.width = 200
    $database_dropdown.autosize = $true
    $database_dropdown.font = New-Object System.Drawing.Font("Arial",11,[System.Drawing.FontStyle]::Regular)
    $database_dropdown.Location = New-Object System.Drawing.Point(($database_name_label.location.x + $database_name_label.width + 5 ),($y_pos))
    $database_dropdown.text = "Type to Create Name"
    $database_dropdown.ForeColor = [Drawing.Color]::Black
    $items = Get-childitem -Directory  $dir
    $found = 0;
    foreach($item in $items)
    {
        $database_dropdown.Items.Add($item) | Out-Null
        if([string]$item -eq [string]$script:settings['Database_Name'])
        {
            
            $found = 1;
            $database_dropdown.text = $script:settings['Database_Name']
        }
    }
    if($found -eq 0)
    {
        $script:settings['Database_Name'] = ""
        $pass_fail = check_settings
    }

    
    $database_dropdown.Add_TextChanged({

        $script:settings['Database_Name'] = $database_dropdown.text
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    $database_dropdown.Add_Click({
        if($database_dropdown.Text -eq "Type to Create Name")
        {
            $database_dropdown.Text = ""
        }
        $script:settings['Database_Name'] = $database_dropdown.text
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false} else {$submit_button.Enabled = $true; update_settings}
    })
    $form.Controls.Add($database_dropdown)
    


    
    
    ##################################################################################
    ###########Skip Known Files Label
    $skip_known_files_label = New-Object System.Windows.Forms.Label   
    $skip_known_files_label.Size = "170,23"
    $skip_known_files_label.Location = New-Object System.Drawing.Point((($target_box.Location.x + $target_box.width - $skip_known_files_label.width)),($y_pos))
    $skip_known_files_label.ForeColor = "White"
    $skip_known_files_label.Text = "Skip Known Files:"
    $skip_known_files_label.TextAlign  = "MiddleRight"
    
    $form.Controls.Add($skip_known_files_label)


    ##################################################################################
    ###########Skip Known Files Checkbox
    $skip_known_files_checkbox = new-object System.Windows.Forms.checkbox
    $skip_known_files_checkbox.Location = new-object System.Drawing.Size(($skip_known_files_label.Location.x + $skip_known_files_label.width + 5),($y_pos - 3));
    $skip_known_files_checkbox.Size = new-object System.Drawing.Size(300,30)
    $skip_known_files_checkbox.Font                     = "Copperplate Gothic,6.1"
    if(($script:settings['Skip_Known_Files'] -eq "") -or ($script:settings['Skip_Known_Files'] -eq $null))
    {
        $script:settings['Skip_Known_Files'] = 1;
    }
    if($script:settings['Skip_Known_Files'] -eq "0")
    {
        $skip_known_files_checkbox.Checked = $false
        $skip_known_files_checkbox.text = "Disabled"
        $skip_known_files_checkbox.ForeColor = "Red"
        update_settings
    }
    else
    {
        $skip_known_files_checkbox.Checked = $true
        $skip_known_files_checkbox.text = "Enabled"
        $skip_known_files_checkbox.ForeColor = "Green"
        $script:settings['Skip_Known_Files'] = 1;
        update_settings
    }
    $skip_known_files_checkbox.Add_CheckStateChanged({
        if($this.Checked -eq $true)
        {
            $this.text = "Enabled"
            $skip_known_files_checkbox.ForeColor = "Green"
            $script:settings['Skip_Known_Files'] = 1;
            update_settings
        }
        else
        {
            $this.text = "Disabled"
            $skip_known_files_checkbox.ForeColor = "Red"
            $script:settings['Skip_Known_Files'] = 0;
            update_settings
        }
    })
    $form.controls.Add($skip_known_files_checkbox);



    ##################################################################################
    ###########Media Types
    $y_pos = $y_pos + 40
    $media_types_label = New-Object System.Windows.Forms.Label 
    $media_types_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos +2 ))
    $media_types_label.Size = "200,23"
    $media_types_label.ForeColor = "White"
    $media_types_label.Text = "Media Types:"
    $media_types_label.TextAlign  = "MiddleRight"
    $form.Controls.Add($media_types_label)


    ##################################################################################
    ###########Media Selection Dropdown
    $media_dropdown                   = New-Object System.Windows.Forms.ComboBox	
    $media_dropdown.width = 120
    $media_dropdown.autosize = $true
    $media_dropdown.font = New-Object System.Drawing.Font("Arial",11,[System.Drawing.FontStyle]::Regular)
    $media_dropdown.Location = New-Object System.Drawing.Point(($media_types_label.location.x + $media_types_label.width + 5),($y_pos))
    $media_dropdown.DropDownStyle = "DropDownList"
    $media_dropdown.AccessibleName = "";
    $media_dropdown.Items.Add("Video & Photos") | Out-Null
    $media_dropdown.Items.Add("Video Only") | Out-Null
    $media_dropdown.Items.Add("Photos Only") | Out-Null
    $media_dropdown.Add_SelectedValueChanged({
        if($this.SelectedItem -eq "Video & Photos")
        {
            $script:settings['media_mode']  = 3
        }
        elseif($this.SelectedItem -eq "Video Only")
        {
            $script:settings['media_mode']  = 1
        }
        elseif($this.SelectedItem -eq "Photos Only")
        {
            $script:settings['media_mode']  = 2
        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    ########Load Settings
    if(!(($script:settings['media_mode']  -is [int]) -and ($script:settings['media_mode']  -ge 1) -and ($script:settings['media_mode']  -le 3)))
    {
        if($script:settings['media_mode'] -eq 1)
        {
            $media_dropdown.SelectedItem = "Video Only"
        }
        if($script:settings['media_mode'] -eq 2)
        {
            $media_dropdown.SelectedItem = "Photos Only"
        }
        if($script:settings['media_mode'] -eq 3)
        {
            $media_dropdown.SelectedItem = "Video & Photos"
        }
    }
    $Form.Controls.Add($media_dropdown)


    ##################################################################################
    ###########Duplicate Action Label
    $duplicate_action_label = New-Object System.Windows.Forms.Label 
    $duplicate_action_label.Size = "190,23"
    $duplicate_action_label.Location = New-Object System.Drawing.Point((($target_box.Location.x + $target_box.width - $duplicate_action_label.width - 60)),($y_pos))
    $duplicate_action_label.ForeColor = "White"
    $duplicate_action_label.Text = "Duplicate Response:"
    $duplicate_action_label.TextAlign  = "MiddleRight"
    $form.Controls.Add($duplicate_action_label)


    ##################################################################################
    ###########Duplicate Action Dropdown
    $duplicate_action_dropdown                   = New-Object System.Windows.Forms.ComboBox	
    $duplicate_action_dropdown.width = 160
    $duplicate_action_dropdown.autosize = $false
    $duplicate_action_dropdown.font = New-Object System.Drawing.Font("Arial",11,[System.Drawing.FontStyle]::Regular)
    $duplicate_action_dropdown.Location = New-Object System.Drawing.Point(($duplicate_action_label.location.x + $duplicate_action_label.width + 5),($y_pos - 3))
    $duplicate_action_dropdown.DropDownStyle = "DropDownList"
    $duplicate_action_dropdown.AccessibleName = "";
    $duplicate_action_dropdown.Items.Add("Log Duplicates") | Out-Null
    $duplicate_action_dropdown.Items.Add("Rename Duplicates") | Out-Null
    $duplicate_action_dropdown.Items.Add("Delete Duplicates") | Out-Null
    $duplicate_action_dropdown.Add_SelectedValueChanged({
        if($this.SelectedItem -eq "Log Duplicates")
        {
            $script:settings['duplicate_response'] = 0
        }
        elseif($this.SelectedItem -eq "Rename Duplicates")
        {
            $script:settings['duplicate_response'] = 1
        }
        elseif($this.SelectedItem -eq "Delete Duplicates")
        {
            $script:settings['duplicate_response'] = 2
            $message = "WARNING: This script is not 100% accurate! It is recommended to Log or Rename duplicates files. I am not responsible for lost data!"
            [System.Windows.MessageBox]::Show($message,"!!!WARNING!!!",'Ok')
        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    $duplicate_action_dropdown.SelectedItem = $script:settings['duplicate_response']
    $Form.Controls.Add($duplicate_action_dropdown)
    ########Load Settings
    if(!(($script:settings['duplicate_response']  -is [int]) -and ($script:settings['duplicate_response']  -ge 0) -and ($script:settings['duplicate_response']  -le 2)))
    {
        if($script:settings['duplicate_response'] -eq 0)
        {
            $duplicate_action_dropdown.SelectedItem = "Log Duplicates"
        }
        if($script:settings['duplicate_response'] -eq 1)
        {
            $duplicate_action_dropdown.SelectedItem = "Rename Duplicates"
        }
        if($script:settings['duplicate_response'] -eq 2)
        {
            $duplicate_action_dropdown.SelectedItem = "Delete Duplicates"
        }
    }
    $Form.Controls.Add($media_dropdown)

    ##################################################################################
    ###########ffmpeg Location Label
    $y_pos = $y_pos + 40
    $ffmpeg_location_label = New-Object System.Windows.Forms.Label 
    $ffmpeg_location_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos))
    $ffmpeg_location_label.Size = "200,23"
    $ffmpeg_location_label.ForeColor = "White"
    $ffmpeg_location_label.Text = "FFmeg Location:   "
    $ffmpeg_location_label.TextAlign  = "MiddleRight"
    $form.Controls.Add($ffmpeg_location_label)

    ##################################################################################
    ###########Scan Directory Input
    $ffmpeg_box = New-Object System.Windows.Forms.TextBox
    $ffmpeg_box.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x + $scan_directory_label.width + 5),$y_pos)
    $ffmpeg_box.width = $target_box.width
    $ffmpeg_box.Height = 40
    $ffmpeg_box.font = 'Arial,11'
    $ffmpeg_box.Text = "Browse or Enter a file path for FFmpeg.exe"
    $ffmpeg_box.Add_Click({
        if($ffmpeg_box.Text -eq "Browse or Enter a file path for FFmpeg.exe")
        {
            $ffmpeg_box.Text = ""
        }
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false} else {$submit_button.Enabled = $true}
    })
    $ffmpeg_box.Add_TextChanged({
    
        $script:settings['ffmpeg']  = $ffmpeg_box.text
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false; update_settings} else {$submit_button.Enabled = $true; update_settings}
    })
    ###Load Settings
    if(($script:settings['ffmpeg']  -eq "") -or ($script:settings['ffmpeg']  -eq $null))
    {
    }
    elseif(!(Test-Path -literalpath $script:settings['ffmpeg']  -PathType Leaf))
    {
    }
    elseif(!($script:settings['ffmpeg']  -match "ffmpeg.exe"))
    {
    }
    else
    {
        $ffmpeg_box.Text = $script:settings['ffmpeg']

    }
    $form.Controls.Add($ffmpeg_box)


    ##################################################################################
    ###########Scan Directory Browse Button 
    $browse2_button = New-Object System.Windows.Forms.Button
    $browse2_button.Location= New-Object System.Drawing.Size(($ffmpeg_box.Location.x + $ffmpeg_box.width + 5),$y_pos)
    $browse2_button.BackColor = "#606060"
    $browse2_button.ForeColor = "White"
    $browse2_button.Width=105
    $browse2_button.Height=25
    $browse2_button.Text='Browse'
    $browse2_button.Add_Click(
    {    
		$prompt_return = prompt_for_file
        if(($prompt_return -ne "") -and ($prompt_return -like "*.exe*") -and ((Test-Path -literalpath $prompt_return) -eq $True))
        {
            $ffmpeg_box.Text = $prompt_return
            $script:settings['ffmpeg']  = $prompt_return
        }
 
        $pass_fail = check_settings
        if($pass_fail -eq 0){$submit_button.Enabled = $false} else {$submit_button.Enabled = $true}
    })
    $form.Controls.Add($browse2_button)


    ##################################################################################
    ###########ffmpeg Download Label
    $y_pos = $y_pos + 28
    $ffmpeg_download_label = New-Object System.Windows.Forms.Label 
    $ffmpeg_download_label.width = $Form.Width
    $ffmpeg_download_label.location = New-Object System.Drawing.Size((($Form.Width / 2) - ($ffmpeg_download_label.Width / 2)),$y_pos)
    $ffmpeg_download_label.ForeColor = "Green"
    $ffmpeg_download_label.Text = "Download FFmpeg"
    $ffmpeg_download_label.TextAlign  = "Middlecenter"
    $ffmpeg_download_label.add_click({
        Start-Process "https://ffmpeg.org/download.html#build-windows"
    });
    $form.Controls.Add($ffmpeg_download_label)


    #####################################################################################################
    #############Editor 
    $y_pos = $y_pos + 25  
    $script:editor.Size                                    = New-Object System.Drawing.Size(($Form.Width - 30),($Form.Height - 440))
    $script:editor.Location                                = New-Object System.Drawing.Size((($Form.Width / 2) - ($script:editor.width / 2) - 10),$y_pos) 
    $script:editor.ReadOnly                                = $true
    $script:editor.WordWrap                                = $False
    $script:editor.Multiline                               = $True
    $script:editor.BackColor                               = "white"
    $script:editor.Font                                    = New-Object System.Drawing.Font("Arial",12.5,[System.Drawing.FontStyle]::Regular)
    $script:editor.ScrollBars                              = "vertical"
    $script:editor.RichTextShortcutsEnabled                = $false
    $script:editor.AutoWordSelection                       = $false
    $script:editor.shortcutsenabled                        = $false
    $script:editor.DetectUrls                              = $false
    $Form.Controls.Add($script:editor)
    $script:editor.HideSelection = $true
    $script:editor.Clear()

    $script:snapshot = $script:settings['Log_Folder'] + "\Snapshot.txt"
    if(($script:snapshot -ne "") -and ($script:snapshot -ne $null) -and (Test-Path -LiteralPath $script:snapshot))
    {
        $script:editor.rtf = Get-Content $script:snapshot
    }
    $script:editor.Add_Click({ 
        if($_.Button -eq [System.Windows.Forms.MouseButtons]::Left ) 
        {   
            if($script:lock -ne 1)
            {
                $script:lock = 1;       
                textbox_open_file
                [System.Windows.Forms.SendKeys]::SendWait("%{ESC}")
                $Form.focus()
                $Form.BringToFront();
                $script:editor.SelectionLength = 0;
                $form.TopMost = $true
                $form.TopMost = $false 
                $script:lock = 0;
            }
        }  
    })

    
    ##################################################################################
    ###########Run Scan Button
    $submit_button = New-Object System.Windows.Forms.Button
    $submit_button.Location= New-Object System.Drawing.Size((($Form.width / 2) - 100),($script:editor.location.y + $script:editor.Height + 5))
    $submit_button.BackColor = "#606060"
    $submit_button.ForeColor = "White"
    $submit_button.Width=200
    $submit_button.Height=25
    $submit_button.Text='Run Scan'
    $submit_button.Add_Click(
    {    
		if($this.text -eq "Run Scan")
        {
            if($script:settings['Continue'] -ne "")
            {
                $message = "Would you like to continue from your last scan?`n`n"
                $yesno = [System.Windows.Forms.MessageBox]::Show("$message","Continue Previous Scan?", "YesNo" , "Information" , "Button1")
                if($yesno -eq "No")
                {
                    $script:settings['Continue']      = ""
                    $script:settings['Log_Folder']    = "";
                    $script:settings['Database_Type'] = ""
                    $script:settings['Continue_Dir']  = ""
                    $script:settings['Log_Folder']    = ""
                    $script:settings['Match_count']   = 0
                    $script:editor.text        = "";
                    update_settings
                }
            }
            else
            {
                $script:settings['Log_Folder']       = "";
            }
            if($script:settings['Log_Folder'] -eq "")
            {
                #write-host reset
                $script:editor.text  = "";
            }
            $this.Text = "Stop Running..."
            $progress_bar.Show();
            $target_box.enabled = $false
            $database_dropdown.enabled = $false
            $media_dropdown.enabled = $false
            $browse1_button.enabled = $false
            $browse2_button.enabled = $false
            $ffmpeg_box.enabled = $false
            $duplicate_action_dropdown.enabled = $false
            run_scan
        }
        else
        {
            #$script:editor.Clear()
            Stop-Job -job $script:cycler_job
            Remove-Job -job $script:cycler_job
            $progress_bar.Hide()
            $this.Text = "Run Scan"
            $progress_bar.Value = "0"
            $progress_bar_label.Text = ""
            $target_box.enabled = $true
            $database_dropdown.enabled = $true
            $media_dropdown.enabled = $true
            $browse1_button.enabled = $true
            $browse2_button.enabled = $true
            $ffmpeg_box.enabled = $true
            $duplicate_action_dropdown.enabled = $true
        }
    })


    ##################################################################################
    ###########Progress Bar
    $progress_bar = New-Object System.Windows.Forms.ProgressBar
    $progress_bar.Minimum = 0
    $progress_bar.Maximum = 100
    $progress_bar.Value = 0
    $progress_bar.Style="Continuous"
    $progress_bar.Location = new-object System.Drawing.Size($script:editor.location.x, ($submit_button.location.y + $submit_button.height + 5));
    $progress_bar.size = new-object System.Drawing.Size($script:editor.width,25)
    $progress_bar.MarqueeAnimationSpeed = 20
    $Form.Controls.Add($progress_bar)


    ##################################################################################
    ###########Progress Bar Status Label
    $progress_bar_label = New-Object System.Windows.Forms.Label 
    $progress_bar_label.Location = New-Object System.Drawing.Size($progress_bar.location.x, ($progress_bar.location.y + $progress_bar.height + 5));
    $progress_bar_label.width = $progress_bar.width
    $progress_bar_label.height = 50
    $progress_bar_label.TextAlign  = "MiddleCenter"
    $progress_bar_label.ForeColor = "White"
    $progress_bar_label.Text = ""
    $progress_bar_label.Font = "Arial,10.5"
    $progress_bar_label.Add_click({
        $load1 = $script:settings['Log_Folder'] + "\Log_Updated.xlsx"
        $load2 = $script:settings['Log_Folder'] + "\Log.xlsx"
        $load3 = $script:settings['Log_Folder'] + "\Log_Updated.csv"
        $load4 = $script:settings['Log_Folder'] + "\Log.csv"
        $logs = ($load1,$load2,$load3,$load4)
        foreach($log in $logs)
        {
            if(Test-Path -LiteralPath $log)
            {
                write-host Loading: $log
                Start-Process $log
                break;
            }
        }        
    })
    $Form.Controls.Add($progress_bar_label)


    $Form.controls.Add($submit_button)
    $pass_fail = check_settings
    if($pass_fail -eq 0){$submit_button.Enabled = $false} else {$submit_button.Enabled = $true}

    [void] $Form.ShowDialog()
}
#################################################################################
######Open Links ################################################################
#Opens URLs Inside Editor
function textbox_open_file
{  
    $script:editor.Refresh()
    $front = "";
    $index_end = $script:editor.SelectionStart;
    $back = ""
    $index_start = $script:editor.SelectionStart;
    For ($i=0; $i -le ($script:editor.text.Length - $script:editor.SelectionStart); $i++) 
    {
        $temp = "";
        if(!(($script:editor.SelectionStart + $i) -ge $script:editor.text.Length))
        {
            $temp = $script:editor.text.Substring(($script:editor.SelectionStart + $i),1);
        }
        $front = $front + $temp
        $index_end = $script:editor.SelectionStart + $i
        if($front -match "`n")
        {
            break
        } 
    }        
    For ($i = $script:editor.SelectionStart - 1; $i -ge 0; $i--) 
    {
        $temp = $script:editor.text.Substring($i,1);
        $back =  $temp + $back
        $index_start = $i
        if($back -match "`n")
        {
            $index_start++
            break
        } 
    }
    $line = $script:editor.text.substring($index_start,($index_end -$index_start))
    $line_split = $line -split '\s{2,}'
        

    
    foreach($split in $line_split)
    {
        if(($split -ne "") -and ($split -ne $null) -and ($split.length -ge 5) -and (Test-Path -LiteralPath $split))
        {
            #write-host $split
            & explorer.exe $split
        }
    }
}
#################################################################################
######Update UI##################################################################
#Function Updates GUI Elements When Window is Resized
function resize_ui
{
    $y_pos = 15
    $title1.Location   = New-Object System.Drawing.Size((($Form.Width / 2) - ($title1.width / 2)),$y_pos)
    $y_pos = $y_pos + 30
    $title2.Location   = New-Object System.Drawing.Size((($Form.Width / 2) - ($title2.width / 2)),$y_pos)
    $y_pos = $y_pos + 50

    $target_box.Location = New-Object System.Drawing.Point((($Form.Width / 2) - (($target_box.width / 2))),($y_pos))
    $scan_directory_label.Location = New-Object System.Drawing.Point(($target_box.location.x - $scan_directory_label.width - 5),($y_pos))
    $browse1_button.Location= New-Object System.Drawing.Size(($target_box.Location.x + $target_box.width + 5),($y_pos - 2))

    $y_pos = $y_pos + 40
    $database_name_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos +2 ))
    $database_dropdown.Location = New-Object System.Drawing.Point(($database_name_label.location.x + $database_name_label.width + 5 ),($y_pos))
    $skip_known_files_label.Location = New-Object System.Drawing.Point((($target_box.Location.x + $target_box.width - $skip_known_files_label.width)),($y_pos))
    $skip_known_files_checkbox.Location = new-object System.Drawing.Size(($skip_known_files_label.Location.x + $skip_known_files_label.width + 5),($y_pos - 3));


    $y_pos = $y_pos + 40
    $media_types_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos +2 ))
    $media_dropdown.Location = New-Object System.Drawing.Point(($media_types_label.location.x + $media_types_label.width + 5),($y_pos))
    $duplicate_action_label.Location = New-Object System.Drawing.Point((($target_box.Location.x + $target_box.width - $duplicate_action_label.width - 60)),($y_pos))
    $duplicate_action_dropdown.Location = New-Object System.Drawing.Point(($duplicate_action_label.location.x + $duplicate_action_label.width + 5),($y_pos - 3))

    $y_pos = $y_pos + 40

    $ffmpeg_location_label.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x),($y_pos))
    $ffmpeg_box.Location = New-Object System.Drawing.Point(($scan_directory_label.Location.x + $scan_directory_label.width + 5),$y_pos)
    $browse2_button.Location= New-Object System.Drawing.Size(($ffmpeg_box.Location.x + $ffmpeg_box.width + 5),$y_pos)

    $y_pos = $y_pos + 28
    $ffmpeg_download_label.location = New-Object System.Drawing.Size((($Form.Width / 2) - ($ffmpeg_download_label.Width / 2)),$y_pos)

    $y_pos = $y_pos + 25
    $script:editor.Size                                    = New-Object System.Drawing.Size(($Form.Width - 30),($Form.Height - 440))
    $script:editor.Location                                = New-Object System.Drawing.Size((($Form.Width / 2) - ($script:editor.width / 2) - 10),$y_pos)
    $submit_button.Location= New-Object System.Drawing.Size((($Form.width / 2) - 100),($script:editor.location.y + $script:editor.Height + 5))
    $progress_bar.width = $script:editor.Width
    $progress_bar.Location = New-Object System.Drawing.Size($script:editor.location.x, ($submit_button.location.y + $submit_button.height + 5));
    $progress_bar_label.Location = New-Object System.Drawing.Size($progress_bar.location.x, ($progress_bar.location.y + $progress_bar.height + 5));
    $progress_bar_label.width = $progress_bar.width
    $Form.Refresh()

}
#################################################################################
######Check Settings ############################################################
#Validates User Input Settings
function check_settings
{
    $pass_fail = 1

    ###################
    if(($script:settings['scan_directory']  -eq "") -or ($script:settings['scan_directory'] -eq $null))
    {
        $pass_fail = 0;
        #write-host Failed Directory1 $script:settings['scan_directory'] 
    }
    elseif(!(Test-Path -literalpath $script:settings['scan_directory']  -PathType Container))
    {
        $pass_fail = 0;
        #write-host Failed Directory2 $script:settings['scan_directory'] 
    }
    ###################
    if($script:settings['Database_Name'] -eq "")
    {
        $pass_fail = 0;
    }
    if($script:settings['Database_Name'] -eq "Type to Create Name")
    {
        $pass_fail = 0;
    }
    if($script:settings['Database_Name'] -match "\<|>|\:|`/|\\|\?|\*")
    {
        $pass_fail = 0;
    }

    ###################
    if(!(($script:settings['media_mode']  -is [int]) -and ($script:settings['media_mode']  -ge 1) -and ($script:settings['media_mode']  -le 3)))
    {
        $pass_fail = 0;
        #write-host Failed Mode $script:settings['media_mode'] 
    }

    ###################
    if(!(($script:settings['duplicate_response'] -is [int]) -and ($script:settings['duplicate_response'] -ge 0) -and ($script:settings['duplicate_response'] -le 2)))
    {
        $pass_fail = 0; 
        #write-host Failed Response $script:settings['duplicate_response']
    }

    ###################
    if(($script:settings['ffmpeg']  -eq "") -or ($script:settings['ffmpeg']  -eq $null))
    {
        $pass_fail = 0;
        #write-host Failed FF1 $script:settings['ffmpeg'] 
    }
    elseif(!(Test-Path -literalpath $script:settings['ffmpeg']  -PathType Leaf))
    {
        $pass_fail = 0;
        #write-host Failed FF2 $script:settings['ffmpeg'] 
    }
    elseif(!($script:settings['ffmpeg']  -match "ffmpeg.exe"))
    {
        $pass_fail = 0;
        #write-host Failed FF3 $script:settings['ffmpeg'] 
    }

    ####################
    if($pass_fail -eq 1)
    {
        update_settings
    }

    #write-host PassFail = $pass_fail
    #write-host -----------------
    return $pass_fail
}
################################################################################
######Prompt for Folder ########################################################
#Browse for Folder Button Support Function
function prompt_for_folder()
{  
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $folder_dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folder_dialog.Description = "Select Target folder"
    $folder_dialog.rootfolder = "MyComputer"

    if($folder_dialog.ShowDialog() -eq "OK")
    {
        $folder = $folder_dialog.SelectedPath
    }
    return $folder
}
################################################################################
######Prompt for File ##########################################################
#Browse for File Button Support Function
function prompt_for_file()
{  
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null
    $file_dialog = New-Object System.Windows.Forms.OpenFileDialog
    $file_dialog.initialDirectory = "::{20D04FE0-3AEA-1069-A2D8-08002B30309D}"
    $file_dialog.filter = "Files (*.exe)|*.exe"
    $file_dialog.ShowDialog() | Out-Null
    $file = $file_dialog.filename        
    return $file
}
################################################################################
######Update Settings ##########################################################
#Saves User Settings
function update_settings
{
    if($script:settings.count -ne 0)
    {
        if(Test-Path "$dir\Buffer_Settings.csv")
        {
            Remove-Item -LiteralPath "$dir\Buffer_Settings.csv"
        }
        $buffer_settings = new-object system.IO.StreamWriter("$dir\Buffer_Settings.csv",$true)
        $buffer_settings.write("PROPERTY,VALUE`r`n");
        foreach($setting in $script:settings.getEnumerator() | Sort key)
        {
                $setting_key = $setting.Key                                               
                $setting_value = $setting.Value
                $buffer_settings.write("$setting_key,$setting_value`r`n");
        }
        $buffer_settings.close();
        if(test-path -LiteralPath "$dir\Buffer_Settings.csv")
        {
            if(Test-Path -LiteralPath "$dir\Settings.csv")
            {
                Remove-Item -LiteralPath "$dir\Settings.csv"
            }
            Rename-Item -LiteralPath "$dir\Buffer_Settings.csv" "$dir\Settings.csv"
        }
    } 
}
################################################################################
######Load Settings ############################################################
#Loads User Settings into Memory
function load_settings
{
    if(Test-Path -literalpath "$dir\Settings.csv")
    {
        $line_count = 0;
        $reader = [System.IO.File]::OpenText("$dir\Settings.csv")
        while($null -ne ($line = $reader.ReadLine()))
        {
            $line_count++;
            if($line_count -ne 1)
            {
                ($key,$value) = $line -split ',',2
                if(!($script:settings.containskey($key)))
                {
                    $script:settings.Add($key,$value);
                }
            } 
        }
        $reader.close();
    }
}
####################################################################################################################################################################
####################################################################################################################################################################  
####################################################################################################################################################################
#################################################################################
######Run Scan ##################################################################
#Main Child Process for Image Matching System
function run_scan
{
$script:cycler_job_block = {
###############################################################################
#####Global Vars###############################################################
Add-Type -AssemblyName 'System.Drawing'            #Needed for Image Processing
$shell = New-Object -ComObject Shell.Application   #Needed for getting extended file details
$script:settings = $using:settings;                #Carry Settings From Parent
$script:dir = $using:dir                           #Carry Directory From Parent
Set-Location $dir

################################################################################
#####Basic Settings#############################################################
        
#$scan_directory = $script:settings['scan_directory']
    #This is the directory you will be looking for duplicate videos in (Recursively)

#$media_mode = $script:settings['media_mode']
    #Determines what media to look at
    #1 = Videos
    #2 = Images
    #3 = Both Images & Videos

#$script:settings['duplicate_response']
    #When a duplicate is found, what do you want to do with it?
    #0 = Log it
    #1 = Rename It
    #2 = Delete it (Not Recommended)


#$script:settings['Skip_Known_Files']
    #Skip files that are already in the database 
    #0 = Scan all Files
    #1 = Skip Known Files with Keys

$script:ffmpeg = $script:settings['ffmpeg']
$script:ffprobe = $script:settings['ffmpeg'] -replace "ffmpeg.exe","ffprobe.exe"
    #Location of FFmpeg & FFprobe Location


################################################################################
#####Advnaced Settings##########################################################
$script:max_zones = 7
    #Zones divide the sample image into grid sections.
    #Zones are squared. e.g. 3 = 9, 4 = 16, 5 = 25
    #Too many zones will impact key generation time and will multiply your keys.

$script:max_keys = 2;
    #Keys are unique identifiers within zones, the more keys the more precise the image detection will be. 
    #However, more keys will have a substantial impact on speed.
    #Keys are multipled by zones:
    #e.g. 4 keys with 5 Zones (Zones are squared) would provide (4 * (5 *5)) = 100 Keys (Per Image) 2x Images = 200 keys.

$script:color_distance_video_phase1 = 28
$script:color_distance_image_phase1 = 5;
    #Color Distance for Database Key Matching

$script:color_distance_video_phase2 = 28;
$script:color_distance_image_phase2 = 28;
    #Color Distance for Key-to-Key Matching

$script:key_integrity_threshold = 50
    #Fingerprints Missing this amount or more will be Invalidated

$script:gradients_max = 3;
    #Gradients Provide Each key a step up and a step down in color. This is useful for videos that have been brightened or darkened.
    #Gradients double, so increasing by 1 will double the amount of gradients.
    #e.g. Gradient of 1 will provide a single key 2 additional colors. 
    #e.g. Gradient of 2 will provide a single key 4 additional colors.
    #e.g. Gradient of 3 will provide a single key 6 additional colors.

$script:screenshots = 2;
    #Sample screenshots will pluck an image out of the video to compare key against.
    #Keys are divided amongst screenshots. e.g. If you have

$script:weight_threshold = 8;
    #Each Color has a percentage of a zone it fills. This will allow a percentage offset of X%.
    #e.g. 0 means the color weight percentages must be identical.
    #e.g. 100 means the color weight perecentage doesn't matter

$script:duration_threshold = 25
    #Scaled Determination on seconds overlap in time.
    #e.g. Set at 25 = 4 Seconds for a 30 Second video
    #e.g. Set at 25 = 34 Seconds for a 120 minute video

$script:keep_screenshots = 0;
    #0 = Will Delete Screenshots
    #1 = Will Keep Screenshots

$script:debug = 0;
    #0 = Off
    #1 = On
    #Will Generate Color Maps for Images



################################################################################
#####Global System Variables####################################################
$script:existing_keys = @{};                                           #Holds entries for Database Keys that already exist
$script:finger_prints = @{};                                           #Holds the current file's fingerprints
$script:possible_dbs  = @{};                                           #List of Current Files Potential Database Matches
$script:duplicate_tracker = @{}                                        #Holds list of all previously matched duplicates
$script:BitMap        = "";                                            #Holds Screenshot Bitmap
$script:zones_squared = $script:max_zones * $script:max_zones          #Zones are squared (Common enough to be global)
$script:gradients_max = $script:gradients_max * 5;                     #Holds Max Gradients for Colors (Multiplier)
$script:database = "";                                                 #Scanned File Database
$script:db_folder = ""                                                 #Root Folder For Database
$script:db_location = "";                                              #Provides a Central Root for Active Database
$script:db_videos = ""                                                 #Root Folder For Video Database 
$script:db_images = ""                                                 #Root Folder For Image Database

$script:color_distance_phase1 = 0;                                     #Switches Between Video & Images
$script:color_distance_phase2 = 0;                                     #Switches Between Video & Images
$script:superior_file = "";                                            #The Current Superior File
$script:duplicate_file = "";                                           #The Current Duplicate File
[int]$script:settings['Match_Count'] = $script:settings['Match_Count'] #Converts to [Int]
[int]$script:overall_red = 0;                                          #Overall Red Value for Current File
[int]$script:overall_green = 0;                                        #Overall Green Value for Current File
[int]$script:overall_blue = 0;                                         #Overall Blue Value for Current File
$script:local_run = 0                                                  #Used for Non-GUI testing
$script:full_path_modified = ""                                        #Used to last Minute Rename

################################################################################
#####Scan Dir Variables ########################################################
###Scan Dir Vars
$script:file_list = "";                                                #Holds all Files being scanned
$script:file_count = 0;                                                #Holds Total File Number
$script:file_counter = 0;                                              #Holds Current File Count


###Process Tracking Vars
$script:eta_average_total = 0;                                         #Holds the Average File Process Run Time 
$script:skipped_files = 0;                                             #Counter for Skipped Files                                               
$script:process_time_start = Get-Date                                  #Process Start
$script:process_time_end = Get-Date                                    #Process End

###File Related
$script:object = "";                                                   #Current File Object
$script:full_path = "";                                                #Current File's Full path
$script:extension = "";                                                #Current File Extension
$script:media_type = "";                                               #Current File is Video or Image
$script:duration = 0                                                   #Current File Duration
$script:sample_screenshots = 1                                         #Screenshot # Switch Variable for Images & Video


###############################################################################
#####Send Single Ouput#########################################################
#Communication Pipeline Between Child and Parent Processes
function send_single_output
{
    $output = "";
    foreach($arg in $args)
    {
        $output = "$output" + "$arg"
    }
    if($script:local_run -eq 1)
    {
        if($output -match "-ForegroundColor")
        {
            $out_split = $output -split "-ForegroundColor | ",3
            $color = $out_split[1]
            $text  = $out_split[2]
            write-host -ForegroundColor $color "$text"
        }
        elseif(!($output -match "^PL-|^PB-|^TXR-|^TX-|^SNAP-|^UP-|^LN-"))
        {
            write-host $output 
        }
    }
    else
    {
        write-output $output
    }
}       
################################################################################
#####Environment Print##########################################################
send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
send_single_output "-ForegroundColor Cyan " "Scan Directory: " $script:settings['scan_directory']
send_single_output "-ForegroundColor Cyan " "Database Name: " $script:settings['Database_Name']
send_single_output "-ForegroundColor Cyan " "FFmpeg: " $script:ffmpeg
send_single_output "-ForegroundColor Cyan " "FFprobe: " $script:ffprobe
send_single_output "-ForegroundColor Cyan " "Media Mode: " $script:settings['media_mode']
send_single_output "-ForegroundColor Cyan " "Duplicate Response: " $script:settings['duplicate_response']
send_single_output "-ForegroundColor Cyan " "Dir: " $dir
send_single_output "-ForegroundColor Cyan " "Continue From: " $script:settings['Continue']
send_single_output "-ForegroundColor Cyan " "Skip Known?: " $script:settings['Skip_Known_Files']
send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
send_single_output " "
################################################################################
####Initial Checks #############################################################
#Verifies Folder Structure Integrity
function initial_checks
{
    ############################################
    ##Verify Input
    if(($script:settings['Continue'] -ne "") -and (!(Test-Path -LiteralPath $script:settings['Continue'])))
    {
        send_single_output "-ForegroundColor Red " "Continue File Invalid - Starting From Scratch"
        $script:settings['Continue'] = "";
    }
    ############################################
    #Create Database Directory
    $script:db_folder = "$dir\" + $script:settings['Database_Name']
    $script:db_videos = "$script:db_folder\Color Database Videos"
    $script:db_images = "$script:db_folder\Color Database Images"

    ############################################
    ##Create Database Structure
    if(!(Test-Path -LiteralPath $script:db_folder))
    {
        New-Item -ItemType Directory "$script:db_folder" | Out-Null
    }
    if(!(Test-Path -LiteralPath "$script:db_folder\Screenshots"))
    {
        New-Item -ItemType Directory "$script:db_folder\Screenshots" | Out-Null
    }
    if(!(Test-Path -LiteralPath "$script:db_folder\Logs"))
    {
        New-Item -ItemType Directory "$script:db_folder\Logs" | Out-Null
    }

    if(!(Test-Path -LiteralPath $script:db_images))
    {
        New-Item -ItemType Directory $script:db_images | Out-Null
    }
    if(!(Test-Path -LiteralPath $script:db_videos))
    {
        New-Item -ItemType Directory $script:db_videos | Out-Null
    }

    if($script:debug -eq 1)
    {
        if(Test-Path -LiteralPath "$script:db_folder\Debug1")
        {
            Get-ChildItem -LiteralPath "$script:db_folder\Debug1" -Include *.* -File -Recurse | foreach { $_.Delete()}
        }
        if(!(Test-Path -LiteralPath "$script:db_folder\Debug1"))
        {
            New-Item -ItemType Directory "$script:db_folder\Debug1" | Out-Null
        }       
    }
    ############################################
    ##Create Log Files
    if(($script:settings['Log_Folder'] -eq $null) -or ($script:settings['Log_Folder'] -eq"") -or (!(Test-Path $script:settings['Log_Folder'])))
    {
        $script:settings['Log_Folder'] = build_log_entry
        $script:settings['Log_Folder'] = "$script:db_folder\Logs\" + $script:settings['Log_Folder'] 
        New-Item -ItemType Directory $script:settings['Log_Folder'] | Out-Null     
        $script:settings['Log_File']           =  $script:settings['Log_Folder'] + "\Log.csv";
        $script:settings['Rename_Tracker']     =  $script:settings['Log_Folder'] + "\Rename Tracker.txt";
        Add-Content -LiteralPath $script:settings['Log_File'] "Mode,Source,Destination,File Match,Pass Level,Direct Hits,Direct Zone Hits,Direct Zone Avg,Direct Weight,Grad Hits,Grad Zone Hits,Grad Zone Avg,Grad Weight,Combined Hits,Combined Zones,Combined Zone Avg,Combined Weight,Super Direct,Super Grad,Super Ultra"
        Add-Content -LiteralPath $script:settings['Rename_Tracker'] "Original Duplicate File & Parent File"
    }
    send_single_output "Log-" $script:settings['Log_Folder']
    
    ############################################
}
################################################################################
####Build Log Entry ############################################################
#Generates a Unique File Log Entry
function build_log_entry
{  
    $date = Get-Date -Format G
    [regex]$pattern = " "
    $date = $pattern.replace($date, " @ ", 1);
    $date = $date.replace('/',"-");
    $date = $date.replace(':',".");
    return $date
}
################################################################################
######Load & Verify Existing Keys ##############################################
function load_existing_keys
{
    $script:databases = "";
    if($script:settings['media_mode'] -eq 1)
    {
        $script:databases = ($script:db_videos);
    }
    elseif($script:settings['media_mode'] -eq 2)
    {
        $script:databases = ($script:db_images);
    }
    else
    {
        $script:databases = ($script:db_videos,$script:db_images);
    }

    $script:eta_average_total = 0; 
    foreach($database in $script:databases)
    {
        $color_files = Get-ChildItem -literalpath $database -Filter *.txt
        $script:file_count = $color_files.count
        $script:file_counter = 0;
        foreach($file in $color_files)
        {
            $script:process_time_start = Get-Date

            if(!($file -match "_temp"))
            {
                $script:file_counter++;          
                $this_db = $file.fullName
                $this_db_temp = $this_db -replace ".txt$","_temp.txt"
                $line_count = 0;
                $db_hash = @{};
                ######################              
                $reader = New-Object IO.StreamReader $this_db      
                while($null -ne ($line = $reader.ReadLine()))
                {
                    $line_count++;
                    $file_path = $line.Substring(($line.IndexOf(",") + 1),(($line.Length - ($line.IndexOf(",") + 1))))
                    $file_path = $file_path -replace "`"",""
                    ##########################################################
                    ###Load Keys into Existing Keys
                    if(!($script:existing_keys.Contains($file_path)))
                    {
                        if(Test-Path -LiteralPath $file_path)
                        {
                            #write-host $file_path
                            $mystream = [IO.MemoryStream]::new([byte[]][char[]]$file_path)
                            $file_hash = (Get-FileHash -InputStream $mystream -Algorithm SHA256)
                            $file_hash = $file_hash.hash.substring(0,5);
                            [string]$size = [int](((Get-Item -LiteralPath $file_path).length/1kb))
                            $size = $size.padleft(7," ");
                            $file_hash = "$file_hash" + "$size"

                            if($line.substring(23,12) -eq $file_hash)
                            {
                                $script:existing_keys.Add($file_path,$this_db) #Update Key Database
                            }
                        }
                    }
                    ##########################################################
                    ###Verified Lines
                    if($script:existing_keys.ContainsKey($file_path))
                    {
                        if(!($db_hash.ContainsKey($line)))
                        {
                            $db_hash.add($line,"")
                        }
                    }
                }
                $reader.Close()
                ################################################################################
                ######Write Hash################################################################
                $reader.Close()
                #send_single_output "Hash Count: " $db_hash.count $script:existing_keys.count
                if(($db_hash.count -ne 0) -and ($db_hash.count -ne $line_count)) #Hash Reveals Duplicate Lines or Missing Paths
                {
                    #send_single_output "Hash & File Mismatch!"
                    $writer = [System.IO.StreamWriter]::new($this_db_temp) 
                    foreach($entry in $db_hash.getEnumerator() | Sort key)
                    {
                        $writer.WriteLine($entry.key)
                    }
                    $writer.Close()
                    if(Test-Path -LiteralPath $this_db_temp)
                    {
                        #send_single_output "Deleted: " $this_db
                        Remove-Item -LiteralPath $this_db
                        Rename-Item -LiteralPath $this_db_temp $this_db
                        #send_single_output "Renamed: " $this_db_temp
                    }
                }
                elseif($db_hash.count -eq 0) #No Valid Entries - Delete DB
                {
                    
                    if(Test-Path -LiteralPath $this_db)
                    {
                        #send_single_output "No Valid Keys! - Removed $this_db"
                        Remove-Item -LiteralPath $this_db
                    }
                }  
            }
            else
            {
                Remove-Item -LiteralPath $file.fullName
            }
            $time_left = 0;
            $script:process_time_end = Get-Date
            $eta = NEW-TIMESPAN -Start $script:process_time_start -End $script:process_time_end
            $script:eta_average_total = ($eta.TotalMilliseconds + $script:eta_average_total);
            $eta_estimate = (($script:eta_average_total / $script:file_counter) * ($script:file_count - $script:file_counter))
            $eta =  [timespan]::FromMilliseconds($eta_estimate)
            [string]$days    = [string]$eta.Days + " Days"
            [string]$hours   = [string]$eta.Hours + " Hours"
            [string]$minutes = [string]$eta.minutes + " Minutes"
            [string]$seconds = [string]$eta.seconds + " Seconds"     
            if($eta.Days -ne 0){$time_left = "$days $hours $minutes $seconds left"}
            elseif($eta.Hours -ne 0){$time_left = "$hours $minutes $seconds left"}
            elseif($eta.minutes -ne 0){$time_left = "$minutes $seconds left"}
            elseif($eta.seconds -ne 0){$time_left = "$seconds"}
            
            $status = (($script:file_counter / $script:file_count) * 100)
            send_single_output "PB-$status"
            send_single_output "PL-" $time_left " To Load Keys ($script:file_counter / $script:file_count Files)"
        }  
    }
}
################################################################################
######Scan Directory Main ######################################################
function scan_directory
{
    ################################################################################
    ####Media Mode File Scan #######################################################
    #Slurp File Directory to $script:file_list
    ####INPUTS####


    media_mode_file_scan
    
    ####OUTPUTS####         
    $script:file_count = $script:file_list.count;
    $script:file_counter = 0;
  

    ################################################################################
    ####Scan Each File##############################################################
    $script:eta_average_total = 0;        #Reset ETA
    send_single_output "PB-0"             #Set GUI Process Bar to Zero
    foreach($script:object in $script:file_list | sort FullName)
    {
        if(!(Test-Path -LiteralPath $script:object.FullName))
        {
            send_single_output "-ForegroundColor Yellow " "File was renamed during execution: " $script:object.FullName     
            Continue;
        }


        ################################################################################
        ####Current File Global Variables###############################################      
        $folder      = $shell.Namespace($script:object.DirectoryName)             #Not Common....
        $file        = $folder.ParseName($script:object.Name)                     #Not Common....
        $script:full_path   = $script:object.FullName
        $script:full_path_modified = ""
        $script:extension  = $script:object.Extension
        $script:duration    = $folder.GetDetailsOf($file, 27)

        ########Default Vars
        $script:possible_dbs = @{};           #Holds all possible matching DBs
        $script:finger_prints = @{}           #Holds Scan File Finger Prints
        $script:process_time_start = Get-Date #Start Process
        $script:file_counter++;               #Increment Counts
        $script:media_type = "Failed"         #Type of media Images/Video
        $script:database = ""                 #Save File Name of Database
        $script:db_location = ""              #Video or Image DB Location
        $script:duration_seconds = 0;         #Flat Numerical Value in seconds
        $script:duration_offset = 0;          #Provides Left & Right boundy for video time limits
        $script:color_distance_phase1 = 0     #Switch Variable for Video/Image Color Distance
        $script:color_distance_phase2 = 0     #Switch Variable for Video/Image Color Distance
        $script:file_load = "No"              #Determine if keys Came from Existing File

        ########Default Color Vars
        [int]$script:overall_red = 0;
        [int]$script:overall_green = 0;
        [int]$script:overall_blue = 0;

            
        ################################################################################
        ####Continue From Last Scan#####################################################
        #Skips to a previous scan stop point
        continue_from_last_scan
        

        ################################################################################
        ####Skip Database Files ########################################################
        $script:skipit = "No"
        #Skips Files in Database
        skip_database_files
        if($script:skipit -eq "Yes"){Continue;}


        ################################################################################
        ####Print Header ###############################################################
        send_single_output " "
        send_single_output "-ForegroundColor Cyan " "     -----------------------------------------------------------------------------------------"
        send_single_output " "
        send_single_output "     Working on: $script:full_path"


        ################################################################################
        ####Determine Media Type########################################################
        determine_media_type
        if($script:media_type -eq "Skip"){Continue;}
        #OUTPUTS
        #$script:media_type
        #$script:sample_screenshots
        #$script:db_location
        #$script:color_distance_phase1
        #$script:color_distance_phase2
        #$script:duration                           #--Duplicated
        #$script:duration_seconds                   #--Duplicated
        #$script:duration_offset                    #--Duplicated
          

        ################################################################################
        ####Load Keys From File#########################################################
        load_keys_from_file
        ####OUTPUTS####
        #$script:finger_prints
        #$script:file_load
        #$script:overall_red
        #$script:overall_blue
        #$script:overall_green
        #$script:duration_seconds                   #--Duplicated


        ################################################################################
        ####Verify Keys ################################################################
        verify_keys
        ####INPUTS####
        #$script:file_load
        #$script:key_integrity_threshold
        #$script:finger_prints
        #$script:max_keys
        #$script:zones_squared

        ####OUTPUTS####
        #$script:file_load      #Resets
        #$script:finger_prints  #Resets
        #$script:overall_green  #Resets
        #$script:overall_blue   #Resets


        ################################################################################
        ####Generate Fresh Keys#########################################################
        $script:generate_keys_try = 0;
        generate_keys
        if($script:finger_prints.count -lt 10)
        {
            send_single_output "-ForegroundColor Red " "     ERROR: " $script:finger_prints.count " Keys Generated - Retrying With Method 2"
            $script:generate_keys_try = 1;
            $script:finger_prints = @{}
            generate_keys
        }
        if($script:finger_prints.count -lt 10)
        {
            send_single_output "-ForegroundColor Red " "     ERROR: " $script:finger_prints.count " Keys Generated - Retrying With Method 3"
            $script:generate_keys_try = 2;
            $script:finger_prints = @{}
            generate_keys
        }
        if($script:finger_prints.Count -eq 0)
        {
            send_single_output "-ForegroundColor Red " "     ERROR: Zero Keys Generated - Possibly Corrupt File!"
            continue;
        }
        else
        {
            send_single_output "     Generated " $script:finger_prints.Count " Keys"
        }  
        ####INPUTS####
        #$script:finger_prints
        #$script:file_load
        #$script:zones_squared
        #$script:max_keys
        #$script:sample_screenshots
        #$script:media_type
        #$script:duration_seconds
        #$script:db_folder
        #$script:object
        #$script:extension
        #$script:ffmpeg
        #$script:full_path
        #$script:BitMap
        #$script:color_hash
        #$script:keep_screenshots
        #$script:debug

        ####SUB FUNCTIONS####
        #get_color_hash
        #build_zone_fingerprints

        ####OUTPUTS####
        #$script:BitMap
        #$script:color_hash
        #$script:overall_red
        #$script:overall_blue
        #$script:overall_green

        
        ################################################################################
        ###Fix this monstrostiy....Duration runs 3x times at different points.
        [string]$duration_s = [string]([string]$script:duration_seconds).PadLeft(5," ");
        $color_db = $script:overall_red + $script:overall_blue + $script:overall_green + $duration_s
        $script:database = $script:db_location + $color_db + ".txt"
        $script:database_temp = $script:db_location + $color_db + "_temp.txt"



        ################################################################################
        ####Find Similar Databases######################################################
        find_similar_databases
        ####INPUTS####
        #$script:color_distance_phase1
        #$script:db_location
        #$script:duration_seconds
        #$script:duration_offset
        #$script:overall_red
        #$script:overall_blue
        #$script:overall_green

        ####SUB FUNCTIONS####
        #measure_color_distance

        ####OUTPUTS####
        #$script:possible_dbs
        send_single_output "     Possible DBs: " $script:possible_dbs.count


        ################################################################################
        ####Find Duplicates############################################################# 
        ####INPUTS####
        $script:direct_zone_hits = @{};
        $script:direct_zone_hits_tracker = @{};
        $script:direct_hit_weights = @{};
        $script:grad_zone_hits = @{};
        $script:grad_zone_hits_tracker = @{};
        $script:grad_hit_weights = @{};
        $script:color_weight_size = 0;
        $script:gradient_max_weight = 0;
                 
        find_duplicates
        
        ####SUB FUNCTIONS####
        #measure_color_distance

        ####OUTPUTS####
        #$script:direct_zone_hits
        #$script:direct_zone_hits_tracker
        #$script:direct_hit_weights   
        #write-host Grad Zone Hits: $script:grad_zone_hits.count
        #$script:grad_zone_hits_tracker
        #$script:grad_hit_weights
        #$script:color_weight_size
        #$script:gradient_max_weight
     
       
        ################################################################################
        ####Calculate Direct Hit Metrics################################################
        ####INPUTS####
        $script:direct_hit_file = ""
	    $script:direct_hits_count = 0
        $script:direct_hits_percentage = 0;
        $script:direct_zone_hits_percent = 0;
        $script:direct_hits_zone_average = 0;
        $script:direct_hits_zone_average_percent = 0;
        $script:direct_hits_zone_count = 0;     
        $script:direct_hit_weight = 0
        $script:direct_hit_weight_percent = 0   
        #$script:direct_zone_hits
        #$script:direct_zone_hits_tracker
        #$script:direct_hit_weights

        calculate_direct_hit_metrics
       
        ####OUTPUTS####
        send_single_output "     ----------------"
        send_single_output "     Direct Hits: ($script:direct_hits_count/" $script:finger_prints.count ") $script:direct_hits_percentage%"
        send_single_output "     Zones Hits: ($script:direct_hits_zone_count/$script:zones_squared) $script:direct_zone_hits_percent%"
        send_single_output "     Zone Avg: ($script:direct_hits_zone_average/$script:max_zone_avg) $script:direct_hits_zone_average_percent%"
        send_single_output "     Direct Hit Weight: ($script:direct_hit_weight/$script:color_weight_size) $script:direct_hit_weight_percent%";
       

        ################################################################################
        ####Calculate Gradient Hit Metrics##############################################
        ####INPUTS####
        $script:grad_hit_file                  = ""
        $script:grad_hits_count                = 0;
        $script:grad_hits_percentage           = 0;
        $script:grad_zone_hits_percent         = 0;
        $script:grad_hits_zone_average         = 0;
        $script:grad_hits_zone_average_percent = 0;
        $script:grad_hits_zone_count           = 0;
        $script:grad_hit_weight                = 0;
        $script:grad_hit_weight_percent        = 0;
        #$script:finger_prints
        #$script:direct_hit_file
        #$script:grad_zone_hits_tracker
        #$script:grad_hit_weights

        calculate_gradient_hit_metrics

        ####OUTPUTS####
        send_single_output "     ----------------"
        send_single_output "     Grad Hits: ($script:grad_hits_count/$script:gradients_total) $script:grad_hits_percentage%"
        send_single_output "     Grad Zones Hit: ($script:grad_hits_zone_count/$script:zones_squared) $script:grad_zone_hits_percent%"
        send_single_output "     Grad Avg Zone: ($script:grad_hits_zone_average/$script:max_zone_avg) $script:grad_hits_zone_average_percent%"
        send_single_output "     Grad Hit Weight: ($script:grad_hit_weight/$script:gradient_max_weight) $script:grad_hit_weight_percent%";


        ################################################################################
        ####Calculate Combined & Super Metrics##########################################
        ####INPUTS####
        $script:combined_hit_percent        = 0;
        $script:combined_zones              = 0;
        $script:combined_avg_zone_percent   = 0;
        $script:combined_zone_percent       = 0;
        $script:combined_hit_weight         = 0;
        $script:combined_weight_percent     = 0;
        $script:super_number_direct         = 0;
        $script:super_number_grad           = 0;
        $script:super_ultra                 = 0;
           
        calculate_combined_hit_metrics

        ####OUTPUTS####
        send_single_output "     ----------------"
        send_single_output "     Combined Hit: $script:combined_hit_percent%"
        send_single_output "     Combined Zone: $script:combined_zone_percent%"
        send_single_output "     Combined Avg Zone: $script:combined_avg_zone_percent%"
        send_single_output "     Combined Weight: $script:combined_weight_percent%"
        send_single_output "     ----------------"
        send_single_output "     Super Number Direct: $script:super_number_direct%"
        send_single_output "     Super Number Grad: $script:super_number_grad%"
        send_single_output "     Super Number ultra: $script:super_ultra%"
        send_single_output "     ----------------"


        ################################################################################
        ####Determine if Duplicate Video################################################
        ####INPUTS####
        $script:is_duplicate = "No"
        $script:pass_level = "";
        #$script:direct_hit_file
        #$script:media_type
        #$script:direct_hits_percentage
        #$script:grad_zone_hits_percent
        #$script:super_number_direct
        #$script:super_ultra
        #$script:combined_zone_percent

        detect_duplicate_video

        ####OUTPUTS####
        #$script:is_duplicate


        ################################################################################
        ####Determine if Duplicate Image################################################
        ####INPUTS####
        #$script:is_duplicate
        #$script:media_type
        #$script:direct_hit_file
        #$script:direct_hits_percentage
        #$script:direct_zone_hits_percent

        detect_duplicate_image

        ####OUTPUTS####
        #$script:is_duplicate
        #$pass_level

        ################################################################################
        ####Point Duplicates to Parent #################################################
        if(($script:is_duplicate -ne "No") -and ($script:direct_hit_file -ne "") -and ($script:direct_hit_file -match " - Duplicate \d+"))
        {
            $parent = $script:direct_hit_file -replace " - Duplicate \d+"
            $child = $script:direct_hit_file
            if(Test-Path -LiteralPath $parent)
            {
                send_single_output "     Duplicate of Duplicate Found - Pointing to Parent"
                send_single_output "     Parent: $parent"
                send_single_output "     Child: $child"
                $script:direct_hit_file = $parent
            }
        }


        ################################################################################
        ####Pick Best File #############################################################
        ####INPUTS####
        $script:superior_file = "";
        $script:duplicate_file = "";

        pick_best_file $script:full_path $script:direct_hit_file

        ####OUTPUTS####
        #$script:superior_file = "";
        #$script:duplicate_file = "";


        ############################################################################
        ####Duplicate Response Actions #############################################
        $script:action = "";
        $script:new_name = "";
        $script:found = 0;
        duplicate_response_actions


        ################################################################################
        #####Update Database ###########################################################
        update_database


        ################################################################################
        #####Merge Duplicates ##########################################################
        merge_duplicates
        

        ################################################################################
        #####End File Scan Process #####################################################
        end_file_scan_process
        if($script:is_duplicate -ne "No")
        {
            send_single_output "SNAP-"
        }
           
    }#Foreach File
    if($script:skipped_files -ne 0)
    {
        send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
        send_single_output "-ForegroundColor Yellow " $script:skipped_files " Files Were Skipped!"
    }
}#Scan Directory
################################################################################
####Media Mode File Scan #######################################################
#Slurps File Directory 
function media_mode_file_scan
{
    if($script:settings['media_mode'] -eq "1")
    {
        $script:file_list = Get-ChildItem -LiteralPath $script:settings['scan_directory'] -File -Recurse -ErrorAction SilentlyContinue | where {$_.extension -in ".avi",".gif",".mp4",".mpeg",".mkv",".rm",".mpg",".m4v",".flv",".wmv",".ogm"}
    }
    elseif($script:settings['media_mode'] -eq "2")
    {
        $script:file_list = Get-ChildItem -LiteralPath $script:settings['scan_directory'] -File -Recurse -ErrorAction SilentlyContinue | where {$_.extension -in ".png",".jpeg",".jpg",".bmp"}
    }
    elseif($script:settings['media_mode'] -eq "3")
    {
        $script:file_list = Get-ChildItem -LiteralPath $script:settings['scan_directory'] -File -Recurse -ErrorAction SilentlyContinue | where {$_.extension -in ".avi",".gif",".mp4",".mpeg",".mkv",".rm",".mpg",".m4v",".flv",".wmv",".ogm",".png",".jpeg",".jpg",".bmp"}
    }
}
################################################################################
####Continue From Last Scan#####################################################
#Skips to file from a previous scan
function continue_from_last_scan
{  
    if(($script:settings['Continue'] -ne "") -and ($script:settings['Continue'] -ne $script:object.FullName))
    {
        $script:skipped_files++
        continue;
    }
    elseif($script:settings['Continue'] -ne "")
    {
        send_single_output "     Starting at: " $script:settings['Continue']
        if($script:skipped_files -ne 0)
        {
            send_single_output "     Skipped: $script:skipped_files files"
        }
        $script:settings['Continue'] = "";
        continue;
    }
}
################################################################################
####Skip Database Files ########################################################
#Skips Files in Database
function skip_database_files
{
    $script:skipit = "No"
    if((($script:settings['Skip_Known_Files'] -eq 1) -and ($script:existing_keys.Contains($script:object.FullName))) -or (($script:settings['Skip_Known_Files'] -eq 1) -and ($script:object.FullName -match " - Duplicate \d+")))
    {
        $script:skipit = "Yes"
        if($script:object.FullName -match " - Duplicate \d+")
        {
            send_single_output " "
            send_single_output "-ForegroundColor Cyan " "     -----------------------------------------------------------------------------------------"
            send_single_output " "
            send_single_output "     Skipped Duplicate: " $script:object.FullName
            $script:superior_file = $script:object.FullName -replace " - Duplicate \d+",""
            $script:duplicate_file = $script:object.FullName

            if(!(Test-path -LiteralPath $script:superior_file))
            {
                send_single_output "-ForegroundColor Red " "     Missing " $script:superior_file
            }

            $script:settings['Match_Count']++;
            $script:action = "Previous Match"
            log_it
            send_single_output "-ForegroundColor Green " "     Superior File:  $script:superior_file"
            send_single_output "-ForegroundColor Green " "     Duplicate File: $script:duplicate_file"
          
            send_single_output "TXR-" " "
            send_single_output "TXR-" "Previous Match " $script:settings['Match_Count']
            send_single_output "TX-" "Superior File   "
            send_single_output "LN-"  "$script:superior_file"
            send_single_output "TX-" "Duplicate File  "
            send_single_output "LN-" "$script:duplicate_file"
            end_file_scan_process
        }
        else
        {

            #send_single_output " "
            #send_single_output "-ForegroundColor Cyan " "     -----------------------------------------------------------------------------------------"
            #send_single_output " "
            #send_single_output "     Skipped: " $script:object.FullName
            end_file_scan_process
        }
        $script:skipped_files++
    }
}
################################################################################
####Determine Media Type########################################################
function determine_media_type
{
    if($script:extension -match ".jpg$|.png$|.jpeg$")
    {
        $script:media_type = "Image"        
        $script:sample_screenshots = 1
        $script:db_location = $script:db_images + "\"
        $script:color_distance_phase1 = $script:color_distance_image_phase1
        $script:color_distance_phase2 = $script:color_distance_image_phase2   
        $script:duration = 0;
    }
    elseif($script:extension -match ".avi$|.mp4$|.mpeg$|.mkv$|.rm$|.mpg$|.m4v$|.flv$|.wmv$|.ogm$|.gif$")
    {
        $script:media_type = "Video"     
        $script:sample_screenshots = $script:screenshots
        $script:db_location = $script:db_videos + "\"
        $script:color_distance_phase1 = $script:color_distance_video_phase1
        $script:color_distance_phase2 = $script:color_distance_video_phase2  

        ##Intitial Duration Attempt
        ([int]$hours,[int]$minutes,[int]$seconds) = $script:duration -split ":"
        [int]$script:duration_seconds = (($seconds + ($minutes * 60) + ($hours * 60 * 60)))
        [int]$script:duration_offset = [Math]::Log10($script:duration_seconds) * ([Math]::Sqrt($script:duration_seconds) * 2) * ($script:duration_threshold / 100)

        if(($script:extension -match ".gif$") -or ($script:duration_seconds -eq 0))
        {
            #send_single_output "FF $script:ffprobe"
            [string]$execute = & cmd /u /c  "$script:ffprobe -i `"$script:full_path`" -show_streams -select_streams a 2>&1"
            $script:duration = $execute.Substring(($execute.IndexOf("Duration:") + 10),8)
            ([int]$hours,[int]$minutes,[int]$seconds) = $script:duration -split ":"
            [int]$script:duration_seconds = (($seconds + ($minutes * 60) + ($hours * 60 * 60)))
            [int]$script:duration_offset = [Math]::Log10($script:duration_seconds) * ([Math]::Sqrt($script:duration_seconds) * 2) * ($script:duration_threshold / 100)
        }
    }
    else
    {
        send_single_output "Media Type Failed!"
        send_single_output "     $script:full_path"
        send_single_output " "
        $script:media_type = "Skip"
    }
}
################################################################################
####Load Keys From File#########################################################
#Loads a files Fingerprints into Memory
function load_keys_from_file
{     
    if($script:existing_keys.Contains($script:full_path))
    {
        $script:file_load = "Yes"
        load_fingerprints $script:full_path $script:media_type
        send_single_output "     Fingerprints Loaded:" $script:finger_prints.count

        $base_key = [io.path]::GetFileNameWithoutExtension($script:existing_keys[$script:full_path])
        [int]$script:overall_red       = $base_key.substring(0,3);
        [int]$script:overall_blue      = $base_key.substring(3,3);
        [int]$script:overall_green     = $base_key.substring(6,3);
        #[int]$script:duration_seconds  = $base_key.substring(9,5);
    }
}
################################################################################
######Load Existing Keys########################################################
function load_fingerprints($script:full_path)
{
    $color_file = "";
    $script:duplicate_count = 0; #This is for Merged Duplicates in keys "D" variable
    if($script:existing_keys.Contains($script:full_path))
    {
        $color_file = $script:existing_keys[$script:full_path]

    }
    if($color_file -ne "")
    {
        $script:finger_prints = @{};
        $reader = New-Object IO.StreamReader $color_file
        while($null -ne ($line = $reader.ReadLine()))
        {
            $line_array = csv_line_to_array $line
            #write-output 
            if(($line_array -ne $null) -and ($line_array[0] -ne $null) -and ($line_array[1] -ne $null))
            {    
                if(($line_array[1] -eq $script:full_path))
                {
                    if(!($script:finger_prints.Contains($line_array[0])))
                    {
                        $script:finger_prints.Add($line_array[0],$line_array[1]);
                    }
                }
            }
        }
        $reader.Close()
    }
}
################################################################################
####Verify Keys ################################################################
#Verifies Fingerprint Integrity
function verify_keys
{
    if(($script:file_load -eq "Yes") -and ($script:finger_prints.count -lt (($script:max_keys * $script:zones_squared)) - $script:key_integrity_threshold))
    {
        $script:file_load = "No"
        $script:finger_prints = @{};
        [int]$script:overall_red = 0;
        [int]$script:overall_green = 0;
        [int]$script:overall_blue = 0;
        send_single_output "-ForegroundColor Red " "     Invalid Keys"
            
        ####Find Location of File
        if($script:existing_keys.Contains($script:full_path))
        {
            $color_file = $script:existing_keys[$script:full_path]
        }

        ####Build Temp File
        $color_file_temp = $color_file -replace ".txt$","_temp.txt"
        if(Test-Path -LiteralPath $color_file_temp)
        {
            Remove-Item -LiteralPath $color_file_temp
        }

        ####Scrub File Of Keys
        if($color_file -ne "")
        {
            $line_found = 0;   
            $writer = [System.IO.StreamWriter]::new($color_file_temp) 
            $reader = New-Object IO.StreamReader $color_file
            while($null -ne ($line = $reader.ReadLine()))
            {
                if(!($line -match [Regex]::Escape("$script:full_path")))
                {
                    $line_found = 1;
                    $writer.WriteLine($line)
                }
            }
            $reader.Close()
            $writer.Close()
            if(($line_found -eq 1) -and (Test-Path -LiteralPath $color_file_temp))
            {
                Remove-Item -LiteralPath $color_file
                Rename-Item -LiteralPath $color_file_temp $color_file
            }
            else
            {
                Remove-Item -LiteralPath $color_file
                Remove-Item -LiteralPath $color_file_temp
            }
        }
    }
}
################################################################################
####Generate Fresh Keys#########################################################
function generate_keys
{
    if($script:finger_prints.count -eq 0)
    {
        send_single_output "     Generating Fresh Keys"
           
        $script:file_load = "No"
        $script:finger_prints = @{}
            
        $stop_threshold = 0;
        $threshold_increment = ((($script:zones_squared * $script:max_keys) / $script:sample_screenshots) / $script:zones_squared)

        $sample_count = 1;
        $projected_name = "";

        ################################################################################
        ####Foreach Screenshot##########################################################
        while($sample_count -le $script:sample_screenshots)
        { 
            ################################################################################
            ####Capture Screenshot##########################################################
            if($script:media_type -eq "Video")
            {
                    
                [int]$sample_location = ((($script:duration_seconds / $script:sample_screenshots) / 2) * ($sample_count + $sample_count - 1))
                $projected_name = "$script:db_folder\Screenshots\" + ($script:object.Name -replace "$script:extension$","_$sample_count") + ".bmp"
                if(Test-Path -LiteralPath $projected_name)
                {
                    Remove-Item -LiteralPath $projected_name
                }
                try
                {
                    $console = & cmd /u /c  "$script:ffmpeg -i `"$script:full_path`" -hide_banner -loglevel error -ss $sample_location -vframes 1 `"$projected_name`" -y"

                    #send_single_output "-ForegroundColor Red " "SS $sample_location"
                }
                catch
                {
                    write-host "Command Failed"

                }

                if(Test-Path -LiteralPath $projected_name)
                {
                    try{$script:BitMap.Dispose();}catch{}
                    [System.GC]::GetTotalMemory(‘forcefullcollection’) | out-null
                    $script:BitMap = [System.Drawing.Bitmap]::FromFile((Resolve-Path -literalpath $projected_name).ProviderPath)
                }
                else
                { 
                    send_single_output "-ForegroundColor Red " "     Failed Image!"
                }                
                send_single_output "     Building Keys for Screenshot $sample_count @ $sample_location Seconds"
            }
            else
            {
                $projected_name = $script:full_path
                $sample_location = 0;
                send_single_output "     Building Keys for $script:full_path"
                $script:BitMap = [System.Drawing.Bitmap]::FromFile((Resolve-Path -literalpath $projected_name).ProviderPath)
            }


            ################################################################################
            ####Get Color Hash##############################################################
            if(($script:BitMap -ne "") -and ($projected_name -ne "Failed"))
            {

                if($BitMap.Height -gt $BitMap.Width)
                {
                    $orientation = "V"
                }
                else
                {
                    $orientation = "H"
                }
                ##Do Run For each Screenshot
                $run_count = 0;
                while($stop_threshold -lt ([int](($script:max_keys * $script:zones_squared) / $script:sample_screenshots) * $sample_count))
                {
                    $run_count++
                        
                    #########################################
                    ##Run count will try to extract images if first round failed
                    if($run_count -eq 2)
                    {
                        break;
                    }
                        
                    $zone = 0;
                    $zone_height_count = 0;
                    while($zone_height_count -lt $script:max_zones)
                    {
                        $zone_height_count++
                        $zone_width_count = 0;
                        while($zone_width_count -lt $script:max_zones)
                        {
                            $zone++;
                            $zone_width_count++
                            $script:color_hash = @{};
                            get_color_hash $zone_height_count $zone_width_count
                            if($script:color_hash.count -ne 0)
                            {
                                [int]$stop_threshold = $stop_threshold + $threshold_increment
                                build_zone_fingerprints $zone $orientation $sample_location $script:object.Name $script:full_path $stop_threshold $script:extension
                            }
                        }
                    }
                }#Each Screenshot
                $script:BitMap.Dispose()
                if($script:media_type -eq "Video")
                {
                    if(($script:debug -eq 0) -and ($script:keep_screenshots -eq 0))
                    {
                        if(Test-Path -LiteralPath $projected_name)
                        {
                            Remove-Item -LiteralPath $projected_name
                        }
                    }
                }
            }
            $sample_count++
        }#Samples
        ################################################################################
        ####Get Overall Color########################################################### 
        [int]$script:overall_red = ($script:overall_red / $script:finger_prints.Count)
        [int]$script:overall_blue  = ($script:overall_blue / $script:finger_prints.Count)
        [int]$script:overall_green  = ($script:overall_green / $script:finger_prints.Count)

        [string]$script:overall_red = [string]([string]$script:overall_red).padleft(3," ");    
        [string]$script:overall_blue = [string]([string]$script:overall_blue).padleft(3," ");
        [string]$script:overall_green = [string]([string]$script:overall_green).padleft(3," ");    
    }
}
################################################################################
####Get Color Hash##############################################################
#Generates a Zone's Color Hash
function get_color_hash($zone_height_location,$zone_width_location)
{
    $pixel_hash = @{};
    ########################################
    #Zone from Center or Zone entire image
    $height_start = 0;
    $height_end = 0;
    $width_start = 0;
    $width_end = 0;

    $thirds_height = ($script:BitMap.Height /3); 
    $thirds_width = ($script:BitMap.width /3);
    $zone_size_height = ($thirds_height / ($script:max_zones))
    $zone_size_width = ($thirds_width / ($script:max_zones))
    [int]$height_start = $thirds_height + (($zone_height_location - 1) * $zone_size_height)
    [int]$height_end = $height_start + $zone_size_height
    [int]$width_start = $thirds_width + (($zone_width_location - 1) * $zone_size_width)
    [int]$width_end = $width_start + $zone_size_width

    if($height_start -eq 0)
    {
        $height_start = 1;
    } 
    if($width_start -eq 0)
    {
        $width_start = 1;
    }
    if($height_end -gt $script:BitMap.Height)
    {
        $height_end = $script:BitMap.Height
    }
    if($width_end -gt $script:BitMap.width)
    {
        $width_end = $script:BitMap.width
    }
    
    foreach($h in $height_start..$height_end)
    {
        foreach($w in $width_start..$width_end) 
        {
            try
            {
                $pixel = $script:BitMap.GetPixel(($w - 1),($h - 1));


                if($script:generate_keys_try -eq 0)
                {
                    #send_single_output "Method 1"
                    $red = ($pixel.r - ($pixel.r % 5))
                    $blue = ($pixel.b - ($pixel.b % 5))
                    $green = ($pixel.g - ($pixel.g % 5))
                    $red   = ([string]$red).PadLeft(3," ");
                    $blue  = ([string]$blue).PadLeft(3," ");
                    $green = ([string]$green).PadLeft(3," ");
                }
                else
                {
                    #send_single_output "Method 2"
                    $red = $pixel.r
                    $blue = $pixel.b
                    $green = $pixel.g
                    $red   = ([string]$red).PadLeft(3," ");
                    $blue  = ([string]$blue).PadLeft(3," ");
                    $green = ([string]$green).PadLeft(3," ");
                }
                
                $pixel = "$red" + "$blue" + "$green"
                if(!($pixel_hash.ContainsKey($pixel)))
                {
                    $pixel_hash.Add($pixel,1);
                    #send_single_output $pixel
                }
                else
                {
                    $pixel_hash[$pixel]++;
                }
            }catch{}
        }
    }

    ############Calculate Weight by Percentage of Zone
    $total_size = ($pixel_hash.Values | Measure-Object -Sum).Sum
    foreach($color in $pixel_hash.GetEnumerator() | Sort Value -Descending)
    {
        [int]$zone_weight_percent = (($color.value / $total_size) * 100);
        $pixel_hash[$color.key] = $zone_weight_percent
    }
    $script:color_hash = $pixel_hash
}
################################################################################
####Build Fingerprints##########################################################
#Creates a Finger Print for a File
function build_zone_fingerprints($zone,$orientation, $duration,$file_name,$fullpath,$stop_threshold,$script:extension)
{
    #############################################################
    #############################################################
    #Finger Print File Name Guide
    #Note: Multiple Files May Share a Fingerprint in a Single File Name
    #$f  = "75 53 55   12.txt"
    #$f1 = $f.Substring(0,3)  #Overall Red Color of File
    #$f2 = $f.Substring(3,3)  #Overall Blue Color of File
    #$f3 = $f.Substring(6,3)  #Overall Green Color of File
    #$f4 = $f.Substring(9,5)  #Duration of File

    #############################################################
    #############################################################
    #Finger Print File Contents Guide
    #$l = "38 180130150V   15   4 00899  11594,Test File Name.mp4"
    #$l1  = $l.Substring(0,2)  #Zone (Grid location on an Image)
    #$l2  = $l.Substring(2,1)  #Color Mode (Blank Space = Color / G = Grayscale / D = Deep Scan)
    #$l3  = $l.Substring(3,3)  #Pixel's Red Color
    #$l4  = $l.Substring(6,3)  #Pixel's Blue Color
    #$l5  = $l.Substring(9,3)  #Pixel's Green Color
    #$l6  = $l.Substring(12,1) #Orientation (H = Horiztonal / V = Vertical)
    #$l7  = $l.Substring(13,5) #ScreenShot Location in Seconds
    #$l8  = $l.Substring(18,4) #Color Weight (How Prevelent is this color in this Zone)
    #$l9  = $l.Substring(23,5) #First 5 Characters of a MD5 Filehash
    #$l10 = $l.Substring(28,7) #File Size in KB
    #$l11 = $l.Substring(36,($l.Length - 36)) #File Name Associated with Key

    #write-host Zone:         $l1
    #write-host Color Mode:   $l2
    #write-host Red Pixel:    $l3
    #write-host Blue Pixel:   $l4
    #write-host Green Pixel:  $l5
    #write-host Orientation:  $l6
    #write-host ScreenShot:   $l7
    #write-host Color Weight: $l8
    #write-host First 5 Hash: $l9
    #write-host File Size:    $l10
    #write-host File Name:    $l11
    #############################################################
    #############################################################

    $key_count = 1;
    [string]$zone_s = $zone
    [string]$zone_s = $zone_s.PadLeft(2," ");

    
    $mystream = [IO.MemoryStream]::new([byte[]][char[]]$script:full_path)
    $file_hash = (Get-FileHash -InputStream $mystream -Algorithm SHA256)
    $file_hash = $file_hash.hash.substring(0,5);
    [string]$size = [int](((Get-Item -LiteralPath $script:full_path).length/1kb))
    $size = $size.padleft(7," ");
    $file_hash = "$file_hash" + "$size"
    [string]$duration_s = $duration
    $duration_s = $duration_s.PadLeft(5," ");
    
    #send_single_output "Duration: " $duration_s

    if($debug -eq 1)
    {
        $html_file = "$script:db_folder\Debug1\$file_name" -replace "$script:extension$",".html"
        if(($zone -eq 1) -and (Test-Path -LiteralPath $html_file))
        {
            Remove-Item -LiteralPath $html_file
        }
        Add-Content -literalpath "$html_file" "<H2>Zone: $zone</h2>"
        $hex_color = "";
    }

    $found_color = 0;
    ################################################################################
    ####Get Primary Colors##########################################################
    foreach ($color in $script:color_hash.GetEnumerator() | sort value -Descending )
    {
        [string]$color_weight_s = $color.value
        [string]$color_weight_s = $color_weight_s.padleft(4," ");
        $color = $color.key

        
        [int]$red = $color.substring(0,3);
        [int]$blue = $color.substring(3,3);
        [int]$green = $color.substring(6,3);
       
        if($script:debug -eq 1)
        {
            $hex_red   = [System.Convert]::ToString($red,16)  
            $hex_green = [System.Convert]::ToString($green,16)
            $hex_blue = [System.Convert]::ToString($blue,16)
            $hex_color = "#$hex_red$hex_green$hex_blue";
        }
        
        ################################################################################
        ####Remove Grayscale############################################################
        if(!(($red -eq $blue ) -and ($red -eq $green)))
        {
            #send_single_output "Key $color"
            if(((($red -gt 20) -and ($blue -gt 20) -and ($green -gt 20)) -and (($red -le 235) -and ($blue -le 235) -and ($green -le 235))) -or ($script:generate_keys_try -ge 1))
            {
                
                if((!(($red -eq $green) -and (([int]$blue - $red) -le 5) -or (($green -eq $blue) -and (([int]$red - $green) -le 5)) -or (($blue -eq $red) -and (([int]$green - $blue) -le 5)))) -or ($script:generate_keys_try -ge 2))
                {
                    if($script:generate_keys_try -ge 1)
                    {
                        $hash = "$zone_s" + "D" + $color + "$orientation"
                    }
                    else
                    {
                        $hash = "$zone_s " + $color + "$orientation"
                    }
                    $value = "$duration_s" + "$color_weight_s" + " $file_hash"
                    #write-output 1= $hash = $color_weight_s

                    if(!($script:finger_prints.containskey($hash)))
                    {
                        $script:finger_prints.Add("$hash","$value");
                        $key_count++;
                        #write-output 2= $hash = $color_weight_s
                        [int]$script:overall_red = [int]$script:overall_red + [int]$red
                        [int]$script:overall_green = [int]$script:overall_green + [int]$green
                        [int]$script:overall_blue = [int]$script:overall_blue + [int]$blue
                        $found_color = 1;
                        if($script:debug -eq 1)
                        {
                            Add-Content -literalpath "$html_file" "<svg width=`"200`" height=`"50`"><rect width=`"200`" height=`"50`" fill=`"$hex_color`"></rect><text x=`"100`" y=`"0`" font-family=`"Verdana`" font-size=`"20`" fill=`"White`"><tspan dy=`"1.2em`" text-anchor=`"middle`">$red $green $blue</tspan><tspan text dy=`"1.2em`" -anchor=`"left`">$color_weight_s</tspan></text></g></svg>"
                            $x = $x + 105
                        }
                    }
                }
            }

            if($script:finger_prints.count -ge $stop_threshold)
            {
                break;
            }
        }
    }
    ################################################################################
    ####Process Grayscale Image#####################################################
    if($found_color -eq 0)
    {
        foreach ($color in $script:color_hash.GetEnumerator() | Sort-Object Value -Descending )
        {
            [string]$color_weight_s = $color.value
            [string]$color_weight_s = $color_weight_s.padleft(4," ");
            $color = $color.key

            $hash = "$zone_s" + "G" + $color + "$orientation"         
            $value = "$duration_s" + "$color_weight_s" + " $file_hash"

            
            if((($red -gt 20) -and ($blue -gt 20) -and ($green -gt 20)) -and (($red -le 235) -and ($blue -le 235) -and ($green -le 235)) -or ($script:generate_keys_try -ge 2))
            {
                if(!($script:finger_prints.containskey($hash)))
                {
                    $script:finger_prints.Add("$hash","$value");
                    $key_count++;
                    [int]$script:overall_red = [int]$script:overall_red + [int]$red
                    [int]$script:overall_green = [int]$script:overall_green + [int]$green
                    [int]$script:overall_blue = [int]$script:overall_blue + [int]$blue


                    if($script:debug -eq 1)
                    {
                        Add-Content "$html_file" "<svg width=`"200`" height=`"50`"><rect width=`"200`" height=`"50`" fill=`"$hex_color`"></rect><text x=`"100`" y=`"0`" font-family=`"Verdana`" font-size=`"20`" fill=`"White`"><tspan dy=`"1.2em`" text-anchor=`"middle`">$red $green $blue</tspan><tspan text dy=`"1.2em`" -anchor=`"left`">$color_weight_s</tspan></text></g></svg>"
                        $x = $x + 105
                    }
                }
            }
    
            if($script:finger_prints.count -ge $stop_threshold)
            {
                break;
            }          
        }
    }
}
################################################################################
####Find Similar Databases######################################################
function find_similar_databases
{
    Get-ChildItem -LiteralPath $script:db_location -Filter *.txt | Foreach-Object {
        $current_db_file = $_.Name
        if($current_db_file.Length -ge 13)
        {
            [int]$current_db_red      = $current_db_file.substring(0,3);
            [int]$current_db_blue     = $current_db_file.substring(3,3);
            [int]$current_db_green    = $current_db_file.substring(6,3);
            [int]$current_db_duration = $current_db_file.substring(9,5);

            if(($current_db_duration -ge ($script:duration_seconds - $script:duration_offset)) -and ($current_db_duration -le ($script:duration_seconds + $script:duration_offset)))
            {
                $distance = measure_color_distance "$current_db_red,$current_db_blue,$current_db_green" "$script:overall_red,$script:overall_blue,$script:overall_green"
                if($distance -le $script:color_distance_phase1)
                {
                    $script:possible_dbs.Add($current_db_file,$distance);
                }
            }
                
        }
    }
}
################################################################################
####Find Duplicates############################################################# 
function find_duplicates
{        
    if($script:finger_prints.count -ne 0)
    {
        $script:update_database = "Yes"
        ################################################################################
        ####Find Matching Files#########################################################   
        foreach ($current_print in $script:finger_prints.GetEnumerator() | Sort-Object Value -Descending)
        {
            $current_print = $current_print.key + $current_print.value
            $current_zone = $current_print.substring(0,2)
            $gray_scale = $current_print.substring(2,1)
            $current_color = $current_print.substring(0,13)
            $orientation = $current_print.substring(12,1)
            [int]$current_duration = $current_print.substring(13,5)
            [int]$color_weight = $current_print.substring(18,4)

            [int]$cc_red = $current_print.substring(3,3)
            [int]$cc_blue = $current_print.substring(6,3)
            [int]$cc_green = $current_print.substring(9,3)

            $script:color_weight_size = $script:color_weight_size + $color_weight
            $script:gradient_max_weight = $script:gradient_max_weight + $color_weight

            ################################################################################
            ####Loop Through Databases######################################################
            $database_count = 0;
            foreach($database in $script:possible_dbs.GetEnumerator())
            {
                $database_count++;
                $this_db = $script:db_location + $database.key
                
                ################################################################################
                ####Loop Database Keys##########################################################
                $reader = New-Object IO.StreamReader $this_db
                $line_count = 0;                  
                while($null -ne ($line = $reader.ReadLine()))
                {
                    if($line.Length -ge 13)
                    {
                        ################################################################################
                        ####Correct Zone/Color Threshold################################################
                        if(($line.substring(0,2) -eq $current_zone) -and (([int]$line.substring(3,3) -In ($cc_red - $script:gradients_max)..($cc_red + $script:gradients_max )))  -and  (([int]$line.substring(6,3) -In ($cc_blue - $script:gradients_max)..($cc_blue + $script:gradients_max ))) -and  (([int]$line.substring(9,3) -In ($cc_green - $script:gradients_max)..($cc_green + $script:gradients_max )))) 
                        {
                            ################################################################################
                            ####Duration Threshold##########################################################
                            [int]$database_duration = $line.substring(13,5)               
                            if(($database_duration -ge ($current_duration - $script:duration_offset)) -and ($database_duration -le ($current_duration + $script:duration_offset)))
                            {
                                ################################################################################
                                ####Same File?##################################################################
                                $database_file_path = $line.Substring(($line.IndexOf(",") + 1),(($line.Length - ($line.IndexOf(",") + 1))))
                                $database_file_path = $database_file_path -replace "`"",""
                                if($database_file_path -ne $script:full_path)
                                {
                                    ################################################################################
                                    ####Weight Matching############################################################
                                    [int]$db_weight = $line.substring(18,4)
                                    [int]$weight_difference = [Math]::Abs($color_weight - $db_weight)  
                                    if($weight_difference -le $script:weight_threshold)
                                    {

                                        [int]$db_red = $line.substring(3,3)
                                        [int]$db_blue = $line.substring(6,3)
                                        [int]$db_green = $line.substring(9,3)
                                        $distance = measure_color_distance "$db_red,$db_blue,$db_green" "$cc_red,$cc_blue,$cc_green"
                                        if($distance -lt $script:color_distance_phase2)
                                        {                                  
                                            ################################################################################
                                            ####Track Direct Zone Hits######################################################
                                            if($current_color -eq $line.substring(0,13))
                                            {
                                                [int]$database_zone = $line.substring(0,2)
                                                if(!($script:direct_zone_hits.Contains("$database_file_path")))
                                                {
                                                    $zone = "   0" * $script:zones_squared
                                                    $database_zone_pos = ($database_zone * 4) - 4
                                                    [int]$current_value = $zone.Substring($database_zone_pos,4);
                                                    [string]$current_value = [int]$current_value + 1
                                                    $current_value = $current_value.padleft(4," ");
                                                    $zone = ($zone).ToCharArray()
                                                    0..($current_value.Length-1) | ForEach-Object { $zone[$database_zone_pos + $_] = $current_value[$_] }
                                                    $zone = [String]::new($zone)
                                                    $script:direct_zone_hits.Add("$database_file_path",$zone);
                                                    $script:direct_zone_hits_tracker.add("$database_file_path",1);
                                                    $script:direct_hit_weights.Add("$database_file_path",$color_weight);
                                            
                                                }
                                                else
                                                {
                                                    $zone = $script:direct_zone_hits[$database_file_path]
                                                    $database_zone_pos = ($database_zone * 4) - 4
                                                    [int]$current_value = $zone.Substring($database_zone_pos,4);
                                                    [string]$current_value = [int]$current_value + 1
                                                    $current_value = $current_value.padleft(4," ");
                                                    $zone = ($zone).ToCharArray()
                                                    0..($current_value.Length-1) | ForEach-Object { $zone[$database_zone_pos + $_] = $current_value[$_] }
                                                    $zone = [String]::new($zone)
                                                    $script:direct_zone_hits[$database_file_path] = $zone
                                                    $script:direct_zone_hits_tracker[$database_file_path]++
                                                    $script:direct_hit_weights[$database_file_path] = $script:direct_hit_weights[$database_file_path] + $color_weight

                                                }
                                            }
                                            ################################################################################
                                            ####Track Gradient Zone Hits####################################################
                                            else
                                            {
                                                [int]$database_zone = $line.substring(0,2)
                                                if(!($script:grad_zone_hits.Contains("$database_file_path")))
                                                {
                                                    $zone = "   0" * $script:zones_squared
                                                    $database_zone_pos = ($database_zone * 4) - 4
                                                    [int]$current_value = $zone.Substring($database_zone_pos,4);
                                                    [string]$current_value = [int]$current_value + 1
                                                    $current_value = $current_value.padleft(4," ");
                                                    $zone = ($zone).ToCharArray()
                                                    0..($current_value.Length-1) | ForEach-Object { $zone[$database_zone_pos + $_] = $current_value[$_] }
                                                    $zone = [String]::new($zone)
                                                    $script:grad_zone_hits.Add("$database_file_path",$zone);
                                                    $script:grad_zone_hits_tracker.add("$database_file_path",1);
                                                    $script:grad_hit_weights.Add("$database_file_path",$color_weight);
                                                }
                                                else
                                                {
                                                    $zone = $script:grad_zone_hits[$database_file_path]
                                                    $database_zone_pos = ($database_zone * 4) - 4
                                                    [int]$current_value = $zone.Substring($database_zone_pos,4);
                                                    [string]$current_value = [int]$current_value + 1
                                                    $current_value = $current_value.padleft(4," ");
                                                    $zone = ($zone).ToCharArray()
                                                    0..($current_value.Length-1) | ForEach-Object { $zone[$database_zone_pos + $_] = $current_value[$_] }
                                                    $zone = [String]::new($zone)
                                                    $script:grad_zone_hits[$database_file_path] = $zone
                                                    $script:grad_zone_hits_tracker[$database_file_path]++
                                                    $script:grad_hit_weights[$database_file_path] = $script:grad_hit_weights[$database_file_path] + $color_weight
                                                }
                                            }#Zone Hits Direct or Gradient
                                        }#Color Distance Phase 2
                                    }#Weight Threshold
                                }#Same File as Current?
                            }#Duration Threshold
                        }#Zone Match
                    }#Line Length
                }#While Reading
                $reader.Close()
            }#Foreach Database File   
        }#Foreach Print
    }#FingerPrints Count
}
################################################################################
####Calculate Direct Hit Metrics################################################
function calculate_direct_hit_metrics
{
    if($script:finger_prints.count -ne 0)
    {
        foreach($file in $script:direct_zone_hits_tracker.GetEnumerator() | Sort-Object value -Descending)
        {
            if($script:direct_hit_file -eq "")
            {
                $script:direct_hit_file = $file.key
            }

            $script:direct_hits_count = $file.value
            $script:direct_hits_percentage = [int](($script:direct_hits_count / $script:finger_prints.count) * 100)

            $script:direct_hit_weight = $script:direct_hit_weights[$file.key]
            $script:direct_hit_weight_percent = [int](($script:direct_hit_weight / ($script:color_weight_size)) * 100)
                
            #######################################################################
            $zones = @{};
            $script:direct_hits_zone_average = 0;
            1..$script:zones_squared | ForEach-Object {
    
                [int]$value = $script:direct_zone_hits[$file.key].Substring((($_ * 4) - 4),4);
                if($value -ne 0)
                {
                    $script:direct_hits_zone_count++
                    $script:direct_hits_zone_average = $script:direct_hits_zone_average + $value
                }
                $zones.add($_,$value);
            }
            [int]$script:direct_hits_zone_average = ($script:direct_hits_zone_average / $script:zones_squared)
            [int]$script:max_zone_avg = ($script:finger_prints.count / $script:zones_squared)
            $script:direct_hits_zone_average_percent = [int](($script:direct_hits_zone_average / $script:max_zone_avg) * 100);
            #########################################################################
            $script:direct_zone_hits_percent = (($script:direct_hits_zone_count / $script:zones_squared) * 100);         
            Break;
        }
    }
}
################################################################################
####Calculate Gradient Hit Metrics##############################################
function calculate_gradient_hit_metrics
{
    if($script:finger_prints.count -ne 0)
    {                          
        if($script:direct_hit_file -eq "")
        {
            foreach($file in $script:grad_zone_hits_tracker.GetEnumerator() | Sort-Object value -Descending)
            {
                $script:direct_hit_file = $file.key
                break;
            }
        }
        if($script:grad_zone_hits_tracker.Contains($script:direct_hit_file))
        {
            [int]$script:gradients_total = (($script:gradients_max * $script:gradients_max * $script:gradients_max) / 3) 
            
            #write-output Grads: $script:gradients_total
            #write-output DHF: $script:direct_hit_file
            #write-output Merge: $script:grad_zone_hits_tracker[$script:direct_hit_file]
            $script:grad_hits_count = $script:grad_zone_hits_tracker[$script:direct_hit_file]


            $script:grad_hits_percentage = [int](($script:grad_hits_count / $script:gradients_total) * 100)
            $script:grad_hit_weight = $script:grad_hit_weights[$script:direct_hit_file]

            $script:grad_hit_weight_percent = [int](($script:grad_hit_weight / $script:gradient_max_weight) * 100)

            #################################################################################
            $zones = @{};
            1..$script:zones_squared | ForEach-Object {
    
                [int]$value = $script:grad_zone_hits[$script:direct_hit_file].Substring((($_ * 4) - 4),4);
                if($value -ne 0)
                {
                        
                    $script:grad_hits_zone_count++
                    $script:grad_hits_zone_average = $script:grad_hits_zone_average + $value
                }
                $zones.add($_,$value);
            }
            [int]$script:grad_hits_zone_average = ($script:grad_hits_zone_average / $script:zones_squared)
            [int]$script:max_zone_avg = ($script:gradients_total / $script:zones_squared)
            $script:grad_hits_zone_average_percent = [int](($script:grad_hits_zone_average / $script:max_zone_avg) * 100);
            #########################################################################
            $script:grad_zone_hits_percent = (($script:grad_hits_zone_count / $script:zones_squared) * 100);
        }
    }
}
################################################################################
####Calculate Combined & Super Metrics##########################################
function calculate_combined_hit_metrics
{
    if($script:finger_prints.count -ne 0)
    {
        if($script:direct_hit_file -ne "")
        {   
            $script:combined_hit_percent              = (($script:direct_hits_percentage + $script:grad_hits_percentage) / 2)
            $script:combined_zone_percent             = (($script:direct_zone_hits_percent + $script:grad_zone_hits_percent) / 2)
            $script:combined_avg_zone_percent         = (($script:direct_hits_zone_average_percent + $script:grad_hits_zone_average_percent) / 2)
            $script:combined_weight_percent           = (($script:direct_hit_weight_percent + $script:grad_hit_weight_percent) / 2)

            $script:super_number_direct = (($script:direct_hits_percentage + $script:direct_zone_hits_percent + $script:direct_hits_zone_average_percent + $script:direct_hit_weight_percent) / 4)
            $script:super_number_grad =   (($script:grad_hits_percentage + $script:grad_zone_hits_percent + $script:grad_hits_zone_average_percent + $script:grad_hit_weight_percent) / 4)
            $script:super_ultra = (($script:super_number_direct + $script:super_number_grad) / 2)            
        }
    }
}
################################################################################
####Determine if Duplicate Video################################################
function detect_duplicate_video 
{    
    if(($script:direct_hit_file -ne "") -and ($script:direct_hit_file -ne $null ) -and (Test-path -literalpath "$script:direct_hit_file"))
    {
        if(($script:media_type -eq "Video") -and ($script:direct_hit_file -ne ""))
        {
            ########################################################################
            ##12%
            if($script:direct_hits_percentage -ge 13)
            {
                    $script:is_duplicate = "Level 13"
            }
            ########################################################################
            ##11%
            if($script:direct_hits_percentage -ge 11)
            {
                if(($script:grad_zone_hits_percent -ge 35))
                {
                    $script:is_duplicate = "Level 11"
                }
            }
            ########################################################################
            ##10%
            elseif($script:direct_hits_percentage -ge 10)
            {
                if(($script:grad_zone_hits_percent -ge 35) -and ($script:super_number_direct -ge 8))
                {
                    $script:is_duplicate = "Level 10"
                }
            }
            ########################################################################
            ##9%
            elseif($script:direct_hits_percentage -ge 9)
            {
                if(($script:grad_zone_hits_percent -ge 36) -and ($script:super_number_direct -ge 8))
                {
                    $script:is_duplicate = "Level 9"
                }
            }
            ########################################################################
            ##8%
            elseif($script:super_ultra -ge 20)
            {
                if(($script:combined_zone_percent -ge 13))
                {
                    $script:is_duplicate = "Sup Level 20"
                }
            }
        }
    }
    else
    {
        #send_single_output "-ForegroundColor Red " "     Error: $script:direct_hit_file Direct Hit File Missing!"
    }
}
################################################################################
####Determine if Duplicate Image################################################
function detect_duplicate_image
{
    if(($script:media_type -eq "Image") -and ($script:direct_hit_file -ne "") -and (Test-path -literalpath "$script:direct_hit_file "))
    {
        if(($script:direct_hits_percentage -ge 40) -and ($script:direct_zone_hits_percent -ge 49))
        {
            $script:is_duplicate = "Level 4"
        }
        elseif(($script:direct_hits_percentage -ge 32) -and ($script:direct_zone_hits_percent -ge 60))
        {
            $script:is_duplicate = "Level 3"
        }
    }
}
################################################################################
####Pick Best File #############################################################
#Determines which file is better
function pick_best_file($file1,$file2)
{
    if($script:is_duplicate -ne "No")
    {          
        ################################################################################
        ####Get File Attributes#########################################################
        $file_object1 = (Get-Item -literalpath $file1)
        $folder1      = $shell.Namespace($file_object1.DirectoryName)
        $file1        = $folder1.ParseName($file_object1.Name)       
        $width1       = $file1.ExtendedProperty("System.Video.FrameWidth")
        $height1      = $file1.ExtendedProperty("System.Video.FrameHeight")
        $path1        = $file_object1.FullName

        $file_object2 = (Get-Item -literalpath $file2)
        $folder2      = $shell.Namespace($file_object2.DirectoryName)
        $file2        = $folder2.ParseName($file_object2.Name)       
        $width2       = $file2.ExtendedProperty("System.Video.FrameWidth")
        $height2      = $file2.ExtendedProperty("System.Video.FrameHeight")
        $path2        = $file_object2.FullName

        $file_dim1 = $width1 * $height1
        $file_dim2 = $width2 * $height2

        $size1 = $file_object1.length
        $size2 = $file_object2.length

        $audio1 = "N/A"
        $audio2 = "N/A"


        ################################################################################
        ####Check if files are the Same ################################################
        if($size1 -eq $size2)
        {
            if($path1 -match " - Duplicate")
            {
                $script:superior_file = $path2
            }
            else
            {
                if($path1 -clt $path2)
                {
                    $script:superior_file = $path1
                }
                else
                {
                    $script:superior_file = $path2
                }           
            }
        }
        ################################################################################
        ####Check if Dimensions are the Same ###########################################
        elseif($file_dim1 -eq $file_dim2)
        {
            $audio1 = check_audio $path1
            $audio2 = check_audio $path2
            if($audio1 -eq $audio2)
            {
                if($size1 -gt $size2)
                {
                    $script:superior_file = $path1
                }
                else
                {
                    $script:superior_file = $path2
                }
            }
            elseif($audio1 -eq "Yes")
            {
                $script:superior_file = $path1
            }
            else
            {
                $script:superior_file = $path2
            }
        }
        ################################################################################
        ####Check if Dimensions are Different ##########################################
        elseif($file_dim1 -gt $file_dim2)
        {
            $script:superior_file = $path1
        }
        else
        {
            $script:superior_file = $path2
        }
        ################################################################################
        ####Finalize Varibles ##########################################################
        if($script:superior_file -eq $path1)
        {
            $script:duplicate_file = $path2;
        }
        else
        {
            $script:duplicate_file = $path1;
        }
    }       
}
############################################################################
####Duplicate Response Actions #############################################
function duplicate_response_actions
{
    if($script:is_duplicate -ne "No")
    {
        
        ################################################################################
        ####Match Found Header #########################################################   
        send_single_output "-ForegroundColor Green " "     Found Match!"
        send_single_output "          $script:direct_hit_file"

        check_duplicate_tracker
        #send_single_output "-ForegroundColor Green " "FOUND: $script:found"
        if($script:found -ne 1)
        {
                
            $script:settings['Match_Count']++;
            
            send_single_output "-ForegroundColor Green " "     Total Matches:" $script:settings['Match_Count']
            send_single_output " "

            ################################################################################
            #####Duplicate Response (Log) ##################################################
            if($script:settings['duplicate_response'] -eq 0)
            {
                $script:action = "Match Found"
                ###Just Log Matches
                log_it
                send_single_output "-ForegroundColor Green " "     Superior File:  $script:superior_file"
                send_single_output "-ForegroundColor Green " "     Duplicate File: $script:duplicate_file"

                send_single_output "TXR-" " "
                send_single_output "TXR-" "Match " $script:settings['Match_Count']
                send_single_output "TX-" "Superior File   "
                send_single_output "LN-"  "$script:superior_file"
                send_single_output "TX-" "Duplicate File  "
                send_single_output "LN-" "$script:duplicate_file"

                write_duplicate_tracker
            }
            ################################################################################
            #####Duplicate Response (Rename) ###############################################
            if($script:settings['duplicate_response'] -eq 1)
            {
                $script:action = "Renamed"
                rename_files
                log_it  
            
                write_duplicate_tracker
            }
            ################################################################################
            #####Duplicate Response (Delete) ###############################################
            if($script:settings['duplicate_response'] -eq 2)
            {
                $script:action = "Deleted"
                Remove-Item -LiteralPath $script:duplicate_file
                send_single_output "     Matched File: $script:superior_file"
                send_single_output "-ForegroundColor Red " "     Deleted File: $script:duplicate_file"
                log_it
                    
            }
        }#Duplicate Tracker
        else
        {
            #write-host DUPLICATE IN TRACKER!
        }
    }
    ################################################################################
    #####Partial Match #############################################################
    elseif($script:direct_hit_file -ne "")
    {
        $script:action = "Partial"
        send_single_output "     Partial Match:"
        send_single_output "          $script:full_path"
        send_single_output "          $script:direct_hit_file"           
        log_it
    }
    ################################################################################
    #####No Match ##################################################################
    else
    {
        send_single_output "     No Match:"         
        send_single_output "          $script:full_path"
    }
}
################################################################################
######Check Duplicate Tracker ##################################################
function check_duplicate_tracker
{
    $script:found = 0
    if($script:duplicate_tracker.Contains($script:duplicate_file))
    {
        if($script:duplicate_tracker[$script:duplicate_file] -eq $script:superior_file)
        {
            $script:found = 1;
            send_single_output "-ForegroundColor Green " "     Previous Match Found."
            send_single_output "          $script:duplicate_file"
        }
    }
    if($script:found -ne 1)
    {
        ############################################################################
        #####Duplicate Intercept ###################################################
        ##Duplicate Intercept Prevents Matched Children from Changing Parents Name
        $duplicate_intercept1 = $script:superior_file -replace " - Duplicate \d+",""
        $duplicate_intercept2 = $script:duplicate_file -replace " - Duplicate \d+",""
        if($duplicate_intercept1 -eq $duplicate_intercept2)
        {
            if((Test-Path -LiteralPath $duplicate_intercept1) -and ($duplicate_intercept1 -eq $script:full_path))
            {
                $script:found = 1;
                send_single_output "-ForegroundColor Yellow " "          Duplicate Previously Identified - Parent Found Child"
                #send_single_output "TXR-" " "
                #send_single_output "TXR-" "Previously Matched " $script:settings['Match_Count']
                #send_single_output "TX-" "Superior File   "
                #send_single_output "LN-" "$script:superior_file"
                #send_single_output "TX-" "Duplicate File  "
                #send_single_output "LN-" $script:new_name              
                #send_single_output "SNAP-" "Save GUI"
            }
            elseif((Test-Path -LiteralPath $duplicate_intercept1) -and ($duplicate_intercept1 -ne $script:full_path))
            {
                $script:found = 1;
                $script:settings['Match_Count']++;
                $script:action = "Match Found"
                log_it
                send_single_output "-ForegroundColor Green " "          Duplicate Previously Identified - Child Found Parent"
                send_single_output "TXR-" " "
                send_single_output "TXR-" "Previously Matched " $script:settings['Match_Count']
                send_single_output "TX-" "Superior File   "
                send_single_output "LN-" "$script:superior_file"
                send_single_output "TX-" "Duplicate File  "
                send_single_output "LN-" $script:duplicate_file
                send_single_output " "
                send_single_output "-ForegroundColor Green " "     Total Matches:" $script:settings['Match_Count']
                send_single_output " "       
            }
        } 
    }
}
################################################################################  
######Rename Files##############################################################
function rename_files
{   
    ################################################################################
    ######Rename Primary File#######################################################
    $count = 0;
    $script:new_name = "C:\"
    while((Test-Path -LiteralPath $script:new_name) -and ($script:new_name -ne $script:duplicate_file))
    {
        
        $script:new_name = $script:superior_file -replace " - Duplicate \d\d$script:extension$| - Duplicate \d$script:extension|$script:extension$",""
        $script:new_name = $script:new_name + " - Duplicate $count$script:extension"
        $count++;
        #write-output $script:new_name
    }
    ################################################################################
    ######Update Finger Print Hash##################################################
    if($script:duplicate_file -eq $script:full_path)
    {
        #send_single_output Modified Path $script:new_name
        $script:full_path_modified = $script:new_name
    }


    if($script:duplicate_file -eq $script:new_name)
    {
        send_single_output "-ForegroundColor Yellow " "     Duplicate Previously Identified - No Rename Necessary"
        send_single_output "TXR-" " "
        send_single_output "TXR-" "Previously Matched " $script:settings['Match_Count']
        send_single_output "TX-" "Superior File   "
        send_single_output "LN-" "$script:superior_file"
        send_single_output "TX-" "Duplicate File  "
        send_single_output "LN-" $script:new_name
    }
    else
    {
        Move-Item -LiteralPath $script:duplicate_file $script:new_name
        $line = "$script:duplicate_file" + "::" + $script:new_name
        Add-Content -LiteralPath $script:settings['Rename_Tracker'] $line

        $core_folder = Split-Path -Path $script:superior_file
       
        send_single_output "-ForegroundColor Green " "     Superior File:  $script:superior_file"
        send_single_output "-ForegroundColor Green " "     Duplicate File: $script:new_name"
        send_single_output " "
        send_single_output "-ForegroundColor Yellow " "     Renaming Match"
        send_single_output "     $script:duplicate_file"
        send_single_output "     to"
        send_single_output "     $script:new_name"
        send_single_output " "

        

        send_single_output "TXR-" " "
        send_single_output "TXR-" "Match " $script:settings['Match_Count']
        send_single_output "TX-" "Folder:  "
        send_single_output "LN-" "$core_folder"
        send_single_output "TX-" "Superior File:   "
        send_single_output "LN-" "$script:superior_file"
        send_single_output "TX-" "Duplicate File:  "
        send_single_output "LN-" $script:new_name
        


    }
    ################################################################################
    ######Transfer Duplicate Children###############################################
    #send_single_output "-ForegroundColor Yellow " "      Duplicate's Children"

    $count_children = 0;
    $script:superior_file_root = (Split-Path $script:new_name)
    $script:superior_file_name = [io.path]::GetFileNameWithoutExtension($script:new_name)
    $script:superior_file_name = $script:superior_file_name -replace " - Duplicate \d+$",""

    $script:duplicate_file_root = (Split-Path $script:duplicate_file)
    $script:duplicate_file_name = [io.path]::GetFileNameWithoutExtension($script:duplicate_file)
    $script:duplicate_file_name = $script:duplicate_file_name -replace " - Duplicate \d+$",""

    #$god_children = Get-ChildItem -LiteralPath $script:superior_file_root -file -filter "$script:superior_file_name*"
    $borg_children = Get-ChildItem -LiteralPath $script:duplicate_file_root -file -filter "$script:duplicate_file_name - Duplicate*"

    #send_single_output $borg_children
    #send_single_output $script:duplicate_file_root
    #send_single_output $script:duplicate_file_name


    if($borg_children.count -ne 0)
    {
        send_single_output "-ForegroundColor Yellow " "        " $borg_children.count " Child Duplicates Found!"
    }
    foreach($borg in $borg_children)
    {
        $count = 0;
        while($count -lt 100)
        {             
            $new_borg_name = "$script:superior_file_root" + "\" + "$script:superior_file_name"+ " - Duplicate $count" + $borg.Extension
            if($new_borg_name -eq $borg.fullname)
            {
                send_single_output "-ForegroundColor Yellow " "          Child Name Matches - No Rename Necessary"
                
                send_single_output "TX-" "            Child:  "
                send_single_output "LN-" $new_borg_name
                break
            }
            elseif(!(Test-Path -literalpath $new_borg_name))
            {
                        
                Move-Item -LiteralPath $borg.fullname $new_borg_name

                $line = $borg.fullname + "::" + "$new_borg_name"
                Add-Content -LiteralPath $script:settings['Rename_Tracker'] $line

                send_single_output "-ForegroundColor Yellow " "           Renamed:"
                send_single_output "           " $borg.fullname
                send_single_output "           to"
                send_single_output "           $new_borg_name"
                send_single_output " "

                #send_single_output "TX-" "     Child Old  "
                #send_single_output "LN-" "     " $borg.fullname
                send_single_output "TX-" "            Child:  "
                send_single_output "LN-" $new_borg_name


                        
                break;
            }
            else
            {
                #send_single_output "-ForegroundColor Red " "Attempt $count Rename = $new_borg_name"
            }
            $count++
        }
        if($count -eq 100)
        {
            send_single_output "-ForegroundColor Red " "Critical Child Error!!!"
        }
    }
}
################################################################################
######Write Duplicate Tracker###################################################
function write_duplicate_tracker
{
    if(!($script:duplicate_tracker.Contains($script:duplicate_file)))
    {
        $script:duplicate_tracker[$script:duplicate_file] = $script:superior_file
    }
}
################################################################################
####Update Database ############################################################
function update_database
{
    #send_single_output "Update DB?: " $script:update_database
    if($script:update_database -eq "Yes")
    {
        if($script:file_load -eq "No")
        {   
            ################################################################################
            ######File Was Renamed During Scan #############################################
            if($script:full_path_modified -ne "")
            {
                #send_single_output "Changed Path: $script:full_path_modified"
                $mystream = [IO.MemoryStream]::new([byte[]][char[]]$script:full_path_modified)
                $file_hash = (Get-FileHash -InputStream $mystream -Algorithm SHA256)
                $file_hash = $file_hash.hash.substring(0,5);
                [string]$size = [int](((Get-Item -LiteralPath $script:full_path_modified).length/1kb))
                $size = $size.padleft(7," ");
                $file_hash = "$file_hash" + "$size"
                $writer = [System.IO.StreamWriter]::new($script:database,$true)
                foreach($print in $script:finger_prints.getenumerator() | Sort key)
                {
                    $key = $print.key + $print.value
                    $line = $key.Substring(0,23)
                    $line = $line + $file_hash                      
                    $line = csv_write_line $line $script:full_path_modified
                    $writer.WriteLine($line)
                }
                $writer.Close();
            }
            ################################################################################
            ######File Did Not change ######################################################
            else
            {
                $writer = [System.IO.StreamWriter]::new($script:database,$true)
                foreach($print in $script:finger_prints.getenumerator() | Sort key)
                {
                    $line = $print.key + $print.value
                    $line = csv_write_line $line $script:full_path
                    $writer.WriteLine($line)
                }
                $writer.Close();
            }
            send_single_output "     Database Updated!"
        }
    }
    
}
################################################################################
######Merging & Purging Keys Mode 0#############################################
function merge_duplicates
{
    if(($script:superior_file -eq $script:full_path) -and ($script:is_duplicate -ne "No") -and ($script:new_name -ne ""))
    {
        #Mode 0: The Current Working File Was Superior           ($script:database) <-Variable with file
        #Mode 1: The Database File Was Superior                  (Will have to find it) 
        #write-output "$script:database"
        $db_count = 0;
        foreach($database in $script:possible_dbs.GetEnumerator())
        {
            $this_db = $script:db_location + $database.key
            $this_db_temp = $script:db_location + "temp_" + $database.key
    
            $db_count++;
            $db_found = 0;
            $line_count = 0;
            $checked_paths = @{};
            $db_hash = @{};

            $file_hash = "";
            if(Test-Path -LiteralPath $script:new_name)
            {
                $mystream = [IO.MemoryStream]::new([byte[]][char[]]$script:new_name)
                $file_hash = (Get-FileHash -InputStream $mystream -Algorithm SHA256)
                $file_hash = $file_hash.hash.substring(0,5);
                [string]$size = [int](((Get-Item -LiteralPath $script:new_name).length/1kb))
                $size = $size.padleft(7," ");
                $file_hash = "$file_hash" + "$size"
                $file_hash = $file_hash + "," + $script:new_name
            }

            ################################################################################
            ######Search for Database of Renamed File & Father Pre-Keys for Merger #########
            $reader = New-Object IO.StreamReader $this_db
            while($null -ne ($line = $reader.ReadLine()))
            {
                $line_count++;
                ################################################################################
                ######Verify Path is Still Valid################################################
                $path_good = 0;
                $line_path = $line.Substring(($line.IndexOf(",") + 1),(($line.Length - ($line.IndexOf(",") + 1))))
                $line_path = $line_path -replace "`"",""
                if($checked_paths.ContainsKey($line_path))
                {
                    $path_good = 1;
                }
                else
                {
                    #send_single_output "Test Path: "$line_path
                    if(Test-Path -LiteralPath $line_path)
                    {
                        #send_single_output "Test Path: Passed"
                        $path_good = 1;
                        $checked_paths.add("$line_path","")
                        #write-host GOOD $line_path
                    }
                    else
                    {
                        if(($line_path -eq $script:duplicate_file) -and (Test-Path -LiteralPath $script:new_name) -and ($file_hash -ne ""))
                        {
                            $db_found = 1;
                            $path_good = 1;
                            $line_front = $line.Substring(0,23);
                            $line = $line_front + $file_hash
                        }     
                    }
                }
                ################################################################################
                ######Add Line to Hash##########################################################
                if(!($db_hash.ContainsKey($line)) -and ($path_good -eq 1))
                {
                    $db_hash.Add($line,"");
                }                           
            }
            ################################################################################
            ######Write Hash################################################################
            $reader.Close()
            #send_single_output "Hash Count: " $db_hash.count
            if((($db_hash.count -ne 0) -and ($db_hash.count -ne $line_count)) -or ($db_found -eq 1)) #Hash Reveals Duplicate Lines or Missing Paths
            {
                #send_single_output "Hash & File Mismatch!"
                $writer = [System.IO.StreamWriter]::new($this_db_temp) 
                foreach($entry in $db_hash.getEnumerator() | Sort key)
                {
                    $writer.WriteLine($entry.key)
                }
                $writer.Close()
                if(Test-Path -LiteralPath $this_db_temp)
                {
                    Remove-Item -LiteralPath $this_db
                    Rename-Item -LiteralPath $this_db_temp $this_db
                }
            }
            elseif($db_hash.count -eq 0) #No Valid Entries - Delete DB
            {
                #send_single_output "No Valid Keys!"
                if(Test-Path -LiteralPath $this_db)
                {
                    Remove-Item -LiteralPath $this_db
                }
            }  
    
            ################################################################################
            ######DB Found - Stop Searching#################################################
            if($db_found -eq 1)
            {
                #send_single_output "      Found the Database! You can Exit Now!"
                Break;
            }      
        }
        #Write-host "Databases Scanned: $db_count = $db_found"
    } 
}
################################################################################
######Log it (Update Log File)##################################################
function log_it
{
    $file_link1 = "=HYPERLINK(`"`"$script:superior_file`"`",`"`"Source`"`")";
    $file_link2 = "=HYPERLINK(`"`"$script:duplicate_file`"`",`"`"Partial`"`")";
    $file_link3 = "=HYPERLINK(`"`"$script:new_name`"`",`"`"Rename`"`")";
    $file_link4 = "=HYPERLINK(`"`"$script:duplicate_file`"`",`"`"Duplicate`"`")";

    if($script:action -eq "Renamed")
    {
        $line1 = "`"$script:action`",`"$file_link1`",`"$file_link3`"";
        $line1 = $line1 + ",`"" + "Match Source:   $script:superior_file"
        $line2 = "Match Original:  $script:duplicate_file"
        $line3 = "Match Rename: $script:new_name" + '"'
    }
    elseif($script:action -eq "Deleted")
    {
        $line1 = "`"$script:action`",`"$file_link1`",`"Deleted`"";
        $line1 = $line1 + ",`"" + "Matched:   $script:full_path"
        $line2 = "Deleted:     $script:duplicate_file"
        $line3 = '"'

    }
    elseif($script:action -eq "Match Found")
    {
        $line1 = "`"$script:action`",`"$file_link1`",`"$file_link4`"";
        $line1 = $line1 + ",`"" + "Superior File:   $script:superior_file" 
        $line2 = "Duplicate File:   $script:duplicate_file"
        $line3 = '"' 

    }
    elseif($script:duplicate_file -eq "") #No Match
    {
        $line1 = "`"No Match`",`"$file_link1`",`"No Match`"";
        $line1 = $line1 + ",`"" + "Match Source:   $script:full_path"
        $line2 = '' 
        $line3 = '"' 
    }
    else #Partial Match
    {
        $line1 = "`"$script:action`",`"$file_link1`",`"$file_link2`"";
        $line1 = $line1 + ",`"" + "Match Source:   $script:full_path" 
        $line2 = "Match Original:$script:duplicate_file"
        $line3 = '"' 
    }
    
    
    $line3 = csv_write_line $line3 "$script:is_duplicate"
    $line3 = csv_write_line $line3 "$script:direct_hits_percentage%"
    $line3 = csv_write_line $line3 "$script:direct_zone_hits_percent%"
    $line3 = csv_write_line $line3 "$script:direct_hits_zone_average_percent%"
    $line3 = csv_write_line $line3 "$script:direct_hit_weight_percent%"
    $line3 = csv_write_line $line3 "$script:grad_hits_percentage%"
    $line3 = csv_write_line $line3 "$script:grad_zone_hits_percent%"
    $line3 = csv_write_line $line3 "$script:grad_hits_zone_average_percent%"
    $line3 = csv_write_line $line3 "$script:grad_hit_weight_percent%"
    $line3 = csv_write_line $line3 "$script:combined_hit_percent%"
    $line3 = csv_write_line $line3 "$script:combined_zone_percent%"
    $line3 = csv_write_line $line3 "$script:combined_avg_zone_percent%" 
    $line3 = csv_write_line $line3 "$script:combined_weight_percent%"
    $line3 = csv_write_line $line3 "$script:super_number_direct%" 
    $line3 = csv_write_line $line3 "$script:super_number_grad%" 
    $line3 = csv_write_line $line3 "$script:super_ultra%"
    


    $writer = [System.IO.StreamWriter]::new($script:settings['Log_File'],$true)
    $writer.WriteLine($line1)
    $writer.WriteLine($line2)
    $writer.WriteLine($line3)     
    $writer.Close();
}
################################################################################
####Check Audio ################################################################
#Support Function for Picking Best File
function check_audio($audio_file)
{
    [string]$audio = & cmd /u /c  "$script:ffprobe -i `"$audio_file`" -show_streams -select_streams a 2>&1"
    if($audio -match "\[STREAM\]")
    {
        return "Yes"
    }
    else
    {
        return "No"
    }
}
################################################################################
#####End File Scan Process #####################################################
function end_file_scan_process
{

    $time_left = 0;
    $script:process_time_end = Get-Date
    $eta = NEW-TIMESPAN -Start $script:process_time_start -End $script:process_time_end
    $script:eta_average_total = ($eta.Totalseconds + $script:eta_average_total);
    $real_file_counter =  $script:file_counter - $script:skipped_files
    $real_file_count = $script:file_count - $script:skipped_files
    $eta_estimate = (($script:eta_average_total / ($real_file_counter)) * (($real_file_count) - ($real_file_counter)))
    $eta =  [timespan]::Fromseconds($eta_estimate)
    [string]$days    = [string]$eta.Days + " Days"
    [string]$hours   = [string]$eta.Hours + " Hours"
    [string]$minutes = [string]$eta.minutes + " Minutes"
    [string]$seconds = [string]$eta.seconds + " Seconds"     
    if($eta.Days -ne 0){$time_left = "$days $hours $minutes $seconds"}
    elseif($eta.Hours -ne 0){$time_left = "$hours $minutes $seconds"}
    elseif($eta.minutes -ne 0){$time_left = "$minutes $seconds"}
    elseif($eta.seconds -ne 0){$time_left = "$seconds"}
    [int]$status = (($script:file_counter / $script:file_count) * 100)
    send_single_output "PB-$status"
    send_single_output "PL-" $time_left " Left To Find Duplicates - " "($script:file_counter / $script:file_count Files) - $status" "%"
    send_single_output "UP-" $script:object.FullName "::" $script:settings['Match_Count']
}
################################################################################
####Update Children in Log #####################################################
#Updates Reference Data in Log to Prevent Broken Links Due to Files Being Renamed
function update_children_in_log
{
    $tracker = $script:settings['Rename_Tracker']
    $log_file = $script:settings['Log_File']
    $log_temp = $script:settings['Log_File']  -replace ".csv","_Updated.csv"

    #send_single_output Tracker1: "$tracker"
    #send_single_output Log1: "$log_file"
    #send_single_output Log2: "$log_temp"


    #$tracker_array = Get-Content -LiteralPath $tracker
    #[array]::reverse($tracker_array)

    if((Test-Path -LiteralPath $log_file) -and (Test-Path -LiteralPath $tracker))
    {   
        if(Test-Path -LiteralPath "$log_temp")
        {
            Remove-Item -LiteralPath "$log_temp"
        }

        $writer = [System.IO.StreamWriter]::new("$log_temp") 
        $reader = New-Object IO.StreamReader $log_file
        $line_count = 0;
        while($null -ne ($line = $reader.ReadLine())) 
        {
            $line_count++;
            if($line -ne $null)
            {
                $reader2 = New-Object IO.StreamReader $tracker
                while($null -ne ($line2 = $reader2.ReadLine())) 
                {
                    ($path1,$path2) = ($line2 -split "::");
                    if($line -match [Regex]::Escape("$path1") -and (!($line -match "Original")) -and ($path2 -ne "") -and ($path2 -ne $null))
                    {
                        $line = $line -replace [Regex]::Escape("$path1"),"$path2"
                    }
                }
                $reader2.Close()
            }
            $writer.WriteLine($line)
        }
        $reader.Close()
        $writer.Close()
        if(Test-Path -LiteralPath $log_temp)
        {
            #Remove-Item -LiteralPath $log_file
            #Rename-Item -LiteralPath "$log_temp" "$log_file 1.csv"
        }
        if(Test-Path -literalPath $tracker)
        {
            #Remove-Item -LiteralPath $tracker
        } 
    }
}
################################################################################
####CSV to XLSX#################################################################
#Converts Log to Excel File & Creates a More Readable Output
function csv_to_xlsx
{
    $csvs = Get-ChildItem -LiteralPath $script:settings['Log_Folder'] -Filter "*.csv"
    foreach($csv in $csvs)
    {
        try
        {
            if(Test-Path -LiteralPath $script:settings['Log_File'])
            {
                ### Set input and output path
                $inputCSV = $csv.FullName
                $outputXLSX = $inputCSV -replace '.csv$',".xlsx"

                #send_single_output $inputCSV
                #send_single_output $outputXLSX


                $objExcel = New-Object -ComObject Excel.Application
                $workbook = $objExcel.Workbooks.Open("$inputCSV")
                $worksheet = $workbook.worksheets.item(1) 
                $objExcel.Visible=$false
                $objExcel.DisplayAlerts = $False


                ### Make it pretty
                $worksheet.columns.item('D').columnWidth = 255
                $worksheet.UsedRange.Columns.Autofit() | Out-Null
                $worksheet.UsedRange.Rows.Autofit() | Out-Null
             
                $worksheet.Columns.item("B").NumberFormat = "@"
                $worksheet.Columns.item("C").NumberFormat = "@"
        
                $headerRange = $worksheet.Range("A1","T1")
                $headerRange.AutoFilter() | Out-Null
                $headerRange.Interior.ColorIndex =48
                $headerRange.Font.Bold=$True
                $row_count = $worksheet.UsedRange.Rows.Count

                $worksheet.Range(“E1","T$row_count").Rows.HorizontalAlignment = -4152
                $worksheet.Range(“A1","T$row_count").Rows.VerticalAlignment = -4160

                $empty_Var = [System.Type]::Missing
                $sort_col = $worksheet.Range("F1:F$row_count")
                $worksheet.UsedRange.Sort($sort_col,1,$empty_Var,$empty_Var,$empty_Var,$empty_Var,$empty_Var,1) | Out-Null

                $borderrange = $worksheet.Range(“A1","T$row_count")
                $borderrange.Borders.Color = 0
                $borderrange.Borders.Weight = 2

                $workbook.SaveAs($outputXLSX,51)
                $workbook.Close()
                $objExcel.Quit()

                if(Test-Path -literalpath $outputXLSX)
                {
                    #Remove-Item -literalpath $output
                }
                ######Exit Excel Forcefully
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($worksheet)  | Out-Null
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook)  | Out-Null
                [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel)  | Out-Null
   
                Remove-Variable objExcel | Out-Null
                Remove-Variable workbook | Out-Null
                Remove-Variable worksheet | Out-Null

                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
                ##############################  
            }
        }
        catch
        {
            send_single_output "-ForegroundColor Red " "CSV to XLSX conversion failed - Most likely DCOM related."
        }
    }
}
################################################################################
####CSV Write Line #############################################################
#Prepares data to be written to CSV
function csv_write_line ($write_line,$data)
{
    ##################################################
    #Function checks to see if there is a comma in the data about to be written
    $return = "";
    if($data -match ',')
    {
        $data = '"' + "$data" + '"'
    }
    if($write_line -eq "")
    {
        $return = "$data"
    }
    else
    {
        $return = "$write_line," + "$data"
    }
    return $return
}
################################################################################
####CSV to Line Array ##########################################################
#Extracts CSV Entries
function csv_line_to_array ($line)
{
    if($line.Substring(0,1) -eq ",")
    {
        $line = ",$line"; 
    }
    Select-String '(?:^|,)(?=[^"]|(")?)"?((?(1)[^"]*|[^,"]*))"?(?=,|$)' -input $line -AllMatches | Foreach { $line_split = $_.matches -replace '^,|"',''}
    [System.Collections.ArrayList]$line_split = $line_split
    return $line_split
}
################################################################################
####Measure Color Distance######################################################
#Provides Numerical Distance Between Two Colors
function measure_color_distance( [Drawing.Color]$a, [Drawing.Color]$b ) 
{
    $sum = 'R','G','B' | foreach { [Math]::Pow( $a.$_ - $b.$_, 2 ) } | measure -Sum
    [Math]::Round( [Math]::Pow( $sum.Sum, .5 ), 2 )
}
################################################################################
####Job Execution Sequence #####################################################
#Starting Point for Child Process
send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
send_single_output "-ForegroundColor Cyan "  "Initializing"
send_single_output "PL-Initializing"
initial_checks
send_single_output "-ForegroundColor Cyan " "Checking Keys"
send_single_output "PL-Checking Keys"
load_existing_keys
send_single_output "-ForegroundColor Cyan " "Scanning..."
send_single_output "PL-Scanning..."
send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
send_single_output " "
scan_directory
send_single_output "-ForegroundColor Cyan " "----------------------------------------------------------------------------------------------"
send_single_output "-ForegroundColor Cyan "  "Updating Log..."
send_single_output "PL-Updating Log..."
update_children_in_log 
send_single_output "-ForegroundColor Cyan "  "Converting Log..."
send_single_output "PL-Converting Log... " 
csv_to_xlsx
send_single_output "-ForegroundColor Cyan " "Finished!"
send_single_output "PL-Finished"
send_single_output "PB-100"
send_single_output "UP-::"
send_single_output "SNAP-"
send_single_output "                    "
send_single_output "                    "
send_single_output "                    "
send_single_output "                    "
#For ($i = 0; $i -lt 5; $i++) { write-output " "; sleep 1; } #Wait for Logs

####################################################################################################################################################################
####################################################################################################################################################################  
####################################################################################################################################################################
}#Job
    ##################################################################################
    #####Start Job & Display Output ##################################################
    $first = 1;
    $script:cycler_job = Start-Job -ScriptBlock  $cycler_job_block
    $status_counter = 0;
    $last_status = "";
    Do {[System.Windows.Forms.Application]::DoEvents()
        $current_count = $cycler_job.ChildJobs.Output.count;
        $status = $cycler_job.ChildJobs.Output | Select-Object -Skip $status_counter
        
        if($status_counter -lt $current_count)
        {
            $status_counter = $current_count;
            foreach($output in $status)
            {
                if($output -ne $last_output)
                {
                    if($output -match "^PB-") #Update Progress Bar Value
                    {
                        $progress_bar.value = [int]$output.substring(3,[string]$output.length -3);
                    }
                    elseif($output -match "^PL-") #Update Progress Bar Text
                    {
                        $progress_bar_label.Text = [string]$output.substring(3,[string]$output.length -3);
                    }
                    elseif($output -match "^TXR-") #Add Regular non-Colored Text to GUI Log WITH a Carriage Return
                    {
                        $output = $output.substring(4,[string]$output.length -4);
                        $script:editor.AppendText("$output`r")
                    }
                    elseif($output -match "^TX-") #Add Regular non-Colored Text to GUI Log WITHOUT a Carriage Return
                    {
                        $output = $output.substring(3,[string]$output.length -3);
                        $script:editor.AppendText($output)
                    
                    }
                    elseif($output -match "^LN-") #Add Color Text Link to GUI
                    {
                        $output = $output.substring(3,[string]$output.length -3);
                        $script:editor.ScrollToCaret();
                        $script:editor.AppendText("$output`r")
                        $script:editor.SelectionStart = ($script:editor.text.length - ($output.length + 1))
                        $script:editor.SelectionLength = $output.length + 2
                        $script:editor.SelectionColor = [Drawing.Color]::Blue
                        $script:editor.SelectionFont = New-Object System.Drawing.Font($script:editor.SelectionFont,'Regular')
                        #update_editor
                    
                    }
                    elseif($output -match "^SNAP-") #Save the GUI Log
                    {
                        update_editor
                    }
                    elseif($output -match "-ForegroundColor") #Write Colored Text to Terminal
                    {
                        $out_split = $output -split "-ForegroundColor | ",3
                        $color = $out_split[1]
                        $text  = $out_split[2]
                        write-host -ForegroundColor $color "$text"
                    }
                    elseif($output -match "^UP-") #Update Scan Loction
                    {
                        $output = $output.substring(3,[string]$output.length -3);
                        $output_split = $output -split '::'
                        $script:settings['Continue'] = $output_split[0]
                        $script:settings['Match_Count'] = $output_split[1];
                    }
                    elseif($output -match "^Log-") #Update Log Information
                    {
                        $script:settings['Log_Folder'] = $output.substring(4,[string]$output.length -4);
                        update_log_paths
                    }
                    else
                    {
                        write-host  $output
                    }
                    $last_output = $output
                }
                #else
                #{
                #    write-host Duplicate $output
                #}
            }  
        }
        
    } Until (($script:cycler_job.State -ne "Running"))
    #update_editor
    $submit_button.Text = "Run Scan"
    #$progress_bar.Value = "0"
    $target_box.enabled = $true
    $database_dropdown.enabled = $true
    $media_dropdown.enabled = $true
    $browse1_button.enabled = $true
    $browse2_button.enabled = $true
    $ffmpeg_box.enabled = $true
    $duplicate_action_dropdown.enabled = $true

    $progress_bar_label.Text = "Finished!`n (Click to View Log)"
    update_settings
}
################################################################################
######Update Log Paths #########################################################
function update_log_paths
{
    #Write-host Writing Log
    $script:rename_tracker = $script:settings['Log_Folder'] + "\Rename Tracker.txt"
    $script:snapshot       = $script:settings['Log_Folder'] + "\Snapshot.txt"
    if(!(Test-Path -LiteralPath $script:snapshot))
    {
        Out-File -LiteralPath $script:snapshot
    }
    update_settings
}
################################################################################
######Update Editor ############################################################
#Updates Information In Gui
function update_editor
{
    Write-host Updating Snapshot
    if(Test-Path -LiteralPath $script:rename_tracker)
    {
        $tracker = Get-Content $script:rename_tracker
        foreach($line in $tracker)
        {
            $line_split = $line -split "::"
            $original = $line_split[0] -replace "\\","\\"
            $replace = $line_split[1] -replace "\\","\\"
            $script:editor.rtf = $script:editor.rtf -replace [Regex]::escape($original),"$replace"
        }
    }
    if(Test-Path -LiteralPath $script:snapshot)
    {
        Set-Content -literalpath $script:snapshot $editor.rtf -encoding Unicode
    }
    update_settings
}
################################################################################
######Parent Start Sequence ####################################################
load_settings
main

#Ver 2.1
#Bug Fixed: Failed duration detection would generate invalid keys & invalid matches
#Setting: Disabled Keep Screenshots
#



