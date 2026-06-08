# Windows 11 Installation Check

Automated Windows 11 readiness assessment and remediation framework designed for enterprise and IT environments.

## Overview

Windows 11 Installation Check automates the process of validating whether a device is ready for a successful Windows 11 deployment or upgrade.

The framework performs comprehensive checks across hardware, software, security settings, Windows components, services, and system configuration. When supported, remediation scripts can be executed automatically to resolve detected issues.

The solution is built around a central orchestration script (`Run-All.ps1`) which coordinates validation modules, remediation tasks, reporting, and execution flow.

## Key Features

### Hardware Validation

- TPM 2.0 verification
- Secure Boot validation
- CPU compatibility checks
- Memory requirements validation
- Storage capacity checks
- UEFI configuration verification

### Operating System Validation

- Windows version assessment
- Update readiness checks
- Windows servicing validation
- Feature status verification

### Security Assessment

- Security configuration validation
- Windows security component checks
- Compliance verification

### Automated Remediation

- Executes predefined remediation scripts
- Resolves supported configuration issues
- Re-runs validation after remediation
- Logs actions performed during execution

### Modular Architecture

- Central execution through `Run-All.ps1`
- Supports additional validation modules
- Supports custom remediation scripts
- Easily extendable for organizational requirements

### Reporting

- Pass / Fail results
- Warning indicators
- Remediation summaries
- Deployment readiness status
- Execution logs

---

## How It Works

```text
Run-All.ps1
      │
      ▼
Discover Validation Modules
      │
      ▼
Execute Checks
      │
      ▼
Identify Issues
      │
      ▼
Run Applicable Fixes
      │
      ▼
Revalidate System
      │
      ▼
Generate Report
      │
      ▼
Windows 11 Readiness Result
```

---

## Requirements

- Windows 10 or later
- PowerShell 5.1+
- Administrator privileges
- Internet connectivity (optional depending on checks)

---

## Installation

```powershell
git clone https://github.com/wiktorlesiak/win11-Installation-check.git

cd win11-Installation-check
```

---

## Usage

```powershell
.\Run-All.ps1
```

For best results, run PowerShell as Administrator.

---

## Project Status

> ⚠️ **Testing Phase**
>
> This project is currently in active testing and development.
>
> Checks, remediation logic, reporting formats, and execution workflows may change between releases.
>
> Results should be reviewed and validated before use in production environments.

---

## Intended Use Cases

- Windows 11 migration projects
- Enterprise deployment readiness assessments
- Device health audits
- IT support troubleshooting
- Automated compliance validation

---

## Disclaimer

This tool attempts to automate Windows 11 readiness validation and remediation. Certain issues may require manual intervention, BIOS/UEFI configuration changes, driver updates, or organizational approval before remediation can be completed.

Always test thoroughly before production deployment.

---

## License

MIT License
