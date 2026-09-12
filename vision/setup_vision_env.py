"""奶蛙：遗忘档案馆 — 摄像头视觉环境自动安装器

用途：在一台新电脑上一次性准备好 MediaPipe 摄像头桥接所需的 Python 依赖。
由 scripts/visual_recognition.gd 在检测到依赖缺失时自动调用，也可以手动运行。

用法：
    python vision/setup_vision_env.py

做的事：
    1. 找一个可用的 Python 解释器（3.10 ~ 3.12，mediapipe 目前不支持 3.13+）
    2. 在 vision/.vision-venv 下建虚拟环境（如果还没有）
    3. 装 opencv-contrib-python + mediapipe + numpy
    4. 打印结果，Godot 侧下次启动即可直接拉起桥接
"""
import os
import subprocess
import sys
from pathlib import Path

VISION_DIR = Path(__file__).resolve().parent
VENV_DIR = VISION_DIR / ".vision-venv"
# Windows 在 Scripts/，类 Unix 在 bin/
VENV_PYTHON = VENV_DIR / ("Scripts/python.exe" if os.name == "nt" else "bin/python")

# mediapipe 1.0.x 目前只支持到 Python 3.12
MIN_PY = (3, 10)
MAX_PY = (3, 12)
REQUIREMENTS = [
    "numpy==1.26.4",
    "opencv-contrib-python==4.10.0.84",
    "mediapipe==1.0.1",
]


def log(msg: str) -> None:
    print("[setup-vision] %s" % msg, flush=True)


def find_system_python() -> str:
    """找一个版本合适的 Python。优先 py launcher，其次 PATH 上的 python。"""
    candidates: list[list[str]] = []
    if os.name == "nt":
        # Windows 的 py launcher 可以指定版本
        for minor in (12, 11, 10):
            candidates.append(["py", "-3.%d" % minor])
    candidates.append([sys.executable])
    candidates.append(["python3"])
    candidates.append(["python"])

    for cmd in candidates:
        try:
            out = subprocess.run(
                cmd + ["-c", "import sys; print('%d.%d' % sys.version_info[:2])"],
                capture_output=True, text=True, timeout=15,
            )
        except (OSError, subprocess.SubprocessError):
            continue
        if out.returncode != 0:
            continue
        ver = out.stdout.strip()
        try:
            major, minor = (int(x) for x in ver.split("."))
        except ValueError:
            continue
        if MIN_PY <= (major, minor) <= MAX_PY:
            log("找到合适的解释器：%s (Python %s)" % (" ".join(cmd), ver))
            return " ".join(cmd)
        log("跳过 %s：Python %s 不在 %d.%d ~ %d.%d 范围内"
            % (" ".join(cmd), ver, *MIN_PY, *MAX_PY))
    return ""


def venv_is_usable() -> bool:
    if not VENV_PYTHON.exists():
        return False
    try:
        out = subprocess.run(
            [str(VENV_PYTHON), "-c",
             "import cv2, mediapipe; print('ok')"],
            capture_output=True, text=True, timeout=60,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return out.returncode == 0 and "ok" in out.stdout


def create_venv(python_cmd: str) -> bool:
    log("在 %s 创建虚拟环境…" % VENV_DIR)
    try:
        out = subprocess.run(
            python_cmd.split() + ["-m", "venv", str(VENV_DIR)],
            capture_output=True, text=True, timeout=180,
        )
    except (OSError, subprocess.SubprocessError) as exc:
        log("创建虚拟环境失败：%s" % exc)
        return False
    if out.returncode != 0:
        log("创建虚拟环境失败：%s" % out.stderr.strip()[-500:])
        return False
    return True


def install_requirements() -> bool:
    log("安装依赖（首次约需几分钟，请耐心等待）…")
    cmds = [
        [str(VENV_PYTHON), "-m", "pip", "install", "--upgrade", "pip", "-q"],
        [str(VENV_PYTHON), "-m", "pip", "install", "-q"] + REQUIREMENTS,
    ]
    for cmd in cmds:
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
        except (OSError, subprocess.SubprocessError) as exc:
            log("安装失败：%s" % exc)
            return False
        if out.returncode != 0:
            log("安装失败：%s" % (out.stderr.strip() or out.stdout.strip())[-800:])
            return False
    return True


def main() -> int:
    log("检查目标：%s" % VENV_DIR)

    if venv_is_usable():
        log("依赖已就绪，无需安装。")
        return 0

    # 环境存在但依赖不全（换机器后常见：venv 路径失效）→ 直接重建
    if VENV_DIR.exists():
        log("已有 .vision-venv 但不可用（换机器后路径会失效），重建中…")

    python_cmd = find_system_python()
    if not python_cmd:
        log("未找到 Python %d.%d ~ %d.%d，请先安装：https://www.python.org/downloads/"
            % (*MIN_PY, *MAX_PY))
        return 1

    if not create_venv(python_cmd):
        return 1
    if not install_requirements():
        return 1

    if venv_is_usable():
        log("完成！摄像头桥接环境已就绪。")
        return 0
    log("安装后依赖校验仍未通过，请手动检查。")
    return 1


if __name__ == "__main__":
    sys.exit(main())
