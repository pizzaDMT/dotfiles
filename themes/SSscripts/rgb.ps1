#!/usr/bin/env pwsh

# Matrix Rain Effect for PowerShell 7.5 - With repeating RGB color pattern
# Anti-flicker version with double buffering
# Modified with white lead character followed by red, green, blue repeating pattern
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Character set with binary and Japanese characters
$CHARS = @(
    "0", "1", "ﾊ", "ﾐ", "ﾋ", "ｳ", "ｼ", "ﾅ", "ﾓ",
    "ﾆ", "ｻ", "ﾜ", "ﾂ", "ｵ", "ﾘ", "ｱ", "ﾎ", "ﾃ", "ﾏ"
)

# Colors (using ANSI escape codes for the sequence)
$WHITE_LEAD = "$([char]27)[38;2;255;255;255m"   # White lead character
$RED = "$([char]27)[38;2;160;100;100m"          # Pale red 
$GREEN = "$([char]27)[38;2;100;160;100m"        # Pale green
$BLUE = "$([char]27)[38;2;100;120;160m"         # Pale blue
$TRAIL_GREY = "$([char]27)[38;2;120;120;120m"   # Grey for trailing characters
$RESET = "$([char]27)[0m"

# Animation settings
$MIN_LENGTH = 5
$MAX_LENGTH = 15
$MIN_TRAIL_LENGTH = 2              # Minimum trailing black characters
$MAX_TRAIL_LENGTH = 4              # Maximum trailing black characters
$FRAME_DELAY = 110  # milliseconds
$DROP_DENSITY = 0.9  # Multiplier for drops (1.0 = screen width)

