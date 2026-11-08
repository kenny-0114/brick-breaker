#!/usr/bin/env python3
"""별도 Godot 프로세스와 UUID 저장 경로로 P0 검증을 실행한다."""

import argparse
import base64
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass


PROJECT_ROOT = Path(__file__).resolve().parent.parent


class SetupError(Exception):
    """엔진 또는 저장 격리 환경을 준비할 수 없음을 나타낸다."""


def command_output(command, timeout=20):
    """환경 확인 명령의 출력을 읽고 실패를 준비 오류로 바꾼다."""
    try:
        result = subprocess.run(command, capture_output=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise SetupError(f"명령 실행 실패: {command[0]}: {error}") from error
    if result.returncode:
        raise SetupError(f"명령 실패(exit {result.returncode}): {command[0]}: "
                         f"{result.stderr.decode(errors='replace').strip()}")
    return result.stdout.decode(errors="replace").strip()


def wsl_path(path, to_windows=False):
    """WSL과 Windows 사이에서 실제 파일 경로를 변환한다."""
    return command_output(["wslpath", "-w" if to_windows else "-u", str(path)])


def resolve_engine(value):
    """Windows 표기와 로컬 표기의 엔진 경로를 실행 가능한 경로로 찾는다."""
    if os.name != "nt" and re.match(r"^[A-Za-z]:[\\/]", value):
        value = wsl_path(value)
    found = shutil.which(value)
    if found is None and Path(value).is_file():
        found = str(Path(value).resolve())
    if found is None:
        raise SetupError(f"Godot 실행 파일을 찾을 수 없습니다: {value}")
    return found, found.lower().endswith(".exe")


def project_name():
    """프로젝트 설정에서 기본 사용자 데이터 디렉터리 이름을 읽는다."""
    text = (PROJECT_ROOT / "project.godot").read_text(encoding="utf-8")
    if re.search(r"^config/use_custom_user_dir\s*=\s*true\s*$", text, re.M):
        raise SetupError("custom_user_dir 프로젝트의 원본 저장 경로는 지원하지 않습니다")
    match = re.search(r'^config/name\s*=\s*(".*")\s*$', text, re.M)
    if match is None:
        raise SetupError("project.godot에 config/name이 없습니다")
    name = json.loads(match.group(1))
    if not name or name in (".", "..") or re.search(r'[<>:"/\\|?*%\x00-\x1f]', name):
        raise SetupError("config/name에서 원본 저장 경로를 안전하게 유도할 수 없습니다")
    return name


def original_save_path(is_windows):
    """엔진 실행 전에 원본 저장 파일의 로컬 접근 경로를 계산한다."""
    name = project_name()
    if is_windows:
        if os.name == "nt":
            appdata = os.environ.get("APPDATA")
        else:
            appdata = command_output(["cmd.exe", "/c", "echo", "%APPDATA%"])
            if not re.match(r"^[A-Za-z]:[\\/]", appdata):
                raise SetupError("Windows APPDATA 경로를 확인할 수 없습니다")
            appdata = wsl_path(appdata)
        if not appdata:
            raise SetupError("APPDATA 환경 변수가 없습니다")
        root = Path(appdata) / "Godot" / "app_userdata"
    elif sys.platform == "darwin":
        root = Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata"
    else:
        root = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/app_userdata"
    return root / name / "save_data.json"


def save_snapshot(path):
    """원본 저장 파일의 존재 여부와 SHA256을 함께 기록한다."""
    if not path.exists():
        return "없음"
    return hashlib.sha256(path.read_bytes()).hexdigest()


def engine_path(path, is_windows):
    """Godot 프로세스가 접근할 수 있는 절대 경로로 변환한다."""
    path = Path(path).resolve()
    return wsl_path(path, to_windows=True) if is_windows and os.name != "nt" else str(path)


def windows_pids(engine, token):
    """고유 저장 UUID로 이번 실행에 속한 Windows PID만 조회한다."""
    powershell = shutil.which("powershell.exe")
    if powershell is None and os.name != "nt":
        powershell = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    if not powershell:
        raise SetupError("Windows 프로세스 종료 확인에 필요한 powershell.exe가 없습니다")
    name = Path(engine).name.replace("'", "''")
    script = ("$ErrorActionPreference='Stop'; "
              f"Get-CimInstance Win32_Process -Filter \"Name='{name}'\" | "
              f"Where-Object {{$_.CommandLine -like '*--save-path=user://p0/{token}.json*'}} | "
              "ForEach-Object {$_.ProcessId}")
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    output = command_output([powershell, "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded])
    try:
        return [int(line.strip()) for line in output.splitlines() if line.strip()]
    except ValueError as error:
        raise SetupError(f"Windows PID 조회 출력 오류: {output}") from error


def stop_process(process, engine, token, is_windows):
    """시간 초과 프로세스 트리를 종료하고 실제 종료까지 확인한다."""
    if is_windows:
        pids = [process.pid] if os.name == "nt" else windows_pids(engine, token)
        for pid in pids:
            # WSL의 Popen.pid는 Windows PID와 다르므로 UUID 조회 결과를 사용한다.
            killed = subprocess.run(["taskkill.exe", "/F", "/T", "/PID", str(pid)],
                                    capture_output=True, timeout=20)
            if killed.returncode and windows_pids(engine, token):
                raise SetupError(f"Windows Godot 종료 실패: PID {pid}")
        if windows_pids(engine, token):
            raise SetupError("시간 초과된 Windows Godot 프로세스가 남아 있습니다")
        if process.poll() is None:
            process.kill()
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    try:
        return process.communicate(timeout=10)
    except subprocess.TimeoutExpired as error:
        raise SetupError("시간 초과된 자식 프로세스의 종료를 확인하지 못했습니다") from error


@dataclass
class CaseResult:
    """최종 표에 필요한 케이스 실행 결과를 보관한다."""

    label: str
    status: str
    elapsed: float
    exit_code: int | None


def parse_result(stdout, case, level, expected_save, is_windows):
    """단일 결과 JSON과 케이스별 저장 격리 계약을 검증한다."""
    lines = [line for line in stdout.splitlines() if line.startswith("P0_RESULT ")]
    if len(lines) != 1:
        raise ValueError(f"P0_RESULT 줄이 정확히 하나여야 합니다(실제 {len(lines)}개)")
    result = json.loads(lines[0][len("P0_RESULT "):])
    if not isinstance(result, dict) or result.get("case") != case:
        raise ValueError("결과 case가 요청과 다릅니다")
    if "level" not in result or (level is not None and result["level"] != level):
        raise ValueError("결과 level이 요청과 다릅니다")
    if not isinstance(result.get("pass"), bool):
        raise ValueError("결과 pass가 bool이 아닙니다")
    checks = result.get("checks")
    if not isinstance(checks, list) or not checks:
        raise ValueError("결과 checks가 비어 있거나 배열이 아닙니다")
    for check in checks:
        if (not isinstance(check, dict) or not isinstance(check.get("name"), str)
                or not isinstance(check.get("ok"), bool) or "detail" not in check):
            raise ValueError("결과 checks 형식이 잘못되었습니다")
    reported = result.get("save_path_global")
    if not isinstance(reported, str):
        raise ValueError("결과 save_path_global이 없습니다")
    reported = reported.replace("\\", "/")
    expected = engine_path(expected_save, is_windows).replace("\\", "/")
    if (reported.casefold() if is_windows else reported) != (expected.casefold() if is_windows else expected):
        raise ValueError(f"저장 격리 경로 불일치: {reported} (기대: {expected})")
    return result


def run_case(args, engine, is_windows, original, log_dir, case, level):
    """한 케이스를 독립 프로세스로 실행하고 실패 자료를 보존한다."""
    token = uuid.uuid4().hex
    label = f"load({level})" if case == "load" else case
    save_path = original.parent / "p0" / f"{token}.json"
    log_path = log_dir / f"{label}-{token}.log"
    command = [engine, "--headless", "--path", engine_path(PROJECT_ROOT, is_windows),
               "--log-file", engine_path(log_path, is_windows),
               "--script", "res://tests/p0_runner.gd", "--",
               f"--save-path=user://p0/{token}.json", f"--case={case}"]
    if level is not None:
        command.append(f"--level={level}")
    if args.self_test == "fail" and case == "turn":
        command.append("--self-test=fail")
    timeout = (90 if case == "turn" else 30) * args.timeout_scale
    if args.self_test == "timeout" and case == "turn":
        timeout = 2
    print(f"실행: {label} (제한 {timeout:g}초, UUID {token})", flush=True)
    start = time.monotonic()
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                   start_new_session=os.name != "nt")
    except OSError as error:
        raise SetupError(f"Godot 실행 실패: {error}") from error
    is_timeout = False
    try:
        stdout_bytes, stderr_bytes = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        is_timeout = True
        stdout_bytes, stderr_bytes = stop_process(process, engine, token, is_windows)
    except BaseException:
        stop_process(process, engine, token, is_windows)
        raise
    elapsed = time.monotonic() - start
    stdout = stdout_bytes.decode("utf-8", errors="replace")
    stderr = stderr_bytes.decode("utf-8", errors="replace")
    log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    status = "TIMEOUT" if is_timeout else "PASS"
    reasons = []
    if "SCRIPT ERROR" in stdout + stderr + log:
        status = "FAIL"
        reasons.append("SCRIPT ERROR 감지")
    if not is_timeout:
        if process.returncode != 0:
            status = "ERROR" if process.returncode == 2 and status != "FAIL" else "FAIL"
            reasons.append(f"자식 exit {process.returncode}")
        try:
            result = parse_result(stdout, case, level, save_path, is_windows)
            if not result["pass"] or any(not check["ok"] for check in result["checks"]):
                if status != "ERROR":
                    status = "FAIL"
                reasons.append("runner 검증 실패")
        except (ValueError, TypeError) as error:
            if status != "ERROR":
                status = "FAIL"
            reasons.append(str(error))
    if status == "PASS":
        save_path.unlink(missing_ok=True)
        log_path.unlink(missing_ok=True)
    else:
        stdout_path = log_path.with_suffix(".stdout.txt")
        stderr_path = log_path.with_suffix(".stderr.txt")
        stdout_path.write_text(stdout, encoding="utf-8")
        stderr_path.write_text(stderr, encoding="utf-8")
        print(f"  {status}: {'; '.join(reasons) or '벽시계 제한 시간 초과'}")
        print(f"  로그: {log_path}\n  stdout: {stdout_path}\n  stderr: {stderr_path}")
        print(f"  저장: {save_path} ({'존재' if save_path.exists() else '미생성'})")
    return CaseResult(label, status, elapsed, process.returncode)


def positive_scale(value):
    """유한한 양수만 시간 제한 배율로 허용한다."""
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise argparse.ArgumentTypeError("timeout-scale은 유한한 양수여야 합니다")
    return number


def main():
    """환경과 원본 저장 보호를 확인하며 전체 P0 결과를 집계한다."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--suite", required=True, choices=["p0"])
    parser.add_argument("--timeout-scale", type=positive_scale, default=1.0)
    parser.add_argument("--self-test", choices=["fail", "timeout"])
    args = parser.parse_args()
    results = []
    original = None
    before = None
    has_setup_error = False
    has_save_change = False
    log_dir = None
    try:
        engine, is_windows = resolve_engine(args.godot)
        version = command_output([engine, "--version"])
        if re.match(r"^4\.6\.", version) is None:
            raise SetupError(f"Godot 4.6.x가 필요합니다(실제: {version!r})")
        print(f"Godot: {version}", flush=True)
        if not (PROJECT_ROOT / "tests/p0_runner.gd").is_file():
            raise SetupError("P0 runner가 없습니다: res://tests/p0_runner.gd (tests 작성 완료 후 재실행)")
        original = original_save_path(is_windows)
        before = save_snapshot(original)
        print(f"원본 저장: {original}\n실행 전 SHA256/존재: {before}", flush=True)
        isolated_dir = original.parent / "p0"
        isolated_dir.mkdir(parents=True, exist_ok=True)
        log_dir = Path(tempfile.mkdtemp(prefix="p0-logs-", dir=isolated_dir))
        cases = [("title", None)] + [("load", level) for level in range(1, 6)] + [("turn", 1), ("ball_angle", None), ("aim_clamp", None)]
        for case, level in cases:
            results.append(run_case(args, engine, is_windows, original, log_dir, case, level))
    except (SetupError, OSError, ValueError, subprocess.SubprocessError) as error:
        has_setup_error = True
        print(f"환경 오류: {error}", file=sys.stderr)
        if log_dir is not None:
            print(f"보존 로그 디렉터리: {log_dir}", file=sys.stderr)
    except KeyboardInterrupt:
        has_setup_error = True
        print("중단: 자식 프로세스 종료 후 원본 저장을 확인합니다", file=sys.stderr)
    finally:
        if original is not None and before is not None:
            try:
                after = save_snapshot(original)
                print(f"실행 후 SHA256/존재: {after}")
                has_save_change = before != after
                if has_save_change:
                    print("FAIL: 원본 save_data.json의 존재 여부 또는 SHA256이 바뀌었습니다", file=sys.stderr)
            except OSError as error:
                has_save_change = True
                print(f"FAIL: 원본 저장 재확인 실패: {error}", file=sys.stderr)
        if log_dir is not None and log_dir.exists() and not any(log_dir.iterdir()):
            log_dir.rmdir()
        print("\n케이스       결과       경과초    자식 exit")
        print("-----------  ---------  --------  ---------")
        for result in results:
            print(f"{result.label:<11}  {result.status:<9}  {result.elapsed:>8.2f}  {result.exit_code}")
    if has_save_change or any(result.status == "FAIL" for result in results):
        return 1
    if has_setup_error or any(result.status == "ERROR" for result in results):
        return 2
    if any(result.status == "TIMEOUT" for result in results):
        return 124
    return 0


if __name__ == "__main__":
    sys.exit(main())
