# 보관된 수첩 검증 근거

결함 검증과 전달을 마친 세 묶음은 각 전달 커밋에 보존한다. 보고서가 인용한 실행 로그, 실패 대조, 소스 지문을 독립 감사에서 대조할 수 있다. 아래 크기와 SHA-256은 Git 원본 바이트 기준이다.

| 묶음 | 검증 보고서 | 전달 커밋 | 소스 트리 | 독립 감사 스크립트 |
| --- | --- | --- | --- | --- |
| `2026-10-10_reset_process` | [별도 프로세스 리셋·기상 복귀 검증 (ERR-0065, ERR-0067, ERR-0068)](2026-10-10_별도프로세스_리셋기상_복귀검증.md) | `8298eaccd43a2f6c8ce55d36ca35a567ec4ece7d` | `18567604b2b1cd4b0d8b61a83ec67de789559d60` | `audit_notebook_reset_process.ps1` |
| `2026-10-11_wake_location` | [신규 기상 기록의 침실 출처 검증 (ERR-0066)](2026-10-11_기상출처_침실정본화_검증.md) | `084492e4ea161b6cbe87fd852585032f91626011` | `6310c1d1e0ea88da7a5fc0ecb16323e43b375303` | `audit_notebook_wake_location.ps1` |
| `2026-10-11_basement_boundary` | [지하 검사 준비 경계·구형 스크롤 수명 검증 (ERR-0069, ERR-0070)](2026-10-11_지하검사_준비경계_및_구형스크롤수명_검증.md) | `f269b80e466ffca87f0297c1cc4ce15bbbf4798b` | `de7e29726aacfd6706b718dd5db83c7f178f6af2` | `audit_notebook_basement_boundary.ps1` |

| 묶음 | 파일 | 바이트 | SHA-256 |
| --- | --- | ---: | --- |
| `2026-10-10_reset_process` | [bundle.json](https://github.com/devb-eru/ggb/blob/8298eaccd43a2f6c8ce55d36ca35a567ec4ece7d/ideas/md/v04/issues/validation/evidence/2026-10-10_reset_process/bundle.json) | 279 | `26c4ff6a4e954a2b71b0cef7af68c6c1ce7d5d707c9a4a8fe5e9140b28c0a8c3` |
| `2026-10-10_reset_process` | [bundle.zip](https://github.com/devb-eru/ggb/blob/8298eaccd43a2f6c8ce55d36ca35a567ec4ece7d/ideas/md/v04/issues/validation/evidence/2026-10-10_reset_process/bundle.zip) | 17,688,550 | `4f40d1dd6378bf635570b4adff76c67f1bef05d9d237a23f3f9bf115939e4e3d` |
| `2026-10-11_wake_location` | [bundle.json](https://github.com/devb-eru/ggb/blob/084492e4ea161b6cbe87fd852585032f91626011/ideas/md/v04/issues/validation/evidence/2026-10-11_wake_location/bundle.json) | 185 | `fd19c375d21cf394e047991f6c3f9ab31394bdccf090289fb5537d0c32f255cf` |
| `2026-10-11_wake_location` | [bundle.zip](https://github.com/devb-eru/ggb/blob/084492e4ea161b6cbe87fd852585032f91626011/ideas/md/v04/issues/validation/evidence/2026-10-11_wake_location/bundle.zip) | 37,545,564 | `d2da0a8a6d9abdb0d0e245449619de13acd1e64ffc1eae47bf969d67428c5cbb` |
| `2026-10-11_basement_boundary` | [manifest.json](https://github.com/devb-eru/ggb/blob/f269b80e466ffca87f0297c1cc4ce15bbbf4798b/ideas/md/v04/issues/validation/evidence/2026-10-11_basement_boundary/manifest.json) | 65,610 | `5cfe8c8bfa7e46623a2ea438a40a333a40a73084cc15c5050f6db0544ca77f02` |
| `2026-10-11_basement_boundary` | [raw.zip](https://github.com/devb-eru/ggb/blob/f269b80e466ffca87f0297c1cc4ce15bbbf4798b/ideas/md/v04/issues/validation/evidence/2026-10-11_basement_boundary/raw.zip) | 707,823 | `586831e3315bc0e2b9d70fb4b71de2f0da16fa28d05ae54ab0501283bfdd389b` |

## 복원과 독립 감사

저장소 루트에서 PowerShell 7로 실행한다. 아래는 지하 준비 경계 묶음의 예시다. 다른 묶음은 표에 있는 전달 커밋, 묶음 이름, 감사 스크립트 이름을 넣는다.

```powershell
$commit = 'f269b80e466ffca87f0297c1cc4ce15bbbf4798b'
$bundle = '2026-10-11_basement_boundary'
$audit = 'audit_notebook_basement_boundary.ps1'
$evidence = "ideas/md/v04/issues/validation/evidence/$bundle"
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ggb-evidence-' + [Guid]::NewGuid().ToString('N'))
$zip = "$scratch.zip"

git archive --format=zip "--output=$zip" $commit -- game/scripts "scripts/$audit" $evidence
if ($LASTEXITCODE -ne 0) { throw 'Git archive failed' }
Expand-Archive -LiteralPath $zip -DestinationPath $scratch
$restoredEvidence = Join-Path $scratch $evidence
Get-ChildItem -LiteralPath $restoredEvidence -File | Get-FileHash -Algorithm SHA256
```

표의 SHA-256과 대조한 뒤 같은 PowerShell 7 세션에서 감사를 실행한다. 리셋·기상 묶음은 `bundle.zip`을 별도 폴더에 풀고 파일 시스템의 실제 경로 표기를 사용한다. 해당 감사기는 manifest 경로를 대소문자까지 비교한다. 제품 스크립트는 증거와 같은 전달 커밋에서 가져온다.

```powershell
$sealed = Join-Path $restoredEvidence 'bundle.zip'
if (Test-Path -LiteralPath $sealed -PathType Leaf) {
    $rawEvidence = Join-Path $scratch 'raw-evidence'
    [IO.Compression.ZipFile]::ExtractToDirectory($sealed, $rawEvidence, [Text.Encoding]::UTF8)
    $restoredEvidence = (Get-Item -LiteralPath $rawEvidence).FullName
}

pwsh -NoProfile -File (Join-Path $scratch "scripts/$audit") `
  -EvidencePath $restoredEvidence -RepoPath $scratch -SelfTest
```
