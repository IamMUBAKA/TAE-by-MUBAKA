# MUBAKA LOCAL MACHINE MECHANICS

Local machine scripts must include:
- `Set-StrictMode -Version Latest`
- `$ErrorActionPreference = 'Stop'`
- predefined root path, target path, receipt path
- explicit tool checks before native commands
- native exit-code checks and artifact assertions
- failure stop marker `BLOCKED_REVIEW_REQUIRED`
- receipt written only after verified state

PowerShell helper requirements:
- `Invoke-NativeChecked`
- `Assert-Path`
- `Write-BlockedReceipt`

Mandatory clause:
“O-O-MUBAKA is closed only when visual posture, mechanical execution, public/private boundary, receipt truth, native exit-code verification, artifact existence verification, and founder-control authority all pass together. No isolated success state is valid outside the full cadence.”