function Show-MatrixRain {
    try {
        # Store original console settings
        $originalCursorVisible = [Console]::CursorVisible
        $originalTitle = $Host.UI.RawUI.WindowTitle
        
        # Configure console
        [Console]::CursorVisible = $false
        $Host.UI.RawUI.WindowTitle = "rgb-rain"
        [Console]::Clear()
        
        # Get terminal dimensions
        $width = [Console]::WindowWidth
        $height = [Console]::WindowHeight
        
        # Create empty matrix for the screen buffer (2D array)
        $screenBuffer = New-Object 'object[,]' $height, $width
        for ($y = 0; $y -lt $height; $y++) {
            for ($x = 0; $x -lt $width; $x++) {
                $screenBuffer[$y, $x] = @{
                    Char = " "
                    Color = $RESET
                }
            }
        }
        
        # Calculate optimal number of drops based on screen size and density
        $maxDrops = [math]::Floor($width * $DROP_DENSITY)
        
        # Initialize drops
        $drops = @()
        for ($i = 0; $i -lt $maxDrops; $i++) {
            $drops += @{
                X = Get-Random -Minimum 0 -Maximum $width
                Y = Get-Random -Minimum -$MAX_LENGTH -Maximum $height
                Length = Get-Random -Minimum $MIN_LENGTH -Maximum $MAX_LENGTH
                TrailLength = Get-Random -Minimum $MIN_TRAIL_LENGTH -Maximum ($MAX_TRAIL_LENGTH + 1)
                Speed = 1  # Simplified speed
                # Pre-generate characters for this drop to avoid random generation every frame
                Chars = (1..$MAX_LENGTH | ForEach-Object { Get-Random -InputObject $CHARS })
                # No color theme needed anymore as all drops follow the same pattern
            }
        }
        
        # Main animation loop
        $frame = 0
        $outputBuffer = [System.Text.StringBuilder]::new($width * $height * 10)  # Pre-allocate buffer
        
        while ($true) {
            # Handle keypresses
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Q' -or $key.Key -eq 'Escape') {
                    break
                }
            }
            
            # Clear screen buffer (reset to spaces)
            for ($y = 0; $y -lt $height; $y++) {
                for ($x = 0; $x -lt $width; $x++) {
                    $screenBuffer[$y, $x] = @{
                        Char = " "
                        Color = $RESET
                    }
                }
            }
            
            # Update all drops
            foreach ($drop in $drops) {
                # Total visible length including trail
                $totalLength = $drop.Length + $drop.TrailLength
                
                # Draw the drop (only parts that are on screen)
                for ($j = 0; $j -lt $totalLength; $j++) {
                    $posY = $drop.Y - $j
                    $posX = $drop.X
                    
                    if ($posY -ge 0 -and $posY -lt $height -and $posX -ge 0 -and $posX -lt $width) {
                        # Select color based on position in drop - white lead, then red, green, blue pattern
                        $color = $TRAIL_GREY  # Default for trailing characters
                        $char = $drop.Chars[$j % $drop.Chars.Count]
                        
                        if ($j -eq 0) { 
                            # Lead character is white
                            $color = $WHITE_LEAD 
                        }
                        elseif ($j -lt $drop.Length) {
                            # Apply repeating RGB pattern based on position
                            switch (($j - 1) % 3) {
                                0 { $color = $RED }   # First position after lead is red
                                1 { $color = $GREEN } # Second position after lead is green
                                2 { $color = $BLUE }  # Third position after lead is blue
                            }
                        }
                        else {
                            # Trailing characters use light grey
                            $color = $TRAIL_GREY
                        }
                        
                        # Update the screen buffer
                        $screenBuffer[$posY, $posX] = @{
                            Char = $char
                            Color = $color
                        }
                    }
                }
                
                # Move the drop down
                $drop.Y += $drop.Speed
                
                # Reset drop if it's fallen off the bottom
                if ($drop.Y - $totalLength -gt $height) {
                    $drop.Y = Get-Random -Minimum -$MAX_LENGTH -Maximum 0
                    $drop.X = Get-Random -Minimum 0 -Maximum $width
                    $drop.Length = Get-Random -Minimum $MIN_LENGTH -Maximum $MAX_LENGTH
                    $drop.TrailLength = Get-Random -Minimum $MIN_TRAIL_LENGTH -Maximum ($MAX_TRAIL_LENGTH + 1)
                    # Refresh the characters
                    $drop.Chars = (1..$drop.Length | ForEach-Object { Get-Random -InputObject $CHARS })
                    # No need to reset color theme as all drops use the same pattern
                }
            }
            
            # Build the entire screen output in one go
            $outputBuffer.Clear() | Out-Null
            $outputBuffer.Append("$([char]27)[H") | Out-Null  # Move cursor to home position (1,1)
            
            $lastColor = ""
            for ($y = 0; $y -lt $height; $y++) {
                for ($x = 0; $x -lt $width; $x++) {
                    $cell = $screenBuffer[$y, $x]
                    if ($cell.Color -ne $lastColor) {
                        $outputBuffer.Append($cell.Color) | Out-Null
                        $lastColor = $cell.Color
                    }
                    $outputBuffer.Append($cell.Char) | Out-Null
                }
            }
            
            # Write the entire screen at once
            $outputBuffer.Append($RESET) | Out-Null
            [Console]::Write($outputBuffer.ToString())
            
            # Increment the frame counter
            $frame++
            
            # Brief pause
            Start-Sleep -Milliseconds $FRAME_DELAY
        }
    }
    catch {
        Write-Host "Error: $_" -ForegroundColor Red
    }
    finally {
        # Restore console settings
        [Console]::CursorVisible = $originalCursorVisible
        $Host.UI.RawUI.WindowTitle = $originalTitle
        Write-Host $RESET
        [Console]::Clear()
    }
}

# Main execution
try {
    Show-MatrixRain
}
catch {
    Write-Host "An unexpected error occurred: $_" -ForegroundColor Red
}
finally {
    # Final cleanup
    [Console]::CursorVisible = $true
    Write-Host "$([char]27)[0m"  # Reset all terminal attributes
}

Write-Host "Press any key to exit..."
$null = [Console]::ReadKey($true)