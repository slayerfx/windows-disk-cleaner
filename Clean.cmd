@echo off
title windows-disk-cleaner
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows-disk-cleaner.ps1" %*
