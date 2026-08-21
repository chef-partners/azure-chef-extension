# Validation Scripts

This directory contains scripts for validating the Azure Chef Extension.

## Scripts

- `validate-windows.ps1` — Validates Windows extension configuration and install flow
- `validate-linux.sh` — Validates Linux extension configuration and install flow

## Usage

### Windows
```powershell
.\validation\validate-windows.ps1 [-LicenseKey <key>]
```

### Linux
```bash
bash validation/validate-linux.sh [--license-key <key>]
```
