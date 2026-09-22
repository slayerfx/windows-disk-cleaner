@echo off
title windows-disk-cleaner (dry run)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows-disk-cleaner.ps1" -DryRun -NoElevate %*
